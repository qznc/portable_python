#!/bin/bash
set -e

# Test script for portable Python distribution
# This validates that the static launcher + shared libpython works correctly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$(cd "${1:-$SCRIPT_DIR/build/output}" && pwd)"
PYTHON_BIN="$OUTPUT_DIR/bin/python3.12"
LIBPYTHON="$OUTPUT_DIR/lib/libpython3.12.so.1.0"

success() { echo "[✓] $1"; }
error() { echo "ERROR: $1"; exit 1; }
warn() { echo "WARN: $1"; }

echo "Checking files..."
[ -f "$PYTHON_BIN" ] || error "Python binary not found: $PYTHON_BIN"
[ -f "$LIBPYTHON" ] || error "libpython not found: $LIBPYTHON"
success "Files exist"

echo "Checking binary types..."
LAUNCHER_TYPE=$(file "$PYTHON_BIN")
LIBPYTHON_TYPE=$(file "$LIBPYTHON")

if echo "$LAUNCHER_TYPE" | grep -q "statically linked"; then
    success "Launcher is statically linked"
else
    warn "Launcher may not be statically linked: $LAUNCHER_TYPE"
fi

if echo "$LIBPYTHON_TYPE" | grep -q "shared object"; then
    success "libpython is a shared library"
else
    error "libpython is not a shared library: $LIBPYTHON_TYPE"
fi

# Check launcher size
LAUNCHER_SIZE=$(stat -c%s "$PYTHON_BIN")
echo "Launcher size: $LAUNCHER_SIZE bytes"
if [ "$LAUNCHER_SIZE" -lt 100000 ]; then
    success "Launcher is small (<100KB)"
else
    warn "Launcher is larger than expected (>100KB)"
fi

echo ""
echo "Running functionality tests..."
echo ""

echo "Test 1: Version check"
if "$PYTHON_BIN" --version; then
    success "Version check passed"
else
    error "Version check failed"
fi

echo "Test 2: Basic Python execution"
if "$PYTHON_BIN" -c "print('Hello from launcher Python')"; then
    success "Basic execution passed"
else
    error "Basic execution failed"
fi

echo "Test 3: sys.executable"
EXECUTABLE=$("$PYTHON_BIN" -c "import sys; print(sys.executable)")
if [ "$EXECUTABLE" = "$PYTHON_BIN" ]; then
    success "sys.executable correct: $EXECUTABLE"
else
    warn "sys.executable unexpected: $EXECUTABLE (expected: $PYTHON_BIN)"
fi

echo "Test 4: pip functionality"
if "$PYTHON_BIN" -m pip --version; then
    success "pip works"
else
    error "pip failed"
fi

echo "Test 5: SSL module (dynamic extension)"
if "$PYTHON_BIN" -c "import ssl; print('SSL version:', ssl.OPENSSL_VERSION)"; then
    success "SSL module loaded"
else
    error "SSL module failed to load"
fi

echo "Test 6: sqlite3 module (dynamic extension)"
if "$PYTHON_BIN" -c "import sqlite3; print('sqlite3 version:', sqlite3.sqlite_version)"; then
    success "sqlite3 module loaded"
else
    error "sqlite3 module failed to load"
fi

echo "Test 7: ctypes module (dynamic extension)"
if "$PYTHON_BIN" -c "import ctypes; print('ctypes loaded')"; then
    success "ctypes module loaded"
else
    warn "ctypes module failed to load"
fi

echo "Test 8: zlib module"
if "$PYTHON_BIN" -c "import zlib; print('zlib version:', zlib.ZLIB_VERSION)"; then
    success "zlib module loaded"
else
    warn "zlib module failed to load"
fi

echo "Test 9: Virtual environment creation"
TEST_VENV="$OUTPUT_DIR/../test-venv"
rm -rf "$TEST_VENV"
if "$PYTHON_BIN" -m venv "$TEST_VENV"; then
    success "venv created"

    # Test venv activation
    if [ -f "$TEST_VENV/bin/python" ]; then
        success "venv has python binary"

        # Test venv python
        if "$TEST_VENV/bin/python" --version; then
            success "venv python works"
        else
            error "venv python failed"
        fi

        # Test venv pip (use python -m pip as pip wrapper may not exist with symlinked python)
        if "$TEST_VENV/bin/python" -m pip --version; then
            success "venv pip works"
        else
            error "venv pip failed"
        fi
    else
        error "venv python binary not found"
    fi

    # Cleanup
    rm -rf "$TEST_VENV"
