#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -b <resultfile>         benchmark mode: write timestamp ID to the given file once the process exits
    -e <path/to/binary>     execute the given binary -- default: rusty-nail/target/release/rusty-nail
    -i <path/to/image>      original image file path
    -o <outfilename>        write start and end timestamps and the output of all commands to the given file
    -p <outdir>             write output file to the given directory
    -t <path/to/thumbnail>  write thumbnail to the given file path
    -x <width>              width of thumbnail -- defaults to 150
    -y <height>             height of thumbnail -- defaults to match width
    -c                      crop the image to exactly fill the given thumbnail dimensions
" 1>&2; exit 1; }

BENCHFILE=
BIN="rusty-nail/target/release/rusty-nail"
OUTFILE=
OUTDIR=
IMAGE=
THUMBNAIL=
WIDTH=150
HEIGHT=
CROP=

while getopts ":hb:e:i:o:p:t:x:y:c" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        b)
            BENCHFILE="$OPTARG"
            ;;
        e)
            BIN="$OPTARG"
            ;;
        i)
            IMAGE="$OPTARG"
            ;;
        o)
            OUTFILE="$OPTARG"
            ;;
        p)
            OUTDIR="$OPTARG"
            ;;
        t)
            THUMBNAIL="$OPTARG"
            ;;
        x)
            WIDTH="$OPTARG"
            ;;
        y)
            HEIGHT="$OPTARG"
            ;;
        c)
            CROP="true"
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
NAME="process-$TS"

[ -n "$OUTFILE" ] || OUTFILE="$NAME.output"
[ -n "$THUMBNAIL" ] || THUMBNAIL="$NAME.png"
[ -n "$OUTDIR" ] && mkdir -p "$OUTDIR" || OUTDIR="."
OUTFILE="$OUTDIR/$OUTFILE"
THUMBNAIL="$OUTDIR/$THUMBNAIL"


##### BEGIN RUNNING PROCESS #####


echo "$(date +%s%N) Process initiated" >> "$OUTFILE"
time -o "$OUTFILE" --append --portability "$BIN" "$IMAGE" "$THUMBNAIL" "$WIDTH" "$HEIGHT" $CROP >> "$OUTFILE"
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
