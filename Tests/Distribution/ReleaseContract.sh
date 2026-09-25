#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
workflow="$repository_root/.github/workflows/release.yml"
installer_workflow="$repository_root/.github/workflows/install-smoke.yml"
windows_builder="$repository_root/.github/scripts/build-release-windows.ps1"
windows_smoke="$repository_root/.github/scripts/smoke-release-windows.ps1"
unix_builder="$repository_root/.github/scripts/build-release-unix.sh"
unix_smoke="$repository_root/.github/scripts/smoke-public-unix.sh"
windows_public_smoke="$repository_root/.github/scripts/smoke-public-windows.ps1"
toolchain_setup="$repository_root/Toolchain/Sources/ToolchainSetup.zig"
release_notes="$repository_root/.github/scripts/release-notes.py"

"$repository_root/Tests/Distribution/InstallerUnixContract.sh"
python3 "$repository_root/Tests/Distribution/ReleaseNotes.py"
python3 "$repository_root/Tests/Distribution/WebsiteRefresh.py"
node --test "$repository_root/Tests/Distribution/HeapQualification.mjs"
manifest_version=$(sed -n 's/^[[:space:]]*\.version = "\([^"]*\)",/\1/p' "$repository_root/Toolchain/build.zig.zon")
python3 "$release_notes" validate "$manifest_version"
python3 "$release_notes" extract "$manifest_version" --locale en | grep -Fq '### Impact and migration'

python3 - "$workflow" "$installer_workflow" "$windows_builder" "$windows_smoke" \
    "$unix_builder" "$unix_smoke" "$windows_public_smoke" "$toolchain_setup" <<'PYTHON'
import re
import sys

workflow = open(sys.argv[1], encoding="utf-8").read()
installer_workflow = open(sys.argv[2], encoding="utf-8").read()
windows_builder = open(sys.argv[3], encoding="utf-8").read()
windows_smoke = open(sys.argv[4], encoding="utf-8").read()
unix_builder = open(sys.argv[5], encoding="utf-8").read()
unix_smoke = open(sys.argv[6], encoding="utf-8").read()
windows_public_smoke = open(sys.argv[7], encoding="utf-8").read()
toolchain_setup = open(sys.argv[8], encoding="utf-8").read()
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

release_set = re.search(r"^  release-set:\n(.*?)(?=^  publish:)", workflow, re.MULTILINE | re.DOTALL)
if release_set is None:
    raise SystemExit("missing release-set job")
release_downloads = release_set.group(1).count("uses: actions/download-artifact@v8")
release_filters = re.findall(r"^          pattern: silex-\*$", release_set.group(1), re.MULTILINE)
if release_downloads != 2 or len(release_filters) != release_downloads:
    raise SystemExit("release-set downloads must exclude non-distribution artifacts")

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

if 'release-notes.py validate "$RELEASE_VERSION"' not in workflow:
    raise SystemExit("release preflight must validate the canonical release notes")
if '--notes-file "$RUNNER_TEMP/release-notes.md"' not in workflow or "--generate-notes" in workflow:
    raise SystemExit("GitHub releases must use the canonical release notes")
if "uses: ./.github/workflows/website-refresh.yml" not in workflow or "::warning::" in workflow:
    raise SystemExit("Website refresh must be a required, independently retryable release job")

llvm_contract = (
    "llvm-21.1.8-silex.1",
    "LLVM-21.1.8-macos-arm64.tar.gz",
    "ab010a170718153633c4fcbf302c43eb9c69817db68cd710cf2798fcb7837c8f",
    "llvm/21.1.8/macos-arm64",
)
for marker in llvm_contract:
    if marker not in toolchain_setup:
        raise SystemExit(f"missing managed LLVM setup marker: {marker}")

for script in (unix_builder, unix_smoke):
    defaults = re.findall(r'^expected_backend=(\w+)$', script, re.MULTILINE)
    if defaults != ['native'] or 'expected_backend=llvm' in script or '--backend native' not in script:
        raise SystemExit("Unix distribution smoke must verify the native default on every host")
    if '--backend llvm' not in script:
        raise SystemExit("Unix distribution smoke must retain explicit LLVM qualification on macOS ARM64")
for script in (windows_smoke, windows_public_smoke):
    if 'backend -ne "native"' not in script or '--backend native' not in script:
        raise SystemExit("Windows distribution smoke must verify the native default and explicit native backend")
for script in (unix_builder, windows_smoke):
    if "Toolchain/Tools/QualifyHeap.mjs" not in script:
        raise SystemExit("Every release target must execute the heap qualification fixture")

print("Release workflow contract passed")
PYTHON
