#!/bin/bash
set -e

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║               RUSTPI BUILD SYSTEM                         ║"
echo "║                                                           ║"
echo "║   Building a custom Linux distribution for Raspberry Pi   ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

START_TIME=$(date +%s)

cd ~/pi-distro/scripts

echo "Starting build at $(date)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./01-clone-repos.sh
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./02-build-kernel.sh
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./03-build-init.sh
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./04-build-busybox.sh
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./05-build-dropbear.sh
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./06-create-rootfs.sh
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./07-create-image.sh
echo ""

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║                  BUILD COMPLETE!                          ║"
echo "║                                                           ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║                                                           ║"
printf "║   Build time: %d minutes %d seconds                       ║\n" $MINUTES $SECONDS
echo "║                                                           ║"
echo "║   Image: /vagrant/rustpi.img                              ║"
echo "║                                                           ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║                                                           ║"
echo "║   FLASHING (on Mac):                                      ║"
echo "║                                                           ║"
echo "║   diskutil list                                           ║"
echo "║   diskutil unmountDisk /dev/disk4                         ║"
echo "║   sudo dd if=rustpi.img of=/dev/rdisk4 bs=4m              ║"
echo "║   diskutil eject /dev/disk4                               ║"
echo "║                                                           ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║                                                           ║"
echo "║   CONNECTING:                                             ║"
echo "║                                                           ║"
echo "║   ssh root@<PI_IP>                                        ║"
echo "║   Password: rustpi                                        ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
