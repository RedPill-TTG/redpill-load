### !!! WARNING - READ ME !!! ###

This directory is automatically managed by the extension manager. DO NOT try to change/move/delete/add any files
here. If someone told you to do that they're wrong. Don't do that. Don't ignore this warning as things WILL break
unexpectedly.

## What if I do?
Any bug reports resulting from modifications of the contents of this directory will be closed as invalid. You're on your
own.

## Isn't that just a directory packed with gzip?
No, it is not. If you unpacked this readme from a .gz file you relied on a smartiness of your packer. This is not your
standard .gz file. This archive is different depending on the platform. It can be a flat CPIO, it can be an XZ+CPIO,
LZMA+CPIO etc. All in all it's an aligned and specially crafted initramfs layer loaded to the memory by GRUB and layered
over with the base image. Don't mess with it unless you REALLY know what you're doing.
If you found this readme in a filesystem you should know you're reading it from RAM - any changes you make here will be
erased as soon as you reboot.

## But why?
This is because the automation layer creating the contents of this directory implements many safety checks. These
 checks allow for code in this directory to be much simpler as it can assume what is the structure of things. By
 modifying anything here you're breaking that promise.
