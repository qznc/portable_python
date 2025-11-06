#!/bin/bash
set -e

PYTHON_VERSION="${PYTHON_VERSION:-3.12.12}"
PYTHON_MAJOR_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f1-2)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_DIR="$BUILD_DIR/output"
WORK_DIR="$BUILD_DIR/work"
CACHED_IMAGE="python-builder:alpine-3.22.1-deps"
CONTAINERFILE="$SCRIPT_DIR/Containerfile.base"

error() { echo "ERROR: $1"; exit 1; }

# Check for container runtime
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
else
    error "Neither podman nor docker found. Please install one."
fi

echo "=========================================="
echo "Building Portable Python"
echo "  - Tiny static launcher (~14KB)"
echo "  - Shared libpython with full dynamic extension support"
echo "  - Portable + full functionality"

echo "Building base image with dependencies..."
$CONTAINER_CMD build -t "$CACHED_IMAGE" -f "$CONTAINERFILE" "$SCRIPT_DIR"

echo "Building Python $PYTHON_VERSION..."
mkdir -p "$OUTPUT_DIR"
mkdir -p "$WORK_DIR"

# Run build in container
$CONTAINER_CMD run --rm \
    --env TZ=UTC \
    --env LANG=C.UTF-8 \
    --env LC_ALL=C.UTF-8 \
    --env SOURCE_DATE_EPOCH=1609459200 \
    --env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    -v "$SCRIPT_DIR/in_container:/in_container:ro" \
    -v "$OUTPUT_DIR:/output:rw" \
    -v "$WORK_DIR:/work:rw" \
    "$CACHED_IMAGE" \
    /bin/sh /in_container/build.sh $PYTHON_VERSION

PYTHON_BIN="$OUTPUT_DIR/bin/python${PYTHON_MAJOR_MINOR}"
LIBPYTHON="$OUTPUT_DIR/lib/libpython${PYTHON_MAJOR_MINOR}.so.1.0"

if [ ! -f "$PYTHON_BIN" ]; then
    error "Build failed - launcher binary not found"
fi

if [ ! -f "$LIBPYTHON" ]; then
    error "Build failed - libpython not found"
fi


echo "=========================================="
echo "Build Summary"
echo "Launcher: $PYTHON_BIN"
echo "  Size: $(ls -lh "$PYTHON_BIN" | awk '{print $5}')"
echo "  SHA256: $(sha256sum "$PYTHON_BIN" | cut -d' ' -f1)"
echo ""
echo "libpython: $LIBPYTHON"
echo "  Size: $(ls -lh "$LIBPYTHON" | awk '{print $5}')"
echo "  SHA256: $(sha256sum "$LIBPYTHON" | cut -d' ' -f1)"
echo ""
echo "Output directory: $OUTPUT_DIR"
echo "=========================================="
