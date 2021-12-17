#!/bin/sh

CWD="$(pwd)"

[ -d "osv" ] || git clone https://github.com/cloudius-systems/osv.git
cd osv

sed -i 's/-nostartfiles//g' Makefile
sed -i 's/-nodefaultlibs//g' Makefile
sed -i '1930s/\/usr//' Makefile

git submodule update --init --recursive
cd apps

[ -d "rusty-nail" ] || git clone https://github.com/olivercalder/rusty-nail.git
cd rusty-nail

cat > Makefile <<EOF
.PHONY: module
module: target/release/rusty-nail
	echo '/rusty-nail: \$\${MODULE_DIR}/target/release/rusty-nail' > usr.manifest
	echo '/mount: /usr/bin/mount' >> usr.manifest

target/release/rusty-nail: src/main.rs src/png.rs
	cargo --version && cargo build --release || echo "Please install Rust"

clean:
	-cargo clean
	rm -f usr.manifest
EOF

cat > module.py <<EOF
from osv.modules import api

default = api.run(cmdline="mount -t virtiofs mydir /mnt; rusty-nail /mnt/image.png /mnt/thumbnail.png")
EOF

grep 'rustc_version_runtime' Cargo.toml || echo 'rustc_version_runtime = "0.1.*"' >> Cargo.toml

cd "${CWD}/osv"

./scripts/build image=rusty-nail

cd "$CWD"

command -v virtiofsd > /dev/null
if [ $? -ne 0 ]; then
    # Ofted, virtiofsd
    mkdir -p "$HOME/.local/bin"
    if [ -f "/usr/libexec/virtiofsd" ]; then    # location on Fedora
        ln -s "/usr/libexec/virtiofsd" "$HOME/.local/bin/"
    elif [ -f "/usr/lib/qemu/virtiofsd" ]; then # location on Ubuntu
        ln -s "/usr/lib/qemu/virtiofsd" "$HOME/.local/bin/"
    fi
    # Add $HOME/.local/bin to path if it is not yet in the path
    case ":${PATH}:" in
        *:"${HOME}/.local/bin":*)
            ;;
        *)
            export PATH="${HOME}/.local/bin:${PATH}"
            ;;
    esac
    # If osv/scripts/run.py is run in a different terminal, may need to export
    # path to include $HOME/.local/bin again manually
fi
