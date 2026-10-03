#!/usr/bin/env python3
"""Check actual #use loading and private-module visibility in a fresh REPL."""
import os
import pathlib
import re
import subprocess
import tempfile
import unittest

from load_parser import ROOT, program, sources
from run_tests import DIAGNOSTIC, DEFAULT_EXECUTABLE, DEFAULT_RUNTIME_DIR


class Bundle(unittest.TestCase):
    def test_private_bundle(self):
        modules = sorted(set(re.findall(r'^structure (Candle\w+) = struct',
            '\n'.join(p.read_text() for p in sources()[:-1]), re.M)))
        self.assertEqual(len(modules), 18)
        # The temporary bundle has no dependencies on its own directory.
        with tempfile.TemporaryDirectory(prefix='candle-public-bundle-') as tmp:
            bundle = pathlib.Path(tmp) / 'parser.cml'
            bundle.write_text(program())
            source = f'#use "{bundle}";\n'
            source += '\n'.join(f'open {name};' for name in modules)
            source += '''
val _ = if CandleParser.parse "let id x = x;;" =
  Inr [Ast.Dlet (Ast.Locs (0,0) (0,11))
    (Ast.Pvar "id") (Ast.Fun "x" (Ast.Ident (Ast.Short "x")))]
  then () else raise Fail "public identity mismatch";
val _ = case CandleParser.Locs CandleParser.Unknownpt CandleParser.Eofpt of
    CandleParser.Locs CandleParser.Unknownpt CandleParser.Eofpt => ()
  | _ => raise Fail "public error-location pattern mismatch";
val _ = if CandleParser.Unknownpt <> CandleParser.Eofpt then ()
  else raise Fail "public error-location distinction lost";
val _ = print "PRIVATE_BUNDLE_OK\\n";
'''
            env = dict(os.environ)
            env.setdefault('CML_HEAP_SIZE', '16384')
            result = subprocess.run([str(DEFAULT_EXECUTABLE.resolve()), '--repl'],
                cwd=DEFAULT_RUNTIME_DIR.resolve(), env=env, input=source, text=True, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, timeout=120)
        output = result.stdout
        self.assertEqual(result.returncode, 0, output[-3000:])
        self.assertRegex(output, r'(?m)^[ \t]*(?:[>#][ \t]*)*PRIVATE_BUNDLE_OK\r?$')
        diagnostics = [line for line in output.splitlines() if DIAGNOSTIC.search(line)]
        self.assertEqual(len(diagnostics), len(modules), '\n'.join(diagnostics))
        self.assertEqual(re.findall(r'Undefined module: (Candle\w+)', '\n'.join(diagnostics)), modules)
        exports = re.findall(r'\bval (Candle\w+)\.(\w+) =', output)
        self.assertIn(('CandleParser', 'parse'), exports)
        allowed = {('CandleParser', name) for name in
                   ('parse', 'Posn', 'Unknownpt', 'Eofpt', 'Locs')}
        # The REPL itself adds pretty-printers for the exported error datatypes.
        # These are not authored parser helpers escaping the local bundle.
        allowed |= {('CandleParser', 'pp_locn'), ('CandleParser', 'pp_locs')}
        self.assertTrue(set(exports) <= allowed, exports)

    def test_development_bundle(self):
        self.assertEqual(program(internals=True), '\n'.join(p.read_text() for p in sources()))


if __name__ == '__main__':
    unittest.main()
