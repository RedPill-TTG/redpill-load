#!/bin/sh

echo "Removing acpi CPUFreq module"
if [ -e /tmpRoot/sbin/dmidecode ] && (/tmpRoot/sbin/dmidecode -s system-manufacturer | grep -q -E "(QEMU|VirtualBox)"); then
  echo "VM detected,remove acpi-cpufreq module"
  /tmpRoot/usr/bin/sed -i 's/acpi-cpufreq/# acpi-cpufreq/g' /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf
else
  echo "*No* VM detected,NOOP"
fi
