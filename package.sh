#!/bin/bash
set -e

# Package script for launcher approach Python distribution
# Creates a tarball with static launcher + shared libpython

PYTHON_VERSION="${PYTHON_VERSION:-3.12.12}"
PYTHON_MAJOR_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f1-2)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_DIR="$BUILD_DIR/output"
PACKAGE_NAME="python-${PYTHON_VERSION}-x86_64-linux.tar.gz"
PACKAGE_PATH="$SCRIPT_DIR/$PACKAGE_NAME"

error() { echo "[ERROR] $1"; exit 1; }

if [ ! -d "$OUTPUT_DIR" ]; then
    error "Output directory not found: $OUTPUT_DIR. Run ./build-launcher.sh first."
fi

echo "Copying instantiate.py..."
cp "$SCRIPT_DIR/instantiate.py" "$OUTPUT_DIR/bin/"
chmod +x "$OUTPUT_DIR/bin/instantiate.py"

echo "Optimizing package size..."
STDLIB_DIR="$OUTPUT_DIR/lib/python${PYTHON_MAJOR_MINOR}"

# Calculate original size
ORIGINAL_SIZE=$(du -sh "$OUTPUT_DIR" | awk '{print $1}')
echo "Original size: $ORIGINAL_SIZE"

# Remove all .pyc bytecode files (Python will regenerate on first import)
echo "  - Removing .pyc bytecode files..."
find "$OUTPUT_DIR" -type f -name "*.pyc" -delete
find "$OUTPUT_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

if [ -d "$STDLIB_DIR/idlelib" ]; then
    echo "  - Removing idlelib/ (IDLE GUI editor)"
    rm -rf "$STDLIB_DIR/idlelib"
fi

if [ -d "$STDLIB_DIR/tkinter" ]; then
    echo "  - Removing tkinter/ (Tk GUI toolkit)"
    rm -rf "$STDLIB_DIR/tkinter"
fi

if [ -d "$STDLIB_DIR/lib2to3" ]; then
    echo "  - Removing lib2to3/ (Python 2→3 conversion tool)"
    rm -rf "$STDLIB_DIR/lib2to3"
fi

if [ -d "$STDLIB_DIR/pydoc_data" ]; then
    echo "  - Removing pydoc_data/ (HTML documentation)"
    rm -rf "$STDLIB_DIR/pydoc_data"
fi

if [ -d "$OUTPUT_DIR/share" ]; then
    echo "  - Removing share/ (man pages)"
    rm -rf "$OUTPUT_DIR/share"
fi

# Calculate optimized size
OPTIMIZED_SIZE=$(du -sh "$OUTPUT_DIR" | awk '{print $1}')
echo "Optimized size: $OPTIMIZED_SIZE"
echo "Note: C extension compilation support preserved (config/ and include/ kept)"

# Verify critical files
PYTHON_BIN="$OUTPUT_DIR/bin/python${PYTHON_MAJOR_MINOR}"
LIBPYTHON="$OUTPUT_DIR/lib/libpython${PYTHON_MAJOR_MINOR}.so.1.0"

if [ ! -f "$PYTHON_BIN" ]; then
    error "Python binary not found: $PYTHON_BIN"
fi

if [ ! -f "$LIBPYTHON" ]; then
    error "libpython not found: $LIBPYTHON"
fi

echo "Creating package: $PACKAGE_NAME"
echo "Source: $OUTPUT_DIR"

# Create tarball
cd "$BUILD_DIR"
tar czf "$PACKAGE_PATH" \
    --owner=0 --group=0 \
    --mtime='2021-01-01 00:00:00' \
    --sort=name \
    -C "$(dirname "$OUTPUT_DIR")" \
    "$(basename "$OUTPUT_DIR")"

if [ ! -f "$PACKAGE_PATH" ]; then
    error "Failed to create package"
fi

# Calculate checksums
SHA256=$(sha256sum "$PACKAGE_PATH" | cut -d' ' -f1)
SIZE=$(ls -lh "$PACKAGE_PATH" | awk '{print $5}')

echo "Package: $PACKAGE_PATH"
echo "Size: $SIZE"
echo "SHA256: $SHA256"
