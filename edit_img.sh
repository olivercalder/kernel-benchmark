#!/bin/bash

# Based on the instructions from https://www.collabora.com/news-and-blog/blog/2017/01/16/setting-up-qemu-kvm-for-kernel-development/

[ -n "$1" ] && IMG=$1 || IMG=qemu_image.img

DIR=mount-point.dir
mkdir -p $DIR
sudo mount -o loop $IMG $DIR    # uses a loop device to map the disk image to the directory
sudo chroot $DIR
sudo umount $DIR
rmdir $DIR
