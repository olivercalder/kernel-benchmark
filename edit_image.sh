#!/bin/bash

# Mounts the given disk image for editing. The first argument is the disk image
# filename, and all remaining arguments are files to be copied to the image.
# Copies any given files to the /root directory, and if those files contain a
# #!/path/to/shell, then treat them as scripts and put calls to them using their
# appropriate shells in /root/.profile, which will be executed on login.
# If no files are given, mounts the image and chroots in for editing manually.

# Based on the instructions from https://www.collabora.com/news-and-blog/blog/2017/01/16/setting-up-qemu-kvm-for-kernel-development/

SHUTDOWN=
if [[ "$1" == "-s" ]]; then SHUTDOWN="1"; shift; fi

[ -n "$1" ] && IMG=$1 || IMG=qemu_image.img

[ -f $IMG ] || { echo "ERROR: qemu disk image does not exist: $IMG"; exit 1; }

shift   # exclude $1 from $@

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
