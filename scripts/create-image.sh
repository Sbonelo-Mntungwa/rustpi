#!/bin/bash
#
# Create bootable SD card image
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
ROOTFS="$BUILD_DIR/rootfs"
IMAGE="$BUILD_DIR/sdcard.img"
IMAGE_SIZE=512  # MB

echo "[image] Creating SD card image..."

cd "$BUILD_DIR"

# Download Raspberry Pi firmware if not present
if [ ! -d "firmware" ]; then
    echo "[image] Downloading Raspberry Pi firmware..."
    git clone --depth=1 https://github.com/raspberrypi/firmware.git
fi

# Create empty image
echo "[image] Creating ${IMAGE_SIZE}MB image..."
dd if=/dev/zero of="$IMAGE" bs=1M count=$IMAGE_SIZE status=progress

# Partition the image
echo "[image] Partitioning..."
parted "$IMAGE" --script mklabel msdos
parted "$IMAGE" --script mkpart primary fat32 4MiB 128MiB
parted "$IMAGE" --script mkpart primary ext4 128MiB 100%
parted "$IMAGE" --script set 1 boot on

# Setup loop device
echo "[image] Setting up loop device..."

# Try different methods for loop device setup
if command -v kpartx &> /dev/null; then
    # Use kpartx (works well in VMs)
    LOOPDEV=$(sudo losetup -f --show "$IMAGE")
    sudo kpartx -av "$LOOPDEV"
    BOOT_PART="/dev/mapper/$(basename $LOOPDEV)p1"
    ROOT_PART="/dev/mapper/$(basename $LOOPDEV)p2"
    USE_KPARTX=true
else
    # Use losetup -P
    LOOPDEV=$(sudo losetup -fP --show "$IMAGE")
    BOOT_PART="${LOOPDEV}p1"
    ROOT_PART="${LOOPDEV}p2"
    USE_KPARTX=false
fi

echo "[image] Using: BOOT=$BOOT_PART ROOT=$ROOT_PART"

# Wait for devices to appear
sleep 2

# Format partitions
echo "[image] Formatting partitions..."
sudo mkfs.vfat -F 32 -n BOOT "$BOOT_PART"
sudo mkfs.ext4 -L rootfs "$ROOT_PART"

# Mount partitions
mkdir -p "$BUILD_DIR/mnt/boot" "$BUILD_DIR/mnt/root"
sudo mount "$BOOT_PART" "$BUILD_DIR/mnt/boot"
sudo mount "$ROOT_PART" "$BUILD_DIR/mnt/root"

# Copy boot files
echo "[image] Populating boot partition..."
sudo cp firmware/boot/bootcode.bin "$BUILD_DIR/mnt/boot/"
sudo cp firmware/boot/start.elf "$BUILD_DIR/mnt/boot/"
sudo cp firmware/boot/fixup.dat "$BUILD_DIR/mnt/boot/"
sudo cp firmware/boot/kernel8.img "$BUILD_DIR/mnt/boot/"

# Copy device tree files
for dtb in bcm2710-rpi-3-b-plus.dtb bcm2710-rpi-3-b.dtb bcm2837-rpi-3-b.dtb; do
    if [ -f "firmware/boot/$dtb" ]; then
        sudo cp "firmware/boot/$dtb" "$BUILD_DIR/mnt/boot/"
    fi
done

# Copy overlays directory if it exists
if [ -d "firmware/boot/overlays" ]; then
    sudo cp -r firmware/boot/overlays "$BUILD_DIR/mnt/boot/"
fi

# Create config.txt
echo "[image] Creating boot configuration..."
if [ -f "$PROJECT_DIR/boot/config.txt" ]; then
    sudo cp "$PROJECT_DIR/boot/config.txt" "$BUILD_DIR/mnt/boot/"
else
    sudo tee "$BUILD_DIR/mnt/boot/config.txt" > /dev/null << 'EOF'
# RustPi Boot Configuration
arm_64bit=1
kernel=kernel8.img
enable_uart=1
dtparam=audio=off
gpu_mem=16
disable_splash=1
EOF
fi

# Create cmdline.txt
if [ -f "$PROJECT_DIR/boot/cmdline.txt" ]; then
    sudo cp "$PROJECT_DIR/boot/cmdline.txt" "$BUILD_DIR/mnt/boot/"
else
    sudo tee "$BUILD_DIR/mnt/boot/cmdline.txt" > /dev/null << 'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait rw init=/sbin/init
EOF
fi

# Copy kernel modules for USB-Ethernet
if [ -d "firmware/modules" ]; then
    echo "[image] Copying kernel modules..."
    sudo mkdir -p "$BUILD_DIR/mnt/root/lib/modules"
    sudo cp -r firmware/modules/* "$BUILD_DIR/mnt/root/lib/modules/" 2>/dev/null || true
fi

# Copy root filesystem
echo "[image] Populating root filesystem..."
sudo cp -a "$ROOTFS"/* "$BUILD_DIR/mnt/root/"

# Ensure proper ownership
sudo chown -R 0:0 "$BUILD_DIR/mnt/root"

# Unmount
echo "[image] Unmounting..."
sudo umount "$BUILD_DIR/mnt/boot"
sudo umount "$BUILD_DIR/mnt/root"

# Cleanup loop device
if [ "$USE_KPARTX" = true ]; then
    sudo kpartx -dv "$LOOPDEV"
fi
sudo losetup -d "$LOOPDEV"

# Cleanup mount dirs
rmdir "$BUILD_DIR/mnt/boot" "$BUILD_DIR/mnt/root" "$BUILD_DIR/mnt" 2>/dev/null || true

SIZE=$(du -h "$IMAGE" | cut -f1)
echo "[image] ✓ Created SD card image: $IMAGE ($SIZE)"
