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
BRP_DEBUG=${BRP_DEBUG:-0} # whether you want to see debug messages
BRP_CACHE_DIR=${BRP_CACHE_DIR:-"$PWD/cache"} # cache directory where stuff is downloaded & unpacked
BRP_USER_CFG=${BRP_USER_CFG:-"$PWD/user_config.json"}
BRP_BUILD_DIR=${BRP_BUILD_DIR:-''} # makes sure attempts are unique; do not override this unless you're using repack
BRP_KEEP_BUILD=${BRP_KEEP_BUILD:-''} # will be set to 1 for repack method or 0 for direct
BRP_LINUX_PATCH_METHOD=${BRP_LINUX_PATCH_METHOD:-"direct"} # how to generate kernel image (direct bsp patch vs repack)
BRP_LINUX_SRC=${BRP_LINUX_SRC:-''} # used for repack method
BRP_BOOT_IMAGE=${BRP_BOOT_IMAGE:-"$PWD/ext/boot-image-template.img.gz"} # gz-ed "template" image to base final image on

# The options below are meant for debugging only. Setting them will create an image which is not normally usable
BRP_DEV_DISABLE_RP=${BRP_DEV_DISABLE_RP:-0} # when set to 1 the rp.ko will be renamed to rp-dis.ko
BRP_DEV_DISABLE_SB=${BRP_DEV_DISABLE_SB:-0} # when set to 1 the synobios.ko will be renamed to synobios-dis.ko
########################################################################################################################


##### INCLUDES #########################################################################################################
. include/log.sh # logging helpers
. include/text.sh # text manipulation
. include/runtime.sh # need to include this early so we can used date and such
. include/json.sh # json parsing routines
. include/config-manipulators.sh
. include/file.sh # file-related operations (copying/moving/unpacking etc)
. include/patch.sh # helpers for patching files using patch(1) and bspatch(1)
. include/boot-image.sh # helper functions for dealing with the boot image
########################################################################################################################

##### CONFIGURATION VALIDATION##########################################################################################

### Command line params handling
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  echo "Usage: $0 platform version <output-file>"
  exit 1
fi
BRP_HW_PLATFORM="$1"
BRP_SW_VERSION="$2"
BRP_OUTPUT_FILE="${3:-"$PWD/images/redpill-${BRP_HW_PLATFORM}_${BRP_SW_VERSION}_b$(date '+%s').img"}"

BRP_REL_CONFIG_BASE="$PWD/config/${BRP_HW_PLATFORM}/${BRP_SW_VERSION}"
BRP_REL_CONFIG_JSON="${BRP_REL_CONFIG_BASE}/config.json"

### Some config validation
if [ "${BRP_LINUX_PATCH_METHOD}" == "direct" ]; then
  BRP_BUILD_DIR=${BRP_BUILD_DIR:-"$PWD/build/$(date '+%s')"}
  BRP_KEEP_BUILD=${BRP_KEEP_BUILD:='0'}
elif [ "${BRP_LINUX_PATCH_METHOD}" == "repack" ]; then
  if [ -z ${BRP_BUILD_DIR} ]; then
    pr_crit "You've chosen \"%s\" method for patching - you must specify BRP_BUILD_DIR" "${BRP_LINUX_PATCH_METHOD}"
  fi
  BRP_KEEP_BUILD=${BRP_KEEP_BUILD:='1'}

  if [ -z ${BRP_LINUX_SRC} ]; then
    pr_crit "You've chosen \"repack\" method for patching - you must specify BRP_LINUX_SRC" "${BRP_LINUX_PATCH_METHOD}"
  fi

  if [ ! -f "${BRP_LINUX_SRC}/Kbuild"  ]; then
    pr_crit "BRP_LINUX_SRC=%s doesn't look like are valid Linux source tree (Kbuild not present)" "${BRP_LINUX_SRC}"
  fi

  if [ ! -f "${BRP_LINUX_SRC}/.config"  ]; then
    pr_crit "Kernel configuration file (%s/.config) doesn't exist - create one (or copy existing one)" "${BRP_LINUX_SRC}"
  fi
else
  pr_crit "BRP_LINUX_PATCH_METHOD=%s is not are valid value: {direct|repack}" "${BRP_LINUX_PATCH_METHOD}"
fi

if [ ! -f "${BRP_USER_CFG}" ]; then
  pr_crit "User config (BRP_USER_CFG) \"%s\" doesn't exist" "${BRP_USER_CFG}"
fi
brp_json_validate "${BRP_USER_CFG}"

