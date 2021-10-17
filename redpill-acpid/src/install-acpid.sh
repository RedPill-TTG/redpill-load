#!/bin/sh

# download files
curl -L https://github.com/jumkey/redpill-load/raw/develop/redpill-acpid/acpid.tar.gz -o /tmp/acpid.tar.gz

# copy file
tar -zxvf /tmp/acpid.tar.gz -C /

# enable
systemctl enable acpid.service

# start
systemctl start acpid.service
