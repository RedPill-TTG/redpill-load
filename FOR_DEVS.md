# Documentation for developers

Currently, it's TBD. Look at examples in `config/` - the docs will come soon.

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