if [ ! -f "${BRP_REL_CONFIG_JSON}" ]; then
  pr_crit "There doesn't seem to be a config for %s platform running %s (checked %s)" \
          "${BRP_HW_PLATFORM}" "${BRP_SW_VERSION}" "${BRP_REL_CONFIG_JSON}"
fi
brp_json_validate "${BRP_REL_CONFIG_JSON}"

### Here we define some common/well-known paths used later, as well as the map for resolving path variables in configs
readonly BRP_REL_OS_ID=$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "os.id")
readonly BRP_UPAT_DIR="${BRP_BUILD_DIR}/pat-${BRP_REL_OS_ID}-unpacked" # unpacked pat directory
readonly BRP_EXT_DIR="$PWD/ext" # a directory with external tools/files/modules
readonly BRP_COMMON_CFG_BASE="$PWD/config/_common" # a directory with common configs & patches sable for many platforms
readonly BRP_USER_DIR="$PWD/custom"
# vars map for copying files from release configs. If you're changing this please add to docs!
typeset -r -A BRP_RELEASE_PATHS=(
  [@@@_DEF_@@@]="${BRP_REL_CONFIG_BASE}"
  [@@@PAT@@@]="${BRP_UPAT_DIR}"
  [@@@COMMON@@@]="${BRP_COMMON_CFG_BASE}"
  [@@@EXT@@@]="${BRP_EXT_DIR}"
)
# vars map for copying files from user config. If you're changing this please add to docs!
typeset -r -A BRP_USER_PATHS=(
  [@@@_DEF_@@@]="${BRP_USER_DIR}"
)

pr_dbg "******** Printing config variables ********"
pr_dbg "Cache dir: %s" "$BRP_CACHE_DIR"
pr_dbg "Build dir: %s" "$BRP_BUILD_DIR"
pr_dbg "Ext dir: %s" "$BRP_EXT_DIR"
pr_dbg "User custom dir: %s" "$BRP_USER_DIR"
pr_dbg "User config: %s" "$BRP_USER_CFG"
pr_dbg "Keep build dir? %s" "$BRP_KEEP_BUILD"
pr_dbg "Linux patch method: %s" "$BRP_LINUX_PATCH_METHOD"
pr_dbg "Linux repack src: %s" "$BRP_LINUX_SRC"
pr_dbg "Hardware platform: %s" "$BRP_HW_PLATFORM"
pr_dbg "Software version: %s" "$BRP_SW_VERSION"
pr_dbg "Image template: %s" "$BRP_BOOT_IMAGE"
pr_dbg "Image destination: %s" "$BRP_OUTPUT_FILE"
pr_dbg "Common cfg base: %s" "$BRP_COMMON_CFG_BASE"
pr_dbg "Release cfg base: %s" "$BRP_REL_CONFIG_BASE"
pr_dbg "Release cfg JSON: %s" "$BRP_REL_CONFIG_JSON"
pr_dbg "Release id: %s" "$BRP_REL_OS_ID"
pr_dbg "*******************************************"

##### SYSTEM IMAGE HANDLING ############################################################################################
readonly BRP_PAT_FILE="${BRP_CACHE_DIR}/${BRP_REL_OS_ID}.pat"

if [ ! -d "${BRP_UPAT_DIR}" ]; then
  pr_dbg "Unpacked PAT %s not found - preparing" "${BRP_UPAT_DIR}"

  brp_mkdir "${BRP_UPAT_DIR}"

  if [ ! -f "${BRP_PAT_FILE}" ]; then
    readonly BRP_PAT_URL=$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "os.pat_url")
    pr_info "PAT file %s not found - downloading from %s" "${BRP_PAT_FILE}" "${BRP_PAT_URL}"
    "${CURL_PATH}" --output "${BRP_PAT_FILE}" "${BRP_PAT_URL}"
  else
    pr_dbg "Found existing PAT at %s - skipping download" "${BRP_PAT_FILE}"
  fi

  brp_verify_file_sha256 "${BRP_PAT_FILE}" "$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "os.sha256")"
  brp_unpack_tar "${BRP_PAT_FILE}" "${BRP_UPAT_DIR}"
else
  pr_info "Found unpacked PAT at \"%s\" - skipping unpacking" "${BRP_UPAT_DIR}"
fi


