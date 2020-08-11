#!/bin/bash

# flex and bison must be installed
which flex > /dev/null || { echo "ERROR: please install flex"; exit 1; }
which bison > /dev/null || { echo "ERROR: please install bison"; exit 1; }
which debootstrap > /dev/null || { echo "ERROR: please install debootstrap"; exit 1; }
which qemu-system-x86_64 > /dev/null || { echo "ERROR: please install qemu-system"; exit 1; }

# If the linux directory does not yet exist, clone it
if [ ! -d linux ] && [[ $(basename $(pwd)) != "linux" ]]; then
    git clone -b v5.8 --depth=1 https://github.com/torvalds/linux.git
fi

CWD=$(pwd)

if [ -d linux ]; then
    cd linux
fi

make clean
make x86_64_defconfig   # make generic config file
make kvm_guest.config   # modify config file for kvm
time make -j $(grep -c "processor" /proc/cpuinfo) || { echo "ERROR: please install libelf-dev and libssl-dev"; exit 1; }
# compile the kernel using all CPU threads (with timing, for fun), and if compilation fails, warn about libelf and libssl

cd ..

IMG=qemu-image.img
DIR=mount-dir

if [ -f $IMG ]; then
    echo "WARNING: $IMG already exists. Overwrite it? [N/y]"
    read RESP
    if [[ "$RESP" == "y" ]]; then
        rm $IMG
    else
        echo "$IMG unchanged."
        cd $CWD
        exit 0
    fi
fi

qemu-img create $IMG 1g     # create a qemu disk image
mkfs.ext2 $IMG      # ext2 is simple and fast, not journaled
mkdir -p $DIR
sudo mount -o loop $IMG $DIR    # uses a loop device to map the disk image to the directory
sudo debootstrap --arch amd64 buster $DIR   # install a minimal Debian Buster system
sudo chroot $DIR passwd -d root     # remove root password
sudo umount $DIR
rmdir $DIR

cd $CWD