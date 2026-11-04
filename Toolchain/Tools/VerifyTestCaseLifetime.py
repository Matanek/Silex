"""Verify that per-case scratch lifetime preserves failure output and continuation."""
import argparse
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("binary", type=Path)
parser.add_argument("source_root", type=Path)
args = parser.parse_args()
binary = args.binary.resolve()
fixture = args.source_root.resolve() / "Toolchain/Fixtures/TestCases/Lifetimes.sx"
for entry, prefix in [(fixture, ""), (fixture.parent, "Lifetimes.sx :: ")]:
    result = subprocess.run([str(binary), "test", str(entry)], text=True, capture_output=True, timeout=90)
    expected = ("before\nok - " + prefix + "before failure\n"
                "failure\nFAILED - " + prefix + "expected failure\n"
                "after\nok - " + prefix + "after failure\n"
                "2 passed; 1 failed" + (" in 1 files" if prefix else "") + "\n")
    assert result.returncode == 1, (result.returncode, result.stdout, result.stderr)
    assert result.stdout == expected, (result.stdout, result.stderr)
    assert "assertion failed" in result.stderr, result.stderr
    assert "native test '" + prefix + "expected failure' exited with code 1" in result.stderr, result.stderr
    print("Test case lifetime: " + ("directory" if prefix else "file") + " failure and continuation passed", flush=True)
