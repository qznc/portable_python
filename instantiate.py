#!/usr/bin/env python3
# Copyright 2025 Andreas Zwinkau
# SPDX-License-Identifier: Apache-2.0

import os
import shutil
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: instantiate.py <target-directory>")

    target_dir = Path(sys.argv[1]).resolve()
    base_python = Path(__file__).parent.parent.resolve()

    if not base_python.is_dir():
        sys.exit("Error: Run 'make' first to create base Python.")
    if target_dir.exists():
        sys.exit(f"Error: Target directory already exists: {target_dir}")

    print(f"Creating Python environment at {target_dir}")

    # Create structure and hardlink binaries
    (target_dir / "bin").mkdir(parents=True)
    for binary in ["python3.12.bin", "python3"]:
        os.link(base_python / "bin" / binary, target_dir / "bin" / binary)
    (target_dir / "bin/python").symlink_to("python3")

    # Hardlink base libraries
    _ = shutil.copytree(base_python / "lib", target_dir / "lib", copy_function=os.link)

    # Create independent site-packages
    site_packages = target_dir / "lib/python3.12/site-packages"
    shutil.rmtree(site_packages, ignore_errors=True)
    site_packages.mkdir(parents=True)

    # Copy pip essentials
    base_site = base_python / "lib/python3.12/site-packages"
    for pkg in [
        "pip",
        "setuptools",
        "packaging",
        "_distutils_hack",
        "distutils-precedence.pth",
    ]:
        if (src := base_site / pkg).exists():
            (shutil.copytree if src.is_dir() else shutil.copy2)(
                src, site_packages / pkg
            )

    # Create pip wrapper scripts
    for name in ["pip", "pip3"]:
        (target_dir / "bin" / name).write_text(
            "#!/bin/bash\n"
            'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
            'exec "$SCRIPT_DIR/python3" -m pip "$@"\n'
        )
        (target_dir / "bin" / name).chmod(0o755)

    # Create pyvenv.cfg
    (target_dir / "pyvenv.cfg").write_text(
        f"home = {base_python / 'bin'}\ninclude-system-site-packages = false\n"
    )

    print(f"Done! Use: {target_dir}/bin/python3 or {target_dir}/bin/pip")


if __name__ == "__main__":
    main()
