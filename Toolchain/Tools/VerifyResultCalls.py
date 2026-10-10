"""Verify Result call policy through the interpreter and native Debug/Release CLI."""
import argparse
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("binary", type=Path)
parser.add_argument("source_root", type=Path)
args = parser.parse_args()
binary = args.binary.resolve()
source_root = args.source_root.resolve()
cases = [
    (source_root / "Tests/Functions/ResultCalls.sx", 0, "", None),
    (source_root / "Tests/Functions/ResultUsage.sx", 0, "42\nempty\n", None),
    (source_root / "Toolchain/Fixtures/ResultCalls/Payloads.sx", 0, "", None),
    (source_root / "Toolchain/Fixtures/ResultCalls/Failure.sx", 1, "kept\n", "code: 7, subject: null"),
    (source_root / "Toolchain/Fixtures/ResultCalls/StringFailure.sx", 1, "original failure\n", "runtime error: original failure"),
]
for source, expected_code, expected_stdout, expected_error in cases:
    for mode in ("interpret", "--debug", "--release"):
        command = [str(binary), "interpret", str(source)] if mode == "interpret" else [str(binary), "run", str(source), "--backend", "native", mode, "--nocache"]
        result = subprocess.run(command, text=True, capture_output=True)
        assert result.returncode == expected_code, (command, result.returncode, result.stdout, result.stderr)
        assert result.stdout == expected_stdout, (command, result.stdout, result.stderr)
        if expected_error:
            assert expected_error in result.stderr, (command, result.stderr)
            assert "unreachable" not in result.stdout, command
        else:
            assert not result.stderr, (command, result.stderr)
        print(f"Result call policy: {source.name} {mode} passed", flush=True)
