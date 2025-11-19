# Copyright 2025 Andreas Zwinkau
# SPDX-License-Identifier: Apache-2.0

PYTHON_VERSION := 3.12.12

.PHONY: default clean test

default: python-$(PYTHON_VERSION)-x86_64-linux.tar.gz

test: test.log
	cat $<

test.log: python-$(PYTHON_VERSION)-x86_64-linux.tar.gz
	./test.sh build/output >test.log 2>&1

build/output/bin/python3.12: Containerfile.base build.sh in_container/launcher.c in_container/build.sh
	PYTHON_VERSION=$(PYTHON_VERSION) ./build.sh >build.log 2>&1

python-$(PYTHON_VERSION)-x86_64-linux.tar.gz: build/output/bin/python3.12 package.sh instantiate.py
	PYTHON_VERSION=$(PYTHON_VERSION) ./package.sh >package.log 2>&1

clean:
	rm -rf build *.tar.gz *.log test-python
