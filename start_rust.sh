#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -b <resultfile>         benchmark mode: write timestamp ID to the given file once qemu exits
    -d                      debug mode: preserve qemu display
    -e <path/to/binary>     boot from the given Rust kernel binary
                            (default is rust-kernel/test_os/target/x86_64-test_os/release/bootimage-test_os.bin)
    -i <path/to/image>      original image file path
    -m <memory>             run qemu with the given memory amount as maximum (default 128M)
    -o <outfilename>        write start and end timestamps as well as any serial output to the given output file
    -p <outdir>             write output file to the given directory
    -t <path/to/thumbnail>  write thumbnail to the given file path
" 1>&2; exit 1; }

BENCHFILE=
BIN="rust-kernel/test_os/target/x86_64-test_os/release/bootimage-test_os.bin"
OUTFILE=
OUTDIR=
NODISP="-display none"
MEMORY=
IMAGE=
THUMBNAIL=

while getopts ":hb:de:i:m:o:p:t:" OPT; do
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
        d)
            NODISP=
            ;;
        i)
            IMAGE="$OPTARG"
            ;;
        m)
            MEMORY="-m $OPTARG"
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
        *)
            echo "ERROR: unknown option: $OPT"
            usage
            ;;
    esac
done

shift $((OPTIND - 1))  # isolate remaining args

[ -f "$BIN" ] || { echo "ERROR: binary does not exist: $BIN"; exit 1; }
[ -n "$IMAGE" ] || { echo "ERROR: missing required argument: -i <path/to/image>"; usage; }
[ -f "$IMAGE" ] || { echo "ERROR: image file does not exist: $IMAGE"; exit 1; }

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp
NAME="qemu-rust-$TS"

[ -n "$OUTFILE" ] || OUTFILE="$NAME.output"
[ -n "$THUMBNAIL" ] || THUMBNAIL="$NAME.png"
[ -n "$OUTDIR" ] && mkdir -p "$OUTDIR" || OUTDIR="."
OUTFILE="$OUTDIR/$OUTFILE"
THUMBNAIL="$OUTDIR/$THUMBNAIL"

NAMEDPIPE="/tmp/$NAME"
mkfifo "$NAMEDPIPE.in" "$NAMEDPIPE.out"     # create I/O pipes
PIPE="-serial pipe:$NAMEDPIPE"


##### DEFINE FUNCTIONS FOR I/O #####


send_image () {
    echo "begin" > "$NAMEDPIPE.in"
    # send a few bytes to trigger serial interrupts
    # if qemu is not finished booting, at least one of these will need to be
    # consumed by the kernel, which ensures the kernel reads all the png data
    cat "$1" > "$NAMEDPIPE.in"
}

receive_image () {
    cat "$NAMEDPIPE.out" > "$1"
}


##### SEND AND RECEIVE DATA FROM SERIAL PORT #####


send_image "$IMAGE" &
receive_image "$THUMBNAIL" &


##### BEGIN RUNNING QEMU #####


time -o "$OUTFILE" --append --portability qemu-system-x86_64 \
    -drive format=raw,file=rust-kernel/test_os/target/x86_64-test_os/release/bootimage-test_os.bin \
    -snapshot \
    -no-reboot \
    -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
    $PIPE \
    $MEMORY \
    $NODISP
# 0xf4 is used to communicate exit codes to qemu
[ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"

rm "$NAMEDPIPE.in" "$NAMEDPIPE.out"     # remove pipes
