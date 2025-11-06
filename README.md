# Portable Python

Self-contained static Python distribution for Linux. Works on any distro without system dependencies. Statically linked from source with musl libc.

## Features

- Works on any x86_64 Linux distro (no system dependencies)
- Statically linked binary with SSL, sqlite3, compression support
- Includes pip pre-installed and working
- Space-efficient hardlinked environments
- Independent site-packages per environment
- Instant environment creation
- Full subprocess support (sys.executable works correctly)

## Quick Start

```bash
make  # build tarball from scratch
tar -xzf python-3.12.12-static-x86_64-linux-musl.tar.gz  # extract tarball
./python-static/bin/instantiate.py my-env  # create isolated environment

# Use the environment:
./my-env/bin/python3 --version
./my-env/bin/pip install requests
./my-env/bin/python3 script.py
```

## How It Works

Python is compiled from source with static linking in an Alpine Linux container. All dependencies (OpenSSL, sqlite3, zlib, bzip2, xz, readline, ncurses) are statically linked into the binary. The result is a truly portable single binary.

`instantiate.py` creates environments using hardlinks (no copying) with independent site-packages. Multiple environments share base files on disk.

## Requirements

**Building**: podman/docker, make, Linux x86_64

**Running**: Linux x86_64 only. No other dependencies.

## Comparison to Alternatives

| Feature | This | venv | pyenv | Conda |
|---------|------|------|-------|-------|
| No system Python | ✅ | ❌ | ❌ | ✅ |
| Single tarball | ✅ | ❌ | ❌ | ❌ |
| Space efficient | ✅ | ✅ | ❌ | ❌ |

## Advanced Usage

Create multiple independent environments:

```bash
./python-static/bin/instantiate.py dev-env
./python-static/bin/instantiate.py prod-env
./python-static/bin/instantiate.py test-env

# Each gets independent packages
./dev-env/bin/pip install pytest
./prod-env/bin/pip install gunicorn
./test-env/bin/pip install requests
```

## Technical Details

- Python 3.12.12 statically linked with musl libc
- OpenSSL, sqlite3, zlib, bzip2, xz, readline, ncurses statically linked
- x86_64 Linux only
- ~13MB tarball, ~39MB extracted

## Limitations

- x86_64 Linux only (no ARM, macOS, Windows, BSD)
- the fully static binary cannot load `.so` files at runtime: "Dynamic loading not supported"
  - This is a fundamental limitation of fully static binaries with no dynamic linker because the library code cannot find symbols of the binary
- musl libc may be incompatible with some glibc-specific packages
- No Tkinter/GUI packages
- ctypes has limited functionality (pythonapi not available in static build)

## License

Apache License 2.0 - see [LICENSE.txt](LICENSE.txt)

Bundled components retain their own licenses: Python (PSF), Alpine packages (various), musl libc (MIT).
