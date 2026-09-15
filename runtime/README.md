# Runtime build

The repository includes one current runtime source:
`cake-ident.S`, copied from the user's rebuilt CakeML
`compiler/bootstrap/compilation/x64/64/cake.S`, and its matching
`../config_enc_str.txt`. It exposes the real `Ast.Ident` constructor.

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
| New original bootstrap assembly | `aecb0da8f4f87945d4dfb82577d745ff39731bcc2b19e55c0ba7779dc18ef935` |
| Included adjusted `cake-ident.S` | `302d373f63c5b79e2940f1121f315c9d2e58c2cb580640b0f9963ffa9f101f64` |
| Included `basis_ffi.c` | `ca80a94c7269208bd169b8cf54c60c498f6194b0669b590be565ca929bef301c` |
| Matching configuration | `a108fb64b1c7a78ffc24dd2c0b7194e36fba5808e2797b6b6797dec849852ce6` |
| Verified built executable | `b2e35989a1ea1b31f99c6b2fbb92db5f6063f4bd2eeb511ffcbc973e933335fc` |

A relocated, cache-free copy rebuilt the executable byte-for-byte and passed
the complete hidden-bundle/layer tests. Different compiler/platform versions
may change binary bytes; structural parser goldens remain the correctness test.
Compiled executables are ignored, not committed.

## Configuration and reference history

Mixing an old configuration with the new assembly previously segfaulted after
the REPL banner. The matching configuration above works. Old executables,
assembly and configuration remain only in the original development workspace;
they are not required or versioned here. Do not substitute them into this build.

The source manifest's Ast entry was updated for user commit
`7155011a29215f042d266bcc1061919d254766ee`, which changes only
`Overload Var[inferior] = “Ident”` to `Overload Var = “Ident”`.
Its previous source SHA-256 was
`be65aeca4359d9060dd922282da7c299ea0b59d74970d3333fe30a145d9a1921`;
the current hash is
`02fe78a17c585fbea7e2f8add2cd1de713a4a0de3fa0e7e98a047150129ea84f`.
This changes HOL name resolution, not the Ast datatype or parser definitions.
All 23 other read-only source hashes were unchanged at verification. Original
proof sources remain external, read-only reference material.
