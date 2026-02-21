#!/bin/bash
set -e

echo "============================================="
echo "  Step 3: Build Rust Init System"
echo "============================================="

source ~/.cargo/env
cd ~/pi-distro

# Copy init source from synced folder if it exists
if [ -d "/vagrant/init" ]; then
    echo "=== Copying init source from /vagrant/init ==="
    cp -r /vagrant/init ~/pi-distro/
else
    echo "=== Using existing init source ==="
fi

# Verify files exist
if [ ! -f "init/Cargo.toml" ] || [ ! -f "init/src/main.rs" ]; then
    echo "ERROR: init/Cargo.toml or init/src/main.rs not found!"
    echo "Make sure the init folder exists with Cargo.toml and src/main.rs"
    exit 1
fi

echo ""
echo "=== Building init system ==="
cd ~/pi-distro/init
cargo build --release --target aarch64-unknown-linux-musl

echo ""
echo "============================================="
echo "  Step 3 Complete: Init system built"
echo "============================================="
echo ""
ls -lh target/aarch64-unknown-linux-musl/release/init
file target/aarch64-unknown-linux-musl/release/init