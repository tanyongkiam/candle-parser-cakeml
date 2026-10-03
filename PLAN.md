# Plan: faithful Candle parser in the Ast-enabled REPL

## M7 amendment — 2026-10-03

The September completion/checklist below is historical. Current M7 uses the
fresh direct-AST M6 runtime and the approved separate `CandleParser.locs` error
API; successes remain current `Ast.dec list`. Parser helpers stay hidden. An
optional `CandleReader.install ()` adapter feeds parsed ASTs into the existing
REPL interface without changing the pure parser. It retries first-byte input
exceptions and fails closed after a mid-phrase exception; safe draining is
deferred. Current acceptance requires fresh independent HOL goldens, all
in-scope layers/public/corpus/boundary cases, comprehensive real reader/Eval
testing and final Astra audit, as tracked in `TEST_GAPS.md` and the enclosing
issue #1314 plan. No optimization/JUrban change or bootstrap parser retirement
is part of M7; the latter belongs to M8. No September pass proves these gates.

Current evidence: all 21 in-scope fixture sets are independently regenerated;
2,012 exact layer comparisons and 972 hidden-public comparisons pass. Framing,
real reader/Eval integration, full-public negative controls and cache-free
standalone build/tests pass. Astra approves all six gates; M7 is complete.
HOL usage has finished. See `TEST_GAPS.md` for the evidence inventory.

## Scope amendment — 2026-09-16

The user has explicitly deferred the embedded CakeML parser. The current
deliverable is the pure Candle parser; `(*CML ... *)` blocks return a located
unsupported-feature error. This is a deliberate fidelity exception, not the
reference behavior. Preserve the partial `cake_*.cml` implementation and its
fixtures for later, but do not require or load that dependency for Candle.
All older requirements below for successful embedded CakeML conversion and
escape-hatch corpus acceptance are deferred by this amendment.

The user also requested substantially more golden vectors using existing HOL
tests. Enable the stored 134 expression vectors, then the in-scope declaration
and public-parser vectors, and expand from **all active Candle HOL test calls**
(not only a selected subset). Keep original expected failures. Add deterministic
generated/mutated inputs, record coverage and exclusions, and compare exact ASTs,
locations and errors against independently evaluated HOL results.

Current implementation: all Candle expression/declaration conversion and the
public API are implemented. The fresh Candle-only suite passes **1,832 reference
comparisons** (615 earlier layer cases, 134 expressions, 50 declarations, 60
initial public results, 210 inherited HOL-test results and 712 expanded public
results, 31 direct lowering-helper goldens, six corpus inputs and 14 conditional
controls), plus hand expectations and runtime-contract checks. Fourteen
declaration and sixteen public pragma-bearing cases remain stored but explicitly
excluded. All 214 active HOL test inputs were accounted for: 210 were compared,
four pragmas explicitly deferred. Expanded public outcomes are 475 successes and
237 failures. The oracle's flat-triple/nested-AST-pair representation issue was
corrected and the three enabled fixture files regenerated from HOL. A separate
negative-control run failed on the deliberately wrong variable AST as required.

Runtime update (2026-09-16): the user's rebuilt assembly is linked separately as
`cake-ast-parse-ident`, with its matching configuration and the 16 MiB bitmap
buffer. All implemented layers and the expanded `Ast.Ident` contract pass in a
fresh REPL. The restored Ident and corpus gates in `TEST_GAPS.md` are closed.
Use this executable, not the old binaries, with the active `parse/` configuration.
This supersedes the historical notes below about awaiting the executable; see
[runtime/README.md](runtime/README.md) for details.

## Execution checklist

This is the working sequence; the sections below supply its technical details. Complete each gate before marking that step done. Setup verified all 32 manifest entries (40 source/copy hash checks); no source drift was found. Prior runtime smoke-test results are recorded in `handoff.md`, not newly rerun during this setup.

