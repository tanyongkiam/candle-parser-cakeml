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


def boundaries():
    # Exercise lexer branches through the public parser, not just bare-token
    # fixtures. Inputs only: acceptance, errors and locations come from HOL.
    cases = []
    for byte in (0, 1, 8, 9, 10, 13, 31, 32, 34, 39, 92, 126, 127, 128, 254, 255):
        char = chr(byte)
        literal = '\\' + char if char in '\\"' else char
        cases.append((f'boundary-string-byte-{byte}',
                      'let result = "' + literal + '";;'))
    for i, escape in enumerate((r'\\', r'\"', r"\'", r'\n', r'\r', r'\t',
                                r'\b', '\\ ', r'\000', r'\001', r'\254', r'\255',
                                r'\256', r'\999', r'\x00', r'\xff', r'\xFF',
                                r'\x0', r'\xgg', r'\o000', r'\o377', r'\o400',
                                r'\o77', r'\q')):
        cases.append((f'boundary-string-escape-{i}',
                      'let result = "' + escape + '";;'))
        cases.append((f'boundary-char-escape-{i}',
                      "let result = '" + escape + "';;"))
    for i, number in enumerate(('0', '0Xff', '0O377', '0B101', '0x', '0o', '0b',
                                '0x_1', '0o8', '0b2', '1_', '1__2', '123l',
                                '123L', '123n', '0xffL', '1.', '1._', '1..2',
                                '1e', '1e+', '1e-2', '1E+2_3', '1.2e-3',
                                '123456789012345678901234567890')):
        cases.append((f'boundary-number-{i}', 'let result = ' + number + ';;'))
    for i, whitespace in enumerate((' ', '\t', '\r\n', '\n\n', '\v', '\f')):
        cases.extend([
            (f'boundary-whitespace-success-{i}',
             whitespace + 'let' + whitespace + 'result = 1;;'),
            (f'boundary-whitespace-error-{i}',
             whitespace + 'let result = ;;'),
        ])
    comments = ('(**)', '(* outer (* inner *) tail *)', '(*\n(*\n*)\n*)',
                '(* " ;; *)', '(*', '(*)', '(* (* *)', '*)')
    for i, comment in enumerate(comments):
        cases.append((f'boundary-comment-{i}', comment + '\nlet result = 1;;'))
    for i, source in enumerate(('let result = "unfinished', "let result = '",
                                'let result = 1;;\x00', 'let result = 1;;\xff',
                                'let result = [1;2', 'let result = (1,2',
                                'module A = struct let result = 1',
                                'let result = "a\nb";;\nlet = ;;',
                                'let result = "(*CML not a pragma *) ;;";;',
                                '(*cml ordinary comment *) let result = 1;;')):
        cases.append((f'boundary-eof-or-trailing-{i}', source))
    # Small explicit bounds keep the reference computation practical. These
    # check shape/locations at scale, not a performance or stack-safety claim.
    for depth in (1, 8, 4):
        expression = '(' * depth + 'x' + ')' * depth
        cases.append((f'boundary-parentheses-{depth}',
                      'let result = ' + expression + ';;'))
        cases.append((f'boundary-parentheses-missing-close-{depth}',
                      'let result = ' + expression[:-1] + ';;'))
    for size, identifier_size in zip((1, 2, 3), (1, 16, 64)):
        cases.append((f'boundary-list-{size}',
                      'let result = [' + ';'.join(map(str, range(size))) + '];;'))
        cases.append((f'boundary-identifier-{identifier_size}',
                      'let ' + 'x' * identifier_size + ' = 1;;'))
    for i, (left, right) in enumerate((('+', '*'), ('::', '@'), ('&&', '||'),
                                     ('+', '='), ('^', '='), ('o', 'THEN'),
                                     (':=', '||'), ('**', '*'))):
        for j, (a, b) in enumerate(((left, right), (right, left))):
            cases.append((f'boundary-mixed-operators-{i}-{j}',
                          f'let result = a {a} b {b} c;;'))
    return cases


def coverage_controls():
    # Clause-by-clause M7 cross-check found gaps in signature branches and
    # typed bindings. These are source inputs, not assumed successes: HOL
    # independently decides acceptance, exact lowering and error precedence.
    return [
        ('coverage/module-alias', 'module Mod = Other;;'),
        ('coverage/module-empty', 'module Mod = struct end;;'),
        ('coverage/module-expression', 'module Mod = struct 1;; let x = 2;; x + 3 end;;'),
        ('coverage/module-ascribed', 'module Mod : (sig val x:int end) = struct let x=1;; end;;'),
        ('coverage/module-ascribed-path', 'module Mod : (Other.Signature) = struct end;;'),
        ('coverage/signature-empty', 'module type SS = sig end;;'),
        ('coverage/signature-parenthesized', 'module type SS = (sig end);;'),
        ('coverage/signature-path', 'module type SS = Other.Signature;;'),
        ('coverage/signature-val-semis', 'module type SS = sig val x:int;; val y:bool;; end;;'),
        ('coverage/signature-type', "module type SS = sig type 'a t = Box of 'a end;;"),
        ('coverage/signature-exception', 'module type SS = sig exception Boom of int end;;'),
        ('coverage/signature-exception-record', 'module type SS = sig exception Boom of {x:int} end;;'),
        ('coverage/signature-module-abstract', 'module type SS = sig module type Inner end;;'),
        ('coverage/signature-module-assigned', 'module type SS = sig module type Inner = sig end end;;'),
        ('coverage/signature-module-ascribed', 'module type SS = sig module type Inner : sig end end;;'),
        ('coverage/signature-functor-one', 'module type SS = sig module type Inner (Arg:SS) : SS end;;'),
        ('coverage/signature-functor-two', 'module type SS = sig module type Inner (Arg:SS) (More:SS) : SS end;;'),
        ('coverage/signature-open-include', 'module type SS = sig open Other;; include More end;;'),
        ('coverage/signature-missing-val-type', 'module type SS = sig val x: end;;'),
        ('coverage/signature-missing-end', 'module type SS = sig val x:int;;'),
        ('coverage/typed-function', 'let f = fun x : int -> x;;'),
        ('coverage/typed-let-function', 'let f x : int = x;;'),
        ('coverage/typed-letrec-function', 'let rec f x : int = f x;;'),
        ('coverage/typed-letrec-local', 'let result = let rec f x : int = f x in f;;'),
        ('coverage/typed-let-local', 'let result = let f x : int = x in f;;'),
        ('coverage/array-update', 'let result = a.(i) <- v;;'),
        ('coverage/string-update', 'let result = s.[i] <- c;;'),
        ('coverage/empty-begin', 'let result = begin end;;'),
        ('coverage/if-unit-else', 'let result = if p then f x;;'),
        ('coverage/semis-only', ';;;;'),
        ('coverage/multiple-expressions', '1;; let x=2;; x+3;;'),
        ('coverage/quotation-unsupported', 'let result = `quoted`;;'),
        ('coverage/file-directive-unsupported', '#use "missing-file";;'),
    ]


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
    public += generated() + boundaries() + coverage_controls()
    print('val expanded_public_cases = [')
    print(',\n'.join('(' + ','.join(map(quoted, row)) + ')' for row in public))
    print('];')
    print(f'(* Counts: {len(cases)} inherited layer inputs; {len(public)} public inputs. *)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
