#!/usr/bin/env bash
set -u

##### BASIC RUNTIME VALIDATION #########################################################################################
# shellcheck disable=SC2128
if [ -z "${BASH_SOURCE}" ] ; then
    echo "You need to execute this script using bash v4+ without using pipes"
    exit 1
fi

cd "${BASH_SOURCE%/*}/" || exit 1
########################################################################################################################

##### CONFIGURATION YOU CAN OVERRIDE USING ENVIRONMENT #################################################################
readonly BRP_DEBUG=${BRP_DEBUG:-0} # whether you want to see debug messages
readonly MRP_SRC_NAME=${MRP_SRC_NAME:-$(basename "$0")}
readonly RPT_EXTS_DIR=${RPT_EXTS_DIR:-"$PWD/custom/extensions"}
########################################################################################################################

##### INCLUDES #########################################################################################################
. include/log.sh # logging helpers
. include/text.sh # text manipulation
. include/runtime.sh # need to include this early so we can used date and such
. include/json.sh # json parsing routines
. include/file.sh # file-related operations (copying/moving/unpacking etc)
. include/patch.sh # helpers for creating *.sh from template
########################################################################################################################


# Validates extension ID
#
# Args: $1 ID of an extension
# Exit: 0 on valid, 1 on validation failure
mrp_validate_id()
{
  if [[ "${1}" =~ ^[A-Za-z]+[A-Za-z0-9._\-]+$ ]]; then
    pr_dbg "ID \"%s\" is verified as valid" "${1}"
    return 0
  else
    pr_err "The ID \"%s\" is invalid" "${1}"
    return 1
  fi
}

# Validates platform ID used to identify releases
#
# Args: $1 platform ID
# Exit: 0 on valid, 1 on validation failure
mrp_validate_platform_id()
{
  if [[ "${1}" =~ ^[a-z0-9_]+$ ]]; then
    pr_dbg "Platform ID \"%s\" is verified as valid" "${1}"
    return 0
  else
    pr_err "Platform ID \"%s\" is invalid" "${1}"
    return 1
  fi

  return 0;
}

# Args: $1 ID of an extension
mrp_has_extension()
{
  if [[ -f "${RPT_EXTS_DIR}/${1}/${1}.json" ]]; then
    return 0;
  else
    return 1;
  fi
}

mrp_get_all_extensions()
{
  rpt_list_directories "${RPT_EXTS_DIR}" $1
}

# Gets index file for an extension (if exists)
# The file path returned is guaranteed to be a valid index file
#
# Args: $1 ID of the extension | $2 silent mode to only return exit code and treat errors as debug [default=0]
# Return: file path
# Exit:
#   0 - success
#   1 - parameters passed are invalid
#   2 - file not found
#   3 - semantic validation failure (json struct, json semantic, etc)
mrp_get_existing_index_file()
{
  pr_dbg "Loading existing index file for extension %s" "${1}"

  if ! mrp_validate_id "${1}"; then
    return 1
  fi

  local IDX_FILE="${RPT_EXTS_DIR}/${1}/${1}.json"
  if [[ ! -r "${IDX_FILE}" ]]; then
    if [[ "${2:-0}" -eq 1 ]]; then # bash is really fugly...
      pr_dbg "Extension %s index file %s is not readable or does not exist - extension is probably not added" "${1}" "${IDX_FILE}"
    else
      pr_err "Extension %s index file %s is not readable or does not exist - extension is probably not added" "${1}" "${IDX_FILE}"
    fi
    return 2
  fi

  if ! mrp_validate_index_file "${IDX_FILE}" "${IDX_FILE}"; then
    if [[ "${2:-0}" -eq 1 ]]; then # bash is really fugly...
      pr_dbg "Extension %s index file %s is is not a valid index file" "${1}" "${IDX_FILE}"
    else
      pr_err "Extension %s index file %s is is not a valid index file" "${1}" "${IDX_FILE}"
    fi
    return 3
  fi

  pr_dbg "Found valid existing index for %s extension at %s" "${1}" "${IDX_FILE}"
  echo "${IDX_FILE}"
  return 0
}

# Args: $1 extension id
mrp_show_ext_info()
{
  local index_file
  local index_file_exit
  local -A info_kv
  index_file=$(mrp_get_existing_index_file "${1}" 1)
  index_file_exit=$?

  pr_info "========================================== %s ==========================================" "${1}"
  case $index_file_exit in
    0) brp_read_kv_to_array "${index_file}" 'info' info_kv
       pr_info "Extension name: %s" "${info_kv[name]}"
       if [[ ! -z ${info_kv[description]+x} ]]; then
         pr_info "Description: %s" "${info_kv[description]}"
       else
         pr_dbg "Description: <not provided>"
       fi
       pr_info "To get help visit: %s" "${info_kv[help_url]}"
       if [[ ! -z ${info_kv[packer_url]+x} ]]; then
         pr_info "Extension preparer/packer: %s" "${info_kv[packer_url]}"
       else
         pr_dbg "Extension preparer/packer: <not provided>"
       fi
       if [[ ! -z ${info_kv[author_url]+x} ]]; then
         pr_info "Software author: %s" "${info_kv[author_url]}"
       else
         pr_dbg "Software author: <not provided>"
       fi
       pr_info "Update URL: %s" "$(brp_json_get_field "${index_file}" 'url' 1)"

       brp_read_kv_to_array "${index_file}" 'releases' info_kv
       local platforms=''
       for platform in "${!info_kv[@]}"; do
         platforms+="${platform} "
       done

       pr_info "Platforms supported: %s" "${platforms}"

       ;;
    1) pr_err "Extension ID %s is invalid" "${1}"
       ;;
    2) pr_err "Extension %s is not installed" "${1}"
       ;;
    3) pr_err "Extension %s index is invalid - try \"%s update\" to fix it" "${1}" "${MRP_SRC_NAME}"
       ;;
    *) pr_err "Unknown error %d" "${index_file_exit}"
  esac
  pr_info "=======================================================================================\n"
}

