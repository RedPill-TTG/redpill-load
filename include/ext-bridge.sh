#!/usr/bin/env bash
set -u
# This file contains delegate functions which are used by the loader builder to operate on extensions on "arms-length"

# Loads list of user-whitelisted extensions
#
# Args: $1 user config
rpt_load_user_extensions()
{
  local user_exts=''

  pr_dbg "Loading user extensions list from %s" "${1}"
  if [[ "$(brp_json_has_field "${1}" 'extensions')" -eq 1 ]]; then
    user_exts=$(rpt_json_get_array_values_flat "${1}" 'extensions')
    if [[ $? -ne 0 ]]; then
      pr_crit "Value of %s->extensions is invalid" "${1}"
    fi
  fi

  echo "${user_exts}"
}

# Loads bundled extensions list
#
# Args: $1 bundled exts file | $2 ext names array | $3 assoc array to read to [which will be random order]
rpt_load_bundled_extensions()
{
  local -n __bundled_ext_keys=$2
  local -n __bundled_exts=$3

  pr_dbg "Loading bundled extensions list from %s"
  brp_read_ordered_kv "${1}" '' __bundled_ext_keys __bundled_exts
}


# Updates extensions indexes
#
# Args: <none>
rpt_update_ext_indexes()
{
  pr_dbg "Running extensions indexes update"
  ( ./ext-manager.sh update )
  if [[ $? -ne 0 ]]; then
    pr_crit "Failed to update extensions indexes - see errors above"
  fi
}
