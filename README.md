# Portable Python

Self-contained Python distribution for Linux. Works on any distro without system Python. Built from Alpine Linux with musl libc.

## Features

- Works on any x86_64 Linux distro
- Includes Python, pip, and all dependencies
- Space-efficient hardlinked environments
- Independent site-packages per environment
- Instant environment creation

## Quick Start

Build from source:

```bash
make
```

Creates `base-python-3.12.12.tar.gz`.

Create isolated environments:

```bash
tar -xvf base-python-3.12.12.tar.gz
./base-python/bin/instantiate.py my-env
```

Use the environment:

```bash
# Run Python
./my-env/bin/python3 --version

# Install packages
./my-env/bin/pip install requests

# Run scripts
./my-env/bin/python3 script.py
```

## How It Works

`extract_python_from_alpine.sh` pulls Alpine Linux 3.22.0, extracts Python 3.12.12 with musl libc, and packages into a tarball.

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
./base-python/bin/instantiate.py dev-env
./base-python/bin/instantiate.py prod-env
./base-python/bin/instantiate.py test-env

# Each has independent packages
./dev-env/bin/pip install pytest
./prod-env/bin/pip install gunicorn
./test-env/bin/pip install requests
```

## Technical Details

- Python 3.12.12, pip 25.1.1, Alpine 3.22.0
- musl libc included
- x86_64 Linux only
- ~15MB tarball, ~49MB extracted

## Limitations

- x86_64 Linux only (no ARM, macOS, Windows, BSD)
- Some C extension packages may need compilation
- musl libc may be incompatible with some glibc-specific packages
- No Tkinter/GUI packages

## License

Apache License 2.0 - see [LICENSE.txt](LICENSE.txt)

Bundled components retain their own licenses: Python (PSF), Alpine packages (various), musl libc (MIT).
