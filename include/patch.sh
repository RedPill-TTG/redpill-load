#!/usr/bin/env bash
set -u

# Applies bspatch(1) from a list to the file specified
#
# Args:
#   $1 source file
#   $2 destination file
#   $3 list of NL separated patches (e.g. from brp_json_get_array_values())
#   $4 base path to find patches (paths in $2 can/should be relative)
brp_apply_binary_patches()
{
  local work_file_src="${2}.tmp_src" # bspatch cannot really patch multiple times in place so we need a work file
  local work_file_final="${2}" # bspatch cannot really patch multiple times in place so we need a work file
  cp "${1}" "${work_file_final}" || pr_crit "Failed to do initial copy of %s to %s" "${1}" "${work_file_final}"

  pr_process "Patching %s to %s" "${1}" "${2}"
  local out;
  for patch_file in ${3}; do
    pr_dbg "Applying %s" "${patch_file}"

    "${MV_PATH}" "${work_file_final}" "${work_file_src}" \
      || pr_crit "Failed to move %s to %s for next patch" "${work_file_final}" "${work_file_src}"

    out=$("${BSPATCH_PATH}" "${work_file_src}" "${work_file_final}" "${4}/${patch_file}" 2>&1)
    if [ $? -ne 0 ]; then
      "${RM_PATH}" "${work_file_final}" "${work_file_src}" || pr_warn "Failed to delete work files"
      pr_crit "One of the patches - %s - failed to apply\n\n%s" "${patch_file}" "${out}"
    fi
  done;

  "${RM_PATH}" "${work_file_src}" || pr_warn "Failed to delete src work file"
  pr_process_ok
}

# Applies standard patch(1) patches from a list to the directory specified
#
# Args:
#   $1 directory
#   $2 list of NL separated patches (e.g. from brp_json_get_array_values())
#   $3 reference to a map of K=>V pairs with variables, see brp_expand_var_path()
brp_apply_text_patches()
{
  local -n _path_map=$3
  pr_process "Apply patches to %s" "${1}"

  local out;
  for patch_file in ${2}; do
    patch_file=$(brp_expand_var_path "${patch_file}" _path_map)
    pr_dbg "Applying %s" "${patch_file}"

    out=$("${PATCH_PATH}" -p1 -d "${1}" <"${patch_file}" 2>&1)
    if [ $? -ne 0 ]; then
      pr_crit "One of the patches - %s - failed to apply\n\n%s" "${patch_file}" "${out}"
    fi
  done;

  pr_process_ok
}


# Generates calls to _set_conf_kv() from this tool's JSON config file
#
# This function is useful for two things:
#  - Actually replacing values in pre-boot configs when the loader is built
#  - Generating a part of shell script which replaces values in the post-boot environment
#
# The resulting text will be array list of _set_conf_kv function calls (present in include/config-manipulators.sh) which
# can be executed during build to patch ramdisk AND embedded in /sbin/init.post to patch the post-boot files
#
# Args: $1 JSON config file | $2 key with options | $3 .conf destination | $4 result array
brp_generate_set_conf_calls()
{
  local -n __JSON_CONF_RESULTS=$4
  local -A conf_kvs;
  brp_read_kv_to_array "${1}" "${2}" conf_kvs
  for key in "${!conf_kvs[@]}"; do
#    pr_dbg "Generating set call for %s=%s" "${key}" "${conf_kvs[$key]}"
    __JSON_CONF_RESULTS+=("_set_conf_kv '${key}' '${conf_kvs[$key]}' '${3}'")
  done
}

# Same as brp_generate_set_conf_calls() but accepts a list of conf files
#
# Args: $1 JSON config file | $2 key with options | $3 result array | $4....n multiple .conf destinations
brp_generate_set_confs_calls()
{
  local JSON_CFG="${1}"
  local JSON_KEY="${2}"
  local -n __JSON_CONFS_RESULTS=$3

  local -a conf_calls;
  local out;
  for conf_file in "${@:4}"; do
    conf_calls=()
    brp_generate_set_conf_calls "${JSON_CFG}" "${JSON_KEY}" "${conf_file}" conf_calls

    # this weirdness handles empty arrays to prevent explosions in bash <4.4, see https://stackoverflow.com/a/58261136
    for call in ${conf_calls[0]+"${conf_calls[@]}"}; do
      __JSON_CONFS_RESULTS+=("${call}")
    done
  done;
}

# Takes a JSON file containing list of key-value pairs and replaces them in all .conf files passed
#
# Args: $1 JSON config file | $2 key with options | $3 multiple .conf destinations
brp_patch_config_files()
{
  local confs_calls;
  brp_generate_set_confs_calls "${1}" "${2}" confs_calls "${@:3}"

  local out;
  # this weirdness handles empty arrays to prevent explosions in bash <4.4, see https://stackoverflow.com/a/58261136
  for conf_call in ${confs_calls[0]+"${confs_calls[@]}"}; do
    pr_dbg "Calling %s" "${conf_call}"
    out=$(eval "${conf_call}")
    if [ $? -ne 0 ]; then
      pr_crit "Config patching failed to run: %s\n\n%s" "${conf_call}" "${out}"
    fi
  done;
}

# Finds the token in file and replaces it with an arbitrary string
#
# This is slightly stupid because it uses a temporary file, but even our senior sed magician gave up. PRs welcomed.
#
# Args: $1 file to modify | $2 token | $3 text to insert
brp_replace_token_with_text()
{
  local temp_file="${1}.tmp_ins_frag"
  pr_dbg "Replacing \"%s\" with text from %s in %s" "${2}" "${temp_file}" "${1}"

  echo "${3}" > "${temp_file}"
  if [ $? -ne 0 ]; then
    pr_crit "Failed to create temp file %s" "${temp_file}"
  fi

  local out;
  out=$("${SED_PATH}" -e "/${2}/ {" -e "r ${temp_file}" -e 'd' -e '}' -i "${1}" 2>&1)
  if [ $? -ne 0 ]; then
    pr_crit "Failed to replace %s in file %s with contents of %s\n\n%s" "${2}" "${1}" "${temp_file}" "${out}"
  fi
  "${RM_PATH}" "${temp_file}" || pr_warn "Failed to remove temp file %s" "${temp_file}"
}

# Finds the token in file and replaces it with a comment-stripped shell script from a file
#
# This is slightly stupid because it uses a temporary file, but even our senior sed magician gave up. PRs welcomed.
#
# Args: $1 file to modify | $2 token | $3 shell script to insert
brp_replace_token_with_script()
{
  pr_dbg "Replacing \"%s\" with script %s in %s" "${2}" "${3}" "${1}"
  local script;
  script=$("${GREP_PATH}" -v -e '^[\t ]*#' -e '^$' "${3}")
  if [ $? -ne 0 ]; then
    pr_crit "Failed to read script to insert from %s" "${3}"
  fi

  brp_replace_token_with_text "${1}" "${2}" "${script}"
}
