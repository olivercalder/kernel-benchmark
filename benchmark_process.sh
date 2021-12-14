#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -e <path/to/binary>     execute the given binary -- default: rusty-nail/target/release/rusty-nail
    -f <frequency>          set the timestep between calls to spawn new VMs in seconds -- default 10
    -i <path/to/image>      original image file path
    -o <resultfilename>     write timestamp IDs to the given file once the process exits
    -p <outputdir>          pass '-p outdir' on to start_process.sh
    -t <duration>           set the duration of the benchmark in seconds -- default 60
    -w <duration>           set the duration of the warmup time prior to the benchmark -- default 60
    -x <width>              width of thumbnail -- defaults to 150
    -y <height>             height of thumbnail -- defaults to match width
    -c                      crop the image to exactly fill the given thumbnail dimensions
" 1>&2; exit 1; }

BIN="rusty-nail/target/release/rusty-nail"
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
            BIN="$OPTARG"
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
            WIDTH="$optarg"
            ;;
        y)
            HEIGHT="$optarg"
            ;;
        c)
            CROP="-c"
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND - 1))  # isolate remaining args

[ -f "$BIN" ] || { echo "ERROR: binary does not exist: $BIN"; exit 1; }
[ -n "$IMAGE" ] || { echo "ERROR: missing required argument: -i <path/to/image>"; usage; }
[ -f "$IMAGE" ] || { echo "ERROR: image file does not exist: $IMAGE"; exit 1; }

[ -n "$HEIGHT" ] || HEIGHT="$WIDTH"

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp
NAME="benchmark-process-$TS"

[ -n "$BENCHFILE" ] || BENCHFILE="$NAME-results.txt"
[ -n "$OUTDIR" ] || OUTDIR="$NAME-output"

TOTAL=$(python3 -c "print(int(($WARMTIME+$TESTTIME)/$FREQUENCY*1.1))")
echo "Warmup time: $WARMTIME"
echo "Test time: $TESTTIME"
echo "Process spawn interval: $FREQUENCY"
echo "Total processess to create (total necessary * 1.1): $TOTAL"

write_begin_end() {
    sleep "$WARMTIME"
    echo "BEGIN BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"
    sleep "$TESTTIME"
    echo "END BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"
}

write_begin_end &

i=1
while [ "$i" -le "$TOTAL" ]; do
    sh start_process.sh -b "$BENCHFILE" -e "$BIN" -i "$IMAGE" -p "$OUTDIR" -x "$WIDTH" -y "$HEIGHT" $CROP &
    printf "\rSpawned process %s" "$i"
    sleep "$FREQUENCY"
    i=$((i + 1))
done
printf "\n"
