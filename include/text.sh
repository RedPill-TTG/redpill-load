#!/usr/bin/env bash
set -u

# Converts bash array to delimiter-separated text
#
# Args: $1 separator | $2...n elements [because you cannot truly pass an array in bash]
function brp_array_to_text()
{
  local separator="${1}"
  shift 1

  local text;
  for el in "${@}"; do
    text+="${el}${separator}" # yes, this will leave last separator... there's no sensibe way to check for last el
  done;

  echo "${text}"
}

# Converts delimiter-separated text into bash array
#
# Args: $1 separator | $2 text | $3 array to write to
rpt_text_to_array()
{
  # readarray would be better but BASH 4.3 doesn't support delimiter
  IFS="${1}"
  read -r -a $3 <<< "${2}"
}
