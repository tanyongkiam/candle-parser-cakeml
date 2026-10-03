# Implementation layers and provenance

The source is a hand-written port of executable definitions, not mechanically
exported source or a line-for-line transcription. Most converter names and
branches follow HOL, but the structural adaptations below must be considered
when comparing implementations. Original sources remain read-only; their
baseline paths and hashes are recorded in [../SOURCES.tsv](../SOURCES.tsv).
No public AST datatype is redeclared.

## Load order

Current fresh-REPL load order:

The default `tools/load_parser.py` output (or `make bundle` at the project
root) encloses the first 17 files in `local`, exports only `parser.cml` in
the `in` branch, and closes with `end`. `CandleParser.parse` and its
error-location types/constructors are public; implementation modules stay hidden.
Use `--internals` or individual source files for layer debugging; all existing
layer suites intentionally retain that development path. `--suite public`
checks the hidden bundle independently, and `tools/test_bundle.py` checks
that every helper module really is inaccessible after fresh `#use` loading.

1. `support.cml`, `tokens.cml`, `lexer.cml`
2. `peg.cml`, `tree.cml`, `grammar_support.cml`, `grammar.cml`, `front_end.cml`
3. `conversion_support.cml`, `names.cml`, `types.cml`, `precedence.cml`, `patterns.cml`
4. `type_declarations.cml`
5. `expression_support.cml`, `expressions.cml`, `declarations.cml`, `parser.cml`

The above **18 files** are the Candle-only implementation. `CandleParser.parse`
is implemented. The current Ast/error-location migration passes 2,012 exact
independent-reference comparisons and comprehensive current-runtime integration
tests; September's 1,832-comparison suite is historical. The user deferred
`(*CML ... *)`, which returns `CandleDeclarations.pragma_error` at its parse-tree
location. This deliberate exception is the only planned behavior change.

The following preserved layers are optional/deferred, not Candle dependencies:

5. `cake_tokens.cml`, `cake_lexer.cml`, `cake_grammar.cml` (embedded CakeML front end)
6. `cake_conversion.cml` (embedded CakeML non-expression conversion)
7. `cake_expression_support.cml` (literal/application/location helpers)
8. `cake_patterns.cml` (written before scope reduction; not yet runtime-tested)

## Source-to-reference map

Every implementation file currently in `src/*.cml` has its own row
below. Port files are linked and original-source paths are given; use the named
definitions to locate the relevant code without relying on line numbers.
Original-source pointers use `CakeML:` and `HOL:` paths relative to those
external checkouts. They are provenance, not dependencies of normal loading or
testing. Resolve them using [../SOURCES.tsv](../SOURCES.tsv) and the optional
checkout configuration in [../STANDALONE.md](../STANDALONE.md).

This maps the implemented subset, not every definition in each source theory.
Final Candle type/declaration lowering is now in `declarations.cml`; the metadata
layer remains in `type_declarations.cml`.
Multiple links in a row identify split provenance, not alternate references.
Test/oracle drivers are new testing code, not parser ports; copied boot/runtime
assets have their own provenance in the manifest and
[../runtime/README.md](../runtime/README.md).

