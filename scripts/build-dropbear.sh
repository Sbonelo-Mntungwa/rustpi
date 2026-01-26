#!/bin/bash
#
# Build Dropbear SSH for ARM64
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

echo "[dropbear] Building Dropbear SSH..."

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clone Dropbear if not present
if [ ! -d "dropbear" ]; then
    echo "[dropbear] Cloning Dropbear..."
    git clone --depth=1 https://github.com/mkj/dropbear.git
fi

cd dropbear

# Clean previous build
make clean 2>/dev/null || true

# Run autoconf if needed
if [ ! -f "configure" ]; then
    echo "[dropbear] Running autoconf..."
    autoconf 2>/dev/null || autoreconf -i 2>/dev/null || true
fi

# Configure for cross-compilation with static linking
echo "[dropbear] Configuring..."
./configure \
    --host=aarch64-linux-gnu \
    CC=aarch64-linux-gnu-gcc \
    --disable-zlib \
    --disable-wtmp \
    --disable-lastlog \
    --disable-syslog \
    --disable-utmp \
    --disable-utmpx \
    --disable-wtmpx \
    --disable-pututline \
    --disable-pututxline

# Build statically
echo "[dropbear] Compiling..."
make PROGRAMS="dropbear dropbearkey scp dbclient" \
     STATIC=1 \
     LDFLAGS="-static" \
     -j$(nproc)

# Copy binaries
mkdir -p "$BUILD_DIR/bin"
cp dropbear dropbearkey scp dbclient "$BUILD_DIR/bin/" 2>/dev/null || \
cp dropbear dropbearkey "$BUILD_DIR/bin/"

# Verify
for bin in dropbear dropbearkey; do
    if [ -f "$BUILD_DIR/bin/$bin" ]; then
        if file "$BUILD_DIR/bin/$bin" | grep -q "statically linked"; then
            echo "[dropbear] ✓ $bin is statically linked"
        else
            echo "[dropbear] ⚠ Warning: $bin may not be statically linked"
        fi
    fi
done

SIZE=$(du -h "$BUILD_DIR/bin/dropbear" | cut -f1)
echo "[dropbear] ✓ Built Dropbear: $SIZE"
