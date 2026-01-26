# Debugging RustPi

Common issues and their solutions.

## Boot Issues

### No Green LED Activity

**Symptom:** Power LED on, no green activity LED.

**Cause:** GPU can't load bootcode.bin.

**Solution:**
```bash
# Check boot partition has required files
ls /mnt/boot/
# Must have: bootcode.bin, start.elf, fixup.dat, kernel8.img
```

### Rainbow Screen Then Nothing

**Symptom:** Display shows rainbow, then black.

**Cause:** Kernel not loading.

**Solution:**
- Verify `kernel8.img` exists on boot partition
- Check `config.txt` has `kernel=kernel8.img`

### Kernel Panic - VFS Unable to Mount Root

**Symptom:**
```
Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(179,2)
```

**Solutions:**
1. Check `cmdline.txt` has correct root device: `root=/dev/mmcblk0p2`
2. Verify root partition is ext4: `sudo file -s /dev/mmcblk0p2`
3. Use pre-built kernel from RPi firmware

### Kernel Panic - No Init Found

**Symptom:**
```
Kernel panic - not syncing: No init found
```

**Solutions:**

1. Check init exists:
```bash
ls -la /mnt/root/sbin/init
```

2. Check init is executable:
```bash
chmod 755 /mnt/root/sbin/init
```

3. Check init is statically linked:
```bash
file /mnt/root/sbin/init
# Should show: "statically linked"
```

4. Rebuild with musl:
```bash
cargo build --release --target aarch64-unknown-linux-musl
```

## Network Issues

### No Network Interface

**Symptom:** `ifconfig` shows only `lo`.

**Solutions:**

1. Check USB-Ethernet is plugged in

2. Find USB device ID:
```bash
cat /sys/bus/usb/devices/*/idVendor
cat /sys/bus/usb/devices/*/idProduct
```

3. Load correct driver:
```bash
modprobe dm9601   # Davicom
modprobe asix     # ASIX
modprobe r8152    # Realtek
```

### DHCP Fails

**Symptom:** No IP address assigned.

**Solutions:**

1. Check UDHCPC script:
```bash
cat /usr/share/udhcpc/default.script
chmod 755 /usr/share/udhcpc/default.script
```

2. Check resolv.conf writable:
```bash
touch /etc/resolv.conf
```

3. Run DHCP manually:
```bash
udhcpc -i eth0 -v
```

## SSH Issues

### Connection Refused

**Symptom:** `ssh: connect to host X port 22: Connection refused`

**Solutions:**

1. Check Dropbear running:
```bash
ps | grep dropbear
```

2. Start manually:
```bash
/bin/dropbear -F -E -R
```

3. Generate host keys:
```bash
mkdir -p /etc/dropbear
dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
```

### Permission Denied

**Symptom:** `Permission denied (publickey)`

**Solution:**
```bash
# Fix file ownership
chown 0:0 /etc/passwd /etc/shadow /etc/group
chmod 644 /etc/passwd
chmod 640 /etc/shadow
chmod 644 /etc/group
```

### "Login attempt for nonexistent user"

**Cause:** Files owned by wrong UID.

**Solution:**
```bash
chown 0:0 /etc/passwd /etc/shadow
```

## Serial Console Debugging

### Setup

Connect USB-to-Serial adapter:

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

## Useful Debug Commands

```bash
# Boot messages
dmesg | head -100

# Mounted filesystems
mount
cat /proc/mounts

# Processes
ps aux

# Memory
free -m

# Storage
df -h
cat /proc/partitions

# Network
ifconfig -a
route -n
cat /etc/resolv.conf
ping 8.8.8.8
```

## Rebuilding After Changes

```bash
# In Vagrant
vagrant ssh
clean
build

# Native
./scripts/clean.sh
./scripts/build-all.sh
```
