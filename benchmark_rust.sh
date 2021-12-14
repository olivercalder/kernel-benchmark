#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -d                      debug mode: preserve qemu display (pass -d to start_rust.sh)
    -e <path/to/binary>     boot from the given Rust kernel binary
                            (default is rust-kernel/test_os/target/x86_64-test_os/release/bootimage-test_os.bin)
    -f <frequency>          set the timestep between calls to spawn new VMs in seconds -- default 10
    -i <path/to/image>      original image file path
    -m <memory>             run qemu with the given memory amount as maximum (default 128)
    -o <resultfilename>     write timestamp IDs to the given file once qemu exits
    -p <outputdir>          write individual qemu outputs to the given directory
    -t <duration>           set the duration of the benchmark in seconds -- default 60
    -w <duration>           set the duration of the warmup time prior to the benchmark -- default 60
" 1>&2; exit 1; }

BIN="rust-kernel/test_os/target/x86_64-test_os/release/bootimage-test_os.bin"
BENCHFILE=
DEBUG=
OUTDIR=
FREQUENCY="10"
TESTTIME="60"
WARMTIME="60"
MEMORY=
IMAGE=

while getopts ":hde:f:i:m:o:p:t:w:" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        e)
            BIN="$OPTARG"
            ;;
        d)
            DEBUG="-d"
            ;;
        f)
            FREQUENCY="$OPTARG"
            ;;
        i)
            IMAGE="$OPTARG"
            ;;
        m)
            MEMORY="-m $OPTARG"
            ;;
        o)
            BENCHFILE="$OPTARG"
            ;;
        p)
            OUTDIR="$OPTARG"
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

shift $((OPTIND - 1))   # isolate remaining args

[ -f "$BIN" ] || { echo "ERROR: binary does not exist: $BIN"; exit 1; }
[ -n "$IMAGE" ] || { echo "ERROR: missing required argument: -i <path/to/image>"; usage; }
[ -f "$IMAGE" ] || { echo "ERROR: image file does not exist: $IMAGE"; exit 1; }

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp
NAME="benchmark-rust-$TS"

[ -n "$BENCHFILE" ] || BENCHFILE="$NAME-results.txt"
[ -n "$OUTDIR" ] || OUTDIR="$NAME-output"

TOTAL=$(python3 -c "print(int(($WARMTIME+$TESTTIME)/$FREQUENCY*1.1))")
echo "Warmup time: $WARMTIME"
echo "Test time: $TESTTIME"
echo "VM spawn interval: $FREQUENCY"
echo "Total VMs to create (total necessary * 1.1): $TOTAL"

write_begin_end() {
    sleep "$WARMTIME"
    echo "BEGIN BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"
    sleep "$TESTTIME"
    echo "END BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"
}

write_begin_end &

i=1
while [ "$i" -le "$TOTAL" ]; do
    sh start_rust.sh -b "$BENCHFILE" $DEBUG -i "$IMAGE" $MEMORY -p "$OUTDIR" -r "$BIN" &
    printf "\rSpawned VM %s" "$i"
    sleep "$FREQUENCY"
    i=$((i + 1))
done
printf "\n"

# Wait until all VMs exit
while [ -n "$(ps -aux | grep -v "grep" | grep -v "benchmark_rust.sh" | grep "$BENCHFILE")" ]; do sleep 0.1; done
