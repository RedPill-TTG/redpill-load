#!/usr/bin/env bash
set -uo pipefail

# Finds an existing loop device for a given image file; if not found it will return exit code 1
#
# Args: $1 img file
brp_get_loop_for_img()
{
  local out;
  out=$("${LOSETUP_PATH}" | "${GREP_PATH}" "${1}" | "${GREP_PATH}" -o '/dev/loop[0-9]*')
  if [ $? -eq 0 ]; then
    echo "${out}"
    return 0
  fi

  return 1
}

# Attaches an image to a loop device and returns the loop device reserved
#
# Args: $1 image to be attached
brp_attach_image()
{
  local out;
  # if it's already attached just return it
  out=$(brp_get_loop_for_img "${1}")
  if [ $? -eq 0 ]; then
    pr_dbg "Image %s already attached to %s - using it" "${1}" "${out}"
    echo "${out}"
    return
  fi

  out=$("${LOSETUP_PATH}" --find --show --partscan "${1}" 2>&1)
  if [ $? -ne 0 ]; then
    pr_crit "Failed to attach %s to a loop device (permissions problem?)\n\n%s" "${1}" "${out}"
  fi
  pr_dbg "Attached %s as %s" "${1}" "${out}"

  echo "${out}";
}

# Mount given partition from image specified into unique folders
# You can call this function multiple times to attach multiple partitions (but calling it twice for the same partition
# within the same image is seen as an error)
#
# Args: $1 image | $2 partition number | $3 where to create mountpoints
brp_mount_img_partitions()
{
  local loop;
  local loop_part;
  local mnt_pt;

  loop=$(brp_attach_image "${1}")
  loop_part="${loop}p${2}"
  mnt_pt="${3}/part-${2}"

  out=$("${MOUNT_PATH}" | "${GREP_PATH}" "${loop_part}")
  if [ $? -eq 0 ]; then
    pr_crit "Partition %d of %s is already mounted:\n\n%s" "${2}" "${1}" "${out}"
  fi

  # We verified that the partition is not mounted but we don't know if the mountpoint is used in any way. Its existance
  # by itself is unusual BUT it's not an error if it's an empty folder
  # "mountpoint" could be used more robustly here but grepping mount is perfectly sufficient in this unlikely scenario
  if [ -d "${mnt_pt}" ]; then
    pr_warn "Mountpoint for %s:part%d already exists at %s" "${1}" "${2}" "${mnt_pt}"

    if [ "$("${LS_PATH}" -A "${mnt_pt}")" ]; then
      pr_crit "Directory %s is not empty - cannot use as mountpoint"
    fi

    out=$("${MOUNT_PATH}" | "${GREP_PATH}" "${mnt_pt}")
    if [ $? -eq 0 ]; then
      pr_crit "The mountpoint %s is already used:\n\n%s" "${mnt_pt}" "${out}"
    fi
  else
    brp_mkdir "${mnt_pt}"
  fi

  out=$("${MOUNT_PATH}" "${loop_part}" "${mnt_pt}")
  if [ $? -ne 0 ]; then
    pr_crit "Failed to mount %s (partition %d of %s) to %s\n\n%s" "${loop_part}" "${2}" "${1}" "${mnt_pt}"
  fi
  pr_dbg "Successfully mounted %s to %s" "${loop_part}" "${mnt_pt}"

  echo "${mnt_pt}"
}

# Unmounts all partitions of a given image and detaches the image
#
# Args: $1 img file
brp_detach_image()
{
  local loop;
  loop=$(brp_get_loop_for_img "$1")
  if [ $? -ne 0 ]; then
    pr_crit "The image is not mounted" "${1}"
  fi

  pr_dbg "Unmounting all partitions of %s via %s" "${1}" "${loop}"
  local parts;
  local out;
  readarray -t parts <<< "$("${MOUNT_PATH}" | "${GREP_PATH}" -o "${loop}p[0-9]*")"
  for part in "${parts[@]}"; do
    out="$("${UMOUNT_PATH}" "${part}" 2>&1)"
    if [ $? -ne 0 ]; then
      pr_crit "Failed to unmount %s\n\n%s" "${part}" "${out}"
    fi
  done;
  pr_dbg "Unmounted all partitions of %s" "${1}"

  out="$("${LOSETUP_PATH}" -d "${loop}" 2>&1)"
  if [ $? -ne 0 ]; then
    pr_crit "Failed to detach image %s from %s\n\n%s" "${1}" "${loop}" "${out}"
  fi
  pr_dbg "Detached %s" "${loop}"
}

