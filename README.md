# 🦀 RustPi

A minimal, custom-built Linux distribution for Raspberry Pi 3A+ featuring a Rust-based init system.

![Boot Time](https://img.shields.io/badge/boot%20time-~3s-green)
![Image Size](https://img.shields.io/badge/image%20size-512MB-blue)
![License](https://img.shields.io/badge/license-MIT-purple)

## Overview

RustPi demonstrates that building your own Linux distribution is achievable. The init system (PID 1) is written entirely in Rust, handling system initialization, service management, and process supervision.

### Features

- **Rust Init System** — Custom PID 1 with mount handling, networking, and service spawning
- **Minimal Footprint** — 512MB image with only essential components
- **Fast Boot** — ~3 second boot time to shell
- **SSH Access** — Dropbear SSH server for remote management
- **USB Networking** — Support for USB-Ethernet adapters with DHCP
- **Vagrant Build** — Reproducible build environment with Vagrant

## Quick Start with Vagrant

The easiest way to build RustPi is using Vagrant. This gives you a consistent build environment regardless of your host OS.

### Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (or VMware)

### Build

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/rustpi.git
cd rustpi

# Start the build VM (downloads Ubuntu, installs tools)
vagrant up

# SSH into the VM and build
vagrant ssh
build

# Or one-liner:
vagrant ssh -c "cd /vagrant && ./scripts/build-all.sh"
```

The built image will be available at `./output/rustpi-latest.img` on your host machine.

### Flash to SD Card

```bash
# On your HOST machine (not in Vagrant)
# Replace /dev/sdX with your SD card device
sudo ./scripts/flash-sd.sh /dev/sdX
```

### Vagrant Commands

| Command | Description |
|---------|-------------|
| `vagrant up` | Start and provision the VM |
| `vagrant ssh` | SSH into the VM |
| `vagrant halt` | Stop the VM |
| `vagrant destroy` | Delete the VM completely |
| `vagrant provision` | Re-run setup scripts |

Inside the VM:
| Command | Description |
|---------|-------------|
| `build` | Build RustPi (alias) |
| `clean` | Clean build artifacts |
| `cd /vagrant` | Go to project directory |

## Native Linux Build

If you prefer to build without Vagrant on a native Linux system:

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt install -y \
    build-essential \
    gcc-aarch64-linux-gnu \
    git wget curl \
    parted dosfstools e2fsprogs kpartx

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add aarch64-unknown-linux-musl
```

### Build

```bash
./scripts/build-all.sh
sudo ./scripts/flash-sd.sh /dev/sdX
```

## Project Structure

```
rustpi/
├── Vagrantfile             # Vagrant VM configuration
├── init/                   # Rust init system source
│   ├── Cargo.toml
│   └── src/main.rs
├── rootfs/                 # Root filesystem configuration
│   └── etc/
│       └── hostname
├── boot/                   # Boot partition files
│   ├── config.txt
│   └── cmdline.txt
├── scripts/                # Build automation
│   ├── build-all.sh        # Main build script
│   ├── build-init.sh       # Build Rust init
│   ├── build-busybox.sh    # Build BusyBox
│   ├── build-dropbear.sh   # Build Dropbear SSH
│   ├── create-rootfs.sh    # Assemble root filesystem
│   ├── create-image.sh     # Create SD card image
│   ├── flash-sd.sh         # Flash to SD card
│   └── clean.sh            # Clean build artifacts
├── configs/                # Build configurations
│   └── busybox.config
├── output/                 # Built images (on host)
└── docs/                   # Documentation
    ├── BUILDING.md
    └── DEBUGGING.md
```

## System Architecture

```
┌─────────────────────────────────────┐
│        User Applications            │
│       (Shell, SSH, Utilities)       │
├─────────────────────────────────────┤
│          Rust Init (PID 1)          │
├─────────────────────────────────────┤
│        BusyBox + musl libc          │
├─────────────────────────────────────┤
│       Linux Kernel (ARM64)          │
├─────────────────────────────────────┤
│      Raspberry Pi Bootloader        │
├─────────────────────────────────────┤
│    Hardware (Pi 3A+ / BCM2837)      │
└─────────────────────────────────────┘
```

## Components

| Component | Purpose | Size |
|-----------|---------|------|
| Rust Init | PID 1, system initialization | ~500KB |
| BusyBox | 300+ Unix utilities | ~1MB |
| Dropbear | SSH server | ~200KB |
| Linux Kernel | Pre-built from RPi firmware | ~8MB |
| Root FS | Configs, libs, symlinks | ~20MB |

## Connect to Your Pi

After flashing and booting:

```bash
# Find your Pi's IP (check router or use serial console)
ssh root@<IP_ADDRESS>

# Default: no password (just press Enter)
```

## Configuration

### Boot Config (`boot/config.txt`)

```ini
arm_64bit=1
kernel=kernel8.img
enable_uart=1
dtparam=audio=off
gpu_mem=16
```

### Kernel Parameters (`boot/cmdline.txt`)

```
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait rw init=/sbin/init
```

## Troubleshooting

| Symptom | Cause | Solution |
|---------|-------|----------|
| No green LED | Missing `bootcode.bin` | Copy from RPi firmware |
| Kernel panic | Wrong kernel format | Use pre-built `kernel8.img` |
| Init not found | Dynamic linking | Build with musl target |
| No network | Wrong driver | Check USB ID, load correct module |
| SSH denied | File ownership | `chown 0:0 /etc/passwd /etc/shadow` |

See [docs/DEBUGGING.md](docs/DEBUGGING.md) for detailed solutions.

## Documentation

- [Building from Source](docs/BUILDING.md) — Detailed build instructions
- [Debugging Guide](docs/DEBUGGING.md) — Common issues and solutions

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open a Pull Request

## License

MIT License — see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Raspberry Pi Foundation](https://github.com/raspberrypi) — Firmware and kernel
- [BusyBox](https://busybox.net/) — Unix utilities
- [Dropbear](https://github.com/mkj/dropbear) — SSH server
- [musl libc](https://musl.libc.org/) — Static linking support

---

**Built with 🦀 and curiosity**
