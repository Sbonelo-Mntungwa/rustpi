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
LOOPDEV=$(sudo losetup -fP --show "$IMAGE")
echo "[image] Using loop device: $LOOPDEV"

# Format partitions
echo "[image] Formatting partitions..."
sudo mkfs.vfat -F 32 -n BOOT "${LOOPDEV}p1"
sudo mkfs.ext4 -L rootfs "${LOOPDEV}p2"

# Mount partitions
mkdir -p "$BUILD_DIR/mnt/boot" "$BUILD_DIR/mnt/root"
sudo mount "${LOOPDEV}p1" "$BUILD_DIR/mnt/boot"
sudo mount "${LOOPDEV}p2" "$BUILD_DIR/mnt/root"

# Copy boot files
echo "[image] Populating boot partition..."
sudo cp firmware/boot/bootcode.bin "$BUILD_DIR/mnt/boot/"
sudo cp firmware/boot/start.elf "$BUILD_DIR/mnt/boot/"
sudo cp firmware/boot/fixup.dat "$BUILD_DIR/mnt/boot/"
sudo cp firmware/boot/kernel8.img "$BUILD_DIR/mnt/boot/"
sudo cp firmware/boot/bcm2710-rpi-3-b-plus.dtb "$BUILD_DIR/mnt/boot/"
sudo cp firmware/boot/bcm2710-rpi-3-b.dtb "$BUILD_DIR/mnt/boot/"

# Copy kernel modules for USB-Ethernet
if [ -d "firmware/modules" ]; then
    echo "[image] Copying kernel modules..."
    sudo mkdir -p "$BUILD_DIR/mnt/root/lib/modules"
    sudo cp -r firmware/modules/* "$BUILD_DIR/mnt/root/lib/modules/"
fi

# Create config.txt
echo "[image] Creating boot configuration..."
sudo tee "$BUILD_DIR/mnt/boot/config.txt" > /dev/null << 'EOF'
# RustPi Boot Configuration
arm_64bit=1
kernel=kernel8.img
device_tree=bcm2710-rpi-3-b-plus.dtb
enable_uart=1
dtparam=audio=off
gpu_mem=16
EOF

# Create cmdline.txt
sudo tee "$BUILD_DIR/mnt/boot/cmdline.txt" > /dev/null << 'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait rw init=/sbin/init
EOF

# Copy root filesystem
echo "[image] Populating root filesystem..."
sudo cp -a "$ROOTFS"/* "$BUILD_DIR/mnt/root/"

# Ensure proper ownership
sudo chown -R 0:0 "$BUILD_DIR/mnt/root"

# Unmount
echo "[image] Unmounting..."
sudo umount "$BUILD_DIR/mnt/boot"
sudo umount "$BUILD_DIR/mnt/root"
sudo losetup -d "$LOOPDEV"

# Cleanup
rmdir "$BUILD_DIR/mnt/boot" "$BUILD_DIR/mnt/root" "$BUILD_DIR/mnt" 2>/dev/null || true

SIZE=$(du -h "$IMAGE" | cut -f1)
echo "[image] ✓ Created SD card image: $IMAGE ($SIZE)"
