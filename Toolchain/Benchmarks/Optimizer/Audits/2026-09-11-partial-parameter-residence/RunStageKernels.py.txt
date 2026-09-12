#!/usr/bin/env python3
"""Validate stage kernels against pinned Box2D before alternating measurements."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import platform
import subprocess
import sys

from RunContactKernel import execute, parity_result, summary


# Fixed local float32 tolerances. Long trajectories permit different legal FMA
# contractions: replay EVERY transition through Box2D from candidate inputs.
# Also retain the independent trajectory difference as a diagnostic.
PROFILES = {
    "integration": {
        "fields": 8, "exact_fields": [7], "weights": [1, 2, 3, 5, 7, 11, 13, 17],
        "short_absolute": 2e-5, "short_relative": 2e-6,
        "full_absolute": 2e-3, "full_relative": 2e-4,
        "replay": True, "accumulate_passes": False,
    },
    "preparation": {
        "fields": 26, "exact_fields": [], "weights": list(range(1, 27)),
        "short_absolute": 2e-6, "short_relative": 2e-6,
        "full_absolute": 2e-6, "full_relative": 2e-6,
        "replay": False, "accumulate_passes": True,
    },
}
COUNT, PASSES = 8192, 2048


def states(output, profile, full=False):
    records = {}
    for line in output.splitlines():
        fields = line.split()
        if len(fields) != 3 + profile["fields"] or fields[0] != "STATE":
            raise ValueError(f"invalid state record: {line}")
        key = (int(fields[1]), int(fields[2]))
        values = tuple(map(float, fields[3:]))
        if key in records or not all(map(math.isfinite, values)):
            raise ValueError(f"duplicate/non-finite state: {key}")
        if any(values[i] not in (0.0, 1.0) for i in profile["exact_fields"]):
            raise ValueError(f"invalid boolean: {key}")
        records[key] = values
    passes = range(PASSES) if full else range(8)
    if set(records) != {(p, i) for p in passes for i in range(16)}:
        raise ValueError("incomplete state coverage")
    return records


def compare_states(reference, candidate, profile, full=False):
    if reference.keys() != candidate.keys():
        raise ValueError("different case sets")
    prefix = "full" if full else "short"
    maximum = 0.0
    for key in reference:
        for i, (expected, actual) in enumerate(zip(reference[key], candidate[key], strict=True)):
            error = abs(actual - expected)
            limit = profile[f"{prefix}_absolute"] + profile[f"{prefix}_relative"] * abs(expected)
            if i in profile["exact_fields"]:
                limit = 0.0
            if not math.isfinite(actual) or error > limit:
                raise ValueError(f"{key} field {i}: {actual} != {expected}; allowance {limit}")
            maximum = max(maximum, error)
    return maximum


def signature_interval(final_states, profile):
    # Each timed array repeats the 16 fully checked independent trajectories.
    # Account for float32 weighted-sum rounding and decimal state printing.
    total = magnitude = 0.0
    for (step, _), values in final_states.items():
        if not profile["accumulate_passes"] and step != PASSES - 1:
            continue
        terms = [v * w for v, w in zip(values, profile["weights"], strict=True)]
        total += sum(terms)
        magnitude += sum(map(abs, terms))
    repeats = COUNT // 16
    allowance = (2 * profile["fields"] * 2**-23 * magnitude + 1e-5) * repeats
    return total * repeats, allowance


def replay(binary, candidate, profile):
    rows = ["STATE " + " ".join(map(str, (*key, *values[:-1], int(values[-1]))))
            for key, values in sorted(candidate.items())]
    result = subprocess.run([str(binary), "--check-replay"], input="\n".join(rows) + "\n",
                            capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise ValueError(f"oracle replay exit {result.returncode}: {result.stderr}")
    return states(result.stdout, profile, full=True)


def timing(output, stage, name, signature):
    fields = output.split()
    engine = "silex" if name.startswith("silex") else "clang"
    layout = "packed4" if name == "clang-packed" else "slots8"
    if len(fields) != 8 or fields[:6] != ["KERNEL", stage, engine, layout, str(COUNT), str(PASSES)]:
        raise ValueError(f"invalid timing metadata: {output}")
    elapsed, actual = map(float, fields[6:])
    if not math.isfinite(elapsed) or elapsed <= 0 or not math.isfinite(actual):
        raise ValueError("invalid timing/signature")
    expected, allowance = signature
    if abs(actual - expected) > allowance:
        raise ValueError(f"timed result differs from checked final states: {actual} != {expected}")
    return {"elapsed_ms": elapsed, "signature": actual, "engine": engine, "layout": layout}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", required=True, choices=PROFILES)
    parser.add_argument("--silex", required=True, type=Path)
    parser.add_argument("--baseline-silex", type=Path)
    parser.add_argument("--clang-slots", required=True, type=Path)
    parser.add_argument("--clang-packed", required=True, type=Path)
    parser.add_argument("--box2d-check", required=True, type=Path)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--require-parity", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.check_only and args.require_parity:
        parser.error("--require-parity needs timing")
    profile = PROFILES[args.stage]
    binaries = {"silex": args.silex, "clang-slots": args.clang_slots, "clang-packed": args.clang_packed}
    if args.baseline_silex:
        binaries["silex-before"] = args.baseline_silex
    references = {full: states(execute(args.box2d_check, "--check-full" if full else "--check"), profile, full)
                  for full in (False, True)}
    result = {"schema": 1, "stage": args.stage, "captured_at": datetime.now(timezone.utc).isoformat(),
              "host": platform.platform(), "machine": platform.machine(),
              "workload": {"count": COUNT, "passes": PASSES, "workers": 1, "float_bits": 32,
                           "fma": True, "allocation_in_kernel": False,
                           "signature_reduction_in_kernel": profile["accumulate_passes"],
                           "input_frames": 16 if args.stage == "preparation" else 1},
              "oracle_revision": "8c661469c9507d3ad6fbd2fea3f1aa71669c2fe3",
              "numerical_budgets": profile, "correctness": {}, "executables": {},
              "warmup": {}, "samples": {}, "summary": {}}
    for name, binary in {**binaries, "box2d-check": args.box2d_check}.items():
        result["executables"][name] = {"path": str(binary), "sha256": hashlib.sha256(binary.read_bytes()).hexdigest()}
    signatures = {}
    for name, binary in binaries.items():
        result["correctness"][name] = {}
        for full in (False, True):
            candidate = states(execute(binary, "--check-full" if full else "--check"), profile, full)
            reference = replay(args.box2d_check, candidate, profile) if full and profile["replay"] else references[full]
            error = compare_states(reference, candidate, profile)
            key = "full" if full else "short"
            result["correctness"][name][key] = {"records": len(candidate), "max_absolute_error": error}
            if full:
                signatures[name] = signature_interval(candidate, profile)
                independent = references[full]
                result["correctness"][name][key]["oracle"] = (
                    "every transition from identical candidate inputs" if profile["replay"] else "every prepared field from identical inputs")
                result["correctness"][name][key]["independent_trajectory_max_error"] = max(
                    abs(a - b) for k in candidate for a, b in zip(candidate[k], independent[k], strict=True))
                try:
                    compare_states(independent, candidate, profile, full=True)
                    within_initial_budget = True
                except ValueError:
                    within_initial_budget = False
                result["correctness"][name][key]["independent_trajectory_within_initial_budget"] = within_initial_budget
        print(f"PASS {name}: short and full trajectories", flush=True)
    if not args.check_only:
        for name, binary in binaries.items():
            result["warmup"][name] = timing(execute(binary), args.stage, name, signatures[name])
            result["samples"][name] = []
        names = list(binaries)
        for sample in range(7):
            offset = sample % len(names)
            for name in names[offset:] + names[:offset]:
                result["samples"][name].append(timing(execute(binaries[name]), args.stage, name, signatures[name]))
            print(f"sample {sample + 1}/7 complete", flush=True)
        for name in names:
            result["summary"][name] = summary(result["samples"][name])
        candidate, reference = result["summary"]["silex"], result["summary"]["clang-slots"]
        result["silex_over_clang_same_layout"] = candidate["median_ms"] / reference["median_ms"]
        result["clang_slots_over_packed"] = reference["median_ms"] / result["summary"]["clang-packed"]["median_ms"]
        result["timing_admissible"] = all(s["mad_percent"] <= 5 and s["min_ms"] >= 20 for s in result["summary"].values())
        result["compiler_parity"] = parity_result(candidate, reference, result["timing_admissible"])
        print(json.dumps(result["summary"], indent=2))
        print(f"Compiler parity: {result['compiler_parity']}; ratio {result['silex_over_clang_same_layout']:.4f}")
    if args.output:
        args.output.write_text(json.dumps(result, indent=2) + "\n")
    return int(args.require_parity and result["compiler_parity"] != "demonstrated-for-this-kernel")


if __name__ == "__main__":
    sys.exit(main())
