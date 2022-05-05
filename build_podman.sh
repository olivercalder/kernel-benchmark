#!/bin/sh

PODMANIMG="$1"
[ -n "$PODMANIMG" ] || PODMANIMG="rusty-nail-podman"

# podman must be installed
command -v podman > /dev/null || { echo "ERROR: podman must be installed"; exit 1; }

CWD="$(pwd)"

TMPDIR="/tmp/$PODMANIMG"

mkdir -p "$TMPDIR"

cd "$TMPDIR"

if [ ! -d "rusty-nail" ]; then
    git clone ssh://git@github.com/olivercalder/rusty-nail
fi

podman --storage-opt overlay.mount_program=/usr/bin/fuse-overlayfs --storage-opt overlay.ignore_chown_errors=true build -f "${CWD}/Dockerfile" -t "$PODMANIMG" .

cd "$CWD"

rm -rf "$TMPDIR"
