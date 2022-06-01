#!/bin/sh

# download from https://bellard.org/quickjs/binary_releases/quickjs-linux-x86_64-2021-03-27.zip
tar -zxvf qjs.tar.gz
# install qjs
chmod +x qjs
cp qjs /usr/sbin/qjs

qjs -e 'console.log("hello world from qjs")'
