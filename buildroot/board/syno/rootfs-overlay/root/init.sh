#!/bin/bash

cd $(dirname $0)

sh bzImage-to-vmlinux.sh /temp2/zImage vmlinux

php patch-boot_params-check.php vmlinux vmlinux-mod
rm vmlinux
php patch-ramdisk-check.php vmlinux-mod vmlinux.bin
rm vmlinux-mod

mkdir "ramdisk" ; cd "ramdisk"

unlzma < /temp2/rd.gz | cpio -idmuv

unlzma < /boot/custom.gz | cpio -idmuv

# rd.gz + custom.gz
find . 2>/dev/null | cpio -o -H newc -R root:root | xz -9 --format=lzma > ../rd.gz

cd ..

# add fake sign
dd if=/dev/zero of=rd.gz bs=68 count=1 conv=notrunc oflag=append

rm -rf ramdisk

# rebuild zImage
if [[ -f "/boot/tools/vmlinux-to-bzImage.sh" ]]; then
  echo -n "Rebuilding zImage using external template..."
  /boot/tools/vmlinux-to-bzImage.sh
else
  echo -n "Rebuilding zImage... "
  ./vmlinux-to-bzImage.sh
fi

# start
kexec -d --args-linux ./zImage --type=bzImage64 --reuse-cmdline --initrd=./rd.gz
kexec -d -e
