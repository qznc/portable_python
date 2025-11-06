#!/bin/bash
set -e

PYTHON_VERSION="${PYTHON_VERSION:-3.12.12}"
PYTHON_MAJOR_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f1-2)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_DIR="$BUILD_DIR/output"
PACKAGE_DIR="$BUILD_DIR/package/python-static"
TARBALL="$SCRIPT_DIR/python-${PYTHON_VERSION}-static-x86_64-linux-musl.tar.gz"
EXPECTED_CHECKSUM="94f9fafcf3e51385907a2dc915af23d4a02f14dc33396d5c437e9ff5dc1db36a"

info() { echo "$1"; }
error() { echo "ERROR: $1"; exit 1; }

[ ! -d "$OUTPUT_DIR" ] && error "Output directory not found. Run ./build.sh first."
PYTHON_BIN="$OUTPUT_DIR/bin/python${PYTHON_MAJOR_MINOR}"
[ ! -f "$PYTHON_BIN" ] && error "Python binary not found: $PYTHON_BIN"

info "Packaging Python ${PYTHON_VERSION}..."
info "Python binary: $(sha256sum "$PYTHON_BIN" | cut -d' ' -f1)"
info "Stdlib: $(find "$OUTPUT_DIR/lib/python${PYTHON_MAJOR_MINOR}" -type f | sort | xargs sha256sum | sha256sum | cut -d' ' -f1)"

rm -rf "$SCRIPT_DIR/package"
mkdir -p "$PACKAGE_DIR/bin" "$PACKAGE_DIR/lib"

info "Copying Python binary..."
cp "$PYTHON_BIN" "$PACKAGE_DIR/bin/"
cd "$PACKAGE_DIR/bin"
ln -sf "python${PYTHON_MAJOR_MINOR}" python3
ln -sf "python${PYTHON_MAJOR_MINOR}" python
cd - > /dev/null

info "Copying standard library..."
[ ! -d "$OUTPUT_DIR/lib/python${PYTHON_MAJOR_MINOR}" ] && \
    error "Python standard library not found in $OUTPUT_DIR/lib/"
cp -a "$OUTPUT_DIR/lib/python${PYTHON_MAJOR_MINOR}" "$PACKAGE_DIR/lib/"

info "Copying instantiate.py..."
cp "$SCRIPT_DIR/instantiate.py" "$PACKAGE_DIR/bin/"
chmod +x "$PACKAGE_DIR/bin/instantiate.py"

info "Removing test files..."
rm -rf "$PACKAGE_DIR/lib/python${PYTHON_MAJOR_MINOR}"/{test,unittest/test,lib2to3/tests,distutils/tests,ctypes/test,tkinter/test,sqlite3/test,idlelib/idle_test}
find "$PACKAGE_DIR" -type f \( -name "*.pyc" -o -name "*.pyo" -o -name "*.a" -o -name "EXTERNALLY-MANAGED" \) -delete
find "$PACKAGE_DIR" -type d -name "__pycache__" -exec rm -rf {} + || true

cat > "$PACKAGE_DIR/README.txt" << EOF
Static Python ${PYTHON_VERSION} for Linux (musl)
================================================

Runs on any Linux system (x86_64) without requiring system libraries.

Usage:
------
1. Extract: tar xzf python-${PYTHON_VERSION}-static-x86_64-linux-musl.tar.gz
2. Run: ./python-static/bin/python3 --version
3. Add to PATH: export PATH="\$(pwd)/python-static/bin:\$PATH"

Features:
---------
- Fully static binary (no dynamic library dependencies)
- Includes SSL/HTTPS support (OpenSSL statically linked)
- sqlite3, compression (zlib, bzip2, lzma), readline support
- pip pre-installed and working

Limitations:
------------
- No tkinter support
- C extensions may need special building for musl
- ctypes has limited functionality (pythonapi not available in static build)

Build info: Python ${PYTHON_VERSION}, Alpine Linux (musl)
EOF

info "Creating tarball ($(du -sh "$PACKAGE_DIR" | cut -f1))..."
find "$PACKAGE_DIR" -type f -exec touch -t 202501010000.00 {} +
find "$PACKAGE_DIR" -type d -exec touch -t 202501010000.00 {} +
find "$PACKAGE_DIR" -type l -exec touch -h -t 202501010000.00 {} +
cd "$BUILD_DIR/package"
tar --sort=name --numeric-owner --owner=0 --group=0 -czf "$TARBALL" python-static/
cd - > /dev/null

ACTUAL_CHECKSUM=$(sha256sum "$TARBALL" | cut -d' ' -f1)

info "Tarball: $TARBALL ($(du -h "$TARBALL" | cut -f1))"
info "SHA256: $ACTUAL_CHECKSUM"

[ "$ACTUAL_CHECKSUM" != "$EXPECTED_CHECKSUM" ] && \
    error "Checksum mismatch! Expected: $EXPECTED_CHECKSUM"

info "Test: tar xzf $TARBALL && ./python-static/bin/python3 --version"
