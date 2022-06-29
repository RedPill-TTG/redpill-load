#!/bin/sh

echo "Removing acpi CPUFreq module"
#if (grep -r -q -E "(QEMU|VirtualBox)" /sys/devices/virtual/dmi/id/); then
#  echo "VM detected,remove acpi-cpufreq module"
  /tmpRoot/usr/bin/sed -i 's/^acpi-cpufreq/# acpi-cpufreq/g' /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf
#else
#  echo "*No* VM detected,NOOP"
#fi
