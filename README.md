# Portable Python

Self-contained Python distribution for Linux. Works on any distro without system dependencies. Uses a launcher approach with full dynamic extension support.

## Features

- Works on any x86_64 Linux distro (no system dependencies)
- Full dynamic C extension support (NumPy, pandas, etc. work!)
- Tiny launcher + shared libpython
- Includes pip pre-installed and working
- Space-efficient hardlinked environments
- Independent site-packages per environment
- Instant environment creation
- Full subprocess support (sys.executable works correctly)

## Quick Start

```bash
make  # build tarball from scratch
tar -xzf python-3.12.12-x86_64-linux.tar.gz  # extract tarball
./output/bin/instantiate.py my-env  # create isolated environment

# Use the environment:
./my-env/bin/python3 --version
./my-env/bin/pip install requests
./my-env/bin/python3 script.py
```

## How It Works

Python is compiled from source in an Alpine Linux container.
A small kinda-static launcher dynamically loads libpython at runtime, enabling full dynamic extension support while maintaining portability.

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
./output/bin/instantiate.py dev-env
./output/bin/instantiate.py prod-env
./output/bin/instantiate.py test-env

# Each gets independent packages
./dev-env/bin/pip install pytest
./prod-env/bin/pip install gunicorn
./test-env/bin/pip install requests
```

## Technical Details

- Python 3.12.12 with launcher approach (kinda-static launcher + shared libpython)
- OpenSSL, sqlite3, zlib, bzip2, xz, readline, ncurses support
- Full dynamic C extension loading support
- x86_64 Linux only
- ~38MB tarball, ~100MB extracted

## Limitations

- x86_64 Linux only (no ARM, macOS, Windows, BSD)
- musl libc may be incompatible with some glibc-specific packages
- No Tkinter/GUI packages

## License

Apache License 2.0 - see [LICENSE.txt](LICENSE.txt)

Bundled components retain their own licenses: Python (PSF), Alpine packages (various), musl libc (MIT).
