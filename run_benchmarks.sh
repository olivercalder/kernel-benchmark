#!/bin/bash

# Linux (non-kvm)
run_linux() {
    bash benchmark_linux.sh -o linux-results-r$1.txt -p linux-output-r$1 -i qemu_image_timescript.img -n -r $1 -w 120 -t 60 2> /dev/null
    bash benchmark_linux.sh -o linux-results-r$1.txt -p linux-output-r$1 -i qemu_image_timescript.img -n -r $1 -w 120 -t 60 2> /dev/null
    bash benchmark_linux.sh -o linux-results-r$1.txt -p linux-output-r$1 -i qemu_image_timescript.img -n -r $1 -w 120 -t 60 2> /dev/null
}
run_linux 8
run_linux 4
run_linux 2
run_linux 1

# Linux (kvm)
run_linux_kvm() {
    bash benchmark_linux.sh -o linux-kvm-results-r$1.txt -p linux-kvm-output-r$1 -i qemu_image_timescript.img -n -r $1 -w 120 -t 60 -k 2> /dev/null
    bash benchmark_linux.sh -o linux-kvm-results-r$1.txt -p linux-kvm-output-r$1 -i qemu_image_timescript.img -n -r $1 -w 120 -t 60 -k 2> /dev/null
    bash benchmark_linux.sh -o linux-kvm-results-r$1.txt -p linux-kvm-output-r$1 -i qemu_image_timescript.img -n -r $1 -w 120 -t 60 -k 2> /dev/null
}
run_linux_kvm 8
run_linux_kvm 4
run_linux_kvm 2
run_linux_kvm 1
run_linux_kvm 0.5
run_linux_kvm 0.25
run_linux_kvm 0.125
run_linux_kvm 0.0625

# Rust
run_rust() {
    bash benchmark_rust.sh -o rust-results-r$1.txt -p rust-output-r$1 -r $1 -w 120 -t 60 2> /dev/null
    bash benchmark_rust.sh -o rust-results-r$1.txt -p rust-output-r$1 -r $1 -w 120 -t 60 2> /dev/null
    bash benchmark_rust.sh -o rust-results-r$1.txt -p rust-output-r$1 -r $1 -w 120 -t 60 2> /dev/null
}
run_rust 8
run_rust 4
run_rust 2
run_rust 1
run_rust 0.5
run_rust 0.25
run_rust 0.125
run_rust 0.0625
run_rust 0.03125
run_rust 0.015625
run_rust 0.0078125
run_rust 0.00390625

# ones that might halt
#run_linux 0.5
#run_linux_kvm 0.03125
#run_rust 0.001953125    # did not test this one
