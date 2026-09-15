#!/usr/bin/env python3
"""Run source-loaded CakeML checks; a successful REPL exit is not sufficient."""

import argparse
import os
import pathlib
import re
import subprocess
import sys

from load_parser import program as public_program, sources as candle_sources

ROOT = pathlib.Path(__file__).resolve().parents[1]
MARKER = "CANDLE_PARSER_TESTS_OK"
MARKER_LINE = re.compile(r"(?m)^[ \t]*(?:[>#][ \t]*)*" + MARKER + r"\r?$")
DIAGNOSTIC = re.compile(
    r"(?m)^[ \t]*(?:[>#][ \t]*)*(?:ERROR:|Exception raised|Uncaught|TEST_FAILED:|"
    r"Compilation interrupted|Unable to read file|Parsing failed|EXCEPTION:|<failure:)"
)


def run(sources, tests, timeout, verbose=False, executable=ROOT / "cake-ast-parse-ident",
        source_text=None):
    program = (source_text if source_text is not None else
               "\n".join(path.read_text() for path in sources))
    program += "\n" + "\n".join(path.read_text() for path in tests)
    program += '\nval _ = print "' + MARKER + '\\n";\n'
    env = dict(os.environ)
    # Source compilation runs inside the REPL heap; allow an explicit override.
    env.setdefault("CML_HEAP_SIZE", "16384")
    try:
        result = subprocess.run(
            [str(executable.resolve()), "--repl"],
            cwd=ROOT, env=env, input=program, text=True, stdout=subprocess.PIPE,
            # CakeML strings are bytes; the REPL may print bytes above 127.
            encoding="utf-8", errors="backslashreplace",
            stderr=subprocess.STDOUT, timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        print(f"FAIL: REPL timed out after {timeout}s", file=sys.stderr)
        if exc.stdout:
            print(exc.stdout.decode() if isinstance(exc.stdout, bytes) else exc.stdout)
        return 1
    output = result.stdout
    # The REPL prints bound values, including corpus source strings. Diagnostic
    # words inside those values are data, not errors. Match diagnostic lines,
    # allowing the REPL's repeated primary/continuation prompts before them.
    bad = DIAGNOSTIC.search(output) is not None
    has_marker = MARKER_LINE.search(output) is not None
    if result.returncode or not has_marker or bad:
        print(output)
        print(f"FAIL: REPL status={result.returncode}, marker={has_marker}",
              file=sys.stderr)
        return 1
    if verbose:
        print(output)
    else:
        print(f"PASS: {len(sources)} source files, {len(tests)} test files; {MARKER}")
    return 0


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("--source", action="append", default=[], type=pathlib.Path)
    args.add_argument("--test", action="append", default=[], type=pathlib.Path)
    args.add_argument("--timeout", type=int, default=120)
    args.add_argument("--verbose", action="store_true")
    args.add_argument("--executable", type=pathlib.Path,
                      default=ROOT / "cake-ast-parse-ident")
    args.add_argument("--suite", choices=["lexer", "cakelexer", "cakegrammar", "cakeconversion", "grammar", "conversion", "candle", "all", "public"])
    opts = args.parse_args()
    extra_sources, extra_tests = opts.source, opts.test
    opts.source, opts.test = [], []
    if opts.suite == "public":
        if extra_sources:
            args.error('--suite public cannot add exposed source modules; use --test for extra public checks')
        opts.source = candle_sources()
        opts.test = [ROOT / 'tests' / name for name in
                     ('runtime.cml', 'ast_contract.cml', 'parser_golden.cml',
                      'expanded_golden.cml', 'corpus_golden.cml', 'limits_golden.cml',
                      'public.cml', 'harness_literals.cml')]
    elif opts.suite == "lexer":
        opts.source = [ROOT / "src" / name for name in
                       ("support.cml", "tokens.cml", "lexer.cml")] + opts.source
        opts.test = [ROOT / "tests" / name for name in
                     ("runtime.cml", "lexer_golden.cml", "lexer.cml")] + opts.test
    elif opts.suite in ("cakelexer", "cakegrammar", "cakeconversion"):
        opts.source = [ROOT / "src" / name for name in
                       ("support.cml", "cake_tokens.cml", "cake_lexer.cml")]
        opts.test = [ROOT / "tests" / name for name in
                     ("runtime.cml", "cakelex_golden.cml", "cake_lexer.cml")]
        if opts.suite in ("cakegrammar", "cakeconversion"):
            opts.source += [ROOT / "src" / name for name in
                            ("peg.cml", "tree.cml", "cake_grammar.cml")]
            opts.test += [ROOT / "tests" / name for name in
                          ("cakegrammar_golden.cml", "cake_grammar.cml")]
        if opts.suite == "cakeconversion":
            opts.source += [ROOT / "src" / name for name in
                            ("cake_conversion.cml", "cake_expression_support.cml")]
            opts.test += [ROOT / "tests" / name for name in
                          ("expression_runtime.cml", "cake_conversion_support.cml", "cakeconversion_golden.cml",
                           "cake_conversion.cml", "cakehelper_golden.cml", "cake_expression_support.cml")]
    elif opts.suite in ("grammar", "conversion", "candle", "all"):
        opts.source = [ROOT / "src" / name for name in
                       ("support.cml", "tokens.cml", "lexer.cml", "peg.cml",
                        "tree.cml", "grammar_support.cml", "grammar.cml",
                        "front_end.cml")] + opts.source
        opts.test = [ROOT / "tests" / name for name in
                     ("runtime.cml", "tree_golden.cml", "grammar.cml")] + opts.test
        if opts.suite in ("conversion", "candle", "all"):
            opts.source += [ROOT / "src" / name for name in
                            ("conversion_support.cml", "names.cml", "types.cml",
                             "precedence.cml", "patterns.cml", "type_declarations.cml")]
            opts.test += [ROOT / "tests" / name for name in
                          ("name_golden.cml", "path_golden.cml", "type_golden.cml",
                           "literal_golden.cml", "pattern_golden.cml", "conversion.cml",
                           "record_golden.cml", "ctor_golden.cml", "typedefs_golden.cml",
                           "exception_golden.cml", "unit_golden.cml", "type_declarations.cml",
                           "recordprep_golden.cml", "record_prep.cml")]
        if opts.suite in ("candle", "all"):
            opts.source += [ROOT / "src" / name for name in
                            ("expression_support.cml", "expressions.cml", "declarations.cml", "parser.cml")]
            opts.test += [ROOT / "tests" / name for name in
                          ("expr_golden.cml", "expressions.cml", "decl_golden.cml",
                           "parser_golden.cml", "parser.cml", "harness_literals.cml",
                           "inherited_golden.cml", "expanded_golden.cml", "expanded.cml",
                           "candlehelper_golden.cml", "candle_helpers.cml",
                           "corpus_golden.cml", "limits_golden.cml", "corpus.cml")]
        if opts.suite == "candle":
            opts.test += [ROOT / "tests" / name for name in
                          ("ast_contract.cml", "lexer_golden.cml", "lexer.cml")]
        if opts.suite == "all":
            opts.source += [ROOT / "src" / name for name in
                            ("cake_tokens.cml", "cake_lexer.cml", "cake_grammar.cml",
                             "cake_conversion.cml", "cake_expression_support.cml")]
            opts.test += [ROOT / "tests" / name for name in
                          ("ast_contract.cml", "lexer_golden.cml", "lexer.cml", "cakelex_golden.cml", "cake_lexer.cml",
                           "cakegrammar_golden.cml", "cake_grammar.cml", "expression_runtime.cml",
                           "cake_conversion_support.cml", "cakeconversion_golden.cml", "cake_conversion.cml",
                           "cakehelper_golden.cml", "cake_expression_support.cml")]
    opts.source += extra_sources
    opts.test += extra_tests
    if opts.suite == "candle" and opts.source != candle_sources() + extra_sources:
        raise RuntimeError("Candle runner load order disagrees with sources.list")
    return run(opts.source, opts.test, opts.timeout, opts.verbose, opts.executable,
               source_text=public_program() if opts.suite == 'public' else None)


if __name__ == "__main__":
    sys.exit(main())
