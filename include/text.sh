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
