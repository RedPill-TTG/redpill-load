#!/bin/sh

# copy file
tar -zxvf acpid_v6.tar.gz -C /tmpRoot/

#install -c -D -m755 acpid -t ${TmpInstDir}/usr/sbin/
chmod 755 /tmpRoot/usr/sbin/acpid

# install config files
#install -c -D -m644 SynoFiles/etc/acpi/events/power ${TmpInstDir}/etc/acpi/events/power
#install -c -D -m744 SynoFiles/etc/acpi/power.sh ${TmpInstDir}/etc/acpi/power.sh
#install -c -D -m744 SynoFiles/etc/init/acpid.conf.upstart ${TmpInstDir}/etc/init/acpid.conf
chmod 644 /tmpRoot/etc/acpi/events/power
chmod 744 /tmpRoot/etc/acpi/power.sh
chmod 744 /tmpRoot/etc/init/acpid.conf
