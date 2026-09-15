# Candle parser acceptance and deferred coverage

Updated 2026-09-16. The Ast.Ident blocker is resolved. The Candle-only parser is
implemented and **1,832 exact reference comparisons pass** in a fresh REPL.
This is strong finite test evidence, not a proof of equivalence for every input.
The amended Candle-only acceptance gates are complete. Remaining user-deferred
features and limits of this finite evidence are recorded below.

## Current command and evidence

```sh
python3 tools/run_tests.py --suite candle
python3 tools/test_harness.py
# Deliberately wrong expected AST: this invocation must fail.
python3 tools/run_tests.py --suite candle --test tests/parser_negative.cml
```

The normal Candle suite uses 18 source files and 34 test files. The executable is
`cake-ast-parse-ident`, SHA-256
`b2e35989a1ea1b31f99c6b2fbb92db5f6063f4bd2eeb511ffcbc973e933335fc`, with its
matching active configuration. See [runtime/README.md](runtime/README.md).

| Coverage | Passing comparisons |
| --- | ---: |
| Earlier Candle lexer/grammar/name/type/pattern/metadata layers | 615 |
| Restored full expression fixtures | 134 |
| In-scope stored declaration fixtures | 50 |
| In-scope stored public-parser fixtures | 60 |
| All in-scope inherited Candle HOL test inputs | 210 |
| Expanded public wrappers/products/mutations | 712 |
| Direct generated-expression/declaration helpers | 31 |
| Real corpus inputs | 6 |
| Conditional/tuple/precedence controls | 14 |
| **Total** | **1,832** |

Counts intentionally overlap layer/public views and earlier selected regressions;
they are not counts of distinct programs. Of the 712 expanded public cases, 475
succeed and 237 fail with exactly the reference error/location. The extractor
accounts for all 214 active `camlTestsScript.sml` inputs, including type-test
helpers and expected failures; four pragma inputs are explicitly deferred.

## Restored Ident-dependent gates

- [x] **G1 — Runtime ABI.** Short/qualified/internal identifiers, annotations and
  enclosing declarations are constructed using the real Ast datatype.
- [x] **G2 — Stored public vectors and negative control.** All 60 in-scope vectors
  compare exactly; hand ASTs and empty/invalid/repeated calls pass. The separate
  changed-identifier test fails as intended, even though the REPL later prints
  its final sentinel. Fixture data resembling diagnostics is also tested.
- [x] **G3 — Full Candle expression family.** All 134 restored vectors and the
  inherited expression tests run, including precedence, application, guards,
  records, loops, let/rec/functions, failure behavior and variable bodies.
- [x] **G4 — Generated lowering.** Thirty-one direct HOL helper goldens plus the
  expression/declaration suites cover generated identifier spellings, guard
  continuations, recursive-binding packaging, record helpers and let variants.
- [x] **G6 — Candle declaration portion.** Final type/module/signature/let
  conversion and generated record functions are compared structurally.

The oracle serializer was corrected to preserve nested binary pairs inside
exported Ast types; private converter metadata still uses native flat tuples.
This is an adapter correction, not a parser behavior change. Original HOL
sources remain unchanged. No Ast.Var placeholder or substitute AST is used.

## Explicitly deferred by the user

**G5, G7 and the embedded part of G6:** CakeML `(*CML ... *)` conversion is out
of scope. Preserve the partial `cake_*.cml` files and their original fixtures;
they are not dependencies of the Candle parser. A reached pragma declaration
returns the explicit located unsupported-feature error. Misplaced pragmas can
still fail earlier in the ordinary lexer/grammar pipeline.

The stored declaration/public fixture files retain all 64/76 original results.
Their drivers explicitly exclude 14/16 pragma-bearing inputs and assert those
scope counts. The four inherited pragma exclusions are named in the expanded
oracle log. None of these original expectations was changed to make the
unsupported candidate result look reference-compatible.

## Final acceptance checks

- [x] **G8 — Final regression audit.** Expanded inherited/generated/mutated
  comparisons pass, including 14 conditional/tuple/precedence controls. Bare
  addition/concatenation operands and second tuple-component conditionals fail;
  parenthesized controls succeed. The local donor supplies concrete examples of
  the limitation associated with #1019, but its issue body was not retrieved:
  these are not claimed to be verbatim issue examples. No compatibility fix was
  applied. See `tests/corpus/README.md` for exact provenance.
- [x] **G9 — Independent real corpus.** Exact HOL comparison covers the records
  file (20 declarations) and a boot projection (42). The projection replaces
  exactly two known pragma blocks with spaces/newlines; it is not raw-boot
  compatibility or a new interactive preprocessor. Four additional local inputs
  (complete fib/streams regressions and pinned HOL Light lib/basics excerpts)
  also match exactly. All six succeed; their declarations are never executed.
  Larger local prepared corpora were identified, but their preprocessing and
  later-compatibility results are not relabeled as tests of this port.
- [x] **G10 — Final package/performance acceptance.** The source bundle command
  and source mapping exist. [BENCHMARKS.md](BENCHMARKS.md) records the completed
  isolated run and bounded scaling/source audit, with raw samples and hashes.
  The fresh Candle (18/34 files) and optional legacy (23/44 files) suites pass;
  the negative control exits 1 on the deliberately wrong identifier, despite
  the REPL's later sentinel. All three Python harness checks pass. Loading the
  generated bundle with `#use` in a fresh REPL produces the exact hand-checked
  identity AST. The source map covers all 24 ported files; reference hashes and
  input/fixture regeneration were checked. No performance rewrite or JUrban fix
  is bundled. The normal bundle now hides all 17 helper structures with `local`;
  only the explicit development path exposes them. The separate `public` suite
  repeats 792 existing public comparisons behind that boundary, and two bundle
  tests verify `#use`/visibility and preservation of the development source order.

## Standalone packaging cleanup

`make test` runs harness/bundle checks, public goldens and every preserved layer
test. The public comparisons reuse existing fixtures and do not inflate the
1,832-vector count. No parser algorithm, reference result or deferred CakeML
source changed during encapsulation. `README.md` commands use this directory
as the repository root; optional oracle regeneration uses external CakeML/HOL
checkouts as documented in `STANDALONE.md`.

Relocation check: a cache-free copy outside the CakeML tree built the bundle,
rebuilt the included runtime assembly and passed `make test`. Every original
suite also passed independently; the hidden-bundle negative control failed on
the deliberately wrong AST. All 24 parser/legacy source-file hashes still match
the prior baseline: this cleanup changes packaging/tooling, not parsing.

Oracle builds: `afc19b02` regenerated the restored AST fixtures;
`cb989c16` generated the expanded 210/712 fixtures; `e3ac3285` generated 31
helper fixtures; `c54b26f3` generated records/boot and `935b571e` generated the
additional corpus/conditional controls. All five completed successfully and their results have been
compared in the native REPL. See [tests/README.md](tests/README.md) for regeneration.
