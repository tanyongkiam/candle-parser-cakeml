# Candle parser

A pure, source-loaded Candle parser using the existing `Ast` module:

```sml
CandleParser.parse : string -> ((CandleParser.locs * string), Ast.dec list) sum
```

`Inr declarations` is success; `Inl (location, message)` is failure. Parsing
preserves ordinary, unknown and EOF error locations using the public
`CandleParser.Posn`, `Unknownpt`, `Eofpt` and `Locs` constructors. Successful
AST annotations use the executable's separate `Ast.locs` type.
Parsing does not execute the program. The public bundle exposes `parse` and
its error-location types/constructors; lexer, grammar and conversion helpers
are hidden in `local ... in ... end`. The REPL automatically adds `pp_locn`
and `pp_locs` for the public error datatypes.

Current migration (2026-10-03): the location API change is approved and the
fresh M6 runtime copy has been linked with the enlarged bitmap buffer. The
September results below are historical. Fresh independent goldens, the full
equality campaign, reader units and all nine real reader/Eval integration tests
now pass against M6. M7 is accepted following Astra's final audit; see `TEST_GAPS.md`.

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

M7 adds an optional direct-AST reader in `src/reader.cml`, separate from the
pure parser bundle. Its framing and real reader/Eval integration tests pass;
The full independent golden campaign also passes. The CakeML
startup is:

```sml
#use "build/candle-parser.cml";
#use "src/reader.cml";
CandleReader.install ();
```

After installation, input is raw Candle syntax, terminated by `;;`. Successful
phrases go directly to `Repl.nextInput` as AST declarations. A parser failure
is printed once and submits empty declarations, never an error string as source.
The reader processes a residual EOF phrase before terminating. An input
exception before any phrase byte is consumed permits retry; one during an
unfinished phrase propagates and ends the session on the next callback, so
the cancelled suffix cannot be evaluated as fresh code. Safe draining/recovery
of unfinished phrases is deferred. Ordinary completed-phrase parse, checking
and evaluation failures do not close the reader. It does not
support loading directives, quotation expansion or CML opt-outs. The pure
`CandleParser.parse` API remains available independently.

## Tests

```sh
make test
```

This runs Python harness checks, fresh-REPL visibility tests for all 18 private
helper structures, the hidden public-bundle suite, all in-scope Candle layer
tests, adapter units and real reader/Eval integration tests. Individual commands:

```sh
python3 tools/run_tests.py --suite public
python3 tools/run_tests.py --suite candle
python3 tools/run_tests.py --suite reader
python3 tools/test_reader.py
# Deliberate wrong AST: this command MUST fail.
python3 tools/run_tests.py --suite public --test tests/parser_negative.cml
# Deliberate wrong error location: this command MUST fail independently.
python3 tools/run_tests.py --suite public --test tests/error_negative.cml
```

The September baseline had **1,832 exact independent HOL golden comparisons**;
its hidden-bundle suite repeated **792 public-API comparisons** from those
fixtures, not 792 new vectors. The current input/count gates add 180 cases
for **2,012 passing exact comparisons** and **972 passing public comparisons**
against fresh independent HOL goldens. They include six real
corpus inputs, generated/mutated cases, exact errors and locations. The
preserved `cake*`/`all` paths belong to the deferred embedded CakeML port;
they retain old AST-location uses and are not current M7-supported commands.

Golden tests use stored fixtures, not a live HOL installation or external test
files, and do not execute parsed programs. The reader integration tests do
execute their small self-checking programs. See [tests/README.md](tests/README.md)
and [TEST_GAPS.md](TEST_GAPS.md) for evidence and exclusions.

## Scope and provenance

The original Candle behavior, including known bugs, is preserved. The agreed
exception is embedded `(*CML ... *)`: a reached declaration returns an explicit
located unsupported-feature error. Full embedded CakeML conversion, interactive
file loading, quotation expansion and replacement of the compiled bootstrap
parser are out of scope. The optional reader configures the existing callback
without replacing the compiled parser.

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
