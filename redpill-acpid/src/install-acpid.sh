#!/bin/sh

SYNOINFO_DEF="/etc.defaults/synoinfo.conf"
UniqueRD=`/bin/get_key_value $SYNOINFO_DEF unique | cut -d"_" -f2`
# check button.ko
if [ ! -f /tmpRoot/lib/modules/button.ko ]; then
  tar -zxvf button.tgz
  button_dir=$(uname -r)/$UniqueRD
  if [ ! -f "${button_dir}/button.ko" ]; then
    echo "Error: ${button_dir}/button.ko not found, acpid may not work"
  else
    cp "${button_dir}/button.ko" /tmpRoot/lib/modules/
  fi
fi

# download files
#curl -L https://cdn.jsdelivr.net/gh/jumkey/redpill-load@develop/redpill-acpid/acpid.tar.gz -o /tmp/acpid.tar.gz

# copy file
#tar -zxvf /tmp/acpid.tar.gz -C /
tar -zxvf acpid.tar.gz -C /tmpRoot/
#install -c -D -m755 acpid -t ${TmpInstDir}/usr/sbin/
chmod 755 /tmpRoot/usr/sbin/acpid

# install config files
#install -c -D -m644 SynoFiles/etc/acpi/events/power ${TmpInstDir}/etc/acpi/events/power
#install -c -D -m744 SynoFiles/etc/acpi/power.sh ${TmpInstDir}/etc/acpi/power.sh
#install -c -D -m744 SynoFiles/systemd/acpid.service ${TmpInstDir}${SYSTEMD_LIB_DIR}/acpid.service
chmod 644 /tmpRoot/etc/acpi/events/power
chmod 744 /tmpRoot/etc/acpi/power.sh
chmod 744 /tmpRoot/usr/lib/systemd/system/acpid.service

# enable
#systemctl enable acpid.service
ln -sf /usr/lib/systemd/system/acpid.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/acpid.service

# start
#systemctl start acpid.service
