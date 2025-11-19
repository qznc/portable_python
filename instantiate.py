#!/usr/bin/env python3
# This is "Portable Python Distro - the Instantiate script"
# Copyright 2025 Andreas Zwinkau
# SPDX-License-Identifier: Apache-2.0

import os
import shutil
import sys
from pathlib import Path


def main():
    if len(sys.argv) == 1 or len(sys.argv) > 3:
        sys.exit(
            "Usage: instantiate.py <target-directory> <optional: requirements.txt>"
        )

    script_path = Path(sys.argv[0])  # lib/python3.12/x.py
    base_python = script_path.parent.parent.parent.resolve()
    target_dir = Path(sys.argv[1]).resolve()

    assert base_python.is_dir(), base_python

    # Create structure and hardlink binaries
    (target_dir / "bin").mkdir(parents=True)
    for binary in ["python3.12", "python3"]:
        os.link(base_python / "bin" / binary, target_dir / "bin" / binary)
    (target_dir / "bin/python").symlink_to("python3")

    # Hardlink base libraries
    _ = shutil.copytree(base_python / "lib", target_dir / "lib", copy_function=os.link)

    # Create pyvenv.cfg
    (target_dir / "pyvenv.cfg").write_text(
        f"home = {base_python / 'bin'}\ninclude-system-site-packages = false\n"
    )

    if len(sys.argv) == 3:
        requirements_file = Path(sys.argv[2])
        assert requirements_file.is_file(), requirements_file
        import subprocess

        cmd = [
            target_dir / "bin" / "python3",
            "-m",
            "pip",
            "install",
            "-r",
            requirements_file,
        ]
        subprocess.run(cmd, check=True)
        # clean up __pycache__ folders at target
        for root, dirs, files in os.walk(target_dir):
            for dir in dirs:
                if dir == "__pycache__":
                    shutil.rmtree(os.path.join(root, dir))


if __name__ == "__main__":
    main()
