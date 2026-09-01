const std = @import("std");
const Machine = @import("../Arm64/Machine.zig");
const Packages = @import("../Packages.zig");
const TargetModule = @import("../Target.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Error = Allocator.Error || error{LinkFailed};

pub fn executable(
    allocator: Allocator,
    io: Io,
    linker_path: []const u8,
    target: TargetModule.Target,
    object_path: []const u8,
    output_path: []const u8,
    providers: []const Packages.BoundaryProvider,
    functions: []const Machine.ExternalFunction,
) !void {
    const triple = if (target.eql(.macos_arm64))
        "aarch64-macos"
    else if (target.eql(.macos_x64))
        "x86_64-macos"
    else
        return error.LinkFailed;
    const sdk_path = try sdkPath(allocator, io);
    const framework_path = try std.fs.path.join(allocator, &.{ sdk_path, "System/Library/Frameworks" });
    const library_path = try std.fs.path.join(allocator, &.{ sdk_path, "usr/lib" });
    var arguments: std.ArrayList([]const u8) = .empty;
    try arguments.appendSlice(allocator, &.{
        linker_path,  "cc",        "-g", "-target",      triple,
        "-isysroot",  sdk_path,    "-F", framework_path, "-L",
        library_path, object_path, "-o", output_path,
    });
    for (providers) |provider| if (provider.archive) |archive| try arguments.append(allocator, archive);
    var frameworks: std.ArrayList([]const u8) = .empty;
    for (providers) |provider| for (provider.frameworks) |framework| {
        var duplicate = false;
        for (frameworks.items) |existing| if (std.mem.eql(u8, existing, framework)) {
            duplicate = true;
            break;
        };
        if (!duplicate) try frameworks.append(allocator, framework);
    };
    std.mem.sort([]const u8, frameworks.items, {}, stringLessThan);
    if (usesWebKit(functions)) for ([_][]const u8{ "Cocoa", "WebKit" }) |framework| {
        var duplicate = false;
        for (frameworks.items) |existing| if (std.mem.eql(u8, existing, framework)) {
            duplicate = true;
            break;
        };
        if (!duplicate) try frameworks.append(allocator, framework);
    };
    std.mem.sort([]const u8, frameworks.items, {}, stringLessThan);
    for (frameworks.items) |framework| try arguments.appendSlice(allocator, &.{ "-framework", framework });
    var libraries: std.ArrayList([]const u8) = .empty;
    for (providers) |provider| for (provider.libraries) |library| {
        var duplicate = false;
        for (libraries.items) |existing| if (std.mem.eql(u8, existing, library)) {
            duplicate = true;
            break;
        };
        if (!duplicate) try libraries.append(allocator, library);
    };
    std.mem.sort([]const u8, libraries.items, {}, stringLessThan);
    for (libraries.items) |library| try arguments.append(allocator, try std.fmt.allocPrint(allocator, "-l{s}", .{library}));
    if (usesWebKit(functions)) try arguments.append(allocator, "-lobjc");

    const result = try std.process.run(allocator, io, .{ .argv = arguments.items });
    switch (result.term) {
        .exited => |code| if (code == 0) return,
        else => {},
    }
    if (result.stderr.len != 0) std.debug.print("{s}", .{result.stderr});
    return error.LinkFailed;
}

pub fn requiresSystemLink(functions: []const Machine.ExternalFunction) bool {
    return usesWebKit(functions);
}

fn usesWebKit(functions: []const Machine.ExternalFunction) bool {
    for (functions) |function| if (std.mem.eql(u8, function.provider, "MacOS.web_kit")) return true;
    return false;
}

fn sdkPath(allocator: Allocator, io: Io) ![]const u8 {
    const result = try std.process.run(allocator, io, .{
        .argv = &.{ "xcrun", "--sdk", "macosx", "--show-sdk-path" },
    });
    switch (result.term) {
        .exited => |code| if (code == 0) {
            const path = std.mem.trim(u8, result.stdout, " \t\r\n");
            if (path.len != 0) return path;
        },
        else => {},
    }
    if (result.stderr.len != 0) std.debug.print("{s}", .{result.stderr});
    return error.LinkFailed;
}

fn stringLessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}

test "link and execute a symbol from a static ARM64 archive" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "provider.c",
        .data = "int boundary_answer(void) { return 42; }\n",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "main.c",
        .data = "extern int boundary_answer(void); int main(void) { return boundary_answer() == 42 ? 0 : 1; }\n",
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const provider_source = try std.fs.path.join(allocator, &.{ base, "provider.c" });
    const provider_object = try std.fs.path.join(allocator, &.{ base, "provider.o" });
    const main_source = try std.fs.path.join(allocator, &.{ base, "main.c" });
    const main_object = try std.fs.path.join(allocator, &.{ base, "main.o" });
    const archive = try std.fs.path.join(allocator, &.{ base, "libProvider.a" });
    const output = try std.fs.path.join(allocator, &.{ base, "program" });

    for ([_][]const []const u8{
        &.{ "zig", "cc", "-target", "aarch64-macos", "-c", provider_source, "-o", provider_object },
        &.{ "zig", "cc", "-target", "aarch64-macos", "-c", main_source, "-o", main_object },
        &.{ "zig", "ar", "rcs", archive, provider_object },
    }) |arguments| {
        const result = try std.process.run(allocator, std.testing.io, .{ .argv = arguments });
        try std.testing.expectEqual(@as(u8, 0), exitCode(result.term));
    }
    const providers = [_]Packages.BoundaryProvider{.{
        .name = "Provider",
        .archive = archive,
        .frameworks = &.{},
        .libraries = &.{},
    }};
    try executable(allocator, std.testing.io, "zig", .macos_arm64, main_object, output, &providers, &.{});
    const executed = try std.process.run(allocator, std.testing.io, .{ .argv = &.{output} });
    try std.testing.expectEqual(@as(u8, 0), exitCode(executed.term));
}

fn exitCode(termination: std.process.Child.Term) u8 {
    return switch (termination) {
        .exited => |code| code,
        else => 255,
    };
}
