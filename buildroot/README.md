# Build

```shell
git clone git://git.buildroot.net/buildroot
cd buildroot
# copy custom files
make syno_defconfig
make
# get bzImage rootfs.cpio.lzma
ls output/images
```

[see .github/workflows/buildroot.yml](../.github/workflows/buildroot.yml)