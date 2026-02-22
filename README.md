# RustPi

A minimal Linux distribution for Raspberry Pi 3B with a custom Rust-based init system.

## What is RustPi?

RustPi is a from-scratch Linux distribution that boots in ~3 seconds and includes:

- **Custom Rust Init System** - PID 1 written in Rust
- **BusyBox** - 300+ Unix utilities in one binary
- **Dropbear SSH** - Lightweight SSH server for remote access
- **Compiled Linux Kernel** - Built specifically for Pi 3B

```
┌─────────────────────────────────────────────┐
│              RUSTPI DISTRO                  │
├─────────────────────────────────────────────┤
│  ✅ Rust Init System (PID 1)                │
│  ✅ BusyBox Shell + Utilities               │
│  ✅ Dropbear SSH Server                     │
│  ✅ DHCP Networking (static IP fallback)    │
│  ✅ Custom Compiled Kernel                  │
└─────────────────────────────────────────────┘
```

## Requirements

### Hardware
- Raspberry Pi 3 Model B (or 3B+)
- SD card (8GB+)
- Ethernet cable
- Power supply

### Software (on your Mac)
- [Vagrant](https://www.vagrantup.com/downloads)
- [VMware Fusion](https://www.vmware.com/products/fusion.html) (free for personal use)
- [Vagrant VMware Plugin](https://www.vagrantup.com/vmware)

```bash
# Install on macOS
brew install --cask vmware-fusion
brew install --cask vagrant
vagrant plugin install vagrant-vmware-desktop
```

## Quick Start (Build Everything)

```bash
# 1. Clone this repo
git clone https://github.com/Sbonelo-Mntungwa/rustpi.git
cd rustpi

# 2. Start the VM (first time takes ~10 min)
vagrant up

# 3. SSH into VM and build everything
vagrant ssh
cd ~/pi-distro/scripts
./00-build-all.sh

# 4. Exit VM when done
exit

# 5. Flash to SD card (on Mac)
diskutil list                    # Find your SD card (e.g., disk4)
diskutil unmountDisk /dev/disk4
sudo dd if=rustpi.img of=/dev/rdisk4 bs=4m status=progress
diskutil eject /dev/disk4
```

**Total build time:** ~45-60 minutes (kernel compilation takes the longest)

## Step-by-Step Build

If you prefer to run each step manually:

```bash
vagrant ssh
cd ~/pi-distro/scripts

# Step 1: Clone repositories (~5 min)
./01-clone-repos.sh

# Step 2: Build Linux kernel (~20-30 min)
./02-build-kernel.sh

# Step 3: Build Rust init system (~2 min)
./03-build-init.sh

# Step 4: Build BusyBox (~3 min)
./04-build-busybox.sh

# Step 5: Build Dropbear SSH (~2 min)
./05-build-dropbear.sh

# Step 6: Create root filesystem (~1 min)
./06-create-rootfs.sh

# Step 7: Create SD card image (~2 min)
./07-create-image.sh
```

## Flashing the SD Card

### On macOS

```bash
# List disks to find SD card
diskutil list

# Unmount (replace disk4 with YOUR disk number - NOT disk0!)
diskutil unmountDisk /dev/disk4

# Flash (use rdisk for faster writes)
sudo dd if=rustpi.img of=/dev/rdisk4 bs=4m status=progress

# Eject
diskutil eject /dev/disk4
```

### On Linux

```bash
# Find SD card
lsblk

# Flash (replace sdX with your device)
sudo dd if=rustpi.img of=/dev/sdX bs=4M status=progress
sync
```

## Booting & Connecting

1. Insert SD card into Pi 3B
2. Connect Ethernet cable to your router
3. Connect power

### LED Status
| Red LED | Green LED | Meaning |
|---------|-----------|---------|
| On | Blinking | Good - reading SD card |
| On | Off | Problem - check SD card |

### Find Your Pi's IP

```bash
# Option 1: Check router's DHCP leases

# Option 2: Scan network
arp -a | grep -i "b8:27:eb"

# Option 3: Use nmap
nmap -sn 192.168.1.0/24

# Option 4: Try static fallback IP (if DHCP failed)
ping 192.168.1.100
```

### SSH In

```bash
ssh root@<PI_IP_ADDRESS>
# Password: rustpi
```

## Project Structure

```
rustpi/
├── Vagrantfile              # VM configuration
├── README.md                # This file
├── scripts/
│   ├── 01-clone-repos.sh    # Download source code
│   ├── 02-build-kernel.sh   # Compile Linux kernel
│   ├── 03-build-init.sh     # Build Rust init system
│   ├── 04-build-busybox.sh  # Build BusyBox utilities
│   ├── 05-build-dropbear.sh # Build SSH server
│   ├── 06-create-rootfs.sh  # Assemble root filesystem
│   ├── 07-create-image.sh   # Create bootable SD image
│   └── 00-build-all.sh      # Run all scripts
└── init/
    └── src/
        └── main.rs          # Rust init source (for reference)
```

## Customization

### Change Root Password

Generate a new password hash:

```bash
openssl passwd -6 -salt xyz "your_new_password"
```

Then edit `scripts/06-create-rootfs.sh` and replace the hash in the shadow file.

### Change Static Fallback IP

Edit `scripts/03-build-init.sh` and modify these lines in the `setup_networking` function:

```rust
Command::new("ip").args(["addr", "add", "192.168.1.100/24", "dev", &iface])
Command::new("ip").args(["route", "add", "default", "via", "192.168.1.1"])
```

### Add More Packages

Modify `scripts/06-create-rootfs.sh` to copy additional binaries into the rootfs.

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Rainbow screen forever | Kernel not loading | Rebuild kernel with `02-build-kernel.sh` |
| Kernel panic: VFS | Wrong root device | Check `cmdline.txt` has `root=/dev/mmcblk0p2` |
| Kernel panic: init not found | Init missing or wrong permissions | Run `06-create-rootfs.sh` again |
| No network | Interface not found | Check `dmesg` output, verify Ethernet connected |
| SSH connection refused | Dropbear not running | Check `/bin/dropbear` exists |
| SSH permission denied | Wrong passwd ownership | Ensure `/etc/passwd` owned by root (0:0) |

### Debug via Serial Console

If you have a USB-to-serial adapter:

| Pi GPIO | Serial Adapter |
|---------|----------------|
| Pin 6 (GND) | GND |
| Pin 8 (TX) | RX |
| Pin 10 (RX) | TX |

```bash
# On Mac
screen /dev/tty.usbserial-* 115200
```

## What You Learn

Building RustPi teaches you:

1. **Linux Boot Process** - GPU → bootloader → kernel → init
2. **Cross-Compilation** - Building ARM code on x86/ARM Mac
3. **Init Systems** - What PID 1 does and why it matters
4. **Kernel Building** - Configuring and compiling Linux
5. **Root Filesystems** - Essential files and permissions
6. **Static Linking** - Creating standalone binaries

## License

MIT License - See LICENSE file

## Acknowledgments

- [Raspberry Pi Foundation](https://www.raspberrypi.org/) - Hardware and firmware
- [BusyBox](https://busybox.net/) - Tiny Unix utilities
- [Dropbear](https://matt.ucc.asn.au/dropbear/dropbear.html) - Lightweight SSH
- [Rust](https://www.rust-lang.org/) - Systems programming language
