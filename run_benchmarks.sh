#!/bin/sh

##### WARNING: HAVING DOCKER DAEMON RUNNING MAY CAUSE OTHER BENCHMARKS TO FAIL #####

# Please start Docker after running this script, and then benchmark Docker
# using `sh run_docker.sh`

if [ -n "$(ps -aux | grep -v grep | grep docker)" ]; then
    echo "WARNING: A process related to Docker is running."
    printf "Are you sure you want to continue? [N/y] "
    read $RESP
    if [ "$RESP" != "y" ]; then
        echo "Aborting."
        exit 1
    fi
fi

ID="$(date +%s)"
OUTDIR=/tmp/Benchmark-"$ID"     # Use /tmp since it is usually on a non-network drive

# Linux (non-kvm)
run_linux() {
    echo "Benchmarking linux with timestep of $1 trial 1"
    sh benchmark_linux.sh -o "$OUTDIR"/linux-results-r"$1".txt -p "$OUTDIR"/linux-output-r"$1" -i qemu_image_timescript.img -n -f "$1" -w 120 -t 60 2> /dev/null
    echo "Benchmarking linux with timestep of $1 trial 2"
    sh benchmark_linux.sh -o "$OUTDIR"/linux-results-r"$1".txt -p "$OUTDIR"/linux-output-r"$1" -i qemu_image_timescript.img -n -f "$1" -w 120 -t 60 2> /dev/null
    echo "Benchmarking linux with timestep of $1 trial 3"
    sh benchmark_linux.sh -o "$OUTDIR"/linux-results-r"$1".txt -p "$OUTDIR"/linux-output-r"$1" -i qemu_image_timescript.img -n -f "$1" -w 120 -t 60 2> /dev/null
}
# run_linux 4
# run_linux 2
# run_linux 1

# Linux (kvm)
run_linux_kvm() {
    echo "Benchmarking linux-kvm with timestep of $1 trial 1"
    sh benchmark_linux.sh -o "$OUTDIR"/linux-kvm-results-r"$1".txt -p "$OUTDIR"/linux-kvm-output-r"$1" -i qemu_image_timescript.img -n -f "$1" -w 120 -t 60 -k 2> /dev/null
    echo "Benchmarking linux-kvm with timestep of $1 trial 2"
    sh benchmark_linux.sh -o "$OUTDIR"/linux-kvm-results-r"$1".txt -p "$OUTDIR"/linux-kvm-output-r"$1" -i qemu_image_timescript.img -n -f "$1" -w 120 -t 60 -k 2> /dev/null
    echo "Benchmarking linux-kvm with timestep of $1 trial 3"
    sh benchmark_linux.sh -o "$OUTDIR"/linux-kvm-results-r"$1".txt -p "$OUTDIR"/linux-kvm-output-r"$1" -i qemu_image_timescript.img -n -f "$1" -w 120 -t 60 -k 2> /dev/null
}
# run_linux_kvm 4
# run_linux_kvm 2
# run_linux_kvm 1
# run_linux_kvm 0.5
# run_linux_kvm 0.25
# run_linux_kvm 0.125
# run_linux_kvm 0.0625

# Rust
run_rust() {
    echo "Benchmarking Rust with timestep of $1 trial 1"
    sh benchmark_rust.sh -o "$OUTDIR"/rust-results-r"$1".txt -p "$OUTDIR"/rust-output-r"$1" -f "$1" -w 120 -t 60 -i rust-kernel/test_os/larger.png 2> /dev/null
    echo "Benchmarking Rust with timestep of $1 trial 2"
    sh benchmark_rust.sh -o "$OUTDIR"/rust-results-r"$1".txt -p "$OUTDIR"/rust-output-r"$1" -f "$1" -w 120 -t 60 -i rust-kernel/test_os/larger.png 2> /dev/null
    echo "Benchmarking Rust with timestep of $1 trial 3"
    sh benchmark_rust.sh -o "$OUTDIR"/rust-results-r"$1".txt -p "$OUTDIR"/rust-output-r"$1" -f "$1" -w 120 -t 60 -i rust-kernel/test_os/larger.png 2> /dev/null
}
# run_rust 4
# run_rust 2
# run_rust 1
run_rust 0.5
# run_rust 0.25
# run_rust 0.125
# run_rust 0.0625
# run_rust 0.03125
# run_rust 0.015625
# run_rust 0.0078125
# run_rust 0.00390625
# run_rust 0.001953125
# run_rust 0.0009765625