# Returns standardized error of extension index validation failure
#
# Args: $1 extension index URL | $2 id of the extension (if known) | $2 error message
mrp_validate_ext_idx_fail()
{
  pr_err "Extension loaded from %s (id: %s) is invalid: %s. Please report that to the extension maintainer via help URL" \
         "${1}" "${2}" "${3}"
}

# Validates extension index file
#
# Args:
#   $1 Path to the index file
#   $2 URL or path of the index file (if known)
#   $3 Verify entries [validate all URLs and post warnings if they're not valid, returning 2 if any are invalid]
# Exit: 0 - success; 1 - failure; 2 - soft-failure
mrp_validate_index_file()
{
  pr_dbg "Validating extension index file \"%s\"" "${1}"

  if ! brp_json_validate "${1}" 1; then # validate JSON *file*, not its format/semantic - it will be parsable
    mrp_validate_ext_idx_fail "${2}" '' 'index JSON file is unparsable'
    return 1
  fi

  local id=$(brp_json_get_field "${1}" 'id') # this will error-out if field doesn't exist at all
  if ! mrp_validate_id "${id}"; then
    mrp_validate_ext_idx_fail "${2}" "${id}" 'the ID did not pass validation'
    return 1
  fi

  # todo validate URL optionally?
  if [[ "$(brp_json_has_field "${1}" 'url')" -ne '1' ]]; then
    mrp_validate_ext_idx_fail "${2}" "${id}" 'index has no update URL'
    return 1
  fi

  if [[ "$(brp_json_has_field "${1}" 'info')" -ne '1' ]]; then
    mrp_validate_ext_idx_fail "${2}" "${id}" 'index has no info section'
    return 1
  fi

  local -A info_kv
  brp_read_kv_to_array "${1}" 'info' info_kv
  if [[ -z "${info_kv[name]+x}" ]] || [[ "${info_kv[name]}" == '' ]]; then
    mrp_validate_ext_idx_fail "${2}" "${id}" 'index info section has no/empty name defined'
    return 1
  fi

  if [[ -z "${info_kv[help_url]+x}" ]] || [[ "${info_kv[help_url]}" == '' ]]; then
    mrp_validate_ext_idx_fail "${1}" "${id}" 'index info section has no/empty help_url defined'
    return 1
  fi

  if [[ "$(brp_json_has_field "${1}" 'releases')" -ne '1' ]]; then
    mrp_validate_ext_idx_fail "${2}" "${id}" 'index has no releases section'
    return 1
  fi

  local -a releases
  brp_json_get_keys "${1}" 'releases' releases
  for rel_id in "${releases[@]}"; do
    if ! mrp_validate_platform_id "${rel_id}"; then
      mrp_validate_ext_idx_fail "${2}" "${id}" "release ID \"${rel_id}\" is invalid"
      return 1
    fi
  done

  pr_dbg "Extension index file \"%s\" OK" "${1}"

  return 0
}

# Returns standardized error of extension recipe validation failure
#
# Args: $1 extension recipe URL | $2 id of the extension (if known) | $3 platform id | $4 error message
mrp_validate_ext_recipe_fail()
{
  local ext_id;
  if [[ "${2}" == '' ]]; then
    ext_id='<unknown>'
  else
    ext_id="${2}"
  fi


  pr_err "Extension (id: %s) recipe for %s loaded from %s is invalid: %s. Please report that to the extension maintainer via help URL" \
         "${2}" "${3}" "${1}" "${4}"
}

# Validates extension recipe file
#
# Args:
#   $1 extension ID
#   $2 platform ID
#   $3 Path to the recipe file
#   $x [removed?] Verify URLs [validate all URLs and post warnings if they're not valid, returning 2 if any are invalid]
# Exit: 0 - success; 1 - failure; 2 - soft-failure of URLs
mrp_validate_recipe_file()
{
  pr_dbg "Validating extension index file \"%s\"" "${1}"

  if ! brp_json_validate "${3}" 1; then # validate JSON *file*, not its format/semantic - it will be parsable
    mrp_validate_ext_recipe_fail "${3}" "${1}" "${2}" 'recipe JSON file is unparsable'
    return 1
  fi


  if [[ "$(brp_json_has_field "${3}" 'files')" -ne '1' ]]; then
    mrp_validate_ext_recipe_fail "${3}" "${1}" "${2}" 'recipe file lacks files section'
    return 1
  fi

  # we're not verifying the structure of files here as during the update it will do that attempting to download them

  # todo: this should check if sections aren't empty but this is annoying in bash
  if [[ "$(brp_json_has_field "${3}" 'kmods')" -ne '1' ]] && [[ "$(brp_json_has_field "${3}" 'scripts')" -ne '1' ]]; then
    mrp_validate_ext_recipe_fail "${3}" "${1}" "${2}" 'recipe file does not define kmods nor scripts'
    return 1
  fi

  local -A scripts_kv
  brp_read_kv_to_array "${3}" "scripts" scripts_kv # we don't care about the order read here
  for scr_name in "${!scripts_kv[@]}"; do
    case "${scr_name}" in
      on_boot)
        ;;
      on_os_load)
        ;;
      check_kmod)
        if [[ "$(brp_json_has_field "${3}" 'kmods')" -ne '1' ]]; then
          mrp_validate_ext_recipe_fail "${3}" "${1}" "${2}" 'recipe contains check_kmod script without any kmods defined'
          return 1
        fi
        ;;
      *) pr_warn "Extension (id: %s) recipe for %s loaded from %s looks suspicious. It defines unknown script type %s" \
                 "${1}" "${2}" "${3}" "${scr_name}"
         ;;
       esac
  done

  return 0
}

# Args: $1 URL
# Return: path to a temp file on exit=0
# Exit: 0 on exit, any other positive number indicates error
mrp_fetch_new_ext_index()
{

  readonly URL="${1}"
  local MRP_TMP_IDX="${RPT_EXTS_DIR}/_new_ext_index.tmp_json"
  rm "${MRP_TMP_IDX}" &> /dev/null

  if [ ${URL::1} == "#" ]; then
    pr_warn "Index file copied locally from %s to %s" "${URL}" "${MRP_TMP_IDX}"
    brp_cp_flat "${URL:1}" "${MRP_TMP_IDX}"
  else
    pr_dbg "Index is remote - getting from %s to %s" "${URL}" "${MRP_TMP_IDX}"
    rpt_download_remote "${URL}" "${MRP_TMP_IDX}" 1
  fi

  echo "${MRP_TMP_IDX}"
}

