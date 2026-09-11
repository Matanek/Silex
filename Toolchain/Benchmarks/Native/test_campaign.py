import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

import campaign


def observations(release: list[int], clang: list[int]) -> list[dict[str, object]]:
    return [
        {
            "index": index,
            "order": campaign.CONFIGURATIONS,
            "timings_ns": {"debug": left * 2, "release": left, "clang": right},
        }
        for index, (left, right) in enumerate(zip(release, clang))
    ]


class CampaignTests(unittest.TestCase):
    def test_exact_one_sided_bound_matches_optimizer_oracle(self) -> None:
        comparison = campaign.analyze_release_vs_clang(
            observations(list(range(80, 101, 2)), [100] * 11)
        )
        self.assertEqual(comparison["lower_bound_ppm"], 840_000)
        self.assertEqual(comparison["median_ppm"], 900_000)
        self.assertEqual(comparison["upper_bound_ppm"], 960_000)
        self.assertEqual(comparison["confidence_ppm"], 967_285)

    def test_qualification_rejects_drift_and_slow_upper_bound(self) -> None:
        release = [85] * 11 + [105] * 10
        clang = [100] * 21
        comparison = campaign.analyze_release_vs_clang(observations(release, clang))
        workload = {
            "release_vs_clang": comparison,
            "configurations": {
                "release": campaign.summarize(release),
                "clang": campaign.summarize(clang),
            },
        }
        failures = campaign.qualification_failures(workload)
        self.assertTrue(any("half_shift" in failure for failure in failures))
        self.assertTrue(any("upper bound" in failure for failure in failures))

    def test_equivalent_reference_failure_cannot_be_hidden_by_historical_parity(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            for configuration in campaign.CONFIGURATIONS:
                (root / f"arithmetic-{configuration}").touch()
            def execute(path):
                return b"same\n", 50 if path.name.endswith("clang-o3-slot8") else 100
            with patch.object(campaign, "execute", side_effect=execute):
                result = campaign.measure_workload(root, 21, 0, "arithmetic")
        self.assertFalse(result["qualified"])
        self.assertEqual(result["release_vs_clang"]["upper_bound_ppm"], 1_000_000)
        self.assertTrue(any("clang-o3-slot8" in failure for failure in result["qualification_failures"]))

    def test_equivalent_reference_output_is_checked(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            for configuration in campaign.CONFIGURATIONS:
                (root / f"arithmetic-{configuration}").touch()
            def execute(path):
                return (b"wrong\n" if path.name.endswith("clang-o3-slot8") else b"same\n"), 100
            with patch.object(campaign, "execute", side_effect=execute):
                with self.assertRaisesRegex(RuntimeError, "outputs differ"):
                    campaign.measure_workload(root, 5, 1, "arithmetic")

    def test_baseline_is_paired_and_its_output_checked(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            before = root / "before"
            before.mkdir()
            for configuration in campaign.CONFIGURATIONS:
                (root / f"arithmetic-{configuration}").touch()
            (before / "arithmetic-release").touch()
            def execute(path):
                return b"same\n", 200 if path.parent == before else 100
            with patch.object(campaign, "execute", side_effect=execute):
                result = campaign.measure_workload(root, 21, 0, "arithmetic", before)
            self.assertEqual(result["release_vs_baseline"]["upper_bound_ppm"], 500_000)
            self.assertTrue(all("baseline" in item["order"] for item in result["observations"]))
            with patch.object(campaign, "execute", side_effect=lambda path: (b"wrong" if path.parent == before else b"same", 100)):
                with self.assertRaisesRegex(RuntimeError, "outputs differ"):
                    campaign.measure_workload(root, 5, 0, "arithmetic", before)

    def test_native_x64_rejects_arm_and_translation(self) -> None:
        self.assertIsNotNone(
            campaign.native_x64_failure({"machine": "arm64", "translated": False})
        )
        self.assertIsNotNone(
            campaign.native_x64_failure({"machine": "x86_64", "translated": True})
        )
        self.assertIsNone(
            campaign.native_x64_failure({"machine": "x86_64", "translated": False})
        )

    def test_zero_warmups_establishes_output_from_first_measurement(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            for configuration in campaign.CONFIGURATIONS:
                (root / f"arithmetic-{configuration}").touch()
            with patch.object(campaign, "execute", return_value=(b"same\n", 100)):
                result = campaign.measure_workload(root, 5, 0, "arithmetic")
        self.assertEqual(result["output_sha256"], campaign.hashlib.sha256(b"same\n").hexdigest())
        self.assertEqual(len(result["observations"]), 5)


if __name__ == "__main__":
    unittest.main()
