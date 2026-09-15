#!/usr/bin/env python3
"""Emit the Candle-only source bundle to stdout in its authoritative load order."""
import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def sources():
    return [ROOT / 'src' / line for line in
            (ROOT / 'sources.list').read_text().splitlines() if line and not line.startswith('#')]


def program(internals=False):
    paths = sources()
    if not paths or paths[-1].name != 'parser.cml':
        raise ValueError('sources.list must end with the public parser.cml module')
    if internals:
        return '\n'.join(path.read_text() for path in paths)
    private = '\n'.join(path.read_text() for path in paths[:-1])
    public = paths[-1].read_text()
    return ('(* Generated public bundle: only CandleParser escapes this local scope. *)\n'
            'local\n' + private + '\nin\n' + public + '\nend;\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--internals', action='store_true',
                        help='development bundle: expose helper structures for layer tests')
    args = parser.parse_args()
    sys.stdout.write(program(internals=args.internals))
