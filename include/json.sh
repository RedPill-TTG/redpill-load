#!/usr/bin/env bash
set -uo pipefail

# Validates JSON and exists if invalid
#
# Args: $1 file path
brp_json_validate()
{
  local jq_out
  jq_out=$(jq empty "$1" 2>&1)
  if [ $? -eq 0 ]; then
    pr_dbg "JSON file \"%s\" is valid" "$1"
    return 0
  fi

  pr_crit "JSON file \"%s\" is invalid:\n\n%s" "$1" "${jq_out}"
}

# Checks if a given key existing in JSON
#
# Args: $1 file path | $2 field
brp_json_has_field()
{
  ${JQ_PATH} -e -r ".$2|select(0)" "$1" &>/dev/null
  if [[ $? -eq 0 ]]; then
    echo "1"
  else
    echo "0"
  fi
}

# Gets a single value of a key or exist on error
#
# Args: $1 file path | $2 field | $3 empty-on-error [default=0]
brp_json_get_field()
{
  local field_val;
  field_val=$(${JQ_PATH} -e -r ".$2" "$1")
  # "1 if the last output value was either false or null"
  if [ $? -le 1 ]; then
    echo $field_val
    return 0
  fi

  if [ "${3:-'0'}" != 1 ]; then
    pr_crit "Field \"$2\" doesn't existing in $1"
  fi
}

# Gets a single value of a key or exist on error
#
# This function GUARANTEES that keys are returned in their order in file
# Do NOT try to change it to "keys" to support older JQs as it will break other things (e.g. brp_read_ordered_kv)
#
# Args: $1 file path | $2 field | $3 return array
brp_json_get_keys()
{
  local -n __json_return=$3

  local out;
  out=$("${JQ_PATH}" -r -e ".${2}|keys_unsorted|.[]" "${1}" 2>&1)
  if [ $? -ne 0 ]; then
    pr_crit "Failed extract K=>V pairs from %s:.%s\n\n%s" "${1}" "${2}" "${out}"
  fi

  readarray -t __json_return <<< "${out}"
}

# Gets a new line-separated list of values from array or exist on error
#
# TODO: this is fugly - it should use references
#
# Args: $1 file path | $2 field | $3 empty-on-error [default=0]
brp_json_get_array_values()
{
  local field_val;
  field_val=$(${JQ_PATH} -e -r ".${2} | .[]" "${1}")
  if [ $? -eq 0 ] ; then
    echo "${field_val}"
    return 0
  fi

  if [ "${3:-'0'}" != 1 ]; then
    pr_crit "Field \"$2\" doesn't existing in $1"
  fi
}

# Check if passed string is "null" or ""
#
# Args: $1 string to check
brp_json_noe()
{
  if [ "$1" == "null" ] || [ -z "$1" ]; then
    return 0
  else
    return 1
  fi
}

# Reads JSON k=>v into bash associative array
#
# WARNING: THIS WILL **NOT** PRESERVE THE ORIGINAL ORDER OF VALUES!
#          Bash stores associative arrays in hashes, so that order is lost. This is perfectly fine for some scenarios
#          (e.g. list of files to copy) but disastrous in others (e.g. GRUB commands). If you want the order use
#          brp_read_ordered_kv() instead.
#
# Args: $1 JSON file | $2 JSON key | $3 array to read to
brp_read_kv_to_array()
{
  # kv_pair used dynamically in kv_extractor
  # shellcheck disable=SC2034
  local -n __json_kv_pairs=$3
  local kv_extractor='.'"${2}"'|to_entries|map("[\(.key|@sh)]=\(.value|@sh) ")|"__json_kv_pairs=(" + add + ")"';

  local out;
  out=$("${JQ_PATH}" -r -e "${kv_extractor}" "${1}" 2>&1)
  if [ $? -ne 0 ]; then
    pr_crit "Failed extract K=>V pairs from %s:.%s\n\n%s" "${1}" "${2}" "${out}"
  fi

  eval "$out"
}

# Reads JSON k=>v preserving order of keys
#
# This function preserves order of keys from the original array. Since Bash uses hash maps for associative arrays two
# array (keys+values) must be used. See https://stackoverflow.com/a/29161460
#
# To use it do:
# local -a keys
# local -A values
# brp_read_ordered_kv 'file.json' 'super.entries' keys values   # do NOT quote keys or values
# for key in "${keys[@]}"; do echo "${values[$key]}"; done
#
# Args: $1 JSON file | $2 JSON key | $3 normal keys array | $4 associative values array
brp_read_ordered_kv()
{
  local -n __json_keys=$3
  local -n __json_values=$4
  brp_json_get_keys "${1}" "${2}" __json_keys
  brp_read_kv_to_array "${1}" "${2}" __json_values # we can reuse code to read k=>v pairs as we need them anyway
}
