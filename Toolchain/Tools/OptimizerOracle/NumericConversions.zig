const std = @import("std");
const Differential = @import("Differential.zig");
const Native = @import("Native.zig");

const Case = struct {
    name: []const u8,
    from: []const u8,
    to: []const u8,
    argument: []const u8,
    expected: ?[]const u8 = null,
};

const cases = [_]Case{
    .{ .name = "NegativeUnsigned8", .from = "int8", .to = "uint8", .argument = "-1" },
    .{ .name = "UnsignedSigned8", .from = "uint8", .to = "int8", .argument = "255" },
    .{ .name = "SignedNarrow8", .from = "int64", .to = "int8", .argument = "128" },
    .{ .name = "UnsignedNarrow8", .from = "uint64", .to = "uint8", .argument = "256" },
    .{ .name = "SignedWiden8", .from = "int8", .to = "int64", .argument = "-1", .expected = "-1" },
    .{ .name = "UnsignedWiden8", .from = "uint8", .to = "uint64", .argument = "255", .expected = "255" },
    .{ .name = "NegativeUnsigned16", .from = "int16", .to = "uint16", .argument = "-1" },
    .{ .name = "UnsignedSigned16", .from = "uint16", .to = "int16", .argument = "65535" },
    .{ .name = "SignedNarrow16", .from = "int64", .to = "int16", .argument = "32768" },
    .{ .name = "UnsignedNarrow16", .from = "uint64", .to = "uint16", .argument = "65536" },
    .{ .name = "SignedWiden16", .from = "int16", .to = "int64", .argument = "-1", .expected = "-1" },
    .{ .name = "UnsignedWiden16", .from = "uint16", .to = "uint64", .argument = "65535", .expected = "65535" },
    .{ .name = "NegativeUnsigned32", .from = "int32", .to = "uint32", .argument = "-1" },
    .{ .name = "UnsignedSigned32", .from = "uint32", .to = "int32", .argument = "4294967295" },
    .{ .name = "SignedNarrow32", .from = "int64", .to = "int32", .argument = "2147483648" },
    .{ .name = "UnsignedNarrow32", .from = "uint64", .to = "uint32", .argument = "4294967296" },
    .{ .name = "SignedWiden32", .from = "int32", .to = "int64", .argument = "-1", .expected = "-1" },
    .{ .name = "UnsignedWiden32", .from = "uint32", .to = "uint64", .argument = "4294967295", .expected = "4294967295" },
    .{ .name = "NegativeUnsigned64", .from = "int64", .to = "uint64", .argument = "-1" },
    .{ .name = "UnsignedSigned64", .from = "uint64", .to = "int64", .argument = "18446744073709551615" },
    .{ .name = "IntegerFloatLoss", .from = "int64", .to = "float32", .argument = "16777217" },
    .{ .name = "IntegerDoubleLoss", .from = "int64", .to = "float64", .argument = "9007199254740993" },
    .{ .name = "SignedFloatUpper", .from = "int64", .to = "float64", .argument = "9223372036854775807" },
    .{ .name = "SignedFloatMinimum", .from = "int64", .to = "float64", .argument = "-9223372036854775808", .expected = "-9223372036854775808.0" },
    .{ .name = "UnsignedFloatHigh", .from = "uint64", .to = "float64", .argument = "9223372036854775808", .expected = "9223372036854775808.0" },
    .{ .name = "UnsignedFloatLoss", .from = "uint64", .to = "float64", .argument = "18446744073709551615" },
    .{ .name = "UnsignedSingleLoss", .from = "uint64", .to = "float32", .argument = "18446744073709551615" },
    .{ .name = "UnsignedSingleHigh", .from = "uint64", .to = "float32", .argument = "9223372036854775808", .expected = "9223372036854775808.0" },
    .{ .name = "FloatFraction", .from = "float64", .to = "int64", .argument = "1.5" },
    .{ .name = "FloatUpper", .from = "float64", .to = "int64", .argument = "9223372036854775808.0" },
    .{ .name = "FloatMinimum", .from = "float64", .to = "int64", .argument = "-9223372036854775808.0", .expected = "-9223372036854775808" },
    .{ .name = "FloatUnsignedHigh", .from = "float64", .to = "uint64", .argument = "9223372036854775808.0", .expected = "9223372036854775808" },
    .{ .name = "FloatUnsignedUpper", .from = "float64", .to = "uint64", .argument = "18446744073709551616.0" },
    .{ .name = "FloatNegativeUnsigned", .from = "float64", .to = "uint64", .argument = "-1.0" },
    .{ .name = "FloatNarrowLoss", .from = "float64", .to = "float32", .argument = "0.1" },
    .{ .name = "FloatNarrowExact", .from = "float64", .to = "float32", .argument = "1.5", .expected = "1.5" },
    .{ .name = "FloatNegativeZero", .from = "float64", .to = "int64", .argument = "-0.0", .expected = "0" },
    .{ .name = "FloatNaNInteger", .from = "float64", .to = "int64", .argument = "0.0 / 0.0" },
    .{ .name = "FloatInfinityInteger", .from = "float64", .to = "int64", .argument = "1.0 / 0.0" },
    .{ .name = "FloatNaNNarrow", .from = "float64", .to = "float32", .argument = "0.0 / 0.0" },
    .{ .name = "SingleFraction", .from = "float32", .to = "int8", .argument = "1.5" },
    .{ .name = "SingleUpper", .from = "float32", .to = "uint8", .argument = "256.0" },
    .{ .name = "SingleExact", .from = "float32", .to = "int8", .argument = "127.0", .expected = "127" },
};

