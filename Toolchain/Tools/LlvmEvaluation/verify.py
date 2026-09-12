#!/usr/bin/env python3
"""Verify the bounded LLVM backend against exact native observables and refusals."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in [
        "native", "adapter", "shadercross", "llvm-dir", "sdk", "output-dir", "report",
    ]:
        parser.add_argument("--"+name, required=True)
    args = parser.parse_args()
    root = Path.cwd()
    corpus = root / "Silex/Toolchain/Benchmarks/Optimizer"
    output = Path(args.output_dir).resolve()
    output.mkdir(parents=True, exist_ok=True)
    report = Path(args.report).resolve()
    driver = Path(__file__).with_name("compile.py")
    env = os.environ.copy()
    env.update(ZIG_GLOBAL_CACHE_DIR=str(root/".zig-global-cache"), ZIG_LOCAL_CACHE_DIR=str(root/".zig-cache"))
    records = []

    def call(name, command):
        started = time.monotonic()
        process = subprocess.run([str(x) for x in command], env=env, capture_output=True, text=True, timeout=180)
        record = dict(name=name, argv=[str(x) for x in command], returncode=process.returncode,
                      stdout=process.stdout, stderr=process.stderr, seconds=time.monotonic()-started)
        records.append(record)
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps(records, indent=2)+"\n")
        return record

    def llvm_command(path, mode, binary, silex_prefix="none"):
        return [sys.executable, driver, "--backend", "llvm", "--source", path,
                "--adapter", args.adapter, "--shadercross", args.shadercross,
                "--silex-prefix", silex_prefix,
                "--llvm-dir", args.llvm_dir, "--sdk", args.sdk,
                "--opt", mode, "--output", binary]

    cases = {
        "LlvmEvaluation/Rounding.sx": "true\n",
        "Regressions/BoundedCollectionLoop.sx": "1056000000\n2\n",
        "ReferenceAliasing.sx": "38\n29\n",
        "OwningCollectionCopy.sx": "true\ntrue\n",
        "LlvmEvaluation/Lifetime.sx": "150015000\ntrue\n",
        "LlvmEvaluation/Overflow.sx": "7\n",
        "LlvmEvaluation/Bounds.sx": "7\n",
        "LlvmEvaluation/NegativeBounds.sx": "7\n",
        "LlvmEvaluation/DivisionByZero.sx": "7\n",
        "LlvmEvaluation/Conversion.sx": "7\n",
        "LlvmEvaluation/SteeringWorkload.sx": "1000000\ntrue\n",
    }
    for relative, expected_stdout in cases.items():
        source = (corpus/relative).resolve()
        expected = None
        for mode in ["debug", "release", "O0", "O3"]:
            binary = output/(source.stem+"-"+mode)
            command = ([args.native, "compile", source, "--"+mode, "--nocache", "--output", binary]
                       if mode in ["debug", "release"] else llvm_command(source, mode, binary))
            built = call(source.stem+"-compile-"+mode, command)
            assert built["returncode"] == 0, built
            run = call(source.stem+"-run-"+mode, [binary])
            observable = {key: run[key] for key in ["returncode", "stdout", "stderr"]}
            assert run["stdout"] == expected_stdout, run
            assert run["returncode"] == (1 if source.stem in ["Overflow", "Bounds", "NegativeBounds", "DivisionByZero", "Conversion"] else 0), run
            if expected is None:
                expected = observable
            else:
                assert observable == expected, (source, mode, expected, observable)
            print(source.stem, mode, "PASS", flush=True)

    for relative in ["LlvmEvaluation/Rounding.sx", "ReferenceAliasing.sx", "OwningCollectionCopy.sx", "LlvmEvaluation/Lifetime.sx"]:
        interpreted = call("interpreter-"+Path(relative).stem, [args.native, "interpret", corpus/relative, "--nocache"])
        assert interpreted["returncode"] == 0 and interpreted["stdout"] == cases[relative], interpreted

    dominance = (corpus/"LlvmEvaluation/CommandsDominance.sx").resolve()
    native_observable = None
    for mode in ["debug", "release"]:
        binary = output/("CommandsDominance-"+mode)
        built = call("CommandsDominance-compile-"+mode,
                     [args.native, "compile", dominance, "--"+mode, "--nocache", "--output", binary])
        assert built["returncode"] == 0, built
        run = call("CommandsDominance-run-"+mode, [binary])
        observable = {key: run[key] for key in ["returncode", "stdout", "stderr"]}
        assert observable == {"returncode": 0, "stdout": "7\n", "stderr": ""}, run
        if native_observable is None:
            native_observable = observable
        else:
            assert observable == native_observable, (native_observable, observable)
    for prefix in ["none", "local_simplification_pre"]:
        target = output/("CommandsDominance-"+prefix+".ll")
        target.write_bytes(b"existing output must survive verifier refusal")
        rejected = call("CommandsDominance-"+prefix, [
            args.adapter, "--backend", "llvm", "--shadercross", args.shadercross,
            "--silex-prefix", prefix, dominance, target,
        ])
        assert rejected["returncode"] != 0, rejected
        assert "DefinitionDoesNotDominateUse" in rejected["stderr"], rejected
        assert target.read_bytes() == b"existing output must survive verifier refusal"
    target = output/"CommandsDominance-ssa_promotion_pre.ll"
    target.write_bytes(b"existing output must survive later refusal")
    canonicalized = call("CommandsDominance-ssa_promotion_pre", [
        args.adapter, "--backend", "llvm", "--shadercross", args.shadercross,
        "--silex-prefix", "ssa_promotion_pre", dominance, target,
    ])
    assert canonicalized["returncode"] != 0, canonicalized
    assert "DefinitionDoesNotDominateUse" not in canonicalized["stderr"], canonicalized
    assert "UnsupportedType" in canonicalized["stderr"], canonicalized
    assert target.read_bytes() == b"existing output must survive later refusal"
    print("COMMANDS DOMINANCE PREFIX ATTRIBUTION PASS", flush=True)

    # The ordinary compiler must accept each refusal witness first.
    for name in ["RefuseString", "RefuseCallback"]:
        source = (corpus/"LlvmEvaluation"/(name+".sx")).resolve()
        native = output/(name+"-native")
        assert call(name+"-native", [args.native, "compile", source, "--debug", "--nocache", "--output", native])["returncode"] == 0
        target = output/(name+"-refused")
        target.write_bytes(b"existing output must survive refusal")
        rejected = call(name+"-llvm", llvm_command(source, "O3", target))
        assert rejected["returncode"] != 0 and "Unsupported" in rejected["stderr"], rejected
        assert target.read_bytes() == b"existing output must survive refusal"
        print(name, "REFUSED before output", flush=True)

    source = (corpus/"LlvmEvaluation/Rounding.sx").resolve()
    native = output/"Rounding-debug"
    before = call("transition-native-before", [native])
    target = output/"cache-rounding"
    first = call("cache-prime", llvm_command(source, "O3", target))
    assert first["returncode"] == 0, first
    second = call("cache-hit", llvm_command(source, "O3", target))
    assert second["returncode"] == 0 and json.loads(second["stdout"])["cache_hit"], second
    llvm_result = call("transition-llvm", [target])
    after = call("transition-native-after", [native])
    for field in ["returncode", "stdout", "stderr"]:
        assert before[field] == llvm_result[field] == after[field]
    o3 = json.loads(second["stdout"])
    o0 = call("cache-other-mode", llvm_command(source, "O0", target))
    assert o0["returncode"] == 0 and json.loads(o0["stdout"])["cache_key"] != o3["cache_key"]
    cached = Path(o3["artifact_directory"])/"program"
    cached.write_bytes(b"intentional cache corruption")
    repaired = call("cache-repair", llvm_command(source, "O3", target))
    assert repaired["returncode"] == 0 and not json.loads(repaired["stdout"])["cache_hit"], repaired
    assert call("cache-repaired-output", [target])["stdout"] == "true\n"
    print("CACHE AND NATIVE/LLVM/NATIVE TRANSITIONS PASS", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
