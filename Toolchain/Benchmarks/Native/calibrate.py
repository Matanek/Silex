"""Calibrate an archived Objects comparison without rebuilding either compiler.

These controls do not admit an optimization or relax the parity thresholds.
"""

import argparse
import json
import shutil
from pathlib import Path

import campaign


def verified_artifact(directory: Path, expected_candidate: str):
    directory = directory.resolve()
    report = json.loads((directory / "optimizer-x64/campaign.json").read_text())
    if report["candidate_sha"] != expected_candidate or not report.get("baseline_sha"):
        raise ValueError("unexpected candidate or missing paired baseline")
    binaries = {}
    for workload in report["workloads"]:
        entries = {}
        for configuration, description in workload["executables"].items():
            _, marker, relative = description["path"].partition(".zig-cache/")
            path = (directory / relative).resolve()
            if not marker or not path.is_relative_to(directory):
                raise ValueError("artifact path escapes its directory")
            if campaign.file_sha256(path) != description["sha256"]:
                raise ValueError(f"artifact checksum mismatch: {path.name}")
            entries[configuration] = path
        if set(entries) != {*campaign.CONFIGURATIONS, "baseline"}:
            raise ValueError("incomplete paired executable set")
        binaries[workload["id"]] = entries
    if set(binaries) != set(campaign.WORKLOADS):
        raise ValueError("incomplete workload set")
    return report, binaries


def prepare_case(directory: Path, binaries, mode: str):
    if mode not in {"forward", "reverse", "same_bytes", "same_file"}:
        raise ValueError("unknown calibration control")
    after = directory / "after"
    before = directory / "before"
    after.mkdir(parents=True)
    before.mkdir()
    for configuration in campaign.CONFIGURATIONS:
        selected = "baseline" if mode == "reverse" and configuration == "release" else configuration
        destination = after / f"objects-{configuration}"
        shutil.copy2(binaries[selected], destination)
        destination.chmod(0o755)
    if mode == "same_file":
        return after, after
    selected = "baseline" if mode == "forward" else "release"
    destination = before / "objects-release"
    shutil.copy2(binaries[selected], destination)
    destination.chmod(0o755)
    return after, before


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact_directory", type=Path)
    parser.add_argument("output_directory", type=Path)
    parser.add_argument("--expected-candidate", required=True)
    parser.add_argument("--source-run-id", required=True)
    parser.add_argument("--validate-only", action="store_true")
    arguments = parser.parse_args()
    source, binaries = verified_artifact(arguments.artifact_directory, arguments.expected_candidate)
    if arguments.validate_only:
        print("verified 15 archived executables; no timing performed")
        return
    host = campaign.host_profile()
    failure = campaign.native_x64_failure(host)
    if failure or "Intel" not in str(host["processor"]):
        raise RuntimeError(failure or "calibration requires physical Intel")
    arguments.output_directory.mkdir(parents=True, exist_ok=False)
    report = {
        "calibration_only": True,
        "source_run_id": arguments.source_run_id,
        "candidate_sha": source["candidate_sha"],
        "baseline_sha": source["baseline_sha"],
        "host": host,
        "samples": 21,
        "warmups": 6,
        "controls": {},
    }
    expected = next(item for item in source["workloads"] if item["id"] == "objects")["output_sha256"]
    for mode in ("forward", "reverse", "same_bytes", "same_file"):
        after, before = prepare_case(arguments.output_directory / mode, binaries["objects"], mode)
        result = campaign.measure_workload(after, 21, 6, "objects", before)
        if result["output_sha256"] != expected:
            raise RuntimeError("calibration output differs from the archived workload")
        result["release_vs_references"]["baseline"] = result["release_vs_baseline"]
        result["stability_failures"] = [
            failure for failure in campaign.qualification_failures(result, "baseline")
            if "upper bound" not in failure
        ]
        report["controls"][mode] = result
        (arguments.output_directory / "calibration.json").write_text(json.dumps(report, indent=2) + "\n")
        print(mode, result["release_vs_baseline"], result["stability_failures"], flush=True)


if __name__ == "__main__":
    main()
