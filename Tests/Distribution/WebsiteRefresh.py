import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest

sys.dont_write_bytecode = True
script = Path(__file__).resolve().parents[2] / ".github/scripts/refresh-website.py"
spec = importlib.util.spec_from_file_location("refresh_website", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RefreshTests(unittest.TestCase):
    def test_dispatches_exact_version_and_awaits_its_run(self):
        calls = []
        responses = iter([
            {"workflow_run_id": 42},
            {"status": "in_progress"},
            {"status": "completed", "conclusion": "success"},
        ])

        def request(path, *args):
            calls.append((path, args))
            return next(responses)

        sleeps = []
        module.refresh("0.47.0", request, sleeps.append)
        self.assertTrue(calls[0][0].endswith("/actions/workflows/deploy.yml/dispatches"))
        self.assertIn("inputs[silex_version]=0.47.0", calls[0][1])
        self.assertEqual(calls[1][0], "repos/Matanek/Silex-Website/actions/runs/42")
        self.assertEqual(calls[1], calls[2])
        self.assertEqual(sleeps, [10])

    def test_rejected_dispatch_is_not_success(self):
        def reject(*args):
            raise subprocess.CalledProcessError(1, "gh", stderr="HTTP 403")
        with self.assertRaises(subprocess.CalledProcessError):
            module.refresh("0.47.0", reject)

    def test_missing_run_id_is_not_success(self):
        with self.assertRaisesRegex(RuntimeError, "run ID"):
            module.refresh("0.47.0", lambda *args: {})

    def test_failed_deployment_is_not_success(self):
        for conclusion in ("failure", "cancelled", "timed_out", "skipped"):
            responses = iter([
                {"workflow_run_id": 42},
                {"status": "completed", "conclusion": conclusion},
            ])
            with self.subTest(conclusion=conclusion), self.assertRaises(RuntimeError):
                module.refresh("0.47.0", lambda *args: next(responses))

    def test_timeout_is_bounded(self):
        ticks = iter([0, 901])
        with self.assertRaisesRegex(RuntimeError, "timed out"):
            module.refresh("0.47.0", lambda *args: {"workflow_run_id": 42}, clock=lambda: next(ticks))

    def test_invalid_version_never_dispatches(self):
        for version in ("", "v0.47.0", "0.47.0\n", "0.47.0; echo bad"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                module.refresh(version, lambda *args: self.fail("unexpected dispatch"))


if __name__ == "__main__":
    unittest.main()
