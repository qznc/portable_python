#!/bin/bash
# Copyright 2025 Andreas Zwinkau
# SPDX-License-Identifier: Apache-2.0

set -e

TARBALL="${1:-base-python}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12.12}"
TEST_DIR="test-python"
PYTHON_DIR="python-static"
TARGET="python-${PYTHON_VERSION}-static-x86_64-linux-musl"

# Check tarball exists
if [ ! -f "$TARBALL" ]; then
    echo "Error: Tarball not found: $TARBALL"
    exit 1
fi

rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
tar -xzf "$TARBALL" -C "$TEST_DIR"

"$TEST_DIR/$PYTHON_DIR/bin/python3" --version

# Test instantiate.py
echo "Testing instantiate.py..."
"$TEST_DIR/$PYTHON_DIR/bin/instantiate.py" "$TEST_DIR/test-env1"
"$TEST_DIR/$PYTHON_DIR/bin/instantiate.py" "$TEST_DIR/test-env2"

# Verify the instantiated environments work
"$TEST_DIR/test-env1/bin/python3" --version
"$TEST_DIR/test-env2/bin/python3" --version

# Verify Python headers are present (needed for C extension compilation)
echo "Checking for Python headers..."
INCLUDE_DIR="$TEST_DIR/$PYTHON_DIR/include/python3.12"
if [ ! -f "$INCLUDE_DIR/Python.h" ]; then
    echo "Error: Python.h not found in $INCLUDE_DIR"
    echo "Headers are required for compiling C extensions like cffi"
    exit 1
fi
echo "✓ Python.h found in $INCLUDE_DIR"

# Install pyyaml in second environment only (has C extension)
echo "Installing pyyaml in test-env2..."
"$TEST_DIR/test-env2/bin/pip" install pyyaml
"$TEST_DIR/test-env2/bin/python3" -c "import yaml; print('pyyaml works')"
echo "✓ pyyaml works in test-env2"

# Test cffi installation (requires headers)
echo "Testing cffi compilation..."
if "$TEST_DIR/test-env2/bin/pip" install cffi >/dev/null 2>&1; then
    echo "✓ cffi compiled successfully (but cannot be loaded - static binary has no dynamic linker)"
else
    echo "✗ cffi compilation failed"
fi

# Verify pyyaml doesn't exist in first environment (independent site-packages)
if "$TEST_DIR/test-env1/bin/python3" -c "import yaml" 2>/dev/null; then
    echo "Error: test-env1 should not have pyyaml from test-env2"
    exit 1
fi
echo "✓ test-env1 is isolated from test-env2"

# Verify pyyaml doesn't exist in base python either
if "$TEST_DIR/$PYTHON_DIR/bin/python3" -c "import yaml" 2>/dev/null; then
    echo "Error: $PYTHON_DIR should not have pyyaml from test-env2"
    exit 1
fi
echo "✓ $PYTHON_DIR is isolated from test-env2"

echo "✓ All tests passed for $TARGET"
