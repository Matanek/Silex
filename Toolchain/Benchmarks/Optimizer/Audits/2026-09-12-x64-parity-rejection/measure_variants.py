import hashlib
import json
import random
import statistics
import subprocess
import time
from pathlib import Path


ROOT = Path("/private/tmp/silex-part03-evidence/x64-power-remainder")
EXECUTABLES = {
    "baseline": ROOT / "objects-before",
    "parity_only": ROOT / "objects-direct-parity",
    "mask_only": ROOT / "objects-mask-only",
    "combined": ROOT / "objects-compact-combined",
}
SAMPLES = 21
WARMUPS = 6
BATCHES = 4


def execute(path):
    start = time.perf_counter_ns()
    completed = subprocess.run([path], check=True, capture_output=True)
    return completed.stdout, time.perf_counter_ns() - start


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[round((len(ordered) - 1) * fraction)]


def paired_interval(ratios):
    rng = random.Random(0x53494C4558)
    medians = []
    for _ in range(10000):
        medians.append(statistics.median(rng.choices(ratios, k=len(ratios))))
    return percentile(medians, 0.025), percentile(medians, 0.975)


expected = None
observations = []
names = tuple(EXECUTABLES)
for sample in range(-WARMUPS, SAMPLES):
    rotation = sample % len(names)
    order = names[rotation:] + names[:rotation]
    if sample % 2:
        order = tuple(reversed(order))
    timings = {name: 0 for name in names}
    launches = []
    for _ in range(BATCHES):
        for name in order:
            output, elapsed = execute(EXECUTABLES[name])
            if expected is None:
                expected = output
            elif output != expected:
                raise RuntimeError(f"output mismatch for {name}")
            timings[name] += elapsed
            launches.append({"configuration": name, "elapsed_ns": elapsed})
    if sample >= 0:
        observations.append({"index": sample, "timings_ns": timings, "launches": launches})

comparisons = {}
baseline = [row["timings_ns"]["baseline"] for row in observations]
for name in names[1:]:
    values = [row["timings_ns"][name] for row in observations]
    ratios = [value / reference for value, reference in zip(values, baseline)]
    low, high = paired_interval(ratios)
    comparisons[name] = {
        "paired_ratio_median": statistics.median(ratios),
        "paired_ratio_ci95": [low, high],
        "gain_median": 1 - statistics.median(ratios),
        "gain_ci95": [1 - high, 1 - low],
        "median_ns": statistics.median(values),
    }

report = {
    "host": subprocess.run(["uname", "-m"], check=True, capture_output=True, text=True).stdout.strip(),
    "diagnostic_only": "macos-x64 executables under Rosetta",
    "samples": SAMPLES,
    "warmups": WARMUPS,
    "launches_per_configuration_per_observation": BATCHES,
    "output_sha256": hashlib.sha256(expected).hexdigest(),
    "executables": {
        name: {
            "path": str(path),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
        for name, path in EXECUTABLES.items()
    },
    "observations": observations,
    "baseline_median_ns": statistics.median(baseline),
    "comparisons": comparisons,
}
(ROOT / "variant-calibration.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(comparisons, indent=2))
