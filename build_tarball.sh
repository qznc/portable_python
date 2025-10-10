#!/bin/sh
# Copyright 2025 Andreas Zwinkau
# SPDX-License-Identifier: Apache-2.0
# NOTE: this script is supposed to be executed within an Alpine container

set -e

PYTHON_VERSION="3.12"
OUTPUT_DIR="/tmp/base-python"
TARBALL="/tmp/base-python-${PYTHON_VERSION}.12.tar.gz"

# Create output structure
mkdir -p "$OUTPUT_DIR/bin" "$OUTPUT_DIR/lib" "$OUTPUT_DIR/include"

# Copy Python binaries (only actual files, not symlinks)
for f in /usr/bin/python* /usr/bin/pip*; do
    [ -e "$f" ] || continue
    [ -L "$f" ] && continue
    [ -f "$f" ] && cp -a "$f" "$OUTPUT_DIR/bin/"
done

# Python libraries
cp -a /usr/lib/python${PYTHON_VERSION} "$OUTPUT_DIR/lib/"
for f in /usr/lib/libpython*.so*; do
    [ -e "$f" ] || continue
    cp -a "$f" "$OUTPUT_DIR/lib/"
done
[ -d /usr/lib/pkgconfig ] && cp -a /usr/lib/pkgconfig "$OUTPUT_DIR/lib/"

# Python headers
for d in /usr/include/python*; do
    [ -e "$d" ] || continue
    [ -d "$d" ] && cp -a "$d" "$OUTPUT_DIR/include/"
done

# Musl loader
for f in /lib/ld-musl*.so.1; do
    [ -e "$f" ] || continue
    cp -a "$f" "$OUTPUT_DIR/lib/"
done

# Collect all shared library dependencies
{
    ldd /usr/bin/python${PYTHON_VERSION} 2>/dev/null | grep "=>" | awk "{print \$3}" | grep "^/"
    find /usr/lib/python${PYTHON_VERSION}/lib-dynload -name "*.so" -exec ldd {} \; 2>/dev/null | grep "=>" | awk "{print \$3}" | grep "^/"
} | sort -u | while read -r lib; do
    if [ -n "$lib" ] && [ -e "$lib" ]; then
        lib_name=$(basename "$lib")
        lib_dir=$(dirname "$lib")
        # Copy the library and any symlinks pointing to it
        for f in "$lib_dir"/${lib_name%.*}*; do
            [ -e "$f" ] || continue
            cp -a "$f" "$OUTPUT_DIR/lib/"
        done
    fi
done

# Remove EXTERNALLY-MANAGED marker
find "$OUTPUT_DIR" -name "EXTERNALLY-MANAGED" -type f -delete

# Remove unnecessary stuff to save space
find "$OUTPUT_DIR" -type f -name "*.pyc" -delete
find "$OUTPUT_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$OUTPUT_DIR" -name "*.a" -type f -delete
rm -rf "$OUTPUT_DIR/lib/python${PYTHON_VERSION}/test"

# Rename original python3 binary to make room for wrapper
cd "$OUTPUT_DIR/bin"
mv "python${PYTHON_VERSION}" "python${PYTHON_VERSION}.bin"

# Create wrapper script
cat > python3 << "WRAPPER"
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
export PYTHONHOME="$PARENT_DIR"
exec "$PARENT_DIR/lib/ld-musl-x86_64.so.1" --library-path "$PARENT_DIR/lib" "$SCRIPT_DIR/python3.12.bin" "$@"
WRAPPER
chmod +x python3
ln -sf python3 python

# Copy instantiate.py to bin directory
cp /tmp/instantiate.py "$OUTPUT_DIR/bin/instantiate.py"
chmod +x "$OUTPUT_DIR/bin/instantiate.py"

cd /tmp

# Create deterministic tarball
chown -R 0:0 "$OUTPUT_DIR"
# Set timestamps on all files, directories, and symlinks for reproducible builds
# Using BusyBox-compatible timestamp format: 202511040000.00 = 2025-11-04 00:00:00 UTC
find "$OUTPUT_DIR" -type f -exec touch -t 202511040000.00 {} +
find "$OUTPUT_DIR" -type d -exec touch -t 202511040000.00 {} +
find "$OUTPUT_DIR" -type l -exec touch -h -t 202511040000.00 {} +

tar --numeric-owner -czf "$TARBALL" -C /tmp base-python
