Create your own device tree binary.

```shell
dtc -I dtb -O dts -o output.dts model.dtb
cat /sys/block/sataX/device/syno_block_info
nano output.dts
dtc -I dts -O dtb -o model_r2.dtb output.dts
```