| Ported file | Original source file(s) | Definitions / scope |
| --- | --- | --- |
| [support.cml](support.cml) | `HOL: examples/formal-languages/context-free/locationScript.sml`; `CakeML: semantics/lexer_funScript.sml`; `CakeML: compiler/parsing/ocaml/caml_lexScript.sml` | Parser-owned `locn`/`locs`, `unknown_loc`, location ordering/merging; `next_loc`, `next_line`, `init_loc`; `take_while`. Other list, numeric and character helpers are local adapters for the operations used by these sources, not a separate copied HOL module. |
| [tokens.cml](tokens.cml) | `CakeML: compiler/parsing/ocaml/caml_lexScript.sml` | `token`, `get_token`: Candle token vocabulary and reserved spellings. |
| [lexer.cml](lexer.cml) | `CakeML: compiler/parsing/ocaml/caml_lexScript.sml` | Executable scanners, `next_sym`, token conversion and `lexer_fun`; `lex` is the port's native-string wrapper. |
| [peg.cml](peg.cml) | `HOL: examples/formal-languages/context-free/pegexecScript.sml`; `HOL: examples/formal-languages/context-free/pegScript.sml` | Continuation/state datatypes, error selection, `coreloop`, `peg_exec`; PEG symbol constructors. See the loop/interface adaptation below. |
| [tree.cml](tree.cml) | `HOL: examples/formal-languages/context-free/grammarScript.sml`; `HOL: examples/formal-languages/context-free/locationScript.sml`; `CakeML: compiler/parsing/ocaml/camlPEGScript.sml` | `parsetree`, `ptree_loc`, `real_fringe`; location merging; `mkNd`. Restricted to token leaves as explained below. |
| [grammar_support.cml](grammar_support.cml) | `CakeML: compiler/parsing/ocaml/camlPEGScript.sml` | `sumID`, tree-building and grammar combinators, token predicates, operator/name predicates. Native helpers wrap the port's PEG constructors. |
| [grammar.cml](grammar.cml) | `CakeML: compiler/parsing/ocaml/camlPEGScript.sml` | Nonterminal datatype and all 129 rule bodies. Original `nFoo` becomes `NFoo`; see vector storage and source chunking below. |
| [front_end.cml](front_end.cml) | `CakeML: compiler/parsing/ocaml/caml_parserScript.sml` | `run_lexer`, `destResult`, and the front-end portion of `run`. `parse_tree` stops before AST conversion; it is not the final public parser. |
| [conversion_support.cml](conversion_support.cml) | `CakeML: compiler/parsing/ocaml/camlPtreeConversionScript.sml`; `CakeML: semantics/cmlPtreeConversionScript.sml` | Sum helpers (`bind`, `choice`, `mapM`, `option`, `fmap`), `list_cart_prod`, `compatCons`, `compatModName`, `destLf`, `expect_tok`, `path_to_ns`, `nterm_of`; the shared `to_locs` AST boundary comes from `cmlPtreeConversion`. Token/identifier extraction is factored locally. |
| [names.cml](names.cml) | `CakeML: compiler/parsing/ocaml/camlPtreeConversionScript.sml` | `ptree_Ident`, name/path converters, `ptree_Op`, `ptree_OperatorName`; local `name` and `op_name` factor repeated cases. |
| [types.cml](types.cml) | `CakeML: compiler/parsing/ocaml/camlPtreeConversionScript.sml` | `ptree_TVar`, `ptree_Type` and its recursive type-list helpers, `ptree_Literal`, `bool2id`, `ptree_Bool`, `ptree_Double`. |
| [precedence.cml](precedence.cml) | `HOL: examples/formal-languages/context-free/precparserScript.sml` | `precparse1` (port name `step`), `precparse`, `isFinal`; machine-record fields become function arguments. |
| [patterns.cml](patterns.cml) | `CakeML: compiler/parsing/ocaml/camlPtreeConversionScript.sml` | `ppat`, `ppat_to_pat(s)`, `compatCurryP`, pattern precedence helpers, `ptree_AsIds`, list/record helpers, `ptree_PPattern`/`grabPairs`, `ptree_Pattern(s)`. |
| [type_declarations.cml](type_declarations.cml) | `CakeML: compiler/parsing/ocaml/camlPtreeConversionScript.sml` | `ptree_FieldDec(s)`, `ptree_Record`, constructor/exception/type metadata converters through `ptree_TypeDef(s)`, `ctor_tup`, `ptree_ExcDefinition`, `ptree_Semis`, `ptree_ValType`, `ptree_OpenMod`, `ptree_IncludeMod`; also `partition_types`, `sort_records`, `MAP_OUTR` (`map_outr`), `extract_record_defns`, `strip_record_fields`. Final type/declaration lowering is in `declarations.cml`. |
| [cake_tokens.cml](cake_tokens.cml) | `CakeML: semantics/tokensScript.sml`; `CakeML: semantics/lexer_funScript.sml` | CakeML `path`/`token` vocabulary; `get_token` reserved-token classification. |
| [cake_lexer.cml](cake_lexer.cml) | `CakeML: semantics/lexer_funScript.sml` | Reachable scanners, symbol-to-token conversion and `lexer_fun`; `read_string` becomes `read_string_rev`; `lex` is the native-string wrapper. Interactive phrase splitting is not ported here. |
| [cake_grammar.cml](cake_grammar.cml) | `CakeML: compiler/parsing/cmlPEGScript.sml`; `CakeML: semantics/gramScript.sml` | Executable grammar/combinators (70 rules); nonterminal vocabulary (75 labels) and predicates. |
| [cake_conversion.cml](cake_conversion.cml) | `CakeML: semantics/cmlPtreeConversionScript.sml` | Token checks, `Long_Short` (`long_short`), `ptree_linfix`, tuple helpers, type/name/path/operator converters, constructor/datatype/type-abbreviation conversion and signature validation. |
| [cake_expression_support.cml](cake_expression_support.cml) | `CakeML: semantics/cmlPtreeConversionScript.sml` | Constructor classification, `Papply` (`papply`), `maybe_handleRef`, `Eseq_encode` (`eseq_encode`), `dest_Conk` (`dest_conk`), FFI/operator recognition, location helpers, `mkAst_App`, `ptree_Eliteral`, `bind_loc`, `letFromPat`. |
| [expression_support.cml](expression_support.cml) | `CakeML: compiler/parsing/ocaml/camlPtreeConversionScript.sml` | `compatCurryE`; `build_binop`, `build_list_exp`, `build_funapp`; record naming/construction/projection/update/match helpers; lambda, let/rec and guarded match/handler lowering; `SmartMat` becomes `smartMat`. |
| [expressions.cml](expressions.cml) | `CakeML: compiler/parsing/ocaml/camlPtreeConversionScript.sml` | Entire mutual `ptree_Expr` family, including binding lists, match rows, expression lists, record updates and indexing. `check_tokens`, `single_patterns`, and `expr_binary` factor repeated checks/clauses without changing error order. |
| [declarations.cml](declarations.cml) | `CakeML: compiler/parsing/ocaml/camlPtreeConversionScript.sml` | `build_rec_funs`, `ptree_TypeDefinition`, `build_dlet`, `ptree_ExprDec`, signature/module converters, `ptree_Definition` family and `ptree_Start`. `distinct` implements `ALL_DISTINCT`. The pragma branch is explicitly unsupported by user direction. |
| [parser.cml](parser.cml) | `CakeML: compiler/parsing/ocaml/caml_parserScript.sml` | `run_parser`/`run` after the existing `CandleFrontEnd.parse_tree`; native-string public wrapper. |
| [cake_patterns.cml](cake_patterns.cml) | `CakeML: semantics/cmlPtreeConversionScript.sml` | Deferred `EtoPat` (`etoPat`), `ptree_OpID`, pattern/list converters, `dePat`, `mkFun`. Written but not yet validated; excluded from normal suites. |
| [reader.cml](reader.cml) | `CakeML: compiler/compilerScript.sml`; framing reference `CakeML: candle/prover/candle_boot.ml` | Optional new I/O adapter, not a parser-definition port and not in `sources.list`. Local `locs_to_string`, `get_nth_line`, `safe_substring`, `find_next_newline` preserve the compiler's formatting. The small new byte-preserving framer omits the boot loader/quotations, tracks strings/chars/comments/blocks/brackets and hands complete original phrases to the public parser. Only `CandleReader.install ()` is exported. Current-runtime framing units, all nine real reader/Eval integration tests and the full independent parser golden campaign pass. |

