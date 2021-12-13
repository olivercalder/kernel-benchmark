#!/bin/sh

# rustup must be installed
command -v rustup > /dev/null || { echo "ERROR: rustup not installed; install from https://www.rust-lang.org/tools/install"; exit 1; }

CWD=$(pwd)

if [ ! -d rusty-nail ]; then
    git clone https://github.com/olivercalder/rusty-nail
fi

cd rusty-nail
cargo clean
cargo build --release

cd "$CWD"
