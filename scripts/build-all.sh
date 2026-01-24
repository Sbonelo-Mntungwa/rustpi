#!/bin/bash
#
# RustPi Build Script - Builds all components
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

echo "============================================="
echo "  RustPi Full Build"
echo "============================================="
echo ""

# Check prerequisites
check_prerequisites() {
    echo "[*] Checking prerequisites..."
    
    local missing=()
    
    command -v aarch64-linux-gnu-gcc >/dev/null 2>&1 || missing+=("aarch64-linux-gnu-gcc")
    command -v rustup >/dev/null 2>&1 || missing+=("rustup")
    command -v make >/dev/null 2>&1 || missing+=("make")
    command -v git >/dev/null 2>&1 || missing+=("git")
    command -v parted >/dev/null 2>&1 || missing+=("parted")
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo "[!] Missing required tools: ${missing[*]}"
        echo ""
        echo "Install on Ubuntu/Debian:"
        echo "  sudo apt install gcc-aarch64-linux-gnu build-essential git parted"
        echo ""
        echo "Install Rust:"
        echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        exit 1
    fi
    
    # Check for Rust target
    if ! rustup target list --installed | grep -q "aarch64-unknown-linux-musl"; then
        echo "[*] Adding Rust target: aarch64-unknown-linux-musl"
        rustup target add aarch64-unknown-linux-musl
    fi
    
    echo "[✓] All prerequisites met"
}

# Create build directory
setup_build_dir() {
    echo "[*] Setting up build directory..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
}

# Build components
build_all() {
    echo ""
    echo "[1/5] Building Rust init system..."
    "$SCRIPT_DIR/build-init.sh"
    
    echo ""
    echo "[2/5] Building BusyBox..."
    "$SCRIPT_DIR/build-busybox.sh"
    
    echo ""
    echo "[3/5] Building Dropbear SSH..."
    "$SCRIPT_DIR/build-dropbear.sh"
    
    echo ""
    echo "[4/5] Creating root filesystem..."
    "$SCRIPT_DIR/create-rootfs.sh"
    
    echo ""
    echo "[5/5] Creating SD card image..."
    "$SCRIPT_DIR/create-image.sh"
}

# Main
check_prerequisites
setup_build_dir
build_all

echo ""
echo "============================================="
echo "  Build Complete!"
echo "============================================="
echo ""
echo "Output: $BUILD_DIR/sdcard.img"
echo ""
echo "Flash to SD card:"
echo "  sudo $SCRIPT_DIR/flash-sd.sh /dev/sdX"
echo ""
