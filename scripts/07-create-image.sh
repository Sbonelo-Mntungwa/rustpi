#!/bin/bash
set -e

echo "============================================="
echo "  Step 7: Create SD Card Image"
echo "============================================="

cd ~/pi-distro

mkdir -p output
rm -f output/rustpi.img

echo ""
echo "=== Creating 512MB image file ==="
dd if=/dev/zero of=output/rustpi.img bs=1M count=512 status=progress

echo ""
echo "=== Creating partition table ==="
sudo parted output/rustpi.img --script \
    mklabel msdos \
    mkpart primary fat32 1MiB 128MiB \
    mkpart primary ext4 128MiB 100% \
    set 1 boot on

echo ""
echo "=== Setting up loop device ==="
sudo losetup -fP output/rustpi.img
LOOP=$(losetup -j output/rustpi.img | cut -d: -f1)
echo "Loop device: $LOOP"

echo ""
echo "=== Formatting partitions ==="
sudo mkfs.vfat -F 32 -n BOOT ${LOOP}p1
sudo mkfs.ext4 -L rootfs ${LOOP}p2

echo ""
echo "=== Mounting partitions ==="
mkdir -p /tmp/boot /tmp/rootfs
sudo mount ${LOOP}p1 /tmp/boot
sudo mount ${LOOP}p2 /tmp/rootfs

echo ""
echo "=== Copying boot files (using COMPILED kernel) ==="

# Bootloader files (from firmware)
sudo cp firmware/boot/bootcode.bin /tmp/boot/
sudo cp firmware/boot/start.elf /tmp/boot/
sudo cp firmware/boot/fixup.dat /tmp/boot/

# COMPILED kernel with USB Ethernet drivers built-in
sudo cp linux/arch/arm64/boot/Image /tmp/boot/kernel8.img

# Device trees for Pi 3A+ and Pi 3B+
sudo cp linux/arch/arm64/boot/dts/broadcom/bcm2710-rpi-3-b.dtb /tmp/boot/
sudo cp linux/arch/arm64/boot/dts/broadcom/bcm2710-rpi-3-b-plus.dtb /tmp/boot/
sudo cp linux/arch/arm64/boot/dts/broadcom/bcm2837-rpi-3-a-plus.dtb /tmp/boot/

echo ""
echo "=== Creating boot configuration ==="

# config.txt
sudo tee /tmp/boot/config.txt << 'CONFIG'
arm_64bit=1
kernel=kernel8.img
device_tree=bcm2710-rpi-3-b-plus.dtb
disable_overscan=1
enable_uart=1
CONFIG

# cmdline.txt (single line, no trailing newline)
echo -n "console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait rw init=/sbin/init" | sudo tee /tmp/boot/cmdline.txt > /dev/null

echo ""
echo "=== Copying root filesystem ==="
sudo cp -a rootfs/* /tmp/rootfs/
sudo chown -R 0:0 /tmp/rootfs/

echo ""
echo "=== Verifying boot partition ==="
ls -la /tmp/boot/

echo ""
echo "=== Verifying root filesystem ==="
ls -la /tmp/rootfs/

echo ""
echo "=== Unmounting partitions ==="
sudo umount /tmp/boot /tmp/rootfs
sudo losetup -d $LOOP

echo ""
echo "=== Copying image to shared folder ==="
cp output/rustpi.img /vagrant/

echo ""
echo "============================================="
echo "  Step 7 Complete: SD card image created"
echo "============================================="
echo ""
echo "Image: output/rustpi.img ($(ls -lh output/rustpi.img | awk '{print $5}'))"
echo "Also:  /vagrant/rustpi.img"
echo ""
echo "On Mac, flash with:"
echo "  diskutil unmountDisk /dev/disk4"
echo "  sudo dd if=rustpi.img of=/dev/rdisk4 bs=4m status=progress"
echo "  diskutil eject /dev/disk4"