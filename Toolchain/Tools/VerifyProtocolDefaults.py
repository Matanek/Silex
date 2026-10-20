"""Verify default protocol methods through interpreter and native Debug/Release."""
import argparse
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("binary", type=Path)
parser.add_argument("source_root", type=Path)
args = parser.parse_args()
binary = args.binary.resolve()
source = args.source_root.resolve() / "Tests/Types/Protocols/Defaults.sx"
expected = "protocol defaults verified\n"

for mode in ("interpret", "--debug", "--release"):
    command = ([str(binary), "interpret", str(source)] if mode == "interpret" else
               [str(binary), "run", str(source), "--backend", "native", mode])
    # A cold and two reusable executions exercise helper identity in the cache.
    for cache in (("--nocache",), (), ()):
        result = subprocess.run(command + list(cache), text=True, capture_output=True)
        assert result.returncode == 0, (command, cache, result.returncode, result.stdout, result.stderr)
        assert result.stdout == expected, (command, cache, result.stdout, result.stderr)
        assert not result.stderr, (command, cache, result.stderr)
    print(f"Protocol defaults: {mode} uncached and cached passed", flush=True)
