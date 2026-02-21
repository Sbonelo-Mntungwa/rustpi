#!/bin/bash
set -e

echo "============================================="
echo "  Step 4: Build BusyBox"
echo "============================================="

cd ~/pi-distro/busybox-1.36.1

echo ""
echo "=== Configuring BusyBox ==="
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig

echo ""
echo "=== Enabling static linking ==="
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config

echo ""
echo "=== Building BusyBox ==="
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)

echo ""
echo "============================================="
echo "  Step 4 Complete: BusyBox built"
echo "============================================="
echo ""
ls -lh busybox
file busybox
