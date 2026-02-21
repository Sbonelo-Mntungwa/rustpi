#!/bin/bash
set -e

echo "============================================="
echo "  Step 5: Build Dropbear SSH (musl)"
echo "============================================="

cd ~/pi-distro/dropbear-2024.86

echo ""
echo "=== Cleaning previous build ==="
make clean || true

echo ""
echo "=== Configuring Dropbear (musl) ==="
CC=musl-gcc ./configure --disable-zlib --enable-static

echo ""
echo "=== Building Dropbear ==="
make PROGRAMS="dropbear dropbearkey dbclient scp" MULTI=1 STATIC=1 CC=musl-gcc -j$(nproc)

echo ""
echo "============================================="
echo "  Step 5 Complete: Dropbear built (musl)"
echo "============================================="
echo ""
ls -lh dropbearmulti
file dropbearmulti