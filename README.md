# RedPill Loader Builder

This project is a complete package which is able to generate RedPill loader images.

## Is it stable?
No. It is not yet stable. DO NOT use it if you're not ready for random crashes and potentially loosing your data (it 
didn't happen to us but hey...).

## How to use it?
1. Make sure you're running Linux
2. Compile RedPill LKM and place it in `ext/rp-lkm/redpill-linux-<VERSION>.ko` (see platform config for details)
3. Create `user_config.json` which contains at minimum (for USB boot):

    ```json
    {
      "extra_cmdline": {
        "vid": "<fill me>",
        "pid": "<fill me>",
        "sn": "<fill me>",
        "mac1": "<fill me>"
      }
    }
    ```

 - We cannot help you obtain the S/N
 - VID/PID correspond to your USB stick vendor id and product id (google: `vid pid usb drive`)
 - If you're running QEmu-based virtualization (e.g. Proxmox or VirtualBox) set `vid` to `0x46f4` and `pid` to `0x0001`
 - If you're running SATA-based boot you can skip `vid` and `pid` fields (just remove them)
 - `mac1` is the MAC address of your first ethernet interface
 - If you want to add more ethernet cards simply put `mac2`/`mac3`/`mac4` and `netif_num` to the number of card
 - `synoinfo` is a key=>value structure where you can override any `synoinfo` options (e.g. `"SataPortMap": "..."`)
 - If you want to see all options available take a look at [`user_config.FULL-EXAMPLE.json`](user_config.FULL-EXAMPLE.json)

3. Run `./build-loader.sh <hw_version> <os_version>` (e.g. `./build-loader.sh 'DS918+' '6.2.4-25556'`)  
It will download all files needed and complain if something isn't right

4. Burn the image onto a USB stick  
When asked for PAT file during OS installation you can use PAT file from `cache/` directory - it's downloaded from the
official CDN automatically to build the loader anyway.


## Architecture
The loader builder is very flexible and derives most of its behavior from config files. There are two main files used
while the code is run: platform config (`config/<hardware>/<OS version>/config.json`) and user config 
(`./user_config.json`). Most of the stuff is self-explanatory.

For more detailed information go to [`FOR_DEVS.md`](./FOR_DEVS.md).

## Rough TODO
 - RP modules should be downloaded automatically from GH releases
 - Compile VirtIO and provide in a separate repos
 - Dev docs
 - Support for additional drivers packages like in Jun's loader
 - Docker
