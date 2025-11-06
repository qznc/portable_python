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

# Install pyyaml in second environment only (has C extension)
echo "Installing pyyaml in test-env2..."
"$TEST_DIR/test-env2/bin/pip" install pyyaml
"$TEST_DIR/test-env2/bin/python3" -c "import yaml; print('pyyaml works')"
echo "✓ pyyaml works in test-env2"

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
