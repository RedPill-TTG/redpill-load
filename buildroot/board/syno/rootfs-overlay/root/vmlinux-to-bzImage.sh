#!/bin/sh

#zImage_head 16494
#+vmlinux.bin x
#+padding 0xf00000-x
#+zImage_tail(
#   vmlinux.bin size 4
#   +72
#   +run_size 4
#   +30
#   +vmlinux.bin size 4
#   +114460
#) 114574
#+crc32 4

# Adapted from: scripts/Makefile.lib
# Usage: size_append FILE [FILE2] [FILEn]...
# Output: LE HEX with size of file in bytes (to STDOUT)
file_size_le () {
  printf $(
    dec_size=0;
    for F in "${@}"; do
      fsize=$(stat -c "%s" $F);
      dec_size=$(expr $dec_size + $fsize);
    done;
    printf "%08x\n" $dec_size |
      sed 's/\(..\)/\1 /g' | {
        read ch0 ch1 ch2 ch3;
        for ch in $ch3 $ch2 $ch1 $ch0; do
          printf '%s%03o' '\' $((0x$ch));
        done;
      }
  )
}

size_le () {
  printf $(
    printf "%08x\n" "${@}" |
      sed 's/\(..\)/\1 /g' | {
        read ch0 ch1 ch2 ch3;
        for ch in $ch3 $ch2 $ch1 $ch0; do
          printf '%s%03o' '\' $((0x$ch));
        done;
      }
  )
}
VMLINUX_MOD=vmlinux.bin
ZIMAGE_MOD=zImage
RUN_SIZE=$(objdump -h $VMLINUX_MOD | sh calc_run_size.sh)
unzip -o zImage_template.zip

dd if=zImage_template of=$ZIMAGE_MOD
dd if=$VMLINUX_MOD of=$ZIMAGE_MOD bs=16494 seek=1 conv=notrunc
file_size_le $VMLINUX_MOD | dd of=$ZIMAGE_MOD bs=15745134 seek=1 conv=notrunc
size_le $RUN_SIZE | dd of=$ZIMAGE_MOD bs=15745210 seek=1 conv=notrunc
file_size_le $VMLINUX_MOD | dd of=$ZIMAGE_MOD bs=15745244 seek=1 conv=notrunc
# cksum $ZIMAGE_MOD # https://blog.box.com/crc32-checksums-the-good-the-bad-and-the-ugly
size_le $(($((16#$(php crc32.php $ZIMAGE_MOD))) ^ 0xFFFFFFFF)) | dd of=$ZIMAGE_MOD conv=notrunc oflag=append
