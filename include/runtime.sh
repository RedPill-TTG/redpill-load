#!/usr/bin/env bash
set -uo pipefail

# This file contains all tools used by the build script as well as checking runtime environment

if [ "$(uname)" != "Linux" ]; then
  pr_warn "You're running on %s - the script may fail. Only running on Linux is supported." "$(uname)"
fi

tools_ok=1
typeset -A system_tools
system_tools=(
  [date]="date --version" # used for generating unique folders & timestamping files
  [curl]="curl --version" # downloading PATs
  [sha256sum]="sha256sum --version" # checksums verification
  [tar]="tar --version" # unpacking PATs
  [xz]="xz --version" # unpacking & repacking ramdisks
  [cpio]="cpio --version" # unpacking & repacking ramdisks
  [jq]="jq --version" # reading JSONs; needs AT LEAST 1.5!!!
  [sed]="sed --version" # manipulating configs
  [grep]="grep --version" # manipulating configs & other
  [patch]="patch --version" # patching text files
  [mkdir]="mkdir --version" # creating directories
  [cut]="cur --version" # extracting data from sha256sum (& others)
  [ls]="ls --version" # checkins lists of files for unpacked ramdisks
  [cp]="ls --version" # creating temps for binary patching
  [mv]="mv --version"
  [rm]="rm --version" # removing temps
  [find]="find --version" # repacking ramdisks
  [losetup]="losetup -V" # attaching template boot image
  [mount]="mount --version" # mounting partitions from boot image
  [umount]="mount --version" # unmounting partitions from boot image
  [gzip]="gzip --version" # unpacking tempalte file
)
typeset -A custom_tools
custom_tools=(
)

if [ "${BRP_LINUX_PATCH_METHOD}" == "repack" ]; then
  system_tools[unlzma]="unlzma --version"
  custom_tools[rebuild_kernel]="ext/recreate-zImage/rebuild_kernel.sh"
  custom_tools[extract_vmlinux]="ext/extract_vmlinux.sh"
else
  system_tools[bspatch]="bspatch --version"
fi


pr_process "Checking runtime for required tools"
for tool in "${!system_tools[@]}";
do
  pr_dbg "Checking for system tool \"%s\"" "$tool"
  tool_path="$(which "${tool}")"
  if [ $? -ne 0 ]; then
    pr_err "Couldn't find %s in your \$PATH" "${tool}"
    tools_ok=0
    continue
  fi

  pr_dbg "Found ${tool} at ${tool_path}"
  export ${tool^^}_PATH="${tool_path}"
done

for tool in "${!custom_tools[@]}";
do
  tool_path="${custom_tools[$tool]}"
  pr_dbg "Checking for \"%s\" (%s)" "$tool" "$tool_path"
  if [ ! -x "${tool_path}" ]; then
    pr_err "Couldn't find %s in your %s" "${tool}" "${tool_path}"
    tools_ok=0
    continue
  fi

  pr_dbg "Found executable for ${tool} at ${tool_path}"
  export ${tool^^}_PATH="${tool_path}"
done

if [ $tools_ok -ne 1 ]; then
  pr_process_err
  pr_crit "Some tools weren't available - install them first"
else
  pr_process_ok
fi
