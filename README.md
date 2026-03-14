# RustPi

A minimal Linux distribution for Raspberry Pi 3A+ with a custom Rust-based init system.

Boots in ~3 seconds with a Rust init (PID 1), BusyBox utilities, Dropbear SSH, and a custom-compiled kernel — all in a 512MB image.

## Quick Start

```bash
# 1. Start the build VM (first time ~10 min)
vagrant up

# 2. SSH in and build everything (~45-60 min)
vagrant ssh
cd ~/pi-distro/scripts
./00-build-all.sh

# 3. Flash to SD card (on Mac)
diskutil unmountDisk /dev/diskN
sudo dd if=rustpi.img of=/dev/rdiskN bs=4m status=progress
diskutil eject /dev/diskN

# 4. SSH into your Pi
ssh root@<pi-ip>
```

## What's Included

| Component | Technology | Size |
|-----------|-----------|------|
| Init system | Rust (PID 1) | ~400KB |
| Shell + utilities | BusyBox | ~1.5MB |
| SSH server | Dropbear (musl-linked) | ~400KB |
| Kernel | Linux 6.x ARM64 | ~22MB |
| Device tree | bcm2710-rpi-3-b-plus.dtb | ~25KB |

## Architecture

- **Rust init system** — PID 1 handling mounts, networking, SSH, and shell spawning
- **Static linking** — all binaries are musl-linked, no shared libraries on the Pi
- **Built-in kernel drivers** — all USB Ethernet drivers compiled as `=y`, no modules
- **DHCP with fallback** — tries DHCP first, falls back to static IP 192.168.1.100

## Requirements

**Hardware**: Raspberry Pi 3A+, SD card (8GB+), USB Ethernet dongle, power supply

**Software** (on your Mac):
```bash
brew install --cask vmware-fusion
brew install --cask vagrant
vagrant plugin install vagrant-vmware-desktop
```

## Build Steps

Each step can be run individually:

```bash
vagrant ssh
cd ~/pi-distro/scripts

./01-clone-repos.sh       # Clone firmware, kernel, BusyBox (~5 min)
./02-build-kernel.sh      # Compile Linux kernel (~20-30 min)
./03-build-init.sh        # Build Rust init system (~2 min)
./04-build-busybox.sh     # Build BusyBox utilities (~3 min)
./05-build-dropbear.sh    # Build Dropbear SSH with musl (~2 min)
./06-create-rootfs.sh     # Assemble root filesystem (~1 min)
./07-create-image.sh      # Create 512MB bootable image (~2 min)
```

## Connecting

```bash
# Find your Pi's IP
arp -a | grep -i "b8:27:eb"

# SSH in (default password: rustpi)
ssh root@<pi-ip>

# If SSH fails, use telnet as backup
telnet <pi-ip>

# Set a proper password after first login
passwd root
```

## Project Structure

```
rustpi/
├── Vagrantfile              # VM configuration (8GB RAM, 4 CPUs)
├── scripts/
│   ├── 00-build-all.sh      # Run all build steps
│   ├── 01-clone-repos.sh    # Download source code
│   ├── 02-build-kernel.sh   # Compile Linux kernel
│   ├── 03-build-init.sh     # Build Rust init system
│   ├── 04-build-busybox.sh  # Build BusyBox utilities
│   ├── 05-build-dropbear.sh # Build SSH server (musl)
│   ├── 06-create-rootfs.sh  # Assemble root filesystem
│   └── 07-create-image.sh   # Create bootable SD image
└── init/
    └── src/
        └── main.rs          # Rust init source code
```

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|---------|
| Rainbow screen forever | Kernel not loading | Rebuild with `02-build-kernel.sh` |
| Kernel panic: VFS | Wrong root device or DTB | Check `cmdline.txt` and `config.txt` |
| Kernel panic: init not found | Init missing or dynamically linked | Rebuild with musl target |
| No network | Interface not detected | Check USB dongle is connected, verify dmesg |
| SSH permission denied | /etc/passwd owned by UID 1000 | `chown 0:0 /etc/passwd /etc/shadow` |
| SSH "nonexistent user" | Dropbear linked against glibc | Rebuild Dropbear with `CC=musl-gcc` |

## License

MIT License — See LICENSE file
