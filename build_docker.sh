#!/bin/sh

DOCKERIMG="$1"
[ -n "$DOCKERIMG" ] || DOCKERIMG="rusty-nail-docker"

# docker must be installed
command -v docker > /dev/null || { echo "ERROR: docker must be installed; https://docs.docker.com/engine/install/"; exit 1; }

CWD="$(pwd)"

TMPDIR="/tmp/$DOCKERIMG"

mkdir -p "$TMPDIR"

cd "$TMPDIR"

if [ ! -d "rusty-nail" ]; then
    git clone https://github.com/olivercalder/rusty-nail
fi

docker build -f "${CWD}/Dockerfile" -t "$DOCKERIMG" .

cd "$CWD"

rm -rf "$TMPDIR"
