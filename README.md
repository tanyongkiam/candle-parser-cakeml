# Candle parser

A pure, source-loaded Candle parser using the existing `Ast` module:

```sml
CandleParser.parse : string -> ((Ast.locs * string), Ast.dec list) sum
```

`Inr declarations` is success; `Inl (location, message)` is failure. Parsing
does not execute the program. The public bundle exposes **only
`CandleParser.parse`**; lexer, grammar and conversion helpers are hidden in
`local ... in ... end`.

Repository: `git@github.com:tanyongkiam/candle-parser-cakeml.git`. All commands
run from its root. Normal loading, tests, benchmarks and rebuilding the runtime
do **not** require a surrounding CakeML or HOL checkout.

## Build and try it

Requirements: Python 3 (standard library only), GNU Make, a C compiler, and
x86-64 Linux with system glibc/libm. The executable is built from the included
assembly; compiled binaries are not committed.
Source loading currently uses a 16 GiB heap; see [runtime/README.md](runtime/README.md).

```sh
make
CML_HEAP_SIZE=16384 ./cake-ast-parse-ident --repl
```

Then enter:

```sml
#use "build/candle-parser.cml";
CandleParser.parse "let id x = x;;";
CandleParser.parse "let square x = x * x;;";
CandleParser.parse "let = ;;";
```

The surrounding REPL uses CakeML syntax (one final semicolon); the strings
contain Candle syntax. Start a fresh REPL if you previously loaded development
helpers: loading a hidden bundle does not delete bindings already in scope.

`make bundle` regenerates the single public source file from
[sources.list](sources.list); do not edit the generated file. Without Make,
`python3 tools/load_parser.py` emits the same bundle to stdout.
`--internals` explicitly emits the old development layout for layer debugging.

`make` builds both the executable and source bundle. `make runtime` links just
the executable from `runtime/cake-ident.S` and `basis_ffi.c` using a C compiler.
No compiler bootstrap or HOL build is needed. Keep `cake-ast-parse-ident`,
`config_enc_str.txt` and `repl_boot.cml` together at this root, and start the
executable here. The assembly is the newest supplied bootstrap copy with only
the documented bitmap-buffer enlargement; old runtime copies are not committed.

## Tests

```sh
make test
```

This runs Python harness checks, fresh-REPL visibility tests for all 17 private
helper structures, the hidden public-bundle suite, and all preserved layer
tests. Individual commands:

```sh
python3 tools/run_tests.py --suite public
python3 tools/run_tests.py --suite candle
python3 tools/run_tests.py --suite all
# Deliberate wrong AST: this command MUST fail.
python3 tools/run_tests.py --suite public --test tests/parser_negative.cml
```

The Candle layer/full-parser suite has **1,832 exact independent HOL golden
comparisons**. The hidden-bundle suite repeats **792 public-API comparisons**
from those fixtures; these are not 792 new vectors. They include six real
corpus inputs, generated/mutated cases, exact errors and locations. The
`all` suite also retains optional, partial CakeML-layer regressions.

Tests use stored fixtures, not a live HOL installation or external test files.
They never execute the parsed programs. See [tests/README.md](tests/README.md)
and [TEST_GAPS.md](TEST_GAPS.md) for evidence and exclusions.

## Scope and provenance

The original Candle behavior, including known bugs, is preserved. The agreed
exception is embedded `(*CML ... *)`: a reached declaration returns an explicit
located unsupported-feature error. Full embedded CakeML conversion, interactive
file loading, quotation expansion and REPL parser replacement are out of scope.

[src/README.md](src/README.md) maps every ported file to its original source,
and documents representation/refactoring adaptations. [SOURCES.tsv](SOURCES.tsv)
records the reference identities. [STANDALONE.md](STANDALONE.md) explains the
included build inputs and optional external dependencies for regenerating HOL
goldens. Existing source notices and provenance are retained.

The implementation and golden plan is in [PLAN.md](PLAN.md); the concise
maintenance handoff is [handoff.md](handoff.md). Finite goldens are strong
compatibility evidence, not a formal equivalence proof for all strings.

## Follow-on work

[JUrban compatibility](COMPATIBILITY_PLAN.md) precedes
[output-preserving optimization](PERFORMANCE_PLAN.md). Neither is implemented
by this packaging cleanup. [BENCHMARKS.md](BENCHMARKS.md) retains the earlier
baseline and explains its applicability to the new public loading path.

```sh
make benchmark
```
