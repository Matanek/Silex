#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
workflow="$repository_root/.github/workflows/release.yml"
installer_workflow="$repository_root/.github/workflows/install-smoke.yml"
windows_builder="$repository_root/.github/scripts/build-release-windows.ps1"
windows_smoke="$repository_root/.github/scripts/smoke-release-windows.ps1"

"$repository_root/Tests/Distribution/InstallerUnixContract.sh"

python3 - "$workflow" "$installer_workflow" "$windows_builder" "$windows_smoke" <<'PYTHON'
import re
import sys

workflow = open(sys.argv[1], encoding="utf-8").read()
installer_workflow = open(sys.argv[2], encoding="utf-8").read()
windows_builder = open(sys.argv[3], encoding="utf-8").read()
windows_smoke = open(sys.argv[4], encoding="utf-8").read()
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

if 'zig build "-Dtarget=$zigTarget"' not in windows_builder:
    raise SystemExit("Windows release build target must be an interpolated PowerShell argument")

windows_arm64_build = re.search(
    r"^  windows-arm64-build:\n(.*?)(?=^  windows-arm64:)", workflow, re.MULTILINE | re.DOTALL
)
if windows_arm64_build is None:
    raise SystemExit("missing Windows ARM64 cross-build job")
if "zig build -Dtarget=aarch64-windows" not in windows_arm64_build.group(1):
    raise SystemExit("Windows ARM64 release must be cross-built for aarch64-windows")
if "70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00" not in windows_arm64_build.group(1):
    raise SystemExit("Windows ARM64 cross-build must pin the Linux Zig archive checksum")
if 'release target $Target does not match host $osArchitecture' not in windows_smoke:
    raise SystemExit("Windows release smoke must reject a mismatched native host")

print("Release workflow contract passed")
PYTHON