# Args:
#   $1 ID of the extension
#   $2 platform code
# Exit:
#   0: success
#   1: error occurred (message will be printed)
mrp_fetch_new_ext_recipe()
{
  pr_dbg "Fetching new recipe for extension %s and platform %s" "${1}" "${2}"

  if ! mrp_validate_platform_id "${2}"; then # extension ID will be verified by mrp_get_existing_index_file
    pr_err "Platform ID %s is not valid" "${2}"
    return 1
  fi

  local index_file;
  index_file=$(mrp_get_existing_index_file "${1}")
  if [ $? -ne 0 ]; then
    pr_err "Failed to load index file for extension %s - see errors above for details" "${1}"
    return 1
  fi

  local recipe_url;
  recipe_url=$(brp_json_get_field "${index_file}" "releases.${2}" 1)
  if [[ $? -ne 0 ]] || [[ "${recipe_url}" == 'null' ]]; then
    pr_warn "Failed to get recipe for %s try fallback to \"_\"" "${2}"
    recipe_url=$(brp_json_get_field "${index_file}" "releases._" 1)
    if [[ $? -ne 0 ]] || [[ "${recipe_url}" == 'null' ]]; then
      pr_err "The extension %s was found. However, the extension index has no recipe for %s platform. It may not be" "${1}" "${2}"
      pr_err "supported on that platform, or author didn't updated it for that platform yet. You can try running"
      pr_err "\"%s update\" to refresh indexes for all extensions manually. Below are the currently known information about" "${MRP_SRC_NAME}"
      pr_err "the extension stored locally:"
      mrp_show_ext_info "${1}"
      return 1
    fi
  fi

  local mrp_tmp_rcp="${RPT_EXTS_DIR}/_ext_new_rcp.tmp_json"
  rm "${mrp_tmp_rcp}" &> /dev/null

  rpt_download_remote "${recipe_url}" "${mrp_tmp_rcp}" 1
  brp_json_validate "${mrp_tmp_rcp}" # validate JSON *file*, not its format/semantic

  echo "${mrp_tmp_rcp}"
}

# Gets recipe file for an extension (if exists)
# The file path returned is guaranteed to be a valid recipe file
#
# Args:
#   $1 ID of the extension
#   $2 Platform code
# Return: file path (if exit=0)
# Exit:
#   0 - success
#   1 - invalid values passed (syntax error)
#   2 - recipe not found
#   3 - recipe semantic validation failure (id, json struct, json semantic, etc)
mrp_get_existing_recipe_file_path()
{
  if ! mrp_validate_id "${1}"; then
    return 1
  fi

  local RCP_FILE="${RPT_EXTS_DIR}/${1}/${2}/${2}.json"
  if [ ! -r "${RCP_FILE}" ]; then
    return 2
  fi

  if ! mrp_validate_recipe_file "${1}" "${2}" "${RCP_FILE}"; then
    return 3
  fi

  echo "${RCP_FILE}"
  return 0
}

# Args: $1 extension id [optional]
__action_info()
{
  if [[ "$#" -gt 1 ]]; then
    pr_crit "\"%s info\" expected 0 or 1 argument - got %d. See \"%s help\" for details" "${MRP_SRC_NAME}" "${#}" "${MRP_SRC_NAME}"
  fi

  if [[ "$#" -eq 1 ]]; then
    mrp_show_ext_info "${1}"
    return
  fi

  local -a extensions
  mrp_get_all_extensions extensions
  for ext_id in ${extensions[@]+"${extensions[@]}"}; do
    mrp_show_ext_info "${ext_id}"
  done
}

# Args: $1 URL to index
__action_add()
{
  if [[ "$#" -ne 1 ]]; then
    pr_crit "\"%s add\" expected 1 argument - got %d. See \"%s help\" for details" "${MRP_SRC_NAME}" "${#}" "${MRP_SRC_NAME}"
  fi

  pr_process "Adding new extension from %s" "${1}"

  local tmp_idx_file;
  tmp_idx_file=$(mrp_fetch_new_ext_index "${1}")
  if [[ $? -ne 0 ]]; then
    pr_crit "Failed to add \"%s\" as an extension:\n\n%s\n", "${1}" "${tmp_idx_file}"
  fi

  if ! mrp_validate_index_file "${tmp_idx_file}" "${1}"; then
    pr_crit "The index file for %s extension is invalid - please report that to the extension maintainer" "${1}"
  fi

  ext_id=$(brp_json_get_field "${tmp_idx_file}" 'id')
  if [[ $? -ne 0 ]]; then
    pr_crit "Failed to get ID from extension index file downloaded from \"%s\":\n\n%s\n", "${1}" "${ext_id}"
  fi

  # before we even validate new file we need to check if a given extension exists maybe
  local IDX_FILE="${RPT_EXTS_DIR}/${ext_id}/${ext_id}.json"
  if [[ -e "${IDX_FILE}" ]]; then
    pr_crit "Extension is already added (index exists at %s). For more info use \"%s info %s\"" \
            "${IDX_FILE}" "${MRP_SRC_NAME}" "${ext_id}"
  fi

  local THIS_EXT_DIR="${RPT_EXTS_DIR}/${ext_id}"
  if [[ -e "${THIS_EXT_DIR}" ]]; then
    pr_crit "Extension %s is damaged. Its index does NOT exists at %s but its folder DOES at %s" \
            "${ext_id}" "${IDX_FILE}" "${THIS_EXT_DIR}"
  fi

  brp_mkdir "${THIS_EXT_DIR}"
  brp_cp_flat "${tmp_idx_file}" "${IDX_FILE}"
  "${RM_PATH}" "${tmp_idx_file}" || pr_warn "Failed to remove temp file %s" "${tmp_idx_file}"

  pr_process_ok
  mrp_show_ext_info "${ext_id}"
}

