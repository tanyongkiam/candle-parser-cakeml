# Plan: a substantially faster Candle parser with identical output

Scope update (2026-09-16): the initial deliverable is Candle-only; the user has
deferred `(*CML ... *)`. Performance equivalence must retain that explicit
unsupported-feature result until support is separately authorized. Keep embedded
CakeML benchmarks below as future work, not a prerequisite for this delivery.

Written 2026-09-16. Planning only. This follows the faithful-port
[PLAN.md](PLAN.md) and [COMPATIBILITY_PLAN.md](COMPATIBILITY_PLAN.md).
No implementation work or new benchmark results are claimed here.

## Sequence and objective

Finish the faithful B0 parser, measure it, apply the scoped compatibility work,
then freeze corrected B1 before substantial optimization. Compatibility first
keeps donor changes reviewable and gives optimization a stable target. Benchmark
setup and profiling may begin earlier; do not mix syntax fixes with performance
commits. Later compatibility features establish a new versioned baseline.

The objective is materially lower **parse-call time**, not merely faster HOL
translation, reduced REPL printing, a larger heap, or faster source installation.
Retain the pure string-to-result API and the existing `Ast` datatypes.

Proposed acceptance target, to be confirmed against measured B1:

- At least **2× geometric-mean speedup** on the pinned representative real-input
  suite, reporting per-input results and absolute times as well. This is a target,
  not a forecast or an excuse to change the workload after measurement.
- No unexplained reproducible slowdown over 10% on meaningful-sized individual
  workloads, including invalid inputs; distinguish measurement noise on tiny
  inputs with sufficiently large batches and repeated trials.
- No avoidable worse scaling, new parse-depth/fuel limit, or substantial unexplained
  memory increase. Report peak RSS and retained memory between calls separately.
- Exact output equality on the full correctness suite at every accepted change.

If these targets are not reached, report the measured outcome and remaining
bottleneck. Do not declare success from a selected microbenchmark or broaden the
implementation into a new compiler/FFI service without approval.

## P0. Define what byte-identical means

The public result is an AST/error value, not an existing byte stream. Interpret
the requirement as exact structural equality, plus byte equality under a fixed,
complete, deterministic test serialization. It does not mean identical memory
addresses, allocation/sharing, REPL banners or pretty-printer formatting.

The serialization must cover:

- The result variant, every AST constructor and field, declaration/list order,
  optional fields, source locations and all nested annotations.
- Every string as its original bytes, including NUL, bytes above 127, backslashes
  and CRLF; explicit lengths/tags avoid ambiguous concatenations.
- Exact integers/words, generated identifier spellings, and floating bit patterns
  if the selected B1 AST contains them. No decimal pretty-print normalization.
- Errors as exact variant, location and message. Unchanged invalid inputs are
  part of the equivalence contract, not second-class benchmark material.

Reuse the current independent oracle's constructor serialization where practical,
but do not mistake its supported subset for a complete public-result encoder.
Complete and version the format, validate it against small hand-built values,
and ensure every constructor in the pinned AST is handled explicitly. Never use
a wildcard that emits a generic placeholder for unfamiliar AST nodes.

Compare baseline and candidate structurally inside CakeML where possible, then
compare serialized bytes for persisted/cross-process runs. Deliberately alter
an annotation, identifier, error location and byte-string payload to confirm the
checker rejects each. A checksum may consume benchmark results or shortlist
mismatches; a checksum match alone is not the exact-equality acceptance test.

Retain B1 as a test reference without creating a second permanently maintained
production parser. Use isolated processes/artifacts or separately named modules
sharing the real `Ast` types. Generate reference answers from the frozen baseline,
never from the optimized candidate. Do not regenerate B1 goldens to make an
optimization pass.

## P1. Build a repeatable measurement and profiling loop

### Existing code and evidence to inspect

- [src/peg.cml](src/peg.cml): generic continuation machine, higher-order semantic
  actions, saved input/value tails and error accumulation.
- [src/grammar.cml](src/grammar.cml) and
  [src/cake_grammar.cml](src/cake_grammar.cml): grammar values and immutable lookup
  vectors already built once. Do not propose this existing optimization as new.
- [src/grammar_support.cml](src/grammar_support.cml), [src/tree.cml](src/tree.cml):
  singleton lists, append/flatten actions and node-location calculation.
