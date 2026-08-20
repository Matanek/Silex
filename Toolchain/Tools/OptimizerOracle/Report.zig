const std = @import("std");
const Benchmark = @import("Benchmark.zig");
const IrStats = @import("IrStats.zig");

pub fn line(io: std.Io, allocator: std.mem.Allocator, comptime format: []const u8, arguments: anytype) !void {
    const message = try std.fmt.allocPrint(allocator, format ++ "\n", arguments);
    try std.Io.File.stdout().writeStreamingAll(io, message);
}

pub fn heading(io: std.Io, allocator: std.mem.Allocator, name: []const u8) !void {
    try line(io, allocator, "optimizer oracle: {s}", .{name});
}

pub fn benchmark(
    io: std.Io,
    allocator: std.mem.Allocator,
    label: []const u8,
    summary: Benchmark.Summary,
) !void {
    try line(io, allocator, "  {s}: median {d} ns, MAD {d} ppm, p10..p90 {d}..{d} ns", .{
        label,
        summary.median_ns,
        summary.deviationPpm(),
        summary.percentile_10_ns,
        summary.percentile_90_ns,
    });
}

pub fn ir(
    io: std.Io,
    allocator: std.mem.Allocator,
    raw: IrStats.Counts,
    optimized: IrStats.Counts,
) !void {
    try line(io, allocator, "  IR: {d} -> {d} instructions, {d} -> {d} blocks, {d} -> {d} values", .{
        raw.instructions,
        optimized.instructions,
        raw.blocks,
        optimized.blocks,
        raw.values,
        optimized.values,
    });
}
