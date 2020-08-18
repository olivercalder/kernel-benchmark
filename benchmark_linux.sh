#!/bin/bash

usage() { echo "USAGE: bash $0 [OPTIONS] [SCRIPT] [SCRIPT2] [...]

OPTIONS:
    -h                      display help
    -o <resultfilename>     write start and end timestamps to the given file once qemu exits
    -p <outputdir>          write individual qemu outputs to the given directory
    -k                      --enable-kvm in qemu
    -i <imagefile.img>      use specified qemu disk image as the base image, adding any specified
                                scripts to it as usual before creating copies so that each VM can 
                                use its own (warning: this script always uses a lot of disk space)
    -n                      do not modify the given image file (thus ignores any scripts in args)
    -r <rate>               set the timestep between calls to spawn new VMs in seconds -- default 10
    -t <duration>           set the duration of the benchmark in seconds -- default 60
    -w <duration>           set the duration of the warmup time prior to the benchmark -- default 60
" 1>&2; exit 1; }

BENCHFILE=
OUTDIR=
USEKVM=
IMGTEMP="qemu_image.img"
NOMOD=
RATE="10"
TESTTIME="60"
WARMTIME="60"

while getopts ":ho:p:ki:nr:t:w:" OPT; do
    case "$OPT" in
        h)
            usage
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

shift $(($OPTIND - 1))  # isolate remaining args (which should be script filenames)

[ -f "linux/arch/x86_64/boot/bzImage" ] || { echo "ERROR: linux kernel not found at linux/arch/x86_64/boot/bzImage"; exit 1; }

[ -f $IMGTEMP ] || { echo "ERROR: qemu disk image does not exist: $IMGTEMP"; exit 1; }

for file in "$@"; do
    [ -f $file ] || { echo "ERROR: file does not exist: $file"; exit 1; }
done

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp

[ -n "$BENCHFILE" ] || BENCHFILE="benchmark-$TS-results.txt"
[ -n "$OUTDIR" ] || OUTDIR="benchmark-$TS-output"

IMG="/tmp/$IMGTEMP-$TS.img"
cp "$IMGTEMP" "$IMG"                # copy the template to /tmp and name it with a timestamp
if [ -z "$NOMOD" ]; then            # -n flag is not present, so add scripts to the image
    bash edit_image.sh -s "$IMG" "$@"   # copy all script files to the image and add them to .profile
fi

typeset -i i TOTAL
TOTAL=$(python3 -c "print(int(($WARMTIME+$TESTTIME)/$RATE*1.1))")
echo "Warmup time: $WARMTIME"
echo "Test time: $TESTTIME"
echo "Image spawn interval: $RATE"
echo "Total images created (total necessary * 1.1): $TOTAL"

# prepare disk images so each vm gets its own image
echo "Copying disk images..."
for ((i=1;i<=TOTAL;i++)); do
    printf "\r$i"
    cp "$IMG" "$IMG.$i.img"
done
printf "\nDone.\n"

start_vms() {
    for ((i=1;i<=TOTAL;i++)); do
        bash start_linux.sh -b "$BENCHFILE" $USEKVM -n -i "$IMG.$i.img" -p "$OUTDIR" &
        printf "\rspawned VM number $i"
        sleep "$RATE"
    done
    printf "\n"
}

start_vms &
sleep "$WARMTIME"
echo "BEGIN BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"
sleep "$TESTTIME"
echo "END BENCHMARK: ID $TS at $(date +%s%N)" >> "$BENCHFILE"

rm "$IMG"
for ((i=1;i<=TOTAL;i++)); do
    while [ -n "$(ps -aux | grep "$IMG.$i.img" | grep -v "grep")" ]; do sleep 1; done    # wait until qemu exits, then remove disk image
    rm "$IMG.$i.img"
done
