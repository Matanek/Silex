#!/usr/bin/env python3
"""Run shared unit guards and native reuse/retention on the current CI host."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--zig", default="zig")
    parser.add_argument("--target", help="Explicit Zig target when the bootstrap tool is emulated")
    parser.add_argument("--initial-compile-timeout", type=float, default=60)
    parser.add_argument("--cold-link-cache", action="store_true",
                        help="Measure the consumer bank with a fresh, disposable SDK cache")
    args = parser.parse_args()
    if args.initial_compile_timeout <= 0:
        parser.error("--initial-compile-timeout must be positive")
    checkout = Path(__file__).resolve().parents[2]
    compiler = args.compiler.resolve(strict=True)
    command = [args.zig, "build", "test-fast-local-compilation",
               "-Doptimize=ReleaseFast", "-Dtest-optimize=Debug", "-Dcpu=baseline", "--summary", "all"]
    if args.target:
        command.append("-Dtarget=" + args.target)
    subprocess.run(command, cwd=checkout / "Toolchain", check=True)
    # Every source-compiling CLI invocation shares the workspace above the repo.
    subprocess.run([sys.executable, str(checkout / "Toolchain/Tools/VerifyCacheProcess.py")],
                   cwd=checkout.parent, check=True)
    bank = [sys.executable, str(checkout / "Toolchain/Tools/VerifyCacheRetention.py"),
            str(compiler), "--initial-compile-timeout", str(args.initial_compile_timeout)]
    if args.cold_link_cache:
        with tempfile.TemporaryDirectory(prefix="silex-cold-link-") as directory:
            subprocess.run(bank, cwd=checkout.parent, check=True,
                           env=dict(os.environ, ZIG_GLOBAL_CACHE_DIR=directory))
            files = [path for path in Path(directory).rglob("*") if path.is_file()]
            compatibility = [str(path) for path in files
                             if path.name in {"libmingw32.lib", "libmingwex.lib", "compiler_rt.lib"}]
            assert not compatibility, compatibility
            print(json.dumps({"cold_link_sdk_bytes": sum(path.stat().st_size for path in files),
                              "cold_link_sdk_files": len(files),
                              "compatibility_archives": compatibility}), flush=True)
    else:
        subprocess.run(bank, cwd=checkout.parent, check=True)


if __name__ == "__main__":
    main()