##### LINUX KERNEL MODIFICATIONS #######################################################################################
# Prepare Linux kernel image
readonly BRP_ZLINUX_FILE=${BRP_UPAT_DIR}/$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" 'files.zlinux.name')
readonly BRP_ZLINUX_PATCHED_FILE="${BRP_BUILD_DIR}/zImage-patched"
if [ ! -f "${BRP_ZLINUX_PATCHED_FILE}" ]; then
  # Using repack method to patch the kernel. This method assumes that it will be interrupted, someone will go and look
  # at the unpacked file, patch it manually and re-run the process to continue packing
  if [ "${BRP_LINUX_PATCH_METHOD}" == "repack" ]; then
    readonly BRP_VMLINUX_FILE="${BRP_BUILD_DIR}/vmlinux.elf"

    if [ ! -f "${BRP_VMLINUX_FILE}" ]; then
      brp_unpack_zimage "${BRP_ZLINUX_FILE}" "${BRP_VMLINUX_FILE}"
    else
      pr_info "Found unpacked vmlinux at \"%s\" - skipping unpacking" "${BRP_VMLINUX_FILE}"
    fi
    brp_verify_file_sha256 "${BRP_VMLINUX_FILE}" "$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "files.vmlinux.sha256")"

    readonly BRP_VMLINUX_PATCHED_FILE="${BRP_BUILD_DIR}/vmlinux-patched.elf"
    if [ ! -f "${BRP_VMLINUX_PATCHED_FILE}" ]; then
      pr_err "Patched unpacked Linux file \"%s\" doesn't exist. Create it based on \"%s\" and run the process again" \
             "${BRP_VMLINUX_PATCHED_FILE}" "${BRP_VMLINUX_FILE}"
      pr_warn "If you don't know what to do you picked A WRONG METHOD - read the README again. The method you used is for developers only!"
      exit 1
    else
      pr_info "Found patched Linux kernel at \"%s\" - repacking" "${BRP_VMLINUX_PATCHED_FILE}"
      brp_repack_zimage "${BRP_LINUX_SRC}" "${BRP_VMLINUX_PATCHED_FILE}" "${BRP_ZLINUX_PATCHED_FILE}"
    fi

  else # we can just "else" for "direct" creation method since it should be checked at the top
    brp_verify_file_sha256 "${BRP_ZLINUX_FILE}" "$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "files.zlinux.sha256")"
    brp_apply_binary_patches \
      "${BRP_ZLINUX_FILE}" \
      "${BRP_ZLINUX_PATCHED_FILE}" \
      "$(brp_json_get_array_values "${BRP_REL_CONFIG_JSON}" 'patches.zlinux')" \
      "${BRP_REL_CONFIG_BASE}"
  fi
else
  pr_info "Found patched zImage at \"%s\" - skipping patching & repacking" "${BRP_ZLINUX_PATCHED_FILE}"
fi


##### RAMDISK MODIFICATIONS ############################################################################################
# here we have a ready kernel in BRP_ZLINUX_PATCHED_FILE which makes the end of playing with the kernel
# Now we can begin to take care of the ramdisk
readonly BRP_RD_FILE=${BRP_UPAT_DIR}/$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" 'files.ramdisk.name') # original ramdisk file
readonly BRP_URD_DIR="${BRP_BUILD_DIR}/rd-${BRP_REL_OS_ID}-unpacked" # folder with unpacked ramdisk contents
readonly BRP_RD_REPACK="${BRP_BUILD_DIR}/rd-patched-${BRP_REL_OS_ID}.gz" # repacked ramdisk file

#rm -rf build/testing/rd-* # for debugging ramdisk routines; also comment-out rm of BRP_URD_DIR
#rm "${BRP_RD_REPACK}" # for testing

