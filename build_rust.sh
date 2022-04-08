#!/bin/sh

# rustup must be installed
command -v rustup > /dev/null || { echo "ERROR: rustup not installed; install from https://www.rust-lang.org/tools/install"; exit 1; }
command -v qemu-system-x86_64 > /dev/null || { echo "ERROR: please install qemu-system"; exit 1; }

CWD=$(pwd)

DEFAULT_PIPE="io_pipe"

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

send_image () {
    echo > "$DEFAULT_PIPE.in"
    cat "$1" > "${DEFAULT_PIPE}.in"
}

cd rust-kernel/test_os
git checkout benchmark
mkfifo ${DEFAULT_PIPE}.in ${DEFAULT_PIPE}.out
cargo clean
send_image img.png &
cargo run --release # compile the rust kernel using cargo run in order to build bootimage

cd "$CWD"
