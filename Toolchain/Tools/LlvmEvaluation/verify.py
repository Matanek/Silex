#!/usr/bin/env python3
"""Verify the bounded LLVM backend against exact native observables and refusals."""
import argparse
import hashlib
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
        "native", "adapter", "format-runtime", "shadercross", "llvm-dir", "sdk", "output-dir", "report",
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
                "--adapter", args.adapter, "--format-runtime", args.format_runtime,
                "--shadercross", args.shadercross,
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
        "LlvmEvaluation/ClassOwnership.sx": "7\n-1\n",
        "LlvmEvaluation/ClassFieldStore.sx": "7\nfalse\n41\ntrue\n",
        "LlvmEvaluation/FunctionAddress.sx": "true\ntrue\n",
        "LlvmEvaluation/IndirectCalls.sx": "42\n7\n",
        "LlvmEvaluation/Mutex.sx": "nested\n42\n",
        "LlvmEvaluation/EmbeddedBytes.sx": "4\n65\n195\n169\n0\n65\n",
        "LlvmEvaluation/AggregateOptional.sx": "-1\n42\ntrue\n",
        "LlvmEvaluation/RichClassStorage.sx": "42\ntrue\nempty\n",
        "LlvmEvaluation/ClassFinalizers.sx": "leaf\nowner\nleaf\n",
        "LlvmEvaluation/OwnedStringList.sx": "2\nalpha\nbeta\n",
        "LlvmEvaluation/PlainEnum.sx": "true\ntrue\n2\n3\n",
        "LlvmEvaluation/PayloadEnum.sx": "41\n7\n-2\n",
        "LlvmEvaluation/AssertSuccess.sx": "7\n",
        "LlvmEvaluation/StringLiterals.sx": "0\nSilex\n3\ntrue\nfalse\nA\0B\n",
        "LlvmEvaluation/StringBytes.sx": "4\n195\n169\n0\n65\n",
        "LlvmEvaluation/StringAddress.sx": "true\ntrue\n",
        "LlvmEvaluation/ListAppendClear.sx": "1\n2\n2\n5\ntrue\n0\n1\n",
        "LlvmEvaluation/StringConcat.sx": "3\n4\ntrue\né\0A\n",
        "LlvmEvaluation/FormatValues.sx": (
            "-128|-32768|-2147483648|-9223372036854775808\n"
            "255|65535|4294967295|9223372036854775807\n"
            "1.5|-0.0|1.2345678806304932\n"
            "0.0|-0.0|inf|-inf|nan\n"
            "true|false|Silex\n"
        ),
        "LlvmEvaluation/RawMemory.sx": (
            "-7\n250\n-12345\n54321\n-123456789\n4000000000\n"
            "-1234567890123456789\n9000000000000000000\n-13.5\n1234.25\n"
        ),
        "LlvmEvaluation/CollectionSlice.sx": "3\n20\n40\n360\n420\ntrue\n",
        "LlvmEvaluation/StringFromBytes.sx": "4\n3\n195\ntrue\né\0A\ntrue\n",
        "LlvmEvaluation/RawEnum.sx": "-7\n42\ntrue\ntrue\ntrue\né\0A\ntrue\n",
        "LlvmEvaluation/ProtocolValues.sx": "7\n42\n41\n41\n41\n",
        "LlvmEvaluation/StorageInitialization.sx": "7\ntrue\n42\ntrue\n",
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

    for relative in ["LlvmEvaluation/Rounding.sx", "ReferenceAliasing.sx", "OwningCollectionCopy.sx", "LlvmEvaluation/Lifetime.sx", "LlvmEvaluation/OptionalValues.sx", "LlvmEvaluation/ClassOwnership.sx", "LlvmEvaluation/ClassFieldStore.sx", "LlvmEvaluation/IndirectCalls.sx", "LlvmEvaluation/Mutex.sx", "LlvmEvaluation/EmbeddedBytes.sx", "LlvmEvaluation/AggregateOptional.sx", "LlvmEvaluation/RichClassStorage.sx", "LlvmEvaluation/ClassFinalizers.sx", "LlvmEvaluation/OwnedStringList.sx", "LlvmEvaluation/PlainEnum.sx", "LlvmEvaluation/PayloadEnum.sx", "LlvmEvaluation/StringLiterals.sx", "LlvmEvaluation/StringBytes.sx", "LlvmEvaluation/ListAppendClear.sx", "LlvmEvaluation/StringConcat.sx", "LlvmEvaluation/FormatValues.sx", "LlvmEvaluation/CollectionSlice.sx", "LlvmEvaluation/StringFromBytes.sx", "LlvmEvaluation/RawEnum.sx", "LlvmEvaluation/ProtocolValues.sx", "LlvmEvaluation/StorageInitialization.sx"]:
        interpreted = call("interpreter-"+Path(relative).stem, [args.native, "interpret", corpus/relative, "--nocache"])
        assert interpreted["returncode"] == 0 and interpreted["stdout"] == cases[relative], interpreted

    function_interpreted = call("interpreter-FunctionAddress-known-limit", [
        args.native, "interpret", corpus/"LlvmEvaluation/FunctionAddress.sx", "--nocache",
    ])
    assert function_interpreted["returncode"] != 0, function_interpreted
    assert "InvalidProgram" in function_interpreted["stderr"], function_interpreted

    assert_failure = (corpus/"LlvmEvaluation/AssertFailure.sx").resolve()
    failed_observable = None
    for mode in ["debug", "release", "O0", "O3"]:
        binary = output/("AssertFailure-"+mode)
        command = ([args.native, "compile", assert_failure, "--"+mode, "--nocache", "--output", binary]
                   if mode in ["debug", "release"] else llvm_command(assert_failure, mode, binary))
        built = call("AssertFailure-compile-"+mode, command)
        assert built["returncode"] == 0, built
        run = call("AssertFailure-run-"+mode, [binary])
        observable = {key: run[key] for key in ["returncode", "stdout", "stderr"]}
        assert run["returncode"] == 1 and run["stdout"] == "7\n", run
        assert "runtime error: assertion failed: échec attendu\n" in run["stderr"], run
        if failed_observable is None:
            failed_observable = observable
        else:
            assert observable == failed_observable, (mode, failed_observable, observable)
    interpreted_failure = call("interpreter-AssertFailure", [args.native, "interpret", assert_failure, "--nocache"])
    assert {key: interpreted_failure[key] for key in ["returncode", "stdout", "stderr"]} == failed_observable
    print("ASSERT SUCCESS AND FAILURE OBSERVABLES PASS", flush=True)

    panic_failure = (corpus/"LlvmEvaluation/PanicFailure.sx").resolve()
    panic_observable = None
    for mode in ["debug", "release", "O0", "O3"]:
        binary = output/("PanicFailure-"+mode)
        command = ([args.native, "compile", panic_failure, "--"+mode, "--nocache", "--output", binary]
                   if mode in ["debug", "release"] else llvm_command(panic_failure, mode, binary))
        built = call("PanicFailure-compile-"+mode, command)
        assert built["returncode"] == 0, built
        run = call("PanicFailure-run-"+mode, [binary])
        observable = {key: run[key] for key in ["returncode", "stdout", "stderr"]}
        assert run["returncode"] == 1 and run["stdout"] == "7\n", run
        assert "runtime error: panique attendue\n" in run["stderr"], run
        if panic_observable is None:
            panic_observable = observable
        else:
            assert observable == panic_observable, (mode, panic_observable, observable)
    interpreted_panic = call("interpreter-PanicFailure", [args.native, "interpret", panic_failure, "--nocache"])
    assert {key: interpreted_panic[key] for key in ["returncode", "stdout", "stderr"]} == panic_observable
    print("PANIC FAILURE OBSERVABLES PASS", flush=True)

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
    canonicalized = call("CommandsDominance-ssa_promotion_pre", [
        args.adapter, "--backend", "llvm", "--shadercross", args.shadercross,
        "--silex-prefix", "ssa_promotion_pre", "--closure-report", boundary_report,
        dominance, target,
    ])
    assert canonicalized["returncode"] == 0, canonicalized
    assert "DefinitionDoesNotDominateUse" not in canonicalized["stderr"], canonicalized
    assert target.read_text().startswith("; Generated by the explicit Silex LLVM evaluation backend."), target
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
        ".present = extractvalue { i1, i64 }",
        "xor i1",
    ]:
        assert fragment in optional_llvm, fragment
    print("STRUCTURED OPTIONAL VALUE EMISSION PASS", flush=True)

    class_metadata = json.loads(Path(str(output/"ClassOwnership-O0")+".json").read_text())
    class_llvm = (Path(class_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "= type { i64, i64, i64, i64, [1 x i64] }",
        "call fastcc ptr @sx_class_alloc",
        "call fastcc void @sx_retain(ptr",
        "call fastcc void @sx_drop(ptr",
        ".class.field = getelementptr i8",
        "{ i1, ptr }",
    ]:
        assert fragment in class_llvm, fragment
    print("ROOT-OWNED OPTIONAL CLASS EMISSION PASS", flush=True)

    class_store_metadata = json.loads(Path(str(output/"ClassFieldStore-O0")+".json").read_text())
    class_store_llvm = (Path(class_store_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "= type { i64, i64, i64, i64, [2 x i64] }",
        ".class.store.field = getelementptr i8",
        "store i64",
        "store i1",
    ]:
        assert fragment in class_store_llvm, fragment
    print("PLAIN CLASS FIELD STORE EMISSION PASS", flush=True)

    function_metadata = json.loads(Path(str(output/"FunctionAddress-O0")+".json").read_text())
    function_llvm = (Path(function_metadata["artifact_directory"])/"raw.ll").read_text()
    assert "select i1 true, ptr @sx_" in function_llvm, function_llvm
    assert "ptrtoint ptr" in function_llvm, function_llvm
    print("CAPTURE-FREE FUNCTION ADDRESS EMISSION PASS", flush=True)

    enum_metadata = json.loads(Path(str(output/"PlainEnum-O0")+".json").read_text())
    enum_llvm = (Path(enum_metadata["artifact_directory"])/"raw.ll").read_text()
    assert "icmp eq i64" in enum_llvm, enum_llvm
    assert "icmp ne i64" in enum_llvm, enum_llvm
    print("PAYLOAD-FREE ENUM EMISSION PASS", flush=True)

    payload_enum_metadata = json.loads(Path(str(output/"PayloadEnum-O0")+".json").read_text())
    payload_enum_llvm = (Path(payload_enum_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "= type { i64, [2 x i64] }",
        ".enum.payload.0 = getelementptr i8",
        ".enum.payload.1 = getelementptr i8",
        ".enum.tag = extractvalue",
        "load %sx.type.",
    ]:
        assert fragment in payload_enum_llvm, fragment
    print("TAGGED PAYLOAD ENUM EMISSION PASS", flush=True)

    string_metadata = json.loads(Path(str(output/"StringLiterals-O0")+".json").read_text())
    string_llvm = (Path(string_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "private constant { i64, [5 x i8] }",
        "private constant { i64, [7 x i8] }",
        "private constant { i64, [3 x i8] }",
        "call fastcc void @sx_string_retain(ptr",
        "call fastcc void @sx_string_drop(ptr",
        "call fastcc i1 @sx_string_equal(ptr",
        "call fastcc i64 @sx_string_count(ptr",
        "call i64 @write(i32 1, ptr",
    ]:
        assert fragment in string_llvm, fragment
    assert "[3 x i8] c\"\\41\\00\\42\"" in string_llvm, string_llvm
    print("STATIC STRING DESCRIPTOR AND LIFETIME EMISSION PASS", flush=True)

    string_bytes_metadata = json.loads(Path(str(output/"StringBytes-O0")+".json").read_text())
    string_bytes_llvm = (Path(string_bytes_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        ".string.tagged = load i64",
        ".string.length = and i64",
        ".string.invalid = icmp uge i64",
        ".string.address = getelementptr i8",
        "load i8",
    ]:
        assert fragment in string_bytes_llvm, fragment
    string_address_metadata = json.loads(Path(str(output/"StringAddress-O0")+".json").read_text())
    string_address_llvm = (Path(string_address_metadata["artifact_directory"])/"raw.ll").read_text()
    assert "getelementptr i8, ptr" in string_address_llvm, string_address_llvm
    print("STRING BYTE PROJECTIONS PASS", flush=True)

    list_edit_metadata = json.loads(Path(str(output/"ListAppendClear-O0")+".json").read_text())
    list_edit_llvm = (Path(list_edit_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        ".count.checked = call { i64, i1 } @llvm.uadd.with.overflow.i64",
        ".appended = getelementptr",
        "call fastcc void @sx_drop(ptr",
        ".count = add i64 0, 0",
    ]:
        assert fragment in list_edit_llvm, fragment
    print("PLAIN LIST APPEND AND CLEAR PASS", flush=True)

    concat_metadata = json.loads(Path(str(output/"StringConcat-O0")+".json").read_text())
    concat_llvm = (Path(concat_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        ".length.checked = call { i64, i1 } @llvm.uadd.with.overflow.i64",
        ".tagged = or i64",
        ".right.destination = getelementptr i8",
        "call void @llvm.memcpy.p0.p0.i64",
    ]:
        assert fragment in concat_llvm, fragment
    print("DYNAMIC STRING CONCATENATION PASS", flush=True)

    format_metadata = json.loads(Path(str(output/"FormatValues-O0")+".json").read_text())
    format_llvm = (Path(format_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "call i64 @silex_format_signed",
        "call i64 @silex_format_unsigned",
        "call i64 @silex_format_float",
        ".format.scratch = alloca [384 x i8]",
        "@sx.format.true = private constant",
        "@sx.format.false = private constant",
    ]:
        assert fragment in format_llvm, fragment
    runtime = Path(args.format_runtime).resolve()
    assert format_metadata["inputs"]["format_runtime"] == str(runtime), format_metadata
    assert format_metadata["inputs"]["format_runtime_sha256"] == hashlib.sha256(runtime.read_bytes()).hexdigest(), format_metadata
    print("EXACT SCALAR FORMATTING RUNTIME PASS", flush=True)

    raw_memory_metadata = json.loads(Path(str(output/"RawMemory-O0")+".json").read_text())
    raw_memory_llvm = (Path(raw_memory_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "inttoptr i64",
        ".raw.address = getelementptr i8",
        "load i8, ptr",
        "load i16, ptr",
        "load i32, ptr",
        "load i64, ptr",
        "load float, ptr",
        "load double, ptr",
        "align 1",
    ]:
        assert fragment in raw_memory_llvm, fragment
    assert raw_memory_llvm.count("store ") > 10, raw_memory_llvm
    print("UNALIGNED TYPED RAW MEMORY PASS", flush=True)

    slice_metadata = json.loads(Path(str(output/"CollectionSlice-O0")+".json").read_text())
    slice_llvm = (Path(slice_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        ".slice.difference = sub i64",
        ".slice.nonempty = icmp sgt i64",
        ".slice.storage = call fastcc ptr @sx_unowned_alloc",
        ".slice.source = getelementptr",
        "call void @llvm.memcpy.p0.p0.i64",
    ]:
        assert fragment in slice_llvm, fragment
    print("PLAIN OWNING COLLECTION SLICE PASS", flush=True)

    from_bytes_metadata = json.loads(Path(str(output/"StringFromBytes-O0")+".json").read_text())
    from_bytes_llvm = (Path(from_bytes_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        ".from_bytes.data = extractvalue",
        ".from_bytes.count = extractvalue",
        ".from_bytes.allocation.checked = call { i64, i1 } @llvm.uadd.with.overflow.i64",
        ".from_bytes.tagged = or i64",
        ".from_bytes.destination = getelementptr i8",
        "call void @llvm.memcpy.p0.p0.i64",
    ]:
        assert fragment in from_bytes_llvm, fragment
    print("OWNED STRING FROM BYTE VIEW PASS", flush=True)

    raw_enum_metadata = json.loads(Path(str(output/"RawEnum-O0")+".json").read_text())
    raw_enum_llvm = (Path(raw_enum_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "= type { i64, i64 }",
        "= type { i64, ptr }",
        "@sx.enum.raw.",
        ".enum.tagged = insertvalue",
        "extractvalue %sx.enum.",
        ".enum.left.tag = extractvalue",
        ".enum.right.tag = extractvalue",
    ]:
        assert fragment in raw_enum_llvm, fragment
    print("INTEGER AND STRING RAW ENUM PASS", flush=True)

    protocol_metadata = json.loads(Path(str(output/"ProtocolValues-O0")+".json").read_text())
    protocol_llvm = (Path(protocol_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "= type { i64, [",
        ".protocol.class.tag = load i64, ptr",
        ".protocol.tag = extractvalue",
        ".protocol.payload = getelementptr i8",
        "@sx_typed_class_retain",
        "@sx_typed_class_release",
    ]:
        assert fragment in protocol_llvm, fragment
    print("TYPE-ERASED PROTOCOL VALUES PASS", flush=True)

    storage_metadata = json.loads(Path(str(output/"StorageInitialization-O0")+".json").read_text())
    storage_llvm = (Path(storage_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "= freeze i64 zeroinitializer",
        "= freeze double zeroinitializer",
        "= freeze i1 zeroinitializer",
    ]:
        assert fragment in storage_llvm, fragment
    print("TRANSIENT FIELD STORAGE INITIALIZATION PASS", flush=True)

    indirect_metadata = json.loads(Path(str(output/"IndirectCalls-O0")+".json").read_text())
    indirect_llvm = (Path(indirect_metadata["artifact_directory"])/"raw.ll").read_text()
    assert "call fastcc i64 %v" in indirect_llvm, indirect_llvm
    assert "call fastcc void %v" in indirect_llvm, indirect_llvm
    print("CAPTURE-FREE INDIRECT CALLS PASS", flush=True)

    mutex_metadata = json.loads(Path(str(output/"Mutex-O0")+".json").read_text())
    mutex_llvm = (Path(mutex_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "@sx.mutex = private global [8 x i64] zeroinitializer",
        "call void @os_unfair_recursive_lock_lock_with_options(ptr @sx.mutex, i64 0)",
        "call void @os_unfair_recursive_lock_unlock(ptr @sx.mutex)",
    ]:
        assert fragment in mutex_llvm, fragment
    print("RECURSIVE MUTEX AND EARLY RELEASE PASS", flush=True)

    embedded_metadata = json.loads(Path(str(output/"EmbeddedBytes-O0")+".json").read_text())
    embedded_llvm = (Path(embedded_metadata["artifact_directory"])/"raw.ll").read_text()
    assert "private constant [4 x i8] c\"\\41\\C3\\A9\\0A\"" in embedded_llvm, embedded_llvm
    assert "call void @llvm.memcpy.p0.p0.i64" in embedded_llvm, embedded_llvm
    print("OWNED EMBEDDED BYTES PASS", flush=True)

    aggregate_optional_metadata = json.loads(Path(str(output/"AggregateOptional-O0")+".json").read_text())
    aggregate_optional_llvm = (Path(aggregate_optional_metadata["artifact_directory"])/"raw.ll").read_text()
    assert "{ i1, %sx.type." in aggregate_optional_llvm, aggregate_optional_llvm
    print("AGGREGATE OPTIONAL VALUES PASS", flush=True)

    rich_class_metadata = json.loads(Path(str(output/"RichClassStorage-O0")+".json").read_text())
    rich_class_llvm = (Path(rich_class_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "= type { i64, i64, i64, i64, [3 x i64] }",
        "getelementptr i8, ptr %v",
        "i64 32",
        "store { i1, %sx.type.",
        "load { i1, %sx.type.",
    ]:
        assert fragment in rich_class_llvm, fragment
    print("NATIVE-ABI RICH CLASS STORAGE PASS", flush=True)

    class_finalizer_metadata = json.loads(Path(str(output/"ClassFinalizers-O0")+".json").read_text())
    class_finalizer_llvm = (Path(class_finalizer_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "atomicrmw add ptr %counter, i64 1 monotonic",
        "atomicrmw sub ptr %counter, i64 1 acq_rel",
        "cmpxchg ptr %state, i64 0, i64 1 acq_rel acquire",
        ".class.finalize = call fastcc i1 @sx_typed_class_release",
        "call fastcc void @sx_typed_class_free",
    ]:
        assert fragment in class_finalizer_llvm, fragment
    print("ROOT/EDGE CLASS FINALIZATION PASS", flush=True)

    owned_list_metadata = json.loads(Path(str(output/"OwnedStringList-O0")+".json").read_text())
    owned_list_llvm = (Path(owned_list_metadata["artifact_directory"])/"raw.ll").read_text()
    for fragment in [
        "getelementptr i8, ptr %data, i64 -24",
        "getelementptr i8, ptr %data, i64 -16",
        "atomicrmw add ptr %counter, i64 1 monotonic",
        "atomicrmw sub ptr %counter, i64 1 acq_rel",
        "call fastcc void @sx_retain(ptr",
        "i64 -16)",
        "call fastcc void @sx_string_drop(ptr",
    ]:
        assert fragment in owned_list_llvm, fragment
    print("ROOT/EDGE OWNED LIST EMISSION PASS", flush=True)

    # The ordinary compiler must accept the refusal witness first.
    for name in ["RefuseCallback"]:
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
