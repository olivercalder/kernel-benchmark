#!/bin/sh

ID="$(date +%s)"
OUTDIR="Benchmark-$ID"

# Linux (non-kvm)
run_linux() {
    echo "Benchmarking linux with timestep of $1 trial 1"
    sh benchmark_linux.sh -o linux-results-r"$1".txt -p "$OUTDIR"/linux-output-r"$1" -i qemu_image_timescript.img -n -r "$1" -w 120 -t 60 2> /dev/null
    echo "Benchmarking linux with timestep of $1 trial 2"
    sh benchmark_linux.sh -o linux-results-r"$1".txt -p "$OUTDIR"/linux-output-r"$1" -i qemu_image_timescript.img -n -r "$1" -w 120 -t 60 2> /dev/null
    echo "Benchmarking linux with timestep of $1 trial 3"
    sh benchmark_linux.sh -o linux-results-r"$1".txt -p "$OUTDIR"/linux-output-r"$1" -i qemu_image_timescript.img -n -r "$1" -w 120 -t 60 2> /dev/null
}
run_linux 4
run_linux 2
run_linux 1

# Linux (kvm)
run_linux_kvm() {
    echo "Benchmarking linux-kvm with timestep of $1 trial 1"
    sh benchmark_linux.sh -o linux-kvm-results-r"$1".txt -p "$OUTDIR"/linux-kvm-output-r"$1" -i qemu_image_timescript.img -n -r "$1" -w 120 -t 60 -k 2> /dev/null
    echo "Benchmarking linux-kvm with timestep of $1 trial 2"
    sh benchmark_linux.sh -o linux-kvm-results-r"$1".txt -p "$OUTDIR"/linux-kvm-output-r"$1" -i qemu_image_timescript.img -n -r "$1" -w 120 -t 60 -k 2> /dev/null
    echo "Benchmarking linux-kvm with timestep of $1 trial 3"
    sh benchmark_linux.sh -o linux-kvm-results-r"$1".txt -p "$OUTDIR"/linux-kvm-output-r"$1" -i qemu_image_timescript.img -n -r "$1" -w 120 -t 60 -k 2> /dev/null
}
run_linux_kvm 4
run_linux_kvm 2
run_linux_kvm 1
run_linux_kvm 0.5
run_linux_kvm 0.25
run_linux_kvm 0.125
run_linux_kvm 0.0625

# Rust
run_rust() {
    echo "Benchmarking Rust with timestep of $1 trial 1"
    sh benchmark_rust.sh -o rust-results-r"$1".txt -p "$OUTDIR"/rust-output-r"$1" -r "$1" -w 120 -t 60 2> /dev/null
    echo "Benchmarking Rust with timestep of $1 trial 2"
    sh benchmark_rust.sh -o rust-results-r"$1".txt -p "$OUTDIR"/rust-output-r"$1" -r "$1" -w 120 -t 60 2> /dev/null
    echo "Benchmarking Rust with timestep of $1 trial 3"
    sh benchmark_rust.sh -o rust-results-r"$1".txt -p "$OUTDIR"/rust-output-r"$1" -r "$1" -w 120 -t 60 2> /dev/null
}
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
run_rust 0.001953125

# Docker
run_docker() {
    echo "Benchmarking Docker with timestep of $1 trial 1"
    sh benchmark_docker.sh -o docker-results-r"$1".txt -p "$OUTDIR"/docker-output-r"$1" -r "$1" -w 120 -t 60 -m 2> /dev/null
    echo "Benchmarking Docker with timestep of $1 trial 2"
    sh benchmark_docker.sh -o docker-results-r"$1".txt -p "$OUTDIR"/docker-output-r"$1" -r "$1" -w 120 -t 60 -m 2> /dev/null
    echo "Benchmarking Docker with timestep of $1 trial 3"
    sh benchmark_docker.sh -o docker-results-r"$1".txt -p "$OUTDIR"/docker-output-r"$1" -r "$1" -w 120 -t 60 -m 2> /dev/null
}
run_docker 4
run_docker 2
run_docker 1
run_docker 0.5
run_docker 0.25
run_docker 0.125
run_docker 0.0625

# Process
run_process() {
    echo "Benchmarking process with timestep of $1 trial 1"
    sh benchmark_process.sh -o process-results-r"$1".txt -p "$OUTDIR"/process-output-r"$1" -r "$1" -w 120 -t 60 2> /dev/null
    echo "Benchmarking process with timestep of $1 trial 2"
    sh benchmark_process.sh -o process-results-r"$1".txt -p "$OUTDIR"/process-output-r"$1" -r "$1" -w 120 -t 60 2> /dev/null
    echo "Benchmarking process with timestep of $1 trial 3"
    sh benchmark_process.sh -o process-results-r"$1".txt -p "$OUTDIR"/process-output-r"$1" -r "$1" -w 120 -t 60 2> /dev/null
}
run_process 4
run_process 2
run_process 1
run_process 0.5
run_process 0.25
run_process 0.125
run_process 0.0625
run_process 0.03125
run_process 0.015625
run_process 0.0078125
run_process 0.00390625
run_process 0.001953125

# ones that might halt
#run_linux 0.5
#run_linux_kvm 0.03125
