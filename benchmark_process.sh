#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -i <'shell commands'>   execute the given shell commands (default: echo \"\$(date +%s%N) Hello World!\")
    -o <resultfilename>     write timestamp IDs to the given file once the process exits
    -p <outputdir>          pass '-p outdir' on to start_process.sh
    -r <rate>               set the timestep between calls to spawn new processes in seconds -- default 10
    -t <duration>           set the duration of the benchmark in seconds -- default 60
    -w <duration>           set the duration of the warmup time prior to the benchmark -- default 60
" 1>&2; exit 1; }

SHELLCMD='echo "$(date +%s%N) Hello World!"'
BENCHFILE=
OUTDIR=
RATE="10"
TESTTIME="60"
WARMTIME="60"

while getopts ":hi:o:p:r:t:w:" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        i)
            SHELLCMD="$OPTARG"
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

shift $((OPTIND - 1))  # isolate remaining args

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp

[ -n "$BENCHFILE" ] || BENCHFILE="benchmark-process-$TS-results.txt"
[ -n "$OUTDIR" ] || OUTDIR="benchmark-process-$TS-output"

TOTAL=$(python3 -c "print(int(($WARMTIME+$TESTTIME)/$RATE*1.1))")
echo "Warmup time: $WARMTIME"
echo "Test time: $TESTTIME"
echo "Process spawn interval: $RATE"
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
    sh start_process.sh -b "$BENCHFILE" -i "$SHELLCMD" -p "$OUTDIR" &
    printf "\rSpawned process %s" "$i"
    sleep "$RATE"
    i=$((i + 1))
done
printf "\n"