# Args: $1 id of the extension
__action_remove()
{
  if [[ "$#" -ne 1 ]]; then
    pr_crit "\"%s remove\" expected 1 argument - got %d. See \"%s help\" for details" "${MRP_SRC_NAME}" "${#}" "${MRP_SRC_NAME}"
  fi

  local idx_file;
  idx_file="$(mrp_get_existing_index_file "${1}")" # id will be validated here [to prevent touching random files]
  if [[ $? -ne 0 ]]; then
    pr_crit "Extension cannot be removed due to previous errors"
  fi

  if ! "${RM_PATH}" -rf "${RPT_EXTS_DIR}/${1}"; then
    pr_crit "Failed to remove %s extension directory" "${1}"
  fi

  pr_info "Extension %s has been removed" "${1}"
}

# Args: $1 extension ID | $2 URL to index
__action_force_add()
{
  if [[ "$#" -ne 2 ]]; then
    pr_crit "\"%s force_add\" expected 2 arguments - got %d. See \"%s help\" for details" "${MRP_SRC_NAME}" "${#}" "${MRP_SRC_NAME}"
  fi

  local index_file;
  index_file=$(mrp_get_existing_index_file "${1}" 1)
  local index_out=$?

  ##   0 - success
  ##   1 - parameters passed are invalid
  ##   2 - file not found
  ##   3 - semantic validation failure (json struct, json semantic, etc)

  case $index_out in
    0) # index was found & loaded correctly
        pr_dbg "Extension %s is installed, checking URL" "${1}"
        local index_url=$(brp_json_get_field "${index_file}" "url")
        if [[ "${index_url}" != "${2}" ]]; then
          pr_info "Reinstalling extension %s as its index location changed from %s to %s" "${1}" "${index_url}" "${2}"
          __action_remove "${1}"
          __action_add "${2}"
        else
          pr_info "Extension %s is already installed from %s" "${1}" "${index_url}"
        fi
        ;;

     1)
        pr_crit "Extension ID \"%s\" is invalid - see above for details" "${1}"
        ;;

     2) # not found/not installed
        __action_add "${2}"
        ;;

     3) # damaged
        pr_warn "Extension %s is damaged - reinstalling from %s"
        __action_remove "${1}"
        __action_add "${2}"
        ;;
     *)
       pr_crit "Unknown error #%d occurred while loading extension %s index. Please report this as a bug." \
               "${index_out}" "${1}"
  esac

}

# Args: $1 list of extensions [optional, if not specified it will cleanup all]
__action_cleanup()
{
  if [[ "$#" -gt 1 ]]; then
    pr_crit "\"%s cleanup\" expected 0 or 1 argument - got %d. See \"%s help\" for details" "${MRP_SRC_NAME}" "${#}" "${MRP_SRC_NAME}"
  fi

  local -a extensions
  if [[ -z "${1+0}" ]]; then # no extensions list passed - use all
    pr_dbg "No extensions list passed - getting all"
    mrp_get_all_extensions extensions
  else # passed list of extensions - split them (we don't need to verify if they exist - we will try to read them anyway)
    pr_dbg "Extensions list passed - splitting"
    rpt_text_to_array ',' "${2}" extensions
  fi

  local failed=0
  for ext_id in ${extensions[@]+"${extensions[@]}"}; do
    pr_process "Removing all platform files for %s extension" "${ext_id}"
    "${RM_PATH}" -rf "${RPT_EXTS_DIR}/${ext_id}/*" || pr_crit "Failed to cleanup extension %s" "${ext_id}"
    pr_process_ok
  done
}

# Called to error-out from recipe fill-in which failed
#
# Args: $1 platform dir to clean | $2 extension id | $3 platform id | $4 error
mrp_fill_recipe_fail()
{
  pr_err "Recipe file for extension %s platform %s is logically invalid - %s. You SHOULD contact the extension packer to report that (see below)" \
         "${2}" "${3}" "${4}"
  mrp_show_ext_info "${ext_id}"

  pr_dbg "Cleaning up %s" "${1}"
  "${RM_PATH}" -rf "${1}"
  if [[ $? -ne 0 ]]; then
    pr_crit "Failed to delete %s after failed recipe fill attempt - please delete it manually"
  fi
}

