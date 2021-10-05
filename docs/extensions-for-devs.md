# RedPill Load Extensions - Developer's Documentation

This document is intended for those who want to create new extensions for RedPill Load. Before you start you should read
the [general overview document first](extensions-overview.md).

## Table of contents
1. [**Anatom of an extension**](#anatomy-of-an-extension)
   1. [Index file](#index-file)
   2. [Recipe file](#recipe-file)
      1. [Scripts environment]
2. [**Example extension**](#examples)
3. [**Why packages at all?**](#why-packages-at-all)


## Anatomy of an extension
The most basic extension consists of three files:

 1. Index file
 2. Recipe file
 3. File you're delivering to the target system

See below for details regarding these files and rationale behind them

### Index file
The index file is the heart of every extension and lists information about the extension itself. It does not contain any
details of *what the extension does*, it only says *what the extension is*. See the sample JSON below with all possible
options and comments below it:


```json
{
  "id": "developer_name.sample_name",
  "url": "http://raw.githubusercontent.com/amazing-dev/sample-name/master/rpext-sample_name.json",
  "info": {
    "name": "Sample Extension",
    "description": "Sample description for the sample extension",
    "author_url": "https://anotherexample.tld/about_sample.html",
    "packer_url": "https://github.com/amazing-dev/sample-name",
    "help_url": "https://example.tld/forum/amazing-sample-extension.html"
  },
  "releases": {
    "ds3615xs_25556": "http://raw.githubusercontent.com/amazing-dev/sample-name/master/recipes/v6.json",
    "ds3615xs_41222": "http://raw.githubusercontent.com/amazing-dev/sample-name/master/recipes/v7.json",
    "ds918p_25556": "http://raw.githubusercontent.com/amazing-dev/sample-name/master/recipes/v6.json",
    "ds918p_41890": "http://raw.githubusercontent.com/amazing-dev/sample-name/master/recipes/v7.json"
  }
}
```

Below are description of fields & recommendations. All fields marked with `*` are required.
 
 - `id`*: unique ID of the extension. The name **MUST NOT** contain spaces. In general, we limit the name to contain 
         ASCII letters (`A-Z`, `a-z`), numbers (`0-9`), underscores (`_`), dashes (`-`), and periods/dots (`.`). The 
         `id` must start with a letter or number. We recommend the ID to be in a format `developer_name.extension_name` 
         to avoid conflicts.
 - `url`*: URL to the JSON index file (the one you're creating). This URL is used to check the updates for the index 
           file itself. It will be queried every time an image is built by anyone. We recommend using GitHub raw URLs, 
           as it's a perfect static hosting for text files which aren't very large.
 - `info`*: section containing all user-readable information
   - `name`*: human-readable name of the extension. Unlike `id` this one can contain any characters. While we don't 
              limit what can be put here you should probably stay away from new lines or non-ASCII characters (as not 
              all terminals can display them) unless your extension is only usable by non-English speaking users.
   - `description`: human-readable short description of what the extension is for. The same character constrains apply
                    here as in `name`. *This field is optional*
   - `author_url`: URL for the author of the extension itself (i.e. code). This is presented to users as the place to
                   check for help with e.g. supported hardware etc. *This field is optional*
   - `packer_url`: URL to direct users to any packer (i.e. person who prepared the extension for RedPill) website/page.
                   Usually we expect that URL to point to a GitHub project where packers can share all the details 
                   needed. *This field is optional*
   - `help_url`*: A required field containing a URL to a place where users can get help with the extension. In some 
                  cases we can detect that problem arose because of the extension being broken (e.g. broken recipe file)
                  and not because the extension manager problem. In such cases we instruct users to go there instead of
                  creating an issue in the manager repository. This URL should lead to either GitHub issues page or some
                  forum thread.
 - `releases`*: List of platforms supported by the extension
   - Every key specifies platform code. This code is the same as used by the files in `config/<HW>/<OS>/config.json` 
     files. This is how the `redpill-load` knows which version to pick for a given loader image being built
   - Every value is a URL to so-called *recipe file*. The recipe file describes what the extension does and how it 
     should do things. See section below for details.
   - Each release can have a unique URL, or the URL can be shared between different releases/platforms. In case of 
     drivers (i.e. kernel modules) you have no choice other than having unique recipes per platform as kernel modules
     are unique per kernel version. However, if multiple software versions share the same kernel you can *sometimes* get
     away with using the same binary extensions. However, keep in mind even if the kernel VERSION didn't change it DOES
     NOT mean that syno didn't change the kernel (yup, that's stupid, we know). The only way is to look at the 
     compilation date.
   - For extensions containing no kernel modules you most likely will use one recipe or one recipe per major version (
     like in the example above). This is useful for e.g. an extension which change CPU governor (power management).
   - We recommend hosting these files on GitHub raw, as these are small text files. They will be downloaded every time
     someone builds a loader image for a given platform. 


### Recipe file
Recipe file (listed under `releases` in the index file; see section above) define *what the extension does* and how it
should be done. As with cooking, recipes are the heart of the extension listing all ingredients and setting the rules
of how things are loaded. See the sample JSON below with all possible options and comments below it:

```json
{
  "ext_version": "v1",
  "files": [
    {
      "name": "check-hardware.sh",
      "url": "http://raw.githubusercontent.com/amazing-dev/sample-name/master/scripts/check-hardware.sh",
      "sha256": "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
      "packed": false
    },
    {
      "name": "kernel-modules.tgz",
      "url": "https://github.com/amazing-dev/sample-name/releases/download/v1/sample_name-kmod-3.10.105.tgz",
      "sha256": "beefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdead",
      "packed": true
    }
  ],

  "kmods": {
    "base.ko": "",
    "some_other.ko": "version=1 do_a_backflip=yes"
  },

  "scripts": {
    "on_boot": "set-cpu-speed.sh",
    "check_kmod": "check-hardware.sh",
    "on_os_load": "disable-syno-cpu.sh"
  }
}
```

Below are description of fields & recommendations. All fields marked with `*` are required.

 - `ext_version`: optional version information about the extension. You can put anything here (or not have it at all)
 - `files`*: list all your files & collections of files packed into the loader image
   - this array can contain as many files as you want, but it's a good practice to pack large sets of files (see below)
   - all fields (`name`, `url`, `sha256`, and `packed`) are required
   - entries of packed and non-packed files can be mixed
   - flat files (`"packed": false`)
     - they're simply downloaded from the `url` given and copied into the loader image under name specified in `name`
     - your `name` must be unique across all the files you specified (including these unpacked from all packed ones). 
       All file names **MUST** only contain contain ASCII letters (`A-Z`, `a-z`), numbers (`0-9`), underscores (`_`), 
       dashes (`-`), and periods/dots (`.`). If you use use a space anywhere things will break really badly due to 
       simplifications we had to take in the code executed in the pre-boot environment (more on that in scripts section
       ). 
     - `sha256` is mandatory to ensure we didn't accidentally get a wrong file because e.g. github broke and served 
       "404 Not Found" with `HTTP/200` code (as we saw before)
   - packed archives (`"packed": true`)
     - `name` here doesn't really matter, it can be anything sensible (as it will be unpacked). However, files inside 
       of the archive **MUST** be named with the same constrains as for "flat files" (see above)
     - if you have multiple binary files you can pack them into a single archive (e.g. what we do with VirtIO extension
       which has many kernel extensions). Such archive will be downloaded and unpacked to your extensions' directory in
       the loader image. The archive will be unpacked **without** folder structure for security (and consistency) 
       reasons. If you pack your archive with folders they will be ignored and all files from them will unpack to a 
       single directory anyway. This is by design.
     - Be mindful of the size: the loader image isn't big
     - The archive can be anything what `tar -x` can unpack. To be most compatible you should probably stick to `tar.gz`
     - `sha256` is mandatory so we can detect corruptions. This also serves as an additional feature: if you're simply
       replacing the file without changing the URL you will replace the `sha256` and thus extension manager will know to
       re-download the file as the recipe file changed.
   - `url` should be any http(s) source. You can use anything [curl](https://curl.se) understands in general. If you are
     hosting a small text file (e.g. a script shared between different recipes) you **can** use GitHub raw URLs. 
     However, if you're downloading binary files and/or something larger (like >few KB, especially packed archives) 
     **do not** use these and use GitHub releases feature instead. GitHub is known to simply block repos which start
     hosting binary files in repos and offer downloads for them (as this puts annoying load on their services as git
     itself was never designed for that).
 - `kmods`: optional section listing kernel modules which should be loaded by the RedPill upon system boot
   - All kernel modules will be loaded in the pre-boot environment, so that you can include drivers e.g. for LAN card
   - Each key is the name of the `.ko` kernel module file. Modules are loaded in that exact order.
   - Each value is a string of [kernel module arguments](https://stackoverflow.com/questions/11035119/). Most modules 
     don't need that but some require it.
   - This section is optional since the extension may not deliver any kernel modules but just scripts.
   - Before the first kernel module from the list is loaded the script specified in `check_kmod` is executed. This is
     useful if the extension is only useful for most hardware platforms but not all (e.g. our VirtIO module).
 - `scripts` defines all scripts
   - All keys in this section are pre-defined script types (currently all unknown ones are simply ignored)
   - All values are script file names which should exist within `files` download (either flat/`packed: false` or 
     unpacked from archives)
   - The whole `scripts` section is optional, as an extension can deliver only kernel modules
   - See next section for details about scripts executeion environment
   - The following types/keys are defined:
     - `on_boot`: executed as soon as the system boots in the preboot environment and hardware is ready. No drives are 
                  mounted at this stage but all kernel modules have been loaded. If extensions kernel modules loading
                  fails `on_boot` scripts will not be executed.
     - `check_kmod`: executed before kernel modules for your extension are loaded. If your script returns with exit code
                     of `0` kernel modules defined in `kmods` will be loaded. When it returns anything else (e.g. `1`)
                     loading of modules defined in `kmods` will be skipped. We use this feature in VirtIO to check if 
                     the system we're running has VirtIO hardware.
     - `on_os_load`: executed after the system disk is mounted, just before starting the full OS boot. This script will
                     NOT execute if the system is not installed.


### Scripts execution environment
Scripts defined here are executed by a basic busybox POSIX shell, so the syntax is very basic and limited (e.g. we 
painfully miss arrays). You should use the standard `#!/bin/sh` shebang for most portability. Your script will
be run in a separate shell instance and within the extension directory. All scripts are run from a read-only partition.
You should not try to circumvent that as the loader may be e.g. network booting. In practice it's usually a ramdisk.

Any script will be passed two variables:
 - `PLATFORM_ID`: id of the platform the script is running for (e.g. `ds3615xs_25556`)
 - `EXT_NAME`: extension ID (e.g. `developer_name.sample_name`), useful when you're reusing the same script across many
               extensions


## Examples?
As we believe in [*eating or own dog food*](https://en.wikipedia.org/wiki/Eating_your_own_dog_food) we moved the, 
previously hardcoded, VirtIO module to an extension. See the GitHub project for details: 
[https://github.com/RedPill-TTG/redpill-virtio](RedPill-TTG/redpill-virtio)

In addition, we also published a simple script-only extension which forces the system to wait for `/dev/synoboot` to be
ready before continuing the boot process. For details why see [https://github.com/RedPill-TTG/redpill-boot-wait](RedPill-TTG/redpill-boot-wait).


## Why packages at all?
Previously used loader by the community (Jun's loader) used a system of a single ramdisk-like `extra.lzma` archive. This
method, while worked, lacked flexibility and required hand-assembly by the packers. As we observed this lead to multiple
versions of the whole loader image floating around - some with VirtIO, some with ethernet drivers, some with SAS HBA
drivers, some with VirtIO **and** SAS HBA... Additionally, while reporting problems on the forum people usually reported 
whether they "used extra.lzma" which without the context was limited in information. In addition, to add extra 
functionality beyond kernel modules, a custom hacks had to be developed.

The extension management shipping with the `redpill-load` hopes to alleviate the pain of packing and managing all
extensions and mods. We set the following objectives while developing the current version:

 - as simple and as automated as possible for users
   - in practice users need only a single `add` command and a URL to add an extension
   - we're planning a better discoverability with a list of all known extensions
   - updates are checked any time a user builds a new image
   - updates are offered not only on per-platform basis but extension can be updated for the currently existing platform
   - if no interdependent extensions are installed users don't need to do a thing as by default all added extensions
     are added to the image
 - easy for developers/packers
   - the most basic extension requires 3 files: index file, recipe file, and the file which is delivered
   - JSON configs were organized such that it's easy to maintain a repo with multiple versions of them (more on that 
     above in rationales sections)
   - the structure is designed for maximum reusability and easy
 - error-proof
   - most errors are meant to be self-fixable (even if user caused them)
   - when an error is displayed it tries to offer a reason and a possible way to fix it (like in `git`)
   - all extensions offer multiple links pointing users to the correct place (do they have a problem with USING 
     the extension? or maybe they have a problem with it being unstable? or maybe they want to see the forum thread
     where they can ask the author questions? => it's all supported)
   - the code will prevent users from updating if extensions they rely on are not updated (as what's the point of 
     updating to a new OS release if your ethernet driver doesn't work yet?)
 - flexible in nature
   - at first, we jotted the idea as delivering kernel extensions/drivers, but we quickly realized it's not enough
   - the current (early) version allows for pretty much any customization of the OS before it's booted with custom
     scripts
   - current implementation is more a PoC (that's why it's a messy shell script monstrosity), but with feedback can be
     eventually built to a much higher standard
 - decentralized
   - we don't want to exert any control or force anyone to do anything: this is our goal from the beginning
   - the extension manager is designed to be not only open-source but open in nature. We deliberately don't offer any 
     centralized repository and simply rely on community and the trust within it to offer a quality contribution
