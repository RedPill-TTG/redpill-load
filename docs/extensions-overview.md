# RedPill Load Extensions

## Table of contents
1. [**Overview**](#overview)
2. [**Managing extensions**](#managing-extensions) (i.e. *"how do I do X?"*)
   1. [Installing extensions](#addinginstalling-new-extensions)
   2. [Removing extensions](#removing-existing-extensions)
   3. [Listing installed & information](#getting-information-about-extensions)
   4. [Other commands](#other-commands)
3. [**Troubleshooting problems**](#troubleshooting-problems)
4. [**Creating extensions**](#creating-extensions)
5. [**Bundled extensions**](#bundled-extensions)


## Overview
The loader contains a rudimentary (at least for the time being) support for custom extensions. The main design goal of 
the extension system is the ease of use & sharing of custom extensions. This file contains an overview indented for both
extensions developers/packers and users of extensions.

Currently, extensions can:
 - run scripts on boot (but before OS loads)
 - run scripts after OS partition is mounted
 - load custom kernel extensions (e.g. drivers for unsupported hardware)


## Managing extensions
All extensions are managed automatically (and this is *the* only supported way). All operations are carried via the
`ext-manager.sh` script. If you're using a custom package of the loader (e.g. via Docker) refeer to its documentation to
learn how to invoke `ext-manager.sh` there.

**Extensions have 3 parts to them:**
 - **Index file**: contains information about the extension and a list of supported platforms (hw version + OS version)
 - **Platform recipe**: contains information about files for a given platform, kernel modules to load, and scripts to
   run in different times of the boot process. As a user you shouldn't worry about this.
 - **Platform files**: all files for a given extension & platform. As a user you shouldn't worry about this.


### Adding/installing new extensions
To install extension you need to know its index file location and nothing more. To install an extension do:

```shell
./ext-manager.sh add 'https://example.com/some-extension/rpext-index.json'
```

If everything went successfully you should see something like that:
```

```

### Removing existing extensions
To remove an already installed extension you need to know its ID (see next section). To remove an extension do:

```shell
./ext-manager.sh remove 'example_dev.some_extension'
```

### Removing existing extensions
To remove an already installed extension you need to know its ID (see next section). To remove an extension do:

```shell
./ext-manager.sh remove 'example_dev.some_extension'
```

If everything went successfully you should see something like that:
```

```

### Getting information about extensions
To get a list of all extensions and detailed information about them do:

```shell
./ext-manager.sh info
```

***Tip:** You can also get information about a single extension using `./ext-manager.sh info 'example_dev.extension1'`* 


### Other commands
There are more commands available. See `./ext-manager.sh help` to see all of them.


## Using extensions
Once added/installed extensions are available to be embedded into the loader image. This process is automatic. By 
default all extensions are loaded in pseudo-random order (independent of installation order etc). Additionally, if you
use `redpill-load` to generate multiple images for multiple platforms you may want to only load some modules on one
platform but not on others.

To solve all these problems `redpill-load` allows for a list of extensions to be specified in `user_config.json` file
as shown below:

```json
{
  "extra_cmdline": {
    "sn": "AXYZNA12354FA",
    "mac1": "abcdef123456"
  },

  "extensions": [
    "thethorgroup.virtio",
    "example_dev.example_extension"
  ]
}
```

Specifying a list under `extensions` guarantees that only these extensions on the list will be included in the image. 
Additionally, extensions will be loaded in that exact order as specified in the `extensions` list.


## Troubleshooting problems
Extensions manager was written to tell you where the problem may be. If you're seeing a weird issue these are the things
to try **in order**:
 1. Run `./ext-manager.sh update` (attempts to update all extensions indexes)
 2. Run `./ext-manager.sh cleanup` (remove all cached files for all platforms)
 3. Read the extension documentation from the developer/packer (use `./ext-manager.sh info` to find it)
 4. Remove everything from `custom/extensions/` folder (removes ALL installed extensions - you WILL NEED TO re-add them 
    again, so make sure you have a list)
 5. Report a bug with either the extension developer/packer or `redpill-load`


## Creating extensions
See [Extensions - For Devs](extensions-for-devs.md) document.  
Currently, there's no way to add scripts without creating an extension. However, 
this is something we have on our roadmap to allow one-off scripts to be added by users themselves. But, look at the 
bright side - if you create an extension others can use it too! :)


## Bundled extensions
Some base functionality of the RedPill is implemented using extensions to make things more modular. These extensions are
always installed. When removed they will be reinstalled automatically upon image creation. These extensions are 
autoconfigured from the `bundles-exts.json` file. It's **not** recommended to change that file unless you know what 
you're doing.  
In addtion these extensions are always loaded first, before any user-installed extensions.
