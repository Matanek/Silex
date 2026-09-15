#!/usr/bin/env python3
"""LLVM executable-cache regression; run from SilexProject with a built CLI.

Uses the shared workspace cache and temporary source/output files. Requires the
managed LLVM tools on macOS ARM64. Assertions concern work skipped and program
output, never a machine-dependent duration threshold.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="silex-cli-cache-") as directory:
        root = Path(directory)
        source = root / "Main.sx"
        source.write_text('func main() { print(41) }\n')
        trace = root / "trace.json"
        executable = root / "program"
        env = dict(os.environ, SILEX_COMPILATION_TRACE=str(trace),
                   SILEX_USER_PACKAGE_ALLOWLIST="STD")

        def compile_case(label, expected, backend="llvm", mode="release", extra=()):
            result = subprocess.run([str(compiler), "compile", str(source),
                                     "--backend", backend, "--" + mode,
                                     "-o", str(executable), *extra],
                                    env=env, capture_output=True, text=True, check=True)
            assert not result.stdout and not result.stderr, result
            report = json.loads(trace.read_text())
            assert report["cache_result"] == expected, (label, report)
            if expected == "hit_before_frontend":
                for phase in ("frontend_total", "optimization", "lowering", "emission", "linking"):
                    assert next(p for p in report["phases"] if p["name"] == phase)["invocations"] == 0, (label, phase, report)
            output = subprocess.run([str(executable)], capture_output=True, text=True, check=True)
            assert output.stdout.strip() == str(value), (label, output)
            print(label + ": " + expected, flush=True)
            return report

        value = 41
        compile_case("initial LLVM Release", "miss")
        compile_case("unchanged LLVM Release", "hit_before_frontend")
        compile_case("separate Debug artifact", "miss", mode="debug")
        compile_case("unchanged LLVM Debug", "hit_before_frontend", mode="debug")
        compile_case("separate native artifact", "miss", backend="native")
        compile_case("native discovery preserves LLVM reuse", "hit_before_frontend")
        source.write_text('func main() { print(42) }\n')
        value = 42
        compile_case("changed source invalidates", "miss")
        compile_case("changed source now cached", "hit_before_frontend")
        compile_case("nocache bypasses executable", "disabled", extra=("--nocache",))
        dependency = root / "Helper.sx"
        dependency.write_text('public func answer() int { return 42 }\n')
        source.write_text('use Module.Helper.answer\nfunc main() { print(answer()) }\n')
        compile_case("new dependency graph", "miss")
        compile_case("unchanged dependency graph", "hit_before_frontend")
        dependency.write_text('public func answer() int { return 43 }\n')
        value = 43
        compile_case("changed imported source invalidates", "miss")
        compile_case("changed dependency now cached", "hit_before_frontend")
        (root / "Package.json").write_text('{"sources":"."}\n')
        compile_case("new ancestor manifest invalidates", "miss")
        compile_case("unchanged manifest cached", "hit_before_frontend")
        # IR requests must not disappear behind an early executable hit.
        for _ in range(2):
            result = subprocess.run([str(compiler), "run", str(source), "--backend", "llvm",
                                     "--release", "--emit-ir"], env=env,
                                    capture_output=True, text=True, check=True)
            report = json.loads(trace.read_text())
            assert report["cache_result"] == "hit_after_frontend", report
            assert next(p for p in report["phases"] if p["name"] == "frontend_total")["invocations"] > 0, report
            assert "func @main(" in result.stdout and result.stdout.endswith("43\n"), result
        print("cached run preserves --emit-ir", flush=True)


if __name__ == "__main__":
    main()
