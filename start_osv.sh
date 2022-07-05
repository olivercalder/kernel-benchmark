#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -a <port>               use the given port to send data using TCP -- can't be used with -w
    -n <tapname>            name of the TAP networking device to use with firecracker
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
MEMORY="128M"
IMAGE=
THUMBNAIL=
PORT="12345"
TAP=
WORKDIR=
WIDTH=150
HEIGHT=
CROP=

while getopts ":ha:n:b:de:i:m:o:p:t:w:x:y:c" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        a)
            PORT="$OPTARG"
            ;;
        n)
            TAP="$OPTARG"
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

cp "$BIN" "/tmp/${NAME}.raw"
BIN="/tmp/${NAME}.raw"

TAP_NAME="fc-$TAP-tap0"
TAP_IP="$(printf '169.%s.%s.%s' $(((4 * TAP + 1) / 256 / 256)) $((((4 * TAP + 1) / 256) % 256)) $(((4 * TAP + 1) % 256)))"
CLIENT_IP="$(printf '169.%s.%s.%s' $(((4 * TAP + 1) / 256 / 256)) $((((4 * TAP + 1) / 256) % 256)) $(((4 * TAP + 2) % 256)))"


run_osv_with_tcp () {
    # "${CWD}/osv-build/scripts/imgedit.py" setargs "$BIN" "rusty-nail -a 10.0.2.15:12345 -x $WIDTH -y $HEIGHT $CROP"
    # 10.0.2.15 is default IP where the hostfwd option sends packets over the forwarded ports
    # echo "$(date +%s%N) OSv initiated" >> "$OUTFILE"
    # echo "/usr/bin/time -o "$OUTFILE" --append --portability ./osv-build/scripts/firecracker.py -i "$BIN" -e "--rootfs=zfs /rusty-nail -a $CLIENT_IP:$PORT -x $WIDTH -y $HEIGHT $CROP" -k osv-build/kernel.elf -n -t "$TAP_NAME" --tap_ip "$TAP_IP" --client_ip "$CLIENT_IP""
    /usr/bin/time -o "$OUTFILE" --append --portability ./firecracker.py \
    -i "$BIN" \
    -e "/rusty-nail -a $CLIENT_IP:$PORT -x $WIDTH -y $HEIGHT $CROP" \
    -k ./kernel.elf -n -t "$TAP_NAME" --tap_ip "$TAP_IP" --client_ip "$CLIENT_IP" \
    -m "$MEMORY" > /dev/null

    ECODE=$?
    END_TS="$(date +%s%N)"
    if [ $ECODE -eq 0 ]; then
        # echo "$END_TS OSv exited successfully" >> "$OUTFILE"
        [ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"
        # true
    else
        echo "$END_TS OSv exited with error code $ECODE" >> "$OUTFILE"
        #[ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE"
        # true
    fi
    rm "$BIN"
}


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

# sleep 0.1 # seems to avoid panic on line 14 of main.rs in rusty-nail
du -b "$IMAGE" | awk -F ' ' '{print $1}' | timeout 0.3s "$NETCAT" "$CLIENT_IP" "$PORT"
while [ $? -ne 0 ]; do
    # echo "Retrying sending image size to OSv"
    sleep 0.1
    du -b "$IMAGE" | awk -F ' ' '{print $1}' | "$NETCAT" "$CLIENT_IP" "$PORT"
done
"$NETCAT" "$CLIENT_IP" "$PORT" < "$IMAGE" > "$THUMBNAIL"
