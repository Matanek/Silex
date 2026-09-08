const std = @import("std");
const Benchmark = @import("Benchmark.zig");

pub const minimum_samples = 11;
pub const maximum_spread_ppm = 200_000;

pub const required_llvm_families = [_][]const u8{
    "new-pass-manager-and-analysis-invalidation",
    "instcombine-and-simplifycfg",
    "mem2reg-sroa-and-early-cse",
    "lazy-value-info-and-correlated-propagation",
    "basic-aa-memoryssa-and-dse",
    "global-value-numbering",
    "ipsccp-attributor-and-function-attrs",
    "inline-cost-and-cgscc",
    "loop-simplify-indvars-licm-and-rotate",
    "loop-vectorize-and-slp-vectorizer",
    "target-transform-info",
    "selectiondag-globalisel-and-combiner",
    "machine-scheduler",
    "greedy-register-allocation-and-spill-placement",
    "lit-filecheck-and-differential-testing",
};

pub fn auditClosedCoverage(coverage: anytype) !void {
    for (coverage) |entry| {
        if (std.mem.eql(u8, entry.state, "gap")) {
            std.debug.print("parity registry: coverage gap '{s}' owned by {s}\n", .{
                entry.id,
                entry.owner_part,
            });
            return error.OpenCoverageGap;
        }
        if (std.mem.eql(u8, entry.state, "equivalent") and
            (!entry.semantic or !entry.cost_model or !entry.debug or !entry.release or !entry.structure))
        {
            return error.UnprovedEquivalentEntry;
        }
    }
}

pub fn auditClosedTransposition(transposition: anytype) !void {
    for (required_llvm_families) |required| {
        var found = false;
        for (transposition) |entry| {
            if (std.mem.eql(u8, entry.family, required)) {
                found = true;
                break;
            }
        }
        if (!found) {
            std.debug.print("parity registry: required LLVM family missing: {s}\n", .{required});
            return error.MissingRequiredLlvmFamily;
        }
    }
    for (transposition) |entry| {
        if (std.mem.eql(u8, entry.verdict, "gap")) {
            std.debug.print("parity registry: LLVM transposition gap '{s}' owned by {s}\n", .{
                entry.family,
                entry.owner_part,
            });
            return error.OpenTranspositionGap;
        }
    }
}

pub fn qualifyTiming(pair: Benchmark.Pair) !void {
    if (pair.left.samples < minimum_samples or pair.right.samples < minimum_samples or
        pair.left.samples % 2 == 0 or pair.right.samples % 2 == 0 or
        pair.left.samples != pair.right.samples or pair.left.batch != pair.right.batch)
    {
        return error.InsufficientQualifiedSamples;
    }
    if (pair.left.spreadPpm() > maximum_spread_ppm or
        pair.right.spreadPpm() > maximum_spread_ppm)
    {
        return error.ExcessiveTimingDispersion;
    }
    if (pair.relative.samples != pair.left.samples or pair.relative.upper_bound_ppm == 0)
        return error.InvalidTimingReference;
    if (pair.relative.upper_bound_ppm <= 1_000_000) return;
    if (pair.relative.lower_bound_ppm > 1_000_000) return error.SlowerThanLlvm;
    return error.InconclusiveTiming;
}

fn summary(samples: usize, p10: u64, median: u64, p90: u64) Benchmark.Summary {
    return .{
        .samples = samples,
        .batch = 4,
        .minimum_ns = p10,
        .percentile_10_ns = p10,
        .median_ns = median,
        .percentile_90_ns = p90,
        .maximum_ns = p90,
        .median_absolute_deviation_ns = 1,
    };
}

fn relative(samples: usize, lower: u64, median: u64, upper: u64) Benchmark.RelativeSummary {
    return .{
        .samples = samples,
        .lower_bound_ppm = lower,
        .median_ppm = median,
        .upper_bound_ppm = upper,
        .confidence_ppm = 967_285,
    };
}

test "qualified timing accepts only a Silex upper bound at or below LLVM" {
    try qualifyTiming(.{
        .left = summary(11, 80, 85, 90),
        .right = summary(11, 90, 95, 100),
        .relative = relative(11, 800_000, 880_000, 950_000),
    });
}

test "qualified timing rejects a ratio whose ranges are entirely slower" {
    try std.testing.expectError(error.SlowerThanLlvm, qualifyTiming(.{
        .left = summary(11, 111, 115, 119),
        .right = summary(11, 96, 100, 104),
        .relative = relative(11, 1_100_000, 1_150_000, 1_190_000),
    }));
}

test "qualified timing rejects excessive dispersion" {
    try std.testing.expectError(error.ExcessiveTimingDispersion, qualifyTiming(.{
        .left = summary(11, 70, 100, 130),
        .right = summary(11, 90, 100, 110),
        .relative = relative(11, 700_000, 1_000_000, 1_300_000),
    }));
}

test "qualified timing rejects an inconclusive overlap" {
    try std.testing.expectError(error.InconclusiveTiming, qualifyTiming(.{
        .left = summary(11, 92, 99, 106),
        .right = summary(11, 95, 100, 105),
        .relative = relative(11, 950_000, 990_000, 1_050_000),
    }));
}

test "qualified timing rejects a diagnostic five-sample comparison" {
    try std.testing.expectError(error.InsufficientQualifiedSamples, qualifyTiming(.{
        .left = summary(5, 80, 85, 90),
        .right = summary(5, 90, 95, 100),
        .relative = relative(5, 800_000, 880_000, 950_000),
    }));
}
