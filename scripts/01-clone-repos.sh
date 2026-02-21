#!/bin/bash
set -e

echo "============================================="
echo "  Step 1: Clone Repositories"
echo "============================================="

cd ~/pi-distro

echo ""
echo "=== Cloning Raspberry Pi Firmware ==="
if [ ! -d "firmware" ]; then
    git clone --depth=1 https://github.com/raspberrypi/firmware
else
    echo "Firmware already exists, skipping..."
fi

echo ""
echo "=== Downloading BusyBox ==="
if [ ! -d "busybox-1.36.1" ]; then
    wget -q --show-progress https://busybox.net/downloads/busybox-1.36.1.tar.bz2
    tar xf busybox-1.36.1.tar.bz2
    rm busybox-1.36.1.tar.bz2
else
    echo "BusyBox already exists, skipping..."
fi

echo ""
echo "=== Downloading Dropbear ==="
if [ ! -d "dropbear-2024.86" ]; then
    wget -q --show-progress https://matt.ucc.asn.au/dropbear/releases/dropbear-2024.86.tar.bz2
    tar xf dropbear-2024.86.tar.bz2
    rm dropbear-2024.86.tar.bz2
else
    echo "Dropbear already exists, skipping..."
fi

echo ""
echo "============================================="
echo "  Step 1 Complete: Repositories cloned"
echo "============================================="