- [src/lexer.cml](src/lexer.cml), [src/cake_lexer.cml](src/cake_lexer.cml),
  [src/support.cml](src/support.cml): byte scanning, allocation, list/string
  conversions and non-tail-recursive token production. The CakeML string scanner
  already uses a reversed accumulator.
- [src/cake_conversion.cml](src/cake_conversion.cml): `ptree_linfix` recursively
  appends singleton results; investigate long left-associated trees. Inspect
  the completed Candle converters for analogous growing-prefix operations.
- [Source adaptation ledger](src/README.md): existing sharing/precedence
  specializations are baseline behavior, not newly earned performance wins.
- `CakeML: compiler/parsing/pegexec_cml_foScript.sml`:
  `sem_u`, `sem_b`, token checks, `corestep_fo_body`, `run_peg_fo` and
  `peg_exec_fuel_fo`. This is design material, not a measured drop-in replacement.
- JUrban commit `06a639c4d` in `../cake-jurban` factors `select_expr_nterm` to
  reduce symbolic translation duplication. The local reviews do not establish
  a parse-throughput benefit; source-loaded compilation cost is a separate metric.

### Workload matrix

Pin exact input bytes and sizes before tuning. Include:

1. Small interactive declarations, both valid and invalid; repeated-call batches.
2. Raw/preprocessed boot and records inputs at their agreed parser boundary.
3. Representative small/medium/large inputs from the existing 400/185 prepared
   corpus; include a held-out set not used for tuning. Keep accepted and rejected
   groups separate so a faster early rejection cannot masquerade as faster parsing.
4. `Multivariate/metric.ml`, `Multivariate/topology.ml` and
   `formal_graph/archive/archive_all.ml`: prior campaigns had no verdict. Recheck
   exact input bytes and classify current failure/resource behavior; do not label
   them parser bugs or assume a speed fix resolves them.
5. Embedded CakeML-heavy and mixed Candle/`(*CML ... *)` inputs, including accepted
   prefixes with leftovers and lexical failures late in a pragma.
6. Geometric-size generated families: many declarations; long application/operator
   chains; tuples/lists/types; nested parentheses/modules/comments; long strings;
   record fields/matches; repeated ambiguous prefixes; failures near EOF. Choose
   families supported by the frozen B1, and retain intended-invalid families too.

Use sizes n, 2n, 4n, ... until a declared resource ceiling. Capture failures as
outcomes; do not quietly reduce the size range for the candidate. No full HOL
Light theorem execution is needed to benchmark its source parser.

### Measurement protocol

- Run both parsers in the **same executable**, with the same heap/stack/bitmap
  settings and host. Record executable/source hashes, CPU, runtime settings and
  exact commands. The old corpus campaign's 512/128 MiB settings are not directly
  comparable with the source-loading harness's current 16 GiB heap allowance.
- Load/compile modules and input values before timing. Warm up, then measure at
  least seven trials, alternating baseline/candidate order. Avoid concurrent
  throughput runs on the same CPU. Report median and spread, not just the best run.
- Measure total parsing and separate lexer, PEG/tree and conversion phases using
  prebuilt intermediate inputs for the isolated measurements. Report that their
  isolated times are diagnostic and need not add to the end-to-end median.
- Use an available monotonic timer in the benchmark driver, outside the pure
  parser. Check timer resolution and empty-batch overhead. If only whole-process
  timing is available, label it as such; do not present startup-subtracted guesses
  as parse-call measurements. Use larger in-process batches for tiny inputs.
- Consume results without pretty-printing complete ASTs. Perform full equality
  and serialization outside the timed interval. Avoid retaining every result
  merely for timing, but explicitly test repeated calls and mixed success/failure.
- Measure source load/compilation time, whole-process RSS and parser throughput
  separately. Record GC/allocation statistics only when the runtime exposes them;
  do not invent byte-allocation estimates from wall-clock differences.

The current `tools/run_tests.py` is a correctness harness, not a benchmark. Its
text-input path can transcode non-UTF8 source. For corpus transport use generated
ASCII `.cml` string literals with three-digit byte escapes, or a byte-preserving
input channel. Verify a round-trip hash before timing; never normalize newline
or Unicode content to get an input to load.

