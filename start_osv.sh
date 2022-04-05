#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -a <port>               use the given port to send data using TCP -- can't be used with -w
    -b <resultfile>         benchmark mode: write timestamp ID to the given file once the process exits
    -d                      debug mode: preserve qemu display
    -e <path/to/osv/image>  execute the given osv image -- default: \$(pwd)/osv/build/last/usr.img
    -i <path/to/image>      original image file path
    -m <memory>             run qemu with the given memory amount as maximum (default 2G)
    -o <outfilename>        write start and end timestamps and the output of all commands to the given file
    -p <outdir>             write output file to the given directory
    -t <path/to/thumbnail>  write thumbnail to the given file path
    -w </path/to/work/dir>  mount this directory to OSv -- thumbnail will be written here
                            - can't be used with -a
                            - if neither -a or -w are given, -w defaults to a unique name
                            - DO NOT USE (broken for now) -- use -a <port> instead
    -x <width>              width of thumbnail -- defaults to 150
    -y <height>             height of thumbnail -- defaults to match width
    -c                      crop the image to exactly fill the given thumbnail dimensions
" 1>&2; exit 1; }

CWD="$(pwd)"
BENCHFILE=
BIN="${CWD}/osv/build/last/usr.img"
OUTFILE=
OUTDIR=
NODISP="-display none"
MEMORY="2G"
IMAGE=
THUMBNAIL=
PORT=
WORKDIR=
WIDTH=150
HEIGHT=
CROP=

while getopts ":ha:b:de:i:m:o:p:t:w:x:y:c" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        a)
            PORT="$OPTARG"
            ;;
        b)
            BENCHFILE="$OPTARG"
            ;;
        d)
            NODISP=
            ;;
        e)
            BIN="$OPTARG"
            ;;
        i)
            IMAGE="$OPTARG"
            ;;
        m)
            MEMORY="$OPTARG"
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
            CROP="-c"
            ;;
        *)
            echo "ERROR: unknown option"
            usage
            ;;
    esac
done

shift $((OPTIND - 1))  # isolate remaining args

[ -f "$BIN" ] || { echo "ERROR: OSv image does not exist: $BIN"; exit 1; }
[ -n "$IMAGE" ] || { echo "ERROR: missing required argument: -i <path/to/image>"; usage; }
[ -f "$IMAGE" ] || { echo "ERROR: image file does not exist: $IMAGE"; exit 1; }

[ -n "$HEIGHT" ] || HEIGHT="$WIDTH"

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp
NAME="osv-$TS"

[ -n "$OUTFILE" ] || OUTFILE="$NAME.output"
[ -n "$OUTDIR" ] && mkdir -p "$OUTDIR" || OUTDIR="."
OUTFILE="$OUTDIR/$OUTFILE"

cp "$BIN" "/tmp/${NAME}.img"
BIN="/tmp/${NAME}.img"