else
    error "venv creation failed"
fi

echo "Test 10: Cross-directory execution"
cd /tmp
if "$PYTHON_BIN" -c "print('Cross-directory works')"; then
    success "Cross-directory execution works"
    cd "$SCRIPT_DIR"
else
    cd "$SCRIPT_DIR"
    error "Cross-directory execution failed"
fi

echo "Test 11: instantiate.py environment duplication"
INSTANTIATE_PY="$OUTPUT_DIR/bin/instantiate.py"
if [ ! -f "$INSTANTIATE_PY" ]; then
    error "instantiate.py not found at $INSTANTIATE_PY"
fi

TEST_ENV1="$OUTPUT_DIR/../test-env1"
TEST_ENV2="$OUTPUT_DIR/../test-env2"
rm -rf "$TEST_ENV1" "$TEST_ENV2"

# Create first environment
if "$PYTHON_BIN" "$INSTANTIATE_PY" "$TEST_ENV1"; then
    success "Created environment 1 with instantiate.py"
else
    error "Failed to create environment 1"
fi

# Create second environment
if "$PYTHON_BIN" "$INSTANTIATE_PY" "$TEST_ENV2"; then
    success "Created environment 2 with instantiate.py"
else
    error "Failed to create environment 2"
fi

# Verify environments work
if "$TEST_ENV1/bin/python3" --version; then
    success "Environment 1 python works"
else
    error "Environment 1 python failed"
fi

if "$TEST_ENV2/bin/python3" --version; then
    success "Environment 2 python works"
else
    error "Environment 2 python failed"
fi

# Install package in env2 only
echo "Installing package in environment 2..."
if "$TEST_ENV2/bin/pip" install pyyaml > /dev/null 2>&1; then
    success "Installed pyyaml in environment 2"

    # Verify it works in env2
    if "$TEST_ENV2/bin/python3" -c "import yaml; print('yaml works')" > /dev/null 2>&1; then
        success "pyyaml works in environment 2"
    else
        error "pyyaml failed to load in environment 2"
    fi

    # Verify it's NOT in env1 (isolation test)
    if "$TEST_ENV1/bin/python3" -c "import yaml" > /dev/null 2>&1; then
        error "Environment 1 should not have pyyaml from environment 2"
    else
        success "Environment 1 is isolated (no pyyaml)"
    fi

    # Verify it's NOT in base python
    if "$PYTHON_BIN" -c "import yaml" > /dev/null 2>&1; then
        error "Base python should not have pyyaml from environment 2"
    else
        success "Base python is isolated (no pyyaml)"
    fi
else
    warn "Failed to install pyyaml (may be expected on some systems)"
fi

# Verify hardlinks (efficient disk usage)
INODE_BASE=$(/bin/ls -i "$PYTHON_BIN" | awk '{print $1}')
INODE_ENV1=$(/bin/ls -i "$TEST_ENV1/bin/python3.12" | awk '{print $1}')
INODE_ENV2=$(/bin/ls -i "$TEST_ENV2/bin/python3.12" | awk '{print $1}')

if [ "$INODE_BASE" = "$INODE_ENV1" ] && [ "$INODE_BASE" = "$INODE_ENV2" ]; then
    success "Environments use hardlinks (space efficient)"
else
    warn "Environments may not be using hardlinks"
fi

rm -rf "$TEST_ENV1" "$TEST_ENV2"
success "instantiate.py test completed"

echo "Test 12: Checking library dependencies"
if command -v ldd &> /dev/null; then
    echo "libpython dependencies:"
    ldd "$LIBPYTHON" || true
else
    echo "ldd not available, skipping dependency check"
fi

echo "Test Summary:"
echo "  Launcher: $PYTHON_BIN"
echo "  Size: $(ls -lh "$PYTHON_BIN" | awk '{print $5}')"
echo "  SHA256: $(sha256sum "$PYTHON_BIN" | cut -d' ' -f1)"
echo "  libpython: $LIBPYTHON"
echo "  Size: $(ls -lh "$LIBPYTHON" | awk '{print $5}')"
echo "  SHA256: $(sha256sum "$LIBPYTHON" | cut -d' ' -f1)"
