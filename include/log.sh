#!/usr/bin/env bash
set -uo pipefail

readonly ASCII_RESET="\e[1;0m"
readonly ASCII_FG_RED="\e[1;91m"
readonly ASCII_FG_GREEN="\e[1;32m"
readonly ASCII_FG_YELLOW="\e[1;33m"
readonly ASCII_FG_GRAY="\e[1;90m"
readonly ASCII_FG_WHITE="\e[1;97m"
readonly ASCII_FG_BLACK="\e[1;30m"
readonly ASCII_BG_RED="\e[1;41m"
readonly ASCII_BG_GREEN="\e[1;42m"

# shellcheck disable=SC2046
if [ $(tput colors || exit 1) -gt 0 ]; then
    readonly ASCII_HAS_COLORS=1
else
    readonly ASCII_HAS_COLORS=0
fi

_BRP_LAST_PROCESS=''
_BRP_PROCESS_WAS_LAST=0 # used a canary flag when "process" printing was interrupted

# Args: $1 colors definition | $2 pattern | $3+ params
pr_print()
{
  if [ $_BRP_PROCESS_WAS_LAST -eq 1 ]; then # if there was a process running end the line gracefully
    echo '' >&2
  fi

  _BRP_PROCESS_WAS_LAST=0
  if [ $ASCII_HAS_COLORS -eq 1 ]; then
    printf "${1}${2}${ASCII_RESET}\n" "${@:3}" >&2
  else
    printf "${2}" "${@:3}" >&2
  fi
}

pr_crit()
{
  pr_print "${ASCII_BG_RED}${ASCII_FG_WHITE}" "[!] $1\n\n*** Process will exit ***" "${@:2}"
  exit 1
}

pr_err()
{
  pr_print "${ASCII_FG_RED}" "[-] $1" "${@:2}"
}

pr_warn()
{
  pr_print "${ASCII_FG_YELLOW}" "[*] $1" "${@:2}"
}

pr_info()
{
  pr_print "${ASCII_FG_GREEN}" "[#] $1" "${@:2}"
}

pr_dbg()
{
  if [ $BRP_DEBUG -ne 0 ]; then
    pr_print "${ASCII_FG_GRAY}" "[%%] $1" "${@:2}"
  fi
}

pr_process()
{
  _BRP_PROCESS_WAS_LAST=1
  pattern="[#] $1... ";

  if [ $ASCII_HAS_COLORS -eq 1 ]; then
    _BRP_LAST_PROCESS=$(printf "${ASCII_FG_GREEN}$pattern${ASCII_RESET} " "${@:2}")
  else
    _BRP_LAST_PROCESS=$(printf "$pattern" "${@:2}")
  fi

  echo -n $_BRP_LAST_PROCESS >&2
}

# Args: $1 [OPTIONAL] custom text instead of OK
pr_process_ok()
{
  if [ $_BRP_PROCESS_WAS_LAST -ne 1 ]; then # if there were any messages in-between re-print process message
    echo -n $_BRP_LAST_PROCESS >&2
  fi

  _BRP_PROCESS_WAS_LAST=0 # remove flag so pr_print prints the message like normal
  pr_print "${ASCII_BG_GREEN}${ASCII_FG_BLACK}" "[%s]" "${1:-"OK"}"
}

# Args: $1 [OPTIONAL] custom text instead of ERR
pr_process_err()
{
  if [ $_BRP_PROCESS_WAS_LAST -ne 1 ]; then # if there were any messages in-between re-print process message
    echo -n $_BRP_LAST_PROCESS >&2
  fi

  _BRP_PROCESS_WAS_LAST=0 # remove flag so pr_print prints the message like normal
  pr_print "${ASCII_BG_RED}${ASCII_FG_WHITE}" "[%s]" "${1:-"ERR"}"
}