run_osv_with_tcp () {
    "${CWD}/osv/scripts/imgedit.py" setargs "$BIN" "rusty-nail -a 10.0.2.15:12345 -x $WIDTH -y $HEIGHT $CROP"
    # 10.0.2.15 is default IP where the hostfwd option sends packets over the forwarded ports
    echo "$(date +%s%N) OSv initiated" >> "$OUTFILE"
    /usr/bin/time -o "$OUTFILE" --append --portability qemu-system-x86_64 \
    -m "$MEMORY" \
    -smp 4 \
    $NODISP \
    -device virtio-blk-pci,id=blk0,drive=hd0,scsi=off,bootindex=0 \
    -drive file=$BIN,if=none,id=hd0,cache=none,aio=native \
    -netdev user,id=mynet,hostfwd=tcp::$PORT-:12345 \
    -device virtio-net-pci,netdev=mynet \
    --enable-kvm \
    -cpu host,+x2apic
    ECODE=$?
    END_TS="$(date +%s%N)"
    if [ $ECODE -eq 0 ]; then
        echo "$END_TS OSv exited successfully" >> "$OUTFILE"
        [ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"
        true
    else
        echo "$END_TS OSv exited with error code $ECODE" >> "$OUTFILE"
        #[ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"
        true
    fi
    rm "$BIN"
}


if [ -n "$PORT" ]; then

    [ -n "$THUMBNAIL" ] || THUMBNAIL="$NAME.png"
    WORKDIR=
    THUMBNAIL="$OUTDIR/$THUMBNAIL"

    NETCAT=$(command -v netcat)
    if [ ! -n "$NETCAT" ]; then
        NETCAT=$(command -v nc)
        if [ ! -n "$NETCAT" ]; then
            echo "ERROR: netcat not found; please install netcat in order to run with TCP"
            exit 1
        fi
    fi

    run_osv_with_tcp &

    # Wait for QEMU to start listening on the port it was passed
    while true; do
        ss -tulpen | grep "$PORT" > /dev/null
        if [ $? -eq 0 ]; then
            break
        fi
        sleep 0.001
    done

    du -b "$IMAGE" | awk -F ' ' '{print $1}' | "$NETCAT" "localhost" "$PORT"
    # It takes a while (several seconds) for QEMU to pass the data from the
    # first connection to rusty-nail
    "$NETCAT" "localhost" "$PORT" < "$IMAGE" > "$THUMBNAIL"

else
    [ -n "$THUMBNAIL" ] || THUMBNAIL="thumbnail.png"
    [ -n "$WORKDIR" ] || WORKDIR="$NAME"
    WORKDIR="$OUTDIR/$WORKDIR"
    mkdir -p "$WORKDIR"
    ORIG="${NAME}_original.png"
    ln "$IMAGE" "${WORKDIR}/${ORIG}"    # can't use soft links, but don't want to copy the whole image

    # Often, virtiofsd is not in the path, so must find where it is hiding
    VIRTIOFSD=$(command -v virtiofsd)
    if [ ! -n $VIRTIOFSD ]; then
        if [ -f "/usr/libexec/virtiofsd" ]; then
            VIRTIOFSD="/usr/libexec/virtiofsd"
        elif [ -f "/usr/lib/qemu/virtiofsd" ]; then
            VIRTIOFSD="/usr/lib/qemu/virtiofsd"
        fi
    fi
    /home/oac/coding/kernel-benchmark/osv/scripts/../scripts/imgedit.py setargs "$BIN" "--mount-fs=virtiofs,/dev/virtiofs0,/virtiofs rusty-nail -i /virtiofs/$ORIG -t /virtiofs/$THUMBNAIL -x 200 -y 300 -c"
    sudo PATH="$VIRTIOFSD:$PATH" virtiofsd \
    --socket-path=/tmp/vhostqemu-$NAME \
    -o source="$WORKDIR" &
    echo "$(date +%s%N) OSv initiated" >> "$OUTFILE"
    /usr/bin/time -o "$OUTFILE" --append --portability sudo qemu-system-x86_64 \
    -m "$MEMORY" \
    -smp 4 \
    $NODISP \
    -device virtio-blk-pci,id=blk0,drive=hd0,scsi=off,bootindex=0 \
    -drive file=$BIN,if=none,id=hd0,cache=none,aio=native \
    -chardev socket,id=char0,path=/tmp/vhostqemu-$NAME \
    -device vhost-user-fs-pci,queue-size=1024,chardev=char0,tag=myfs \
    -object memory-backend-file,id=mem,size="$MEMORY",mem-path=/dev/shm,share=on \
    -numa node,memdev=mem \
    --enable-kvm \
    -cpu host,+x2apic
    ECODE=$?
    END_TS="$(date +%s%N)"
    if [ $ECODE -eq 0 ]; then
        echo "$END_TS OSv exited successfully" >> "$OUTFILE"
        [ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"
        true
    else
        echo "$END_TS OSv exited with error code $ECODE" >> "$OUTFILE"
        #[ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"
        true
    fi
    rm "$BIN"
fi
