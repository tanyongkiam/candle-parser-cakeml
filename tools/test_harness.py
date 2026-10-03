#!/usr/bin/env python3
"""Unit checks for diagnostic discrimination, independent of the CakeML parser."""
import unittest
import sys
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from run_tests import DIAGNOSTIC, MARKER, MARKER_LINE, main, run
from load_parser import program as public_program, ROOT
from expand_cases import boundaries, coverage_controls, decode_string, quoted


class Diagnostics(unittest.TestCase):
    def test_real_diagnostics(self):
        for prefix in ['', '> ', '> # # ', '  ']:
            for message in ['ERROR: Type mismatch', 'TEST_FAILED: x', 'EXCEPTION: <exn>',
                            'Compilation interrupted', 'Parsing failed']:
                with self.subTest(prefix=prefix, message=message):
                    self.assertIsNotNone(DIAGNOSTIC.search(prefix + message + '\n'))

    def test_quoted_data(self):
        for message in ['ERROR:', 'TEST_FAILED:', 'EXCEPTION:', 'Compilation interrupted']:
            self.assertIsNone(DIAGNOSTIC.search(f'> # val source = "{message}": string\n'))

    def test_marker_must_be_printed(self):
        self.assertIsNotNone(MARKER_LINE.search('> # CANDLE_PARSER_TESTS_OK\n> '))
        self.assertIsNone(MARKER_LINE.search('val source = "CANDLE_PARSER_TESTS_OK": string\n'))

    def test_runtime_selection(self):
        executable = Path('/example/runtime/cake')
        runtime_dir = Path('/example/matching-support-files')
        result = SimpleNamespace(returncode=0, stdout=MARKER + '\n')
        with patch('run_tests.subprocess.run', return_value=result) as launch:
            self.assertEqual(run([], [], 1, executable=executable,
                                 runtime_dir=runtime_dir), 0)
        self.assertEqual(launch.call_args.args[0], [str(executable), '--repl'])
        self.assertEqual(launch.call_args.kwargs['cwd'], runtime_dir)

    def test_successful_exit_and_marker_do_not_hide_failures(self):
        for diagnostic in ['TEST_FAILED: wrong AST', 'TEST_FAILED: wrong error location',
                           'ERROR: Type mismatch', 'EXCEPTION: <exn>']:
            result = SimpleNamespace(returncode=0, stdout=diagnostic + '\n' + MARKER + '\n')
            with self.subTest(diagnostic=diagnostic), \
                    patch('run_tests.subprocess.run', return_value=result), \
                    redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(run([], [], 1), 1)

    def test_completion_requires_printed_marker_and_successful_exit(self):
        for status, output in [(0, ''), (0, 'val source = "' + MARKER + '": string\n'),
                               (1, MARKER + '\n')]:
            result = SimpleNamespace(returncode=status, stdout=output)
            with self.subTest(status=status, output=output), \
                    patch('run_tests.subprocess.run', return_value=result), \
                    redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(run([], [], 1), 1)

    def test_boundary_input_transport(self):
        inputs = boundaries() + coverage_controls()
        self.assertEqual(len(inputs), len(set(name for name, _ in inputs)))
        self.assertEqual(inputs, boundaries() + coverage_controls())
        for name, source in inputs:
            with self.subTest(name=name):
                self.assertEqual(decode_string(quoted(source)), source)

    def test_reader_suite_keeps_parser_private(self):
        result = SimpleNamespace(returncode=0, stdout=MARKER + '\n')
        with patch.object(sys, 'argv', ['run_tests.py', '--suite', 'reader']), \
                patch('run_tests.subprocess.run', return_value=result) as launch, \
                redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            self.assertEqual(main(), 0)
        source = launch.call_args.kwargs['input']
        parser = public_program()
        reader = (ROOT / 'src' / 'reader.cml').read_text()
        self.assertTrue(source.startswith(parser + '\n' + reader))
        self.assertEqual(source.count('structure CandleReader = struct'), 1)
        self.assertIn((ROOT / 'tests' / 'reader.cml').read_text(), source)
        self.assertNotIn('reader.cml', (ROOT / 'sources.list').read_text())


if __name__ == '__main__':
    unittest.main()
