#!/usr/bin/env python3
"""Verify a cold Windows ARM64 link with archive initializers, TLS and UCRT."""
import argparse
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
from VerifyCacheRetention import run_compiler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--emit-only", action="store_true")
    parser.add_argument("--cpp-runtime", action="store_true")
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    archive = args.archive.resolve(strict=True)
    checkout = Path(__file__).resolve().parents[2]
    fixture = checkout / "Tests/Target/windows-arm64/WindowsArm64BoundaryProbe"
    # CLI compilation always shares the workspace above the checkout.
    os.chdir(checkout.parent)
    with tempfile.TemporaryDirectory(prefix="silex-windows-startup-") as directory:
        root = Path(directory)
        package = root / "WindowsArm64BoundaryProbe"
        for relative in ("Package.json", "Module/Api.sx", "Tests/BoundaryMain.sx"):
            destination = package / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(fixture / relative, destination)
        if args.cpp_runtime:
            shutil.copyfile(fixture / "Tests/CppMain.sx", package / "Tests/BoundaryMain.sx")
        boundary = package / "Boundary/windows-arm64/BoundaryProbe.lib"
        boundary.parent.mkdir(parents=True)
        shutil.copyfile(archive, boundary)
        if args.cpp_runtime:
            manifest_path = package / "Package.json"
            manifest = json.loads(manifest_path.read_text())
            manifest["boundary"]["windows-arm64"]["providers"]["Native"]["libraries"] = ["stdc++"]
            manifest_path.write_text(json.dumps(manifest))
        trace = root / "trace.json"
        for mode in ("debug", "release"):
            sdk = root / ("sdk-cpp" if args.cpp_runtime else "sdk-" + mode)
            env = dict(os.environ, ZIG_GLOBAL_CACHE_DIR=str(sdk),
                       SILEX_COMPILATION_TRACE=str(trace), SILEX_USER_PACKAGE_ALLOWLIST="STD")
            output = root / (mode + ".exe")
            started = time.monotonic()
            result = run_compiler([str(compiler), "compile", str(package / "Tests/BoundaryMain.sx"),
                                   "--target", "windows-arm64", "--" + mode, "--nocache",
                                   "-o", str(output)], env,
                                  timeout=1800 if args.cpp_runtime else 60)
            assert result.returncode == 0, result
            report = json.loads(trace.read_text())
            data = output.read_bytes()
            pe = struct.unpack_from("<I", data, 60)[0]
            assert data[pe:pe + 4] == b"PE\0\0"
            assert struct.unpack_from("<H", data, pe + 4)[0] == 0xAA64
            tls_rva, tls_size = struct.unpack_from("<II", data, pe + 24 + 112 + 9 * 8)
            assert tls_rva and tls_size == 40
            if not args.cpp_runtime:
                assert b"ucrtbase.dll" in data.lower()
                assert b"msvcrt.dll" not in data.lower()
            files = [path for path in sdk.rglob("*") if path.is_file()]
            if not args.cpp_runtime:
                assert not [path for path in files if path.name in
                            {"libmingw32.lib", "libmingwex.lib", "compiler_rt.lib"}]
            assert not list(root.rglob("*.startup.obj"))
            if not args.emit_only:
                execution = subprocess.run([str(output), "simple", "moteur-été"],
                                           env=dict(env, SILEX_WINDOWS_STARTUP_PROBE="verify"),
                                           capture_output=True, text=True, timeout=20)
                assert execution.returncode == 0, execution
                assert execution.stdout.splitlines() == ["windows arm64 boundary ready",
                                                         "windows arm64 finalized"], execution
            print(json.dumps({"windows_startup": mode, "cpp_runtime": args.cpp_runtime, "executed": not args.emit_only,
                              "wall_seconds": round(time.monotonic() - started, 6),
                              "phases": report["phases"], "sdk_bytes": sum(path.stat().st_size for path in files),
                              "sdk_files": len(files)}), flush=True)


if __name__ == "__main__":
    main()
