# Plan: JUrban compatibility work for the source-loaded Candle parser

Scope update (2026-09-16): the user has deferred `(*CML ... *)` conversion in
the initial port. Its explicit unsupported-feature result is part of the
current Candle-only baseline; do not expand that scope merely to execute this
follow-on plan. Embedded-path items below remain deferred until authorized.

Written 2026-09-16. This remains a follow-on plan, not authorization to apply
compatibility fixes during the faithful port. The updated executable is now
available and Candle implementation/testing has resumed. Read this alongside
[PLAN.md](PLAN.md), not as a replacement for its acceptance evidence. The
faithful Candle-only baseline now has full in-scope golden and corpus coverage
and baseline measurements; this follow-on compatibility work is not implemented.

## Recommended order and behavioral contract

1. Finish the faithful port and its outstanding tests: baseline **B0**.
2. Apply the compatibility batches below, with explicitly reviewed changes to
   accepted syntax and output: corrected baseline **B1**.
3. Execute [PERFORMANCE_PLAN.md](PERFORMANCE_PLAN.md), requiring exact output
   equality to B1. Performance measurement starts at B0; substantial performance
   rewrites follow compatibility, while the code still resembles its donors.

Compatibility and optimization have different contracts. B0 reproduces the
frozen original HOL parser, including its bugs. B1 deliberately changes specific
behaviors. The optimized parser must reproduce B1, not somehow remain identical
to B0 on cases whose meaning or acceptance was corrected. Preserve B0 fixtures
and reference identity; do not overwrite them with candidate-generated answers.

The interface remains pure:

```sml
CandleParser.parse : string -> ((Ast.locs * string), Ast.dec list) sum
```

It remains an ordinary source-loaded module, usable outside a rebuilt CakeML
compiler. No translator rewrite, REPL parser replacement, interactive loader,
quotation expander or #1314 integration is part of these parser changes.
Changes requiring those components must be separately identified, not hidden
inside parsing. No permanent compatibility-mode switch is needed merely to keep
a test baseline: preserve reference artifacts separately.

## Local evidence and provenance

This plan is based on local work, not a fresh online review of JUrban's fork:

- JUrban extraction review (external `cake-dopen/JURBAN-UPSTREAM-REVIEW.md`): donor
  branches, commits, concrete compatibility defects and extraction boundaries.
- Flyspeck intake review (external `cake-dopen/FLYSPECK-CANDLE-UPSTREAM-REVIEW.md`):
  distinguishes parser acceptance, direct execution, runtime support and PFT.
- Completed opens work and extension plan (external `cake-dopen/OCAML-OPENS-PLAN.md`).
- Opens campaign and later triage (external `cake-dopen/OCAML-OPENS-FUZZ-REPORT.md`).
- Core opens port record (external `cake-dopen/DOPEN-PORT.md`), for dependencies only:
  do not propose implementing the core namespace machinery again.

Local source identities inspected:

| Checkout | Identity / use |
| --- | --- |
| `cake-thunks` | HEAD `7e95a26704ee62dbd8c396356e314d8afeb839f2` at planning time. The lexer, Candle grammar/converter and AST hashes still match [SOURCES.tsv](SOURCES.tsv); the manifest, not HEAD alone, defines B0. |
| `../cake-jurban` | Donor stack `8a8926906ec97204eeec961496d191103cda3229`, locally available as `origin/codex/flyspeck-v13-frontend-batch`. |
| `../cake-dopen` | Corrected opens `882c5eaa1383fe0886c25911ae69a250c190869d`; includes, aliases and unit opens `0544d3a1007cf22d131da8674975b47dc8df7f8b`. |

The prior campaign records 900 semantic comparisons passing, 346/400 prepared
corpus inputs parsing, and 149/185 small/donor inputs parsing, with no regression
among historical successes. It also records three large-input no-verdict cases.
These are historical results, not tests of this `.cml` port. The later 33-case
include/alias/unit extension has native-reference and HOL frontend evidence,
but its report explicitly leaves rebuilt-binary validation pending. Preserve
that distinction when reusing it.

