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

info() { echo "$1"; }
error() { echo "ERROR: $1"; exit 1; }

# Check for container runtime
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
else
    error "Neither podman nor docker found. Please install one."
fi

info "Building base image with dependencies..."
$CONTAINER_CMD build -t "$CACHED_IMAGE" -f "$CONTAINERFILE" "$SCRIPT_DIR"

info "Building Python $PYTHON_VERSION"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$WORK_DIR"

# Run build in container
$CONTAINER_CMD run --rm \
    --env TZ=UTC \
    --env LANG=C.UTF-8 \
    --env LC_ALL=C.UTF-8 \
    --env SOURCE_DATE_EPOCH=1609459200 \
    --env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    -v "$SCRIPT_DIR:/build:ro" \
    -v "$OUTPUT_DIR:/output:rw" \
    -v "$WORK_DIR:/work:rw" \
    "$CACHED_IMAGE" \
    /bin/sh /build/build-inside-container.sh $PYTHON_VERSION

PYTHON_BIN="$OUTPUT_DIR/bin/python${PYTHON_MAJOR_MINOR}"
if [ -f "$PYTHON_BIN" ]; then
    CHECKSUM=$(sha256sum "$PYTHON_BIN" | cut -d' ' -f1)
    info "Binary: $PYTHON_BIN"
    info "Size: $(ls -lh "$PYTHON_BIN" | awk '{print $5}')"
    info "SHA256: $CHECKSUM"
else
    error "Build failed - output binary not found"
fi
