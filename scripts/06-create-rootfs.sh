#!/bin/bash
set -e

echo "============================================="
echo "  Step 6: Create Root Filesystem"
echo "============================================="

cd ~/pi-distro

echo ""
echo "=== Creating directory structure ==="
rm -rf rootfs
mkdir -p rootfs/{bin,sbin,etc,proc,sys,dev,tmp,root,run,var/log,lib}
mkdir -p rootfs/etc/dropbear
mkdir -p rootfs/root/.ssh

echo ""
echo "=== Installing init system ==="
if [ -d ~/pi-distro/modules_out/lib/modules ]; then
    cp -a ~/pi-distro/modules_out/lib/modules rootfs/lib/
    echo "Modules installed"
else
    echo "WARNING: No kernel modules found, skipping"
fi

echo ""
echo "=== Installing init system ==="
cp init/target/aarch64-unknown-linux-musl/release/init rootfs/sbin/init

echo ""
echo "=== Installing BusyBox ==="
cp busybox-1.36.1/busybox rootfs/bin/

echo "=== Creating BusyBox symlinks ==="
cd rootfs/bin
for cmd in sh ash ls cat cp mv rm mkdir rmdir mount umount \
           chmod chown ln echo sleep ps kill killall grep sed awk \
           vi less head tail wc sort uniq cut tr \
           ip ifconfig route ping wget udhcpc \
           tar gzip gunzip df du free top dmesg \
           login passwd su getty modprobe telnetd; do
    ln -sf busybox $cmd
done

cd ../sbin
ln -sf ../bin/busybox reboot
ln -sf ../bin/busybox poweroff
ln -sf ../bin/busybox halt
cd ~/pi-distro

echo ""
echo "=== Installing Dropbear ==="
cp dropbear-2024.86/dropbearmulti rootfs/bin/
cd rootfs/bin
ln -sf dropbearmulti dropbear
ln -sf dropbearmulti dropbearkey
ln -sf dropbearmulti dbclient
ln -sf dropbearmulti scp
ln -sf dropbearmulti ssh
cd ~/pi-distro

echo ""
echo "=== Creating configuration files ==="

# /etc/passwd
cat > rootfs/etc/passwd << 'EOF'
root:x:0:0:root:/root:/bin/sh
nobody:x:65534:65534:nobody:/nonexistent:/bin/false
EOF

# /etc/shadow (password: rustpi)
# Hash generated with: openssl passwd -6 -salt xyz "rustpi"
cat > rootfs/etc/shadow << 'EOF'
root:$6$cUFTNDfRa9q2UHAd$S2uKpKnoeFUw2D7p9sG/FinpzBN4sD2pWtmHOTjFELow.kU2.AyNf5gMsPZ2qsXhXiDBJqVIXXSJH42HBPdiI1:0:0:99999:7:::
nobody:*:0:0:99999:7:::
EOF

# /etc/group
cat > rootfs/etc/group << 'EOF'
root:x:0:
tty:x:5:
nobody:x:65534:
EOF

# /etc/hostname
echo "rustpi" > rootfs/etc/hostname

# /etc/hosts
cat > rootfs/etc/hosts << 'EOF'
127.0.0.1   localhost
127.0.1.1   rustpi
EOF

# /etc/nsswitch.conf
cat > rootfs/etc/nsswitch.conf << 'EOF'
passwd: files
group: files
shadow: files
EOF

# /etc/profile
cat > rootfs/etc/profile << 'EOF'
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export HOME=/root
export TERM=linux
export PS1='\[\033[01;32m\]rustpi\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# '
alias ll='ls -la'
alias la='ls -A'
echo ""
echo "Welcome to RustPi!"
echo ""
EOF

echo ""
echo "=== Setting permissions ==="
sudo chown -R 0:0 rootfs/
sudo chmod 755 rootfs/sbin/init
sudo chmod 755 rootfs/bin/busybox
sudo chmod 755 rootfs/bin/dropbearmulti
sudo chmod 644 rootfs/etc/passwd
sudo chmod 640 rootfs/etc/shadow
sudo chmod 644 rootfs/etc/group
sudo chmod 700 rootfs/root

echo ""
echo "============================================="
echo "  Step 6 Complete: Root filesystem created"
echo "============================================="
echo ""
echo "Contents:"
ls -la rootfs/
echo ""
echo "Binaries:"
ls -la rootfs/sbin/init rootfs/bin/busybox rootfs/bin/dropbearmulti
echo ""
echo "=== Creating DHCP configuration ==="

# Create udhcpc directory and script
sudo mkdir -p rootfs/etc/udhcpc

sudo tee rootfs/etc/udhcpc/default.script << 'DHCPSCRIPT'
#!/bin/sh

RESOLV_CONF="/etc/resolv.conf"

case "$1" in
    deconfig)
        ip addr flush dev $interface
        ip link set $interface up
        ;;

    renew|bound)
        ip addr flush dev $interface
        ip addr add $ip/$mask dev $interface

        if [ -n "$router" ]; then
            while ip route del default 2>/dev/null; do :; done
            for gw in $router; do
                ip route add default via $gw dev $interface
            done
        fi

        if [ -n "$dns" ]; then
            > $RESOLV_CONF
            for ns in $dns; do
                echo "nameserver $ns" >> $RESOLV_CONF
            done
        fi

        if [ -n "$hostname" ]; then
            hostname $hostname
        fi
        ;;
esac

exit 0
DHCPSCRIPT

sudo chmod +x rootfs/etc/udhcpc/default.script

# Create empty resolv.conf
sudo touch rootfs/etc/resolv.conf