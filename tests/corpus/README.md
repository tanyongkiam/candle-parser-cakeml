# Additional local corpus snapshots

These are parser inputs only: no declarations, file loaders or generated ASTs
are executed. [manifest.json](manifest.json) records the donor paths, whole-file
hashes, copied-byte hashes and exact end-before delimiters for excerpts. Hashes
are checked by `tools/limits_inputs.py` before generating oracle inputs.

- `ocaml-fib.ml` and `ocaml-streams.ml` are complete, unchanged files from this
  checkout's `unverified/ocaml-syntax/tests/`. They exercise recursive functions,
  streams, simultaneous bindings, patterns and modules.
- `hol-light-lib-prefix.ml` is the unchanged prefix of the locally available
  `../cake-dopen/hol-light/lib.ml` through `map2`, before `mapi`. It includes
  combinators, uppercase HOL Light value names and recursive list functions.
- `hol-light-basics-prefix.ml` is the unchanged prefix of that checkout's
  `hol-light/basics.ml` through `strip_abs`, before the binary-operator section.
  It includes references, sequencing, type-constructor patterns and exceptions.
  Its `needs "fusion.ml"` is retained as raw syntax; parsing it does not load
  that file. No quotations occur in these excerpts.

Copyright notices in the source excerpts are retained. These bounded inputs
exercise useful real syntax without claiming whole-HOL-Light acceptance.
Larger HOL Light/Flyspeck files and prepared corpora exist locally, but depend
on quotation/loader preprocessing and compatibility work outside this port.
Their historical results are not results for `CandleParser.parse`.

The separate frozen records file and boot projection are selected by
`tools/corpus_inputs.py`. Only the boot projection changes source bytes: exactly
two known, user-deferred CakeML pragmas are replaced with spaces/newlines.

The independent `candleLimitsOracleScript.sml` driver also characterizes 14
conditional/tuple/precedence inputs. The two bare conditional forms are from
local donor commit `51513f0dfb3bcf169c8342de6efd04e5b7b4e00b`; the remaining
controls are explicitly authored neighboring cases. We have not retrieved
GitHub #1019's issue body, so these must not be called verbatim issue examples.
They test the limitation described in the local compatibility notes, against
the original parser, without importing the donor's behavior changes.

Status: all four snapshots and all 14 controls compare exactly against the
independent HOL oracle (`935b571e`, successful). All four snapshots succeed;
10 controls succeed and four fail. The records/boot oracle (`c54b26f3`) also
completed successfully and both candidate results match. These 20 comparisons
are enabled by default. See `../README.md` for regeneration commands.
