#!/bin/bash

usage() { echo "USAGE: bash $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -b <resultfile>         benchmark mode: write timestamp ID to the given file once the process exits
    -i <'shell commands''>  execute the given shell commands (default: date +%s%N)
    -o <outfilename>        write output of all commands to the given file
    -p <outdir>             write output file to the given directory
" 1>&2; exit 1; }

BENCHFILE=
SHELLCMD="date +%s%N"
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
            SHELLCMD="$OPTARG"
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

shift $(($OPTIND - 1))  # isolate remaining args

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp
NAME="process-$TS"

[ -n "$OUTFILE" ] || OUTFILE="$NAME.output"
[ -n "$OUTDIR" ] && mkdir -p "$OUTDIR" || OUTDIR="."
OUTFILE="$OUTDIR/$OUTFILE"


##### BEGIN RUNNING PROCESS #####


echo "$(date +%s%N) Process initiated" >> "$OUTFILE"
eval $SHELLCMD >> "$OUTFILE"
ECODE=$?
END_TS="$(date +%s%N)"
if [ $ECODE -eq 0 ]; then
    echo "$END_TS Process exited successfully" >> "$OUTFILE"
    [ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"
    true
else
    echo "$END_TS Process exited with error code $ECODE" >> "$OUTFILE"
    #[ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"
    true
fi
