import hashlib
import json
import subprocess
import sys
from pathlib import Path

root = Path("/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree")
sys.path.insert(0, str(root / "Silex/Toolchain/Benchmarks/Native"))
import campaign

evidence = Path("/private/tmp/silex-part03-evidence")
names = ["baseline", "release", "control"]
binaries = {
    "baseline": evidence / "preparation-before-inline",
    "release": evidence / "preparation-physics-inline-regional",
    "control": evidence / "preparation-before-inline-control",
}


def run(name):
    result = subprocess.run([str(binaries[name])], capture_output=True, text=True, timeout=60)
    if result.returncode or result.stderr:
        raise RuntimeError((name, result.returncode, result.stdout, result.stderr))
    fields = result.stdout.strip().split()
    if fields[:6] != ["KERNEL", "preparation", "silex", "slots8", "8192", "2048"]:
        raise RuntimeError((name, result.stdout))
    if fields[7] != "4744923641.0":
        raise RuntimeError((name, "signature", fields[7]))
    return {"elapsed_ms": float(fields[6]), "stdout": result.stdout}


for index in range(6):
    for name in names[index % 3 :] + names[: index % 3]:
        run(name)

observations = []
for index in range(21):
    order = names[index % 3 :] + names[: index % 3]
    runs = {name: run(name) for name in order}
    observations.append(
        {
            "index": index,
            "order": order,
            "runs": runs,
            "timings_ns": {name: round(runs[name]["elapsed_ms"] * 1_000_000) for name in names},
        }
    )

configurations = {
    name: campaign.summarize([row["timings_ns"][name] for row in observations]) for name in names
}
comparisons = {"candidate_vs_baseline": campaign.analyze_release_vs_clang(observations, "baseline")}
control_observations = [
    {**row, "timings_ns": {**row["timings_ns"], "release": row["timings_ns"]["control"]}}
    for row in observations
]
comparisons["control_vs_baseline"] = campaign.analyze_release_vs_clang(control_observations, "baseline")
report = {
    "scope": "diagnostic physical ARM64 canonical Preparation; Silex candidate versus frozen Silex baseline and identical-file control",
    "host": campaign.host_profile(),
    "warmups": 6,
    "samples": 21,
    "binaries": {
        name: {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size}
        for name, path in binaries.items()
    },
    "observations": observations,
    "configurations": configurations,
    "comparisons": comparisons,
}
(evidence / "preparation-inline-diagnostic.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"median_ms": {name: configurations[name]["median_ns"] / 1_000_000 for name in names}, "comparisons": comparisons}, indent=2))
