"""Replay the archived balanced Silex pair on physical macOS ARM64."""
from pathlib import Path
import hashlib, json, sys
root = Path(__file__).resolve().parent
sys.path.insert(0, str(root.parents[3] / "Benchmarks/Native"))
import campaign
import calibrate
host = campaign.host_profile()
if host["machine"] != "arm64" or host["translated"] or host["system"] != "Darwin":
    raise RuntimeError("These archived binaries require physical macOS ARM64")
manifest = json.loads((root / "manifest.json").read_text())
for name, sha in manifest["files"].items():
    if hashlib.sha256((root / name).read_bytes()).hexdigest() != sha:
        raise RuntimeError("Evidence checksum mismatch: " + name)
result = calibrate.measure_balanced_pair(root / "private-class-measurement/after", root / "private-class-measurement/before")
print(json.dumps({"host": host, "workload": result}, indent=2))
