#!/usr/bin/env python3
"""Bound LLVM test-runner memory growth for a shared, repeatedly scoped body.

Run from SilexProject or a Spec Worktree group. This macOS ARM64 regression
compares one test with 64 tests of the same 1024-operation helper. The many-test
peak may be at most three times the single-test peak; elapsed time is diagnostic.
No package, renderer or native-provider dependency participates in the workload.
"""
import argparse
import json
from pathlib import Path
import platform
import subprocess
import sys
import tempfile


def source(count):
    body = '\n'.join('    value += 1' for _ in range(1024))
    helper = 'func shared(input:int) int {\n    var value = input\n' + body + '\n    return value\n}\n'
    return helper + ''.join(f'test "case {index}" {{ assert(shared({index}) == {index + 1024}) }}\n'
                            for index in range(count))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    root = Path.cwd()
    if not (root / 'Silex/Toolchain').is_dir():
        parser.error('run from SilexProject or a Spec Worktree group')
    if sys.platform != 'darwin' or platform.machine() != 'arm64':
        parser.error('this LLVM memory regression is qualified on macOS ARM64')
    compiler = args.compiler.resolve(strict=True)
    report = args.report.resolve()
    temporary_root = root / '.silex'
    temporary_root.mkdir(exist_ok=True)
    records = []
    with tempfile.TemporaryDirectory(prefix='llvm-test-memory-', dir=temporary_root) as temporary:
        directory = Path(temporary)
        for count in [1, 64]:
            fixture = directory / f'Cases{count}.sx'
            fixture.write_text(source(count))
            measurement = directory / f'Peak{count}.json'
            monitor = (
                'import json,resource,subprocess,sys,time; '
                'started=time.monotonic(); p=subprocess.run(sys.argv[2:]); '
                'open(sys.argv[1],"w").write(json.dumps({"peak_rss_bytes":'
                'resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'
                '"elapsed_seconds":time.monotonic()-started})); '
                'sys.exit(p.returncode if p.returncode>=0 else 128-p.returncode)'
            )
            result = subprocess.run([sys.executable, '-c', monitor, str(measurement),
                                     str(compiler), 'test', str(fixture), '--backend', 'llvm', '--nocache'],
                                    capture_output=True, text=True, timeout=300)
            record = dict(count=count, returncode=result.returncode, stdout=result.stdout,
                          stderr=result.stderr, **json.loads(measurement.read_text()))
            records.append(record)
            report.write_text(json.dumps(records, indent=2) + '\n')
            assert result.returncode == 0 and f'{count} passed; 0 failed\n' in result.stdout, record
            print(f'{count} tests: {record["peak_rss_bytes"] / 1048576:.1f} MiB', flush=True)
    ratio = records[1]['peak_rss_bytes'] / records[0]['peak_rss_bytes']
    print(f'peak ratio: {ratio:.3f}; maximum: 3.000', flush=True)
    if ratio > 3.0:
        raise SystemExit('LLVM per-test compilation storage accumulates across cases')


if __name__ == '__main__':
    main()
