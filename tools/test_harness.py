#!/usr/bin/env python3
"""Unit checks for diagnostic discrimination, independent of the CakeML parser."""
import unittest
from run_tests import DIAGNOSTIC, MARKER_LINE


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


if __name__ == '__main__':
    unittest.main()