The triage of 51 remaining whole-file syntax failures identified independent
blockers including records, floats, tuple parameters/components, `::!`, annotated
recursive binders and semicolon placement. It does not establish that every
other construct in those files works. The prepared corpus masks loader actions,
expands quotations and includes upstream normalizations; it is not raw Flyspeck.

## C0. Establish the usable baseline and test references

- Complete [PLAN.md](PLAN.md) and close the required [TEST_GAPS.md](TEST_GAPS.md)
  items for B0. Passing layer tests alone are not this gate; current counts and
  corpus/performance evidence belong in that tracker.
- Verify actual construction/equality of `Ast.Ident`, and separately the
  existing `Ast.Open`, `Ast.Dopen`, `Ast.Dlocal` and `Ast.Dmod` exports needed for
  compatibility. Their presence in HOL source does not prove runtime exposure.
  Check source-loading capacity in a fresh REPL. Ask for an appropriate user
  executable if a required export is unavailable; do not redeclare AST types.
- Pin the exact donor commits and copy only needed regression inputs into the
  durable `tests/` corpus, recording original bytes, hashes, provenance
  and preprocessing. Do not make the final suite depend on `/tmp` surviving.
- Reuse available evidence from
  the extracted campaign (historical `/tmp/ocaml-opens-baseline.SV53OI`).
  Its `extra.py`, `corpus/`, `small/` and donor cases exist at planning time;
  `/tmp/ocaml-opens-conformance.JIPYHY` supplies the native reference fixtures.
  Reuse execution logic, not old assumptions about executable paths or output
  directories. Never rerun a command that overwrites historical results.
- Use original HOL results for unchanged behavior, corrected `cake-dopen` HOL
  results for opens, and independently reviewed expected ASTs for repaired donor
  cases. A donor's buggy output is not an oracle for the intended correction.
- For shared OCaml forms, use the locally available OCaml interpreter and pin
  its version. HOL Light's default identifier dialect differs from plain OCaml.
  The prior campaign did not build an independent HOL Light/Camlp5 runtime;
  do not imply that oracle exists. Where needed, use its checked-out grammar
  and hand-reviewed cases, marking the weaker evidence explicitly.
- Distinguish the candidate path from the executable's built-in parser. Running
  the original source through `cake --candle` alone does not test the new
  `CandleParser.parse`. Structural tests must call that function. Semantic tests
  must pass its resulting AST to an existing compiler/evaluation test entry point
  (or a separate scoped harness), not reparse the source with another frontend.
  Verify that entry point before scheduling semantic runs; if unavailable, record
  the harness dependency. Do not replace the REPL parser to conceal it, and do not
  relabel historical donor executions as candidate execution evidence.

Exit: a complete callable B0, exact-result regression loop, negative controls,
and a durable corpus with honest oracle classifications.

## C1. Reuse corrected opens/imports before adding more syntax

Port the grammar and conversion delta from `cake-dopen`, not JUrban's original
`fc612c662`/`a5690401e` lowering. Source pointers without line numbers:

- camlPEGScript.sml (external `cake-dopen/compiler/parsing/ocaml/camlPEGScript.sml`):
  `nOpenPath`, `nOpen`, `nELocalOpen`, `nELet`, include/module alternatives.
- camlPtreeConversionScript.sml (external `cake-dopen/compiler/parsing/ocaml/camlPtreeConversionScript.sml`):
  `ptree_OpenPath`, `ptree_Open`, `is_open_definition`, `lower_module_items`,
  `ptree_Expr`, `ptree_Definition`, `ptree_ModExpr` and module-item conversion.
- camlTestsScript.sml (external `cake-dopen/compiler/parsing/ocaml/camlTestsScript.sml`):
  enduring exact-AST and rejection cases, including the later import extension.

