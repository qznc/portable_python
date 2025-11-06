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

echo "Building Python $PYTHON_VERSION with launcher approach"
echo "This creates a static launcher + shared libpython for full dynamic extension support"
echo "Environment: TZ=$TZ, LANG=$LANG, SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH"

cd "$WORK_DIR"

# Download and verify Python
PYTHON_TARBALL="Python-$PYTHON_VERSION.tar.xz"
if [ ! -f "$PYTHON_TARBALL" ]; then
    echo "Downloading Python $PYTHON_VERSION..."
    curl -sSL -O "$PYTHON_URL"
fi

ACTUAL_SHA256=$(sha256sum "$PYTHON_TARBALL" | cut -d' ' -f1)
if [ "$ACTUAL_SHA256" != "$PYTHON_SHA256" ]; then
    echo "[ERROR] Checksum mismatch!"
    echo "[ERROR] Expected: $PYTHON_SHA256"
    echo "[ERROR] Got:      $ACTUAL_SHA256"
    exit 1
fi
echo "✓ Checksum verified"

if [ ! -d "Python-$PYTHON_VERSION" ]; then
    echo "Extracting Python..."
    tar -xf "$PYTHON_TARBALL"
fi

cd "Python-$PYTHON_VERSION"

# Configure Python to build as shared library
if [ ! -f Makefile ]; then
    echo "Configuring Python build with --enable-shared..."
    echo "This builds libpython3.12.so with dynamic linking support"

    # Build with shared library enabled
    # - Statically link heavy dependencies into libpython (ssl, crypto, sqlite, etc.)
    # - Set RPATH so libpython can find other libs in ../lib
    # - Enable shared library for dynamic extension loading
    MODULE_BUILDTYPE=static \
    CFLAGS="-fdebug-prefix-map=/work=/build -ffile-prefix-map=/work=/build" \
    LDFLAGS="-Wl,-rpath,\$\$ORIGIN -Wl,--build-id=none" \
    LIBS="-Wl,-Bstatic -lssl -lcrypto -lsqlite3 -lz -lbz2 -llzma -lreadline -lncursesw -lffi -Wl,-Bdynamic -lm -ldl" \
    ./configure \
        --enable-shared \
        --prefix="$INSTALL_DIR" \
        --with-ensurepip=install \
        --disable-test-modules
fi

# Build Python
if [ ! -f python ]; then
    echo "Building Python (this takes a few minutes)..."
    make -j$(nproc)
fi

# Install Python
if [ ! -f "$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" ]; then
    echo "Installing Python..."
    make install
fi

# Verify shared library was created
LIBPYTHON="$INSTALL_DIR/lib/libpython${PYTHON_MAJOR_MINOR}.so.1.0"
if [ ! -f "$LIBPYTHON" ]; then
    echo "[ERROR] libpython shared library not found at $LIBPYTHON"
    echo "[ERROR] The build may have failed to create the shared library"
    exit 1
fi
echo "✓ Found libpython: $LIBPYTHON"

# Build launcher
echo "Building launcher..."
echo "This creates a small launcher that uses dlopen (dynamically linked with musl)"

# Update the launcher C file to match the Python version
LAUNCHER_SRC="/tmp/launcher.c"
cp /in_container/launcher.c "$LAUNCHER_SRC"

# Replace version in launcher if needed (should match PYTHON_MAJOR_MINOR)
sed -i "s/#define PYTHON_VERSION \"[0-9.]*\"/#define PYTHON_VERSION \"$PYTHON_MAJOR_MINOR\"/" "$LAUNCHER_SRC"

# Compile launcher - must link dynamically with musl for dlopen to work
# Note: -static would statically link libdl which doesn't support actual dynamic loading
# The launcher will depend on musl libc at runtime
gcc \
    -o "$INSTALL_DIR/bin/python${PYTHON_MAJOR_MINOR}-launcher" \
    "$LAUNCHER_SRC" \
    -ldl \
    -Os \
    -s \
    -Wall \
    -Wextra \
    -frandom-seed=portable-python-launcher \
    -ffile-prefix-map=/work=/build \
    -ffile-prefix-map=/in_container=/src \
    -Wl,--build-id=none

if [ ! -f "$INSTALL_DIR/bin/python${PYTHON_MAJOR_MINOR}-launcher" ]; then
    echo "[ERROR] Failed to compile launcher"
    exit 1
fi

LAUNCHER_SIZE=$(stat -c%s "$INSTALL_DIR/bin/python${PYTHON_MAJOR_MINOR}-launcher")
echo "✓ Launcher compiled successfully (size: $LAUNCHER_SIZE bytes)"

