#!/bin/bash
#
# Clean build artifacts
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

echo "[*] Cleaning build directory..."

# Remove build artifacts
rm -rf "$BUILD_DIR"

# Clean Rust target
if [ -d "$PROJECT_DIR/init/target" ]; then
    echo "[*] Cleaning Rust build..."
    cd "$PROJECT_DIR/init"
    cargo clean 2>/dev/null || rm -rf target
fi

echo "[✓] Clean complete"
