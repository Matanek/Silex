#!/usr/bin/env python3
"""Verify CLI retention after final writes, from the workspace root.

Run alone with a built CLI. Uses the shared cache, temporary sources, and one
old sparse history file; no native executable is launched. No timing assertions.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import uuid


RESERVE = 320 * 1024 * 1024
ROOTS = ("cache/v4", "cache/shaders", "artifacts/v1", "run", "test", "llvm")


def retained_bytes(cache):
    return sum(path.stat().st_size
               for relative in ROOTS for path in (cache / relative).rglob("*")
               if path.is_file() and not path.is_symlink())


def verify_publication(compiler, command, fail=False):
    cache = Path.cwd() / ".silex"
    history = cache / "cache/v4" / ("retention-probe-" + uuid.uuid4().hex)
    with tempfile.TemporaryDirectory(prefix="silex-cache-retention-") as directory:
        root = Path(directory)
        source, output, trace = root / "Main.sx", root / "program", root / "trace.json"
        (root / "Package.json").write_text('{"sources":"."}\n')
        env = dict(os.environ, SILEX_COMPILATION_TRACE=str(trace),
                   SILEX_USER_PACKAGE_ALLOWLIST="STD")
        arguments = [str(compiler), command, str(source)]
        if command == "compile":
            arguments += ["--backend", "native", "--debug", "-o", str(output)]

        def run(letter):
            # Stay below the source read limit, but make final publication large
            # enough to distinguish pre-backend cleanup from function-exit cleanup.
            text = letter * (768 * 1024)
            failure = '; panic("retention probe failure")' if fail else ""
            source.write_text('func main() { print("' + text + '")' + failure + ' }\n')
            result = subprocess.run(arguments, env=env, capture_output=True,
                                    text=True, timeout=60)
            if fail:
                assert result.returncode == 1, result
                assert result.stderr.endswith("runtime error: retention probe failure\n"), result.stderr
            else:
                assert result.returncode == 0 and not result.stderr, result.stderr
            assert result.stdout == (text + "\n" if command == "interpret" else "")
            return retained_bytes(cache)

        try:
            first, second = run("a"), run("b")
            delta = second - first
            late_bytes = output.stat().st_size if command == "compile" else delta
            assert delta >= late_bytes > 0, (command, first, second, late_bytes)
            # Before final publication the cache fits. Afterwards only the old
            # probe must be evicted; all real preexisting entries still fit.
            history_size = RESERVE - second - delta + late_bytes // 2
            assert history_size > 0, ("working set too large for probe", second, delta)
            identity = (cache / "compiler-identity-v1").read_bytes()
            previous = [path for relative in ROOTS for path in (cache / relative).rglob("*")
                        if path.is_file() and not path.is_symlink()]
            with history.open("xb") as file:
                file.truncate(history_size)
            os.utime(history, (100, 100))
            final = run("c")
            assert (cache / "compiler-identity-v1").read_bytes() == identity
            assert not history.exists(), (command, "final publication left old history", final)
            assert final <= RESERVE, (command, final, RESERVE)
            assert all(path.exists() for path in previous), "unnecessary eviction of real entries"
            if command == "compile":
                digest = hashlib.sha256(output.read_bytes()).digest()
                # The exact executable must remain usable, without new writes or
                # frontend/backend work after retention. Do not execute it.
                assert run("c") == final
                report = json.loads(trace.read_text())
                assert report["cache_result"] == "hit_before_frontend", report
                assert report["metrics"]["cache_bytes_written"] == 0, report
                for phase in ("frontend_total", "optimization", "lowering", "emission", "linking"):
                    assert next(p for p in report["phases"] if p["name"] == phase)["invocations"] == 0, report
                assert hashlib.sha256(output.read_bytes()).digest() == digest
            label = command + (" error exit" if fail else "")
            print(f"{label}: final writes bounded ({final} bytes); real entries retained", flush=True)
        finally:
            history.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    verify_publication(compiler, "compile")
    verify_publication(compiler, "interpret")
    verify_publication(compiler, "interpret", fail=True)


if __name__ == "__main__":
    main()