if [ ! -f "${BRP_RD_REPACK}" ]; then # do we even need to unpack-modify-repack the ramdisk or was it already done?
  if [ ! -d "${BRP_URD_DIR}" ]; then # do we need to unpack the ramdisk first?
    pr_dbg "Unpacked ramdisk %s not found - preparing" "${BRP_URD_DIR}"

    brp_mkdir "${BRP_URD_DIR}"
    brp_verify_file_sha256 "${BRP_RD_FILE}" "$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "files.ramdisk.sha256")"
    brp_unpack_zrd "${BRP_RD_FILE}" "${BRP_URD_DIR}"
  else
    pr_info "Found unpacked ramdisk at \"%s\" - skipping unpacking" "${BRP_URD_DIR}"
  fi

  # Applies all static .patch files to the ramdisk
  brp_apply_text_patches \
    "${BRP_URD_DIR}" \
    "$(brp_json_get_array_values "${BRP_REL_CONFIG_JSON}" 'patches.ramdisk')" \
    BRP_RELEASE_PATHS

  # Now we apply dynamic patches for configs
  # These paths look to be static throughout maaaaany years, so they're not in config file - if needed it's easy to move
  # them to the JSON file
  readonly BRP_POST_INIT_FILE="${BRP_URD_DIR}/sbin/init.post" # file with @@@CONFIG-MANIPULATORS-TOOLS@@@ and @@@CONFIG-GENERATED@@@
  readonly BRP_RD_CONFS=("${BRP_URD_DIR}/etc/synoinfo.conf" "${BRP_URD_DIR}/etc.defaults/synoinfo.conf") # files to patch in the baked-in ramdisk
  readonly BRP_OS_CONFS=("/tmpRoot/etc/synoinfo.conf" "/tmpRoot/etc.defaults/synoinfo.conf") # paths of files on the OS partition (valid after the RD boots)
  readonly BRP_USER_HAS_SYNOINFO=$(brp_json_has_field "${BRP_USER_CFG}" 'synoinfo')

  # Patch preboot (statically)
  pr_process "Patching config files in ramdisk"
  brp_patch_config_files "${BRP_REL_CONFIG_JSON}" 'synoinfo' "${BRP_RD_CONFS[@]}" # first apply platform changes

  if [[ ${BRP_USER_HAS_SYNOINFO} -eq 1 ]]; then
    brp_patch_config_files "${BRP_USER_CFG}" 'synoinfo' "${BRP_RD_CONFS[@]}" # then apply user changes
  fi
  pr_process_ok

  # Next we need to ensure the same patches are applied to post-boot environment too (dynamically)
  pr_process "Adding OS config patching"
  BRP_TEMP_ARRAY=(); brp_generate_set_confs_calls \
                     "${BRP_REL_CONFIG_JSON}" 'synoinfo' BRP_TEMP_ARRAY "${BRP_OS_CONFS[@]}" # platform configs
  BRP_OS_CONFS_LINES="$(brp_array_to_text $'\n' "${BRP_TEMP_ARRAY[@]}")"

  if [[ ${BRP_USER_HAS_SYNOINFO} -eq 1 ]]; then
    BRP_TEMP_ARRAY=(); brp_generate_set_confs_calls \
                       "${BRP_USER_CFG}" 'synoinfo' BRP_TEMP_ARRAY "${BRP_OS_CONFS[@]}" # user configs
    BRP_OS_CONFS_LINES+=$'\n'"$(brp_array_to_text $'\n' "${BRP_TEMP_ARRAY[0]+"${BRP_TEMP_ARRAY[@]}"}")"
  fi
  brp_replace_token_with_script "${BRP_POST_INIT_FILE}" '@@@CONFIG-MANIPULATORS-TOOLS@@@' "$PWD/include/config-manipulators.sh"
  brp_replace_token_with_text "${BRP_POST_INIT_FILE}" '@@@CONFIG-GENERATED@@@' "${BRP_OS_CONFS_LINES}"
  pr_process_ok

  # Copy any extra files to the ramdisk
  brp_cp_from_list "${BRP_REL_CONFIG_JSON}" "extra.ramdisk_copy" BRP_RELEASE_PATHS "${BRP_URD_DIR}"
  if [[ "$(brp_json_has_field "${BRP_USER_CFG}" 'ramdisk_copy')" -eq 1 ]]; then
    brp_cp_from_list "${BRP_USER_CFG}" "ramdisk_copy" BRP_USER_PATHS "${BRP_URD_DIR}"
  fi

  # Handle debug flags
  if [ "${BRP_DEV_DISABLE_RP}" -eq 1 ]; then
    pr_warn "<DEV> Disabling RedPill LKM"
    "${MV_PATH}" "${BRP_URD_DIR}/usr/lib/modules/rp.ko" "${BRP_URD_DIR}/usr/lib/modules/rp-dis.ko" \
      || pr_crit "Failed to move RedPill LKM"
  fi
  if [ "${BRP_DEV_DISABLE_SB}" -eq 1 ]; then
      pr_warn "<DEV> Disabling mfgBIOS LKM"
      "${MV_PATH}" "${BRP_URD_DIR}/usr/lib/modules/synobios.ko" "${BRP_URD_DIR}/usr/lib/modules/synobios-dis.ko" \
        || pr_crit "Failed to move mfgBIOS LKM"
    fi

  # Finally, we can finish ramdisk modifications with repacking it
  readonly BRP_RD_COMPRESSED=$(brp_json_get_field "${BRP_REL_CONFIG_JSON}" "extra.compress_rd")

  pr_process "Repacking ramdisk to %s" "${BRP_RD_REPACK}"
  if [ "${BRP_RD_COMPRESSED}" == "true" ]; then
    brp_pack_zrd "${BRP_RD_REPACK}" "${BRP_URD_DIR}"
  elif [ "${BRP_RD_COMPRESSED}" == "false" ]; then
    brp_pack_cpiord "${BRP_RD_REPACK}" "${BRP_URD_DIR}"
  else
    pr_crit "Invalid value for platform extra.compress_rd (expected bool, got \"%s\")" "${BRP_RD_COMPRESSED}"
  fi
  pr_process_ok

  # remove unpacked ramdisk in case the script is run again (to prevent stacking changes); this should happen even if
  # BRP_KEEP_BUILD is set!
  pr_dbg "Removing old unpacked RD files"
  "${RM_PATH}" -rf "${BRP_URD_DIR}" || pr_warn "Failed to remove unpacked ramdisk %s" "${BRP_URD_DIR}"
