#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -d                      debug mode: preserve qemu display (pass -d to start_osv.sh)
    -e <osv-img>            use the given OSv image as the base image for the benchmarks
                            (default is ./osv/build/last/usr.img)
    -f <frequency>          set the timestep between calls to spawn new containers in seconds -- default 10
    -i <path/to/image>      original image file path
    -m <memory>             run qemu with the given memory amount as maximum (default 2G)
    -o <resultfilename>     write timestamp IDs to the given file once OSv exits
    -p <outputdir>          pass '-p outdir' on to start_osv.sh
    -t <duration>           set the duration of the benchmark in seconds -- default 60
    -w <duration>           set the duration of the warmup time prior to the benchmark -- default 60
    -x <width>              width of thumbnail -- defaults to 150
    -y <height>             height of thumbnail -- defaults to match width
    -c                      crop the image to exactly fill the given thumbnail dimensions
" 1>&2; exit 1; }

OSVIMG=
BENCHFILE=
DEBUG=
OUTDIR=
FREQUENCY="10"
TESTTIME="60"
WARMTIME="60"
IMAGE=
MEMORY="2G"
WIDTH=150
HEIGHT=
CROP=

while getopts ":hde:f:i:m:o:p:t:w:x:y:c" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        d)
            DEBUG="-d"
            ;;
        e)
            OSVIMG="$OPTARG"
            ;;
        f)
            FREQUENCY="$OPTARG"
            ;;
        i)
            IMAGE="$OPTARG"
            ;;
        m)
            MEMORY="$OPTARG"
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
        x)
            WIDTH="$OPTARG"
            ;;
        y)
            HEIGHT="$OPTARG"
            ;;
        c)
            CROP="-c"
            ;;
        *)
            echo "ERROR: unknown option: $OPT"
            usage
            ;;
    esac
done

shift $((OPTIND - 1))  # isolate remaining args

[ -n "$IMAGE" ] || { echo "ERROR: missing required argument: -i <path/to/image>"; usage; }
[ -f "$IMAGE" ] || { echo "ERROR: image file does not exist: $IMAGE"; exit 1; }

[ -n "$HEIGHT" ] || HEIGHT="$WIDTH"

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp
NAME="benchmark-osv-$TS"

[ -d "osv" ] || git clone https://github.com/cloudius-systems/osv.git

if [ ! -n "$OSVIMG" ]; then
    OSVIMG="$(pwd)/osv/build/last/usr.img"
    sh build_osv.sh
fi

[ -n "$BENCHFILE" ] || BENCHFILE="$NAME-results.txt"
[ -n "$OUTDIR" ] || OUTDIR="$NAME-output"

TOTAL=$(python3 -c "print(int(($WARMTIME+$TESTTIME)/$FREQUENCY*1.1))")
echo "Warmup time: $WARMTIME"
echo "Test time: $TESTTIME"
echo "Container spawn interval: $FREQUENCY"
echo "Total containers to create (total necessary * 1.1): $TOTAL"

write_begin_end() {
    sleep "$WARMTIME"
    echo "BEGIN BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"
    sleep "$TESTTIME"
    echo "END BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"
}

write_begin_end &

PORT_OFFSET=12345
i=1
while [ "$i" -le "$TOTAL" ]; do
    sh start_osv.sh -a "$((i + PORT_OFFSET))" -b "$BENCHFILE" $DEBUG -e "$OSVIMG" -i "$IMAGE" -m "$MEMORY" -p "$OUTDIR" -x "$WIDTH" -y "$HEIGHT" $CROP &
    printf "\rSpawned VM %s" "$i"
    sleep "$FREQUENCY"
    i=$((i + 1))
done
printf "\n"

# Wait until all containers exit or fail
while [ -n "$(ps -aux | grep -v "grep" | grep -v "benchmark_osv.sh" | grep "$OSVIMG")" ]; do sleep 0.1; done
