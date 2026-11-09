#!/usr/bin/env python3
"""Verify native reuse and retention after final writes, from the workspace root.

Run alone with a built CLI. Uses the shared cache, temporary sources, and one
old sparse history file. Only small console fixtures are launched; no timing assertions.
"""
import argparse
import hashlib
import json
import os
import signal
from pathlib import Path
import subprocess
import tempfile
import time
import uuid


RESERVE = 320 * 1024 * 1024
ROOTS = ("cache/v4", "cache/shaders", "artifacts/v1", "run", "test", "llvm")


def run_compiler(arguments, env, timeout=60):
    """Keep phase evidence and stop this compiler's descendants on timeout."""
    trace = Path(env["SILEX_COMPILATION_TRACE"])
    trace.unlink(missing_ok=True)
    watched = [trace]
    if "-o" in arguments:
        output = Path(arguments[arguments.index("-o") + 1])
        watched += [output, Path(str(output) + ".silex.o")]
    started = time.monotonic()
    with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
        process = subprocess.Popen(arguments, env=env, stdout=stdout, stderr=stderr,
                                   start_new_session=os.name != "nt")
        expired = False
        try:
            while True:
                remaining = timeout - (time.monotonic() - started)
                try:
                    process.wait(timeout=max(0, min(15, remaining)))
                    break
                except subprocess.TimeoutExpired:
                    sizes = {}
                    for path in watched:
                        try:
                            sizes[str(path)] = path.stat().st_size
                        except OSError:
                            sizes[str(path)] = None
                    print(json.dumps({"compiler_pending_seconds": round(time.monotonic() - started, 3),
                                      "file_bytes": sizes}), flush=True)
                    if time.monotonic() - started >= timeout:
                        expired = True
                        break
        finally:
            if process.poll() is None:
                if os.name == "nt":
                    subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
                else:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                if process.poll() is None:
                    process.kill()
                process.wait(timeout=10)
        stdout.seek(0)
        stderr.seek(0)
        out, err = (stream.read().decode("utf-8", errors="replace").replace("\r\n", "\n")
                    for stream in (stdout, stderr))
    if expired:
        print(json.dumps({"compiler_timeout_seconds": timeout, "stdout_tail": out[-8192:],
                          "stderr_tail": err[-8192:]}), flush=True)
        raise subprocess.TimeoutExpired(arguments, timeout, output=out, stderr=err)
    return subprocess.CompletedProcess(arguments, process.returncode, out, err)


def retained_bytes(cache):
    return sum(path.stat().st_size
               for relative in ROOTS for path in (cache / relative).rglob("*")
               if path.is_file() and not path.is_symlink())


def verify_reuse(compiler, mode, initial_timeout=60):
    """Same-basename consumers must retain hits and invalidate edited imports."""
    with tempfile.TemporaryDirectory(prefix="silex-native-reuse-") as directory:
        root = Path(directory)
        projects = [root / name for name in ("First", "Second")]
        for project, value in zip(projects, (41, 42)):
            project.mkdir()
            (project / "Package.json").write_text('{"sources":"."}\n')
            (project / "Shared.sx").write_text(f"public func answer() int {{ return {value} }}\n")
            (project / "Main.sx").write_text('use Module.Shared.answer\nfunc main() { print(answer()) }\n')
        trace = root / "trace.json"
        env = dict(os.environ, SILEX_COMPILATION_TRACE=str(trace),
                   SILEX_USER_PACKAGE_ALLOWLIST="STD")
        digests = {}

        def compile_case(index, value, expected):
            project = projects[index]
            output = project / ("program.exe" if os.name == "nt" else "program")
            initial = not digests
            started = time.monotonic()
            result = run_compiler([str(compiler), "compile", str(project / "Main.sx"),
                                   "--backend", "native", "--" + mode, "-o", str(output)],
                                  env, timeout=initial_timeout if initial else 60)
            assert result.returncode == 0 and not result.stdout and not result.stderr, result
            report = json.loads(trace.read_text())
            if initial:
                print(json.dumps({"first_native_compile": mode,
                                  "wall_seconds": round(time.monotonic() - started, 6),
                                  "phases": report["phases"]}), flush=True)
            assert report["cache_result"] == expected, report
            digest = hashlib.sha256(output.read_bytes()).digest()
            if expected == "hit_before_frontend":
                assert digest == digests[index]
                assert report["metrics"]["cache_bytes_written"] == 0, report
                for phase in ("frontend_total", "optimization", "lowering", "emission", "linking"):
                    assert next(p for p in report["phases"] if p["name"] == phase)["invocations"] == 0, report
            digests[index] = digest
            actual = subprocess.run([str(output)], capture_output=True, text=True, timeout=60)
            assert actual.returncode == 0 and actual.stdout == str(value) + "\n" and not actual.stderr, actual

        for index, value, expected in ((0, 41, "miss"), (1, 42, "miss"),
                                       (0, 41, "hit_before_frontend"), (1, 42, "hit_before_frontend")):
            compile_case(index, value, expected)
        (projects[0] / "Shared.sx").write_text("public func answer() int { return 43 }\n")
        compile_case(0, 43, "miss")
        compile_case(0, 43, "hit_before_frontend")
        compile_case(1, 42, "hit_before_frontend")
        print(f"native {mode}: A/B hits retained; edited import invalidates only A", flush=True)


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
            result = run_compiler(arguments, env)
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
    parser.add_argument("--initial-compile-timeout", type=float, default=60,
                        help="Diagnostic bound for the first Debug compile; other cases keep 60 seconds")
    args = parser.parse_args()
    if args.initial_compile_timeout <= 0:
        parser.error("--initial-compile-timeout must be positive")
    compiler = args.compiler.resolve(strict=True)
    verify_reuse(compiler, "debug", args.initial_compile_timeout)
    verify_reuse(compiler, "release")
    verify_publication(compiler, "compile")
    verify_publication(compiler, "interpret")
    verify_publication(compiler, "interpret", fail=True)


if __name__ == "__main__":
    main()
