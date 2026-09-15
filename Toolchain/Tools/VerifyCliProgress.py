#!/usr/bin/env python3
"""Exercise the real progress renderer in POSIX pseudo-terminals, without screenshots."""
import argparse
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import struct
import subprocess
import termios
import time


def capture(probe, mode, width, term):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, width, 0, 0))
    child = subprocess.Popen([str(probe), mode], stdout=slave, stderr=slave,
                             env=dict(os.environ, TERM=term))
    os.close(slave)
    chunks = []
    deadline = time.monotonic() + 15
    try:
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.1)[0]:
                try:
                    data = os.read(master, 65536)
                except OSError:
                    break
                if not data:
                    break
                chunks.append(data)
            if child.poll() is not None and not select.select([master], [], [], 0.1)[0]:
                break
        assert child.wait(timeout=1) == 0
    finally:
        if child.poll() is None:
            child.kill()
            child.wait()
        os.close(master)
    return b"".join(chunks).decode()


def screen_text(text, width):
    """Replay the cursor/erase sequences emitted by std.Progress.

    Checking raw logs alone cannot detect a diagnostic erased by a later redraw.
    Unknown control sequences fail rather than silently claiming preservation.
    """
    rows = [[" "] * width for _ in range(24)]
    row = col = 0
    tokens = re.findall(r"\x1b\][^\x1b\x07]*(?:\x1b\\|\x07)|\x1b\[[0-?]*[ -/]*[@-~]|\x1bM|[^\x1b]", text)
    for token in tokens:
        if token.startswith("\x1b]") or token in ("\x1b[?2026h", "\x1b[?2026l"):
            continue
        if token == "\x1b[J":
            rows[row][col:] = [" "] * (width - col)
            for index in range(row + 1, len(rows)):
                rows[index] = [" "] * width
        elif token == "\x1bM":
            row = max(0, row - 1)
        elif token == "\r":
            col = 0
        elif token == "\n":
            row += 1
        elif token.startswith("\x1b"):
            raise AssertionError("Unknown terminal sequence " + repr(token))
        else:
            if col == width:
                row += 1
                col = 0
            if row == len(rows):
                rows.pop(0)
                rows.append([" "] * width)
                row -= 1
            rows[row][col] = token
            col += 1
    return "\n".join("".join(line).rstrip() for line in rows).rstrip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("probe", type=Path)
    args = parser.parse_args()
    probe = args.probe.resolve(strict=True)
    for mode, width, term in (("build", 100, "xterm-256color"),
                              ("install", 100, "xterm-256color"),
                              ("build", 35, "xterm-256color"),
                              ("build", 100, "dumb")):
        text = capture(probe, mode, width, term)
        if term != "dumb":
            assert re.search(r"silex: [|/\\-] 1s ", text), repr(text)
            assert len(set(re.findall(r"silex: ([|/\\-])", text))) > 1, repr(text)
        else:
            assert "\x1b" not in text, repr(text)
        screen = screen_text(text, width)
        if mode == "build":
            assert "test diagnostic during progress" in screen, screen
            assert "IR" in screen.splitlines(), screen
            assert "application output\r\n" in text
            assert not text.split("application output\r\n")[-1], repr(text)
        else:
            assert "[ready] Example@1.0.0 (installed)" in screen, screen
            assert "[failed] Second: test diagnostic" in screen, screen
            assert "[1]" in text
        print(f"{mode}, {width} columns, {term}: PASS", flush=True)
    for mode in ("build", "install"):
        result = subprocess.run([str(probe), mode], capture_output=True,
                                text=True, check=True, timeout=15)
        assert "[analyze]" not in result.stderr and "[download]" not in result.stderr
        assert "\x1b" not in result.stderr
    print("redirected stderr stays free of progress: PASS")


if __name__ == "__main__":
    main()