# Generates GRUB config file from a config structure
#
# - The main config file is expected to have .grub root key
# - The user config is expected to have extra_cmdline key
#
# Args:
#   $1 main JSON config
#   $2 user config
#   $3 reference to a map of K=>V pairs with variables, see brp_expand_var_path()
#   $4 GRUB config destination file path
brp_generate_grub_conf()
{
  local menu_entries_txt;
  local -n _path_map=$3

  # First get user cmdline overrides
  pr_dbg "Reading user extra_cmdline entries"
  local -A extra_cmdline;
  brp_read_kv_to_array "${2}" 'extra_cmdline' extra_cmdline
  if [[ -v ${extra_cmdline['sn']} ]]; then pr_warn "User configuration (%s) doesn't contain unique extra_cmdline.sn" "${2}"; fi
  if [[ -v ${extra_cmdline['vid']} ]]; then pr_warn "User configuration (%s) doesn't contain extra_cmdline.vid" "${2}"; fi
  if [[ -v ${extra_cmdline['pid']} ]]; then pr_warn "User configuration (%s) doesn't contain extra_cmdline.pid" "${2}"; fi
  if [[ -v ${extra_cmdline['mac1']} ]]; then pr_warn "User configuration (%s) doesn't contain at least one MAC (extra_cmdline.mac1)" "${2}"; fi

  # First generate menu entries
  pr_dbg "Generating GRUB menu entries"
  local entries_names;
  brp_json_get_keys "${1}" 'grub.menu_entries' entries_names

  # Cmdline is constructed by applying, in order, options from the follownig sources
  #  - platform config.json => .grub.base_cmdline
  #  - platform config.json => .grub.menu_entries.<entry name>.cmdline
  #  - user_config.json => .grub.menu_entries.<entry name>.extra_cmdline

  local -A base_cmdline;
  pr_dbg "Reading base cmdline"
  brp_read_kv_to_array "${1}" "grub.base_cmdline" base_cmdline

  local -A entry_cmdline;
  local -A final_cmdline;
  local -a menu_entries_arr;
  local entry_cmdline_txt;
  for entry_name in "${entries_names[@]}"; do
    pr_dbg "Processing entry \"%s\"" "${entry_name}"

    final_cmdline=()
    # Bash doesn't have any sensible way of merging or even copying associative arrays... FML
    # See https://stackoverflow.com/a/8881121
    for base_cmdl_key in "${!base_cmdline[@]}"; do final_cmdline[$base_cmdl_key]=${base_cmdline[$base_cmdl_key]}; done

    pr_dbg "Applying entry cmdline"
    brp_read_kv_to_array "${1}" "grub.menu_entries[\"${entry_name}\"].cmdline" entry_cmdline # read entry CMDLINE
    for entry_cmdl_key in "${!entry_cmdline[@]}"; do
      pr_dbg "Replacing base cmdline \"%s\" value \"%s\" with entry value \"%s\"" \
        "${entry_cmdl_key}" "${final_cmdline[entry_cmdl_key]:-<not set>}" "${entry_cmdline[$entry_cmdl_key]}"
      final_cmdline[$entry_cmdl_key]=${entry_cmdline[$entry_cmdl_key]};
    done

    pr_dbg "Applying user extra_cmdline"
    for user_cmdl_key in "${!extra_cmdline[@]}"; do
      pr_dbg "Replacing previous cmdline \"%s\" value \"%s\" with user value \"%s\"" \
        "${user_cmdl_key}" "${final_cmdline[$user_cmdl_key]:-<not set>}" "${extra_cmdline[$user_cmdl_key]}"
      final_cmdline[$user_cmdl_key]=${extra_cmdline[$user_cmdl_key]};
    done

    # Build the final cmdline for the entry
    # There are more tricks in BASH 5.1 for printing but not on v4.3 which is standard on Debian 8 (needed for old GCC)
    entry_cmdline_txt=''
    for cmdline_key in "${!final_cmdline[@]}"; do
      if brp_json_noe "${final_cmdline[$cmdline_key]}"; then
        entry_cmdline_txt+="${cmdline_key} "
      else
        entry_cmdline_txt+="${cmdline_key}=${final_cmdline[$cmdline_key]} "
      fi
    done
    pr_dbg "Generated cmdline for entry: %s" "${entry_cmdline_txt}"

    # Now we can actually assemble the entry
    menu_entries_txt+="menuentry '${entry_name}' {"$'\n'
    brp_read_ordered_kv "${1}" "grub.menu_entries[\"${entry_name}\"].options" entry_options_keys entry_options_vals

    readarray -t menu_entries_arr <<< "$(brp_json_get_array_values "${1}" "grub.menu_entries[\"${entry_name}\"].options")"
    for entry in "${menu_entries_arr[@]}"; do
      menu_entries_txt+=$'\t'"${entry/@@@CMDLINE@@@/${entry_cmdline_txt}}"$'\n'
    done
    menu_entries_txt+='}'$'\n'$'\n'
  done;

  pr_dbg "Generated all menu entries:\n%s" "${menu_entries_txt}"

  pr_dbg "Assembling final grub config in %s" "${4}"
  local template;
  template=$(brp_json_get_field "${1}" 'grub.template')
  brp_cp_flat "$(brp_expand_var_path "${template}" _path_map)" "${4}"
  brp_replace_token_with_text "${4}" '@@@MENU_ENTRIES@@@' "${menu_entries_txt}"
}
