#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -i <'docker commands'>  execute the given docker commands, rather than 'docker run hello-world'
    -m                      mute output from start_docker.sh stdout (pipe 1> /dev/null)
    -o <resultfilename>     write timestamp IDs to the given file once docker exits
    -p <outputdir>          pass '-p outdir' on to start_docker.sh
    -r <rate>               set the timestep between calls to spawn new containers in seconds -- default 10
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

shift $((OPTIND - 1))  # isolate remaining args (which should be script filenames)

$DOCKERCMD > /dev/null

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp

[ -n "$BENCHFILE" ] || BENCHFILE="benchmark-docker-$TS-results.txt"
[ -n "$OUTDIR" ] || OUTDIR="benchmark-docker-$TS-output"

TOTAL=$(python3 -c "print(int(($WARMTIME+$TESTTIME)/$RATE*1.1))")
echo "Warmup time: $WARMTIME"
echo "Test time: $TESTTIME"
echo "Container spawn interval: $RATE"
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
    sh start_docker.sh -b "$BENCHFILE" -i "$DOCKERCMD" -p "$OUTDIR" > $MUTE &
    printf "\rSpawned container %s" "$i"
    sleep "$RATE"
    i=$((i + 1))
done
printf "\n"

# Wait until all containers exit or fail
while [ -n "$(ps -aux | grep -v "grep" | grep -v "benchmark_docker.sh" | grep "$DOCKERCMD")" ]; do sleep 0.1; done

# Restart all docker containers that stopped so that they are cleaned up for future benchmarks
docker start $(docker ps -a | grep "$DOCKERCMD" | awk '{print $1}')     # need single quotes for print $1, so use grep
