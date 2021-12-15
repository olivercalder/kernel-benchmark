#!/bin/sh

CWD="$(pwd)"

[ -d "osv" ] || git clone https://github.com/cloudius-systems/osv.git
cd osv

sed -i 's/-nostartfiles//g' Makefile
sed -i 's/-nodefaultlibs//g' Makefile

git submodule update --init --recursive
cd apps

[ -d "rusty-nail" ] || git clone https://github.com/olivercalder/rusty-nail.git
cd rusty-nail

cat > Makefile <<EOF
.PHONY: module
module: target/release/rusty-nail
	echo '/rusty-nail: \$\${MODULE_DIR}/target/release/rusty-nail' > usr.manifest

target/release/rusty-nail: src/main.rs src/png.rs
	cargo --version && cargo build --release || echo "Please install Rust"

clean:
	-cargo clean
	rm -f usr.manifest
EOF

cat > module.py <<EOF
from osv.modules import api

default = api.run(cmdline="/rusty-nail")
EOF

grep 'rustc_version_runtime' Cargo.toml || echo 'rustc_version_runtime = "0.1.*"' >> Cargo.toml

cd "${CWD}/osv"

./scripts/build image=rusty-nail

cd "$CWD"
