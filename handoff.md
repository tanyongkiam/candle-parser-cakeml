# Handoff: Candle-only source-loaded parser

Updated 2026-09-16. The public parser and all in-scope lowering are implemented.
The current suite passes **1,832 exact independent HOL comparisons** in a fresh
Ident-enabled REPL: 18 source files and 34 test files. Six real-input comparisons
and the isolated baseline benchmark are complete. Final acceptance is tracked in
[TEST_GAPS.md](TEST_GAPS.md); do not use the earlier Var-era blockers as current
work instructions.

## Contract and scope

```sml
CandleParser.parse : string -> ((Ast.locs * string), Ast.dec list) sum
```

The function is pure and returns the executable's existing Ast types.
`Inl (location, message)` is failure; `Inr declarations` is success. It does
not execute the AST, load files, expand quotations, or replace the REPL parser.
This is not #1314 integration.

The user explicitly deferred the embedded CakeML parser. A reached
`(*CML ... *)` declaration therefore returns a located unsupported-feature
error. Misplaced pragmas can fail earlier in the ordinary grammar. This is the
one deliberate fidelity exception, not original HOL behavior. Preserve the
partial `cake_*.cml` files and original pragma goldens for later; they are not
dependencies of the 18-file Candle bundle. Do not complete them as a side task.

Otherwise preserve original grammar, AST lowering, locations, error messages
and known bugs. JUrban compatibility fixes and substantial optimization remain
separate follow-on plans: [COMPATIBILITY_PLAN.md](COMPATIBILITY_PLAN.md) first,
then [PERFORMANCE_PLAN.md](PERFORMANCE_PLAN.md) against the corrected baseline.

## Run and inspect

From this project root (the current `parse/` directory):

```sh
python3 tools/run_tests.py --suite candle
python3 tools/test_harness.py
# Optional preserved CakeML-layer regressions, not a full embedded parser:
python3 tools/run_tests.py --suite all
# Negative control: MUST fail with negative/changed-identifier.
python3 tools/run_tests.py --suite candle --test tests/parser_negative.cml
```

Interactive loading instructions are in [README.md](README.md). The bundle
generator `tools/load_parser.py` uses [sources.list](sources.list), then the
public call can be made directly. Loading individual files through the supplied
`#use` reader has also been checked in a fresh REPL.

Use **cake-ast-parse-ident**, from this project root, with its active matching
`config_enc_str.txt`. The test/benchmark drivers default to a 16 GiB heap for
source compilation. The larger bitmap buffer is separately documented in
[runtime/README.md](runtime/README.md), together with exact hashes and rebuilding.
Old executables/configuration remain only in the development workspace, not
the standalone commit. The committed newest assembly and matching configuration
build the active executable with `make` or `make runtime`.
No HOL/compiler bootstrap is needed to load parser source.

The default generated bundle now wraps all helpers in `local ... in ... end`
and exports only `CandleParser.parse`. `--internals` retains the old development
bundle; existing sub-tests load individual modules unchanged. The new `public`
suite repeats 792 public-API goldens behind the hidden boundary. `test_bundle.py`
checks all 17 helpers are undefined after fresh `#use` loading, and that the
only printed Candle export is `CandleParser.parse`.

Treat this whole directory as the future repository root. `make bundle`,
`make runtime` and `make test` work here without the surrounding CakeML checkout.
See [STANDALONE.md](STANDALONE.md) for extraction and the optional external
`CAKEML_ROOT` configuration for regenerating HOL reference results.

## Evidence and provenance

- Earlier Candle layers: 615 comparisons.
- Full expressions: 134; in-scope declarations: 50; initial public inputs: 60.
- All 214 active HOL test inputs accounted for: 210 compared, four pragmas deferred.
- Expanded public wrappers/products/mutations: 712, with 475 successes and 237 failures.
- Direct lowering helpers: 31.
- Real corpus: six successful exact comparisons.
- Conditional/tuple/precedence controls: 14, with ten successes and four failures.

These counts overlap layer/public views and earlier regressions; they are not
1,832 distinct programs. Goldens compare complete constructor-valued ASTs,
including annotations and locations, or exact located errors. Parsed programs
are never executed. Finite comparisons are not a formal equivalence proof.

The independent oracle builds all succeeded: `afc19b02` (restored AST fixtures),
`cb989c16` (inherited/expanded), `e3ac3285` (helpers), `c54b26f3` (records/boot),
and `935b571e` (additional corpus/conditional controls). None is still running.
Fixture regeneration and input-generator commands are in
[tests/README.md](tests/README.md); expected results never come from the candidate.

The raw records and two-pragma boot projection have 20/42 declarations.
The other corpus inputs are complete fib/streams regression files and exact
prefixes of locally available HOL Light lib/basics files. Their hashes and
excerpt boundaries are retained in [tests/corpus](tests/corpus/README.md).
This is not whole-HOL-Light, raw-boot, quotation-expansion or Flyspeck acceptance.

Conditional controls preserve the locally documented limitation associated with
#1019. The bare addition and second-tuple-component cases came from local donor
commit `51513f0dfb3bcf169c8342de6efd04e5b7b4e00b`; neighboring controls were
authored explicitly. The issue body was not retrieved, so do not describe these
as verified verbatim issue examples or as a compatibility fix.

## Source map and adaptations

[src/README.md](src/README.md) maps every one of the 24 ported files to original
sources without fragile source line-number pointers. Eighteen are in the Candle
bundle; six are preserved/deferred CakeML work. The implementation is a direct
hand-written executable-definition port, not a mechanical exporter output.
Do not build a new translator/exporter as part of maintaining it.

The adaptation ledger records grammar vectors/chunking, the PEG continuation
machine, natural-number arithmetic, helper factoring, lazy alternatives and
private representation changes. Runtime Ast products require nested binary
pairs, whereas private metadata can use native flat tuples. The oracle adapter
was corrected accordingly. Variables use real `Ast.Ident`; the source Candle
constructor named `Var` is unrelated and must not be renamed.

Original HOL sources remain read-only. All 24 read-only reference hashes in
[SOURCES.tsv](SOURCES.tsv) were rechecked. Its Ast row was deliberately updated
for the user's already-committed non-inferior Var overload; the old hash and
exact one-line change are documented in `runtime/README.md`. Parser-definition
hashes did not change.

## Performance and remaining limits

[BENCHMARKS.md](BENCHMARKS.md) records isolated startup/loading/batched parsing,
raw JSON samples and environment/source hashes. The earlier calibrated baseline measured
about 8 ms for records and 138 ms for the 24 KB boot projection; parser loading
took about 5.8 seconds. These are host-wall estimates with visible variability,
not a speedup comparison or parser-only memory measurements.

The standalone hidden-bundle rerun is stored separately as `benchmark-public.json`
and `benchmark-public-environment.json`: approximately 2.4 s parser loading,
6 ms records and 106 ms boot projection. It verifies the packaged loading path,
not a controlled attribution of speedup to `local` encapsulation. A relocated
cache-free project rebuilt its runtime byte-identically and passed `make test`.

No port-specific asymptotic regression was identified in the bounded scaling
and source audit. Arbitrary-input linearity, maximum depth/file size, very large
HOL Light/Flyspeck workloads and minimum source-loading heap are not established.
Inherited PEG backtracking and or-pattern expansion can still be expensive.
No compatibility fix or parser performance rewrite was applied during this
golden-test expansion.
