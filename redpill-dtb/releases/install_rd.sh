#!/bin/sh

# install dtc
chmod +x dtc
cp dtc /usr/sbin/dtc

# copy file
if [ ! -f model_${PLATFORM_ID%%_*}.dtb ]; then
  # Dynamic generation
  ./dtc -I dtb -O dts -o output.dts /etc.defaults/model.dtb
  # http://security.debian.org/debian-security/pool/updates/main/z/zlib/zlib1g_1.2.8.dfsg-5+deb9u1_amd64.deb
  LD_LIBRARY_PATH=. ./dts-upx output.dts output.dts.out
  if [ $? -ne 0 ]; then
    echo "auto generated dts file is broken"
    exit 0
  fi
  ./dtc -I dts -O dtb -o model_r2.dtb output.dts.out
  cp -vf model_r2.dtb /etc.defaults/model.dtb
  cp -vf model_r2.dtb /var/run/model.dtb
else
  cp -vf model_${PLATFORM_ID%%_*}.dtb /etc.defaults/model.dtb
  cp -vf model_${PLATFORM_ID%%_*}.dtb /var/run/model.dtb
fi
