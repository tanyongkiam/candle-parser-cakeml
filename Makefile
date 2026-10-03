# Run from this repository's root.
PYTHON ?= python3
CANDLE_PARSER_EXECUTABLE ?= $(CURDIR)/cake-ast-parse-ident
CANDLE_PARSER_RUNTIME_DIR ?= $(CURDIR)
export CANDLE_PARSER_EXECUTABLE CANDLE_PARSER_RUNTIME_DIR
.DEFAULT_GOAL := all
.NOTPARALLEL:
.DELETE_ON_ERROR:
.PHONY: all bundle runtime test test-public test-layers test-reader test-tools benchmark

all: runtime bundle

bundle: build/candle-parser.cml

build/candle-parser.cml: sources.list tools/load_parser.py $(wildcard src/*.cml)
	mkdir -p build
	$(PYTHON) tools/load_parser.py > $@

runtime:
	$(MAKE) -C runtime

test: test-tools test-public test-layers test-reader

ifeq ($(abspath $(CANDLE_PARSER_EXECUTABLE)),$(CURDIR)/cake-ast-parse-ident)
test-tools test-public test-layers test-reader: runtime
endif
benchmark: runtime

test-tools:
	$(PYTHON) tools/test_harness.py
	$(PYTHON) tools/test_bundle.py

test-public:
	$(PYTHON) tools/run_tests.py --suite public

test-layers:
	$(PYTHON) tools/run_tests.py --suite candle

test-reader:
	$(PYTHON) tools/run_tests.py --suite reader
	$(PYTHON) tools/test_reader.py

benchmark:
	$(PYTHON) tools/benchmark.py --samples 3 --rounds 10