else
  pr_info "Found repacked ramdisk at \"%s\" - skipping patching & repacking" "${BRP_URD_DIR}"
fi

##### PREPARE GRUB CONFIG ##############################################################################################
readonly BRP_TMP_GRUB_CONF="${BRP_BUILD_DIR}/grub.cfg"
pr_process "Generating GRUB config"
brp_generate_grub_conf "${BRP_REL_CONFIG_JSON}" "${BRP_USER_CFG}" BRP_RELEASE_PATHS "${BRP_TMP_GRUB_CONF}"
pr_process_ok

##### CREATE FINAL LOADER IMAGE ########################################################################################
pr_process "Creating loader image at %s" "${BRP_OUTPUT_FILE}"
brp_unpack_single_gz "${BRP_BOOT_IMAGE}" "${BRP_OUTPUT_FILE}"
readonly BRP_OUT_P1="$(brp_mount_img_partitions "${BRP_OUTPUT_FILE}" 1 "${BRP_BUILD_DIR}/img-mnt")" # partition 1 of img
readonly BRP_OUT_P2="$(brp_mount_img_partitions "${BRP_OUTPUT_FILE}" 2 "${BRP_BUILD_DIR}/img-mnt")" # partition 2 of img
readonly BRP_ZLINMOD_NAME="zImage" # name of the linux kernel in the final image
readonly BRP_RDMOD_NAME="rd.gz" # name of the ramdisk in the final image

# Copy any config-specified extra files
pr_dbg "Copying extra files"
brp_cp_from_list "${BRP_REL_CONFIG_JSON}" "extra.bootp1_copy" BRP_RELEASE_PATHS "${BRP_OUT_P1}"
brp_cp_from_list "${BRP_REL_CONFIG_JSON}" "extra.bootp2_copy" BRP_RELEASE_PATHS "${BRP_OUT_P2}"

# Copy user files to boot partitions
if [[ "$(brp_json_has_field "${BRP_USER_CFG}" 'bootp1_copy')" -eq 1 ]]; then
  brp_cp_from_list "${BRP_USER_CFG}" "bootp1_copy" BRP_RELEASE_PATHS "${BRP_OUT_P1}"
fi
if [[ "$(brp_json_has_field "${BRP_USER_CFG}" 'bootp2_copy')" -eq 1 ]]; then
  brp_cp_from_list "${BRP_USER_CFG}" "bootp2_copy" BRP_RELEASE_PATHS "${BRP_OUT_P2}"
fi

# Add patched zImage, patched ramdisk and our GRUB config
pr_dbg "Copying patched files"
brp_cp_flat "${BRP_ZLINUX_PATCHED_FILE}" "${BRP_OUT_P1}/${BRP_ZLINMOD_NAME}"
brp_cp_flat "${BRP_RD_REPACK}" "${BRP_OUT_P1}/${BRP_RDMOD_NAME}"
brp_cp_flat "${BRP_TMP_GRUB_CONF}" "${BRP_OUT_P1}/boot/grub/grub.cfg"
pr_process_ok

##### CLEANUP ##########################################################################################################
pr_process "Cleaning up"
brp_detach_image "${BRP_OUTPUT_FILE}"
if [ "${BRP_KEEP_BUILD}" -eq 0 ]; then
  "${RM_PATH}" -rf "${BRP_BUILD_DIR}"
fi
pr_process_ok
