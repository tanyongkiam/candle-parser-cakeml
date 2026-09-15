# Current layer tests

All commands below run from this project's root (the current `parse/`
directory), not the enclosing CakeML checkout. Stored-golden tests need no
upstream sources or HOL installation. `make test` runs the complete recommended
check: three harness unit tests, two bundle tests, the public bundle suite and
all existing layers, sequentially to avoid competing large REPL heaps.

## Public bundle and private layers

`python3 tools/run_tests.py --suite public` loads the default generated
`local ... in ... end` bundle and compares 792 stored public results: 60 initial,
712 expanded, two records/boot and 18 additional corpus/conditional cases.
These repeat existing vectors, not new expectations. Public tests use only
`CandleParser.parse`, the Basis and Ast; pragma filtering does not call a private
lexer. Exact hand AST, error, repeat-call and runtime-contract checks also run.

`python3 tools/test_bundle.py` loads a temporary generated file through `#use`
in a fresh REPL. Opening each of the 17 private helper modules must produce
exactly the expected undefined-module diagnostic; the public identity check
must still pass. The only Candle export printed at loading is `CandleParser.parse`.
The second test checks that `--internals` retains the original source sequence.

Existing `lexer`, `cakelexer`, `cakegrammar`, `cakeconversion`, `grammar`,
`conversion`, `candle` and `all` suites keep their individual-module load paths
so every layer remains testable. To test deliberate AST mismatch through the
hidden bundle, run `python3 tools/run_tests.py --suite public --test
tests/parser_negative.cml` (one command); it must exit nonzero.

HOL oracle regeneration is optional. See [../STANDALONE.md](../STANDALONE.md)
for `CAKEML_ROOT` and reference checkout requirements. Source paths in the
original manifest and donor notes are provenance, not local test dependencies.

## Candle-only implementation (2026-09-16)

The pure public parser is implemented. The current task defers embedded CakeML;
use the **18-source-file** Candle suite, which does not load `cake_*.cml`:

```sh
python3 tools/run_tests.py --suite candle
```

The default executable is `cake-ast-parse-ident` with the matching active
configuration. The runner fails on REPL diagnostics or a missing final sentinel,
not just process status. The expression driver compares all 134 stored cases.
The declaration/public driver retains the original fixtures but explicitly skips
inputs containing a lexed `PragmaT`, printing the in-scope counts on a verbose
run. Independent checks cover identifiers, lambdas, public ASTs, empty/repeated
calls and the deliberate located unsupported-pragma error. The pragma span is
the reference lexer's span, which is not the physical closing column.

The initial full-parser suite passed **859 reference comparisons**: 615 earlier
Candle layer cases, 134 expressions, 50 declarations and 60 public-parser cases.
The separate negative-control invocation failed on the deliberately changed
identifier as required. Fourteen declaration and sixteen public pragma-bearing
vectors remain preserved but excluded; the driver checks these scope counts.

Harness regression: the boot corpus contains the literal text `Compilation
interrupted`. The former substring scan falsely treated its printed string value
as a diagnostic. The runner now matches actual diagnostic lines (allowing REPL
prompts), and requires the completion sentinel on its own printed line.
`harness_literals.cml` and `python3 tools/test_harness.py` test this
distinction; the deliberately wrong-AST invocation still must fail.

Real corpus preparation: `tools/corpus_inputs.py` retains the records file raw
and replaces exactly the two known CakeML pragma blocks in the frozen boot copy
with spaces/newlines. It asserts the exact block contents/count, rather than
implementing a new interactive preprocessor. The resulting boot projection is
not claimed to be raw-boot compatibility. Both exact input strings are stored in
`tools/corpus_cases.sml`. Both complete results now compare exactly against HOL
(20 and 42 declarations). Oracle job `c54b26f3` completed successfully, and
`corpus_golden.cml` is included in the normal suite. No boot declarations or
file-loading code were executed.

The recursive-binding/datatype fixture representation was corrected after
testing against the exported `Ast` types: AST products require nested pairs,
not flat native triples. `tools/oracle_support.sml` now distinguishes AST fields
from port-private tuples; `expr_golden`, `decl_golden` and `parser_golden` were
regenerated independently in successful oracle build `afc19b02`. This changed
serialization only, not the reference parser or candidate semantics.

