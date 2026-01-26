#!/bin/bash
#
# RustPi Build Script - Builds all components
# 
# This script can run both inside Vagrant VM and on native Linux.
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

# Detect if running in Vagrant
if [ -d "/vagrant" ] && [ "$PROJECT_DIR" = "/vagrant" ]; then
    OUTPUT_DIR="/home/vagrant/output"
    IN_VAGRANT=true
else
    OUTPUT_DIR="$PROJECT_DIR/output"
    IN_VAGRANT=false
fi

echo "============================================="
echo "  RustPi Full Build"
echo "============================================="
echo ""
echo "Project:  $PROJECT_DIR"
echo "Build:    $BUILD_DIR"
echo "Output:   $OUTPUT_DIR"
echo "Vagrant:  $IN_VAGRANT"
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
        if [ "$IN_VAGRANT" = true ]; then
            echo "Try: vagrant provision"
        else
            echo "Install on Ubuntu/Debian:"
            echo "  sudo apt install gcc-aarch64-linux-gnu build-essential git parted"
            echo ""
            echo "Or use Vagrant:"
            echo "  vagrant up && vagrant ssh"
        fi
        exit 1
    fi
    
    # Check for Rust target
    if ! rustup target list --installed | grep -q "aarch64-unknown-linux-musl"; then
        echo "[*] Adding Rust target: aarch64-unknown-linux-musl"
        rustup target add aarch64-unknown-linux-musl
    fi
    
    echo "[✓] All prerequisites met"
}

# Create directories
setup_dirs() {
    echo "[*] Setting up directories..."
    mkdir -p "$BUILD_DIR"
    mkdir -p "$OUTPUT_DIR"
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

# Copy output
copy_output() {
    echo ""
    echo "[*] Copying output..."
    
    if [ -f "$BUILD_DIR/sdcard.img" ]; then
        cp "$BUILD_DIR/sdcard.img" "$OUTPUT_DIR/rustpi-$(date +%Y%m%d).img"
        
        # Also keep a "latest" symlink/copy
        cp "$BUILD_DIR/sdcard.img" "$OUTPUT_DIR/rustpi-latest.img"
        
        echo "[✓] Image copied to $OUTPUT_DIR/"
    fi
}

# Main
check_prerequisites
setup_dirs
build_all
copy_output

echo ""
echo "============================================="
echo "  Build Complete!"
echo "============================================="
echo ""
echo "Output files:"
ls -lh "$OUTPUT_DIR"/*.img 2>/dev/null || echo "  (no images found)"
echo ""
if [ "$IN_VAGRANT" = true ]; then
    echo "Images are available on your host at: ./output/"
    echo ""
    echo "Flash to SD card (on host):"
    echo "  sudo dd if=output/rustpi-latest.img of=/dev/sdX bs=4M status=progress"
else
    echo "Flash to SD card:"
    echo "  sudo $SCRIPT_DIR/flash-sd.sh /dev/sdX"
fi
echo ""
