#!/bin/sh

# flex and bison must be installed
command -v flex > /dev/null || { echo "ERROR: please install flex"; exit 1; }
command -v bison > /dev/null || { echo "ERROR: please install bison"; exit 1; }
command -v qemu-system-x86_64 > /dev/null || { echo "ERROR: please install qemu-system"; exit 1; }

# If the linux directory does not yet exist, clone it
if [ ! -d linux ] && [ "$(basename "$(pwd)")" != "linux" ]; then
    git clone -b v5.8 --depth=1 https://github.com/torvalds/linux.git
fi

CWD=$(pwd)

if [ -d linux ]; then
    cd linux
fi

make clean
make x86_64_defconfig   # make generic config file
make kvm_guest.config   # modify config file for kvm
time make -j "$(grep -c "processor" /proc/cpuinfo)" || { echo "ERROR: please install libelf-dev and libssl-dev"; exit 1; }
# compile the kernel using all CPU threads (with timing, for fun), and if compilation fails, warn about libelf and libssl

cd ..

echo "Create new Debian disk image for qemu? [N/y] "
read -r RESP
if [ "$RESP" = "y" ]; then
    sh create_image.sh
fi

cd $CWD
