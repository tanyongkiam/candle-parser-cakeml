# Current layer tests

## M7 campaign — 2026-10-03

The full comparison and integration campaigns pass against fresh independent
current-reference goldens. Astra's final audit approves all six M7 gates.
Errors use `CandleParser.locs`; private fixtures
use `CandleLocation`; successful AST annotations use `Ast.locs`.
The matching fresh M6 runtime is now linked here with an enlarged bitmap
buffer; see `../runtime/README.md` for all acceptance artifact hashes.

Passing current checks: eight harness units, both public-bundle visibility
tests, the focused Ast contract, all 46 reader frame checks plus 18 mid-phrase
exception/Interrupt scenarios, and all nine real reader/Eval integration tests
(26 fresh sessions). All 21 in-scope fixture sets have been independently
regenerated and count-checked. The input generator adds 147 boundary inputs
and 33 source-audit controls to the historical 712 expanded inputs.

Run from this project root:

```sh
make test
python3 tools/run_tests.py --suite reader
python3 tools/test_reader.py
```

`make test` runs harness, bundle, public, Candle layers, reader units and real
integration sequentially, avoiding competing large REPL heaps. Embedded
CakeML suites are preserved but outside the M7 gate. For an external runtime:

```sh
CANDLE_PARSER_EXECUTABLE=/absolute/path/to/cake \
CANDLE_PARSER_RUNTIME_DIR=/absolute/path/to/matching-support-files make test
```

Both selections apply to all suites, bundle tests, negative controls and reader
integration. `run_tests.py` also accepts `--executable`/`--runtime-dir`.
The runtime cwd must contain its matching configuration and boot files.

## Reader framing and integration

`tests/reader.cml` uses a strict synthetic channel that raises on reads beyond
the first phrase's `;;`. The 46 frame checks cover comments, multiline/CRLF
input, strings/escapes, character forms, apostrophes/type variables, blocks,
brackets, constructor records, modules and signatures. These compare framed
payloads with parsing unchanged whole phrases: they test framing, not independent
parser equivalence. EOF/repeated callbacks, stale-state clearing, zero-read
installation and first-byte input-exception/Interrupt retry are asserted.
Original refs are restored on both success and failure.

Eighteen additional scenarios interrupt comments, nested comments, strings,
escapes, character/comment/delimiter lookahead, blocks and brackets. The agreed
fail-closed policy returns EOF on the next callback without any suffix read.
Safe draining is deferred; first-byte retry remains permitted. These input-raised
Interrupt cases do not replace real SIGINT/polling tests.

`tools/test_reader.py` loads a temporary public bundle and the optional adapter
through the existing CakeML `#use` path, then installs it and feeds actual
Candle source bytes. Successful ASTs go through the real REPL evaluator.
It checks exact diagnostic traces for intentional-error sessions, and printed
markers for effects/recovery; it never disables the ordinary harness's strict
diagnostic filter. Test-only Candle `ref`/`assert` aliases supply the environment
absent from generic `--repl`, not parser semantic fixes. All nine current
integration tests pass (26 fresh sessions): success/shadowing, empty/residual
EOF, unchanged default reader, exact parse/type/check/evaluation diagnostics,
failed-module allocation rollback, first-byte/mid-phrase reader exceptions,
five malformed residual-EOF forms, unsupported-pragma recovery, preserved
loop-lowering failures, ten strict malformed-escape boundaries, and real
mid-comment OS SIGINT through the default polling frequency and FFI. No
cancelled suffix or following phrase executes in either mid-phrase exception
test. The type/check failures have preceding effects in the same phrase;
those effects must not execute. The parser failure must not replay the previous
AST's increment. Unknown helper behavior is not repaired: reference for/while
lowering is characterized as an expected generic-environment failure.

Intentional diagnostics are checked in exact order/count, with no extras;
successful recovery/effects need a separately printed marker. Exact raw parser
error/AST equivalence still requires the fresh HOL golden campaign. See
`../TEST_GAPS.md` for its outstanding gates.

## M7 coverage cross-check

