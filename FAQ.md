# Frequently Asked Questions & Problems (FAQ)

## Building the loader
### Can it be run on Windows?
Most likely it will work with WSL. However, none of us uses Windows. In the future a docker image will be provided.

### Can it be run on macOS?
Probably, but not natively. There are two roadblocks:
 - The code uses Linux-specific things (e.g. `losetup`)
 - BASH provided by macOS is ANCIENT and doesn't support a lot of features we use

### It crashes with "keys_unsorted" error
Make sure your `jq` is at least v1.5 (some distros have an older v1.4 release).


## Running the image
### Nothing is printed after `Booting the kernel.`
It's perfectly normal. DSM kernels are built without display support and log everything using serial ports. You will
not see any kernel output on the physical screen. As far as we know this isn't something fixable without kernel 
recompilation.

### Serial0 stops updating after `bootconsole [uart0] disabled`
The kernel has two different consoles: earlycon and normal console. This is the moment it switches to the normal console
from the "earlycon". For Linux v4 the console is set for Serial2 (3rd serial port), for Linux v3 it is set to Serial1
(2nd serial port). As mfgBIOS is hardcoded to use `ttyS0` we cannot use the first serial port for kernel.

There's also some weirdness with swapping serial 0 & 1 making `ttyS1` unavailable on Linux v4. This is fixable, but as
of now it's a low priority bug.

### Boot stops at `clocksource: Switched to clocksource tsc`
Wait, on some systems it may take ~30s to progress.

## Early kernel panic with "No filesystem could mount root"
If you get something like this while running in virtualized environment:
```
[....] RAMDISK: lzma image found at block 0
[....] tsc: Refined TSC clocksource calibration: 3292.538 MHz
[....] Switching to clocksource tsc
[....] RAMDISK: EOF while reading compressed data
[....] unexpected EOF
[....] EXT3-fs (md0): error: unable to read superblock
[....] EXT2-fs (md0): error: unable to read superblock
[....] EXT4-fs (md0): unable to read superblock
[....] List of all partitions:
[....] 0860          131072 sdg  driver: sd
[....]   0861           49152 sdg1 f110ee87-01
[....]   0862           76800 sdg2 f110ee87-02
[....]   0863            4096 sdg3 f110ee87-03
[....] 0870        33554432 sdh  driver: sd
[....] No filesystem could mount root, tried:  ext3 ext2 ext4
[....] Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(9,0)
```

You should know this is a bug somewhere between host kernel and hypervisor. This is intermittent and usually happens 
when you try to quickly power-cycle (using ACPI reset) the VM. It's nothing specific to this loader and happens with
other OSes too. We weren't able to isolate the cause. The fix is simple - stop the VM, wait 5-10 second and start it 
again. Magically the problem will solve itself.

If it doesn't go away make sure to read the log up carefully as you may have e.g. initramfs unpack bug (see below).


### Initramfs cannot be unpacked
If during boot you get something like log below:

```
[....] Trying to unpack rootfs image as initramfs...
[....] decompress cpio completed and skip redundant lzma
[....] rootfs image is not initramfs (unexpected EOF); looks like an initrd
```

If you've just added a new platform you just stepped into a [known syno kernels bug](https://github.com/RedPill-TTG/dsm-research/blob/master/quirks/ramdisk-checksum.md#recreating-ramdisks).
You need to generate CPIO instead of LZMA ramdisks (see [`FOR_DEVS.md`](FOR_DEVS.md) for details) for this OS version.

## Misc
### What's the deal with fake `modprobe`?
Loading kernel modules is complex. However, in short there are two distinct ways for them to load: from userspace or
from kernel space. The latter is kind of misleading since the kernel, after doing some checks, calls /sbin/modprobe to
actually load the module (see `kmod.c`). This path is hardcoded in the kernel. Usually it's a symlink to a kmod utility
which uses userspace syscalls to load the module.

Here comes the less-intuitive part. RedPill LKM is loaded on the **kernel's request**. It happens because we specify
the `elevator=elevator` boot param. This causes kernel to, very early in the boot process (in fact still being in the
formal init-before-boot stage), request module named `elevator-iosched`. There's nothing special in that name - it can
be anything as long as the userspace and cmdline agree on the name. Our [fake `modprobe`](config/_common/iosched-trampoline.sh)
checks (very loosely) if the requested module is `elevator-iosched` and triggers the standard force-insmod, then deletes
itself. Keep in mind that our "modprobe" isn't actually overriding anything - preboot environment contains no `modprobe`
as it has no concept of depmods (=modprobe would be useless).

Using I/O scheduler loading method over `insmod`ing it in init allows us to load the LKM much earlier. While by itself
it has advantages of simply being faster, it also carries another **very important** advantage: I/O scheduler, as
mentioned earlier, is loaded **during init stage**. This means we can safely call methods which are marked with `__init`
and potentially removed after init finishes (which is in fact [what prompted that rewrite](https://github.com/RedPill-TTG/redpill-lkm/issues/10)).

### Why is this written in BASH?!
We ask the same question... it was a huge mistake, leading to spaghetti code. But when we realized it was a mistake it 
was too late to scrap everything and start from scratch. Consider this version an MVP.

We will most likely rewrite it in Python or PHP, as both of these are easily installable or already available in 
modern-ish versions in distros.