Target files: `src/grammar.cml`, `names.cml`, remaining expression/declaration
conversion modules created by B0, and their tests. Update the grammar lookup
and source map together; retain the core AST and existing namespace semantics.

Required behavior:

| Form | Lowering / distinction |
| --- | --- |
| Top-level `open Mod` | Persistent `Dopen` with the reference location/path. |
| Structure-level `open Mod` | Tag source opens separately; lower over the remaining structure suffix using `Dlocal [Dopen ...] suffix`, keeping imports private. |
| `let open Mod in e`, `Mod.(e)`, list/unit variants | Existing lexical `Open path body`, preserving local binders and outer fallback. |
| `include Mod` | Exporting `Dopen`, not the private-open tag. |
| `module Alias = Mod` | `Dmod Alias [Dopen ...]`; capture namespace identity without rerunning initialization. |

Keep parenthesized paths and `open!`; do not promise an OCaml warning subsystem.
Keep qualified operator lookup distinct from opening an operator expression.
Do not misclassify embedded CakeML `Dopen` as an OCaml source open. Preserve
empty-suffix opens so missing modules still fail when the AST is checked/run.

Tests must cover private/exported values, types, constructor/exception identity,
shared references, once-only initialization, alias capture before shadowing,
nested scopes, malformed paths, `Mod.()`, `Mod.[...]`, `Mod.(++)` versus
`Mod.((++))`, and mixed Candle/CakeML declarations. Preserve the previously
chosen Candle duplicate type/module shadowing policy, explicitly different
from OCaml's rejection. Do not newly erase constraints on path aliases or
claim that parsed signatures are enforced.

Exit: exact corrected-donor AST comparison and focused semantic comparisons,
including the 33 later extension cases on the actual candidate path.

## C2. Extract the lexical fixes; decide identifier widening separately

Read the local pinned patches, for example from this project root (the current `parse/` directory):

```sh
git -C ../cake-jurban show 055fd9e1b -- compiler/parsing/ocaml/caml_lexScript.sml
git -C ../cake-jurban show fd5c47337 -- compiler/parsing/ocaml/caml_lexScript.sml
```

1. **Unknown string escapes**, donor `055fd9e1b`: adapt `scan_strlit` in
   `src/lexer.cml` to retain the backslash and following character for the
   donor's unknown-escape cases. Preserve rejection of malformed numeric
   escapes and the donor's line-continuation limitation. Test `\q`, `\_`, valid
   escapes, incomplete backslashes, bad hex/octal/decimal escapes, mixed strings,
   exact byte contents and locations. Do not apply this OCaml fix to the
   embedded CakeML lexer or silently change character literals.
2. **Tight cons/prefix lexing**, lexical hunk of `fd5c47337`: recognize reserved
   `::` before the generic symbolic run. Compare `x::!xs`, spaced controls,
   repeated colons, nearby custom operators, strings/comments and end of input.
   Review whether other `::`-prefixed spellings are intentionally affected;
   do not bundle this commit's unrelated expression/record grammar changes.
3. **Identifier context**, donors `29c4d2c94` and `36e2245f4`: first run controls
   against B0+C1. Qualified HOL Light uppercase values already worked in the
   corrected opens campaign; do not import a rewrite merely for its title.
   Single-letter/all-capital module widening conflicts with the dialect boundary
   explicitly retained in `cake-dopen`. Default: keep that boundary. If widening
   is wanted, obtain an explicit dialect decision, then test `A.(i)`, `S.[i]`,
   assignments, qualified uppercase values and constructors together. Widening
   must not reinterpret uppercase-value indexing as module opens.

Exit: full lexer equality outside enumerated changes, dedicated before/after
vectors for each intentional change, and no regression of C1's disambiguation.

## C3. Small syntax fixes, repaired rather than copied wholesale

Target `src/grammar.cml`, `patterns.cml` and B0's expression/binding conversion.
Keep grammar and conversion changes in the same coherent batch.

