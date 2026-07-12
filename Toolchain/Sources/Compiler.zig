const std = @import("std");
const builtin = @import("builtin");
const CppGenerator = @import("CppGenerator.zig");
const ParserModule = @import("Parser.zig");
const Semantic = @import("Semantic.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Compilation = struct {
    executable_path: []const u8,
    cpp_path: []const u8,
    project_path: []const u8,
    program_name: []const u8,
    cache_hit: bool,
};

pub fn compile(allocator: Allocator, io: Io, source_path: []const u8) !Compilation {
    if (!std.mem.endsWith(u8, source_path, ".sx")) {
        std.debug.print("silex: source file must use the .sx extension\n", .{});
        return error.Reported;
    }

    const source = Io.Dir.cwd().readFileAlloc(io, source_path, allocator, .limited(16 * 1024 * 1024)) catch |err| {
        std.debug.print("silex: unable to read '{s}': {t}\n", .{ source_path, err });
        return error.Reported;
    };

    var parser = ParserModule.Parser.init(allocator, source);
    const ast = parser.parse() catch |err| switch (err) {
        error.InvalidSource => return report(source_path, parser.diagnostic.?),
        else => |other| return other,
    };

    var analyzer = Semantic.Analyzer.init(allocator);
    const program = analyzer.analyze(ast) catch |err| switch (err) {
        error.InvalidSource => return report(source_path, analyzer.diagnostic.?),
        else => |other| return other,
    };

    const cpp = try CppGenerator.generate(allocator, program);
    const project_path = "";
    const source_name = std.fs.path.basename(source_path);
    const program_name = source_name[0 .. source_name.len - 3];
    const cache_key = cacheKey(cpp);
    const cache_dir = try std.fs.path.join(allocator, &.{ project_path, ".silex", "cache", &cache_key });
    try Io.Dir.cwd().createDirPath(io, cache_dir);

    const cpp_path = try std.fs.path.join(allocator, &.{ cache_dir, "Generated.cpp" });
    const executable_path = try std.fs.path.join(allocator, &.{ cache_dir, program_name });
    const cache_hit = try fileExists(io, executable_path);

    if (!cache_hit) {
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = cpp_path, .data = cpp });
        const term = try runProcess(io, &.{ "c++", "-std=c++23", cpp_path, "-o", executable_path });
        if (exitCode(term) != 0) return error.NativeCompilationFailed;
    }

    return .{
        .executable_path = executable_path,
        .cpp_path = cpp_path,
        .project_path = project_path,
        .program_name = program_name,
        .cache_hit = cache_hit,
    };
}

pub fn runProcess(io: Io, arguments: []const []const u8) !std.process.Child.Term {
    var child = try std.process.spawn(io, .{
        .argv = arguments,
        .stdin = .inherit,
        .stdout = .inherit,
        .stderr = .inherit,
    });
    defer child.kill(io);
    return child.wait(io);
}

pub fn exitCode(term: std.process.Child.Term) u8 {
    return switch (term) {
        .exited => |code| code,
        else => 1,
    };
}

pub fn defaultOutputPath(
    allocator: Allocator,
    project_path: []const u8,
    program_name: []const u8,
) ![]const u8 {
    return std.fs.path.join(allocator, &.{ project_path, ".silex", "bin", program_name });
}

pub fn copyArtifact(io: Io, source_path: []const u8, destination_path: []const u8) !void {
    if (std.fs.path.dirname(destination_path)) |directory| {
        if (directory.len > 0) try Io.Dir.cwd().createDirPath(io, directory);
    }
    try Io.Dir.copyFile(.cwd(), source_path, .cwd(), destination_path, io, .{ .make_path = true });
}

fn report(source_path: []const u8, diagnostic: @import("Source.zig").Diagnostic) error{Reported} {
    std.debug.print("{s}:{d}:{d}: error: {s}\n", .{
        source_path,
        diagnostic.position.line,
        diagnostic.position.column,
        diagnostic.message,
    });
    return error.Reported;
}

fn cacheKey(cpp: []const u8) [64]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update("silex-cache-v7\x00");
    hasher.update(@tagName(builtin.target.cpu.arch));
    hasher.update("\x00");
    hasher.update(@tagName(builtin.target.os.tag));
    hasher.update("\x00");
    hasher.update(cpp);

    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    hasher.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

fn fileExists(io: Io, path: []const u8) !bool {
    Io.Dir.cwd().access(io, path, .{ .execute = true }) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |other| return other,
    };
    return true;
}

test "cache key follows generated content" {
    const first = cacheKey("first");
    const repeated = cacheKey("first");
    const changed = cacheKey("second");
    try std.testing.expectEqualSlices(u8, &first, &repeated);
    try std.testing.expect(!std.mem.eql(u8, &first, &changed));
}

test "default output belongs to current project" {
    const output = try defaultOutputPath(std.testing.allocator, "", "Main");
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings(".silex/bin/Main", output);
}
