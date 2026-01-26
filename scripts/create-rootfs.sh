#!/bin/bash
#
# Create root filesystem
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
ROOTFS="$BUILD_DIR/rootfs"

echo "[rootfs] Creating root filesystem..."

# Clean and create directory structure
rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"/{bin,sbin,etc,proc,sys,dev,tmp,root,var,usr,lib,run}
mkdir -p "$ROOTFS"/usr/{bin,sbin,share}
mkdir -p "$ROOTFS"/usr/share/udhcpc
mkdir -p "$ROOTFS"/var/{log,run}
mkdir -p "$ROOTFS"/etc/dropbear
mkdir -p "$ROOTFS"/lib/modules

echo "[rootfs] Copying binaries..."

# Copy init
cp "$BUILD_DIR/bin/init" "$ROOTFS/sbin/init"
chmod 755 "$ROOTFS/sbin/init"

# Copy BusyBox and create symlinks
cp "$BUILD_DIR/bin/busybox" "$ROOTFS/bin/busybox"
chmod 755 "$ROOTFS/bin/busybox"

# Create BusyBox symlinks
BUSYBOX_CMDS="sh ash cat ls cp mv rm mkdir rmdir chmod chown chgrp
    ln touch echo printf head tail grep sed awk cut sort uniq wc
    mount umount mknod mkfifo
    ps top kill killall sleep
    ifconfig route ip ping netstat hostname udhcpc
    tar gzip gunzip
    vi less more
    df du free
    dmesg sysctl
    id whoami login passwd su
    date hwclock
    clear reset
    test [ true false
    env export set unset
    modprobe insmod rmmod lsmod
    find xargs
    stty
    getty"

cd "$ROOTFS/bin"
for cmd in $BUSYBOX_CMDS; do
    ln -sf busybox "$cmd" 2>/dev/null || true
done

# Also create in /sbin for system commands
cd "$ROOTFS/sbin"
for cmd in ifconfig route ip modprobe insmod rmmod mount umount mknod init halt reboot poweroff; do
    ln -sf ../bin/busybox "$cmd" 2>/dev/null || true
done

# Copy Dropbear
if [ -f "$BUILD_DIR/bin/dropbear" ]; then
    cp "$BUILD_DIR/bin/dropbear" "$ROOTFS/bin/"
    cp "$BUILD_DIR/bin/dropbearkey" "$ROOTFS/bin/"
    chmod 755 "$ROOTFS/bin/dropbear" "$ROOTFS/bin/dropbearkey"
fi

echo "[rootfs] Creating configuration files..."

# /etc/passwd
cat > "$ROOTFS/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/sh
nobody:x:65534:65534:nobody:/nonexistent:/bin/false
EOF

# /etc/shadow (empty password for root - login with just Enter)
cat > "$ROOTFS/etc/shadow" << 'EOF'
root::0:0:99999:7:::
nobody:*:0:0:99999:7:::
EOF
chmod 640 "$ROOTFS/etc/shadow"

# /etc/group
cat > "$ROOTFS/etc/group" << 'EOF'
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
tty:x:5:
disk:x:6:
wheel:x:10:root
nobody:x:65534:
EOF

# /etc/hostname
if [ -f "$PROJECT_DIR/rootfs/etc/hostname" ]; then
    cp "$PROJECT_DIR/rootfs/etc/hostname" "$ROOTFS/etc/hostname"
else
    echo "rustpi" > "$ROOTFS/etc/hostname"
fi

# /etc/hosts
cat > "$ROOTFS/etc/hosts" << 'EOF'
127.0.0.1   localhost
127.0.1.1   rustpi
::1         localhost ip6-localhost ip6-loopback
EOF

# /etc/profile
cat > "$ROOTFS/etc/profile" << 'EOF'
export PATH="/bin:/sbin:/usr/bin:/usr/sbin"
export HOME="/root"
export TERM="linux"
export PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '

alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'

echo ""
echo "Welcome to RustPi!"
echo ""
EOF

# /etc/shells
cat > "$ROOTFS/etc/shells" << 'EOF'
/bin/sh
/bin/ash
EOF

# /etc/inittab (for BusyBox init fallback)
cat > "$ROOTFS/etc/inittab" << 'EOF'
::sysinit:/sbin/init
::respawn:/bin/getty -L tty1 115200 vt100
::restart:/sbin/init
::shutdown:/bin/umount -a -r
EOF

# UDHCPC script
cat > "$ROOTFS/usr/share/udhcpc/default.script" << 'EOF'
#!/bin/sh

case "$1" in
    deconfig)
        ifconfig "$interface" 0.0.0.0
        ;;
    bound|renew)
        ifconfig "$interface" "$ip" netmask "$subnet"
        if [ -n "$router" ]; then
            while route del default gw 0.0.0.0 dev "$interface" 2>/dev/null; do :; done
            for r in $router; do
                route add default gw "$r" dev "$interface"
            done
        fi
        if [ -n "$dns" ]; then
            echo -n > /etc/resolv.conf
            for d in $dns; do
                echo "nameserver $d" >> /etc/resolv.conf
            done
        fi
        ;;
esac
EOF
chmod 755 "$ROOTFS/usr/share/udhcpc/default.script"

# /etc/resolv.conf (will be populated by DHCP)
touch "$ROOTFS/etc/resolv.conf"

# Create device nodes
echo "[rootfs] Creating device nodes..."
cd "$ROOTFS/dev"
sudo mknod -m 666 null c 1 3 2>/dev/null || true
sudo mknod -m 666 zero c 1 5 2>/dev/null || true
sudo mknod -m 666 random c 1 8 2>/dev/null || true
sudo mknod -m 666 urandom c 1 9 2>/dev/null || true
sudo mknod -m 666 tty c 5 0 2>/dev/null || true
sudo mknod -m 600 console c 5 1 2>/dev/null || true
sudo mknod -m 666 ptmx c 5 2 2>/dev/null || true
sudo mknod -m 660 tty1 c 4 1 2>/dev/null || true

# Set ownership
echo "[rootfs] Setting permissions..."
sudo chown -R 0:0 "$ROOTFS"
sudo chmod 640 "$ROOTFS/etc/shadow"

SIZE=$(du -sh "$ROOTFS" | cut -f1)
echo "[rootfs] ✓ Root filesystem created: $SIZE"