### Expression/declaration representation details

The runtime's `Ast.Ident` corresponds to HOL `Ident`, also written `Var` through
the existing HOL overload. Parser/error locations use `CandleLocation`;
`CandleParser` re-exports its types/constructors. Only the reference's
`to_locs` boundary converts positioned spans to `Ast.Locs` coordinate pairs,
or sentinel-containing spans to `Ast.Nolocs`. Lexer/PEG/errors and converter
metadata retain their full parser locations. In **exported AST fields**,
HOL products remain nested binary pairs: recursive bindings are `(f,(v,e))`,
and datatype definitions are `(tvs,(name,constructors))`. Port-private converter
metadata keeps its documented native flat tuples. `build_letrec` and final
`Dtype` construction explicitly cross this boundary. The oracle serializer was
corrected to preserve binary pairs within AST constructors; it does not flatten
or normalize AST results to fit the candidate.

`build_lets` takes the final body **first** and binding list second, just as the
reference's `FOLDR` actually does (the HOL formal parameter names suggest the
opposite). Guard closure names, record field sorting, record-pattern lowering,
recursive-value eta expansion and eager loop lowering are preserved. The
reference's missing token checks and typo-bearing errors are also retained.

## Structural adaptations and comparison boundaries

### PEG execution: `peg.cml`