fn source(allocator: std.mem.Allocator, entry: Case) ![]const u8 {
    const comparison = if (entry.expected) |expected| try std.fmt.allocPrint(allocator, " == {s}", .{expected}) else "";
    return std.fmt.allocPrint(allocator, "func convert(value:{s}) {s} {{ return value as {s} }}\n" ++
        "func main() {{ print(true); print(convert({s}){s}); print(false) }}\n", .{ entry.from, entry.to, entry.to, entry.argument, comparison });
}

fn check(entry: Case, result: Differential.Result) !void {
    if (result.execution != .completed) return error.ConversionExecutionFailed;
    const run = result.execution.completed;
    const expected_exit: u8 = if (entry.expected == null) 1 else 0;
    const expected_output = if (entry.expected == null) "true\n" else "true\ntrue\nfalse\n";
    if (run.exit_code != expected_exit or !std.mem.eql(u8, run.stdout, expected_output)) {
        std.debug.print("conversion contract failed: {s}, exit={d}, stdout={s}\n", .{ entry.name, run.exit_code, run.stdout });
        return error.ConversionContractFailed;
    }
    if (entry.expected == null) {
        if (std.mem.indexOf(u8, run.stderr, "invalid numeric conversion") == null) return error.MissingConversionDiagnostic;
    } else if (run.stderr.len != 0) return error.UnexpectedConversionDiagnostic;
}

pub fn qualify(allocator: std.mem.Allocator, io: std.Io, compiler: []const u8, directory: []const u8) !usize {
    try std.Io.Dir.cwd().createDirPath(io, directory);
    const manifest = try std.fs.path.join(allocator, &.{ directory, "Package.json" });
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = manifest, .data = "{\"sources\":\".\"}\n" });
    for (cases) |entry| {
        const stem = try std.fs.path.join(allocator, &.{ directory, entry.name });
        const path = try std.fmt.allocPrint(allocator, "{s}.sx", .{stem});
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = try source(allocator, entry) });
        const differential = try Differential.verifyPath(io, allocator, path);
        try check(entry, differential);
        _ = try Native.verify(allocator, io, compiler, path, differential.execution, stem, true);
    }
    return cases.len;
}

test "numeric conversion boundaries preserve exact values or their ordered diagnostic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    for (cases) |entry| try check(entry, try Differential.verify(arena.allocator(), try source(arena.allocator(), entry)));
}
