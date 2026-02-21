#!/bin/bash
set -e

echo "============================================="
echo "  Step 2: Building Kernel with USB Ethernet"
echo "============================================="

cd ~/pi-distro

# Clone kernel if needed
if [ ! -d "linux" ]; then
    echo ""
    echo "=== Cloning Linux Kernel ==="
    git clone --depth=1 https://github.com/raspberrypi/linux
fi

cd linux

echo ""
echo "=== Configuring Kernel ==="
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

# Start with Pi 3/4 config
make bcm2711_defconfig

# Disable EFI (causes boot issues on Pi)
scripts/config --disable CONFIG_EFI_STUB
scripts/config --disable CONFIG_EFI

# Enable SD card support (built-in)
scripts/config --set-val CONFIG_MMC y
scripts/config --set-val CONFIG_MMC_BCM2835 y
scripts/config --set-val CONFIG_MMC_SDHCI y
scripts/config --set-val CONFIG_MMC_SDHCI_IPROC y

# Enable USB Ethernet drivers (built-in)
echo "Enabling USB Ethernet drivers..."
scripts/config --enable CONFIG_USB_USBNET
scripts/config --set-val CONFIG_USB_NET_DM9601 y
scripts/config --set-val CONFIG_USB_NET_SR9700 y
scripts/config --set-val CONFIG_USB_NET_SMSC95XX y
scripts/config --set-val CONFIG_USB_NET_ASIX y
scripts/config --set-val CONFIG_USB_NET_AX88179_178A y
scripts/config --set-val CONFIG_USB_NET_CDC_EEM y
scripts/config --set-val CONFIG_USB_NET_CDC_SUBSET y
scripts/config --set-val CONFIG_USB_NET_CDC_NCM y
scripts/config --set-val CONFIG_USB_NET_CDC_ETHER y
scripts/config --set-val CONFIG_USB_RTL8152 y

# Disable problematic netfilter modules
scripts/config --disable CONFIG_IP_NF_TARGET_ECN
scripts/config --disable CONFIG_NETFILTER_XT_TARGET_DSCP
scripts/config --disable CONFIG_NETFILTER_XT_TARGET_HL
scripts/config --disable CONFIG_IP_NF_TARGET_TTL
scripts/config --disable CONFIG_IP6_NF_TARGET_HL

make olddefconfig

echo ""
echo "=== Building Kernel (this takes 20-30 minutes) ==="
make -j$(nproc) Image dtbs

echo ""
echo "=== Skipping module install (all drivers built-in) ==="

echo ""
echo "=== Kernel Built Successfully ==="
echo "Kernel: $(ls -lh arch/arm64/boot/Image | awk '{print $5}')"

echo ""
echo "============================================="
echo "  Step 2 Complete: Kernel compiled"
echo "============================================="