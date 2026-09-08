const std = @import("std");
const Silex = @import("silex_optimizer_api");
const Native = @import("Native.zig");
const Report = @import("Report.zig");

const root = ".zig-cache/optimizer-oracle/robustness/ProjectStress";
const package_count = 16;
const maximum_source_bytes = 1024 * 1024;
const maximum_ir_bytes = 8 * 1024 * 1024;
const maximum_native_bytes = 16 * 1024 * 1024;

const Verification = struct {
    raw_sha256: [64]u8,
    optimized_sha256: [64]u8,
    output_sha256: [64]u8,
    packages: usize,
    loaded_modules: usize,
    portable_functions: usize,
    source_bytes: usize,
    raw_bytes: usize,
    optimized_bytes: usize,
    execution: Silex.Interpreter.RunResult,
    optimized: Silex.Ir.Program,
};

pub fn run(io: std.Io, allocator: std.mem.Allocator, silex_binary: []const u8) !void {
    try materialize(io, allocator);
    const main_path = root ++ "/Main.sx";
    const first = try verify(io, allocator, main_path);
    const repeated = try verify(io, allocator, main_path);
    if (!std.mem.eql(u8, &first.raw_sha256, &repeated.raw_sha256) or
        !std.mem.eql(u8, &first.optimized_sha256, &repeated.optimized_sha256) or
        !std.mem.eql(u8, &first.output_sha256, &repeated.output_sha256))
    {
        return error.NondeterministicStressProject;
    }
    if (first.packages != package_count + 1 or first.loaded_modules < package_count + 1 or
        first.portable_functions < package_count + 3) return error.IncompleteStressGraph;
    if (first.source_bytes > maximum_source_bytes or first.raw_bytes > maximum_ir_bytes or
        first.optimized_bytes > maximum_ir_bytes) return error.StressBudgetExceeded;

    const native = try Native.verify(
        allocator,
        io,
        silex_binary,
        main_path,
        .{ .completed = first.execution },
        root ++ "/native",
        true,
    );
    const repeated_native = try Native.verify(
        allocator,
        io,
        silex_binary,
        main_path,
        .{ .completed = first.execution },
        root ++ "/native-repeated",
        true,
    );
    if (native.debug_size.? > maximum_native_bytes or native.release_size > maximum_native_bytes)
        return error.NativeArtifactBudgetExceeded;
    if (repeated_native.debug_size.? > maximum_native_bytes or repeated_native.release_size > maximum_native_bytes)
        return error.NativeArtifactBudgetExceeded;
    const debug_sha256 = try fileSha256(allocator, io, root ++ "/native-debug.silex.o");
    const release_sha256 = try fileSha256(allocator, io, root ++ "/native-release");
    const repeated_debug_sha256 = try fileSha256(allocator, io, root ++ "/native-repeated-debug.silex.o");
    const repeated_release_sha256 = try fileSha256(allocator, io, root ++ "/native-repeated-release");
    if (!std.mem.eql(u8, &debug_sha256, &repeated_debug_sha256) or
        !std.mem.eql(u8, &release_sha256, &repeated_release_sha256))
    {
        return error.NondeterministicNativeStressCode;
    }

    var report: std.Io.Writer.Allocating = .init(allocator);
    errdefer report.deinit();
    try report.writer.writeAll(
        "raw_sha256\toptimized_sha256\toutput_sha256\tpackages\tloaded_modules\tportable_functions\t" ++
            "source_bytes\traw_ir_bytes\toptimized_ir_bytes\tdebug_bytes\trelease_bytes\t" ++
            "debug_code_sha256\trelease_executable_sha256\tarm64\tx64\n",
    );
    try report.writer.print("{s}\t{s}\t{s}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{s}\t{s}\tpassed\tpassed\n", .{
        &first.raw_sha256,
        &first.optimized_sha256,
        &first.output_sha256,
        first.packages,
        first.loaded_modules,
        first.portable_functions,
        first.source_bytes,
        first.raw_bytes,
        first.optimized_bytes,
        native.debug_size.?,
        native.release_size,
        &debug_sha256,
        &release_sha256,
    });
    try sealReport(io, allocator, root ++ "/project-stress-v1.tsv", try report.toOwnedSlice());
    try Report.heading(io, allocator, "large package graph and function stress passed");
}

