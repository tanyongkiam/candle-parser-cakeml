#!/usr/bin/env python3
"""Measure source-loaded Candle batches, separately from startup/source loading.

Host wall times include the small REPL command overhead. A zero-iteration batch
measures that overhead separately; do not mistake these for native CPU timings.
"""
import argparse
import json
import os
import pathlib
import resource
import selectors
import statistics
import subprocess
import time

from corpus_inputs import corpus
from expand_cases import quoted
from load_parser import ROOT, program
from run_tests import DIAGNOSTIC


class Repl:
    def __init__(self):
        env = dict(os.environ)
        env.setdefault('CML_HEAP_SIZE', '16384')
        self.proc = subprocess.Popen([str(ROOT / 'cake-ast-parse-ident'), '--repl'],
                                     cwd=ROOT, env=env, stdin=subprocess.PIPE,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        os.set_blocking(self.proc.stdin.fileno(), False)
        os.set_blocking(self.proc.stdout.fileno(), False)
        self.number = 0

    def command(self, source, timeout=120):
        self.number += 1
        marker = f'CANDLE_BENCH_DONE_{self.number}'
        source += '\nval _ = print "' + marker + '\\n";\n'
        pending = memoryview(source.encode())
        output = bytearray()
        started = time.perf_counter()
        with selectors.DefaultSelector() as sel:
            sel.register(self.proc.stdout, selectors.EVENT_READ)
            sel.register(self.proc.stdin, selectors.EVENT_WRITE)
            while True:
                remaining = timeout - (time.perf_counter() - started)
                if remaining <= 0:
                    raise TimeoutError('benchmark phase timed out')
                for key, event in sel.select(min(remaining, 1)):
                    if event == selectors.EVENT_WRITE:
                        n = os.write(key.fd, pending[:4096])
                        pending = pending[n:]
                        if not pending:
                            sel.unregister(key.fileobj)
                    else:
                        data = os.read(key.fd, 65536)
                        if not data:
                            raise RuntimeError('REPL ended: ' + output[-3000:].decode(errors='backslashreplace'))
                        output.extend(data)
                # The marker's printed line, not its occurrence in a bound string.
                if (marker + '\n').encode() in output:
                    text = output.decode(errors='backslashreplace')
                    if DIAGNOSTIC.search(text):
                        raise RuntimeError(text[-5000:])
                    return time.perf_counter() - started

    def close(self):
        self.proc.stdin.close()
        try:
            self.proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.proc.terminate()
            self.proc.wait(timeout=10)


def inputs():
    cases = [(n, s, True) for n, s in corpus()]
    for n in [8, 32, 128]:
        declarations = ''.join(f'let x{i} = f {i};;\n' for i in range(n))
        cases.extend([
            (f'declarations/{n}', declarations, True),
            (f'list/{n}', 'let x = [' + ';'.join(['x'] * n) + '];;', True),
            (f'application/{n}', 'let x = f ' + ' '.join(['x'] * n) + ';;', True),
            (f'parentheses/{n}', 'let x = ' + '(' * n + 'x' + ')' * n + ';;', True),
            (f'comments/{n}', '(*' * n + 'comment' + '*)' * n + 'let x = y;;', True),
            (f'literal/{n * 128}', 'let x = "' + 'a' * (n * 128) + '";;', True),
            (f'late-failure/{n}', declarations + ')', False),
        ])
    return cases


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument('--samples', type=int, default=3)
    args.add_argument('--rounds', type=int, default=3)
    args.add_argument('--min-batch-seconds', type=float, default=0.15,
                      help='calibrate each batch above REPL overhead; 0 disables')
    opts = args.parse_args()
    if opts.samples < 1 or opts.rounds < 1 or opts.min_batch_seconds < 0:
        args.error('samples/rounds must be positive; min-batch-seconds nonnegative')
    cases = inputs()
    started = time.perf_counter()
    repl = Repl()
    try:
        repl.command('')
        startup = time.perf_counter() - started
        load = repl.command(program())
        data = ',\n'.join('(' + quoted(n) + ',' + quoted(s) + ',' +
                          ('True' if ok else 'False') + ')' for n, s, ok in cases)
        definitions = '''
structure CandleBench = struct
  val inputs = Vector.fromList [DATA];
  fun run index rounds =
    let val (name,source,want_success) = Vector.sub inputs index
        fun loop n total = if n = 0 then total else
          case CandleParser.parse source of
            Inr ds => if want_success then loop (n-1) (total + List.length ds)
              else raise Fail ("unexpected success: " ^ name)
          | Inl _ => if want_success then raise Fail ("unexpected failure: " ^ name)
              else loop (n-1) (total-1)
    in print ("CANDLE_BENCH_CHECKSUM " ^ Int.toString (loop rounds 0) ^ "\\n") end;
end;
'''.replace('DATA', data)
        input_load = repl.command(definitions)
        overhead_samples = [repl.command('val _ = CandleBench.run 0 0;') for _ in range(opts.samples)]
        overhead = statistics.median(overhead_samples)
        results = []
        for i, (name, source, ok) in enumerate(cases):
            repl.command(f'val _ = CandleBench.run {i} 1;')  # warmup
            rounds = opts.rounds
            if opts.min_batch_seconds:
                while True:
                    calibration = repl.command(f'val _ = CandleBench.run {i} {rounds};')
                    if calibration >= opts.min_batch_seconds or rounds >= 10000:
                        break
                    rounds = min(rounds * 2, 10000)
            times = [repl.command(f'val _ = CandleBench.run {i} {rounds};')
                     for _ in range(opts.samples)]
            median = statistics.median(times)
            results.append(dict(name=name, bytes=len(source.encode()), success=ok, rounds=rounds,
                                batch_seconds=times, median_batch_seconds=median,
                                estimated_seconds_per_parse=(median-overhead)/rounds
                                    if median > overhead else None,
                                resolution_limited=median <= overhead))
        report = dict(startup_seconds=startup, parser_load_seconds=load,
                      benchmark_input_load_seconds=input_load, zero_batch_seconds=overhead,
                      zero_batch_samples=overhead_samples,
                      samples=opts.samples, minimum_rounds=opts.rounds,
                      minimum_batch_seconds=opts.min_batch_seconds, results=results,
                      timing='host wall batch minus measured zero-batch overhead; not native CPU time',
                      reference_comparison='none: no comparable source-loaded reference executable')
    finally:
        repl.close()
    report['process_peak_rss_kib'] = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
