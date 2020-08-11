#!/bin/bash

# Based on the instructions from https://www.collabora.com/news-and-blog/blog/2017/01/16/setting-up-qemu-kvm-for-kernel-development/

IMG=qemu-image.img

if [ -n "$1" ]; then
    IMG=$1
fi

exit 0

DIR=mount-point.dir
mkdir -p $DIR
sudo mount -o loop $IMG $DIR    # uses a loop device to map the disk image to the directory
sudo chroot $DIR
sudo umount $DIR
rmdir $DIR
