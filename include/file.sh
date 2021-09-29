#!/usr/bin/env bash
set -u

# Resolves array relative path to a file
#
# Args:
#   $1 raw file path
#   $2 reference to a K=>V map of variables; it should contain "@@@_DEF_@@@" entry for non-variabled paths
brp_expand_var_path()
{
  local -n __vars_map=$2
  local file_path="${1}"

  if [[ "${1}" == /* ]]; then
    : #noop, absolute paths don't need any modifications
  elif [[ "${1}" != @@@* ]]; then
    # since path doesn't begin with a variable we just assume the default
    file_path="${__vars_map[@@@_DEF_@@@]}/${file_path}"
  else
    local var_value
    for var_name in "${!__vars_map[@]}"
    do
      var_value="${__vars_map[$var_name]}"
      file_path="${file_path/${var_name}/${var_value}}"
    done
  fi

  pr_dbg "Resolved path '${1}' to '${file_path}'"
  echo "${file_path}"
}

# Computes SHA-256 hash for a file and returns it
#
# Args: $1 file path
rpt_get_file_sha256()
{
  pr_dbg "Generating SHA-256 for %s" "${1}"

  local hash;
  local hash_res;
  hash=$("${SHA256SUM_PATH}" "${1}" | cut -d ' ' -f1)
  hash_res=$?


  echo "${hash}"
  return $hash_res
}

# Validates file
#
# Args: $1 file path | $2 expected checksum | $3 make failure non-critical [default=0]
brp_verify_file_sha256()
{
  pr_process "Verifying %s file" "${1}"

  local hash;
  hash=$(rpt_get_file_sha256 "${1}")

  if [ $? -ne 0 ]; then
    pr_process_err
    if [[ "${3:-1}" -eq 1 ]]; then
      pr_err "Failed to generate checksum for file\n\n%s" "${hash}"
    else
      pr_crit "Failed to generate checksum for file\n\n%s" "${hash}"
    fi
  fi

  if [ "$2" != "$hash" ]; then
    pr_process_err
    if [[ "${3:-1}" -ne 1 ]]; then
      pr_err "Checksum mismatch - expected %s but computed %s" "$2" "$hash"
    else
      pr_crit "Checksum mismatch - expected %s but computed %s" "$2" "$hash"
    fi
  fi

  pr_process_ok
}

# Unpacks tar-like file
#
# Args: $1 file path | $2 directory to unpack (must exist) | $3 should hard fail on error? [default=1]
brp_unpack_tar()
{
  pr_process "Unpacking %s file to %s" "${1}" "${2}"

  local output;
  output=$("${TAR_PATH}" -xf "${1}" -C "${2}" 2>&1)
  if [ $? -ne 0 ]; then
    pr_process_err

    if [[ "${3:-1}" -ne 1 ]]; then
      pr_err "Failed to unpack tar\n\n%s" "${output}"
      return 1
    else
      pr_crit "Failed to unpack tar\n\n%s" "${output}"
    fi
  fi

  pr_process_ok
}

# Unpacks tar-like file without any folder structure
#
# Args: $1 file path | $2 directory to unpack (must exist) | $3 should hard fail on error? [default=1]
brp_unpack_tar_flat()
{
  pr_process "Unpacking files from %s to %s" "${1}" "${2}"

  local output;
  # Lovely hack by ford: https://stackoverflow.com/a/14295908
  #todo: some older tar versions leave empty directories... there's no elegant way to get rid of them ;<
  output=$("${TAR_PATH}" -xf "${1}" --transform='s/.*\///' -C "${2}" 2>&1)
  if [ $? -ne 0 ]; then
    pr_process_err

    if [[ "${3:-1}" -ne 1 ]]; then
      pr_err "Failed to unpack tar\n\n%s" "${output}"
      return 1
    else
      pr_crit "Failed to unpack tar\n\n%s" "${output}"
    fi
  fi

  pr_process_ok
}

# Unpacks compressed ramdisks
#
# Args: $1 file path | $2 directory to unpack (must exist)
brp_unpack_zrd()
{
  pr_process "Unpacking %s file to %s" "${1}" "${2}"

  local output;
  output=$(cd "${2}" && "${XZ_PATH}" -dc < "${1}" 2>/dev/null | "${CPIO_PATH}" -idm 2>&1)

  # Sadly we cannot check exit code of the unpacking as xz will always error out array as ramdisks have appended
  # checksum, so we can check if something unpacked instead
  if [ "$(ls -A ${2})" ]; then
    pr_process_ok
    return
  fi

  pr_process_err
  pr_crit "Failed to unpack compressed ramdisk\n\n%s" "${output}"
}

# Repacks ramdisk into compressed archive
#
# Args: $1 output ramdisk path | $2 directory to repack
brp_pack_zrd()
{
  pr_dbg "Repacking %s to LZ %s" "${2}" "${1}"

  local output;
  output=$(cd "${2}" && "${FIND_PATH}" . 2>/dev/null | \
           cpio -o -H newc -R root:root 2>/dev/null | "${XZ_PATH}" -9 --format=lzma 2>/dev/null 1> "${1}")
  if [ $? -ne 0 ]; then
    pr_process_err
    pr_crit "Failed to repack compressed ramdisk\n\n%s" "${output}"
  fi
}

# Repacks ramdisk into flat CPIO archive
#
# This one is useful for kernels with broken unpacking routines <points fingers>
#
# Args: $1 output ramdisk path | $2 directory to repack
brp_pack_cpiord()
{
  pr_dbg "Repacking %s to CPIO %s" "${2}" "${1}"

  local output;
  output=$(cd "${2}" && "${FIND_PATH}" . 2>/dev/null | \
           cpio -o -H newc -R root:root 2>/dev/null 1> "${1}")
  if [ $? -ne 0 ]; then
    pr_crit "Failed to repack flat ramdisk\n\n%s" "${output}"
  fi
}

# Unpacks compressed (or not) linux kernel image
#
# Args: $1 packed file | $2 destination
brp_unpack_zimage()
{
  pr_process "Unpacking %s file to %s" "${1}" "${2}"

  local output;
  local log_file="${2}.log";

  output=$("${EXTRACT_VMLINUX_PATH}" "${1}" 1> "${2}" 2>"${log_file}")
  if [ $? -ne 0 ]; then
    pr_process_err
    pr_crit "Failed to unpack zImage\n\n%s" "$(cat \"${2}.log\")"
  fi

  pr_process_ok
  pr_dbg "Log file saved to %s" "${log_file}"
}

# Repacks uncompressed vmlinux image into zImage
#
# Args: $1 kernel sources | $2 unpacked vmlinux file | $3 destination for zImage
brp_repack_zimage()
{
  pr_info "Repacking \"%s\" to \"%s\" within \"%s\"" "${2}" "${3}" "${1}"

  # Make file more anonymous
  export KBUILD_BUILD_TIMESTAMP="1970/1/1 00:00:00"
  export KBUILD_BUILD_USER="root"
  export KBUILD_BUILD_HOST="localhost"
  export KBUILD_BUILD_VERSION=0

  "${REBUILD_KERNEL_PATH}" "${1}" "${2}" "${3}"

  if [ $? -ne 0 ]; then
    pr_crit "Failed to rebuild zImage, see log above"
  fi

  pr_info "Successfully created \"%s\"" "${3}"
}

# Decompresses a single gzipped file without removing the original
#
# Args: $1 source.gz | $2 destination.plain
brp_unpack_single_gz()
{
  pr_dbg "Unpacking %s to %s" "${1}" "${2}"
  "${GZIP_PATH}" --decompress --stdout "${1}" > "${2}"
  if [ $? -ne 0 ]; then
    pr_crit "Failed to unpack %s to %s" "${1}" "${2}"
  fi
}

brp_mkdir()
{
  if [[ -d "${1}" ]]; then return 0; fi

  pr_dbg "Creating directory \"%s\"" "${1}"
  "${MKDIR_PATH}" -p "${1}" || pr_crit "Failed to create \"%s\" directory" "${1}"
}

rpt_make_executable()
{
    "${CHMOD_PATH}" +x "${1}" || pr_crit "Failed to make \"%s\" executable" "${1}"
}

# Copies files while resolving all symlinks
#
# Args: $1 source file or dir | $2 destination file or dir
brp_cp_flat()
{
  pr_dbg "Copying %s to %s" "${1}" "${2}"

  local out;
  if [[ "${2: -1}" == '/' ]]; then
    brp_mkdir "${2}"
  else
    brp_mkdir "$("${DIRNAME_PATH}" "${2}")"
  fi

  out="$("${CP_PATH}" --recursive --dereference "${1}" "${2}" 2>&1)"
  if [ $? -ne 0 ]; then
    pr_process_err
    pr_crit "Failed to copy %s to %s\n\n%s" "${1}" "${2}" "${out}"
  fi
}

# Copies all files from K=>V list in JSON, resolving all symlinks with flat copy
#
# Args:
#   $1 JSON config file
#   $2 key containing SRC=>DST pairs
#   $3 reference to a map of K=>V pairs with variables for source resolution, see brp_expand_var_path()
#   $4 dst prefix
brp_cp_from_list()
{
  local -n _path_map=$3
  pr_dbg "Mass copying files from entries in %s:.%s" "${1}" "${2}"

  local -A kv_pairs;
  brp_read_kv_to_array "${1}" "${2}" kv_pairs
  for from in "${!kv_pairs[@]}"; do
    brp_cp_flat "$(brp_expand_var_path "${from}" _path_map)" "${4}/${kv_pairs[$from]}"
  done
}

# Downloads remote file to a specific file path
#
# Args: $1 URL to download from | $2 destination file | $3 hard fail on error [1 to do so]
rpt_download_remote()
{
    pr_info "Downloading remote file %s to %s" "${1}" "${2}"
    local out;
    out=$("${CURL_PATH}" --location --fail --progress-bar --retry 5 --output "${2}" "${1}")
    if [ $? -ne 0 ]; then
      if [[ "${3}" -eq 1 ]]; then
        pr_crit "Failed to download %s to %s\n\n%s" "${1}" "${2}" "${out}"
      else
        return 1
      fi
    fi
}

# Lists directories in a path
#
# Args: $1 path | $2 array to read to
rpt_list_directories()
{
  local -n __ls_list=$2

  local out;
  out=$(cd "${1}" && ls -A)
  if [[ -z "${out}" ]]; then # we need to check if directory contains anything to prevent next ls failure
    return 0
  fi

  out=$(cd "${1}" && ls -A -1 -d */ | sed 's^/^^')
  if [[ $? -ne 0 ]]; then
    pr_crit "Failed to list directories in %s\n\n%s" "${1}" "${out}"
  fi

  readarray -t __ls_list <<< "${out}"
}
