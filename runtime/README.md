# Runtime build

The repository includes one current runtime source:
`cake-ident.S`, copied from the user's rebuilt CakeML
`compiler/bootstrap/compilation/x64/64/cake.S`, and its matching
`../config_enc_str.txt`. The current copy is the completed issue #1314 M6 build
(2026-10-03); it exposes `Ast.Ident`, integer-pair AST locations and the
direct-AST `Repl.nextInput` interface. Matching migrated `repl_boot.cml` and
`candle_boot.ml` were copied with it. No HOL/bootstrap rebuild was run to link
this standalone copy.

From the project root:

```sh
make              # runtime plus public parser bundle
make runtime      # runtime only
make test         # builds the runtime if necessary, then runs tests
```

The link command runs inside `runtime/`:

```sh
cc -O2 cake-ident.S basis_ffi.c -DEVAL -o ../cake-ast-parse-ident -lm
```

The assembly and FFI C source are sufficient; no CakeML/HOL checkout or compiler
bootstrap is needed. A C compiler, x86-64 Linux system loader, libc and libm are
required. Source basenames matter for reproducing assertion strings in the binary.

Start the executable from the project root, where `config_enc_str.txt` and
`repl_boot.cml` live. Test tools do this automatically and default to
`CML_HEAP_SIZE=16384` (MiB), allowing an explicit environment override.
`candle_boot.ml` supports the optional built-in `--candle` mode; the new parser
is loaded into `--repl`, not installed as a replacement REPL parser.

## Exact assembly adjustment

The **only** change from the newest supplied assembly is
`DATA_BUFFER_SIZE`: 65,536 → 16,777,216 bytes. The code buffer remains
5,242,880 bytes. This is the bitmap installation buffer, not the ordinary heap.

The original buffer exhausted during source loading: one compiled chunk needed
1,240 words, while only 962 remained. GDB confirmed the ordinary heap was
already 16 GiB; increasing it could not enlarge this separate buffer. The new
buffer supplies headroom, not a measured minimum. No parser/runtime semantics
or original upstream source was changed by this adjustment.

| Artifact | SHA-256 |
| --- | --- |
| New original bootstrap assembly | `520711aab3983c74b24382af6cb9190b8c5cc366e3319f45adad3fdf4b2a6b2f` |
| Included adjusted `cake-ident.S` | `2fdd9a64ca6586db07adb32c99a56f956e425b56865839c22002f423a308049d` |
| Included `basis_ffi.c` | `ca80a94c7269208bd169b8cf54c60c498f6194b0669b590be565ca929bef301c` |
| Matching configuration | `3f29f536ae734b28c15d0adac8be9397b5c7f020fa3f5529a18a9daf6e4caa70` |
| Built executable | `621d9552aef15cde336b82c16e94223d136954212eb5e60f8c0221195b9b2df6` |
| Matching `repl_boot.cml` | `a2caba62066d19ac11fe54cdf4bf24701e1e953e0ac404b8fdc567955bff8554` |
| Matching `candle_boot.ml` | `a70784a8def58d511a9ddde408ec9f3aee67fad4817f8d9d25e5cd5beb8615ef` |

September's relocated, cache-free check rebuilt the previous executable
byte-for-byte and passed its then-current suites. That historical result does
not validate this M6 refresh. The 2026-10-03 cache-free source export also
reproduced the current binary byte-for-byte and passed the complete M7 test
campaign; see `../STANDALONE.md`.
Different compiler/platform versions
may change binary bytes; structural parser goldens remain the correctness test.
Compiled executables are ignored, not committed.

## Configuration and reference history

Mixing an old configuration with the new assembly previously segfaulted after
the REPL banner. The matching configuration above works. Old executables,
assembly and configuration remain only in the original development workspace;
they are not required or versioned here. Do not substitute them into this build.

`../SOURCES.tsv` records the current reference hashes, including the changed
Ast ABI and converters. Its frozen `reference/` corpus rows describe historical
snapshots, not the migrated active boot files. September's Ident/overload-only
source comparison does not establish the current M6 reference identity.
Original proof sources remain external, read-only reference material.
