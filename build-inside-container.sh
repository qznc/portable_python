#!/bin/sh
set -e

# Deterministic environment
export TZ=UTC
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export SOURCE_DATE_EPOCH=1609459200  # 2021-01-01 00:00:00 UTC

PYTHON_VERSION="$1"
PYTHON_MAJOR_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f1-2)
PYTHON_URL="https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz"
WORK_DIR="/work"
INSTALL_DIR="$WORK_DIR/install"

PYTHON_SHA256="fb85a13414b028c49ba18bbd523c2d055a30b56b18b92ce454ea2c51edc656c4"

echo "[INFO] Building Python $PYTHON_VERSION"
echo "[INFO] Environment: TZ=$TZ, LANG=$LANG, SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH"
echo ""

cd "$WORK_DIR"

PYTHON_TARBALL="Python-$PYTHON_VERSION.tar.xz"
if [ ! -f "$PYTHON_TARBALL" ]; then
    echo "[INFO] Downloading Python $PYTHON_VERSION..."
    curl -sSL -O "$PYTHON_URL"
fi

ACTUAL_SHA256=$(sha256sum "$PYTHON_TARBALL" | cut -d' ' -f1)
if [ "$ACTUAL_SHA256" != "$PYTHON_SHA256" ]; then
    echo "[ERROR] Checksum mismatch!"
    echo "[ERROR] Expected: $PYTHON_SHA256"
    echo "[ERROR] Got:      $ACTUAL_SHA256"
    exit 1
fi
echo "[INFO] ✓ Checksum verified"

if [ ! -d "Python-$PYTHON_VERSION" ]; then
    echo "[INFO] Extracting Python..."
    tar -xf "$PYTHON_TARBALL"
fi

cd "Python-$PYTHON_VERSION"

if [ ! -f .patches_applied ]; then
    echo "[INFO] Applying staticbuild.patch..."
    patch -p1 < /build/staticbuild.patch
    echo "[INFO] Applying ctypes-static.patch..."
    patch -p1 < /build/ctypes-static.patch
    touch .patches_applied
fi

if [ ! -f Makefile ]; then
    echo "[INFO] Configuring Python build..."
    MODULE_BUILDTYPE=static LDFLAGS="-static" ./configure \
        --disable-test-modules \
        --disable-xxlimited-modules \
        --prefix="$INSTALL_DIR" \
        --with-ensurepip=install \
        --disable-shared
fi

if [ ! -f python ]; then
    echo "[INFO] Building Python (this takes a few minutes)..."
    make -j$(nproc)
fi

if [ ! -f "$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" ]; then
    echo "[INFO] Installing Python..."
    make install
fi

echo "[INFO] Stripping debug symbols..."
strip "$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" 2>/dev/null || true

# Test
echo "[INFO] Testing binary..."
"$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" --version

echo "[INFO] Testing pip..."
"$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" -m pip --version

echo "[INFO] Copying to output..."
mkdir -p /output
cp -r "$INSTALL_DIR"/* /output/

FINAL_SHA256=$(sha256sum "$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" | cut -d' ' -f1)
echo "[INFO] Build completed successfully!"
echo "[INFO] Binary: $INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR"
echo "[INFO] SHA256: $FINAL_SHA256"
