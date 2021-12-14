#!/bin/bash

command -v capstan > /dev/null
if [ $? -ne 0 ]; then
    # script from https://raw.githubusercontent.com/cloudius-systems/capstan/master/scripts/download
    set -e

    case "$OSTYPE" in
    darwin*)  NAME="darwin_capstan" ;;
    linux*)   NAME="capstan"  ;;
    freebsd*) NAME="capstan";;
    *)        echo "Your operating system ('$OSTYPE') is not supported by Capstan. Exiting." && exit 1 ;;
    esac

    case "$HOSTTYPE" in
    x86_64*)  ARCH="amd64" ;;
    amd64*)   ARCH="amd64" ;;
    *)        echo "OSv only supports 64-bit x86. Exiting." && exit 1 ;;
    esac

    URL="https://github.com/cloudius-systems/capstan/releases/latest/download/${NAME}"
    DIR="$HOME/.local/bin"

    mkdir -p $DIR

    echo "Downloading Capstan binary: $URL"

    curl -# -L -o $DIR/capstan $URL

    chmod u+x $DIR/capstan
fi

command -v build-capstan-base-image > /dev/null
if [ $? -ne 0 ]; then
    URL="https://github.com/cloudius-systems/osv/blob/master/scripts/build-capstan-base-image"
    DIR="$HOME/.local/bin"

    mkdir -p $DIR

    echo "Downloading Capstan image builder: $URL"

    curl -# -L -o $DIR/build-capstan-base-image $URL

    chmod u+x $DIR/build-capstan-base-image
fi
