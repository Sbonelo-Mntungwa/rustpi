#!/bin/bash
#
# Build Rust init system
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
INIT_DIR="$PROJECT_DIR/init"

echo "[init] Building Rust init system..."

# Ensure cargo is in path (for Vagrant)
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

cd "$INIT_DIR"

# Build for ARM64 with static linking (musl)
cargo build --release --target aarch64-unknown-linux-musl

# Copy binary to build directory
mkdir -p "$BUILD_DIR/bin"
cp "target/aarch64-unknown-linux-musl/release/rustpi-init" "$BUILD_DIR/bin/init"

# Verify it's statically linked
if file "$BUILD_DIR/bin/init" | grep -q "statically linked"; then
    echo "[init] ✓ Binary is statically linked"
else
    echo "[init] ⚠ Warning: Binary may not be statically linked"
    file "$BUILD_DIR/bin/init"
fi

# Show binary size
SIZE=$(du -h "$BUILD_DIR/bin/init" | cut -f1)
echo "[init] ✓ Built init binary: $SIZE"
