#!/usr/bin/env python3
"""Execute the six stack-only probes emitted by the owning machine test."""

import pathlib
import struct
import subprocess
import sys


target, directory = sys.argv[1:]
assert target in ("linux-arm64", "windows-arm64"), target
expectations = sorted(pathlib.Path(directory).glob(f"{target}-*.expected"))
assert len(expectations) == 6, f"expected six probes, found {len(expectations)}"
for expectation in expectations:
    executable = expectation.with_suffix("").resolve()
    data = executable.read_bytes()
    if target == "linux-arm64":
        assert data[:4] == b"\x7fELF" and struct.unpack_from("<H", data, 18)[0] == 183
        executable.chmod(0o700)
    else:
        offset = struct.unpack_from("<I", data, 0x3C)[0]
        assert data[offset:offset + 4] == b"PE\0\0"
        assert struct.unpack_from("<H", data, offset + 4)[0] == 0xAA64
    actual = subprocess.run([str(executable)], capture_output=True, text=True, timeout=10)
    assert actual.returncode == 0, (executable.name, actual.returncode, actual.stderr)
    assert actual.stdout == expectation.read_text(), (executable.name, actual.stdout)
    print(f"PASS {executable.name}")
