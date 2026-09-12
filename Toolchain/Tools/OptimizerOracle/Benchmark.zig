const std = @import("std");

pub const Config = struct {
    samples: usize = 11,
    warmups: usize = 2,
    minimum_workload_ns: u64 = 10 * std.time.ns_per_ms,
    target_sample_ns: u64 = 100 * std.time.ns_per_ms,
    maximum_batch: usize = 128,
};

pub const Summary = struct {
    samples: usize,
    batch: usize,
    minimum_ns: u64,
    percentile_10_ns: u64,
    median_ns: u64,
    percentile_90_ns: u64,
    maximum_ns: u64,
    median_absolute_deviation_ns: u64,

    pub fn deviationPpm(self: Summary) u64 {
        if (self.median_ns == 0) return 0;
        return @intCast((@as(u128, self.median_absolute_deviation_ns) * 1_000_000) / self.median_ns);
    }

    pub fn spreadPpm(self: Summary) u64 {
        if (self.median_ns == 0) return 0;
        return @intCast((@as(u128, self.percentile_90_ns - self.percentile_10_ns) * 1_000_000) / self.median_ns);
    }
};

pub const Pair = struct {
    left: Summary,
    right: Summary,
    relative: RelativeSummary,
    observations: []const Observation,
};

pub const FirstBackend = enum { left, right };

pub const Observation = struct {
    index: usize,
    first: FirstBackend,
    left_ns: u64,
    right_ns: u64,

    pub fn ratioPpm(self: Observation) !u64 {
        if (self.right_ns == 0) return error.InvalidTimingReference;
        return @intCast((@as(u128, self.left_ns) * 1_000_000) / self.right_ns);
    }
};

pub const Stationarity = struct {
    left_half_shift_ppm: u64,
    right_half_shift_ppm: u64,
    ratio_half_shift_ppm: u64,
};

pub const RelativeSummary = struct {
    samples: usize,
    lower_bound_ppm: u64,
    median_ppm: u64,
    upper_bound_ppm: u64,
    confidence_ppm: u64,
};

pub fn measurePair(
    allocator: std.mem.Allocator,
    io: std.Io,
    left_executable: []const u8,
    right_executable: []const u8,
    config: Config,
) !Pair {
    if (config.samples < 5 or config.samples % 2 == 0 or config.maximum_batch == 0) {
        return error.InvalidBenchmarkConfiguration;
    }
    for (0..config.warmups) |_| {
        _ = try runBatch(allocator, io, left_executable, 1);
        _ = try runBatch(allocator, io, right_executable, 1);
    }
    const left_probe = try runBatch(allocator, io, left_executable, 1);
    const right_probe = try runBatch(allocator, io, right_executable, 1);
    if (left_probe < config.minimum_workload_ns or right_probe < config.minimum_workload_ns) {
        return error.WorkloadTooShort;
    }
    const faster_probe = @max(@min(left_probe, right_probe), 1);
    const desired_batch = @max(
        @as(u64, 1),
        (config.target_sample_ns + faster_probe - 1) / faster_probe,
    );
    const batch: usize = @intCast(@min(desired_batch, config.maximum_batch));

    const left_samples = try allocator.alloc(u64, config.samples);
    const right_samples = try allocator.alloc(u64, config.samples);
    const observations = try allocator.alloc(Observation, config.samples);
    for (0..config.samples) |index| {
        if (index % 2 == 0) {
            left_samples[index] = try normalizedBatch(allocator, io, left_executable, batch);
            right_samples[index] = try normalizedBatch(allocator, io, right_executable, batch);
        } else {
            right_samples[index] = try normalizedBatch(allocator, io, right_executable, batch);
            left_samples[index] = try normalizedBatch(allocator, io, left_executable, batch);
        }
        observations[index] = .{
            .index = index,
            .first = if (index % 2 == 0) .left else .right,
            .left_ns = left_samples[index],
            .right_ns = right_samples[index],
        };
    }
    return .{
        .left = try summarize(allocator, left_samples, batch),
        .right = try summarize(allocator, right_samples, batch),
        .relative = try summarizeRelative(allocator, left_samples, right_samples),
        .observations = observations,
    };
}