| Donor material | Planned work | Required counterexamples |
| --- | --- | --- |
| `bffa9107e`: parenthesized annotated recursive binders | Port shape/token checks; verify where `Tannot` belongs relative to generated lambdas/eta expansion. | Function-valued bindings, multiple recursive bindings, malformed annotations, annotated recursive values. Do not call inherited recursive-value lowering OCaml-compatible merely because syntax parses. |
| `58da58c68`: tuple function arguments | Port tuple-parameter recognition and pattern conversion while preserving currying boundaries. | `fun x,y -> ...`, parenthesized controls, several parameters, constructor patterns, annotations and malformed commas. The existing deferred expected failure for this form is an intentional B0→B1 change, not a test to delete. |
| `14f25006e`, selected `fd5c47337`: separators | Accept the agreed trailing semicolon forms at explicit expression delimiters, with matching conversion. Inspect existing module-item separators before adding anything. | Parentheses, `begin/end`, loop bodies, handlers, typed expressions, list separators, `;` versus `;;`, and malformed `; THEN` forms. Do not accept arbitrary missing expressions by making every separator optional. |
| `51513f0df`, expression portion of `fd5c47337`: conditional operands/components | Repair the grammar for unparenthesized conditional operands/tuple components without weakening ordinary precedence. Include the old #1019 cases. | Concatenation/append next to comparison, arithmetic, Boolean operators, commas, sequencing, let/match/if and dangling `else`; left/right associativity. |

Do **not** transplant the donor's `nECat` right operand `nEIf` unchanged. It can
turn `"a" ^ "b" = "ab"` into `"a" ^ ("b" = "ab")`. Retain the ordinary
precedence ladder and add narrowly identified unclosed-expression alternatives
where the dialect permits them; select the precise grammar only after checking
the cross-product above against the reference. Test AST grouping, not just
acceptance. A pretty printer or successful typecheck can miss other regroupings.

For each affected operator tier, generate both valid and malformed surrounding
contexts; use distinguishable operands and side-effect sentinels in shared
semantic tests. Check error locations/messages for cases outside the agreed
change set. Grammar restructuring may alter diagnostics on related invalid
inputs: record those as compatibility changes instead of silently rebaselining
every failing golden.

Exit: targeted new forms work, precedence/association controls retain their
expected ASTs, and every changed old result has a reviewed explanation.

## C4. Float literals: a compiler/runtime contract gate

Donors `30e014bd9` and `8ef793fd8` supply useful material, not a finished design.
Inspect `ptree_Double`, literal and negation conversion against
the donor review (external `cake-dopen/JURBAN-UPSTREAM-REVIEW.md`). The donor emits
shadowable `Option.valOf (Double.fromString ...)` calls; its ordinary `-` still
uses integer negation. Negative zero, subnormals, overflow/underflow and runtime
conversion failure are not solved by accepting a positive decimal token.

Plan:

1. Establish the desired literal-value contract from the chosen native reference:
   decimal/exponent/underscore forms, unary minus versus negative constants,
   signed zero, rounding ties, smallest normal/subnormal and extreme exponents.
2. Prefer existing AST support for an exact floating representation if the
   executable exposes it; investigate that capability rather than assume it.
   Otherwise specify a stable runtime helper contract, including shadowing and
   conversion/range behavior. Do not hard-code ordinary shadowable names and
   call the result general literal compatibility.
3. Keep the parser pure: no `strtod` FFI or runtime evaluation while parsing.
   If exact bits must be computed there, a deterministic correctly rounded pure
   decimal conversion is a substantial subtask with its own tests, not a quick
   parser patch. If that is disproportionate, request a supported runtime/AST
   route instead of claiming the donor implementation is sufficient.
4. Compare emitted ASTs structurally, and compare evaluated results by exact
   floating bits (including signed zero), not formatted decimal strings. Test
   shadowing, repeated evaluation and failure behavior independently.

