#!/usr/bin/env python3

import argparse
import hashlib
import json
import platform
import statistics
import subprocess
import time
from pathlib import Path


WORKLOADS = ("arithmetic", "objects", "flocking")
CONFIGURATIONS = ("debug", "release", "clang")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Measure prebuilt Silex native benchmark executables."
    )
    parser.add_argument("binary_directory", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--samples", type=int, default=11)
    parser.add_argument("--warmups", type=int, default=2)
    arguments = parser.parse_args()
    if arguments.samples < 5 or arguments.samples % 2 == 0:
        parser.error("--samples must be an odd integer greater than or equal to 5")
    if arguments.warmups < 0:
        parser.error("--warmups must be non-negative")
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


def percentile(values: list[int], fraction: float) -> int:
    ordered = sorted(values)
    return ordered[round((len(ordered) - 1) * fraction)]


def summarize(values: list[int]) -> dict[str, int | list[int]]:
    median = int(statistics.median(values))
    deviations = [abs(value - median) for value in values]
    return {
        "minimum_ns": min(values),
        "p10_ns": percentile(values, 0.1),
        "median_ns": median,
        "p90_ns": percentile(values, 0.9),
        "maximum_ns": max(values),
        "mad_ns": int(statistics.median(deviations)),
        "samples_ns": values,
    }


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
    for sample in range(samples):
        rotation = sample % len(CONFIGURATIONS)
        order = CONFIGURATIONS[rotation:] + CONFIGURATIONS[:rotation]
        for configuration in order:
            output, elapsed = execute(executables[configuration])
            if output != expected_output:
                raise RuntimeError(f"{workload} outputs differ during measurement")
            measurements[configuration].append(elapsed)

    assert expected_output is not None
    return {
        "id": workload,
        "output_sha256": hashlib.sha256(expected_output).hexdigest(),
        "configurations": {
            configuration: summarize(measurements[configuration])
            for configuration in CONFIGURATIONS
        },
    }


def main() -> None:
    arguments = parse_arguments()
    report = {
        "schema_version": 1,
        "host": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
            "processor": platform.processor(),
        },
        "samples": arguments.samples,
        "warmups": arguments.warmups,
        "workloads": [
            measure_workload(
                arguments.binary_directory,
                arguments.samples,
                arguments.warmups,
                workload,
            )
            for workload in WORKLOADS
        ],
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