# Takes a new recipe, nukes old data for given ext+platform and downloads everything from the recipe
# It's assumed that the recipe passed here is semantically valid and matches the platform/extension. This function will
# always leave the directory for ext+platform in a valid state (or nuke it)
#
# Args: $1 extension id | $2 platform id | $3 path to recipe file to use [probably freshly downloaded]
mrp_fill_recipe()
{
  local ext_id="${1}"
  local platform_id="${2}"
  local tmp_rcp_file="${3}"
  local platform_rcp_file;
  local platform_dir;

  pr_info "Filling-in newly downloaded recipe for extension %s platform %s" "${ext_id}" "${platform_id}"

  # prepare new directory for the extension+platform combo
  platform_dir="${RPT_EXTS_DIR}/${ext_id}/${platform_id}"
  pr_dbg "Platform dir for extension %s platform %s is %s" "${ext_id}" "${platform_id}" "${platform_dir}"
  if [[ -d "${platform_dir}" ]]; then # we don't really care if the recipe is old or broken - if it's there nuke it
    pr_dbg "Removing old platform dir %s" "${platform_dir}"
    "${RM_PATH}" -rf "${RPT_EXTS_DIR}/${ext_id}/${platform_id}/"
    if [[ $? -ne 0 ]]; then
      pr_crit "Failed to delete %s while preparing to update extension %s for %s platform - try deleting it manually?" \
              "${platform_dir}" "${ext_id}" "${platform_id}"
    fi
  fi
  pr_dbg "Creating new platform dir %s" "${platform_dir}"
  brp_mkdir "${platform_dir}"
  platform_rcp_file="${platform_dir}/${platform_id}.json"

  pr_dbg "Copying recipe %s to its permanent place in %s" "${tmp_rcp_file}" "${platform_rcp_file}"
  brp_cp_flat "${tmp_rcp_file}" "${platform_rcp_file}"

  local -a file_idxs;
  local -A file_meta;
  local platform_fpatch;
  brp_json_get_keys "${platform_rcp_file}" 'files' file_idxs
  for file_idx in "${file_idxs[@]}"; do
    pr_dbg "Processing file entry #%d" "${file_idx}"

    brp_read_kv_to_array "${platform_rcp_file}" "files[${file_idx}]" file_meta # todo: move that to recipe validation
    for fm_key in name url sha256 packed; do #todo here also check the file name in recipe so there are no rogue chars
      if [[ -z "${file_meta[${fm_key}]+0}" ]]; then
        mrp_fill_recipe_fail "${platform_dir}" "${ext_id}" "${platform_id}" "no [${fm_key}] key for file at idx #${file_idx}"
        return 1
      fi
    done

    platform_fpatch="${platform_dir}/${file_meta[name]}"
    if [[ -e "${platform_fpatch}" ]]; then # this can happen if two file records define the same name OR previous packed archive had that file
      mrp_fill_recipe_fail "${platform_dir}" "${ext_id}" "${platform_id}" "file ${file_meta[name]} already exists while processing idx #${file_idx} (duplicated name?)"
      return 1
    fi

    rpt_download_remote "${file_meta[url]}" "${platform_fpatch}" 0
    if [[ $? -ne 0 ]]; then
      mrp_fill_recipe_fail "${platform_dir}" "${ext_id}" "${platform_id}" "failed to download file ${file_meta[url]}"
      return 1
    fi

    brp_verify_file_sha256 "${platform_fpatch}" "${file_meta[sha256]}" 1
    if [[ $? -ne 0 ]]; then
      mrp_fill_recipe_fail "${platform_dir}" "${ext_id}" "${platform_id}" "failed to verify file ${file_meta[url]}"
      return 1
    fi

    if [[ "${file_meta[packed]}" == 'true' ]]; then
      pr_dbg "File %s is marked as a packed archive - unpacking" "${platform_fpatch}"
      brp_unpack_tar_flat "${platform_fpatch}" "${platform_dir}/" 0
      if [ $? -ne 0 ]; then
        mrp_fill_recipe_fail "${platform_dir}" "${ext_id}" "${platform_id}" "file download ${file_meta[url]} cannot be unpacked"
        return 1
      fi
       # this is critical as we don't want the archive accidentally landing in the final image
      "${RM_PATH}" "${platform_fpatch}" || pr_crit "Failed to delete archive %s"
    fi
  done

  # at this point we've got all files - now we need to check that all kernel modules & scripts defined are actually there
  local -A files_kv;
  if [[ "$(brp_json_has_field "${platform_rcp_file}" 'kmods')" -eq 1 ]]; then # not all extensions must have *.ko
    pr_dbg "Extension has kernel modules - checking"
    brp_read_kv_to_array "${platform_rcp_file}" "kmods" files_kv
    for ko_name in "${!files_kv[@]}"; do
      platform_fpatch="${platform_dir}/${ko_name}"
      pr_dbg "Checking if file exists at %s" "${platform_fpatch}"

      if [[ ! -f "${platform_fpatch}" ]]; then # it HAS TO BE a normal file, it's deliberate here
        mrp_fill_recipe_fail "${platform_dir}" "${ext_id}" "${platform_id}" "recipe defines kmod ${ko_name} *FILE* which doesn't exist after all files entries are processed"
        return 1
      fi
    done
  fi
  if [[ "$(brp_json_has_field "${platform_rcp_file}" 'scripts')" -eq 1 ]]; then # not all extensions must have scripts
    pr_dbg "Extension has scripts - checking"
    brp_read_kv_to_array "${platform_rcp_file}" "scripts" files_kv
    for script_action in "${!files_kv[@]}"; do
      platform_fpatch="${platform_dir}/${files_kv[$script_action]}"
      pr_dbg "Checking if file for action %s exists at %s" "${script_action}" "${platform_fpatch}"

      if [[ ! -f "${platform_fpatch}" ]]; then # it HAS TO BE a normal file, it's deliberate here
        mrp_fill_recipe_fail "${platform_dir}" "${ext_id}" "${platform_id}" "recipe defines ${files_kv[$script_action]} *FILE* for ${script_action} script action which doesn't exist after all files entries are processed"
        return 1
      fi
    done
  fi

  pr_info "Successfully processed recipe for extension %s platform %s" "${ext_id}" "${platform_id}"
}

# Args: $1 list of extensions [optional, if not specified it will update all]
__action_update()
{
  if [[ "$#" -gt 1 ]]; then
    pr_crit "\"%s update\" expected 0 or 1 argument - got %d. See \"%s help\" for details" "${MRP_SRC_NAME}" "${#}" "${MRP_SRC_NAME}"
  fi

  local -a extensions
  if [[ -z "${1+0}" ]]; then # no extensions list passed - use all
    pr_dbg "No extensions list passed - getting all"
    mrp_get_all_extensions extensions
  else # passed list of extensions - split them (we don't need to verify if they exist - we will try to read them anyway)
    pr_dbg "Extensions list passed - splitting"
    rpt_text_to_array ',' "${1}" extensions
  fi

  local index_url
  local cur_index_file
  local cur_index_sha256
  local new_index_file
  local new_index_sha256
  local failed=0
  for ext_id in ${extensions[@]+"${extensions[@]}"}; do
    pr_process "Updating %s extension" "${ext_id}"
    cur_index_file=$(mrp_get_existing_index_file "${ext_id}")
    if [ $? -ne 0 ]; then
      pr_err "Failed to load index file for extension %s - see errors above for details" "${ext_id}"
      return 1
    fi

    index_url=$(brp_json_get_field "${cur_index_file}" 'url')
    new_index_file=$(mrp_fetch_new_ext_index "${index_url}")
    if [[ $? -ne 0 ]]; then # so we cannot get new index
      pr_err "Failed to download index file for %s extension from %s" "${ext_id}" "${index_url}"
      ((failed=failed+1))
      continue
    fi

    # now we know we have the new [valid] recipe file (since previous if allowed us to get here)
    pr_dbg "Got new index for %s from %s to %s" "${ext_id}" "${index_url}" "${new_index_file}"

    cur_index_sha256=$(rpt_get_file_sha256 "${cur_index_file}")
    if [[ $? -ne 0 ]]; then
      pr_crit "Failed to hash old index file %s for comparison:\n\n%s" "${cur_index_file}" "${cur_index_sha256}"
    fi

    new_index_sha256=$(rpt_get_file_sha256 "${new_index_file}")
    if [[ $? -ne 0 ]]; then
      pr_crit "Failed to hash new index file %s for comparison:\n\n%s" "${new_index_file}" "${new_index_sha256}"
    fi

    pr_dbg "Current idx SHA256=%s vs new SHA256=%s" "${cur_index_sha256}" "${new_index_sha256}"
    if [[ "${cur_index_sha256}" == "${new_index_sha256}" ]]; then
      pr_info "Extension %s index is already up to date" "${ext_id}"
      "${RM_PATH}" "${new_index_file}" || pr_warn "Failed to remove temp file %s" "${new_index_file}"
      continue
    fi

    # todo: for now we can invalidate all platforms but properly we shouldn't invalidate if the recipe URLs are the same
    # However, this is tricky as we need to compare list of platforms as well... it's VERY ANNOYING to do it in bash
    "${RM_PATH}" -rf "${RPT_EXTS_DIR}/${ext_id}/*/"
    "${MV_PATH}" "${new_index_file}" "${cur_index_file}" || pr_crit "Failed to install new index to %s" "${cur_index_file}"
  done

  if [[ "${failed}" -eq 0 ]]; then
    pr_process_ok
  else
    pr_err "%d extensions failed to update" "${failed}"
  fi
}

