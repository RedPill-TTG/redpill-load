# Documentation for developers

Currently, it's TBD. Look at examples in `config/` - more detailed docs will come soon.

The loader generator has facilities for creating new platforms by automatically repacking vmlinux into zimages. You do
it by initializing all submodules and running something along the lines of:

```shell
# 1. download kernel source from SF & unpack
# 2. synoconfigs/apollolake
# 3. run:
BRP_DEBUG=1 \
BRP_LINUX_PATCH_METHOD=repack \
BRP_BUILD_DIR=$PWD/build/testing \
BRP_LINUX_SRC=$PWD/linux-3.10.x \
./build-loader.sh 'DS3615xs' '6.2.4-25556'
```

### Platform config file format
A "template" config file for a new platform/OS will look something like below. See explanation of values below the JSON 
template.

```json
{
  "os": {
    "id": "<...>",
    "pat_url": "https://global.download.synology.com/....",
    "sha256": "<...>"
  },

  "files": {
    "zlinux": {
      "name": "zImage",
      "sha256": "<...>"
    },
    "ramdisk": {
      "name": "rd.gz",
      "sha256": "<...>"
    },
    "vmlinux": {
      "sha256": "<...>"
    }
  },

  "patches": {
    "zlinux": [ "file1.bsp" ],
    "ramdisk": [ "file2.patch" ]
  },

  "synoinfo": {
    "key": "value",
    "removekey": ""
  },

  "grub": {
    "template": "@@@COMMON@@@/grub-template.conf",
    "base_cmdline": {
      "sn": "124",
      "root": "/dev/md0"
    },

    "menu_entries": {
      "RedPill DSxxx v0.0-123456 (USB, Verbose)": {
        "options": [
          "savedefault",
          "linux /zImage @@@CMDLINE@@@"
        ],
        "cmdline": {
          "earlyprintk": null,
          "loglevel": 15
        }
      }
    }
  },

  "extra": {
    "compress_rd": false,
    "ramdisk_copy": {
      "redpill-linux-v4.4.180+.ko": "usr/lib/modules/rp.ko"
    },
    "bootp1_copy": {
      "@@@PAT@@@/GRUB_VER": "GRUB_VER"
    },
    "bootp2_copy": {
      "EFI": "EFI"
    }
  }
}
```

- `os` contains all things dealing with DSM PAT files
  - `id` contains a unique platform-install id (e.g. `ds3615xs_25556` for DS3615xs and OS build 25556)
  - `pat_url` is a publicly accessible URL to download PAT file, it's preferred to be from `global.downlaod.synology.com`
  - `sha256` is the SHA-256 sum of the downloaded file used for verification
- `files` section contains logically designated files used during the boot process; keys are statically defined
  - `zlinux` is the compressed Linux image
    - `name` contains name of the file in the unpacked PAT
    - `sha256` contains SHA-256 checksum of unmodified file
  - `ramdisk` is the original compressed ramdisk image
    - `name` contains name of the file in the unpacked PAT
    - `sha256` contains SHA-256 checksum of unmodified file
  - `vmlinux` is the unpacked `zlinux` image
    - As the file doesn't exist in the PAT directly there's no name specified
    - It is only used when repack method is used to build the kernel
    - `sha256` is the expected checksum of unpacked file before any modifications
- `patches` is the main section for any patches applied anywhere
  - `zlinux` contains an array of patch files (in `.bsp` / `bspatch(1)` binary format) to be applied to `files.zlinux.name` 
    **file** before copying it to the boot disk; see "File Paths" section below
  - `ramdisk` contains an array of patch files (in `.patch` / `patch(1)` text format) to be applied to a **directory**
    containing files unpacked from `files.ramdisk.name`; see "File Paths" section below
- `synoinfo` contains a list of key=>value pairs to change in the synoinfo configuration
  - Changes are made directly to the `/etc/synoinfo.conf` and `/etc.defaults/synoinfo.conf` in the ramdisk image
  - Dynamic patches are generated to make the same changes the main OS partition's files in `/etc/synoinfo.conf` and 
    `/etc.defaults/synoinfo.conf` just before its booted
  - Values specified in the platform config (files under `config/`) can be overridden by the user config
  - You can specify `"key": "value"` pairs to add/change value under `key` to `"value"` in configs, or use `"key2": null`
    to remove value under `key2` key.
- `grub` section contains everything to do with the new GRUB bootloader
  - `template` is a file for grub configuration file (see "File Paths" section below) used to generate the final file. 
    It should contain `@@@MENU_ENTRIES@@@` token where newly generated menu entries are pasted.
  - `base_cmdline` is a list of key=>value pairs which will be placed in the cmdline of **every single menu entry**. 
    This is done to avoid copying the same platform-dependent options for every menu entry.
  - `menu_entries` contains a list of menu entries in GRUB; each entry is a separate object containing the following 
    keys:
    - `options` is an array of strings exactly how you would put them in a GRUB **2** menu entry. It is only scanned for
      the `@@@CMDLINE@@@` variable which contains an assembled Linux cmdline key=>value pairs combining values from 
      `grub.base_cmdline` and `cmdline` in the given entry (see below)
    - `cmdline` is a list of key=>value pairs merged with `grub.base_cmdline` to create the `@@@CMDLINE@@@` variable
      mentioned above. You can specify `"key": "value"` to get `key=value` in the kernel cmdline, or use `"key2": null`
      to define a value-less parameter (e.g. `param1=val1 key2 param2=val2`)
- `extra` is a catch-all bag for everything which doesn't fit above ;) 
  - `compress_rd` specified if ramdisk image should be compressed or should be left as a flat CPIO archive. In general, 
    you always want the compressed one. However, some kernels have a syno-broken decompression routines and require a
    flat CPIO instead. To keep the consistency the ramdisk file will always be called `rd.gz` (regardless of the 
    compression type or lack thereof)
  - `ramdisk_copy` is a list of key=>value pairs containing source=>destination definitions of files/folders copied to
    the ramdisk. Don't go overboard here! Kernel has a hard-crash-limit for it. See "File Paths" section below for 
    supported variables.
  - `part1_copy` and `part2_copy` are lists of key=>value pairs containing source=>destination definitions of 
    files/folder copied to first/second partition of the bootloader image. See "File Paths" section below for supported 
    variables.
  - All file/directory copy operations are performed using `cp -rL` so that you can specify sources with symlinks which
    will be resolved on copy time.


### File Paths
The following platform places in the **platform** configuration file support special variables:
 - `patches.ramdisk` (the `zlinux` one doesn't support it as it doesn't make sense to share anything)
 - `grub.template`
 - `extra.ramdisk_copy`
 - `extra.bootp1_copy`
 - `extra.bootp2_copy`

In those places you can use some shortcut variables to grab files from some predetermined locations, avoiding symlink:
 - `@@@PAT@@@` points to a directory where PAT file was unpacked
 - `@@@COMMON@@@` points to `<repo-root>/config/_common`
 - `@@@EXT@@@` points to `<repo-root>/ext`
 
Specifying a path with no variable implies that the path lookup will start at the same place where the config is located
(which is in fact a variable `@@@_DEF_@@@` but it's an implementation detail and should NOT be used). We decided against
magical "path lookup order" logic and used variables as to not make the config opaque. When someone sees `@@@PAT@@@` 
they will either search in the repo for what that means (finding this explanation). Putting just the patch and searching
in order within multiple places can (and will) cause confusion and hard to debug scenarios.