- [x] **0. Establish the baseline.** Read the handoff, plan, README, and source manifest; verify source and bundle hashes; confirm no parser implementation exists yet. Keep the supplied binary/support files fixed and the original HOL scripts read-only.
- [x] **1. Settle the load/reuse route.** Direct executable-definition port selected after inspecting export options. Existing `Ast` literals, locations, identifiers, types and patterns load and compare structurally in the source-loaded test modules. The sum result type is checked in `tests/runtime.cml`; provenance/load order is in `src/README.md`. The real `Ast.Ident` expression/runtime contract now passes; no temporary constructor is used.
- [x] **2. Establish the reference test loop (2026-09-16).** Independent `caml_parser.run` goldens compare complete ASTs/errors; the 60 in-scope public cases include multiple declarations, lexical/parser failures and trailing input. Hand AST checks pass; a deliberately altered variable AST makes the runner fail. Embedded CakeML is deferred by the scope amendment above.
- [x] **3. Port shared support (Candle scope, 2026-09-16).** Location, PEG, precedence, lexer, grammar and conversion support pass focused reference tests. Basis/natural-number adaptations and source mappings are documented; no duplicate public AST exists. The embedded CakeML requirement is explicitly deferred by the user.
- [x] **4. Port the Candle core incrementally (2026-09-16).** The real 18-file `CandleParser.parse` has the agreed pure type and passes the initial 859-comparison Candle suite, including expression/declaration lowering, full-input checks and repeated-call independence. No in-scope placeholder remains. The explicit unsupported pragma branch implements the user's scope reduction, not the frozen reference's behavior.
- [x] **5. Complete compatibility coverage.** All in-scope inherited tests, deterministic products/mutations, six corpus inputs and 14 conditional/precedence controls match the independent reference. Corpus byte hashes and preparation boundaries are recorded. The locally documented #1019-related class is characterized without fixes; the issue body itself was not retrieved, so the donor-derived cases are not claimed as verbatim issue text. There are zero unexplained mismatches in the declared suite.
- [x] **6. Measure efficiency, then optimize only demonstrated bottlenecks.** The isolated calibrated run separates startup, parser loading, input loading and repeated parsing. Raw samples, source/runtime hashes, memory interpretation and the bounded scaling/source audit are recorded. No port-specific asymptotic regression was identified; there is no comparable source-loaded reference executable, and no speedup claim. Inherited/resource limits are explicit. No grammar/behavior fix or parser performance rewrite is bundled in.

  [BENCHMARKS.md](BENCHMARKS.md) records the accepted baseline and limitations,
  superseding the historical concurrent pilot.
- [x] **7. Package and hand back.** Source/load order, exhaustive file mapping, golden commands, compatibility limits and benchmark artifacts are provided. The fresh full Candle suite and optional legacy suite pass; the negative control fails as intended and all three Python harness checks pass. The default generated bundle now hides 17 helper structures with `local`, exporting only `CandleParser.parse`. Two bundle checks verify real `#use`/visibility and unchanged development loading; the public suite repeats 792 goldens behind the hidden boundary. This directory is the standalone project root, with root Make targets and external oracle dependencies documented in `STANDALONE.md`.

Current coverage and remaining gates are maintained in [TEST_GAPS.md](TEST_GAPS.md).
The normal Candle-only invocation is `python3 tools/run_tests.py --suite candle`.
The new `Ast.Ident` executable removes the old constructor blocker. See
[runtime/README.md](runtime/README.md) for the separate build and bitmap-buffer
provenance; original binaries and original HOL sources remain preserved.
The source-only load bundle is generated from `sources.list` by
`tools/load_parser.py`. Direct helper and expanded HOL-test goldens are enabled,
not merely stored. Corpus and baseline performance acceptance are complete.

## 1. Contract and scope

Follow-on work is planned separately in [COMPATIBILITY_PLAN.md](COMPATIBILITY_PLAN.md)
and [PERFORMANCE_PLAN.md](PERFORMANCE_PLAN.md). Those plans deliberately distinguish
the original faithful baseline from later compatibility changes and subsequent
output-preserving optimization. They do not relax this initial port's fidelity
or completion gates.

Implement the CakeML module `CandleParser`, loaded into the supplied `cake-ast-parse-ident --repl`. It consumes a complete source string and returns either an error value or source declarations, using the existing `Ast` types:

```sml
CandleParser.parse : string -> ((CandleParser.locs * string), Ast.dec list) sum
```

