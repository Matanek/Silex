#!/usr/bin/env python3
"""Explicit, isolated macOS ARM64 LLVM evaluation; no native fallback."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import time


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def compile_source(args):
    started = time.monotonic()
    root = Path.cwd()
    if not (root / "Silex/Toolchain").is_dir():
        raise RuntimeError("run from SilexProject or the Spec Worktree group root")
    if sys.platform != "darwin" or platform.machine() != "arm64":
        raise RuntimeError("this evaluation is qualified only for macOS ARM64")
    source = Path(args.source).resolve(strict=True)
    adapter = Path(args.adapter).resolve(strict=True)
    format_runtime = Path(args.format_runtime).resolve(strict=True)
    archives = [Path(path).resolve(strict=True) for path in args.archive]
    llvm = Path(args.llvm_dir).resolve(strict=True)
    sdk = Path(args.sdk).resolve(strict=True)
    linker = Path(args.linker).resolve(strict=True)
    output = Path(args.output).resolve()
    cache = root / ".silex/llvm-evaluation/v1"
    cache.mkdir(parents=True, exist_ok=True)
    records = []
    env = os.environ.copy()
    env.update(ZIG_GLOBAL_CACHE_DIR=str(root / ".zig-global-cache"),
               ZIG_LOCAL_CACHE_DIR=str(root / ".zig-cache"))

    with tempfile.TemporaryDirectory(prefix="staging-", dir=cache) as temporary:
        staging = Path(temporary)

        def run(name, argv):
            rss_path = staging / (name + ".rss")
            before = time.monotonic()
            command = [str(x) for x in argv]
            # A fresh Python parent measures exactly this child. Darwin's `time -l`
            # requires an unrelated sysctl that is unavailable in the sandbox.
            monitor = (
                "import json,resource,subprocess,sys; "
                "p=subprocess.run(sys.argv[2:]); "
                "open(sys.argv[1],'w').write(json.dumps({'max_rss_bytes':"
                "resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss})); "
                "sys.exit(p.returncode if p.returncode >= 0 else 128-p.returncode)"
            )
            process = subprocess.run([sys.executable, "-c", monitor, str(rss_path), *command],
                                     capture_output=True, text=True, env=env, timeout=180)
            peak = json.loads(rss_path.read_text()).get("max_rss_bytes") if rss_path.exists() else None
            if not peak:
                peak = None
            record = dict(stage=name, argv=command, seconds=time.monotonic()-before,
                          max_rss_bytes=peak, returncode=process.returncode,
                          stdout=process.stdout, stderr=process.stderr)
            records.append(record)
            if process.returncode:
                raise RuntimeError(json.dumps(record, indent=2))
            return process

        raw = staging / "raw.ll"
        run("compose_translate_serialize", [
            adapter, "--backend", "llvm", "--shadercross", args.shadercross,
            "--silex-prefix", args.silex_prefix,
            source, raw,
        ])
        inputs = dict(backend="llvm-evaluation-v1", driver_sha256=sha(__file__), raw_ir_sha256=sha(raw),
                      source=str(source), source_sha256=sha(source), opt=args.opt,
                      silex_prefix=args.silex_prefix,
                      cpu=args.cpu, triple="arm64-apple-macosx26.0.0", sdk=str(sdk),
                      shadercross=str(Path(args.shadercross).resolve(strict=True)),
                      shadercross_sha256=sha(args.shadercross),
                      sdk_settings_sha256=sha(sdk/"SDKSettings.json"),
                      system_stub_sha256=sha(sdk/"usr/lib/libSystem.tbd"),
                      format_runtime=str(format_runtime), format_runtime_sha256=sha(format_runtime),
                      archives=[dict(path=str(path), sha256=sha(path)) for path in archives],
                      frameworks=args.framework, libraries=args.library,
                      tools={str(p): sha(p) for p in [adapter, llvm/"bin/opt", llvm/"bin/llc",
                             llvm/"lib/libLLVM.dylib", llvm/"lib/libzstd.1.dylib", linker]})
        key = hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()
        destination = cache / key
        cached = destination / "program"
        manifest = destination / "manifest.json"
        hit = False
        if not args.no_cache and cached.is_file() and manifest.is_file():
            prior = json.loads(manifest.read_text())
            hit = prior.get("executable_sha256") == sha(cached) and prior.get("inputs") == inputs
        if not hit:
            level = "0" if args.opt == "O0" else "3"
            optimized = staging / "optimized.ll"
            obj = staging / "program.o"
            executable = staging / "program"
            run("llvm_opt", [llvm/"bin/opt", "-S", "-passes=verify,default<O"+level+">", raw, "-o", optimized])
            run("llvm_codegen", [llvm/"bin/llc", "-filetype=obj", "-O="+level,
                                 "-mtriple=arm64-apple-macosx26.0.0", "-mcpu="+args.cpu,
                                 "-fp-contract=off", optimized, "-o", obj])
            if linker.name == "zig":
                link = [linker, "cc", "-target", "aarch64-macos", "-isysroot", sdk,
                        "-F", sdk/"System/Library/Frameworks", "-L", sdk/"usr/lib",
                        obj, format_runtime, *archives]
            else:
                link = [linker, "-arch", "arm64", "-platform_version", "macos", "26.0", "26.5",
                        "-syslibroot", sdk, "-lSystem", obj, format_runtime, *archives]
            for framework in args.framework:
                link.extend(["-framework", framework])
            link.extend("-l"+library for library in args.library)
            link.extend(["-o", executable])
            run("link", link)
            # Publish the cache entry only after every stage succeeds.
            destination.mkdir(exist_ok=True)
            for item in [raw, optimized, obj, executable]:
                shutil.copy2(item, destination/item.name)
            manifest.write_text(json.dumps(dict(inputs=inputs, stages=records,
                                                executable_sha256=sha(cached)), indent=2)+"\n")
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(cached, output)
        result = dict(backend="llvm", opt=args.opt, cache_hit=hit, cache_key=key,
                      artifact_directory=str(destination), output=str(output),
                      executable_sha256=sha(output), executable_bytes=output.stat().st_size,
                      end_to_end_seconds=time.monotonic()-started, stages=records, inputs=inputs)
        Path(str(output)+".json").write_text(json.dumps(result, indent=2)+"\n")
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backend", choices=["llvm"], required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--adapter", required=True)
    parser.add_argument("--format-runtime", required=True)
    parser.add_argument("--archive", action="append", default=[])
    parser.add_argument("--framework", action="append", default=[])
    parser.add_argument("--library", action="append", default=[])
    parser.add_argument("--shadercross", required=True)
    parser.add_argument("--silex-prefix", default="none")
    parser.add_argument("--llvm-dir", required=True)
    parser.add_argument("--sdk", required=True)
    parser.add_argument("--linker", default="/usr/bin/ld")
    parser.add_argument("--opt", choices=["O0", "O3"], required=True)
    parser.add_argument("--cpu", default="apple-m3")
    parser.add_argument("--output", required=True)
    parser.add_argument("--no-cache", action="store_true")
    try:
        print(json.dumps(compile_source(parser.parse_args()), indent=2))
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print("LLVM evaluation refused: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
