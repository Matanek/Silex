#!/usr/bin/env python3
"""Check that CLI probes retain output and stop owned descendants on timeout."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

sys.dont_write_bytecode = True
from VerifyCacheRetention import run_compiler


class CompilerProcessTests(unittest.TestCase):
    def test_exit_preserves_output_and_clears_stale_trace(self):
        with tempfile.TemporaryDirectory() as directory:
            trace = Path(directory) / "trace.json"
            trace.write_text("stale")
            env = dict(os.environ, SILEX_COMPILATION_TRACE=str(trace))
            result = run_compiler([sys.executable, "-c",
                                   "import sys; print('out'); print('err',file=sys.stderr); sys.exit(7)"], env)
            self.assertEqual((result.returncode, result.stdout, result.stderr), (7, "out\n", "err\n"))
            self.assertFalse(trace.exists())

    def test_timeout_retains_diagnostics_and_stops_descendant(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            marker = root / "orphan-wrote.txt"
            output = root / "program"
            child = "import pathlib,sys,time; time.sleep(3); pathlib.Path(sys.argv[1]).write_text('orphan')"
            parent = ("import pathlib,subprocess,sys,time; "
                      "pathlib.Path(sys.argv[4]+'.silex.o').write_bytes(b'object'); "
                      "subprocess.Popen([sys.executable,'-c',sys.argv[1],sys.argv[2]]); "
                      "print('spawned',flush=True); print('pending',file=sys.stderr,flush=True); time.sleep(30)")
            env = dict(os.environ, SILEX_COMPILATION_TRACE=str(root / "trace.json"))
            captured = io.StringIO()
            with contextlib.redirect_stdout(captured):
                with self.assertRaises(subprocess.TimeoutExpired) as failure:
                    run_compiler([sys.executable, "-c", parent, child, str(marker), "-o", str(output)],
                                 env, timeout=2)
            self.assertIn("spawned", failure.exception.output)
            self.assertIn("pending", failure.exception.stderr)
            self.assertIn('"compiler_timeout_seconds": 2', captured.getvalue())
            pending = json.loads(captured.getvalue().splitlines()[0])
            self.assertEqual(pending["file_bytes"][str(output) + ".silex.o"], 6)
            time.sleep(3.5)
            self.assertFalse(marker.exists(), "compiler descendant survived the timeout")


if __name__ == "__main__":
    unittest.main()
