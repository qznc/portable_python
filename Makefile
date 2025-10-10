# Copyright 2025 Andreas Zwinkau
# SPDX-License-Identifier: Apache-2.0

.PHONY: default clean test
default: base-python-3.12.12.tar.gz

base-python-3.12.12.tar.gz: extract_python_from_alpine.sh build_tarball.sh
	./extract_python_from_alpine.sh

test: base-python-3.12.12.tar.gz test.sh
	./test.sh

clean:
	rm -rf base-python base-python-3.12.12.tar.gz test-python
