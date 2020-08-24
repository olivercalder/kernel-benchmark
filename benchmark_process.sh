#!/bin/bash

usage() { echo "USAGE: bash $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -i <'shell commands'>   execute the given shell commands (default: date +%s%N)
    -o <resultfilename>     write timestamp IDs to the given file once the process exits
    -p <outputdir>          pass '-p outdir' on to start_process.sh
    -r <rate>               set the timestep between calls to spawn new processes in seconds -- default 10
    -t <duration>           set the duration of the benchmark in seconds -- default 60
    -w <duration>           set the duration of the warmup time prior to the benchmark -- default 60
" 1>&2; exit 1; }

SHELLCMD="time +%s%N"
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

shift $(($OPTIND - 1))  # isolate remaining args

$SHELLCMD > /dev/null

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp

[ -n "$BENCHFILE" ] || BENCHFILE="benchmark-$TS-results.txt"
[ -n "$OUTDIR" ] || OUTDIR="benchmark-$TS-output"

typeset -i i TOTAL
TOTAL=$(python3 -c "print(int(($WARMTIME+$TESTTIME)/$RATE*1.1))")
echo "Warmup time: $WARMTIME"
echo "Test time: $TESTTIME"
echo "Process spawn interval: $RATE"
echo "Total processess to create (total necessary * 1.1): $TOTAL"

start_processes() {
    time for ((i=1;i<=TOTAL;i++)); do
        bash start_process.sh -b "$BENCHFILE" -i "$SHELLCMD" -p "$OUTDIR" &
        printf "\rSpawned process $i"
        sleep "$RATE"
    done
    printf "\n"
}

start_processes &
sleep "$WARMTIME"
echo "BEGIN BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"
sleep "$TESTTIME"
echo "END BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"

# Wait until all processes exit
while [ -n "$(ps -aux | grep -v "grep" | grep -v "benchmark_process.sh" | grep "$SHELLCMD")" ]; do sleep 0.01; done
# it is possible that a few short-lived processes (0.1 of all VMs for the benchmark) might still
# spawn later but since they are short-lived, this should have negligible effect on the results
