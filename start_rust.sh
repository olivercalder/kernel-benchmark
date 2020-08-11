#!/bin/bash

qemu-system-x86_64 -drive format=raw,file=rust-kernel/test_os/target/x86_64-test_os/release/bootimage-test_os.bin
