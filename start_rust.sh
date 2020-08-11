#!/bin/bash

qemu-system-x86_64 -drive format=raw,file=rust-kernel/test_os/target/x86_64-test_os/release/bootimage-test_os.bin -device isa-debug-exit,iobase=0xf4,iosize=0x04 -serial mon:stdio -display none

# 0xf4 is used to communicate exit codes to qemu