# Args: $1 platform id | $2 extensions ID list [optional]
__action__update_platform_exts()
{
  if [[ "$#" -lt 1 ]] || [[ "$#" -gt 2 ]]; then
    pr_crit "\"%s _update_platform_exts\" expected 1-2 arguments - got %d. See \"%s help\" for details" "${MRP_SRC_NAME}" "${#}" "${MRP_SRC_NAME}"
  fi

  pr_process "Updating %s platforms extensions" "${1}"

  local platform_id="${1}"
  if ! mrp_validate_platform_id "${platform_id}"; then
    pr_err "Platform ID %s is not valid" "${platform_id}"
    return 1
  fi

  local -a extensions
  if [[ -z "${2+0}" ]]; then # no extensions list passed - use all
    pr_dbg "No extensions list passed - getting all"
    mrp_get_all_extensions extensions
  else # passed list of extensions - split them (we don't need to verify if they exist - we will try to read them anyway)
    pr_dbg "Extensions list passed - splitting"
    rpt_text_to_array ',' "${2}" extensions
  fi


  local cur_recipe_file;
  local cur_recipe_sha256;
  local cur_recipe_result;
  local new_recipe_file;
  local new_recipe_sha256;
  local platform_dir;
  local hard_fail=0;
  for ext_id in ${extensions[@]+"${extensions[@]}"}; do
    pr_dbg "Processing extension %s for %s platform" "${ext_id}" "${platform_id}"
    if ! mrp_has_extension "${ext_id}"; then
      pr_crit "Extension \"%s\" is not added/installed - did you misspell the name or forgot to do \"%s add <URL>\" first?" \
              "${ext_id}" "${MRP_SRC_NAME}"
    fi

    cur_recipe_file=$(mrp_get_existing_recipe_file_path "${ext_id}" "${platform_id}")
    cur_recipe_result=$?
    if [[ "${cur_recipe_result}" -eq 1 ]]; then
      pr_crit "<BUG> Failed to read current recipe failure due to call error" # this is some bug in validation
    else
      pr_dbg "Attempted to get existing recipe - call resulted in code #%d" "${cur_recipe_result}"
    fi

    #todo: check if ok & recently checked and skip over the whole checking below (to not re-download receipt all the time)

    new_recipe_file=$(mrp_fetch_new_ext_recipe "${ext_id}" "${platform_id}")
    if [[ $? -ne 0 ]]; then # so we cannot get the recipe
      case "${cur_recipe_result}" in
        0) pr_warn "Failed to update recipe for %s extension for platform %s. The script will try to continue with the old" "${ext_id}" "${platform_id}"
           pr_warn "recipe. If the old recipe still works at worst you will miss on an update. Contact the packer of the"
           pr_warn "extension if this problem persists (displayed below)"
           hard_fail=0
           ;;
        2) pr_err "Failed to update recipe for %s extension for platform %s. The script will terminate as you do not" "${ext_id}" "${platform_id}"
           pr_err "have previously downloaded recipe which can be used if download fails. Try again later. If problem"
           pr_err "persists contact the extension packer for support (displayed below)"
           hard_fail=1
           ;;
        3) pr_err "Failed to update recipe for %s extension for platform %s. The script will terminate as your existing" "${ext_id}" "${platform_id}"
           pr_err "recipe is damaged and cannot be used if download fails. Try again later. If problem persists"
           pr_err "contact the extension packer for support (displayed below)"
           hard_fail=1
           ;;
        *) pr_crit "Unhandled cur_recipe_result exception #%d" "${cur_recipe_result}"
           ;;
      esac

      mrp_show_ext_info "${ext_id}"
      if [[ "${hard_fail}" -eq 1 ]]; then
        pr_crit "Cannot continue due to previous errors (see above)"
      fi

      continue # if there's no new recipe we cannot download any files or anything - we assume offline operation
    fi

    # now we know we have the new [valid] recipe file (since previous if allowed us to get here)
    pr_dbg "Got new recipe to %s" "${new_recipe_file}"

    if [[ "${cur_recipe_result}" -eq 0 ]]; then # we have the current one so we can try to check if it's the same
      pr_dbg "Both new (%s) and old (%s) recipes exist - comparing" "${new_recipe_file}" "${cur_recipe_file}"

      cur_recipe_sha256=$(rpt_get_file_sha256 "${cur_recipe_file}")
      if [[ $? -ne 0 ]]; then
        pr_crit "Failed to hash old recipe file %s for comparison:\n\n%s" "${cur_recipe_file}" "${cur_recipe_sha256}"
      fi

      new_recipe_sha256=$(rpt_get_file_sha256 "${new_recipe_file}")
      if [[ $? -ne 0 ]]; then
        pr_crit "Failed to hash new recipe file %s for comparison:\n\n%s" "${new_recipe_file}" "${new_recipe_sha256}"
      fi

      if [[ "${cur_recipe_sha256}" == "${new_recipe_sha256}" ]]; then
        pr_info "Extension %s for %s platform is already up to date" "${ext_id}" "${platform_id}"
        "${RM_PATH}" "${new_recipe_file}" || pr_warn "Failed to remove temp file %s" "${new_recipe_file}"
        continue
      fi

    fi

    pr_dbg "Previous recipe is not usable (outdated, broken, or missing) - processing newly downloaded one"
    # now we know know that either ext is out of date or something is wrong with the current recipe (see previous if)
    # either way we need to cleanup old one and simply get new one
    # but just before we do that let's verify new recipe - if there's a new one and we confirmed it's different (or the
    # old one is not found/broken) it should explode and user should not be able to complete update
    if ! mrp_validate_recipe_file "${ext_id}" "${platform_id}" "${new_recipe_file}"; then
      pr_err "Failed to update recipe for %s extension for platform %s. The script will terminate as the new recipe is" "${ext_id}"
      pr_err "available but it's invalid. Try again later. If problem persists contact the extension packer for support"
      pr_err "(displayed below)"
      mrp_show_ext_info "${ext_id}"
      pr_crit "Cannot continue due to previous errors (see above)"
    fi

    mrp_fill_recipe "${ext_id}" "${platform_id}" "${new_recipe_file}"
    "${RM_PATH}" "${new_recipe_file}" || pr_warn "Failed to remove temp file %s" "${new_recipe_file}"

  done

  pr_process_ok
}

