#!/bin/bash
# Copyright 2025 Andreas Zwinkau
# SPDX-License-Identifier: Apache-2.0

set -e

TARBALL="base-python-3.12.12.tar.gz"
EXPECTED_CHECKSUM="add816ef6c556cc62d5afb457a0b7515ba33d902d170e567b5a8e65fedc9679d"
TEST_DIR="test-python"

# Verify checksum
ACTUAL=$(sha256sum "$TARBALL" | awk '{print $1}')
if [ "$EXPECTED_CHECKSUM" != "$ACTUAL" ]; then
    echo "Checksum mismatch means the build is not deterministic!"
    echo "Expected: $EXPECTED_CHECKSUM"
    echo "Actual:   $ACTUAL"
    exit 1
fi

# Extract and test
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
tar -xzf "$TARBALL" -C "$TEST_DIR"

"$TEST_DIR/base-python/bin/python3" --version

# Test instantiate.py
echo "Testing instantiate.py..."
"$TEST_DIR/base-python/bin/instantiate.py" "$TEST_DIR/test-env1"
"$TEST_DIR/base-python/bin/instantiate.py" "$TEST_DIR/test-env2"

# Verify the instantiated environments work
"$TEST_DIR/test-env1/bin/python3" --version
"$TEST_DIR/test-env2/bin/python3" --version

# Install numpy in second environment only
"$TEST_DIR/test-env2/bin/pip" install numpy
"$TEST_DIR/test-env2/bin/python3" -c "import numpy; assert numpy.array([1,2,3]).sum() == 6"

# Verify numpy doesn't exist in first environment (independent site-packages)
if "$TEST_DIR/test-env1/bin/python3" -c "import numpy" 2>/dev/null; then
    echo "Error: test-env1 should not have numpy from test-env2"
    exit 1
fi

# Verify numpy doesn't exist in base-python either
if "$TEST_DIR/base-python/bin/python3" -c "import numpy" 2>/dev/null; then
    echo "Error: base-python should not have numpy from test-env2"
    exit 1
fi

echo "Test passed"