pub fn stationarity(pair: Pair) !Stationarity {
    const observations = pair.observations;
    if (observations.len < 5 or observations.len > 63 or observations.len % 2 == 0)
        return error.InvalidBenchmarkConfiguration;
    const half = observations.len / 2;
    var first_left: [31]u64 = undefined;
    var second_left: [31]u64 = undefined;
    var first_right: [31]u64 = undefined;
    var second_right: [31]u64 = undefined;
    var first_ratio: [31]u64 = undefined;
    var second_ratio: [31]u64 = undefined;
    for (observations, 0..) |observation, index| {
        const expected_first: FirstBackend = if (index % 2 == 0) .left else .right;
        if (observation.index != index or
            observation.first != expected_first)
            return error.InvalidObservationOrder;
        if (index == half) continue;
        const destination = if (index < half) index else index - half - 1;
        if (index < half) {
            first_left[destination] = observation.left_ns;
            first_right[destination] = observation.right_ns;
            first_ratio[destination] = try observation.ratioPpm();
        } else {
            second_left[destination] = observation.left_ns;
            second_right[destination] = observation.right_ns;
            second_ratio[destination] = try observation.ratioPpm();
        }
    }
    return .{
        .left_half_shift_ppm = halfWindowShiftPpm(first_left[0..half], second_left[0..half]),
        .right_half_shift_ppm = halfWindowShiftPpm(first_right[0..half], second_right[0..half]),
        .ratio_half_shift_ppm = halfWindowShiftPpm(first_ratio[0..half], second_ratio[0..half]),
    };
}

fn halfWindowShiftPpm(first: []u64, second: []u64) u64 {
    std.mem.sort(u64, first, {}, std.sort.asc(u64));
    std.mem.sort(u64, second, {}, std.sort.asc(u64));
    const first_median = percentile(first, 50);
    const second_median = percentile(second, 50);
    if (first_median == 0) return std.math.maxInt(u64);
    const difference = if (first_median >= second_median)
        first_median - second_median
    else
        second_median - first_median;
    return @intCast((@as(u128, difference) * 1_000_000) / first_median);
}

fn summarizeRelative(
    allocator: std.mem.Allocator,
    left: []const u64,
    right: []const u64,
) !RelativeSummary {
    if (left.len < 5 or left.len != right.len or left.len > 63) return error.InvalidBenchmarkConfiguration;
    const ratios = try allocator.alloc(u64, left.len);
    defer allocator.free(ratios);
    for (left, right, ratios) |left_value, right_value, *ratio| {
        if (right_value == 0) return error.InvalidTimingReference;
        ratio.* = @intCast((@as(u128, left_value) * 1_000_000) / right_value);
    }
    std.mem.sort(u64, ratios, {}, std.sort.asc(u64));
    const bound = oneSidedMedianBound(ratios.len);
    return .{
        .samples = ratios.len,
        .lower_bound_ppm = ratios[ratios.len - 1 - bound.index],
        .median_ppm = percentile(ratios, 50),
        .upper_bound_ppm = ratios[bound.index],
        .confidence_ppm = bound.confidence_ppm,
    };
}

const MedianBound = struct {
    index: usize,
    confidence_ppm: u64,
};

fn oneSidedMedianBound(samples: usize) MedianBound {
    std.debug.assert(samples >= 5 and samples <= 63);
    const total: u128 = @as(u128, 1) << @intCast(samples);
    var combination: u128 = 1;
    var cumulative: u128 = 0;
    for (0..samples) |index| {
        cumulative += combination;
        if (cumulative * 1_000_000 >= total * 950_000) return .{
            .index = index,
            .confidence_ppm = @intCast((cumulative * 1_000_000) / total),
        };
        combination = (combination * (samples - index)) / (index + 1);
    }
    unreachable;
}

fn normalizedBatch(
    allocator: std.mem.Allocator,
    io: std.Io,
    executable: []const u8,
    batch: usize,
) !u64 {
    return (try runBatch(allocator, io, executable, batch)) / batch;
}

fn runBatch(
    allocator: std.mem.Allocator,
    io: std.Io,
    executable: []const u8,
    batch: usize,
) !u64 {
    const started = std.Io.Clock.awake.now(io);
    for (0..batch) |_| {
        const result = try std.process.run(allocator, io, .{
            .argv = &.{executable},
            .stdout_limit = .limited(1024 * 1024),
            .stderr_limit = .limited(1024 * 1024),
        });
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        const success = switch (result.term) {
            .exited => |code| code == 0,
            else => false,
        };
        if (!success) return error.BenchmarkCommandFailed;
    }
    return @intCast(started.untilNow(io, .awake).nanoseconds);
}

