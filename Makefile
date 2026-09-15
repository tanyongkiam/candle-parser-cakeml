# Run from this repository's root.
PYTHON ?= python3
.DEFAULT_GOAL := all
.NOTPARALLEL:
.DELETE_ON_ERROR:
.PHONY: all bundle runtime test test-public test-layers test-tools benchmark

all: runtime bundle

bundle: build/candle-parser.cml

build/candle-parser.cml: sources.list tools/load_parser.py $(wildcard src/*.cml)
	mkdir -p build
	$(PYTHON) tools/load_parser.py > $@

runtime:
	$(MAKE) -C runtime

test: test-tools test-public test-layers

test-tools test-public test-layers benchmark: runtime

test-tools:
	$(PYTHON) tools/test_harness.py
	$(PYTHON) tools/test_bundle.py

test-public:
	$(PYTHON) tools/run_tests.py --suite public

test-layers:
	$(PYTHON) tools/run_tests.py --suite all

benchmark:
	$(PYTHON) tools/benchmark.py --samples 3 --rounds 10