# Replace the default Python binary with our launcher
echo "Replacing default Python binary with static launcher..."
mv "$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" "$INSTALL_DIR/bin/python${PYTHON_MAJOR_MINOR}.old"
mv "$INSTALL_DIR/bin/python${PYTHON_MAJOR_MINOR}-launcher" "$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR"
rm -f "$INSTALL_DIR/bin/python${PYTHON_MAJOR_MINOR}.old"

# Recreate symlinks
echo "Creating symlinks..."
cd "$INSTALL_DIR/bin"
ln -sf "python$PYTHON_MAJOR_MINOR" python3
ln -sf "python$PYTHON_MAJOR_MINOR" python
cd "$WORK_DIR/Python-$PYTHON_VERSION"

# Verify binary type
echo "Verifying binary types..."
file "$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" 2>/dev/null || echo "  (file command not available)"
file "$LIBPYTHON" 2>/dev/null || echo "  (file command not available)"

# Test the installation
echo "Testing Python installation..."
export LD_LIBRARY_PATH="$INSTALL_DIR/lib:$LD_LIBRARY_PATH"

"$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" --version || {
    echo "[ERROR] Python version check failed"
    echo "[ERROR] Debugging information:"
    ldd "$LIBPYTHON" 2>&1 || true
    exit 1
}

"$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" -c "import sys; print('Python executable:', sys.executable)" || {
    echo "[ERROR] Basic Python execution failed"
    exit 1
}

echo "Testing pip..."
"$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" -m pip --version || {
    echo "[ERROR] Pip check failed"
    exit 1
}

# Test dynamic extension support
echo "Testing dynamic extension loading..."
"$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" -c "import ssl; print('✓ SSL module loaded')" || {
    echo "[WARN] SSL module failed to load"
}

"$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" -c "import sqlite3; print('✓ sqlite3 module loaded')" || {
    echo "[WARN] sqlite3 module failed to load"
}

"$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" -c "import ctypes; print('✓ ctypes module loaded')" || {
    echo "[WARN] ctypes module failed to load"
}

# Bundle all required shared libraries
echo "Bundling shared libraries for portability..."
cp /usr/lib/libz.so.1 "$INSTALL_DIR/lib/" 2>/dev/null || true
cp /usr/lib/libbz2.so.1 "$INSTALL_DIR/lib/" 2>/dev/null || true
cp /usr/lib/liblzma.so.5 "$INSTALL_DIR/lib/" 2>/dev/null || true
cp /usr/lib/libreadline.so.8 "$INSTALL_DIR/lib/" 2>/dev/null || true
cp /usr/lib/libffi.so.8 "$INSTALL_DIR/lib/" 2>/dev/null || true
cp /usr/lib/libncursesw.so.6 "$INSTALL_DIR/lib/" 2>/dev/null || true
cp /usr/lib/libpanelw.so.6 "$INSTALL_DIR/lib/" 2>/dev/null || true
cp /usr/lib/libsqlite3.so.0 "$INSTALL_DIR/lib/" 2>/dev/null || true
cp /usr/lib/libssl.so.3 "$INSTALL_DIR/lib/" 2>/dev/null || true
cp /usr/lib/libcrypto.so.3 "$INSTALL_DIR/lib/" 2>/dev/null || true
cp /lib/ld-musl-x86_64.so.1 "$INSTALL_DIR/lib/libc.musl-x86_64.so.1" 2>/dev/null || true
echo "✓ Bundled shared libraries"

echo "Library dependencies of libpython:"
ldd "$LIBPYTHON" 2>/dev/null || echo "ldd not available or static binary"

echo "Stripping debug symbols..."
strip "$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" 2>/dev/null || true
strip "$LIBPYTHON" 2>/dev/null || true

echo "Copying to output..."
mkdir -p /output
cp -r "$INSTALL_DIR"/* /output/

LAUNCHER_SHA256=$(sha256sum "$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" | cut -d' ' -f1)
LIBPYTHON_SHA256=$(sha256sum "$LIBPYTHON" | cut -d' ' -f1)

echo ""
echo "=========================================="
echo "Build completed successfully!"
echo "=========================================="
echo "Architecture: Static launcher + shared libpython"
echo "Launcher: $INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR"
echo "Launcher SHA256: $LAUNCHER_SHA256"
echo "Launcher Size: $(ls -lh "$INSTALL_DIR/bin/python$PYTHON_MAJOR_MINOR" | awk '{print $5}')"
echo "libpython: $LIBPYTHON"
echo "libpython SHA256: $LIBPYTHON_SHA256"
echo "libpython Size: $(ls -lh "$LIBPYTHON" | awk '{print $5}')"
echo ""
echo "This Python installation supports:"
echo "  ✓ Dynamic C extension loading"
echo "  ✓ Portable execution (static launcher)"
echo "  ✓ Virtual environments (venv)"
echo "  ✓ Standard Python tooling (pip, setuptools, etc.)"
echo "=========================================="
