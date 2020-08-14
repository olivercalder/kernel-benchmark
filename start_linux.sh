#!/bin/bash

usage() { echo "USAGE: bash $0 [OPTIONS] [SCRIPT] [SCRIPT2] [...]

OPTIONS:
    -h                      display help
    -d                      debug mode: preserve stderr and qemu display
    -k                      --enable-kvm in qemu
    -l                      long lived -- don't shutdown
    -n                      do not modify or copy the disk image
                            - saves a lot of startup time if there is a free preconfigured image
                            - however, ignores any scripts which are passed in as arguments
    -c                      copy (but do not modify) the disk image
                            - image is copied by default, but this copies the image without modification
    -i <imagefile.img>      use specified qemu disk image
    -o <outfilename>        write output of all scripts to the given file
" 1>&2; exit 1; }

PIPEERR="/dev/null"        # leading space is necessary due to option for 2>"&1"
NODISP="-display none"
IMGTEMP="qemu_image.img"    # qemu image template
SHUTDOWN="-s"
NOMOD=
COPY=
OUTFILE=
USEKVM=

while getopts ":hdklnci:o:" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        d)
            PIPEERR="/dev/stdout"
            NODISP=
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
        c)
            COPY="1"
            ;;
        i)
            IMGTEMP="$OPTARG"
            ;;
        o)
            OUTFILE="$OPTARG"
            ;;
        *)
            usage
            ;;
    esac
done

shift $(($OPTIND - 1))  # isolate remaining args (which should be script filenames)

[ -f $IMGTEMP ] || { echo "ERROR: qemu disk image does not exist: $IMGTEMP"; exit 1; }

for file in "$@"; do
    [ -f $file ] || { echo "ERROR: file does not exist: $file"; exit 1; }
done

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp

IMG="/tmp/$IMGTEMP-$TS.img"
if [ -n "$COPY" ]; then             # -c flag is present, so use an unmodified copy (-n doesn't matter)
    cp "$IMGTEMP" "$IMG"            # copy and use the image without modification
elif [ -n "$NOMOD" ]; then          # -n flag is present and -c is not
    IMG="$IMGTEMP"                  # directly use the given image
else                                # -n and -c flags not present, so make a copy of the image, modify it, and use it
    cp "$IMGTEMP" "$IMG"            # make a copy of the disk image so that each VM gets its own
    bash edit_image.sh $SHUTDOWN "$IMG" "$@"    # copy all script files to the image and add them to .profile
fi

NAME="qemu-linux$USEKVM-$TS"

[ -n "$OUTFILE" ] || OUTFILE="$NAME.output"

NAMEDPIPE="/tmp/$NAME"

mkfifo "$NAMEDPIPE.in" "$NAMEDPIPE.out"     # create I/O pipes


##### DEFINE FUNCTIONS FOR I/O #####


# print the given command to the input buffer, terminated by a newline character
do_now() {
    CMD=$1
    echo "now doing $CMD"
    printf "$CMD\n" > "$NAMEDPIPE.in"
}

# wait until any of the given strings appear in the output buffer, then return
wait_for() {
    BREAK=
    while read line; do
        for STR in "$@"; do
            if [[ "$line" == *"$STR"* ]]; then
                BREAK=1
                break
            fi
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
    while read outline; do
        for STR in "$@"; do   # if no further arguments, read indefinitely
            if [[ "$outline" == *"$STR"* ]]; then
                BREAK=1 # remember to break from the actual read loop
                break   # break from the inner for loop
            fi
        done
        [ -n "$BREAK" ] && break    # break if the BREAK variable has been set
        echo "$outline " | sed 's/.*//g' >> $OUTFILE
    done < "$NAMEDPIPE.out"
}


##### BEGIN RUNNING QEMU IN THE BACKGROUND #####


echo "$(date +%s%N) QEMU initiated" >> $OUTFILE && qemu-system-x86_64 \
    -kernel linux/arch/x86_64/boot/bzImage \
    -hda $IMG \
    -append "root=/dev/sda console=ttyS0" \
    -no-reboot \
    $USEKVM \
    -device isa-debug-exit \
    -serial pipe:$NAMEDPIPE \
    $NODISP \
    2> $PIPEERR \
    && echo "$(date +%s%N) QEMU exited successfully" >> $OUTFILE \
    || { ECODE=$?; echo "$(date +%s%N) QEMU exited with error code $ECODE" >> $OUTFILE ; } \
    &
# write timestamp and start qemu with the named pipe for I/O, and background it,
# since we need to begin watching its output; when it exits, write the timestamp


##### WAIT FOR AUTOMATIC LOGIN, THEN RECORD OUTPUT UNTIL SHUTDOWN OCCURS #####


# This is the last line of the message printed after login
wait_for "permitted by applicable law"

write_until "$OUTFILE" "shutdown now"

rm "$NAMEDPIPE.in" "$NAMEDPIPE.out"     # remove pipes
[ -n "$NOMOD" ] && [ ! -n "$COPY" ] || rm "$IMG"  # remove image if it was copied from a template