fn materialize(io: std.Io, allocator: std.mem.Allocator) !void {
    try std.Io.Dir.cwd().createDirPath(io, root ++ "/.silex/links");
    var manifest: std.Io.Writer.Allocating = .init(allocator);
    errdefer manifest.deinit();
    try manifest.writer.writeAll("{\"sources\":\".\",\"dependencies\":{");
    var main: std.Io.Writer.Allocating = .init(allocator);
    errdefer main.deinit();
    for (0..package_count) |index| {
        const name = try std.fmt.allocPrint(allocator, "RobustPkg{d}", .{index});
        if (index != 0) try manifest.writer.writeByte(',');
        try manifest.writer.print("\"{s}\":\"=1.0.0\"", .{name});
        try main.writer.print("use {s}\n", .{name});
        const module_directory = try std.fmt.allocPrint(allocator, "{s}/{s}/Module", .{ root, name });
        try std.Io.Dir.cwd().createDirPath(io, module_directory);
        const package_manifest = try std.fmt.allocPrint(allocator, "{s}/{s}/Package.json", .{ root, name });
        const package_manifest_bytes = try std.fmt.allocPrint(
            allocator,
            "{{\"name\":\"{s}\",\"version\":\"1.0.0\"}}\n",
            .{name},
        );
        try writeFile(io, package_manifest, package_manifest_bytes);
        const module_path = try std.fmt.allocPrint(allocator, "{s}/@Module.sx", .{module_directory});
        const module_source = try std.fmt.allocPrint(
            allocator,
            "public func value() int {{ return {d} }}\n",
            .{index + 1},
        );
        try writeFile(io, module_path, module_source);
        const link_path = try std.fmt.allocPrint(allocator, "{s}/.silex/links/{s}.json", .{ root, name });
        const package_root = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root, name });
        const link = try std.fmt.allocPrint(allocator, "{{\"path\":\"{s}\"}}\n", .{package_root});
        try writeFile(io, link_path, link);
    }
    try manifest.writer.writeAll("}}\n");
    try writeFile(io, root ++ "/Package.json", try manifest.toOwnedSlice());

    try main.writer.writeAll(
        \\struct Wide {
        \\    var a:int; var b:int; var c:int; var d:int
        \\    var e:int; var f:int; var g:int; var h:int
        \\}
        \\func recursive(value:int) int {
        \\    if value <= 0 { return 0 }
        \\    return value + recursive(value - 1)
        \\}
        \\func aggregate(seed:int) int {
        \\    var wide = Wide(a:seed, b:2, c:3, d:4, e:5, f:6, g:7, h:8)
        \\    let snapshot = copy wide
        \\    wide.a += recursive(12)
        \\    let values:int[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
        \\    var total = snapshot.a + wide.a + wide.b + wide.c + wide.d
        \\    for value in values { total += value }
        \\    return total + wide.e + wide.f + wide.g + wide.h
        \\}
        \\func main() {
        \\    var total = aggregate(3)
    );
    try main.writer.writeByte('\n');
    for (0..package_count) |index| {
        try main.writer.print("    total += RobustPkg{d}.value()\n", .{index});
    }
    try main.writer.writeAll("    print(total)\n}\n");
    const main_bytes = try main.toOwnedSlice();
    if (main_bytes.len > maximum_source_bytes) return error.StressSourceBudgetExceeded;
    try writeFile(io, root ++ "/Main.sx", main_bytes);
}

fn verify(io: std.Io, allocator: std.mem.Allocator, main_path: []const u8) !Verification {
    var compiler = Silex.Project.Compiler.init(allocator, io);
    const compilation = try compiler.compile(main_path);
    try Silex.ReleaseVerifier.verify(allocator, compilation.ir);
    const raw_execution = try Silex.Interpreter.runCapture(allocator, compilation.ir);
    const optimized = try Silex.ReleaseOptimizer.optimizeWithOptions(allocator, compilation.ir, .{
        .verify_each_pass = true,
    });
    try Silex.ReleaseVerifier.verify(allocator, optimized);
    const optimized_execution = try Silex.Interpreter.runCapture(allocator, optimized);
    if (!equalRun(raw_execution, optimized_execution)) return error.SemanticMismatch;
    const raw_text = try Silex.Ir.writeText(allocator, compilation.ir);
    const optimized_text = try Silex.Ir.writeText(allocator, optimized);
    _ = try Silex.Arm64Lower.lowerWithMode(allocator, optimized, .release);
    const stack_machine = try Silex.Arm64Lower.lowerWithMode(allocator, optimized, .debug);
    _ = try Silex.X64RegisterAllocation.allocateProgram(allocator, stack_machine);
    return .{
        .raw_sha256 = sha256(raw_text),
        .optimized_sha256 = sha256(optimized_text),
        .output_sha256 = runHash(raw_execution),
        .packages = compilation.metrics.packages,
        .loaded_modules = compilation.metrics.loaded_modules,
        .portable_functions = compilation.metrics.portable_functions,
        .source_bytes = compilation.metrics.source_bytes_read,
        .raw_bytes = raw_text.len,
        .optimized_bytes = optimized_text.len,
        .execution = raw_execution,
        .optimized = optimized,
    };
}

fn equalRun(left: Silex.Interpreter.RunResult, right: Silex.Interpreter.RunResult) bool {
    return left.exit_code == right.exit_code and
        std.mem.eql(u8, left.stdout, right.stdout) and
        std.mem.eql(u8, left.stderr, right.stderr);
}

fn runHash(result: Silex.Interpreter.RunResult) [64]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(&.{result.exit_code});
    hasher.update(result.stdout);
    hasher.update(result.stderr);
    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

fn sha256(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

fn fileSha256(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![64]u8 {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(maximum_native_bytes + 1));
    return sha256(bytes);
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

test "stress project scale is intentionally bounded" {
    try std.testing.expect(package_count >= 16);
    try std.testing.expect(maximum_source_bytes <= 1024 * 1024);
    try std.testing.expect(maximum_ir_bytes <= 8 * 1024 * 1024);
    try std.testing.expect(maximum_native_bytes <= 16 * 1024 * 1024);
}
