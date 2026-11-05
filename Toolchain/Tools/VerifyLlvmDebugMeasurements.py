"""Independently recompute LLVM Debug measurement gates from the exported observations."""
import argparse
import json
import pathlib
import random
import statistics

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("dataset", type=pathlib.Path)
args = parser.parse_args()
data = json.loads(args.dataset.read_text())
median = statistics.median

def near(left, right):
    assert abs(left - right) < 1e-12, (left, right)

def interval(values):
    ordered = sorted(values)
    return dict(lower_two_sided_95=ordered[249], upper_two_sided_95=ordered[9749],
                upper_one_sided_95=ordered[9499])

def stability(points):
    center = median(points)
    spread = max(points) - min(points)
    delta = median(points[3:]) - median(points[:3])
    ratio = median(points[3:]) / median(points[:3])
    return spread <= .05 and abs(delta) <= .05 if center < 1 else spread / center <= .10 and 1 / 1.05 <= ratio <= 1.05

cohorts = data["reference_controls"] | data["configurations"]
assert len(data["reference_controls"]) == 2 and len(data["configurations"]) == 20
checked = {}
for name, cohort in cohorts.items():
    blocks, expected = cohort["blocks"], cohort["assessment"]
    assert len(blocks) == 6 and [b["round"] for b in blocks] == list(range(6))
    assert all(len(b["samples"][v]) == b["subpair_count"] for b in blocks for v in "AB")
    samples = [sample for b in blocks for rows in b["samples"].values() for sample in rows]
    assert all(s["exit"] == 0 and s["reason"] is None and s["inputs_unchanged"] and not s["profile_run"] for s in samples)
    assert len({s["output_sha256"] for s in samples}) == 1 and all(b["output_identical"] for b in blocks)
    raw = {v: [s["wall_s"] for b in blocks for s in b["samples"][v]] for v in "AB"}
    points = {v: [median(s["wall_s"] for s in b["samples"][v]) for b in blocks] for v in "AB"}
    rss = {v: [max(s["process_metrics"]["maximum_rss_bytes"] for s in b["samples"][v]) for b in blocks] for v in "AB"}
    sizes = {v: [max(s["binary_bytes"] for s in b["samples"][v]) for b in blocks] for v in "AB"}
    near(median(raw["B"]) / median(raw["A"]), expected["median_raw_wall_ratio"])
    near(median(raw["B"]) - median(raw["A"]), expected["median_raw_wall_delta"])
    draws = {key: [] for key in ["wall_ratio_ci", "wall_delta_ci", "rss_ratio_ci", "size_ratio_ci"]}
    rng = random.Random(20261104)
    for _ in range(10000):
        ids = [rng.randrange(6) for _ in range(6)]
        aa = [s["wall_s"] for i in ids for s in blocks[i]["samples"]["A"]]
        bb = [s["wall_s"] for i in ids for s in blocks[i]["samples"]["B"]]
        draws["wall_ratio_ci"].append(median(bb) / median(aa))
        draws["wall_delta_ci"].append(median(bb) - median(aa))
        draws["rss_ratio_ci"].append(median(rss["B"][i] / rss["A"][i] for i in ids))
        draws["size_ratio_ci"].append(median(sizes["B"][i] / sizes["A"][i] for i in ids))
    computed = {key: interval(values) for key, values in draws.items()}
    for key, values in computed.items():
        for metric, value in values.items():
            near(value, expected[key][metric])
    neutral = (
        computed["wall_delta_ci"]["lower_two_sided_95"] >= -.05 and computed["wall_delta_ci"]["upper_two_sided_95"] <= .05
        if median(raw["A"]) < 1 else
        computed["wall_ratio_ci"]["lower_two_sided_95"] >= 1 / 1.05 and computed["wall_ratio_ci"]["upper_two_sided_95"] <= 1.05
    )
    latency = computed["wall_ratio_ci"]["upper_one_sided_95"] <= 1.05 or (
        median(raw["A"]) < 1 and computed["wall_delta_ci"]["upper_one_sided_95"] <= .05)
    passed = stability(points["A"]) and latency and computed["rss_ratio_ci"]["upper_one_sided_95"] <= 1.10 and computed["size_ratio_ci"]["upper_one_sided_95"] <= 1.10
    if expected["control"]:
        passed = passed and stability(points["B"]) and neutral
        assert neutral == expected["control_neutral"]
    assert passed and expected["passed"] and expected["all_outputs_identical"]
    assert latency == expected["latency_guard"]
    phase = []
    for b in blocks:
        phase.append({v: [next(p["nanoseconds"] for p in s["trace"]["phases"] if p["name"] == "frontend_total") / 1e9
                          for s in b["samples"][v]] for v in "AB"})
    rng = random.Random(20261104)
    ratios = []
    for _ in range(10000):
        ids = [rng.randrange(6) for _ in range(6)]
        aa = [value for i in ids for value in phase[i]["A"]]
        bb = [value for i in ids for value in phase[i]["B"]]
        ratios.append(median(bb) / median(aa))
    target = cohort["frontend_assessment"]["phases"]["frontend_total"]
    for metric, value in interval(ratios).items():
        near(value, target["ratio_" + metric])
    checked[name] = "exact"

functional = data["functional"]
tools = functional["tool-controls"]
cache = functional["cache-controls"]
corpus = functional["llvm-corpus"]
assert tools["passed"] and cache["passed"] and corpus["passed"]
assert len(corpus["cases"]) == 123 and all(len(c["runs"]) == 2 for c in corpus["cases"])
assert all(r["identical_executable"] and r["identical_observable"] for c in corpus["cases"] for r in c["runs"])
assert tools["invalid_module"]["rejected"]
assert len(cache["runs"]) == 14
for mode in ["debug", "release"]:
    rows = [r for r in cache["runs"] if r["mode"] == mode]
    assert [r["stage"] for r in rows] == ["cold", "hit", "consumer", "entry", "caller", "callee", "forced"]
    assert rows[1]["trace"]["cache_result"] == "hit_before_frontend"
    assert all(r["trace"]["metrics"]["llvm_units_reused"] > 0 for r in rows[2:6])
    assert rows[-1]["trace"]["cache_result"] == "disabled" and rows[-1]["trace"]["metrics"]["llvm_units_reused"] == 0
for mode in ["debug", "release"]:
    rows = {r["variant"]: r for r in tools["runs"] if r["mode"] == mode}
    assert rows["A"]["binary_sha256"] == rows["B"]["binary_sha256"]
    assert rows["A"]["llc"] == rows["B"]["llc"] == rows["A"]["units"] == rows["B"]["units"]
    if mode == "debug":
        assert 0 < rows["B"]["opt"] < rows["A"]["opt"]
    else:
        assert rows["B"]["opt"] == rows["A"]["opt"]
assert data["validation"]["measured_processes"] == 624 and data["validation"]["control_processes"] == 48
print(json.dumps(dict(passed=True, cohorts_recomputed=len(checked), measured_processes=624,
                      exact="wall/RSS/size and frontend_total intervals to1e-12", cache_scenarios=14,
                      llvm_cases=123), indent=2))
