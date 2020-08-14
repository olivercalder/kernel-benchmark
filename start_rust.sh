#!/bin/bash

usage() { echo "USAGE: bash $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -d                      debug mode: preserve qemu display
    -i <path/to/binary>     boot from the given Rust kernel binary
                            (default is rust-kernel/test_os/target/x86_64-test_os/release/bootimage-test_os.bin)
    -o <outfilename>        write output of all scripts to the given file
" 1>&2; exit 1; }

BIN="rust-kernel/test_os/target/x86_64-test_os/release/bootimage-test_os.bin"
OUTFILE=
NODISP="-display none"

while getopts ":hdi:o:" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        d)
            NODISP=
            ;;
        i)
            BIN="$OPTARG"
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

[ -f "$BIN" ] || { echo "ERROR: qemu disk image does not exist: $BIN"; exit 1; }

TS="$(date +%s%N)"  # get current time in nanoseconds -- good enough for unique timestamp
NAME="qemu-rust-$TS"

[ -n "$OUTFILE" ] || OUTFILE="$NAME.output"

NAMEDPIPE="/tmp/$NAME"

mkfifo "$NAMEDPIPE.in" "$NAMEDPIPE.out"     # create I/O pipes

# kill the sleeping task from build_rust.sh if a previous compile happened to fail
kill $(ps -aux | grep wait-to-kill-qemu | awk '{print $2}') 2> /dev/null

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
    -drive format=raw,file=rust-kernel/test_os/target/x86_64-test_os/release/bootimage-test_os.bin \
    -no-reboot \
    -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
    -serial pipe:$NAMEDPIPE \
    $NODISP \
    && echo "$(date +%s%N) QEMU exited successfully" >> $OUTFILE \
    || { ECODE=$?; echo "$(date +%s%N) QEMU exited with error code $ECODE" >> $OUTFILE ; } \
    &

# 0xf4 is used to communicate exit codes to qemu


##### RECORD OUTPUT FROM SERIAL CONSOLE UNTIL THE PIPE CLOSES #####


write_until "$OUTFILE"

#rm "$NAMEDPIPE.in" "$NAMEDPIPE.out"     # remove pipes