HOL `pegexec.coreloop` uses `OWHILE` and returns a state option. Its separate
`peg_exec` wrapper unwraps `SOME` and maps `NONE` to `Looped`. The port's
`CandlePeg.coreloop` instead runs the same continuation transitions in a local
tail-recursive `loop`, returning a state directly. `execute` supplies the
initial `EV` state with empty stacks and `Done`/`Failed` continuations. Thus
the port's function named `coreloop` is **not** an interface-identical port of
HOL `coreloop`; compare it with the loop plus execution wrapper.

The grammar record becomes a tuple containing rule lookup and the four error
values. Constructor names are capitalized for source syntax. The separate HOL
invalid-stack cases are consolidated into the final `Looped` branch; a missing
rule also returns `Looped` directly. Backtracking still restores saved input
and value-stack tails, and the error/continuation transitions are retained.
This is not a replacement parser algorithm, memoizing packrat parser, or new
depth-limited parser.

There is an important limit to that correspondence: HOL's mathematical
`OWHILE` can denote nontermination by `NONE`. The native recursive loop does
not detect arbitrary cycles; a cyclic user-supplied grammar could diverge.
Explicit invalid states return `Looped`, but this is not a general executable
implementation of `OWHILE`'s nontermination semantics. The target is the two
fixed parser grammars and their reachable executions, not equivalence for all
possible grammars/states. Existing grammar tests are evidence for those paths,
not a proof of termination or general machine equivalence.

### Grammar storage and source chunking

Both [grammar.cml](grammar.cml) and [cake_grammar.cml](cake_grammar.cml) replace
HOL finite-map rule lookup with an immutable `rule_vector` and an explicit
nonterminal-to-index `lookup`. Rule values are constructed at module load, not
on every token or recursive nonterminal call. Compare each `rule_NFoo` body
with the original rule for `nFoo`; ordered choices and sequence order remain
significant. The vector indices must match the accompanying rule-list order.

Candle's 129 rules are packaged into eleven chunks (`chunk_0` through
`chunk_10`: ten groups of twelve rules and one of nine). Repeated
`structure CandleGrammar = struct open CandleGrammar; ... end` declarations
extend the previous structure without redeclaring its nonterminal datatype.
Each chunk returns its already constructed rule list; the final structure
concatenates the chunks in order and builds the lookup vector.

This chunking is port-side loading scaffolding, not a feature of `camlPEG`.
It was introduced while investigating REPL loading failure, before the fixed
bitmap-buffer exhaustion was identified. It did not solve that underlying
problem; the separately rebuilt larger-buffer executable did. The chunking
remains in the current source, but is not claimed to be necessary with the
larger buffer or to improve parser throughput. See
[../runtime/README.md](../runtime/README.md) for the actual diagnosis.

