#!/bin/sh

tar --exclude etc/init --owner=root --group=root -czf ../acpid.tar.gz etc usr
tar --owner=root --group=root -czf ../button.tgz -C button 4.4.180+
sha256sum ../acpid.tar.gz
sha256sum ../button.tgz
sha256sum install-acpid.sh
tar --exclude usr/lib --owner=root --group=root -czf ../acpid_v6.tar.gz etc usr
sha256sum ../acpid_v6.tar.gz
sha256sum install-acpid_v6.sh