Expanded testing now passes: `tools/expand_cases.py` extracts 214 active
inputs from `compiler/parsing/ocaml/camlTestsScript.sml` (including the type-test
helpers and expected failures), and creates 712 public inputs. The latter include
184 wrapped inherited cases, 264 finite-product cases, and 264 deterministic
mutations. No random seed or candidate-generated expectation is involved.
`expanded_cases.sml` stores the exact inputs and original source locations.
`candleExpandedOracleScript.sml` evaluates the original HOL parser and converters.
Pragma exclusions are printed explicitly: four inherited cases are deferred,
leaving 210 comparisons. Oracle build `cb989c16` completed successfully and all
210 layer + 712 public cases compare exactly in a fresh REPL. Public outcomes
are 475 successes and 237 failures. The **1,781-comparison** Candle suite now
includes `inherited_golden.cml`, `expanded_golden.cml` and their driver by default.
These counts include deliberately overlapping layer/public views and previously
selected regressions; they are not a claim of 1,781 distinct source programs.

The direct lowering suite adds **31 passing goldens**, generated by successful
`candleHelpersOracleTheory` build `e3ac3285`: operators, annotated/qualified
`raise`, records (including duplicate input fields), lambdas, recursive binding
ABI, let variants, guard closures, handlers, and generated record functions.
`candlehelper_golden.cml` and `candle_helpers.cml` are now included normally.
The final corpus/limitation suite adds **20 passing goldens**: the records and
boot inputs above, four raw local corpus snapshots, and 14 conditional/precedence
controls. Successful oracle job `935b571e` generated `limits_golden.cml` using
the frozen original parser, not the later JUrban behavior. All six corpus inputs
succeed. Ten conditional controls succeed and four fail exactly as the reference.
`corpus.cml` runs both fixtures and asserts their counts.

**Current total: 1,832 Candle reference comparisons**, 18 source files and 34
test files, plus the separate three Python harness checks and negative control.
The additional corpus's byte hashes, complete-file/excerpt boundaries and local
provenance are in [corpus/README.md](corpus/README.md). These are finite exact-AST
comparisons, not whole-HOL-Light or raw-boot acceptance claims.

Regenerate the two additional fixtures only after successful named builds of
`candleCorpusOracleTheory` and `candleLimitsOracleTheory` in `tools/`:

```sh
python3 tools/corpus_inputs.py > tools/corpus_cases.sml
python3 tools/limits_inputs.py > tools/limits_cases.sml
# Run the named HOL oracle builds after generating inputs, then extract:
python3 tools/extract_goldens.py tools/.hol/logs/candleCorpusOracleTheory --kind corpus --count 2 > tests/corpus_golden.cml
python3 tools/extract_goldens.py tools/.hol/logs/candleLimitsOracleTheory --kind limits --count 18 > tests/limits_golden.cml
```

```sh
python3 tools/extract_goldens.py tools/.hol/logs/candleHelpersOracleTheory --kind candlehelper --count 31 > tests/candlehelper_golden.cml
```

Negative control (must fail with `TEST_FAILED: negative/changed-identifier`):

```sh
python3 tools/run_tests.py --suite candle --test tests/parser_negative.cml
```

The historical sections below describe the earlier implemented-layer suite.
Their statements that expression/declaration fixtures are disabled are superseded
by this section; their embedded CakeML coverage remains preserved, but optional.

Expanded regeneration route (after a **successful, complete** named HOL build):

```sh
python3 tools/expand_cases.py > tools/expanded_cases.sml
# Build candleExpandedOracleTheory in tools/ using HOL4.
python3 tools/extract_goldens.py tools/.hol/logs/candleExpandedOracleTheory --kind inherited --count 210 > tests/inherited_golden.cml
python3 tools/extract_goldens.py tools/.hol/logs/candleExpandedOracleTheory --kind expanded --count 712 > tests/expanded_golden.cml
```

The generated driver inputs are SML, not candidate results. The inherited fixture
contains equality closures solely to accommodate the differing converter result
types; each expected result is a complete independently serialized HOL value.
Four original pragma inputs are excluded by the expanded oracle with named log
entries. `tests/expanded.cml` enforces the two counts and compares every result.

Deferred coverage is tracked explicitly in [../TEST_GAPS.md](../TEST_GAPS.md).
It distinguishes completed Candle gates from user-deferred CakeML vectors.
`Ast.Ident` is usable in `cake-ast-parse-ident`; its runtime-contract checks are
included in both `candle` and `all`. The `all` suite also covers preserved legacy
layers; it does not claim a complete embedded CakeML parser.

From this project root (the current `parse/` directory):

```sh
python3 tools/run_tests.py --executable cake-ast-parse-ident --suite all
```

The current suite contains 1,366 independently generated reference cases:

