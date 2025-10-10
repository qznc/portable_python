#!/bin/bash
# Copyright 2025 Andreas Zwinkau
# SPDX-License-Identifier: Apache-2.0

set -e

# Deterministic configuration
PYTHON_VERSION="3.12.12"
ALPINE_IMAGE="alpine:3.22.0"
PYTHON_PACKAGE="python3=${PYTHON_VERSION}-r0"
PIP_PACKAGE="py3-pip=25.1.1-r0"
PYTHON_DEV_PACKAGE="python3-dev=3.12.12-r0"

CONTAINER_NAME="python-extractor"

if ! command -v podman &> /dev/null; then
    echo "Error: podman is not installed"
    exit 1
fi

cleanup() {
    podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

echo "Setting up container..."
podman pull "$ALPINE_IMAGE"
podman run -d --name "$CONTAINER_NAME" "$ALPINE_IMAGE" sleep infinity
podman exec "$CONTAINER_NAME" apk update
podman exec "$CONTAINER_NAME" apk add --no-cache \
    "$PYTHON_PACKAGE" \
    "$PIP_PACKAGE" \
    "$PYTHON_DEV_PACKAGE"

podman cp "$(dirname "$0")/instantiate.py" "$CONTAINER_NAME:/tmp/instantiate.py"
podman cp "$(dirname "$0")/build_tarball.sh" "$CONTAINER_NAME:/tmp/build_tarball.sh"
podman exec "$CONTAINER_NAME" sh /tmp/build_tarball.sh

TARBALL_NAME="base-python-${PYTHON_VERSION}.tar.gz"
podman cp "$CONTAINER_NAME:/tmp/$TARBALL_NAME" "$TARBALL_NAME"

echo "Created: $TARBALL_NAME ($(du -sh "$TARBALL_NAME" | cut -f1))"
