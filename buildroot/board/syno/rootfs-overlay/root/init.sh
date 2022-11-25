#!/bin/bash

cd $(dirname $0)
mkdir /temp1
mkdir /temp2
# TODO sdb?
usbfs=$(fdisk -l /dev/sd* | grep '128 MB' | awk '{print $2}' | awk -F ':' '{print $1}')
wait_time=30
time_counter=0
while [ "${usbfs}" = "" ] && [ $time_counter -lt $wait_time ]; do
  sleep 1
  usbfs=$(fdisk -l /dev/sd* | grep '128 MB' | awk '{print $2}' | awk -F ':' '{print $1}')
  echo "Still waiting for boot device (waited $((time_counter=time_counter+1)) of ${wait_time} seconds)"
done
mount ${usbfs}1 /temp1
mount ${usbfs}2 /temp2

sh bzImage-to-vmlinux.sh /temp2/zImage vmlinux

php patch-boot_params-check.php vmlinux vmlinux-mod
rm vmlinux
php patch-ramdisk-check.php vmlinux-mod vmlinux.bin
rm vmlinux-mod

mkdir "ramdisk" ; cd "ramdisk"

unlzma < /temp2/rd.gz | cpio -idmuv

unlzma < /temp1/custom.gz | cpio -idmuv

# make any modifications and recompress \/ 
find . 2>/dev/null | cpio -o -H newc -R root:root | xz -9 --format=lzma > ../rd.gz

cd ..

# add fake sign
dd if=/dev/zero of=rd.gz bs=68 count=1 conv=notrunc oflag=append

rm -rf ramdisk
umount /temp1
umount /temp2

kexec -d --args-linux ./vmlinux.bin --type=elf-x86_64 --reuse-cmdline --initrd=./rd.gz
kexec -d -e
