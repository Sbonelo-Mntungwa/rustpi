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

### System Architecture

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

## Quick Start

### Prerequisites

- Linux host (or VM) with:
  - `aarch64-linux-gnu-gcc` cross-compiler
  - Rust with `aarch64-unknown-linux-musl` target
  - Standard build tools (`make`, `git`, `parted`, etc.)
- Raspberry Pi 3A+ (or 3B/3B+/4)
- SD card (1GB minimum)
- USB-Ethernet adapter (for Pi 3A+)

### Build

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/rustpi.git
cd rustpi

# Install Rust target
rustup target add aarch64-unknown-linux-musl

# Run full build
./scripts/build-all.sh

# Flash to SD card (replace /dev/sdX)
./scripts/flash-sd.sh /dev/sdX
```

### Connect

```bash
# Find Pi's IP (check your router or use serial console)
ssh root@<PI_IP_ADDRESS>
# Default: no password (press Enter)
```

## Project Structure

```
rustpi/
├── init/                   # Rust init system source
│   ├── Cargo.toml
│   └── src/main.rs
├── rootfs/                 # Root filesystem configuration
│   ├── etc/
│   │   ├── passwd
│   │   ├── group
│   │   └── hostname
│   └── usr/share/udhcpc/
│       └── default.script
├── boot/                   # Boot partition files
│   ├── config.txt
│   └── cmdline.txt
├── scripts/                # Build automation
│   ├── build-all.sh
│   ├── build-init.sh
│   ├── build-busybox.sh
│   ├── build-dropbear.sh
│   ├── create-rootfs.sh
│   ├── create-image.sh
│   └── flash-sd.sh
├── configs/                # Build configurations
│   └── busybox.config
└── docs/                   # Documentation
    ├── BUILDING.md
    └── DEBUGGING.md
```

## Documentation

- [Building from Source](docs/BUILDING.md) — Detailed build instructions
- [Debugging Guide](docs/DEBUGGING.md) — Common issues and solutions

## How It Works

### Boot Sequence

1. **GPU Boot** — VideoCore loads `bootcode.bin` from SD card
2. **Firmware** — `start.elf` reads `config.txt`, loads kernel
3. **Kernel** — Linux initializes hardware, mounts root filesystem
4. **Init** — Rust init (`/sbin/init`) becomes PID 1
5. **Services** — Init mounts filesystems, configures network, starts SSH
6. **Ready** — System ready for login

### The Rust Init System

The init system handles:

```rust
fn main() {
    mount_filesystems();    // /proc, /sys, /dev, /tmp
    setup_hostname();       // Set system hostname
    setup_devices();        // Create device symlinks
    load_kernel_modules();  // USB-Ethernet driver
    setup_networking();     // DHCP configuration
    start_ssh_server();     // Dropbear daemon
    spawn_shell();          // Login shell
    reap_zombies();         // Process supervision
}
```

## Components

| Component | Purpose | Size |
|-----------|---------|------|
| Rust Init | PID 1, system initialization | ~500KB |
| BusyBox | 300+ Unix utilities | ~1MB |
| Dropbear | SSH server | ~200KB |
| Linux Kernel | Pre-built from RPi firmware | ~8MB |
| Root FS | Configs, libs, symlinks | ~20MB |

## Configuration

### Boot Config (`boot/config.txt`)

```ini
arm_64bit=1
kernel=kernel8.img
device_tree=bcm2710-rpi-3-b-plus.dtb
enable_uart=1
```

### Kernel Parameters (`boot/cmdline.txt`)

```
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait rw init=/sbin/init
```

## Customization

### Adding a New Service

Edit `init/src/main.rs`:

```rust
fn start_my_service() {
    spawn_daemon("/usr/bin/my-service", &["--daemon"]);
}
```

### Changing Hostname

Edit `rootfs/etc/hostname`:

```
my-custom-pi
```

### Adding Packages

Add binaries to `create-rootfs.sh` and ensure they're statically linked or include required libraries.

## Troubleshooting

| Symptom | Cause | Solution |
|---------|-------|----------|
| No green LED | Missing `bootcode.bin` | Copy from RPi firmware |
| Kernel panic | Wrong kernel format | Use pre-built `kernel8.img` |
| Init not found | Dynamic linking | Build with `--target aarch64-unknown-linux-musl` |
| No network | Wrong driver | Check USB ID, load correct module |
| SSH denied | File ownership | `chown 0:0 /etc/passwd /etc/shadow` |

See [DEBUGGING.md](docs/DEBUGGING.md) for detailed solutions.

## Contributing

Contributions welcome! Please:

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
