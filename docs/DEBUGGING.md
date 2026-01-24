# Debugging RustPi

This guide covers common issues and how to solve them.

## Boot Issues

### No Green LED Activity

**Symptom:** Power LED is on (red), but no green activity LED blinking.

**Cause:** The GPU can't find or load `bootcode.bin`.

**Solutions:**
1. Verify boot partition is FAT32
2. Check these files exist on boot partition:
   - `bootcode.bin`
   - `start.elf`
   - `fixup.dat`
3. Re-copy files from Raspberry Pi firmware repository

```bash
# Verify boot partition
sudo mount /dev/mmcblk0p1 /mnt
ls -la /mnt
# Should show: bootcode.bin, start.elf, fixup.dat, kernel8.img, config.txt, cmdline.txt
```

### Rainbow Screen

**Symptom:** Display shows rainbow gradient, then nothing.

**Cause:** Kernel not loading properly.

**Solutions:**
1. Verify `kernel8.img` exists on boot partition
2. Check `config.txt` has correct `kernel=kernel8.img`
3. Verify device tree file matches your Pi model

### Kernel Panic - VFS Unable to Mount Root

**Symptom:** 
```
Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(179,2)
```

**Causes & Solutions:**

1. **Wrong root device in cmdline.txt**
   ```bash
   # Should be:
   root=/dev/mmcblk0p2
   ```

2. **Root partition not ext4**
   ```bash
   # Check filesystem type
   sudo file -s /dev/mmcblk0p2
   # Should show: ext4 filesystem
   ```

3. **Kernel missing SD card driver**
   - Use pre-built kernel from RPi firmware (has all drivers)

### Kernel Panic - No Init Found

**Symptom:**
```
Kernel panic - not syncing: No init found
```

**Causes & Solutions:**

1. **Init binary missing**
   ```bash
   # Check init exists
   ls -la /mnt/root/sbin/init
   ```

2. **Init not executable**
   ```bash
   chmod 755 /mnt/root/sbin/init
   ```

3. **Init dynamically linked (needs glibc)**
   ```bash
   # Check if statically linked
   file /mnt/root/sbin/init
   # Should show: "statically linked"
   
   # If not, rebuild with musl:
   cargo build --release --target aarch64-unknown-linux-musl
   ```

4. **Wrong architecture**
   ```bash
   file /mnt/root/sbin/init
   # Should show: "ARM aarch64" or "ARM64"
   ```

## Network Issues

### No Network Interface

**Symptom:** `ifconfig` shows only `lo` (loopback).

**Causes & Solutions:**

1. **USB-Ethernet not plugged in**
   - Check physical connection

2. **Wrong driver loaded**
   ```bash
   # Find USB device ID
   cat /sys/bus/usb/devices/*/idVendor
   cat /sys/bus/usb/devices/*/idProduct
   
   # Look up driver needed
   grep "VENDOR_ID" /lib/modules/*/modules.alias
   
   # Load correct driver
   modprobe dm9601  # or asix, cdc_ether, r8152, etc.
   ```

3. **Kernel modules missing**
   - Copy modules from firmware repository:
   ```bash
   cp -r firmware/modules/* /lib/modules/
   ```

### DHCP Gets IP But No Internet

**Symptom:** `udhcpc` reports lease obtained, but can't ping anything.

**Causes & Solutions:**

1. **Missing UDHCPC script**
   ```bash
   # Check script exists
   cat /usr/share/udhcpc/default.script
   
   # Make executable
   chmod 755 /usr/share/udhcpc/default.script
   ```

2. **Default route not set**
   ```bash
   # Check routes
   route -n
   
   # Manually add if missing
   route add default gw 192.168.1.1 eth0
   ```

3. **DNS not configured**
   ```bash
   # Check resolv.conf
   cat /etc/resolv.conf
   
   # Add DNS server manually
   echo "nameserver 8.8.8.8" > /etc/resolv.conf
   ```

## SSH Issues

### Connection Refused

**Symptom:** `ssh: connect to host X.X.X.X port 22: Connection refused`

**Causes & Solutions:**

1. **Dropbear not running**
   ```bash
   # On the Pi, check if running
   ps | grep dropbear
   
   # Start manually
   /bin/dropbear -F -E -R
   ```

2. **Host keys not generated**
   ```bash
   # Generate keys
   mkdir -p /etc/dropbear
   dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
   dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
   ```

### Permission Denied

**Symptom:** `Permission denied (publickey)`

**Causes & Solutions:**

1. **File ownership wrong**
   ```bash
   # Fix ownership
   chown 0:0 /etc/passwd /etc/shadow /etc/group
   chmod 644 /etc/passwd
   chmod 640 /etc/shadow
   chmod 644 /etc/group
   ```

2. **User doesn't exist**
   ```bash
   # Check /etc/passwd has root user
   cat /etc/passwd
   # Should contain: root:x:0:0:root:/root:/bin/sh
   ```

3. **Shell not in /etc/shells**
   ```bash
   echo "/bin/sh" > /etc/shells
   ```

### "Login attempt for nonexistent user"

**Symptom:** Dropbear logs show this error.

**Cause:** Static Dropbear can't use NSS to look up users. Files must have correct ownership.

**Solution:**
```bash
# Files MUST be owned by root (UID 0)
chown 0:0 /etc/passwd /etc/shadow /etc/group
```

## Serial Console Debugging

### Setup Serial Connection

You need a USB-to-Serial adapter connected to Pi's GPIO:

| Pi Pin | Signal | Adapter |
|--------|--------|---------|
| GPIO14 (Pin 8) | TXD | RXD |
| GPIO15 (Pin 10) | RXD | TXD |
| GND (Pin 6) | GND | GND |

### Connect

```bash
# Linux
screen /dev/ttyUSB0 115200

# macOS
screen /dev/tty.usbserial-* 115200

# Or use minicom
minicom -D /dev/ttyUSB0 -b 115200
```

### Enable Serial Output

In `config.txt`:
```
enable_uart=1
```

In `cmdline.txt`:
```
console=serial0,115200 console=tty1 ...
```

## Init System Debugging

### Add Debug Output

Edit `init/src/main.rs` and add print statements:

```rust
println!("[init] DEBUG: Starting mount_filesystems");
mount_filesystems()?;
println!("[init] DEBUG: Finished mount_filesystems");
```

### Run Init Manually

If you have shell access (via serial), you can test init:

```bash
# Kill current init (careful!)
# Then run your init binary directly
/sbin/init
```

### Check Init with QEMU

Test your init binary on your host machine:

```bash
# Install QEMU user-mode
sudo apt install qemu-user-static

# Run init (won't fully work but tests basic execution)
qemu-aarch64-static ./target/aarch64-unknown-linux-musl/release/rustpi-init
```

## Useful Commands

### Check Boot Messages

```bash
dmesg | head -100
```

### Check Mounted Filesystems

```bash
mount
cat /proc/mounts
```

### Check Running Processes

```bash
ps aux
```

### Check Memory

```bash
free -m
cat /proc/meminfo
```

### Check Storage

```bash
df -h
cat /proc/partitions
```

### Network Status

```bash
ifconfig -a
route -n
cat /etc/resolv.conf
ping 8.8.8.8
```