| Layer | Cases | Coverage |
| --- | ---: | --- |
| Lexer | 324 | Every single byte, comments, pragmas, escapes, numbers, capitalization, whitespace, lexical errors and exact locations |
| Whole-input grammar/tree | 12 | Exact trees, remaining-input rejection and error values for initial declaration/pragma/failure cases |
| Names/operators | 66 | Name categories, reserved operators, compatibility renaming, rejected names/operators |
| Qualified paths | 22 | Nested modules and renamed modules/constructors, malformed qualification |
| Types | 21 | Variables, constructor application, products, right-associative arrows, malformed/trailing input |
| Literals | 13 | Integers/bases, characters/escapes, byte strings, rejected alternatives |
| Patterns | 50 | Lists, tuples, constructor currying, or-pattern distribution, alias precedence, annotations, record-pattern restrictions, failures |
| Record metadata | 10 | Field types/order, trailing semicolons, duplicate fields, malformed records |
| Constructor declarations | 13 | Nullary/tuple/record arguments, compatibility renaming, malformed declarations |
| Type-definition metadata | 21 | Parameters, abbreviations, variants, recursive groups, abstract types, failures |
| Exception ASTs | 10 | Exact locations/tuple packaging, forbidden records and abbreviations, syntax failures |
| Signature validation helpers | 16 | Exception/val type specifications and open/include paths, including rejections |
| Embedded CakeML lexer | 294 | Every byte, qualified identifiers, numeric/word literals, escapes, FFI token syntax, comments, malformed strings and complete-tail retention |
| Embedded CakeML grammar | 240 | Every one of the 70 executable rule entry points; exact trees, leftovers, failure and retained-success errors; precedence, applications, tuple/sequence node shapes, constructor patterns, types, declarations, signatures and qualified opens |
| Embedded CakeML conversion | 172 | 26 converter functions: names/operators/paths, types and type lists, type names, constructor/datatype groups, exact type-abbreviation ASTs, optional type equations, signature validation, literals/words/FFI expressions |
| Lowering helpers | 45 | Sequencing, annotation stripping/merging, `Ref`/constructor/FFI/function application, pattern binding, constructor classification and reference patterns |
| Record preparation | 37 | Reversed partition groups, record sorting including duplicate names, field-name extraction and tuple packaging |

Twenty-five additional hand-written layer checks cover path renaming, function-type
associativity, or-pattern distribution, wildcard currying, record restriction,
repeated-call independence, constructor tuple packaging, retained field order,
deferred duplicate-field validation, and three embedded-lexer checks (no final
semicolon, incomplete-tail retention, qualified-token shape). Three embedded
grammar checks cover an empty tree, malformed-prefix retention, and direct-token
EOF failure. Six conversion checks cover arrow associativity, unchanged CakeML
constructor names, tuple arguments, absent type equations, retained duplicate
constructors and malformed-tree rejection. Four more checks cover application/
annotation behavior, record sorting/tuple packaging, and partition reversal.
`runtime.cml` checks existing AST values and the result type; `expression_runtime.cml`
checks the `Ast.Ffi` and `Ast.Word64` exports. These test layers, not a completed `CandleParser.parse` API.

`--suite lexer`, `--suite cakelexer`, `--suite cakegrammar`, `--suite cakeconversion`, `--suite grammar`, and `--suite conversion` select smaller
suites. Conversion tests include the initial grammar/tree checks. Each run
starts a fresh REPL and fails on error diagnostics, a nonzero exit, or a missing
final marker. The runner decodes non-UTF-8 diagnostic bytes with backslash
escapes, because CakeML strings are byte strings. Equality is computed inside
CakeML; its pretty-printer is not the equality oracle.

Both negative controls were verified to fail, even though the REPL itself
continued to the final marker and exited zero:

```sh
python3 tools/run_tests.py --executable cake-ast-parse-ident --suite lexer --test tests/lexer_negative.cml
python3 tools/run_tests.py --executable cake-ast-parse-ident --suite lexer --test tests/harness_negative.cml
```

## Independent fixture regeneration

The executable-only `tools/candleParserOracleScript.sml` evaluates the original
HOL lexer, PEG and AST conversion functions. It never loads candidate source.
Use the HOL4 tool to build the named `candleParserOracleTheory.dat` target in
`tools/`, following the HOL4 skill when using an agent, and require build success. The latest
successful generation was job `6c726ceb` on 2026-09-15. Core reference hashes
were checked against `SOURCES.tsv` and still matched.

Extract a group from `tools/.hol/logs/candleParserOracleTheory`, for example:

```sh
python3 tools/extract_goldens.py tools/.hol/logs/candleParserOracleTheory --kind pattern --count 50
```

