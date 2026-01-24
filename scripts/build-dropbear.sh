#!/bin/bash
#
# Build Dropbear SSH for ARM64
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

echo "[dropbear] Building Dropbear SSH..."

cd "$BUILD_DIR"

# Clone Dropbear if not present
if [ ! -d "dropbear" ]; then
    echo "[dropbear] Cloning Dropbear..."
    git clone --depth=1 https://github.com/mkj/dropbear.git
fi

cd dropbear

# Configure for cross-compilation with static linking
./configure \
    --host=aarch64-linux-gnu \
    CC=aarch64-linux-gnu-gcc \
    --disable-zlib \
    --disable-wtmp \
    --disable-lastlog \
    --disable-syslog

# Build statically
make PROGRAMS="dropbear dropbearkey scp dbclient" \
     STATIC=1 \
     LDFLAGS="-static" \
     -j$(nproc)

# Copy binaries
mkdir -p "$BUILD_DIR/bin"
cp dropbear dropbearkey scp dbclient "$BUILD_DIR/bin/"

# Verify
for bin in dropbear dropbearkey; do
    if file "$BUILD_DIR/bin/$bin" | grep -q "statically linked"; then
        echo "[dropbear] ✓ $bin is statically linked"
    else
        echo "[dropbear] ⚠ Warning: $bin may not be statically linked"
    fi
done

SIZE=$(du -h "$BUILD_DIR/bin/dropbear" | cut -f1)
echo "[dropbear] ✓ Built Dropbear: $SIZE"
