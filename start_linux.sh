#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS] [SCRIPT] [SCRIPT2] [...]

OPTIONS:
    -h                      display help
    -b <resultfile>         benchmark mode: write timestamp ID to the given file once qemu exits
    -d                      debug mode: preserve qemu display, do not redirect serial output to an I/O pipe
    -k                      --enable-kvm in qemu
    -l                      long lived: don't add shutdown command to the image's .profile automatically
    -n                      do not modify or copy the disk image
                            - saves a lot of startup time if there is a preconfigured image
                            - however, ignores any scripts which are passed in as arguments
    -i <imagefile.img>      use specified qemu disk image
    -o <outfilename>        write start and end timestamps, and output of all scripts, to the given file
    -p <outdir>             write the output file in the given directory
" 1>&2; exit 1; }

BENCHFILE=
NODISP="-display none"
NOPIPE=
IMGTEMP="qemu_image.img"    # qemu image template
SHUTDOWN="-s"
NOMOD=
OUTFILE=
OUTDIR=
USEKVM=

while getopts ":hdklnb:i:o:p:" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        b)
            BENCHFILE="$OPTARG"
            ;;
        d)
            NODISP=
            NOPIPE="1"
            ;;
        k)
            USEKVM="--enable-kvm"
            ;;
        l)
            SHUTDOWN=
            ;;
        n)
            NOMOD="1"
            ;;
        i)
            IMGTEMP="$OPTARG"
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

shift $((OPTIND - 1))  # isolate remaining args (which should be script filenames)

[ -f "linux/arch/x86_64/boot/bzImage" ] || { echo "ERROR: linux kernel not found at linux/arch/x86_64/boot/bzImage"; exit 1; }

[ -f "$IMGTEMP" ] || { echo "ERROR: qemu disk image does not exist: $IMGTEMP"; exit 1; }

for file in "$@"; do
    [ -f "$file" ] || { echo "ERROR: file does not exist: $file"; exit 1; }
done

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp

IMG="/tmp/$IMGTEMP-$TS.img"
if [ -n "$NOMOD" ]; then            # -n flag is present
    IMG="$IMGTEMP"                  # directly use the given image
else                                # -n flag not present, so make a copy of the image, modify it, and use it
    cp "$IMGTEMP" "$IMG"            # make a copy of the disk image so that the original is not modified
    sh edit_image.sh $SHUTDOWN "$IMG" "$@"    # copy all script files to the image and add them to .profile
fi

NAME="qemu-linux$USEKVM-$TS"

[ -n "$OUTFILE" ] || OUTFILE="$NAME.output"
[ -n "$OUTDIR" ] && mkdir -p "$OUTDIR" || OUTDIR="."
OUTFILE="$OUTDIR/$OUTFILE"

if [ -n "$NOPIPE" ]; then
    NAMEDPIPE="/dev/null"
    PIPE=
else
    NAMEDPIPE="/tmp/$NAME"
    mkfifo "$NAMEDPIPE.in" "$NAMEDPIPE.out"     # create I/O pipes
    PIPE="-serial pipe:$NAMEDPIPE"
fi


##### DEFINE FUNCTIONS FOR I/O #####


# print the given command to the input buffer, terminated by a newline character
do_now() {
    CMD=$1
    echo "now doing $CMD"
    printf "%s\n" "$CMD" > "$NAMEDPIPE.in"
}

# wait until any of the given strings appear in the output buffer, then return
wait_for() {
    BREAK=
    while read -r line; do
        for STR in "$@"; do
            case "$line" in
                *$STR*)
                    BREAK=1
                    break
                    ;;
            esac
        done
        [ -n "$BREAK" ] && break
    done < "$NAMEDPIPE.out"
}

# write from the output buffer to the given file until any of the given strings appear
# does not write the final line containing the found string
write_until() {
    OUTFILE=$1
    BREAK=      # initialize empty BREAK variable
    shift       # shift arg index by 1
    while read -r outline; do
        for STR in "$@"; do   # if no further arguments, read indefinitely
            case "$outline" in
                *$STR*)
                    BREAK=1
                    break
                    ;;
            esac
        done
        [ -n "$BREAK" ] && break    # break if the BREAK variable has been set
        echo "$outline " | sed 's/.*//g' >> "$OUTFILE"
    done < "$NAMEDPIPE.out"
}


##### BEGIN RUNNING QEMU IN THE BACKGROUND #####


echo "$(date +%s%N) QEMU initiated" >> "$OUTFILE" && qemu-system-x86_64 \
    -kernel linux/arch/x86_64/boot/bzImage \
    -hda "$IMG" \
    -snapshot \
    -append "root=/dev/sda console=ttyS0" \
    -no-reboot \
    $USEKVM \
    -device isa-debug-exit \
    $PIPE \
    $NODISP \
    && { echo "$(date +%s%N) QEMU exited successfully" >> "$OUTFILE" ; [ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE" ; true; } \
    || { ECODE=$?; echo "$(date +%s%N) QEMU exited with error code $ECODE" >> "$OUTFILE" ; [ -n "$BENCHFILE" ] && echo "$TS" >> "$BENCHFILE" ; true; } \
    &
# write timestamp and start qemu with the named pipe for I/O, and background it,
# since we need to begin watching its output; when it exits, write the timestamp


##### WAIT FOR AUTOMATIC LOGIN, THEN RECORD OUTPUT UNTIL SHUTDOWN OCCURS #####


if [ -z "$NOPIPE" ]; then
    # This is the last line of the message printed after login
    wait_for "permitted by applicable law"

    write_until "$OUTFILE" "shutdown now"

    rm "$NAMEDPIPE.in" "$NAMEDPIPE.out"     # remove pipes
    [ -n "$NOMOD" ] || rm "$IMG"  # remove image if it was copied from a template
fi
