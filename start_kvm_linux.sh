#!/bin/bash

IMG=qemu-image.img

if [ -n "$1" ]; then
    IMG=$1
fi

qemu-system-x86_64 -kernel linux/arch/x86_64/boot/bzImage -hda $IMG -append "root=/dev/sda console=ttyS0" -device isa-debug-exit -serial stdio -display none --enable-kvm
