#!/bin/bash

usage() { echo "USAGE: bash $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -d                      debug mode: preserve qemu display (pass -d to start_rust.sh)
    -i <path/to/binary>     boot from the given Rust kernel binary
                            (default is rust-kernel/test_os/target/x86_64-test_os/release/bootimage-test_os.bin)
    -o <resultfilename>     write start and end timestamps to the given file once qemu exits
    -p <outputdir>          write individual qemu outputs to the given directory
    -r <rate>               set the timestep between calls to spawn new VMs in seconds -- default 10
    -t <duration>           set the duration of the benchmark in seconds -- default 60
    -w <duration>           set the duration of the warmup time prior to the benchmark -- default 60
" 1>&2; exit 1; }

BIN="rust-kernel/test_os/target/x86_64-test_os/release/bootimage-test_os.bin"
BENCHFILE=
DEBUG=
OUTDIR=
NOMOD=
RATE="10"
TESTTIME="60"
WARMTIME="60"

while getopts ":hdi:o:p:r:t:w:" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        d)
            DEBUG="-d"
            ;;
        i)
            BIN="$OPTARG"
            ;;
        o)
            BENCHFILE="$OPTARG"
            ;;
        p)
            OUTDIR="$OPTARG"
            ;;
        r)
            RATE="$OPTARG"
            ;;
        t)
            TESTTIME="$OPTARG"
            ;;
        w)
            WARMTIME="$OPTARG"
            ;;
        *)
            usage
            ;;
    esac
done

shift $(($OPTIND - 1))  # isolate remaining args (which should be script filenames)

[ -f "linux/arch/x86_64/boot/bzImage" ] || { echo "ERROR: linux kernel not found at linux/arch/x86_64/boot/bzImage"; exit 1; }

for file in "$@"; do
    [ -f $file ] || { echo "ERROR: file does not exist: $file"; exit 1; }
done

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp

[ -n "$BENCHFILE" ] || BENCHFILE="benchmark-$TS-results.txt"
[ -n "$OUTDIR" ] || OUTDIR="benchmark-$TS-output"

typeset -i i TOTAL
TOTAL=$(python3 -c "print(int(($WARMTIME+$TESTTIME)/$RATE*1.1))")
echo "Warmup time: $WARMTIME"
echo "Test time: $TESTTIME"
echo "VM spawn interval: $RATE"
echo "Total VMs to create (total necessary * 1.1): $TOTAL"

start_vms() {
    time for ((i=1;i<=TOTAL;i++)); do
        bash start_rust.sh -b "$BENCHFILE" $DEBUG -i "$BIN" -p "$OUTDIR" &
        printf "\rSpawned VM $i"
        sleep "$RATE"
    done
    printf "\n"
}

start_vms &
sleep "$WARMTIME"
echo "BEGIN BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"
sleep "$TESTTIME"
echo "END BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"

# Wait until all VMs exit
for ((i=1;i<=TOTAL;i++)); do
    while [ -n "$(ps -aux | grep -v "grep" | grep -v "benchmark_rust.sh" | grep "$BENCHFILE")" ]; do sleep 1; done
done