fn summarize(allocator: std.mem.Allocator, values: []const u64, batch: usize) !Summary {
    if (values.len == 0) return error.InvalidBenchmarkConfiguration;
    const sorted = try allocator.dupe(u64, values);
    defer allocator.free(sorted);
    std.mem.sort(u64, sorted, {}, std.sort.asc(u64));
    const median = percentile(sorted, 50);
    const deviations = try allocator.alloc(u64, sorted.len);
    defer allocator.free(deviations);
    for (sorted, 0..) |value, index| deviations[index] = if (value >= median) value - median else median - value;
    std.mem.sort(u64, deviations, {}, std.sort.asc(u64));
    return .{
        .samples = values.len,
        .batch = batch,
        .minimum_ns = sorted[0],
        .percentile_10_ns = percentile(sorted, 10),
        .median_ns = median,
        .percentile_90_ns = percentile(sorted, 90),
        .maximum_ns = sorted[sorted.len - 1],
        .median_absolute_deviation_ns = percentile(deviations, 50),
    };
}

fn percentile(sorted: []const u64, value: usize) u64 {
    const index = ((sorted.len - 1) * value + 50) / 100;
    return sorted[index];
}

test "summary uses robust median and deviation statistics" {
    const values = [_]u64{ 100, 102, 99, 101, 10_000 };
    const summary = try summarize(std.testing.allocator, &values, 3);
    try std.testing.expectEqual(@as(u64, 101), summary.median_ns);
    try std.testing.expectEqual(@as(u64, 1), summary.median_absolute_deviation_ns);
    try std.testing.expectEqual(@as(usize, 3), summary.batch);
}

test "paired ratios expose an exact one-sided median bound" {
    const left = [_]u64{ 80, 82, 84, 86, 88, 90, 92, 94, 96, 98, 100 };
    const right = [_]u64{100} ** left.len;
    const relative = try summarizeRelative(std.testing.allocator, &left, &right);
    try std.testing.expectEqual(@as(u64, 840_000), relative.lower_bound_ppm);
    try std.testing.expectEqual(@as(u64, 900_000), relative.median_ppm);
    try std.testing.expectEqual(@as(u64, 960_000), relative.upper_bound_ppm);
    try std.testing.expectEqual(@as(u64, 967_285), relative.confidence_ppm);
}

test "stationarity retains pair order and measures half-window shifts" {
    const observations = [_]Observation{
        .{ .index = 0, .first = .left, .left_ns = 80, .right_ns = 100 },
        .{ .index = 1, .first = .right, .left_ns = 82, .right_ns = 100 },
        .{ .index = 2, .first = .left, .left_ns = 84, .right_ns = 100 },
        .{ .index = 3, .first = .right, .left_ns = 88, .right_ns = 100 },
        .{ .index = 4, .first = .left, .left_ns = 90, .right_ns = 100 },
    };
    const result = try stationarity(.{
        .left = undefined,
        .right = undefined,
        .relative = undefined,
        .observations = &observations,
    });
    try std.testing.expectEqual(@as(u64, 97_560), result.left_half_shift_ppm);
    try std.testing.expectEqual(@as(u64, 0), result.right_half_shift_ppm);
    try std.testing.expectEqual(@as(u64, 97_560), result.ratio_half_shift_ppm);
}

test "stationarity rejects reordered observations" {
    const observations = [_]Observation{
        .{ .index = 0, .first = .left, .left_ns = 80, .right_ns = 100 },
        .{ .index = 1, .first = .left, .left_ns = 82, .right_ns = 100 },
        .{ .index = 2, .first = .left, .left_ns = 84, .right_ns = 100 },
        .{ .index = 3, .first = .right, .left_ns = 86, .right_ns = 100 },
        .{ .index = 4, .first = .left, .left_ns = 88, .right_ns = 100 },
    };
    try std.testing.expectError(error.InvalidObservationOrder, stationarity(.{
        .left = undefined,
        .right = undefined,
        .relative = undefined,
        .observations = &observations,
    }));
}