The embedded CakeML grammar uses one rule list rather than Candle's chunking.
It has 70 executable rules and 75 labels: five labels are constructed by other
rules and have no standalone lookup entry. Both grammars use native-string
versions of the reference predicates.

### Scanner and converter refactoring

| Port location | HOL counterpart | Adaptation to check |
| --- | --- | --- |
| `cake_lexer.cml`: `read_string_rev` | `lexer_fun.read_string` | Accumulate decoded characters in reverse, then reverse/implode once. HOL appends to the growing character list. This is an algorithmic optimization, not just a syntax change; escape/error cases and location updates must still agree. |
| `cake_lexer.cml`: `read_while` | `lexer_fun.read_while` | Reuse `take_while`, then combine its result with the reversed incoming accumulator; callers explicitly convert the character list to a string where needed. |
| `conversion_support.cml`: `choice`; `cake_conversion.cml`: `choice`, `guard` | Sum/option alternatives and conditional conversion | Thunk the alternative/guarded branch so strict source evaluation does not compute unused conversions. Preserve the first successful alternative and reference error selection. |
| `conversion_support.cml`: `list_cart_prod` | `camlPtreeConversion.list_cart_prod` | Compute the recursive tail product once outside the map, sharing it across choices. Preserve output order and multiplicity. |
| `names.cml`: `name`, `op_name` | Individual name converters and `ptree_Op` | Factor repeated node checks and token-to-name branches into parameterized helpers/tables. Keep each caller's nonterminal, compatibility renaming, and exact error messages. |
| `cake_conversion.cml`: `node`, token helpers | Repeated checks in `cmlPtreeConversion` | Factor shape checks while retaining option failures and child-conversion order. This is not Candle's located-error API. |
| `precedence.cml`: `step`, `precparse` | `precparser.precparse1`, `precparse` | Pass the machine record's functions as arguments; rename the single-step function to `step`. Retain the stack transitions and successful terminal-state test. |
| `patterns.cml`: `rank`, `tok_action` | `camlPtreeConversion.tokprec`, `tok_action` | Specialize the four fixed precedences, whose options are always `SOME`, into direct rank/associativity checks. Alias reduces first; cons is right-associative; product/or are left-associative. This is not a general precedence-table implementation. |

These changes preserve the reachable results on the declared golden suite.
The Candle path has the bounded benchmark/source audit in
[../BENCHMARKS.md](../BENCHMARKS.md). It does not isolate a speedup from each
adaptation, nor benchmark the deferred CakeML scanner changes.
The Candle lexer's existing reversed string accumulator and both lexers'
non-tail-recursive token-list construction are retained, not new optimizations.

### Representation and naming adaptations

Native strings replace HOL `mlstring` values and selected character-list string
interfaces; scanner inputs still use character lists. Basis fold arguments are
adapted to HOL's argument order. Natural-number subtraction uses saturation
where required, while AST integer literals remain signed.

`tree.cml` restricts HOL's general parse-tree leaf representation to token
leaves: `Lf (TOK token,locs)` becomes `Lf (token,locs)`, with no nonterminal
leaf alternative. The two executable grammars construct token leaves; this is
not an interface-equivalent implementation for arbitrary HOL parse trees.
Nonterminal node labels retain their sum representation, and node locations
and fringes remain part of the comparisons.

Source syntax requires spelling adaptations such as `nFoo` to `NFoo`,
`IntLit` to `Ast.Intlit`, `StrLit` to `Ast.Strlit`, and `FFI` to `Ast.Ffi`.
HOL constructor functions passed as values may need explicit source lambdas.
Existing AST datatypes are always reused. The golden exporter maps variable
expressions to `Ast.Ident`; this is not a rename of the Candle constructor
string `"Var"` or a claim that the old executable supports `Ast.Ident`.

## Behavior retained from the reference

The pattern `Var _` denotes a *Candle constructor pattern* and produces
`Ast.Pcon (Some (Ast.Short "Var")) ...`; it does not construct a variable
expression. Variable-expression tests are restored using the real `Ast.Ident`.

