#!/usr/bin/env python3

import argparse
import hashlib
import json
import platform
import subprocess
import sys
import time
from pathlib import Path


WORKLOADS = ("arithmetic", "objects", "flocking")
CONFIGURATIONS = ("debug", "release", "clang")
MINIMUM_QUALIFIED_SAMPLES = 21
MAXIMUM_SPREAD_PPM = 200_000
MAXIMUM_HALF_WINDOW_SHIFT_PPM = 100_000
PARITY_LIMIT_PPM = 1_000_000


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Measure prebuilt Silex native benchmark executables."
    )
    parser.add_argument("binary_directory", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--samples", type=int, default=11)
    parser.add_argument("--warmups", type=int, default=2)
    parser.add_argument("--candidate-sha")
    parser.add_argument("--require-native-x64", action="store_true")
    parser.add_argument("--require-parity", action="store_true")
    arguments = parser.parse_args()
    if arguments.samples < 5 or arguments.samples % 2 == 0:
        parser.error("--samples must be an odd integer greater than or equal to 5")
    if arguments.warmups < 0:
        parser.error("--warmups must be non-negative")
    if arguments.require_parity and arguments.samples < MINIMUM_QUALIFIED_SAMPLES:
        parser.error(
            f"--require-parity needs at least {MINIMUM_QUALIFIED_SAMPLES} samples"
        )
    if arguments.require_parity and not arguments.candidate_sha:
        parser.error("--require-parity needs --candidate-sha")
    return arguments


def execute(executable: Path) -> tuple[bytes, int]:
    started = time.perf_counter_ns()
    result = subprocess.run(
        [executable],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    elapsed = time.perf_counter_ns() - started
    if result.returncode != 0:
        raise RuntimeError(
            f"{executable} exited with {result.returncode}: "
            f"{result.stderr.decode(errors='replace')}"
        )
    return result.stdout, elapsed


def percentile(values: list[int], percent: int) -> int:
    ordered = sorted(values)
    index = ((len(ordered) - 1) * percent + 50) // 100
    return ordered[index]


def ratio_ppm(left: int, right: int) -> int:
    if right <= 0:
        raise ValueError("timing reference must be positive")
    return left * 1_000_000 // right


def summarize(values: list[int]) -> dict[str, int | list[int]]:
    median = percentile(values, 50)
    deviations = [abs(value - median) for value in values]
    p10 = percentile(values, 10)
    p90 = percentile(values, 90)
    return {
        "minimum_ns": min(values),
        "p10_ns": p10,
        "median_ns": median,
        "p90_ns": p90,
        "maximum_ns": max(values),
        "mad_ns": percentile(deviations, 50),
        "mad_ppm": ratio_ppm(percentile(deviations, 50), median),
        "spread_ppm": ratio_ppm(p90 - p10, median),
        "samples_ns": values,
    }


def one_sided_median_bound(samples: int) -> tuple[int, int]:
    total = 1 << samples
    combination = 1
    cumulative = 0
    for index in range(samples):
        cumulative += combination
        if cumulative * 1_000_000 >= total * 950_000:
            return index, cumulative * 1_000_000 // total
        combination = combination * (samples - index) // (index + 1)
    raise AssertionError("median bound not found")


def half_window_shift_ppm(values: list[int]) -> int:
    half = len(values) // 2
    first = percentile(values[:half], 50)
    second = percentile(values[half + 1 :], 50)
    return ratio_ppm(abs(second - first), first)


def analyze_release_vs_clang(observations: list[dict[str, object]]) -> dict[str, object]:
    release = [int(observation["timings_ns"]["release"]) for observation in observations]
    clang = [int(observation["timings_ns"]["clang"]) for observation in observations]
    ratios = [ratio_ppm(left, right) for left, right in zip(release, clang)]
    ordered = sorted(ratios)
    bound_index, confidence_ppm = one_sided_median_bound(len(ratios))
    return {
        "samples": len(ratios),
        "lower_bound_ppm": ordered[len(ordered) - 1 - bound_index],
        "median_ppm": percentile(ratios, 50),
        "upper_bound_ppm": ordered[bound_index],
        "confidence_ppm": confidence_ppm,
        "release_half_shift_ppm": half_window_shift_ppm(release),
        "clang_half_shift_ppm": half_window_shift_ppm(clang),
        "ratio_half_shift_ppm": half_window_shift_ppm(ratios),
        "ratios_ppm": ratios,
    }


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def command_output(arguments: list[str]) -> str | None:
    try:
        result = subprocess.run(
            arguments,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except OSError:
        return None
    output = result.stdout.strip()
    return output if result.returncode == 0 and output else None


def host_profile() -> dict[str, object]:
    translated = False
    cpu = platform.processor()
    if platform.system() == "Darwin":
        translated = command_output(["sysctl", "-n", "sysctl.proc_translated"]) == "1"
        cpu = command_output(["sysctl", "-n", "machdep.cpu.brand_string"]) or cpu
    return {
        "system": platform.system(),
        "release": platform.release(),
        "machine": platform.machine(),
        "processor": cpu or "unknown",
        "translated": translated,
    }


def native_x64_failure(host: dict[str, object]) -> str | None:
    if str(host["machine"]).lower() not in {"x86_64", "amd64"}:
        return f"expected native X64, got {host['machine']}"
    if host["translated"]:
        return "translated X64 process is not physical X64 evidence"
    return None


def qualification_failures(workload: dict[str, object]) -> list[str]:
    failures: list[str] = []
    comparison = workload["release_vs_clang"]
    configurations = workload["configurations"]
    if comparison["samples"] < MINIMUM_QUALIFIED_SAMPLES:
        failures.append("insufficient paired samples")
    for name in ("release", "clang"):
        if configurations[name]["spread_ppm"] > MAXIMUM_SPREAD_PPM:
            failures.append(f"{name} spread exceeds {MAXIMUM_SPREAD_PPM} ppm")
    for name in (
        "release_half_shift_ppm",
        "clang_half_shift_ppm",
        "ratio_half_shift_ppm",
    ):
        if comparison[name] > MAXIMUM_HALF_WINDOW_SHIFT_PPM:
            failures.append(f"{name} exceeds {MAXIMUM_HALF_WINDOW_SHIFT_PPM} ppm")
    if comparison["upper_bound_ppm"] > PARITY_LIMIT_PPM:
        failures.append(f"Silex/Clang upper bound exceeds {PARITY_LIMIT_PPM} ppm")
    return failures


def measure_workload(
    binary_directory: Path, samples: int, warmups: int, workload: str
) -> dict[str, object]:
    executables = {
        configuration: binary_directory / f"{workload}-{configuration}"
        for configuration in CONFIGURATIONS
    }
    for executable in executables.values():
        if not executable.is_file():
            raise FileNotFoundError(executable)

    expected_output: bytes | None = None
    for _ in range(warmups):
        for configuration in CONFIGURATIONS:
            output, _ = execute(executables[configuration])
            if expected_output is None:
                expected_output = output
            elif output != expected_output:
                raise RuntimeError(f"{workload} outputs differ during warmup")

    measurements = {configuration: [] for configuration in CONFIGURATIONS}
    observations: list[dict[str, object]] = []
    for sample in range(samples):
        rotation = sample % len(CONFIGURATIONS)
        order = CONFIGURATIONS[rotation:] + CONFIGURATIONS[:rotation]
        timings: dict[str, int] = {}
        for configuration in order:
            output, elapsed = execute(executables[configuration])
            if expected_output is None:
                expected_output = output
            elif output != expected_output:
                raise RuntimeError(f"{workload} outputs differ during measurement")
            measurements[configuration].append(elapsed)
            timings[configuration] = elapsed
        observations.append({"index": sample, "order": order, "timings_ns": timings})

    assert expected_output is not None
    result: dict[str, object] = {
        "id": workload,
        "output_sha256": hashlib.sha256(expected_output).hexdigest(),
        "executables": {
            configuration: {
                "path": str(executable),
                "sha256": file_sha256(executable),
            }
            for configuration, executable in executables.items()
        },
        "observations": observations,
        "configurations": {
            configuration: summarize(measurements[configuration])
            for configuration in CONFIGURATIONS
        },
        "release_vs_clang": analyze_release_vs_clang(observations),
    }
    result["qualification_failures"] = qualification_failures(result)
    result["qualified"] = not result["qualification_failures"]
    return result


def main() -> None:
    arguments = parse_arguments()
    host = host_profile()
    host_failure = native_x64_failure(host) if arguments.require_native_x64 else None
    workloads = [
        measure_workload(
            arguments.binary_directory,
            arguments.samples,
            arguments.warmups,
            workload,
        )
        for workload in WORKLOADS
    ]
    failures = []
    if host_failure:
        failures.append(host_failure)
    for workload in workloads:
        failures.extend(
            f"{workload['id']}: {failure}"
            for failure in workload["qualification_failures"]
        )
    report = {
        "schema_version": 2,
        "evidence_mode": "qualified" if arguments.require_parity else "diagnostic",
        "candidate_sha": arguments.candidate_sha,
        "host": host,
        "clang": command_output(["clang++", "--version"]),
        "contract": {
            "minimum_samples": MINIMUM_QUALIFIED_SAMPLES,
            "maximum_spread_ppm": MAXIMUM_SPREAD_PPM,
            "maximum_half_window_shift_ppm": MAXIMUM_HALF_WINDOW_SHIFT_PPM,
            "parity_limit_ppm": PARITY_LIMIT_PPM,
            "middle_observation_excluded_from_half_windows": True,
        },
        "samples": arguments.samples,
        "warmups": arguments.warmups,
        "workloads": workloads,
        "qualification": {
            "requested": arguments.require_parity,
            "passed": arguments.require_parity and not failures,
            "failures": failures,
        },
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if arguments.require_parity and failures:
        for failure in failures:
            print(f"optimizer X64 qualification: {failure}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
