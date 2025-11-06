This directory contains everything that's needed **inside the container** during the build process.

The host system's `build.sh` script:

1. Builds the Alpine container image
2. Mounts this directory as `/in_container` (read-only)
3. Mounts output directories for build artifacts
4. Runs `/in_container/build.sh` inside the container

This separation keeps the container environment isolated and makes it clear which files are used where.
