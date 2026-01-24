# Building RustPi from Source

This guide walks you through building RustPi on a Linux host.

## Prerequisites

### Required Packages (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install -y \
    build-essential \
    gcc-aarch64-linux-gnu \
    git \
    parted \
    dosfstools \
    e2fsprogs \
    wget \
    curl
```

### Rust Toolchain

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Add ARM64 musl target for static linking
rustup target add aarch64-unknown-linux-musl

# Verify
rustc --version
rustup target list --installed | grep aarch64
```

## Quick Build

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/rustpi.git
cd rustpi

# Make scripts executable
chmod +x scripts/*.sh

# Build everything
./scripts/build-all.sh

# Flash to SD card
sudo ./scripts/flash-sd.sh /dev/sdX
```

## Manual Build Steps

### 1. Build Rust Init System

```bash
cd init

# Build for ARM64 with static linking
cargo build --release --target aarch64-unknown-linux-musl

# Verify it's statically linked
file target/aarch64-unknown-linux-musl/release/rustpi-init
# Should show: "statically linked"
```

### 2. Build BusyBox

```bash
mkdir -p build && cd build

# Clone BusyBox
git clone --depth=1 https://git.busybox.net/busybox
cd busybox

# Configure
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig

# Enable static linking
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config

# Build
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)

# Verify
file busybox
# Should show: "statically linked"
```

### 3. Build Dropbear SSH

```bash
cd build

# Clone Dropbear
git clone --depth=1 https://github.com/mkj/dropbear.git
cd dropbear

# Configure for cross-compilation
./configure \
    --host=aarch64-linux-gnu \
    CC=aarch64-linux-gnu-gcc \
    --disable-zlib \
    --disable-wtmp \
    --disable-lastlog

# Build with static linking
make PROGRAMS="dropbear dropbearkey" STATIC=1 LDFLAGS="-static" -j$(nproc)
```

### 4. Get Raspberry Pi Firmware

```bash
cd build

# Clone firmware (contains bootloader and pre-built kernel)
git clone --depth=1 https://github.com/raspberrypi/firmware.git
```

### 5. Create Root Filesystem

```bash
ROOTFS=build/rootfs
mkdir -p $ROOTFS/{bin,sbin,etc,proc,sys,dev,tmp,root,var,usr,lib,run}

# Copy binaries
cp build/bin/init $ROOTFS/sbin/init
cp build/busybox/busybox $ROOTFS/bin/
cp build/dropbear/dropbear $ROOTFS/bin/
cp build/dropbear/dropbearkey $ROOTFS/bin/

# Create BusyBox symlinks
cd $ROOTFS/bin
for cmd in sh ls cat cp mv rm mkdir mount ifconfig; do
    ln -sf busybox $cmd
done
cd -

# Copy config files
cp -r rootfs/etc/* $ROOTFS/etc/
```

### 6. Create SD Card Image

```bash
# Create 512MB image
dd if=/dev/zero of=build/sdcard.img bs=1M count=512

# Partition
parted build/sdcard.img --script mklabel msdos
parted build/sdcard.img --script mkpart primary fat32 4MiB 128MiB
parted build/sdcard.img --script mkpart primary ext4 128MiB 100%
parted build/sdcard.img --script set 1 boot on

# Setup loop device
LOOPDEV=$(sudo losetup -fP --show build/sdcard.img)

# Format
sudo mkfs.vfat -F 32 -n BOOT ${LOOPDEV}p1
sudo mkfs.ext4 -L rootfs ${LOOPDEV}p2

# Mount
mkdir -p build/mnt/boot build/mnt/root
sudo mount ${LOOPDEV}p1 build/mnt/boot
sudo mount ${LOOPDEV}p2 build/mnt/root

# Copy boot files
sudo cp build/firmware/boot/bootcode.bin build/mnt/boot/
sudo cp build/firmware/boot/start.elf build/mnt/boot/
sudo cp build/firmware/boot/fixup.dat build/mnt/boot/
sudo cp build/firmware/boot/kernel8.img build/mnt/boot/
sudo cp build/firmware/boot/bcm2710-rpi-3-b-plus.dtb build/mnt/boot/
sudo cp boot/config.txt build/mnt/boot/
sudo cp boot/cmdline.txt build/mnt/boot/

# Copy root filesystem
sudo cp -a build/rootfs/* build/mnt/root/
sudo chown -R 0:0 build/mnt/root

# Unmount
sudo umount build/mnt/boot build/mnt/root
sudo losetup -d $LOOPDEV
```

### 7. Flash to SD Card

```bash
# WARNING: Make sure /dev/sdX is your SD card!
sudo dd if=build/sdcard.img of=/dev/sdX bs=4M status=progress
sync
```

## Troubleshooting Build Issues

### "musl-gcc not found"

Install the musl toolchain:

```bash
# Ubuntu/Debian
sudo apt install musl-tools

# Or use the Rust-provided musl
rustup target add aarch64-unknown-linux-musl
```

### "aarch64-linux-gnu-gcc not found"

```bash
sudo apt install gcc-aarch64-linux-gnu
```

### "parted: command not found"

```bash
sudo apt install parted
```

### Loop device errors

Make sure loop module is loaded:

```bash
sudo modprobe loop
```

## Build Output

After successful build:

```
build/
├── sdcard.img          # Bootable SD card image (512MB)
├── bin/
│   ├── init            # Rust init binary
│   ├── busybox         # BusyBox binary
│   ├── dropbear        # SSH server
│   └── dropbearkey     # SSH key generator
├── rootfs/             # Root filesystem tree
├── busybox/            # BusyBox source
├── dropbear/           # Dropbear source
└── firmware/           # RPi firmware
```
