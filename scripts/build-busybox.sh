#!/bin/bash
#
# Build BusyBox for ARM64
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
CONFIG_FILE="$PROJECT_DIR/configs/busybox.config"

echo "[busybox] Building BusyBox..."

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clone BusyBox if not present
if [ ! -d "busybox" ]; then
    echo "[busybox] Cloning BusyBox..."
    git clone --depth=1 https://git.busybox.net/busybox
fi

cd busybox

# Clean previous build
make distclean 2>/dev/null || true

# Use custom config or create default
if [ -f "$CONFIG_FILE" ]; then
    echo "[busybox] Using custom configuration"
    cp "$CONFIG_FILE" .config
else
    echo "[busybox] Creating default configuration"
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
    
    # Enable static linking
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
    
    # Disable some unnecessary features for smaller binary
    sed -i 's/CONFIG_FEATURE_SH_STANDALONE=y/# CONFIG_FEATURE_SH_STANDALONE is not set/' .config
fi

# Build
echo "[busybox] Compiling (this may take a few minutes)..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)

# Copy binary
mkdir -p "$BUILD_DIR/bin"
cp busybox "$BUILD_DIR/bin/"

# Verify
if file "$BUILD_DIR/bin/busybox" | grep -q "statically linked"; then
    echo "[busybox] ✓ Binary is statically linked"
else
    echo "[busybox] ⚠ Warning: Binary may not be statically linked"
fi

SIZE=$(du -h "$BUILD_DIR/bin/busybox" | cut -f1)
echo "[busybox] ✓ Built BusyBox: $SIZE"
