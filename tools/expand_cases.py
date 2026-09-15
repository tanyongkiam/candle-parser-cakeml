#!/usr/bin/env python3
"""Extract active Candle HOL tests and produce deterministic oracle inputs.

No candidate parser is imported. Output is SML on stdout; source locations are
provenance, not test identities. Nested comments and SML string gaps are handled.
"""
import argparse
import os
import pathlib
import re
import sys

DEFAULT_CAKEML_ROOT = pathlib.Path(__file__).resolve().parents[2]
STRING = re.compile(r'"(?:[^"\\]|\\.)*"', re.S)


def without_comments(source):
    out = list(source)
    i = 0
    while i < len(source):
        if source[i] == '"':
            match = STRING.match(source, i)
            if not match:
                raise ValueError(f"unterminated string at {i}")
            i = match.end()
        elif source.startswith('(*', i):
            start, depth = i, 1
            i += 2
            while depth:
                if i >= len(source):
                    raise ValueError("unterminated comment")
                if source.startswith('(*', i):
                    depth += 1
                    i += 2
                elif source.startswith('*)', i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            for j in range(start, i):
                if out[j] != '\n':
                    out[j] = ' '
        else:
            i += 1
    return ''.join(out)


def decode_string(literal):
    s, out, i = literal[1:-1], [], 0
    escapes = dict(zip('abtnvfr', '\a\b\t\n\v\f\r'))
    while i < len(s):
        if s[i] != '\\':
            out.append(s[i])
            i += 1
            continue
        i += 1
        c = s[i]
        if c.isspace():
            while i < len(s) and s[i].isspace():
                i += 1
            if i == len(s) or s[i] != '\\':
                raise ValueError("bad SML string gap")
            i += 1
        elif c.isdigit():
            out.append(chr(int(s[i:i + 3])))
            i += 3
        elif c == '^':
            out.append(chr(ord(s[i + 1]) - 64))
            i += 2
        else:
            out.append(escapes.get(c, c))
            i += 1
    return ''.join(out)


def quoted(s):
    return '"' + ''.join('\\' + c if c in '\\"' else
                         f'\\{ord(c):03d}' if ord(c) < 32 or ord(c) >= 127 else c
                         for c in s) + '"'


def inherited(cakeml_root=None):
    root = pathlib.Path(cakeml_root or os.environ.get('CAKEML_ROOT', DEFAULT_CAKEML_ROOT))
    path = root / 'compiler/parsing/ocaml/camlTestsScript.sml'
    if not path.is_file():
        raise FileNotFoundError('HOL test source not found: pass --cakeml-root or set CAKEML_ROOT')
    source = path.read_text()
    clean = without_comments(source)
    quote = r'(?:“([^”]*)”|``([^`]*)``)'
    direct = re.compile(r'\bparsetest0?\s+' + quote + r'\s+' + quote + r'\s*(' + STRING.pattern + ')', re.S)
    cases = []
    for m in direct.finditer(clean):
        nt, conv = m[1] or m[2], m[3] or m[4]
        line = source.count('\n', 0, m.start()) + 1
        cases.append((m.start(), f'camlTests:{line}', nt, conv.split()[0], decode_string(m[5])))
    typed = re.compile(r'\btytest0?\s*(' + STRING.pattern + ')', re.S)
    for m in typed.finditer(clean):
        line = source.count('\n', 0, m.start()) + 1
        cases.append((m.start(), f'camlTests:{line}', 'nType', 'ptree_Type', decode_string(m[1])))
    # Every call-site spelling is accounted for: remaining occurrences are
    # exactly the helper definitions/partial applications at the top of the file.
    occupied = {p for p, *_ in cases}
    remaining = [(source.count('\n', 0, m.start()) + 1, m[0])
                 for m in re.finditer(r'\b(?:parsetest0?|tytest0?)\b', clean)
                 if m.start() not in occupied]
    if remaining != [(55, 'parsetest0'), (123, 'parsetest'), (123, 'parsetest0'),
                     (228, 'tytest0'), (228, 'parsetest0'), (229, 'tytest'), (229, 'parsetest')]:
        raise ValueError(f"unaccounted test calls; audit source changes: {remaining}")
    return [row[1:] for row in sorted(cases)]


def generated():
    # Exhaustive finite products, no randomness or changing external corpus.
    atoms = ['x', 'M.x', '0', 'true', '(f x)', '[x;y]', '(x,y)', 'Some x']
    operators = ['+', '*', '::', '@', '=', '<', '&&', '||', 'o', 'THEN', ':=', '**']
    cases = []
    for i, a in enumerate(atoms):
        for j, op in enumerate(operators):
            b = atoms[(i + j + 1) % len(atoms)]
            c = atoms[(i + j + 3) % len(atoms)]
            cases.append((f'generated-bin-{i}-{j}', f'let result = {a} {op} {b} {op} {c};;'))
    pats = ['x', '_', '(x,y)', 'Some x', 'x::xs', '(x | y)', 'Foo {a;b}']
    for i, p in enumerate(pats):
        for j, a in enumerate(atoms):
            cases.extend([
                (f'generated-fun-{i}-{j}', f'let result = fun ({p}) -> {a};;'),
                (f'generated-match-{i}-{j}', f'let result = match x with {p} when g x -> {a} | _ -> y;;'),
                (f'generated-let-{i}-{j}', f'let ({p}) = {a};;'),
            ])
    seeds = [source for _, source in cases[::8]]
    for i, source in enumerate(seeds):
        for j, cut in enumerate(sorted({0, 1, len(source)//3, len(source)//2, len(source)-1})):
            cases.append((f'mutation-truncate-{i}-{j}', source[:cut]))
        cases.append((f'mutation-junk-{i}', source + ' )'))
        cases.append((f'mutation-delete-{i}', source.replace('=', '', 1)))
        cases.append((f'mutation-comment-{i}', '(* nested (* comment *) *)\n' + source))
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cakeml-root', type=pathlib.Path,
                        help='external CakeML checkout (or CAKEML_ROOT environment variable)')
    args = parser.parse_args()
    cases = inherited(args.cakeml_root)
    print('(* Generated by expand_cases.py; inputs only, not candidate expectations. *)')
    print('val inherited_cases = [')
    print(',\n'.join('(' + ','.join(map(quoted, row)) + ')' for row in cases))
    print('];')
    public = []
    for name, nt, conv, source in cases:
        if '(*CML' in source:
            continue
        if nt in ('nExpr', 'nENeg'):
            public.append((name + '/public', 'let golden_value = (' + source + ');;'))
        elif nt in ('nStart', 'nDefinition'):
            public.append((name + '/public', source + (';;' if nt == 'nDefinition' else '')))
        elif nt == 'nPattern':
            public.append((name + '/public', 'let (' + source + ') = golden_rhs;;'))
        elif nt == 'nType':
            public.append((name + '/public', 'type golden = ' + source + ';;'))
    public += generated()
    print('val expanded_public_cases = [')
    print(',\n'.join('(' + ','.join(map(quoted, row)) + ')' for row in public))
    print('];')
    print(f'(* Counts: {len(cases)} inherited layer inputs; {len(public)} public inputs. *)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
