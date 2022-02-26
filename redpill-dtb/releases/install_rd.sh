#!/bin/sh

# copy file
cp -vf model_${PLATFORM_ID%%_*}.dtb /etc.defaults/model.dtb
cp -vf model_${PLATFORM_ID%%_*}.dtb /var/run/model.dtb