Temporary profiling counters may count PEG steps, rule visits, repeated visits
at the same token position, backtracking distance, constructed nodes, conversion
visits and maximum stack lengths. Keep them in a diagnostic build; measuring
list lengths at every transition would itself introduce quadratic work. Remove
instrumentation from timed production comparisons. Use sampled profiles if
supported, but do not require a compiler bootstrap just to enable profiling.

Exit: reproducible B1 timings and a ranked account of where parse time/allocation
actually goes. Save raw measurements, not just a prose conclusion.

## P2. First optimization batch: measured allocation and traversal costs

Choose the hottest observed opportunities, one coherent change at a time:

| Candidate | Implementation approach | Equality risks to test |
| --- | --- | --- |
| Growing-prefix append in converters | Accumulate in reverse or traverse left spines with an explicit work stack; reverse once. Start with measured `ptree_linfix`-like paths. | Source order, tuple grouping, annotations, first failure and error selection. Preserve left-to-right conversion behavior even if results are accumulated backwards. |
| Deep non-tail recursion | Tail-recursive token production and explicit stacks for measured deep conversion paths. | EOF/last-token locations, partial lexer failure, list order; no new depth cutoff. |
| Repeated string/list conversion or scanning | Classify each token once, reuse decoded text and local lengths; move to a byte-index scanner only if lexer allocation dominates. | Byte offsets versus row/column locations, CRLF, escape/comment quirks, numeric suffixes and pragmas. No global Unicode conversion. |
| Tree/action allocation | Specialize common singleton/node/append actions; avoid constructing discarded intermediary lists where measured. | Exact parse-tree shape/location when used by conversion, choice/error bookkeeping. |

For each patch: run unit/layer tests, full B1 exact-result comparison and the
pinned benchmark subset; then full benchmarks for the batch. If performance is
within noise or worsens, drop the patch instead of retaining complexity on faith.
Do not replace the reversing `partition_types` with stable partition or change
duplicate-field sorting order under the guise of a faster list implementation.

Exit: measured improvement with zero unexplained output differences, plus updated
function-level provenance/adaptation notes.

## P3. Main architectural candidate: specialize PEG execution

If profiles show the generic PEG interpreter/action dispatch is still a major
cost, prioritize specialization over importing a new parsing library. Inspect
the existing first-order implementation before designing another machine.

1. **Inventory the fixed grammar actions.** Defunctionalize closure-valued token
   checks and tree-building actions into a small tagged representation or direct
   specialized functions. Preserve grammar order and the current continuation
   semantics. Reuse appropriate ideas from `pegexec_cml_fo`, but it is specialized
   to CakeML tokens/nonterminals, not the Candle grammar and its new compatibility
   productions.
2. **Prototype one actual hot slice.** Test it against the generic engine on raw
   PEG results, including input remainder and retained error option on success.
   Compare allocations/throughput; a tag-dispatch interpreter can also be slower
   than compiled closures. Do not commit to a full port from theoretical appeal.
3. **Use an unbounded executable loop.** The local first-order entry point is
   fuelled and returns `Looped_fo` on fuel exhaustion. Copying a fixed fuel budget
   would introduce new failures and violate the output contract. Reuse its step
   structure, not that bounded entry-point policy. Any resource limit remains an
   external harness limit, not a syntax error.
4. **Specialize fixed rule calls if beneficial.** Compile common sequence/choice
   paths into direct source functions or compact instruction blocks, reducing
   intermediate `EV`/`AP` transitions. Keep one authoritative grammar description
   and reproducible generation if generation is used; do not maintain two hand-
   edited rule tables indefinitely. No translator refactor is required.
5. **Revalidate error algebra.** `maxerr` favors the second error at tied ordered
   locations; `ome`, `CmpEO`, `RestoreEO`, `DropErr` and failed alternatives affect
   observable results. A FIRST-token dispatch shortcut that skips a branch can
   change its error contribution even when successful parsing is unchanged.
   Either reproduce that contribution exactly or keep the original choice.

Keep the outer Candle full-input check and embedded CakeML prefix behavior
distinct. Preserve arbitrary bytes, source locations, generated names and every
AST annotation. Test nullable/repetition cases; do not assume any arbitrary PEG
can safely be rewritten into predictive recursive descent.

Exit: demonstrated improvement on real workloads, exact raw-result layer checks
and complete B1 AST/error comparisons. Do not call a verified HOL source theorem
a proof about this separately hand-written optimization.

