#!/bin/bash

command -v capstan
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

    curl -# -L $URL > $DIR/capstan
    chmod u+x $DIR/capstan
fi
