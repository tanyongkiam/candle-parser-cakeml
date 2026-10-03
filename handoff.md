# Handoff: Candle source-loaded parser

## Current M7 state — 2026-10-03

The implementation uses the matching direct-AST M6 runtime. All nine real
reader/Eval tests pass (26 fresh sessions), as do 46 framing checks, 18
mid-phrase exception/Interrupt cases, eight harness units and both bundle
visibility checks. The documented repository-root startup path also passes
a fresh direct-AST evaluation check.

Fresh current-reference HOL goldens, all 2,012 in-scope exact comparisons and
the repeating 972-comparison public subset now pass. Both full-public negative
controls fail only for their intended assertion, despite outer REPL status
zero and a printed completion marker. Astra approves all six M7 gates; M7 is
complete, with no remaining must-fix or over-engineering finding.
[TEST_GAPS.md](TEST_GAPS.md) records the live checkpoint. September's
1,832/792 results are historical, not evidence for the new runtime/location ABI.
HOL usage is finished; the remaining audit uses stored evidence and native tests.
M7 is approved for a local commit. Pushing requires separate approval.

## Contract and settled scope

```sml
CandleParser.parse : string -> ((CandleParser.locs * string), Ast.dec list) sum
```

This pure function returns existing Ast declarations: `Inr declarations`
for success; `Inl (location, message)` for failure. Error types/constructors
are public: `Posn`, `Unknownpt`, `Eofpt`, `Locs`. Successful annotation
locations instead use `Ast.locs` with integer-pair coordinates or `Nolocs`,
following the reference's `to_locs` boundary. Neither parser errors nor AST
successes are converted back to source for reparsing.

All 18 helper structures are hidden by `local ... in ... end`. The REPL's
generated error-datatype printers `pp_locn` and `pp_locs` are the only
additional permitted exports. `--internals` retains the development load order.

A reached `(*CML ... *)` declaration returns the explicit located unsupported
error. Misplaced pragmas may fail earlier. This is the deliberate fidelity
exception: preserve reference grammar, lowering, locations, error messages and
known quirks otherwise. Interactive file loading and quotation expansion are
excluded. Preserve partial `cake_*.cml` source and original CML fixtures;
do not port the embedded CakeML parser as a side task.

## Optional direct-AST reader

Load `src/reader.cml` after the pure bundle and call `CandleReader.install ()`.
This new I/O glue is deliberately outside `sources.list`; only `install`
is authored public API. It captures the original Repl slots, frames unchanged
bytes, calls the public parser and supplies successful ASTs through `Inr`.
Parse failures print one located diagnostic and submit empty declarations,
clearing stale payloads while keeping EOF distinct.

The approved small policy retries input exceptions before any framing byte is
consumed. After any consumed byte/lookahead, it propagates the exception and
returns EOF on the next callback without reading the cancelled suffix.
Sophisticated safe draining is deferred. Completed-phrase parse/type/check/
evaluation failures remain recoverable. Mid-phrase injected exceptions and a
real OS SIGINT through polling/FFI validate fail-closed behavior.

The reader configures the existing callback, not a new compiler protocol or
replacement compiled parser. M8, not M7, retires the bootstrap OCaml parser.

## Reproduce

Use this directory as the standalone repository root. Runtime hashes and the
only assembly adjustment (larger bitmap buffer) are in
[runtime/README.md](runtime/README.md). Keep the executable, configuration and
boot files matched, and start it from this root. Native linking does not require
HOL or a compiler bootstrap.

```sh
make
CML_HEAP_SIZE=16384 ./cake-ast-parse-ident --repl
```

Then enter CakeML startup commands:

```sml
#use "build/candle-parser.cml";
#use "src/reader.cml";
CandleReader.install ();
```

After installation enter raw Candle phrases terminated by `;;`.
Without installing the reader, use `CandleParser.parse "let id x = x;;";`
in the unchanged CakeML REPL.

```sh
make test
# Both commands below MUST fail for their intended named assertion only:
python3 tools/run_tests.py --suite public --test tests/parser_negative.cml
python3 tools/run_tests.py --suite public --test tests/error_negative.cml
```

All suites, visibility checks and negative controls honor
`CANDLE_PARSER_EXECUTABLE` and `CANDLE_PARSER_RUNTIME_DIR` together.
[tests/README.md](tests/README.md) gives count gates, scope exclusions,
coverage mapping, strict diagnostic checks and independent oracle commands.
Preserved `cake*`/`all` entry points retain the old location ABI and are not
current M7-supported commands.

## Provenance and follow-on work

[src/README.md](src/README.md) maps all 24 ported files and the new reader glue
to upstream definitions without fragile line numbers, and records representation/
refactoring adaptations. Eighteen files form the pure Candle bundle; six are
deferred embedded CakeML work. This is a hand-written executable-definition
port, not a mechanical exporter: do not introduce a translator or another AST.

Ast fields preserve nested binary pairs; private metadata can use flat tuples.
Variables use real `Ast.Ident`; Candle source constructors named `Var`
are unrelated. Parser-owned locations preserve unknown/EOF markers separately
from AST annotations. Current reference/copy identities are in
[SOURCES.tsv](SOURCES.tsv); frozen corpus snapshots are intentionally distinct
from migrated active boot files. All 33 current reference/copied/frozen asset
hashes were rechecked and matched.

[STANDALONE.md](STANDALONE.md) explains self-contained assets and optional
external CakeML/HOL requirements for regeneration. Normal tests need stored
fixtures, not upstream sources or network access. Never derive expectations
from candidate output. Corpus equality does not execute the frozen programs;
real reader/Eval tests do execute their bounded self-checking inputs.

Finite goldens are strong evidence, not a proof for every string or unbounded
size/depth. Historical measurements in [BENCHMARKS.md](BENCHMARKS.md) do not
establish current-runtime performance. JUrban work in
[COMPATIBILITY_PLAN.md](COMPATIBILITY_PLAN.md) precedes
[PERFORMANCE_PLAN.md](PERFORMANCE_PLAN.md); neither is part of M7.
