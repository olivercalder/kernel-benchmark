#!/bin/bash

usage() { echo "USAGE: bash $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -i <'docker commands'>  execute the given docker commands, rather than 'docker run hello-world'
    -m                      mute output from start_docker.sh stdout (pipe 1> /dev/null)
    -o <resultfilename>     write timestamp IDs to the given file once docker exits
    -p <outputdir>          pass '-p outdir' on to start_docker.sh
    -r <rate>               set the timestep between calls to spawn new VMs in seconds -- default 10
    -t <duration>           set the duration of the benchmark in seconds -- default 60
    -w <duration>           set the duration of the warmup time prior to the benchmark -- default 60
" 1>&2; exit 1; }

DOCKERCMD="docker run hello-world"
MUTE="/dev/stdout"
BENCHFILE=
OUTDIR=
RATE="10"
TESTTIME="60"
WARMTIME="60"

while getopts ":hi:mo:p:r:t:w:" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        i)
            DOCKERCMD="$OPTARG"
            ;;
        m)
            MUTE="/dev/null"
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

$DOCKERCMD > /dev/null

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp

[ -n "$BENCHFILE" ] || BENCHFILE="benchmark-$TS-results.txt"
[ -n "$OUTDIR" ] || OUTDIR="benchmark-$TS-output"

typeset -i i TOTAL
TOTAL=$(python3 -c "print(int(($WARMTIME+$TESTTIME)/$RATE*1.1))")
echo "Warmup time: $WARMTIME"
echo "Test time: $TESTTIME"
echo "VM spawn interval: $RATE"
echo "Total VMs to create (total necessary * 1.1): $TOTAL"

start_containers() {
    time for ((i=1;i<=TOTAL;i++)); do
        bash start_docker.sh -b "$BENCHFILE" -i "$DOCKERCMD" -p "$OUTDIR" > $MUTE &
        printf "\rSpawned container $i"
        sleep "$RATE"
    done
    printf "\n"
}

start_containers &
sleep "$WARMTIME"
echo "BEGIN BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"
sleep "$TESTTIME"
echo "END BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"

# Wait until all containers exit
while [ -n "$(ps -aux | grep -v "grep" | grep -v "benchmark_docker.sh" | grep "$DOCKERCMD")" ]; do sleep 0.01; done
# it is possible that a few short-lived VMs (0.1 of all VMs for the benchmark) might still spawn later
# but since they are short-lived, this should have negligible effect on the results
