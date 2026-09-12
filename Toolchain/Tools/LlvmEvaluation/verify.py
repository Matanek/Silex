#!/usr/bin/env python3
"""Verify the bounded LLVM backend against exact native observables and refusals."""
import argparse
import json
import os
from pathlib import Path
import re
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
        "LlvmEvaluation/SystemBoundary.sx": "true\n",
        "LlvmEvaluation/GlobalInventory.sx": "2\n",
        "LlvmEvaluation/OptionalValues.sx": "-1\n41\n-1\n",
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

    system_metadata = json.loads(Path(str(output/"SystemBoundary-O0")+".json").read_text())
    system_llvm = (Path(system_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "declare void @freeaddrinfo(ptr)",
        "declare i32 @arc4random()",
        "declare ptr @__error()",
        "call void @freeaddrinfo(ptr",
    ]:
        assert fragment in system_llvm, fragment
    print("DIRECT SCALAR AND VOID SYSTEM BOUNDARIES PASS", flush=True)

    for relative in ["LlvmEvaluation/Rounding.sx", "ReferenceAliasing.sx", "OwningCollectionCopy.sx", "LlvmEvaluation/Lifetime.sx", "LlvmEvaluation/OptionalValues.sx"]:
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
    boundary_report = output/"CommandsDominance-boundaries.json"
    target.write_bytes(b"existing output must survive later refusal")
    canonicalized = call("CommandsDominance-ssa_promotion_pre", [
        args.adapter, "--backend", "llvm", "--shadercross", args.shadercross,
        "--silex-prefix", "ssa_promotion_pre", "--closure-report", boundary_report,
        dominance, target,
    ])
    assert canonicalized["returncode"] != 0, canonicalized
    assert "DefinitionDoesNotDominateUse" not in canonicalized["stderr"], canonicalized
    assert "class_retain" in canonicalized["stderr"], canonicalized
    assert target.read_bytes() == b"existing output must survive later refusal"
    inventory = json.loads(boundary_report.read_text())
    assert inventory["reachable_direct_boundary_functions"] == 0, inventory
    assert inventory["direct_call_sites"] == 0 and inventory["indirect_call_sites"] == 0, inventory
    print("COMMANDS DOMINANCE PREFIX ATTRIBUTION PASS", flush=True)

    pure_math = (corpus/"Regressions/PureMathReferenceInlining.sx").resolve()
    boundary_report = output/"PureMathReferenceInlining-boundaries.json"
    raw_llvm = output/"PureMathReferenceInlining-raw.ll"
    reported = call("PureMathReferenceInlining-boundary-report", [
        args.adapter, "--backend", "llvm", "--shadercross", args.shadercross,
        "--silex-prefix", "none", "--closure-report", boundary_report,
        pure_math, raw_llvm,
    ])
    assert reported["returncode"] == 0, reported
    inventory = json.loads(boundary_report.read_text())
    assert inventory["boundary_table_size"] > inventory["reachable_direct_boundary_functions"], inventory
    assert inventory["reachable_direct_boundary_functions"] == 1, inventory
    assert inventory["direct_call_sites"] == 1 and inventory["indirect_call_sites"] == 0, inventory
    function = inventory["functions"][0]
    assert function["source_name"] == "sqrtf" and function["supported_by_prototype"], inventory
    print("REACHABLE BOUNDARY INVENTORY PASS", flush=True)

    global_source = (corpus/"LlvmEvaluation/GlobalInventory.sx").resolve()
    target = output/"GlobalInventory-reported.ll"
    closure_report = output/"GlobalInventory-closure.json"
    reported = call("GlobalInventory-closure-report", [
        args.adapter, "--backend", "llvm", "--shadercross", args.shadercross,
        "--silex-prefix", "none", "--closure-report", closure_report,
        global_source, target,
    ])
    assert reported["returncode"] == 0, reported
    inventory = json.loads(closure_report.read_text())
    assert inventory["reachable_global_values"] == 1, inventory
    assert inventory["global_load_sites"] == 2 and inventory["global_store_sites"] == 1, inventory
    global_value = inventory["globals"][0]
    assert global_value["name"] == "LlvmEvaluation.GlobalInventory.State.counter", inventory
    assert global_value["type_name"] == "int" and global_value["bits"] == 1, inventory
    instruction_coverage = {
        entry["name"]: entry for entry in inventory["instruction_coverage"]
    }
    assert inventory["instruction_sites"] > 0, inventory
    assert instruction_coverage["global_load"]["sites"] == 2, inventory
    assert instruction_coverage["global_store"]["sites"] == 1, inventory
    assert instruction_coverage["global_load"]["support"] == "conditional", inventory
    raw_llvm = target.read_text()
    for fragment in [
        "@sx.global.0 = internal global i64 1",
        "load i64, ptr @sx.global.0",
    ]:
        assert fragment in raw_llvm, fragment
    assert re.search(r"store i64 %v\d+, ptr @sx\.global\.0", raw_llvm), raw_llvm
    print("REACHABLE SCALAR GLOBAL EMISSION PASS", flush=True)

    optional_metadata = json.loads(Path(str(output/"OptionalValues-O0")+".json").read_text())
    optional_llvm = (Path(optional_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "{ i1, i64 }",
        "insertvalue { i1, i64 } zeroinitializer, i1 false, 0",
        "insertvalue { i1, i64 } zeroinitializer, i1 true, 0",
        "extractvalue { i1, i64 }",
        ".same_presence = icmp eq i1",
        ".same_payload = icmp eq i64",
    ]:
        assert fragment in optional_llvm, fragment
    print("STRUCTURED OPTIONAL VALUE EMISSION PASS", flush=True)

    # The ordinary compiler must accept each refusal witness first.
    for name in ["RefuseString", "RefuseCallback", "RefuseClassOwnership"]:
        source = (corpus/"LlvmEvaluation"/(name+".sx")).resolve()
        native = output/(name+"-native")
        assert call(name+"-native", [args.native, "compile", source, "--debug", "--nocache", "--output", native])["returncode"] == 0
        target = output/(name+"-refused")
        target.write_bytes(b"existing output must survive refusal")
        rejected = call(name+"-llvm", llvm_command(source, "O3", target))
        assert rejected["returncode"] != 0 and "Unsupported" in rejected["stderr"], rejected
        if name == "RefuseClassOwnership":
            assert "class_retain" in rejected["stderr"] or "structure_init" in rejected["stderr"], rejected
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