This preserves the current `caml_parser.run` result shape with parser-owned
error locations and a public string wrapper around its character-list input.
`Inl (location, message)` means failure; `Inr declarations` means success.
The public error datatype retains HOL unknown/EOF markers that current
`Ast.locs` cannot represent; declaration lowering applies the reference's
`to_locs` conversion at the AST boundary.

The parser is pure: no I/O, global parser state, runtime evaluation, or exception-based syntax-error API. Do not catch all runtime exceptions and turn programming errors into parse failures. Resource exhaustion is not a syntax error.

The latest user instruction supersedes the earlier permission to fix mishandling: preserve the existing grammar, AST lowering, locations, rejection behavior, and error messages. Record known limitations, but fix none in this first version. In particular, investigate #1019 only to characterize and preserve the reference behavior.

The authoritative core behavior is `caml_parser.run (explode input)` from the current checkout, not arbitrary modern OCaml. The compiler's `parse_ocaml_syntax` wrapper additionally formats an error for terminal display; that formatting does not belong in this structured-error API.

## 2. Freeze and map the reference

Use `SOURCES.tsv` to locate the reference material. Per the user's final instruction, HOL scripts stay read-only at their original paths and do not need copying. Four non-HOL fixtures are snapshotted under `reference/`; the runnable bundle is directly in `parse/`. Put implementation separately under `src/`. The recorded source hashes are the baseline: the current checkout contains changes beyond HEAD, so the Git commit alone does not identify the parser/AST environment. Check for source drift before producing reference results, and record a deliberate baseline update if needed; do not silently mix versions.

Reference at planning time:

- CakeML HEAD: `d7800ad297ee27e24ca9c52e016e6f925f30f7c6`, with the current working-tree versions of selected sources.
- Local HOL HEAD: `e395eb6e69054ff6f7cef9d1107fd1a04dd5848f`; selected source hashes are recorded separately.
- Supplied executable SHA-256: `5fb7281af35ff7d3719965dcacb4e69564e4904454befa8fcdc68dac555433fb`.

Core dependency path:

```text
string -> character list -> caml_lex
       -> camlPEG + generic PEG execution
       -> camlPtreeConversion -> Ast.dec list
                 |
                 +-- (*CML ... *) -> CakeML lexer/PEG/AST conversion
```

Use `caml_lexProgScript.sml`, `caml_parserProgScript.sml`, `lexerProgScript.sml`, and `parserProgScript.sml` as a map of executable definitions and existing translation choices. They are HOL scripts, not source files that can be loaded into the CakeML REPL.

Retain the Candle-specific identifier conventions and lowering functions such as `compatCurryP`, `compatCurryE`, `compatCons`, and `compatModName`. Replacing these with normal OCaml conventions would be a semantic change even if simple examples still parse.

### Input preprocessing boundary

`candle_boot.ml` has a separate input reader handling phrase collection, file-loading directives, and quotation expansion through a mutable `unquote` function. That reader is not `caml_parser.run`.

The pure core accepts the string that would be passed to `caml_parser.run`. It does not execute `#use`, `loads`, or `needs`, and does not consult a global quotation callback. Document this explicitly. For raw Candle-session corpus tests, capture the strings after the existing reader's preprocessing, then feed those strings to both parsers. Also test raw input against the core reference, preserving its actual response rather than pretending the core supports every interactive-reader feature.

Do not change `Repl.nextString`, wire in a new REPL parser, or implement #1314. Loading and calling the parser as an ordinary function is the deliverable.

## 3. Implementation sequence

### A. Establish source loading and representation compatibility

Start with a tiny `CandleParser` module and one AST construction test loaded through the existing REPL boot loader. Confirm `Ast.dec`, locations, identifiers, and literals can be referenced without redeclaring AST datatypes. The supplied `repl_ast.cml` is a concrete naming reference (`Ast.Ident`, `Ast.Intlit`, `Ast.Locs`, etc.).

Private token, grammar, and intermediate parse-tree types are fine. Final AST values must use the executable's constructors. Do not copy `astScript.sml` into a new runtime datatype declaration.

### B. Reuse executable definitions with minimal translation work

First inspect whether the existing translated program state can cheaply export the parser's dependency slice as loadable CakeML source. If so, reuse those generated declarations, retaining only required helpers and referencing the already available `Ast`/Basis declarations. Validate the exported source by loading it; a displayed HOL AST is not automatically valid CakeML source.

