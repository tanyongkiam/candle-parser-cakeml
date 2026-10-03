# Candle parser baseline measurements

The measurement driver is [tools/benchmark.py](tools/benchmark.py). It loads the
same 18-source Candle-only bundle as the test suite, without goldens. It reports
startup, parser source compilation/loading, benchmark-input loading, zero-batch
command overhead, and repeated parse batches separately. Results consume a
declaration count or an expected failure; they do not print full ASTs or execute
parsed programs. Whole-process peak RSS includes source compilation and the
configured runtime heap, not just parser working memory.

Packaging update: `tools/load_parser.py` now wraps the same source definitions
in `local`, exposing `CandleParser.parse` and its error-location datatypes.
The benchmark automatically uses
that public bundle. The saved baseline below predates this wrapper: its load
times/printed declarations are historical, not measurements of the new packaging.
Parser definitions and golden expectations did not change. The old JSON path
keys use the enclosing checkout's `parse/` prefix; see `STANDALONE.md`.

M7 (2026-10-03) changes the runtime/AST location representation and adds the
public error-location datatypes. All recorded timings below predate that
migration; none is a current-runtime performance claim. This milestone's
acceptance campaign tests fidelity and integration, not an optimization or
benchmark comparison.

## Hidden public-bundle check — 2026-09-16

A new isolated run completed in the relocated standalone copy, using its
byte-identically rebuilt runtime and the hidden public bundle. All 23 benchmark
inputs completed with their expected success/failure class. Raw samples are in
[benchmark-public.json](benchmark-public.json); project-relative file hashes,
the generated bundle hash and environment are in
[benchmark-public-environment.json](benchmark-public-environment.json).

| Measurement | New public bundle |
| --- | ---: |
| REPL startup | 0.628 s |
| Parser source compilation/loading | 2.443 s |
| Benchmark input loading | 2.904 s |
| Records | 6.089 ms/parse |
| Candle-only boot projection | 106.257 ms/parse |
| Whole-process peak RSS | 16,794,332 KiB |

The benchmark ran after the other REPL tests finished. This checks that the
standalone public loading path works within the same resource settings; it is
not an alternating controlled comparison proving that encapsulation sped up
parsing. In particular, module-loading output and compilation grouping changed,
while host scheduling and runtime variation still affect wall times. Keep the
earlier baseline below as historical evidence, not a measurement of this bundle.

## Accepted baseline — 2026-09-16

The isolated run completed after both HOL oracle jobs had finished; no other
parser test or benchmark was run concurrently. Raw samples are retained in
[benchmark-baseline.json](benchmark-baseline.json); host, executable,
configuration, source and driver hashes are in
[benchmark-environment.json](benchmark-environment.json). Host scheduling/GC
variation still exists: this is not a dedicated-machine laboratory result.

| Measurement | Result |
| --- | ---: |
| REPL startup | 0.857 s |
| Parser source compilation/loading | 5.839 s |
| Benchmark input compilation/loading | 5.203 s |
| Median zero-batch command overhead | 4.852 ms |
| Records, 1,779 bytes | 8.138 ms/parse |
| Candle-only boot projection, 23,683 bytes | 137.923 ms/parse |
| Whole-process peak RSS | 16,789,144 KiB |

The three boot batch samples range from 1.354 to 2.237 seconds for ten parses.
This variability is why the median and all raw samples are retained. RSS is
roughly the configured 16 GiB heap plus runtime overhead, **not** a claim that
parsing a 24 KB file intrinsically needs 16 GiB. Finding the minimum practical
source-loading heap is outside this baseline measurement.

The driver now calibrates each case by doubling the batch size toward 150 ms
(at most 10,000 parses), before collecting three measured samples. Per-case
round counts are stored. This avoids the fixed-ten-round run's inability to
resolve fast comment/string cases. Calibration is not included in the samples;
subsequent samples can still be shorter because of runtime/host variation.

### Scaling review

Overhead-subtracted median milliseconds per parse:

| Family | n=8 | n=32 | n=128 |
| --- | ---: | ---: | ---: |
| Declarations | 2.273 | 9.933 | 25.885 |
| List elements | 1.529 | 6.880 | 14.863 |
| Application arguments | 0.409 | 0.780 | 2.335 |
| Nested parentheses | 2.006 | 5.204 | 19.922 |
| Nested comments | 0.308 | 0.321 | 0.202 |
| String bytes (128*n) | 0.358 | 0.306 | 0.566 |
| Late failure after n declarations | 2.177 | 5.887 | 22.117 |

The declaration/list/application/parenthesis/failure families show no sustained
superlinear growth across this bounded range. Comment and string times are
small and non-monotonic; they do not establish an asymptotic complexity bound.
All workloads completed with their expected success/failure class. Exact AST
correctness is checked separately by the goldens, not by timing checksums.

The source audit checked the port-specific risk points: one `String.explode`
per public call; shared input-list tails in PEG backtracking; grammar vectors
constructed once; and no new repeated length-of-remaining-input scans in the
PEG loop. Tree fringe/location traversal and tuple-pattern growing appends
retain the reference's traversal shapes. Cartesian-product tail sharing retains
output order; successful pattern alternatives are nonempty, so hoisting that
tail computation introduces no empty-head expansion on the public parse path.
No port-specific asymptotic regression was identified in these checks.

Inherited backtracking, non-tail token production and or-pattern expansion can
still be costly. This audit does not establish linearity on arbitrary input,
maximum nesting/file sizes, or large Flyspeck performance. No comparable
source-loaded reference executable is available; HOL evaluation time is not a
valid throughput comparator. Substantial speed improvements belong to the
separate compatibility-then-performance plans, not this faithful baseline.

## Reproducing the measurement

```sh
python3 tools/benchmark.py --samples 3 --rounds 10
```

Timing is **host wall time**, including the small REPL invocation/printing cost.
The zero-iteration batch estimates that cost. Batches no slower than the
measured overhead are marked resolution-limited (`null`), not zero-cost
parsing. Keep the raw batch samples. There is no comparable source-loaded
reference executable, so this cannot support a claimed speedup over the original.

A historical pilot run with three samples and three parses per batch completed on the new
runtime: startup approximately 1.59 s, parser loading 6.76 s, input loading
5.64 s; records/raw approximately 13 ms and the 23,683-byte Candle-only boot
projection approximately 219 ms per parse after overhead subtraction. Peak
whole-process RSS was approximately 16 GiB with `CML_HEAP_SIZE=16384`.
**This pilot ran concurrently with HOL oracle generation and is not the final
performance acceptance measurement.** Several small cases were below timing
resolution. It is superseded by the isolated, calibrated run above.

The 23 inputs cover the two frozen real-input cases and geometric sizes of
declaration sequences, lists, application chains, nested parentheses, nested
comments, long string literals, and late syntax failures. The boot input is the
explicit two-pragma projection documented in [tests/README.md](tests/README.md),
not a claim of raw-boot or embedded-CakeML compatibility.
