#!/usr/bin/env bash
# Removed all existing images and builds all permutations of the ones we test. We usually use this tool just after
# executing tools/make_all.sh from the LKM repo. The we usually do something akin to:
#    sftp dropbox@vm-003.local:/_images/rp-img/ <<< 'put images/*.gz'
# When you are executing this script do it from the root of the repo dir like ./tools/rebuild_all.sh

rm images/*.img images/*.gz

IMG_POSTFIX=""
if [[ -v BRP_DEV_ALL ]]; then
  export BRP_DEV_DISABLE_SB=1
  export BRP_DEV_DISABLE_RP=1
  IMG_POSTFIX="-dis"
fi

set -euo pipefail
BRP_DEBUG=1 BRP_USER_CFG=$PWD/user_config-ds3615.json ./build-loader.sh 'DS3615xs' '6.2.4-25556' "$PWD/images/rp-3615-v6$IMG_POSTFIX.img"
BRP_DEBUG=1 BRP_USER_CFG=$PWD/user_config-ds3615.json ./build-loader.sh 'DS3615xs' '7.0-41222' "$PWD/images/rp-3615-v7$IMG_POSTFIX.img"
BRP_DEBUG=1 BRP_USER_CFG=$PWD/user_config-ds918.json ./build-loader.sh 'DS918+' '6.2.4-25556' "$PWD/images/rp-918-v6$IMG_POSTFIX.img"
BRP_DEBUG=1 BRP_USER_CFG=$PWD/user_config-ds918.json ./build-loader.sh 'DS918+' '7.0-41890' "$PWD/images/rp-918-v7$IMG_POSTFIX.img"
gzip "$PWD/images/rp-3615-v6$IMG_POSTFIX.img"
gzip "$PWD/images/rp-3615-v7$IMG_POSTFIX.img"
gzip "$PWD/images/rp-918-v6$IMG_POSTFIX.img"
gzip "$PWD/images/rp-918-v7$IMG_POSTFIX.img"
