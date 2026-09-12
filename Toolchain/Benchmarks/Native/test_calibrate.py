import hashlib
import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import calibrate
import campaign


class CalibrationTests(unittest.TestCase):
    def artifact(self, directory):
        report = {"candidate_sha": "candidate", "baseline_sha": "baseline", "workloads": []}
        for workload in campaign.WORKLOADS:
            entries = {}
            for configuration in (*campaign.CONFIGURATIONS, "baseline"):
                relative = f"bins/{workload}-{configuration}"
                path = directory / relative
                path.parent.mkdir(exist_ok=True)
                payload = configuration.encode()
                path.write_bytes(payload)
                entries[configuration] = {"path": f"/runner/.zig-cache/{relative}", "sha256": hashlib.sha256(payload).hexdigest()}
            report["workloads"].append({"id": workload, "executables": entries})
        (directory / "optimizer-x64").mkdir()
        (directory / "optimizer-x64/campaign.json").write_text(json.dumps(report))
        return report

    def test_archived_identity_and_checksums_are_required(self):
        with TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.artifact(directory)
            _, binaries = calibrate.verified_artifact(directory, "candidate")
            self.assertEqual(sum(map(len, binaries.values())), 15)
            with self.assertRaises(ValueError):
                calibrate.verified_artifact(directory, "another")
            binaries["objects"]["release"].write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "checksum"):
                calibrate.verified_artifact(directory, "candidate")

    def test_artifact_path_cannot_escape_the_download(self):
        with TemporaryDirectory() as temporary:
            directory = Path(temporary)
            report = self.artifact(directory)
            report["workloads"][0]["executables"]["release"]["path"] = "/runner/.zig-cache/../outside"
            (directory / "optimizer-x64/campaign.json").write_text(json.dumps(report))
            with self.assertRaisesRegex(ValueError, "escapes"):
                calibrate.verified_artifact(directory, "candidate")

    def test_controls_swap_content_and_distinguish_one_file_from_two(self):
        with TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.artifact(directory)
            _, binaries = calibrate.verified_artifact(directory, "candidate")
            for mode, expected in (("forward", (b"release", b"baseline")), ("reverse", (b"baseline", b"release")), ("same_bytes", (b"release", b"release")), ("same_file", (b"release", b"release"))):
                after, before = calibrate.prepare_case(directory / mode, binaries["objects"], mode)
                self.assertEqual(((after / "objects-release").read_bytes(), (before / "objects-release").read_bytes()), expected)
                self.assertEqual(after == before, mode == "same_file")


if __name__ == "__main__":
    unittest.main()
