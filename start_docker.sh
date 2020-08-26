#!/bin/bash

usage() { echo "USAGE: bash $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -b <resultfile>         benchmark mode: write timestamp ID to the given file once docker exits
    -i <'docker commands'>  execute the given docker commands, rather than 'docker run hello-world'
    -o <outfilename>        write start and end timestamps to the given output file
    -p <outdir>             write output file to the given directory
" 1>&2; exit 1; }

BENCHFILE=
DOCKERCMD="docker run hello-world"
OUTFILE=
OUTDIR=

while getopts ":hb:i:o:p:" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        b)
            BENCHFILE="$OPTARG"
            ;;
        i)
            DOCKERCMD="$OPTARG"
            ;;
        o)
            OUTFILE="$OPTARG"
            ;;
        p)
            OUTDIR="$OPTARG"
            ;;
        *)
            usage
            ;;
    esac
done

shift $(($OPTIND - 1))  # isolate remaining args (which should be script filenames)

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp
NAME="docker-$TS"

[ -n "$OUTFILE" ] || OUTFILE="$NAME.output"
[ -n "$OUTDIR" ] && mkdir -p "$OUTDIR" || OUTDIR="."
OUTFILE="$OUTDIR/$OUTFILE"


##### BEGIN RUNNING DOCKER #####


echo "$(date +%s%N) Docker initiated" >> $OUTFILE
eval $DOCKERCMD
ECODE=$?
END_TS="$(date +%s%N)"
if [ $ECODE -eq 0 ]; then
    echo "$END_TS Docker exited successfully" >> $OUTFILE
    [ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"
    true
else
    echo "$END_TS Docker exited with error code $ECODE" >> $OUTFILE
    #[ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"   # docker actually fails under load, so don't write failures as successes
    true
fi
