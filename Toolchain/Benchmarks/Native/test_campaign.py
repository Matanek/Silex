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