This prints the complete `pattern_golden.cml` source. Replace that generated
fixture with the output. Other kind/count pairs are `lex/324`, `tree/12`,
`parse/76`, `name/66`, `path/22`, `type/21`, `literal/13`, `record/10`, `ctor/13`,
`typedefs/21`, `exception/10`, `unit/16`, `cakelex/294`, `cakegrammar/240`, `cakeconversion/172`, `cakehelper/45`, and `recordprep/37`. A wrong count fails
instead of silently accepting a partially generated fixture. The exporter uses
three-digit decimal escapes for non-printable bytes and rejects unevaluated or
unmapped HOL values. The layer oracle evaluates the grammar's error-field
projections explicitly; otherwise specialized PEG compute rules leave those
projections unevaluated in some rejected-input cases.

Deferred expression fixtures are regenerated with `--kind expr --count 134`.
They contain 102 active `ptree_Expr` test inputs from `camlTestsScript.sml`
(including its `nENeg` entry and an expected syntax failure), plus 32 curated
variable/control-flow/malformed-input cases. Source line references and exact
SML input strings are retained in the oracle driver. The expected values come
from fresh HOL evaluation with full locations; the original test file's
location-insensitive expected-AST assertions were not run by this export.

Deferred declaration fixtures use `--kind decl --count 64`: 40 active
`ptree_Definition`/`ptree_Start` inputs from `camlTestsScript.sml` and 24 curated
record/type/recursive-binding/module/pragma/failure cases. The same 64 inputs
are also evaluated directly by `caml_parser.run`, bringing `parse/76` to 76
stored public-parser results. Definition-only inputs gain a `;;` terminator
for the public wrapper. These are overlapping coverage, not additional unique
inputs. Declaration-layer results retain full locations and strict outer
input consumption; embedded CakeML retains its reference prefix behavior.

`cake_conversion_support.cml` defines a test-only tagged value type so one
fixture can compare heterogeneous converter results without printing or
normalizing ASTs. The payloads are the existing `Ast` values, not a replacement
parser AST. This suite tests conversion of grammar-accepted prefixes, matching
the embedded path; exact leftover-token behavior is checked separately by the
grammar suite. The oracle explicitly instantiates each generic converter's
tree/location type before applying it to the reference parse tree.

`cakehelper_golden.cml` and `recordprep_golden.cml` store generated comparisons
as named `unit -> bool` closures. Each contains the full arguments and expected
constructor-valued result obtained from HOL; only the actual side calls the
candidate helper. The word64 serializer uses `Word64.fromInt` for fully evaluated
64-bit word constants. The exported FFI constructor is spelled `Ast.Ffi`.

## Known reference behavior, not fixes

- `or` maps to the operator name `"|"`; `!=` is accepted as an operator token but
  its operator-name conversion fails.
- Single-letter uppercase names are not constructor/module names under the
  reference's `identUpperLower` convention. Both rejected and valid qualified
  names are kept in the suite.
- Some malformed embedded CakeML pragmas produce an empty declaration list.
  The initial full-parser fixtures record this, but complete embedded AST
  conversion has not yet been ported or end-to-end tested.
- Floats have their existing token/location behavior but are not accepted as
  ordinary literals by the grammar tested here.
- The embedded CakeML path uses the raw lexer, not `lex_impl_all` or the
  interactive phrase splitter. Unterminated final phrases are retained as
  tokens. The grammar tests confirm that some malformed tails remain unconsumed
  on success; `pegexec.destResult` does not reject them. The subsequent embedded
  AST conversion and end-to-end pragma tests are still pending.
- Only top-level record patterns survive conversion; nested records fail with
  the original error. Basis/Candle constructor currying is not normal OCaml
  tuple packaging.
- Type-definition metadata is not final declaration lowering. Mixed recursive
  abbreviation/datatype groups and duplicate record fields are retained in
  metadata here; their later rejection in `ptree_TypeDefinition` is now
  implemented and tested. Passing metadata-only tests does not claim those
  full-source inputs are accepted by the public parser.
- `partition_types` uses HOL's reversing `sorting.PARTITION`, not a stable
  partition. The final type-definition converter reverses its input first.
  Regression tests cover both abbreviation and datatype group order; duplicate
  record fields retain the reference sorting order before later rejection.

`parser_golden.cml`, `expr_golden.cml`, and `decl_golden.cml` are active for
all in-scope cases, as detailed above. `ast_contract.cml` is also active: the
new executable passes actual `Ast.Ident`
construction/equality tests. Pattern tests containing the source text `Var _`
construct `Ast.Pcon`, not variable expressions.

The 76 public-parser, 134 expression and 64 declaration vectors remain stored;
60, 134 and 50 respectively are compared. Only the pragma exclusions remain.
Inherited HOL integration and generated/mutated testing are complete. Current
corpus and performance gates are tracked in `../TEST_GAPS.md`; embedded CakeML
conversion is user-deferred, not an unfinished gate for this Candle-only port.