__action__dump_exts()
{
  if [[ "$#" -lt 2 ]] || [[ "$#" -gt 3 ]]; then
    pr_crit "\"%s _dump\" expected 2-3 arguments - got %d. See \"%s help\" for details" "${MRP_SRC_NAME}" "${#}" "${MRP_SRC_NAME}"
  fi

  local platform_id="${1}"
  local dump_dir="${2}"
  pr_process "Dumping %s platform extensions to %s" "${platform_id}" "${dump_dir}"

  if ! mrp_validate_platform_id "${platform_id}"; then
    pr_err "Platform ID %s is not valid" "${platform_id}"
    return 1
  fi

  if [ ! -d "${dump_dir}" ] || [[ ! -z "$(${LS_PATH} -A "${dump_dir}")" ]]; then
    pr_err "%s is not an **existing and empty** directory" "${dump_dir}"
    return 1
  fi

  local -a extensions
  if [[ -z "${3+0}" ]]; then # no extensions list passed - use all
    pr_dbg "No extensions list passed - getting all"
    mrp_get_all_extensions extensions
  else # passed list of extensions - split them (we don't need to verify if they exist - we will try to read them anyway)
    pr_dbg "Extensions list passed - splitting"
    rpt_text_to_array ',' "${3}" extensions
  fi

  local platform_dir;
  local dump_ext_di;
  local platform_rcp_file;
  local target_extensions; # list of extensions (space-separated) in order of how they should be loaded by the loader
  local -A target_vars; # dump of variables for the script dumped to the final image to load everything in order
  local -a files_keys;
  local -A files_kv;
  local ext_counter=-1;
  local kmod_counter;
  for ext_id in ${extensions[@]+"${extensions[@]}"}; do
    ((ext_counter++))
    platform_dir="${RPT_EXTS_DIR}/${ext_id}/${platform_id}"
    dump_ext_di="${dump_dir}/${ext_id}"
    pr_dbg "Dumping platform %s extension %s from %s to %s" "${platform_id}" "${ext_id}" "${platform_dir}" "${dump_ext_di}"

    platform_rcp_file=$(mrp_get_existing_recipe_file_path "${ext_id}" "${platform_id}")
    if [[ $? -ne 0 ]]; then
      pr_crit "Failed to dump extension %s for platform %s as its recipe file cannot be retrieved. Isn't the extension misspelled or not supported on that platform?" \
              "${ext_id}" "${platform_id}"
    fi

    brp_cp_flat "${platform_dir}" "${dump_ext_di}" # theoretically this will suffice, but we can cleanup a bit
    "${RM_PATH}" "${dump_ext_di}/${platform_id}.json" || true #this may safely fail (it shouldn't thou)
    "${FIND_PATH}" "${dump_ext_di}" -type d -empty -delete # delete all empty dirs which may resulted from unpacking

    # Handle kernel extensions (if any)
    target_extensions+="${ext_id} " # POSIX shells don't care about leading/trailing whitespaces in IFS
    if [[ "$(brp_json_has_field "${platform_rcp_file}" 'kmods')" -eq 1 ]]; then # not all extensions must have *.ko
      pr_dbg "Extension has kernel modules - dumping"
      brp_read_ordered_kv "${platform_rcp_file}" "kmods" files_keys files_kv
      kmod_counter=0
      for ko_name in ${files_keys[@]+"${files_keys[@]}"}; do
        pr_dbg "Adding %s kmod (args: %s) from %s extension" "${ko_name}" "${files_kv[${ko_name}]}" "${ext_id}"
        target_vars["EXT_${ext_counter}_kmod_files"]+="${ko_name} "
        if [[ ! -z "${files_kv[${ko_name}]}" ]]; then
          target_vars["EXT_${ext_counter}_kmod_${kmod_counter}_args"]="${files_kv[${ko_name}]}"
        fi
        ((kmod_counter++))
      done
    fi

    # Handle scripts (if any)
    if [[ "$(brp_json_has_field "${platform_rcp_file}" 'scripts')" -eq 1 ]]; then # not all extensions must have scripts
      pr_dbg "Extension has scripts - dumping"
      brp_read_kv_to_array "${platform_rcp_file}" "scripts" files_kv # we don't care about the order read here
      for script_action in "${!files_kv[@]}"; do
        pr_dbg "Adding %s script for action %s from %s extension" \
               "${script_action}" "${files_kv[${script_action}]}" "${ext_id}"

        target_vars["EXT_${ext_counter}_scripts_${script_action}"]="${files_kv[${script_action}]}"
      done
    fi
  done

  # Copy bootstrap files
  local target_exec_scr_path="${dump_dir}/exec.sh"
  brp_cp_flat "include/loader-ext/readme.txt_" "${dump_dir}/__README__.txt"
  brp_cp_flat "include/loader-ext/target_exec.sh_" "${target_exec_scr_path}"
  rpt_make_executable "${target_exec_scr_path}"

  # Fill-in bootstrap script
  local ext_data='';
  brp_replace_token_with_text "${target_exec_scr_path}" '@@@PLATFORM_ID@@@' "PLATFORM_ID=\"${platform_id}\""
  brp_replace_token_with_text "${target_exec_scr_path}" '@@@EXTENSION_IDS@@@' "EXTENSION_IDS=\"${target_extensions}\""
  for var_name in "${!target_vars[@]}"; do
    ext_data+="${var_name}=\"${target_vars[${var_name}]}\""$'\n'
  done
  pr_dbg "Prepared EXT_DATA:\n%s" "${ext_data}"
  brp_replace_token_with_text "${target_exec_scr_path}" '@@@EXT_DATA@@@' "${ext_data}"

}