Do not turn this into an exporter/translator refactor. If an existing export route is not usable with a small adaptation, port the executable definitions directly in dependency order, using the translation scripts as guidance. Strip proof scaffolding only from the new implementation, not the reference files. Record source-definition-to-port mappings so each function has a reviewable origin.

The implementation should retain these layers, whether represented by separate files or small internal modules:

1. Location and small shared helpers, generic parse-tree/PEG execution, precedence parser.
2. CakeML escape-hatch dependencies needed by `ptree_Definition` (user-deferred;
   the current Candle-only parser instead reports the explicit unsupported error).
3. Candle token definitions and lexer.
4. Candle grammar and ordered PEG choices.
5. Parse-tree conversion and its compatibility transformations.
6. The pure `parse` wrapper and a separate test driver.

Audit the reachable dependency closure rather than importing the entire bootstrap compiler. The selected reference files cover the principal code, not every upstream list/string/finite-map helper. Reuse available Basis functions where their semantics agree. In particular, preserve HOL natural-number subtraction behavior when porting counters into CakeML integers; do not mechanically replace saturating subtraction with signed subtraction.

### C. Preserve parser execution semantics

Keep PEG choice order, backtracking, error accumulation, and full-input checking. The outer Candle `caml_parser.destResult` explicitly rejects leftover tokens; an accepted prefix is not a successful parse of the entire Candle string. The embedded CakeML pragma path deliberately uses the different `pegexec.destResult`: it unwraps the parse result without checking leftovers, then converts the accepted prefix. Preserve that distinction, including malformed embedded input that yields an empty declaration list. Preserve lexer error selection (the first reported lexical-error location) and conversion failures.

Preserve source locations and `Lannot` structure in output. Preserve constructor-argument packaging, currying, generated bindings, sequencing, and declaration order. These affect program meaning and cannot be normalized away to make tests pass.

Repeated calls must be independent: interleave valid, invalid, empty, and valid inputs, then compare the repeated results. Any local state needed by an adapted implementation must be fresh per call and must not leak across parses.

### D. Finish a reproducible loadable package

Provide the `.cml` implementation files, a documented load order or generated combined file, the test driver, and a short compatibility note. Keep the core usable without the test harness or external processes. The combined file, if generated, should have one reproducible generation route rather than a second hand-maintained copy.

Do not rebuild the compiler merely to load changed parser source. Use the supplied Ast-enabled REPL throughout development.

## 4. Correctness testing

### Independent reference results

Build a small oracle around the original `caml_parser.run`, not around the newly ported code. Use existing HOL evaluation or a separately exported original translated parser, whichever is practical. Any necessary HOL work follows the HOL4 skill. Freeze the reference sources before port changes, and generate expected results outside the candidate's implementation.

Compare successful results structurally, including locations and annotations. AST pretty-print output is for diagnostics, not the equality oracle: it can omit details or truncate large values. If values cannot be compared in one runtime, use a complete, unambiguous structural serialization with lengths/tags and escaped strings. Test that serializer on small hand-checked ASTs. Check error variants, locations, and message strings exactly.

Maintain some independent hand-written expectations alongside differential tests. Otherwise a shared bug in the port and reused oracle adapter could pass unnoticed.

### Test groups

| Group | Required coverage |
| --- | --- |
| Existing tests | Reuse cases from `camlTestsScript.sml`, including expected failures. Some target grammar nonterminals directly: preserve those as layer tests, and wrap appropriate cases in declarations for public-API tests. |
| Lexer | Nested/unterminated comments, string and character escapes, identifier capitalization, integer bases/suffixes/underscores, floating literals, whitespace and newlines, invalid characters, EOF. Compare token locations as well as kinds. |
| Expressions and patterns | Precedence and associativity; application and constructor arguments; tuples/lists; alias/or/typed patterns; let/rec/function/match/try; sequencing, conditionals, records and loops where the reference supports them. |
| Declarations | Several declarations in one input; type definitions/abbreviations, exceptions, modules and name qualification; supported and unsupported forms based on the actual reference. |
| Escape hatch | User-deferred by the scope amendment: test the explicit unsupported result, retain original reference fixtures, and label the boot projection. Successful embedded conversion is not a current completion gate. |
| Compatibility limits | Conditional operands/tuple components associated with #1019 in the local notes, unsupported syntax, quotation/directive boundaries, and discovered oddities. Record exact provenance; do not claim unavailable issue text was retrieved. Lock in observed baseline behavior, not desired OCaml behavior. |
| Completeness | Empty/comment-only inputs, missing terminators, trailing junk after a valid prefix, malformed final declarations. Compare to the oracle; do not assume every malformed-looking input must be rejected. |
| Real inputs | The copied Candle boot program and records test; then representative available Candle/HOL Light files after the same preprocessing boundary. Record corpus provenance and which inputs are raw versus preprocessed. |