The cross-check used the executable definitions in `caml_lexScript.sml`,
`camlPEGScript.sml`, `camlPtreeConversionScript.sml` and `caml_parserScript.sml`,
not just the inherited-input count. The OCaml parsing directory contains one
test script, `camlTestsScript.sml`: the extractor accounts for every active
parsetest/tytest call, including calls inside `expectFailure`. The other relevant
sources contain parser definitions/proofs, not an unimported second test suite.
Additional cases already authored in the existing oracle, helper, corpus and
conditional owners were examined against their branches. This is a source-to-
fixture coverage audit, not an instrumented 100% branch-coverage claim or a
universal equivalence proof.

| Source family / interaction | Concrete fixture owners and additions |
| --- | --- |
| `next_sym`, comment/string/character/number/float scanners, token mapping | `lexer_golden` includes every byte; `boundary-string-*`, `boundary-char-*`, `boundary-number-*`, `boundary-comment-*`, whitespace/CRLF/error spans and NUL/high-byte/trailing-input cases add public interactions. |
| Name/path/operator predicates and precedence tiers | `name_golden`, `path_golden`, `pattern_golden`, `expr_golden`; deterministic binary products plus 16 `boundary-mixed-operators-*`; exact operator renaming/rejections and conditional/tuple controls in `limits_golden`. |
| Type lists/products/functions, constructor/record metadata and exceptions | `type_golden`, `ctor_golden`, `record_golden`, `typedefs_golden`, `exception_golden`, `recordprep_golden`; declaration controls preserve sorting/order, duplicates, nonrec and mixed-group rejections. |
| Pattern alias/or/cartesian distribution, currying and record restrictions | `pattern_golden`, inherited cases, generated fun/match/let products; `candlehelper_golden` directly checks guards, record helpers and wildcard/letrec packaging. |
| Every `ptree_Expr` syntactic family and binding/match/list/index/update helpers | `expr_golden` includes assert/lazy, both for directions, while, annotations, guards and malformed constructs; inherited array/string indices; new `coverage/typed-*`, `coverage/array-update`, `coverage/string-update`, `coverage/empty-begin`, `coverage/if-unit-else`. Rejections remain expectations, not missing support to fix. |
| Module/signature/item/ascription grammar and lowering | Existing Queue/Buffer modules, signature/path/unit fixtures and module-functor rejection; new `coverage/module-*` and `coverage/signature-*` cover alias/empty/expression bodies, parenthesized/path/ascribed module types, all seven signature-item alternatives, semis, one/two functor applications and malformed signatures. |
| Complete-input/start behavior, multiple declarations, truncation and unsupported extensions | Existing empty/trailing/missing-binding controls; new `coverage/semis-only`, `coverage/multiple-expressions`, quotation/directive rejection; `boundary-eof-or-trailing-*`. CML-bearing success expectations remain explicitly excluded; reached pragmas have separate exact unsupported-feature tests. |
| Size/nesting and call independence | Bounded parentheses (1/4/8), lists (1/2/3), identifiers (1/16/64), repeated-call public checks, six frozen real corpus inputs. These are bounded robustness evidence, not unbounded stack/performance guarantees. |
| Framing versus evaluation safety/recovery | 46 strict frame checks, 18 interruption injections and 26 real integration sessions, including no-prefetch malformed escapes, stale-effect prevention, pre-check rejection, rollback, shadowing and real SIGINT. |

The audit adds 33 named `coverage_controls()` inputs beyond the 147 boundary
inputs, so the expanded set is **892**, and the hidden public set **972**.
Their fresh independent expectations pass. The in-scope comparison total is
2,012, with 597 expanded successes and 295 exact failures.
No malformed internal parse tree can be supplied through the public API;
existing direct-helper/hand tests retain selected internal shape checks without
adding a second fuzzing/coverage framework.

## Public bundle, private layers and count gates

`python3 tools/run_tests.py --suite public` loads the hidden public bundle.
Its expected count is 972: 60 initial + 892 expanded + two records/boot inputs
+ 18 additional corpus/conditional cases. These repeat the public portions of
the layer campaign, not new expectations. Only the public parser API, Basis and
Ast are used. Exact hand AST/error, repeat-call and runtime-contract checks
also run.

`python3 tools/test_bundle.py` loads through `#use` in a fresh REPL. All
18 private helper structures must be undefined; the identity AST, public error
constructor patterns and distinct unknown/EOF markers must still work. Exports
are restricted to `parse`, the error-location constructors and the REPL's
generated `pp_locn`/`pp_locs` printers. The second test checks that
`--internals` preserves the development source sequence.

