# Standalone build inputs and reference regeneration

This is the root of `tanyongkiam/candle-parser-cakeml`; there is no extra
`parse/` level in its commands. The local repository is based on the existing
remote `master` history. Compiled executables, old runtime copies and build
caches are deliberately not versioned.

## What is self-contained

- `src/`, `sources.list`, `tools/load_parser.py`: build the public parser bundle.
- `tests/`, stored goldens and the test tools: run public and private-layer
  tests without upstream sources, HOL or network access.
- `reference/cakeml/`: frozen non-HOL input files used by the benchmark/corpus
  input generator. Keep these for reproducible tests and measurements.
- `config_enc_str.txt`, `repl_boot.cml`: the active runtime configuration and
  REPL support; `make` builds `cake-ast-parse-ident`. Keep `candle_boot.ml` for the optional built-in
  `--candle` mode, which is not the new parser's loading path.
- `runtime/cake-ident.S`, `runtime/basis_ffi.c`, `runtime/Makefile`: rebuild the
  active executable with `make runtime`, without CakeML/HOL sources.
- Documentation, source manifests and benchmark evidence retain provenance.

The older binaries/assembly/configuration remain only in the original
development workspace and are excluded from the commit. Partial `cake_*.cml`
source and its sub-tests remain versioned for later work, but are not
dependencies of the public bundle.
Generated `build/`, `.hol/`, `*Theory.dat/sml/sig` outputs under `tools/`, and
Python caches are ignored. They are not required to run stored-golden tests.
Do not treat an old `.hol` cache as portable reference evidence.

Use `make` and `make test` from the repository root. The default build creates
both the executable and public bundle; test targets also build the executable
when needed. Tools locate assets relative to their own project root, not to the
parent repository. Python 3 and system runtime libraries remain prerequisites;
they are not vendored. Source compilation still uses the enlarged runtime
bitmap buffer and a default 16 GiB heap.

## Optional: regenerate independent reference results

Oracle regeneration is intentionally separate from normal development tests.
It requires compatible external CakeML and HOL checkouts and built HOL
dependencies. The original proof sources remain read-only, not vendored here.

Set `CAKEML_ROOT` to an **absolute path** to the reference CakeML checkout.
`tools/Holmakefile` uses it for its includes; when unset, it retains the original
in-tree `../../compiler/parsing/ocaml` fallback. The external CakeML checkout
must itself be configured to find its compatible HOL installation.

```sh
export CAKEML_ROOT=/absolute/path/to/cakeml
python3 tools/expand_cases.py --cakeml-root "$CAKEML_ROOT" > tools/expanded_cases.sml
python3 tools/corpus_inputs.py > tools/corpus_cases.sml
python3 tools/limits_inputs.py > tools/limits_cases.sml
```

Then build the named oracle theories under `tools/` using your HOL build
workflow, with that environment variable passed through. The named targets
and extraction commands are in [tests/README.md](tests/README.md). Do not run
an untargeted whole-upstream rebuild merely to run the stored fixtures.

`SOURCES.tsv` source paths describe the original donor layout: relative source
paths belong to the external CakeML root; absolute HOL paths are historical
provenance and can be resolved by their `examples/formal-languages/` suffix in
your HOL checkout. Copy paths are relative to this standalone project root.
The `adjusted_copy` assembly row records the included copy's hash, not the
unmodified donor hash; the single bitmap-buffer change is in `runtime/README.md`.
The old `historical_executable` row is provenance only, with no versioned copy.
Verify reference hashes before regenerating; the Git commit alone does not
capture the original working-tree baseline. Never replace expected results
with candidate-generated answers.

## Current relocation verification — 2026-10-03

A source-only export, without Git metadata, executables, caches, symlinks or
a parent CakeML checkout, passed `make` and `make test` at
`/tmp/candle-m7-standalone.jZusQ1`. Native linking reproduced the recorded M6
copy byte-for-byte (`621d9552aef15cde336b82c16e94223d136954212eb5e60f8c0221195b9b2df6`).
The complete public/layer/reader campaign passed, including all nine real
reader/Eval tests (81.480 seconds). No HOL or bootstrap build was used.
The temporary directory is test evidence, not a dependency or Git worktree.

## Historical relocation verification — 2026-09-16

A copy of the whole project was placed at `/tmp/candle-standalone.2nygKp`,
excluding build/HOL/Python caches, with no parent CakeML tree or source symlinks.
`make bundle` and `make -B runtime` succeeded there using only included sources.
`make test` then passed using that freshly rebuilt executable: the three
harness tests, two visibility/development-bundle tests, 792 hidden public
comparisons and the complete 23-source/44-test legacy-plus-Candle suite.
All eight original suite entry points were also run independently in the
working project. The hidden-bundle negative control exited 1 on the changed
identifier as intended. This verifies normal build/test independence, not a
standalone HOL installation or regenerated oracle build; those external
requirements remain as described above. The `/tmp` path is evidence of this
run, not a dependency that needs to be preserved.

The benchmark also completed from that relocated root using the hidden bundle;
its project-relative source/runtime hashes and raw samples are retained in
`benchmark-public-environment.json` and `benchmark-public.json`. The rebuilt
binary matched the active supplied Ident binary byte-for-byte.

A second check exported only the staged Git files to
`/tmp/candle-commit-check.iLwrcJ`, with no prebuilt executable or caches.
The default `make` built both runtime and bundle, and `make test` passed all
the harness, visibility, public and layer tests listed above. The rebuilt
executable was again byte-identical, and the changed-identifier negative
control exited 1 as intended. This checks the actual versioned build inputs,
including the automatic runtime prerequisite on test targets.

## Historical evidence and future plans

The original benchmark JSON records paths prefixed `parse/` because it was
captured in the enclosing CakeML checkout. Strip that prefix when resolving
those historical hash keys here; do not rewrite the old measurements as new
ones. The public packaging change and its measurements are documented separately.

The compatibility/performance plans identify external donor checkouts,
review notes and old `/tmp` campaign artifacts. Those are research provenance,
not portable runtime or test dependencies, and their availability after
extraction is not assumed. Obtain the pinned donors/notes explicitly before
that future work; the normal test path never reads them.
