#!/bin/sh

usage() { echo "USAGE: sh $0 [OPTIONS]

OPTIONS:
    -h                      display help
    -i <imagename>          specify a name for the new qemu disk image
    -s <size>               create disk image with the given size, default 384M (format from qemu-img manpage)
" 1>&2; exit 1; }

SIZE="384M"

IMG="qemu_image.img"

while getopts ":hi:s:" OPT; do
    case "$OPT" in
        h)
            usage
            ;;
        i)
            IMG="$OPTARG"
            ;;
        s)
            SIZE="$OPTARG"
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND - 1))

TS=$(date +%s%N)
DIR="/tmp/mount_dir-$TS"

[ "$(echo "$IMG" | sed -r 's/.*(.{4})/\1/')" = ".img" ] || { echo "ERROR: image file must have suffix .img"; exit 1; }

echo "Building $IMG..."

command -v debootstrap > /dev/null || { 
    echo "ERROR: please install debootstrap"
    echo "    If not on a Debian-based system, a pre-built image is available at"
    echo "    https://calder.dev/files/qemu_image.img"
    exit 1
}

if [ -f "$IMG" ]; then
    echo "WARNING: $IMG already exists. Overwrite it? [N/y] "
    read -r RESP
    if [ "$RESP" = "y" ]; then
        rm "$IMG"
    else
        echo "$IMG unchanged."
        exit 0
    fi
fi

qemu-img create "$IMG" "$SIZE"  # create a qemu disk image
mkfs.ext2 "$IMG"    # ext2 is simple and fast, not journaled
mkdir -p "$DIR"
sudo mount -o loop "$IMG" "$DIR"    # uses a loop device to map the disk image to the directory
sudo debootstrap --arch amd64 buster "$DIR" # install a minimal Debian Buster system
sudo chroot "$DIR" passwd -d root   # remove root password
sudo rm -f "$DIR/etc/hostname"      # remove hostname so that it is always localhost

# set up autologin to the ttyS0 terminal using getty
GETTYDIR="$DIR/etc/systemd/system/serial-getty@ttyS0.service.d"
sudo mkdir -p "$GETTYDIR"
OVER="/tmp/$TS-override.conf"
echo '[Service]' > "$OVER"
echo 'ExecStart=' >> "$OVER"
echo 'ExecStart=-/sbin/agetty --autologin root --noclear %I vt220' >> "$OVER"
sudo mv "$OVER" "$GETTYDIR/override.conf"

sudo umount "$DIR"
rmdir "$DIR"
