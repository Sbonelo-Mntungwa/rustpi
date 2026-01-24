#!/bin/bash
#
# Flash SD card image to device
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
IMAGE="$BUILD_DIR/sdcard.img"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <device>"
    echo ""
    echo "Examples:"
    echo "  $0 /dev/sdb      # Linux"
    echo "  $0 /dev/disk4    # macOS"
    echo ""
    echo "WARNING: This will ERASE ALL DATA on the target device!"
    exit 1
}

if [ -z "$1" ]; then
    usage
fi

DEVICE="$1"

# Check if image exists
if [ ! -f "$IMAGE" ]; then
    echo -e "${RED}[!] Image not found: $IMAGE${NC}"
    echo "Run ./build-all.sh first"
    exit 1
fi

# Check if device exists
if [ ! -b "$DEVICE" ]; then
    echo -e "${RED}[!] Device not found: $DEVICE${NC}"
    exit 1
fi

# Confirm
echo -e "${YELLOW}=============================================${NC}"
echo -e "${YELLOW}  WARNING: This will ERASE ALL DATA on:${NC}"
echo -e "${YELLOW}  $DEVICE${NC}"
echo -e "${YELLOW}=============================================${NC}"
echo ""

# Show device info
if command -v lsblk &> /dev/null; then
    lsblk "$DEVICE"
elif command -v diskutil &> /dev/null; then
    diskutil info "$DEVICE" | grep -E "Device|Total Size|Volume Name"
fi

echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "[*] Unmounting device..."

# Unmount on Linux
if command -v umount &> /dev/null; then
    for part in "${DEVICE}"*; do
        sudo umount "$part" 2>/dev/null || true
    done
fi

# Unmount on macOS
if command -v diskutil &> /dev/null; then
    diskutil unmountDisk "$DEVICE" 2>/dev/null || true
fi

echo "[*] Flashing image to $DEVICE..."

# Determine raw device for macOS (faster)
RAW_DEVICE="$DEVICE"
if [[ "$OSTYPE" == "darwin"* ]]; then
    RAW_DEVICE="${DEVICE/disk/rdisk}"
fi

# Flash with progress
if command -v pv &> /dev/null; then
    # Use pv for progress bar
    sudo sh -c "pv '$IMAGE' | dd of='$RAW_DEVICE' bs=4M"
else
    # Use dd with status=progress
    sudo dd if="$IMAGE" of="$RAW_DEVICE" bs=4M status=progress
fi

# Sync
echo "[*] Syncing..."
sync

# Eject on macOS
if command -v diskutil &> /dev/null; then
    diskutil eject "$DEVICE" 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  Flash complete!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo "You can now:"
echo "1. Insert the SD card into your Raspberry Pi"
echo "2. Connect USB-Ethernet adapter"
echo "3. Connect to your network"
echo "4. Power on the Pi"
echo "5. SSH to the Pi: ssh root@<IP_ADDRESS>"
echo ""
