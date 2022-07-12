#!/bin/sh

tar --owner=root --group=root -czf qjs.tar.gz --mode='+x' qjs
tar --owner=root --group=root -czf ../releases/package.tgz --mode='+x' qjs.tar.gz install_rd.sh
sha256sum ../releases/package.tgz
