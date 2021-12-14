#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -e <podmanimage>        execute the given podman image (should be build from ./Dockerfile)
    -f <frequency>          set the timestep between calls to spawn new containers in seconds -- default 10
    -i <path/to/image>      original image file path
    -o <resultfilename>     write timestamp IDs to the given file once podman exits
    -p <outputdir>          pass '-p outdir' on to start_podman.sh
    -t <duration>           set the duration of the benchmark in seconds -- default 60
    -w <duration>           set the duration of the warmup time prior to the benchmark -- default 60
    -x <width>              width of thumbnail -- defaults to 150
    -y <height>             height of thumbnail -- defaults to match width
    -c                      crop the image to exactly fill the given thumbnail dimensions
" 1>&2; exit 1; }

PODMANIMG=
BENCHFILE=
OUTDIR=
FREQUENCY="10"
TESTTIME="60"
WARMTIME="60"
IMAGE=
WIDTH=150
HEIGHT=
CROP=

while getopts ":he:f:i:o:p:t:w:x:y:c" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        e)
            PODMANIMG="$OPTARG"
            ;;
        f)
            FREQUENCY="$OPTARG"
            ;;
        i)
            IMAGE="$OPTARG"
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

shift $((OPTIND - 1))  # isolate remaining args (which should be script filenames)

[ -n "$IMAGE" ] || { echo "ERROR: missing required argument: -i <path/to/image>"; usage; }
[ -f "$IMAGE" ] || { echo "ERROR: image file does not exist: $IMAGE"; exit 1; }

[ -n "$HEIGHT" ] || HEIGHT="$WIDTH"

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp
NAME="benchmark-podman-$TS"

if [ ! -n "$PODMANIMG" ]; then
    PODMANIMG="$NAME"
    sh build_podman.sh "$PODMANIMG"
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

i=1
#for ((i=1;i<=TOTAL;i++)); do
while [ "$i" -le "$TOTAL" ]; do
    sh start_podman.sh -b "$BENCHFILE" -e "$PODMANIMG" -i "$IMAGE" -p "$OUTDIR" -x "$WIDTH" -y "$HEIGHT" $CROP &
    printf "\rSpawned container %s" "$i"
    sleep "$FREQUENCY"
    i=$((i + 1))
done
printf "\n"

# Wait until all containers exit or fail
while [ -n "$(ps -aux | grep -v "grep" | grep -v "benchmark_podman.sh" | grep "$PODMANIMG")" ]; do sleep 0.1; done

# Remove all podman containers that stopped from this benchmark so that they are cleaned up for future benchmarks
podman system prune -f