The `lexer`, `grammar`, `conversion` and `candle` entry points load
individual in-scope modules. The preserved `cakelexer`, `cakegrammar`,
`cakeconversion` and `all` paths retain the old location ABI and are deferred,
not current M7-supported commands. Do not use their historical passes as current
acceptance evidence.

The Candle-only campaign's expected comparison counts are:

| Group | Comparisons |
| --- | ---: |
| Lexer/grammar/name/type/pattern/metadata layers | 615 |
| Full expressions | 134 |
| In-scope declarations | 50 |
| Initial public parser results | 60 |
| In-scope inherited HOL tests | 210 |
| Expanded public wrappers/products/mutations/boundaries/controls | 892 |
| Direct lowering helpers | 31 |
| Six real corpus inputs | 6 |
| Conditional/tuple/precedence controls | 14 |
| **Total** | **2,012** |

All these count gates and exact comparisons pass on the current M6 runtime.
The September baseline was 1,832 comparisons with 712 expanded cases and a
792-comparison public subset. Counts overlap layer/public views and selected
regressions; neither total counts distinct programs. Equality compares complete
AST values inside CakeML, including annotations, generated identifiers, binary
products, locations, operators and declaration order. Strings are exact byte
strings; printing/truncating ASTs is not the equality oracle.

All 214 active `camlTestsScript.sml` calls are accounted for: 210 in scope,
four named pragma exclusions. Original declaration/public fixtures retain all
64/76 results; their drivers exclude 14/16 pragma-bearing inputs and assert the
scope counts. Original CML expectations are not rewritten to match the
candidate's unsupported-feature result. Reached pragmas have separate exact
candidate-error tests.

The frozen corpus comprises raw records, a boot projection, complete fib/streams
regressions and pinned HOL Light lib/basics excerpts. The boot projection replaces
exactly two known CML blocks with spaces/newlines, preserving locations; it is
not raw-boot compatibility or an interactive preprocessor. Snapshot hashes and
excerpt boundaries are in [corpus/README.md](corpus/README.md). Corpus goldens do
not execute those programs. This is not whole-HOL-Light, quotation or Flyspeck
acceptance.

## Strict harness and negative controls

Every normal run requires zero process status, a separately printed completion
marker and no unexpected diagnostic lines. Intentional reader errors assert the
exact trace/count and a recovery/effect marker. Diagnostic-looking text inside
a fixture's printed string value is data, not a runtime error. Harness units
cover this distinction, missing completion markers and zero-exit failures.

Run both full-public negative controls after the positive campaign:

```sh
python3 tools/run_tests.py --suite public --test tests/parser_negative.cml
python3 tools/run_tests.py --suite public --test tests/error_negative.cml
```

Each must exit 1 with exactly its named assertion failure
(`negative/changed-identifier` or `negative/changed-error-location`),
propagated `EXCEPTION: <exn>`, outer REPL exit zero and printed final
`CANDLE_PARSER_TESTS_OK` marker. A load/compile failure is not a valid negative
control. Both full-public runs satisfy this on the current runtime. The
original lexer/harness controls also fail for their intended assertion only:

```sh
python3 tools/run_tests.py --suite lexer --test tests/lexer_negative.cml
python3 tools/run_tests.py --suite lexer --test tests/harness_negative.cml
```

## Independent fixture regeneration

Normal loading/testing requires no HOL checkout. Regeneration needs a matching
external CakeML/HOL reference; see [../STANDALONE.md](../STANDALONE.md) and
`CAKEML_ROOT`. Original manifest/donor paths are provenance, not runtime
dependencies. Check all current reference hashes in `SOURCES.tsv` before
regenerating and record deliberate baseline changes.

The five existing executable oracle owners evaluate only original HOL
definitions, never candidate source. After generating inputs, use the HOL4
tool to build the named `m7-oracles` target in `tools/`, following the HOL4
skill. Require terminal success before extracting any fixture. This groups the
existing core, expanded, helper, corpus and limits owners; no compiler/bootstrap
build or new exporter is needed.

