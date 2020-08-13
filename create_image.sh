#!/bin/bash

[ -n "$1" ] && IMG=$1 || IMG=qemu_image.img
DIR="/tmp/mount_dir-$(date +%s%N)"

[[ "$(echo "$IMG" | sed -r 's/.*(.{4})/\1/')" == ".img" ]] || { echo "ERROR: image file must have suffix .img"; exit 1; }

echo "Building $IMG..."

which debootstrap > /dev/null || { 
    echo "ERROR: please install debootstrap"
    echo "    If not on a Debian-based system, a pre-built image is available at"
    echo "    https://calder.dev/qemu_image.img"
    exit 1
}

if [ -f $IMG ]; then
    echo "WARNING: $IMG already exists. Overwrite it? [N/y] "
    read RESP
    if [[ "$RESP" == "y" ]]; then
        rm $IMG
    else
        echo "$IMG unchanged."
        exit 0
    fi
fi

qemu-img create $IMG 1g     # create a qemu disk image
mkfs.ext2 $IMG      # ext2 is simple and fast, not journaled
mkdir -p $DIR
sudo mount -o loop $IMG $DIR    # uses a loop device to map the disk image to the directory
sudo debootstrap --arch amd64 buster $DIR   # install a minimal Debian Buster system
sudo chroot $DIR passwd -d root     # remove root password
sudo chroot $DIR rm /etc/hostname   # remove hostname so that it is always localhost
sudo umount $DIR
rmdir $DIR
