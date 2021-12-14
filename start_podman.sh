#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -b <resultfile>         benchmark mode: write timestamp ID to the given file once podman exits
    -e <podmanimage>        execute the given podman image (should be built from ./Dockerfile)
    -i <path/to/image>      original image file path
    -o <outfilename>        write start and end timestamps to the given output file
    -p <outdir>             write output file and work dir to the given directory
    -t <thumbnail>          write thumbnail with the given filename
    -w <path/to/work/dir>   mount this directory to the podman container -- thumbnail will be written here
    -x <width>              width of thumbnail -- defaults to 150
    -y <height>             height of thumbnail -- defailts to match width
    -c                      crop the image to exactly fill the given thumbnail dimensions
" 1>&2; exit 1; }

BENCHFILE=
PODMANIMG="rusty-nail-podman"
OUTFILE=
OUTDIR=
IMAGE=
THUMBNAIL=
WORKDIR=
WIDTH=150
HEIGHT=
CROP=

while getopts ":hb:e:i:o:p:t:w:x:y:c" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        b)
            BENCHFILE="$OPTARG"
            ;;
        e)
            PODMANIMG="$OPTARG"
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
NAME="podman-$TS"

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


##### BEGIN RUNNING PODMAN #####


echo "$(date +%s%N) Podman initiated" >> "$OUTFILE"
# Don't run podman as user, since permission problems arise as volumes are
# mounted as root in the container, and workarounds are messy and slow
# This works on Debian-based systems. On RHEL-based systems, workarounds are necessary.
time -o "$OUTFILE" --append --portability podman run --rm \
    -v "$WORKDIR":/images -w /images \
    "$PODMANIMG" "rusty-nail" "$ORIG" "$THUMBNAIL" "$WIDTH" "$HEIGHT" $CROP >> "$OUTFILE"
ECODE=$?
END_TS="$(date +%s%N)"
if [ $ECODE -eq 0 ]; then
    echo "$END_TS Podman exited successfully" >> "$OUTFILE"
    [ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"
    true
else
    echo "$END_TS Podman exited with error code $ECODE" >> "$OUTFILE"
    #[ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"   # don't write failures as successes
    true
fi