__action_help ()
{
  echo "  RedPill Extensions Manager  "
  echo "=============================="
  echo "Usage: ${MRP_SRC_NAME} <action> [arguments/options]"
  echo "------------------------------"
  echo "Actions intended for users:"
  echo "    info"
  echo "      Purpose: Gets information about an extension (or all of them)"
  echo "      Arguments:"
  echo "        [EXT_ID]: id of the extension; optional (if not specified it will list all)"
  echo "      Examples:"
  echo "        ${MRP_SRC_NAME} info                        # gets info about all installed"
  echo "        ${MRP_SRC_NAME} info thethorgroup.virtio    # gets info about thethorgroup.virtio"
  echo ""
  echo "    add"
  echo "      Purpose: Adds new extension. If exists this action will fail."
  echo "      Arguments:"
  echo "        URL: the url to an index file; argument is mandatory"
  echo "      Example: ${MRP_SRC_NAME} add https://example.tld/sample-ext/rpext-index.json"
  echo ""
  echo "    force_add"
  echo "      Purpose: Adds new extension. If it exists url is verified to be the same, if not extension is removed"
  echo "               and reinstalled from the URL provided. If extension exists with the same URL nothing happens."
  echo "      Arguments:"
  echo "        EXT_ID: ID of the extension; argument is mandatory"
  echo "        URL: the url to an index file; argument is mandatory"
  echo "      Example: ${MRP_SRC_NAME} force_add example-dev.sample-ext https://example.tld/sample-ext/rpext-index.json"
  echo ""
  echo "    cleanup"
  echo "      Purpose: Remove all platform (cache) files for an extension. If it does not exists this action will fail."
  echo "      Arguments:"
  echo "        [EXT_IDS]: comma-separated ordered list of extensions to cleanup; optional"
  echo "      Examples:"
  echo "        ${MRP_SRC_NAME} cleanup thethorgroup.virtio,thethorgroup.boot-wait  # cleanup only 2 extensions listed"
  echo "        ${MRP_SRC_NAME} cleanup                                             # cleanup all extensions"
  echo ""
  echo "    remove"
  echo "      Purpose: Remove an extension and all its platform files. If it does not exists this action will fail."
  echo "      Arguments:"
  echo "        EXT_ID: if of the extension to remove; argument is mandatory"
  echo "      Example: ${MRP_SRC_NAME} remove badcoder.unstable-ext"
  echo ""
  echo "    update"
  echo "      Purpose: Updates information about extensions; this will NOT download platform extensions itself"
  echo "      Arguments:"
  echo "        [EXT_IDS]: comma-separated ordered list of extensions to update; optional"
  echo "      Examples:"
  echo "        ${MRP_SRC_NAME} update thethorgroup.virtio,thethorgroup.boot-wait  # update only 2 extensions listed"
  echo "        ${MRP_SRC_NAME} update                                             # update all extensions installed"
  echo ""
  echo "    help"
  echo "      Purpose: Helping you! (you're reading it right now)"
  echo "      Arguments: takes no arguments"
  echo ""
  echo "------------------------------"
  echo "Actions intended for usage in scripts:"
  echo "    _update_platform_exts"
  echo "      Purpose: Checks all extensions added expecting the platform to be supported; updates all recipes & files"
  echo "      Arguments:"
  echo "        PLATFORM_CODE: id of the platform, e.g. ds3615xs_25556"
  echo "        [EXT_IDS]: comma-separated ordered list of extensions to include; optional"
  echo ""
  echo "    _dump_exts"
  echo "      Purpose: Dump all extensions, their scripts + loader script; used by the redpill-load during image build"
  echo "      Arguments:"
  echo "        PLATFORM_CODE: id of the platform, e.g. ds3615xs_25556; required"
  echo "        DST_DIR: where to save all files; required"
  echo "        [EXT_IDS]: comma-separated ordered list of extensions to include; optional"
  exit 1
}

# Checks if the extensions directory exists and creates an empty one if it doesn't so other things don't break
__housekeep_init()
{
  if [[ -d "${RPT_EXTS_DIR}" ]]; then
    return 0
  fi

  pr_warn "Your extensions directory %s doesn't exists - creating" "${RPT_EXTS_DIR}"
  brp_mkdir "${RPT_EXTS_DIR}"
}


readonly ACTION_NAME=${1:-"help"}
case "${ACTION_NAME}" in
    "" | "-h" | "--help")
        __action_help
        ;;
    *)
        shift
        __housekeep_init
        __action_"${ACTION_NAME}" "$@"
        if [ $? = 127 ]; then
            echo "You've called \"${MRP_SRC_NAME} ${ACTION_NAME}\" - this action is unknown, see help below"
            __action_help
        fi
        ;;
esac
