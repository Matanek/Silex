#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
workflow="$repository_root/.github/workflows/release.yml"
installer_workflow="$repository_root/.github/workflows/install-smoke.yml"

"$repository_root/Tests/Distribution/InstallerUnixContract.sh"

python3 - "$workflow" "$installer_workflow" <<'PYTHON'
import re
import sys

workflow = open(sys.argv[1], encoding="utf-8").read()
installer_workflow = open(sys.argv[2], encoding="utf-8").read()
targets = (
    "macos-arm64",
    "macos-x64",
    "linux-arm64",
    "linux-x64",
    "windows-arm64",
    "windows-x64",
)

for target in targets:
    if re.search(rf"^  {re.escape(target)}:\s*$", workflow, re.MULTILINE) is None:
        raise SystemExit(f"missing release job {target}")
    if f"          - {target}\n" not in workflow:
        raise SystemExit(f"missing target option {target}")
    if re.search(rf"^  {re.escape(target)}:\s*$", installer_workflow, re.MULTILINE) is None:
        raise SystemExit(f"missing installer smoke job {target}")
    if f"          - {target}\n" not in installer_workflow:
        raise SystemExit(f"missing installer smoke option {target}")

runners = {
    "macos-arm64": "macos-15",
    "macos-x64": "macos-15-intel",
    "linux-arm64": "ubuntu-24.04-arm",
    "linux-x64": "ubuntu-24.04",
    "windows-arm64": "windows-11-arm",
    "windows-x64": "windows-2025",
}
for target, runner in runners.items():
    pattern = rf"^  {re.escape(target)}:\n(?:(?:    .*|)\n)*?    runs-on: {re.escape(runner)}$"
    if re.search(pattern, workflow, re.MULTILINE) is None:
        raise SystemExit(f"release job {target} does not use {runner}")
    if re.search(pattern, installer_workflow, re.MULTILINE) is None:
        raise SystemExit(f"installer smoke job {target} does not use {runner}")

match = re.search(r"          expected=\(\n(.*?)          \)\n", workflow, re.DOTALL)
if match is None:
    raise SystemExit("missing expected release set")

expected_files = []
for target in targets:
    extension = ".zip" if target.startswith("windows-") else ".tar.gz"
    filename = f"silex-{target}{extension}"
    expected_files.extend((filename, f"{filename}.sha256"))
actual_files = [line.strip() for line in match.group(1).splitlines() if line.strip()]
if actual_files != expected_files:
    raise SystemExit("release set differs from the twelve target files")

print("Release workflow contract passed")
PYTHON
