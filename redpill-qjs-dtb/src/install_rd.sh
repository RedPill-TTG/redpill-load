#!/bin/sh

tar -zxvf patch.tar.gz
# install dtc
chmod +x dtc
cp dtc /usr/sbin/dtc

# copy file
if [ ! -f model_${PLATFORM_ID%%_*}.dtb ]; then
  # Dynamic generation
  ./dtc -I dtb -O dts -o output.dts /etc.defaults/model.dtb
  qjs --std ./dts.js output.dts output.dts.out
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
