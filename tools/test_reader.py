#!/usr/bin/env python3
"""Real public-parser -> configured reader -> REPL evaluation checks.

Intentional-error sessions check their exact diagnostic trace, never disable
the ordinary harness's diagnostic rejection. Every case uses a fresh runtime.
"""
import os
import re
import selectors
import signal
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

from load_parser import ROOT, program
from run_tests import DEFAULT_EXECUTABLE, DEFAULT_RUNTIME_DIR, DIAGNOSTIC
from expand_cases import quoted

PROMPTS = re.compile(r'^[ \t]*(?:[>#][ \t]*)*')


class Reader(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory(prefix='candle-reader-tests-')
        cls.bundle = Path(cls.directory.name) / 'parser.cml'
        cls.bundle.write_text(program())

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

    def launch(self, candle, setup='', install=True):
        source = (f'#use "{self.bundle}";\n'
                  f'#use "{ROOT / "src/reader.cml"}";\n' + setup)
        if install:
            source += '\nCandleReader.install ();\n'
        env = dict(os.environ)
        env.setdefault('CML_HEAP_SIZE', '16384')
        result = subprocess.run([str(DEFAULT_EXECUTABLE.resolve()), '--repl'],
            cwd=DEFAULT_RUNTIME_DIR.resolve(), env=env, input=source + candle,
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout[-6000:])
        return result.stdout

    def check_trace(self, output, diagnostics=(), markers=()):
        trace = [PROMPTS.sub('', line) for line in output.splitlines()
                 if DIAGNOSTIC.search(line)]
        self.assertEqual(trace, list(diagnostics), output[-6000:])
        for marker in markers:
            self.assertEqual(len(re.findall(
                r'(?m)^[ \t]*(?:[>#][ \t]*)*' + re.escape(marker) + r'\r?$', output)),
                1, output[-6000:])

    def test_evaluation_and_framing(self):
        # The generic CakeML boot does not define these Candle prelude aliases.
        # This test-only environment is not a change to parser lowering.
        output = self.launch(r'''
(* leading ;; (* nested ;; *) comment *)
let id x = x;;
let total = ref 0;;
let text = "a\";; begin struct sig end";;
let pair = (
  1,
  2
);;
type point = Point of {x:int; y:int};;
module Mod = struct
  type payload = Box of int;;
  let boxed = Box 40;;
  module Nested = struct let extra = 2;; end;;
end;;
let Mod.Box number = Mod.boxed;;
let Point {x;y} = Point {y=Mod.Nested.extra; x=number};;
assert (x + y = 42);;
let selected = match Some 3 with Some n when n > 0 -> id n | _ -> 0;;
assert (selected = 3);;
let rec add_to n = if n = 0 then () else (total := !total + n; add_to (n-1));;
add_to 4;;
total := !total + 2;;
assert (!total = 12);;
let handled = try failwith "handled" with Failure _ -> 9;;
assert (handled = 9);;
let updated = Point {Point {x=1;y=2} with x=3};;
let Point {x;y} = updated;;
assert (x = 3 && y = 2);;
print "READER_EVAL_OK\n";;
let saved_reader = Repl.readNextString;;
let saved_error = Repl.errorMessage;;
let saved_exn = Repl.exn;;
module Ast = struct type noise = Noise end;;
module Repl = struct
  let nextInput = ref 0;; let isEOF = ref 0;;
  let readNextString = saved_reader;; let errorMessage = saved_error;;
  let exn = saved_exn;;
end;;
assert (!Repl.nextInput = 0 && !Repl.isEOF = 0);;
assert (id 42 = 42);;
print "READER_SHADOW_OK\n";;
''', setup='val ref = fn x => Ref x;\n'
              'fun assert b = if b then () else raise Failure "assertion failed";\n')
        self.check_trace(output, markers=('READER_EVAL_OK', 'READER_SHADOW_OK'))

    def test_empty_and_residual_eof(self):
        for source, markers in [('', ()), (' \n\r\t', ()),
                                ('print "READER_RESIDUAL_OK\\n"', ('READER_RESIDUAL_OK',))]:
            with self.subTest(source=source):
                self.check_trace(self.launch(source), markers=markers)

    def test_default_cakeml_reader(self):
        # Loading but not installing the optional adapter leaves the old reader.
        self.check_trace(self.launch(
            'val x = 40;\nval y = x + 2;\n'
            'val _ = if y = 42 then print "DEFAULT_READER_OK\\n" '
            'else raise Fail "default reader changed";\n', install=False),
            markers=('DEFAULT_READER_OK',))

    def test_error_recovery_and_rollback(self):
        output = self.launch(r'''
let events = Ref 0;;
events := !events + 1;;
let = ;;
if !events = 1 then print "\nAFTER_PARSE\n" else failwith "stale AST";;
let bad = (events := 999; 1 + "x");;
print "\nAFTER_TYPE\n";;
(events := 999; Tyvar "a");;
print "\nAFTER_CHECK\n";;
let failed = if true then failwith "intentional eval" else 0;;
print "\nAFTER_EVAL\n";;
module Alloc = struct
  type ghost = Ghost;;
  let doomed = if true then failwith "allocation" else 0;;
end;;
let leaked = Alloc.Ghost;;
type after_failure = After_failure;;
if !events = 1 then print "\nAFTER_ALLOC\n" else failwith "corrupt state";;
''')
        self.check_trace(output, diagnostics=(
            'Parsing failed at line 2',
            'ERROR: Type mismatch between int -> int and string -> _4 at line 2',
            'ERROR: input contains reserved constructor/FFI names',
            'EXCEPTION: Failure "intentional eval"',
            'EXCEPTION: Failure "allocation"',
            'ERROR: Undefined constructor: Alloc.Ghost at line 2'),
            markers=('AFTER_PARSE', 'AFTER_TYPE', 'AFTER_CHECK',
                     'AFTER_EVAL', 'AFTER_ALLOC'))
        self.assertEqual(output.count('Expected to be at EOF\nParsing failed at line 2\n\nlet = ;;\n^^^\n'), 1)
        self.assertNotIn('val bad =', output)
        self.assertNotIn('val failed =', output)
        self.assertNotIn('val Alloc.', output)

    def test_reader_exceptions(self):
        first_byte = r'''
val original_input = !CakeML.input1;
val fail_once = Ref True;
fun failing_input () = if !fail_once then
  (fail_once := False; raise Failure "reader first byte") else original_input ();
val _ = (CandleReader.install (); CakeML.input1 := failing_input);
'''
        output = self.launch('print "READER_RETRY_OK\\n";;\n',
                             setup=first_byte, install=False)
        self.check_trace(output, diagnostics=('EXCEPTION: Failure "reader first byte"',),
                         markers=('READER_RETRY_OK',))
        mid_phrase = r'''
val original_input = !CakeML.input1;
fun failing_input () = case original_input () of
  Some c => if c = #"!" then raise Failure "reader mid phrase" else Some c
| None => None;
val _ = (CandleReader.install (); CakeML.input1 := failing_input);
'''
        output = self.launch('(* prefix ! print "UNSAFE_SUFFIX\\n";; *) '
                             'print "AFTER_CANCEL\\n";;\n',
                             setup=mid_phrase, install=False)
        self.check_trace(output, diagnostics=('EXCEPTION: Failure "reader mid phrase"',))
        self.assertNotIn('UNSAFE_SUFFIX', output)
        self.assertNotIn('AFTER_CANCEL', output)

    def test_unfinished_eof_and_unsupported_pragma(self):
        for source in ('let x = "unfinished', '(* unfinished', 'let x = (1',
                       'module Mod = struct let x = 1', 'let x ='):
            with self.subTest(source=source):
                output = self.launch(source)
                self.check_trace(output, diagnostics=('Parsing failed at line 2',))
                self.assertNotIn('val x =', output)
                self.assertNotIn('val Mod.', output)
        output = self.launch('(*CML val x=1; *);;print "CML_RECOVERY_OK\\n";;\n')
        self.check_trace(output, diagnostics=('Parsing failed at line 2',),
                         markers=('CML_RECOVERY_OK',))
        self.assertEqual(output.count('CakeML pragmas are not supported by this Candle-only parser\n'), 1)

    def test_reference_loop_lowering_is_not_repaired(self):
        # Existing lowering calls free for/while identifiers on evaluated
        # expressions, not bound/thunked loop bodies. Preserve it, including
        # diagnostics in this generic environment; grammar/AST goldens remain
        # the independent fidelity test, not an invented runtime loop helper.
        output = self.launch('for i = 1 to 2 do () done;;\n'
                             'while false do () done;;\n'
                             'print "LOOP_FAILURE_RECOVERY_OK\\n";;\n')
        self.check_trace(output, diagnostics=(
            'ERROR: Undefined variable: for at line 2',
            'ERROR: Type mismatch between (_0 -> bool) -> (_0 -> _0) -> _0 -> _0 and bool -> _1 at line 2'),
            markers=('LOOP_FAILURE_RECOVERY_OK',))

    def test_malformed_escape_boundaries(self):
        # EOF would hide an over-read, so make the first phrase's actual next
        # byte raise. Only a completed reader callback unlocks the second one.
        for literal in (r"'\x'", r"'\xG'", r"'\x0'", r"'\x;;", r"'\o4'",
                        r"'\o400'", r"'\o;;", r"'\256'", r"'\1;;", r"'\q'"):
            with self.subTest(literal=literal):
                first = 'let malformed = ' + literal + ('' if literal.endswith(';;') else ';;')
                second = 'print "ESCAPE_RECOVERY_OK\\n";;'
                setup = f'''
val source = {quoted(first + second)};
val position = Ref 0;
val boundary = Ref {len(first)};
fun bounded_input () = if !position = String.size source then None
  else if !position >= !boundary then raise Failure "read past malformed phrase"
  else let val c = String.sub source (!position) in
    position := !position + 1; Some c end;
val _ = (CandleReader.install ();
  let val read = !Repl.readNextString in
    Repl.readNextString := (fn () => (read (); boundary := String.size source));
    CakeML.input1 := bounded_input
  end);
'''
                output = self.launch('', setup=setup, install=False)
                self.check_trace(output, diagnostics=('Parsing failed at line 1',),
                                 markers=('ESCAPE_RECOVERY_OK',))
                self.assertNotIn('val malformed =', output)

    def test_midphrase_sigint(self):
        # A byte-source checkpoint puts the signal inside a real unfinished
        # comment, rather than racing against startup or compiler evaluation.
        setup = r'''
val original_input = !CakeML.input1;
fun observed_input () = case original_input () of
  Some c => (if c = #"!" then print "SIGINT_IN_COMMENT\n" else (); Some c)
| None => None;
val _ = (CandleReader.install (); CakeML.input1 := observed_input);
'''
        source = (f'#use "{self.bundle}";\n'
                  f'#use "{ROOT / "src/reader.cml"}";\n' + setup + '(* prefix !')
        env = dict(os.environ)
        env.setdefault('CML_HEAP_SIZE', '16384')
        process = subprocess.Popen([str(DEFAULT_EXECUTABLE.resolve()), '--repl'],
            cwd=DEFAULT_RUNTIME_DIR.resolve(), env=env, stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        output = bytearray()
        try:
            process.stdin.write(source.encode())
            process.stdin.flush()
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                deadline = time.monotonic() + 120
                while b'SIGINT_IN_COMMENT\n' not in output:
                    remaining = deadline - time.monotonic()
                    self.assertGreater(remaining, 0, output[-3000:].decode(errors='replace'))
                    self.assertTrue(selector.select(remaining), 'reader checkpoint timeout')
                    chunk = os.read(process.stdout.fileno(), 65536)
                    self.assertTrue(chunk, 'reader exited before comment checkpoint')
                    output.extend(chunk)
            process.send_signal(signal.SIGINT)
            # More than the default 1,000 poll calls ensures the actual FFI path
            # sees the signal. No cancelled comment/program suffix may execute.
            tail = (' ' * 2048 + 'print "UNSAFE_SUFFIX\\n";; *) '
                    'print "AFTER_CANCEL\\n";;\n').encode()
            rest, _ = process.communicate(tail, timeout=30)
            output.extend(rest)
            self.assertEqual(process.returncode, 0)
            text = output.decode(errors='backslashreplace')
            self.check_trace(text, diagnostics=('EXCEPTION: Interrupt',),
                             markers=('SIGINT_IN_COMMENT',))
            self.assertNotIn('UNSAFE_SUFFIX', text)
            self.assertNotIn('AFTER_CANCEL', text)
        finally:
            if process.poll() is None:
                process.kill()
            process.communicate()


if __name__ == '__main__':
    unittest.main()