```sh
python3 tools/expand_cases.py > tools/expanded_cases.sml
python3 tools/corpus_inputs.py > tools/corpus_cases.sml
python3 tools/limits_inputs.py > tools/limits_cases.sml
# Build the named m7-oracles target through the HOL4 tool, then extract:
python3 tools/extract_goldens.py tools/.hol/logs/candleExpandedOracleTheory --kind inherited --count 210 > tests/inherited_golden.cml
python3 tools/extract_goldens.py tools/.hol/logs/candleExpandedOracleTheory --kind expanded --count 892 > tests/expanded_golden.cml
python3 tools/extract_goldens.py tools/.hol/logs/candleHelpersOracleTheory --kind candlehelper --count 31 > tests/candlehelper_golden.cml
python3 tools/extract_goldens.py tools/.hol/logs/candleCorpusOracleTheory --kind corpus --count 2 > tests/corpus_golden.cml
python3 tools/extract_goldens.py tools/.hol/logs/candleLimitsOracleTheory --kind limits --count 18 > tests/limits_golden.cml
```

For the core owner, use `tools/.hol/logs/candleParserOracleTheory`:

| Extractor kind / required count | Fixture |
| --- | --- |
| lex / 324 | lexer_golden.cml |
| tree / 12 | tree_golden.cml |
| parse / 76 | parser_golden.cml |
| name / 66; path / 22; type / 21; literal / 13 | corresponding *_golden.cml |
| pattern / 50; record / 10; ctor / 13; typedefs / 21 | corresponding *_golden.cml |
| exception / 10; unit / 16; recordprep / 37 | corresponding *_golden.cml |
| expr / 134; decl / 64 | corresponding *_golden.cml |

For example:

```sh
python3 tools/extract_goldens.py tools/.hol/logs/candleParserOracleTheory --kind pattern --count 50 > tests/pattern_golden.cml
```

The 2026-10-03 expanded regeneration retained completed independent outputs
across two user-requested cancellations. Depth-32 parentheses became depth
four; 16/64-element list controls became two/three elements. No retained input
changed. The final 53-input resume succeeded in 38 seconds; the combined
892 public name/source pairs and 210 inherited cases were checked against the
canonical full generator inventory before extraction. The full input library
is restored. Local recovery logs are in `build/oracle-resume/`; normal tests
depend only on the stored fixtures, not these logs or HOL. The per-case
reference-evaluation cap is 20 minutes.

The core owner also preserves deferred outputs `cakelex/294`,
`cakegrammar/240`, `cakeconversion/172` and `cakehelper/45`; these do not
expand M7's scope. Extraction rejects missing counts/incomplete lines.
The serializer rejects unevaluated or unmapped HOL values, uses three-digit
decimal escapes for bytes, and preserves right-associated binary products
inside Ast while keeping private metadata tuples flat. Error locations are
qualified by `CandleLocation` for private layers and `CandleParser` for public
results; Ast annotations remain distinct. PEG error-field projections are
evaluated explicitly rather than unfolding the whole grammar map.

Expression fixtures include 102 active inherited expression calls plus 32
curated cases. Declaration fixtures include 40 active declaration/start calls
plus 24 curated cases; these also contribute the original public wrapper cases.
Inherited and direct-helper fixtures use named `unit -> bool` closures solely
to handle heterogeneous result types; each expected payload is a full HOL
constructor value. Only the actual side invokes a candidate helper.

## Reference quirks and limits

Preserve reference behavior rather than fixing it inside the port:

- `or` maps to `"|"`; `!=` lexes but operator-name conversion rejects it.
- Single-letter uppercase constructor/module names fail the reference's
  `identUpperLower` convention.
- Floats retain their token/location behavior but are not ordinary grammar literals.
- Only top-level record patterns survive; nested records fail. Known Basis/Candle
  constructor currying differs from normal OCaml tuple packaging.
- Type metadata can retain mixed groups/duplicate record fields that final
  declaration lowering rejects. Metadata success is not public-parser acceptance.
- `partition_types` uses the reference's reversing partition; record sorting
  and generated declaration order are compared exactly.
- For/while lowering uses the existing free/eager helper applications. Runtime
  characterization does not invent bound/thunked helpers to repair it.
- Conditional/tuple controls characterize the locally documented #1019 limitation,
  not a compatibility fix or verified verbatim issue-body examples.

CML conversion, interactive file loading and quotation expansion remain excluded.
The finite campaign is strong compatibility evidence, not a universal parser
equivalence proof, full branch-coverage measurement or unbounded robustness claim.
JUrban fixes, optimization and bootstrap parser retirement are separate work.
