# Building RustPi from Source

This guide covers both Vagrant-based and native Linux builds.

## Option 1: Vagrant (Recommended)

Vagrant provides a consistent, reproducible build environment.

### Prerequisites

1. Install [Vagrant](https://www.vagrantup.com/downloads)
2. Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads)

### Build Steps

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/rustpi.git
cd rustpi

# Start VM (first time takes ~10 minutes to download and provision)
vagrant up

# SSH into VM
vagrant ssh

# Build RustPi
build
# Or: cd /vagrant && ./scripts/build-all.sh

# Exit VM
exit

# Image is now at ./output/rustpi-latest.img on your host
```

### Vagrant Tips

```bash
# Stop VM (preserves state)
vagrant halt

# Restart VM
vagrant up

# Destroy VM completely
vagrant destroy

# Re-run provisioning
vagrant provision

# SSH and run command directly
vagrant ssh -c "build"
```

## Option 2: Native Linux

### Prerequisites (Ubuntu/Debian)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install build tools
sudo apt install -y \
    build-essential \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    git \
    wget \
    curl \
    parted \
    dosfstools \
    e2fsprogs \
    kpartx \
    qemu-user-static \
    libncurses-dev \
    flex \
    bison \
    libssl-dev \
    bc

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Add ARM64 musl target
rustup target add aarch64-unknown-linux-musl

# Install musl tools
sudo apt install musl-tools

# Configure cross-linker
mkdir -p ~/.cargo
cat >> ~/.cargo/config.toml << 'EOF'
[target.aarch64-unknown-linux-musl]
linker = "aarch64-linux-gnu-gcc"
EOF
```

### Build Steps

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

## Build Process Overview

The build process runs these scripts in order:

1. **build-init.sh** — Compiles the Rust init system
2. **build-busybox.sh** — Compiles BusyBox utilities
3. **build-dropbear.sh** — Compiles Dropbear SSH server
4. **create-rootfs.sh** — Assembles the root filesystem
5. **create-image.sh** — Creates the bootable SD card image

## Build Output

```
build/
├── bin/
│   ├── init           # Rust init binary
│   ├── busybox        # BusyBox binary
│   ├── dropbear       # SSH server
│   └── dropbearkey    # SSH key generator
├── rootfs/            # Root filesystem tree
├── busybox/           # BusyBox source
├── dropbear/          # Dropbear source
├── firmware/          # RPi firmware
└── sdcard.img         # Final bootable image

output/
├── rustpi-latest.img  # Copy of latest image
└── rustpi-YYYYMMDD.img # Dated backup
```

## Individual Script Usage

### Build Only Init

```bash
./scripts/build-init.sh
```

### Build Only BusyBox

```bash
./scripts/build-busybox.sh
```

### Clean Build

```bash
./scripts/clean.sh
./scripts/build-all.sh
```

## Customization

### Custom BusyBox Config

1. Build BusyBox once to generate default config
2. Copy to `configs/busybox.config`
3. Edit as needed
4. Rebuild

```bash
# Generate default config
cd build/busybox
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
cp .config ../../configs/busybox.config
```

### Adding Packages

Edit `scripts/create-rootfs.sh` to add files to the root filesystem.

### Changing Boot Config

Edit `boot/config.txt` and `boot/cmdline.txt`.

## Troubleshooting Build Issues

### "musl target not found"

```bash
rustup target add aarch64-unknown-linux-musl
```

### "aarch64-linux-gnu-gcc not found"

```bash
sudo apt install gcc-aarch64-linux-gnu
```

### Loop device errors

```bash
sudo modprobe loop
```

### Permission denied on /dev/loop*

Run with sudo or add user to disk group:
```bash
sudo usermod -aG disk $USER
# Log out and back in
```
