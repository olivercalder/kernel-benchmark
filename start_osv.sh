#!/bin/sh

# This does not work, as there are problems with permissions, mounting the
# virtual image, and other issues. This is a placeholder suggestion for the
# general way of running an OSv image.

./osv/scripts/run.py -e "rusty-nail /mnt/$IMAGE /mnt/$THUMBNAIL $WIDTH $HEIGHT $CROP" \
    --virtio-fs-dir localimages \
    --virtio-fs-tag mydir

# Need to do something like:
#   mount -t virtiofs mydir /mnt
# first in the OSv guest, perhaps by including that at the beginning of the -e argument.
