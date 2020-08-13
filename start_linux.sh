#!/bin/bash

usage() { echo "USAGE: bash $0 [OPTIONS] [SCRIPT] [SCRIPT2] [...]

OPTIONS:
    -h                      display help
    -k                      --enable-kvm in qemu
    -i <imagefile.img>      use specified qemu disk image
    -o <outfilename>        write output of all scripts to the given file
" 1>&2; exit 1; }

IMG=qemu_image.img
DEFOUTFILE=
USEKVM=

while getopts ":hki:o:" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        i)
            IMG="$OPTARG"
            ;;
        o)
            DEFOUTFILE="$OPTARG"
            ;;
        k)
            USEKVM="--enable-kvm"
            ;;
        *)
            usage
            ;;
    esac
done

shift $(($OPTIND - 1))  # isolate remaining args (which should be script filenames)

for file in "$@"; do
    [ -f $file ] || { echo "ERROR: file does not exist: $file"; exit 1; }
done


##### BEGIN RUNNING QEMU IN THE BACKGROUND #####


NAME="qemu-linux"
TS=$(date +%s%N)    # get current time in nanoseconds -- good enough for unique timestamp
NAMEDPIPE=/tmp/$NAME-$TS

mkfifo $NAMEDPIPE.in $NAMEDPIPE.out     # create I/O pipes

qemu-system-x86_64 \
    -kernel linux/arch/x86_64/boot/bzImage \
    -hda $IMG \
    -append "root=/dev/sda console=ttyS0" \
    -no-reboot \
    -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
    -serial pipe:$NAMEDPIPE \
    -display none \
    $USEKVM \
    2> /dev/null \
    &
# start qemu with the named pipe for I/O, and background it, since we need to
# begin watching its output and giving input accordingly using the pipe


##### DEFINE FUNCTIONS TO RUN SCRIPTS AND STORE OUTPUT #####


# print the given command to the input buffer, terminated by a newline character
do_now() {
    CMD=$1
    printf "$CMD\n" > $NAMEDPIPE.in
}

# wait until the given string appears in the output buffer, then return
wait_for() {
    STR=$1
    while read line; do
        if [[ "$line" == *"$STR"* ]]; then
            break
        fi
    done < $NAMEDPIPE.out
}

# write from the output buffer to the given file until the given string appears
write_until() {
    OUTFILE=$1
    STR=$2
    if [ -n "$STR" ]; then
        while read outline; do
            if [[ "$outline" == *"$STR"* ]]; then
                break
            fi
            echo "$outline " | sed 's/.*//g' >> $OUTFILE
        done < $NAMEDPIPE.out
    else
        # write indefinitely, or until the pipe closes
        while read outline; do
            echo "$outline " | sed 's/.*//g' >> $OUTFILE
        done < $NAMEDPIPE.out
    fi
}

# write each line of the given file to the input buffer, terminated by a newline
do_script() {
    SCRIPTFILE=$1
    [ -n "$2" ] && OUTFILE=$2 || OUTFILE="$SCRIPTFILE.output"

    STARTTIME=$(date +%s%N)

    # run each command from the script on the VM
    while read cmdline; do
        do_now "$cmdline"
    done < $SCRIPTFILE
    do_now "echo END OF SCRIPT $SCRIPTFILE"

    # get the output from the script and store it in the output file
    printf "START OF SCRIPT $SCRIPTFILE $(date +%D_%T)\n\n" >> $OUTFILE
    write_until "$OUTFILE" "END OF SCRIPT $SCRIPTFILE"
    read < $NAMEDPIPE.out   # throw away the last line, which is "END OF SCRIPT $SCRIPTFILE" from the echo statement

    ENDTIME=$(date +%s%N)
    TOTALMS=$(echo "$(($ENDTIME-$STARTTIME))" | sed -r 's/.{6}$//')

    printf "\nEND OF SCRIPT $SCRIPTFILE $(date +%D_%T) -- $TOTALMS ms\n\n" >> $OUTFILE
}


##### RUN ALL SCRIPTS WHICH WERE PASSED AS ARGUMENTS AND STORE THEIR OUTPUT #####


# "Debian GNU/Linux 10 localhost" is the last line before the login prompt, which
# is not terminated by a newline character, so does not appear in the pipe yet
wait_for "Debian GNU/Linux 10 localhost"
read < $NAMEDPIPE.out   # throw away blank line after the above line
do_now "root"
wait_for "permitted by applicable law."

for SCRIPTFILE in "$@"; do
    do_script "$SCRIPTFILE" "$DEFOUTFILE"
done

do_now "shutdown now"   # tell Linux VM to shut down

# Write until the pipe closes
write_until "/dev/null"

# kill the backgrounded qemu process
#kill $(ps -aux | grep qemu-system-x86_64 | grep $NAMEDPIPE | awk '{print $2}')
# there should be a better way to do this using the I/O port via isa-debug-exit
# it also may be the case that the the VM is not yet shut down

rm $NAMEDPIPE.in $NAMEDPIPE.out