## P4. Conditional follow-up: repeated parsing and tree elimination

Only pursue these if P1–P3 measurements justify their added complexity.

### Selective memoization

Use rule-call counts to identify repeated work at the same token offset. Prototype
memoization only for costly rules; use token indices or persistent cursor IDs,
never structural list equality or repeated `length remaining_input` as a key.
If indexed input is introduced, preserve the full token/location data and compute
remainders without copying the tail on each return.

A cache entry cannot simply store `(success, AST)`: PEG behavior carries errors
and saved state. Isolate a compositional nonterminal result including its consumed
position, semantic value, failure and successful-path error contribution, then
show that replay reproduces the caller's error/value-stack effects. If that
contract is not established, do not cache the rule. Test the same rule/input under
different accumulated errors, lookahead and fallback contexts.

Caches must be fresh per parse call (or provably input-local); local mutation is
acceptable behind a pure interface, global reuse across inputs is not. Measure
memory as well as time, cap retained caching only in ways that change reuse rather
than syntax results, and avoid indiscriminate packrat storage of every large tree.

### Fusing tree construction and conversion

Consider only if complete parse-tree materialization remains a dominant cost.
Prototype a narrow hot production, preserving exact public ASTs and errors. Keep
conversion pure; backtracking must not commit generated bindings or side effects.
Conversion failures occur after grammar success in the baseline: a fused converter
must not turn them into grammar failures that try another alternative. Location
and annotation reconstruction must follow the old tree, not a cleaner convention.

Retain a debug tree path/reference for differential testing while developing.
Expand only if this produces worthwhile measured gains. A wholesale handwritten
recursive-descent/Pratt replacement is a last resort, not the initial plan: it
greatly enlarges the precedence, error-selection and compatibility proof burden.

Exit: additional measured gains with the same exact-output gate; otherwise stop
at the simpler faster architecture and report its measured result.

## P5. Adversarial equivalence, resource checks and handoff

Use exact B1 comparisons on all stored fixtures, new compatibility cases,
prepared/raw corpus categories and deterministic generated mutations. Include
late failures, tied-location errors, different error histories, empty/comment-only
inputs, repeated calls, long/invalid byte strings, unknown escapes, `::!`, operators
and local-open/indexing ambiguity, recursive and record-generated names, and
valid/malformed embedded CakeML with leftovers.

Keep semantic spot checks for the compatibility changes, but AST/error equality
is the central optimization gate. Add adversarial negative controls that remove
an `Lannot`, reorder a declaration, change an internal identifier, or alter a
retained PEG error. Fuzzing is finite evidence, not proof for every input string.

For geometric families, publish input size, token count, outcome, time and memory;
inspect doubling ratios and the generated output size. Do not demand linear time
for inputs whose required or-pattern expansion produces exponentially many AST
nodes, and do not alter those outputs to improve the graph. Distinguish intrinsic
output cost from avoidable repeated traversal/backtracking.

Run correctness separately from timing and in fresh REPLs. Keep the original
runtime-buffer fix unchanged unless a new, independently diagnosed runtime need
is authorized. A higher resource allowance is not an optimization speedup.

Proposed artifacts (create only during implementation):

- A small separate benchmark driver under `tools/` and source-loaded timing
  harness under `tests/` or `parse/bench/`, with documented actual commands.
- Versioned B1 input/result manifests, a complete serializer, deterministic seeds
  and minimized mismatches in `tests/`.
- `parse/bench/RESULTS.md` plus machine-readable raw measurements, showing B1 and
  candidate hashes, per-phase/per-input results, rejected-input results, memory
  and source-load costs. No fake currently runnable benchmark command in this plan.
- Updated source mapping and one production parser path; frozen reference remains
  a test artifact, not a second supported implementation.

## Completion checklist

- [ ] Corrected B1 scope frozen; complete exact-result/byte comparison verified.
- [ ] Real and scaling workloads pinned, including failures and held-out cases.
- [ ] Baseline measured; optimization choices tied to observed costs.
- [ ] Every accepted patch passes full exact-output and resource regressions.
- [ ] Meaningful speed target met on the declared suite, or shortfall reported.
- [ ] No fuel/depth cutoff, state leakage, error normalization or changed AST.
- [ ] Repeatable commands, raw results, source provenance and fresh-load handoff.
