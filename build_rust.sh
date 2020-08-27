#!/bin/sh

# rustup must be installed
command -v rustup > /dev/null || { echo "ERROR: rustup not installed; install from https://www.rust-lang.org/tools/install"; exit 1; }
command -v qemu-system-x86_64 > /dev/null || { echo "ERROR: please install qemu-system"; exit 1; }

CWD=$(pwd)

# If the rust-kernel directory does not yet exist, clone it, and set up the Rust compiler
if [ ! -d rust-kernel ]; then
    git clone https://github.com/olivercalder/rust-kernel
    rustup toolchain install nightly
    cargo install bootimage
    cd rust-kernel/test_os
    rustup component add rust-src
    rustup component add llvm-tools-preview
    cd ../..
fi

waittokillqemu () {
    while true; do
        kill $(ps -aux | grep "qemu-system-x86_64" | grep "bootimage-test_os.bin" | awk '{print $2}') 2> /dev/null && break
        sleep 1
    done
}

cd rust-kernel/test_os
cargo clean
waittokillqemu &            # run waittokillqemu in the background
time cargo run --release    # compile the rust kernel using cargo run in order to build bootimage (and time it for fun)

kill "$(ps -aux | grep waittokillqemu | awk '{print $2}')" 2> /dev/null    # kill the sleeping task if the compile failed

cd "$CWD"
