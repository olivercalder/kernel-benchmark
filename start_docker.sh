#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -b <resultfile>         benchmark mode: write timestamp ID to the given file once docker exits
    -e <dockerimage>        execute the given docker image (should be built from ./Dockerfile)
    -i <path/to/image>      original image file path
    -o <outfilename>        write start and end timestamps to the given output file
    -p <outdir>             write output file and work dir to the given directory
    -t <thumbnail>          write thumbnail with the given filename
    -w <path/to/work/dir>   mount this directory to the docker container -- thumbnail will be written here
    -x <width>              width of thumbnail -- defaults to 150
    -y <height>             height of thumbnail -- defailts to match width
    -c                      crop the image to exactly fill the given thumbnail dimensions
" 1>&2; exit 1; }

BENCHFILE=
DOCKERIMG="rusty-nail-docker"
OUTFILE=
OUTDIR=
IMAGE=
THUMBNAIL=
WORKDIR=
WIDTH=150
HEIGHT=
CROP=

while getopts ":hb:e:i:o:p:t:q:x:y:c" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        b)
            BENCHFILE="$OPTARG"
            ;;
        e)
            DOCKERIMG="$OPTARG"
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
        w)
            WORKDIR="$OPTARG"
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

shift $((OPTIND - 1))  # isolate remaining args (which should be script filenames)

[ -n "$IMAGE" ] || { echo "ERROR: missing required argument: -i <path/to/image>"; usage; }
[ -f "$IMAGE" ] || { echo "ERROR: image file does not exist: $IMAGE"; exit 1; }

[ -n "$HEIGHT" ] || HEIGHT="$WIDTH"

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp
NAME="docker-$TS"

[ -n "$OUTFILE" ] || OUTFILE="$NAME.output"
[ -n "$THUMBNAIL" ] || THUMBNAIL="thumbnail.png"
[ -n "$OUTDIR" ] && mkdir -p "$OUTDIR" || OUTDIR="$(pwd)"
[ -n "$WORKDIR" ] || WORKDIR="$NAME"
OUTFILE="$OUTDIR/$OUTFILE"
WORKDIR="$OUTDIR/$WORKDIR"
mkdir -p "$WORKDIR"
ORIG="${NAME}_original.png"
ln "$IMAGE" "${WORKDIR}/${ORIG}"    # can't use soft links, but don't want to copy the whole image

CWD="$(pwd)"
WORKDIR="$(cd "$(dirname "$WORKDIR")" && pwd)/$(basename "$WORKDIR")"   # get absolute path
cd "$CWD"


##### BEGIN RUNNING DOCKER #####


echo "$(date +%s%N) Docker initiated" >> "$OUTFILE"
time -o "$OUTFILE" --append --portability docker run --rm --user "$(id -u)":"$(id -g)" \
    -v "$WORKDIR":/images -w /images \
    "$DOCKERIMG" "rusty-nail" "$ORIG" "$THUMBNAIL" "$WIDTH" "$HEIGHT" $CROP >> "$OUTFILE"
ECODE=$?
END_TS="$(date +%s%N)"
if [ $ECODE -eq 0 ]; then
    echo "$END_TS Docker exited successfully" >> "$OUTFILE"
    [ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"
    true
else
    echo "$END_TS Docker exited with error code $ECODE" >> "$OUTFILE"
    #[ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"   # docker actually fails under load, so don't write failures as successes
    true
fi
