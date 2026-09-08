const std = @import("std");
const InteractionGenerator = @import("InteractionGenerator.zig");
const Report = @import("Report.zig");

const directory = ".zig-cache/optimizer-oracle/robustness/CacheStress";

pub fn run(io: std.Io, allocator: std.mem.Allocator, silex_binary: []const u8) !void {
    try std.Io.Dir.cwd().createDirPath(io, directory);
    const source_path = directory ++ "/Main.sx";
    const manifest_path = directory ++ "/Package.json";
    try writeFile(io, manifest_path, "{\"sources\":\".\"}\n");
    const first = try InteractionGenerator.source(allocator, .{
        .seed = 0x4341_4348_455f_3031,
        .first_axis = "target",
        .first_state = true,
    });
    const second = try InteractionGenerator.source(allocator, .{
        .seed = 0x4341_4348_455f_3032,
        .first_axis = "target",
        .first_state = true,
    });
    try writeFile(io, source_path, first.main);

    const cold = directory ++ "/cold";
    const warm = directory ++ "/warm";
    const repaired = directory ++ "/repaired";
    try compile(allocator, io, silex_binary, source_path, cold, true);
    try compile(allocator, io, silex_binary, source_path, warm, false);
    const cold_hash = try fileSha256(allocator, io, cold);
    const warm_hash = try fileSha256(allocator, io, warm);
    if (!std.mem.eql(u8, cold_hash, warm_hash)) return error.ColdWarmCacheMismatch;
    try writeFile(io, repaired, "controlled partial artifact");
    try compile(allocator, io, silex_binary, source_path, repaired, false);
    const repaired_hash = try fileSha256(allocator, io, repaired);
    if (!std.mem.eql(u8, cold_hash, repaired_hash)) return error.PartialArtifactNotRepaired;

    try writeFile(io, source_path, second.main);
    const invalidated = directory ++ "/invalidated";
    try compile(allocator, io, silex_binary, source_path, invalidated, false);
    const invalidated_hash = try fileSha256(allocator, io, invalidated);
    if (std.mem.eql(u8, cold_hash, invalidated_hash)) return error.SourceInvalidationMissed;
    try writeFile(io, source_path, first.main);
    const restored = directory ++ "/restored";
    try compile(allocator, io, silex_binary, source_path, restored, false);
    const restored_hash = try fileSha256(allocator, io, restored);
    if (!std.mem.eql(u8, cold_hash, restored_hash)) return error.RestoredSourceMismatch;

    const concurrent_a = directory ++ "/concurrent-a";
    const concurrent_b = directory ++ "/concurrent-b";
    var child_a = try std.process.spawn(io, .{
        .argv = &.{ silex_binary, "compile", source_path, "-r", "-o", concurrent_a },
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .inherit,
    });
    defer child_a.kill(io);
    var child_b = try std.process.spawn(io, .{
        .argv = &.{ silex_binary, "compile", source_path, "-r", "-o", concurrent_b },
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .inherit,
    });
    defer child_b.kill(io);
    if (!successful(try child_a.wait(io)) or !successful(try child_b.wait(io)))
        return error.ConcurrentCompilationFailed;
    const concurrent_a_hash = try fileSha256(allocator, io, concurrent_a);
    const concurrent_b_hash = try fileSha256(allocator, io, concurrent_b);
    if (!std.mem.eql(u8, cold_hash, concurrent_a_hash) or
        !std.mem.eql(u8, cold_hash, concurrent_b_hash))
    {
        return error.ConcurrentCacheMismatch;
    }

    const expected = try successfulCommand(allocator, io, &.{cold});
    for ([_][]const u8{ warm, repaired, restored, concurrent_a, concurrent_b }) |path| {
        const actual = try successfulCommand(allocator, io, &.{path});
        if (!std.mem.eql(u8, expected.stdout, actual.stdout) or
            !std.mem.eql(u8, expected.stderr, actual.stderr)) return error.CacheOutputMismatch;
    }

    var report: std.Io.Writer.Allocating = .init(allocator);
    errdefer report.deinit();
    try report.writer.writeAll("cold_sha256\twarm_sha256\trepaired_sha256\tinvalidated_sha256\trestored_sha256\tconcurrent_a_sha256\tconcurrent_b_sha256\n");
    try report.writer.print("{s}\t{s}\t{s}\t{s}\t{s}\t{s}\t{s}\n", .{
        cold_hash,
        warm_hash,
        repaired_hash,
        invalidated_hash,
        restored_hash,
        concurrent_a_hash,
        concurrent_b_hash,
    });
    try sealReport(io, allocator, directory ++ "/cache-stress.tsv", try report.toOwnedSlice());
    try Report.heading(io, allocator, "cache invalidation and concurrency stress passed");
}

fn compile(
    allocator: std.mem.Allocator,
    io: std.Io,
    silex_binary: []const u8,
    source_path: []const u8,
    output_path: []const u8,
    nocache: bool,
) !void {
    if (nocache) {
        _ = try successfulCommand(allocator, io, &.{ silex_binary, "compile", source_path, "-r", "-n", "-o", output_path });
    } else {
        _ = try successfulCommand(allocator, io, &.{ silex_binary, "compile", source_path, "-r", "-o", output_path });
    }
}

fn fileSha256(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]const u8 {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(32 * 1024 * 1024));
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.allocPrint(allocator, "{s}", .{std.fmt.bytesToHex(digest, .lower)});
}

fn successful(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
}

fn successfulCommand(
    allocator: std.mem.Allocator,
    io: std.Io,
    arguments: []const []const u8,
) !std.process.RunResult {
    const result = try std.process.run(allocator, io, .{
        .argv = arguments,
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
    });
    if (!successful(result.term)) return error.CommandFailed;
    return result;
}

fn sealReport(io: std.Io, allocator: std.mem.Allocator, path: []const u8, bytes: []const u8) !void {
    const existing = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => {
            try writeFile(io, path, bytes);
            return;
        },
        else => return err,
    };
    if (!std.mem.eql(u8, existing, bytes)) return error.SealedReportConflict;
}

fn writeFile(io: std.Io, path: []const u8, bytes: []const u8) !void {
    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}

test "cache stress seeds distinguish invalidation while remaining deterministic" {
    const first = try InteractionGenerator.source(std.testing.allocator, .{
        .seed = 0x4341_4348_455f_3031,
        .first_axis = "target",
        .first_state = true,
    });
    defer std.testing.allocator.free(first.main);
    const repeated = try InteractionGenerator.source(std.testing.allocator, .{
        .seed = 0x4341_4348_455f_3031,
        .first_axis = "target",
        .first_state = true,
    });
    defer std.testing.allocator.free(repeated.main);
    const changed = try InteractionGenerator.source(std.testing.allocator, .{
        .seed = 0x4341_4348_455f_3032,
        .first_axis = "target",
        .first_state = true,
    });
    defer std.testing.allocator.free(changed.main);
    try std.testing.expectEqualStrings(first.main, repeated.main);
    try std.testing.expect(!std.mem.eql(u8, first.main, changed.main));
}