Small deterministic generators should combine grammar fragments and mutate valid inputs by deletion, insertion, truncation, or delimiter changes. Use fixed seeds, compare with the oracle, and minimize mismatches into regression cases. Do not execute arbitrary generated programs: parsing and structural comparison suffice.

Useful metamorphic tests include whitespace/comment insertion at known token boundaries and equivalent parenthesization where the grammar permits it. Location changes are expected in these tests: compare structural shape separately while retaining exact-location checks against the oracle for each concrete input. Do not strip locations from the primary differential suite.

## 5. Efficiency testing and optimization policy

Get the faithful baseline working before changing representations. Preserve sharing of list tails and the existing PEG execution model. Avoid repeated `explode`, growing-prefix append/string concatenation, and repeatedly measuring the remaining input. Instantiate grammar data once where the reference permits it, not once per token or recursive call.

The current Candle lexer builds its token list with non-tail recursion. This is a potential limit, not permission to redesign the lexer immediately. Measure first; a later accumulator conversion is acceptable only if results and locations remain identical on the full suite. Apply the same discipline to repeated parse-tree flattening/conversion.

Benchmark parsing alone: load and compile the parser first, avoid printing full ASTs, perform warmups, and consume results via a small count/checksum or validation. Separately report module load time and whole-process startup/peak memory, which matter operationally but are not parser throughput. Do not compare time spent in HOL evaluation with candidate native runtime and call that a parser speedup.

Use real boot/corpus inputs plus geometric-size synthetic inputs: many declarations/tokens, long lists and application chains, nested syntax/comments, long literals, and a late syntax failure. Compare candidate and executable reference under the same compiler/runtime when available. Record input sizes, repeated-run medians, peak resident memory, and whether either parser hits a resource limit. Do not assume a generic backtracking PEG is linear on all inputs.

Acceptance: no avoidable asymptotic regression on the scaling families, no material unexplained slowdown against a comparable executable reference, and successful parsing of the real corpus within available resources. If an optimization changes behavior, revert it rather than classifying it as a bug fix. Record inherited resource limits honestly; do not add a parser depth limit disguised as a syntax error.

## 6. Completion gates

1. The module loads in a fresh supplied REPL and has the intended pure result type over existing `Ast` types.
2. All baseline regression and corpus results match, with zero unexplained differential mismatches and no behavior fixes bundled in.
3. Full-input/error handling and repeat-call independence are covered. The
   user-deferred CakeML escape hatch has explicit rejection checks and preserved
   original fixtures; successful conversion is not part of this amended gate.
4. Performance measurements distinguish startup, source loading/compilation, and parsing; identified regressions are resolved or explicitly reported before claiming an efficient finished port.
5. One documented test invocation produces a clear pass/fail result. REPL process exit status alone is insufficient: the REPL can print a type/runtime error and continue. Use an explicit final sentinel and fail the outer harness on missing sentinel or unexpected diagnostics.
6. Report implementation provenance, tests actually run, known inherited limitations, and untested syntax/corpus areas. Finite tests establish strong compatibility evidence, not a formal proof for all strings.

Current status (2026-09-16): the Candle-only public parser and all in-scope
converters are implemented. The normal suite passes 1,832 exact reference
comparisons, plus hand/runtime/harness checks. Independent corpus evaluation
and the isolated performance/scaling audit are complete. The amended Candle-only
plan's acceptance gates are recorded as complete in `TEST_GAPS.md`. Embedded
CakeML and the separate compatibility/performance follow-on plans remain deferred.
