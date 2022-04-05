#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS] [SCRIPT] [SCRIPT2] [...]

OPTIONS:
    -h                      display help
    -d                      debug mode: preserve qemu display and serial output (pass -d to start_linux.sh)
    -i <imagefile.img>      use specified qemu disk image as the base image, adding any specified
                                scripts to it as usual before creating copies so that each VM can 
                                use its own (warning: this script always uses a lot of disk space)
    -k                      --enable-kvm in qemu
    -n                      do not modify the given image file (thus ignores any scripts in args)
    -o <resultfilename>     write timestamp IDs to the given file once qemu exits
    -p <outputdir>          write individual qemu outputs to the given directory
    -f <frequency>               set the timestep between calls to spawn new VMs in seconds -- default 10
    -t <duration>           set the duration of the benchmark in seconds -- default 60
    -w <duration>           set the duration of the warmup time prior to the benchmark -- default 60
" 1>&2; exit 1; }

BENCHFILE=
DEBUG=
OUTDIR=
USEKVM=
IMGTEMP="qemu_image.img"
NOMOD=
RATE="10"
TESTTIME="60"
WARMTIME="60"

while getopts ":hdo:p:ki:nr:t:w:" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        d)
            DEBUG="-d"
            ;;
        o)
            BENCHFILE="$OPTARG"
            ;;
        p)
            OUTDIR="$OPTARG"
            ;;
        k)
            USEKVM="-k"
            ;;
        i)
            IMGTEMP="$OPTARG"
            ;;
        n)
            NOMOD="1"
            ;;
        r)
            FREQUENCY="$OPTARG"
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

[ -f "linux/arch/x86_64/boot/bzImage" ] || { echo "ERROR: linux kernel not found at linux/arch/x86_64/boot/bzImage"; exit 1; }

[ -f "$IMGTEMP" ] || { echo "ERROR: qemu disk image does not exist: $IMGTEMP"; exit 1; }

for file in "$@"; do
    [ -f "$file" ] || { echo "ERROR: file does not exist: $file"; exit 1; }
done

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp

[ -n "$BENCHFILE" ] || BENCHFILE="benchmark-linux$USEKVM-$TS-results.txt"
[ -n "$OUTDIR" ] || OUTDIR="benchmark-linux$USEKVM-$TS-output"

if [ -n "$NOMOD" ]; then                # -n flag is present, so do not modify the disk image
    IMG="$IMGTEMP"                      # thus, disregard any scripts passed as arguments
else                                    # -n flag is not present, so copy the image template and add scripts
    IMG="/tmp/$IMGTEMP-$TS.img"
    cp "$IMGTEMP" "$IMG"                # copy the template to /tmp and name it with a timestamp
    sh edit_image.sh -s "$IMG" "$@"   # copy all script files to the image and add them to .profile
fi

TOTAL=$(python3 -c "print(int(($WARMTIME+$TESTTIME)/$FREQUENCY*1.1))")
echo "Warmup time: $WARMTIME"
echo "Test time: $TESTTIME"
echo "VM spawn interval: $FREQUENCY"
echo "Total VMs to create (total necessary * 1.1): $TOTAL"

write_begin_end() {
    sleep "$WARMTIME"
    echo "BEGIN BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"
    sleep "$TESTTIME"
    echo "END BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"
}

write_begin_end &

i=1
while [ "$i" -le "$TOTAL" ]; do
    sh start_linux.sh -b "$BENCHFILE" $DEBUG $USEKVM -n -i "$IMG" -p "$OUTDIR" &
    printf "\rSpawned VM %s" "$i"
    sleep "$FREQUENCY"
    i=$((i + 1))
done
printf "\n"

# Wait until all VMs exit
while [ -n "$(ps -aux | grep -v "grep" | grep -v "benchmark_linux.sh" | grep "$BENCHFILE")" ]; do sleep 0.01; done

# If the VMs use a modified disk image, then remove disk image
[ -n "$NOMOD" ] || rm "$IMG"
