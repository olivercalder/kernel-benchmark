#!/bin/bash

# Mounts the given disk image for editing. The first argument is the disk image
# filename, and all remaining arguments are files to be copied to the image.
# Copies any given files to the /root directory, and if those files contain a
# #!/path/to/shell, then treat them as scripts and put calls to them using their
# appropriate shells in /root/.profile, which will be executed on login.
# If no files are given, mounts the image and chroots in for editing manually.

# Based on the instructions from https://www.collabora.com/news-and-blog/blog/2017/01/16/setting-up-qemu-kvm-for-kernel-development/

usage() { echo "USAGE: bash $0 [OPTIONS] [SCRIPT] [...]

OPTIONS:
    -h                      display help
    -i <imagename>          edit the given image (if unspecified, default is qemu_image.img)
    -s                      write 'shutdown now' to .profile
                            this occurs automatically if one or more scripts are passed as args

If the -s flag is absent and there are no scripts passed as arguments, the image is mounted and
chrooted with no other changes made. The user must exit from chroot before the script exits.
" 1>&2; exit 1; }

IMG="qemu_image.img"
SHUTDOWN=

while getopts ":hi:s" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        i)
            IMG="$OPTARG"
            ;;
        s)
            SHUTDOWN="1"
            ;;
        *)
            usage
            ;;
    esac
done

shift $(($OPTIND - 1))  # isolate remaining args (which should be script filenames)

[ -f $IMG ] || { echo "ERROR: qemu disk image does not exist: $IMG"; exit 1; }

IS_SCRIPT=
for file in "$@"; do
    [ -f $file ] || { echo "ERROR: file does not exist: $file"; exit 1; }
    IS_SCRIPT="1"
done

TS="$(date +%s%N)"
DIR="/tmp/mount-point-$IMG.dir"
NEWPROFILE="/tmp/$TS.profile"
mkdir -p $DIR
sudo mount -o loop $IMG $DIR    # uses a loop device to map the disk image to the directory
if [ -n "$IS_SCRIPT" ] || [ -n "$SHUTDOWN" ]; then
    PROFILE="$DIR/root/.profile"
    sudo cp "$PROFILE" "$NEWPROFILE.tmp"
    grep -v "shutdown" "$NEWPROFILE.tmp" > "$NEWPROFILE"
    sudo rm "$NEWPROFILE.tmp"
    for file in "$@"; do
        sudo cp "$file" "$DIR/root/$file"
        SH="$(grep '#!' "$file" | sed 's/#!//g')"   # if the file has #!/path/to/shell, assume it is a script to be autorun
        [ -n "$SH" ] && { echo "$SH" "$file" >> "$NEWPROFILE"; }     # put /path/to/shell filename in .profile
    done
    echo "echo shutdown now" >> "$NEWPROFILE"    # so that "shutdown now" appears in the output pipe
    echo "shutdown now" >> "$NEWPROFILE"         # actually shutdown
    sudo mv "$NEWPROFILE" "$PROFILE"
else
    sudo chroot $DIR
fi
sudo umount $DIR
rmdir $DIR
