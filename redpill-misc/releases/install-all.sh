#!/bin/sh
#
#
# Script for fixing missing HW features dependencies
#

PLATFORM=$(/bin/get_key_value /etc/synoinfo.conf unique | /bin/cut -d"_" -f2)

fixcpufreq() {

    cpufreq=$(ls -ltr /sys/devices/system/cpu/cpufreq/* 2>/dev/null | wc -l)

    if [ $cpufreq -eq 0 ]; then

        echo "CPU does NOT support CPU Performance Scaling, disabling"

        /tmpRoot/usr/bin/sed -i 's/^acpi-cpufreq/# acpi-cpufreq/g' /tmpRoot/usr/lib/modules-load.d/70-cpufreq-kernel.conf

    else
        echo "CPU supports CPU Performance Scaling"
    fi

}

fixcrypto() {

    CPUFLAGS=$(cat /proc/cpuinfo | grep flags | grep sse4_2 | wc -l)

    if [ $CPUFLAGS -gt 0 ]; then

        echo "CPU Supports SSE4.2, crc32c-intel should load"

    else

        echo "CPU does NOT support SSE4.2, crc32c-intel will not load, disabling"

        /tmpRoot/usr/bin/sed -i 's/^crc32c-intel/# crc32c-intel/g' /tmpRoot/usr/lib/modules-load.d/70-crypto-kernel.conf

    fi

}

fixnvidia() {

    NVIDIADEV=$(cat /proc/bus/pci/devices | grep -i 10de | wc -l)

    if [ $NVIDIADEV -eq 0 ]; then

        echo "NVIDIA GPU is not detected, disabling "

        /tmpRoot/usr/bin/sed -i 's/^nvidia/# nvidia/g' /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf
        /tmpRoot/usr/bin/sed -i 's/^nvidia-uvm/# nvidia-uvm/g' /tmpRoot/usr/lib/modules-load.d/70-syno-nvidia-gpu.conf

    else

        echo "NVIDIA GPU is detected, nothing to do"

    fi

}

case "${PLATFORM}" in

bromolow)
    fixcpufreq
    fixcrypto
    ;;
apollolake)
    fixcpufreq
    fixcrypto
    ;;
broadwell)
    fixcpufreq
    fixcrypto
    ;;
broadwellnk)
    fixcpufreq
    fixcrypto
    ;;
v1000)
    fixcpufreq
    fixcrypto
    ;;
denverton)
    fixcpufreq
    fixcrypto
    fixnvidia
    ;;
geminilake)
    fixcpufreq
    fixcrypto
    ;;

*)
    fixcpufreq
    fixcrypto
    ;;

esac