# OSv
run_osv() {
    echo "Benchmarking osv with timestep of $1 trial 1"
    sh benchmark_osv.sh -e ./osv-build/usr.img -o "$OUTDIR"/osv-results-r"$1".txt -p "$OUTDIR"/osv-output-r"$1" -f "$1" -w 120 -t 60 -c -i rust-kernel/test_os/larger.png 2> /dev/null
    echo "Benchmarking osv with timestep of $1 trial 2"
    sh benchmark_osv.sh -e ./osv-build/usr.img -o "$OUTDIR"/osv-results-r"$1".txt -p "$OUTDIR"/osv-output-r"$1" -f "$1" -w 120 -t 60 -c -i rust-kernel/test_os/larger.png 2> /dev/null
    echo "Benchmarking osv with timestep of $1 trial 3"
    sh benchmark_osv.sh -e ./osv-build/usr.img -o "$OUTDIR"/osv-results-r"$1".txt -p "$OUTDIR"/osv-output-r"$1" -f "$1" -w 120 -t 60 -c -i rust-kernel/test_os/larger.png 2> /dev/null
}
# run_osv 4
# run_osv 2
# run_osv 1
run_osv 0.5
# run_osv 0.25
# run_osv 0.125
# run_osv 0.0625
# run_osv 0.03125

# Podman
run_podman() {
    echo "Benchmarking Podman with timestep of $1 trial 1"
    sh benchmark_podman.sh -e "rusty-nail-podman" -o "$OUTDIR"/podman-results-r"$1".txt -p "$OUTDIR"/podman-output-r"$1" -f "$1" -w 120 -t 60 -c -i rust-kernel/test_os/larger.png 2> /dev/null
    echo "Benchmarking Podman with timestep of $1 trial 2"
    sh benchmark_podman.sh -e "rusty-nail-podman" -o "$OUTDIR"/podman-results-r"$1".txt -p "$OUTDIR"/podman-output-r"$1" -f "$1" -w 120 -t 60 -c -i rust-kernel/test_os/larger.png 2> /dev/null
    echo "Benchmarking Podman with timestep of $1 trial 3"
    sh benchmark_podman.sh -e "rusty-nail-podman" -o "$OUTDIR"/podman-results-r"$1".txt -p "$OUTDIR"/podman-output-r"$1" -f "$1" -w 120 -t 60 -c -i rust-kernel/test_os/larger.png 2> /dev/null
}
# run_podman 4
# run_podman 2
run_podman 1
run_podman 0.5
# run_podman 0.25
# run_podman 0.125
# run_podman 0.0625
# run_podman 0.03125

# Process
run_process() {
    echo "Benchmarking process with timestep of $1 trial 1"
    sh benchmark_process.sh -o "$OUTDIR"/process-results-r"$1".txt -p "$OUTDIR"/process-output-r"$1" -f "$1" -w 120 -t 60 -c -i rust-kernel/test_os/larger.png 2> /dev/null
    echo "Benchmarking process with timestep of $1 trial 2"
    sh benchmark_process.sh -o "$OUTDIR"/process-results-r"$1".txt -p "$OUTDIR"/process-output-r"$1" -f "$1" -w 120 -t 60 -c -i rust-kernel/test_os/larger.png 2> /dev/null
    echo "Benchmarking process with timestep of $1 trial 3"
    sh benchmark_process.sh -o "$OUTDIR"/process-results-r"$1".txt -p "$OUTDIR"/process-output-r"$1" -f "$1" -w 120 -t 60 -c -i rust-kernel/test_os/larger.png 2> /dev/null
}
# run_process 4
# run_process 2
# run_process 1
run_process 0.5
# run_process 0.25
# run_process 0.125
# run_process 0.0625
# run_process 0.03125
# run_process 0.015625
# run_process 0.0078125
# run_process 0.00390625
# run_process 0.001953125
# run_process 0.0009765625

# ones that might halt
#run_linux 0.5
#run_linux_kvm 0.03125

mv "$OUTDIR" .