Type/record metadata deliberately retains source field order and duplicate
names; the reference validates/sorts these in the later `ptree_TypeDefinition`
layer. Exception conversion produces `Ast.Dexn`, including original locations
and tuple packaging, and retains rejection of record exceptions/abbreviations.

`type_declarations.cml` also ports `partition_types`, `sort_records`, `MAP_OUTR`
(`map_outr`), `extract_record_defns` and `strip_record_fields`. Partitioning
reverses each output group, matching `sorting.PARTITION`; the final converter
separately reverses its input before partitioning. Do not replace this with a
stable partition.
Record sorting reuses `List.sort` with `String.<`: the Basis translates the same
`mllist.sort`/`mergesort_tail` operation as the reference. Duplicate-name checks
and generated record functions are implemented in the final lowering and tested
by the declaration and direct-helper goldens.

`CakeLexer.lex` retains all input tokens, including unterminated final phrases.
The **reference** `ptree_Definition` CakeML-pragma branch calls `lexer_fun`
directly, then the CakeML `nTopLevelDecs` grammar; it does **not** use
`lex_impl_all` or an interactive phrase splitter. The Candle-only port instead
returns the user-agreed unsupported-feature error; this embedded conversion is
deferred. Those unrelated interactive helpers are not included in the port.
The preserved CakeML scanner uses a reversed private string accumulator to avoid repeated
growing-prefix concatenation; token contents and locations remain reference
outputs, including their existing location-counting quirks.

`cake_grammar.cml` ports all 70 executable rules and 75 node labels from
`compiler/parsing/cmlPEGScript.sml` / `semantics/gramScript.sml`, reusing the
existing PEG engine and tree representation. Rule data is instantiated once;
nonterminal lookup uses an immutable vector. The five labels without executable
rules are only constructed by other rules. Native-string predicates preserve
the source's exact prefix/length conditions and module-path keyword checks.

The embedded grammar returns the raw PEG state, retaining unconsumed tokens and
error information even on success. Its caller must not impose the outer Candle
parser's complete-input check: `ptree_Definition` intentionally converts the
accepted prefix. Independent grammar tests cover all 70 rule entry points.

`CakeConversion` returns the reference's options; it does not import Candle's
located-error conversion helpers or compatibility renaming. It preserves type
variable spellings, constructor argument lists, duplicate declarations and type
abbreviation locations. Signature conversion validates structure and returns
unit, just as the reference does. The node-check helper only factors identical
nonterminal checks; token checks and child-shape failures remain explicit.
Operator classification reuses the grammar's four exported pure predicates.

The literal/application helpers use the actual export spelling `Ast.Ffi`, not
HOL's `FFI`. Word literals use `Word64.fromInt`, preserving modulo-2^64 conversion.
Application lowering preserves the special `Ref` case, FFI argument accumulation,
and reference location rules: stripping nested annotations retains the outer
location, constructor application merges locations only when both are present,
and ordinary function application retains its annotated operands. No helper
executes an FFI operation; all such values are AST data.

All in-scope Candle expression/declaration lowering and the `CandleParser.parse`
wrapper are implemented and exercised by full-AST goldens. Embedded CakeML AST
conversion remains deferred. Tests are finite compatibility evidence, not a
proof of equivalence or a throughput benchmark.

## Verification and maintaining this map

See [../tests/README.md](../tests/README.md) for the independent HOL oracle,
stored fixture groups, exact comparison scope, and commands. The current
passing suite covers the Candle public parser and its implemented layers;
pragma-bearing expectations remain stored but excluded. Open coverage is
tracked in [../TEST_GAPS.md](../TEST_GAPS.md). There is no formal equivalence
proof for this hand-written port.

When adding or changing a port function, record its HOL definition here. If its
name, interface, control flow, representation, or algorithm differs beyond
routine syntax conversion, document that difference and its comparison scope
in the adaptation ledger above. Keep source-hash provenance separate from
behavioral evidence: matching reference hashes identifies the baseline but
does not validate a port.
