#!/usr/bin/env python3
"""Run shared unit guards and native reuse/retention on the current CI host."""
import argparse
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--zig", default="zig")
    parser.add_argument("--target", help="Explicit Zig target when the bootstrap tool is emulated")
    args = parser.parse_args()
    checkout = Path(__file__).resolve().parents[2]
    compiler = args.compiler.resolve(strict=True)
    command = [args.zig, "build", "test-fast-local-compilation",
               "-Doptimize=ReleaseFast", "-Dtest-optimize=Debug", "-Dcpu=baseline", "--summary", "all"]
    if args.target:
        command.append("-Dtarget=" + args.target)
    subprocess.run(command, cwd=checkout / "Toolchain", check=True)
    # Every source-compiling CLI invocation shares the workspace above the repo.
    subprocess.run([sys.executable, str(checkout / "Toolchain/Tools/VerifyCacheRetention.py"),
                    str(compiler)], cwd=checkout.parent, check=True)


if __name__ == "__main__":
    main()
