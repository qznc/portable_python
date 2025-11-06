# Copyright 2025 Andreas Zwinkau
# SPDX-License-Identifier: Apache-2.0

PYTHON_VERSION := 3.12.12

.PHONY: default clean test
default: python-$(PYTHON_VERSION)-static-x86_64-linux-musl.tar.gz

test: test.log

test.log: python-$(PYTHON_VERSION)-static-x86_64-linux-musl.tar.gz test.sh
	./test.sh $< >$@ 2>&1

build/output/bin/python3.12: Containerfile.base build.sh
	PYTHON_VERSION=$(PYTHON_VERSION) ./build.sh >build.log 2>&1

python-$(PYTHON_VERSION)-static-x86_64-linux-musl.tar.gz: build/output/bin/python3.12 package.sh
	PYTHON_VERSION=$(PYTHON_VERSION) ./package.sh >package.log 2>&1

clean:
	rm -rf test-python
	rm -rf build *.tar.gz *.log