Exit: an explicit supported range/rounding/name-resolution contract and actual
value tests. If runtime/AST changes are necessary, record this batch as gated
on that separate work; do not silently weaken its completion criterion.

## C5. Structural records: an elaboration gate, not a label-name patch

Donor `60f1f95ea` implements useful syntax, construction/projection/update and
mutable fields, but sorted field names do not identify nominal record types.
Unqualified field helpers also resolve incorrectly when labels are reused.
Do not replace the existing named-constructor Candle records with that encoding.

Required design work before implementation:

- Trace declared type/module identities through declarations and uses. Test two
  types with the same labels but different field types, types in separate modules,
  aliases/opens/includes and later declarations shadowing earlier labels.
- Explain how a pure `string -> Ast.dec list` call can resolve a use of a record
  declared in an earlier REPL input. A within-string label table cannot do this,
  and a mutable global parser registry would violate the API contract.
- Therefore prefer representation/elaboration support at the existing compiler
  type-resolution boundary, with source parsing remaining pure, if general
  nominal records are required. That may need new AST/elaborator/runtime support
  and is a separate approved expansion. An explicitly constrained subset is an
  alternative only after a user decision; unique generated constructor names
  alone do not fix label resolution.
- Specify functional-update copying versus mutable-field reference sharing,
  duplicate labels, field types, annotations, evaluation order and module export
  behavior. Where OCaml leaves evaluation order unspecified, state Candle's
  chosen order rather than claiming one native run defines the language.
- Build typing/execution counterexamples as well as syntax/AST fixtures. Include
  cross-call declarations, alias identity, overlapping labels and mutation.

Exit: approved implementable design and all its semantic tests, or an explicit
recorded dependency on compiler elaboration. This plan does not label general
records as a completed or trivial parser-only compatibility fix.

## C6. Corpus acceptance and release of corrected B1

Run each compatibility batch on the original bytes and the documented prepared
inputs, separately. Reuse the 400/185 corpus and the isolated triage controls;
do not import their source substitutions as product behavior. Reports must
separate exact AST equality, syntax acceptance, typing, execution, intentional
differences and no-verdict resource failures. Reaching an undefined-variable
guard is only evidence of parsing/conversion, not application execution.

For every batch, retain a change manifest: donor commit/hunk, port functions,
before/after source cases, exact old/new result, independent oracle and reason.
Include changes to locations and diagnostics, not just accepted/rejected status.
Keep the original B0 golden files available and add versioned B1 expectations.
No unexplained differences are allowed on previously passing unaffected cases.

General boot fixes (filename splitting, loaded-file EOF and directive boundaries),
runtime libraries, hash tables, SOS/thecops, tracing/PFT, and quotation expansion
are tracked external dependencies, not changes to this pure parser. Their need
may explain a failed full application; it must not be disguised as parser success.

Freeze B1 with its source hashes, runtime requirements, exact serializer version,
fixture manifests, corpus results and baseline timings. The initial bounded B1
can comprise C1–C3 once those are complete; C4/C5 require explicit contract and
dependency decisions. Name that scope accurately. Do not wait indefinitely for
general OCaml records before optimizing a useful tested parser, and do not call
that bounded release completion of the gated float/record work. Later feature
batches create a new baseline and rerun the performance equivalence gates.

## Completion checklist

- [ ] B0 complete; usable runtime exports checked; baseline evidence retained.
- [ ] Corrected opens/includes/aliases ported and candidate-tested.
- [ ] Lexical fixes and the identifier-dialect decision recorded.
- [ ] Tuple/binder/separator/conditional syntax tested, including counterexamples.
- [ ] Float and record decisions explicit; implemented batches meet their gates,
      remaining external dependencies are named rather than hidden.
- [ ] All intended result changes reviewed; no unexplained regressions.
- [ ] Durable corpus/reference artifacts and corrected B1 frozen.
- [ ] Source mapping, compatibility notes and test-gap inventory updated.
