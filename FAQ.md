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
## Nothing is printed after `Booting the kernel.`
It's perfectly normal. DSM kernels are built without display support and log everything using serial ports. You will
not see any kernel output on the physical screen. As far as we know this isn't something fixable without kernel 
recompilation.

## Serial0 stops updating after `bootconsole [uart0] disabled`
The kernel has two different consoles: earlycon and normal console. This is the moment it switches to the normal console
from the "earlycon". For Linux v4 the console is set for Serial2 (3rd serial port), for Linux v3 it is set to Serial1
(2nd serial port). As mfgBIOS is hardcoded to use `ttyS0` we cannot use the first serial port for kernel.

There's also some weirdness with swapping serial 0 & 1 making `ttyS1` unavailable on Linux v4. This is fixable, but as
of now it's a low priority bug.

## Boot stops at `clocksource: Switched to clocksource tsc`
Wait, on some systems it may take ~30s to progress.


## Misc
### Why is this written in BASH?!
We ask the same question... it was a huge mistake, leading to spaghetti code. But when we realized it was a mistake it 
was too late to scrap everything and start from scratch. Consider this version an MVP.

We will most likely rewrite it in Python or PHP, as both of these are easily installable or already available in 
modern-ish versions in distros.
