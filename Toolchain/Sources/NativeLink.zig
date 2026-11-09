const std = @import("std");
const Packages = @import("Packages.zig");
const TargetModule = @import("Target.zig");
const WindowsStartup = @import("Windows/Startup.zig");

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
) !void {
    const triple = if (target.eql(.linux_x64))
        "x86_64-linux-gnu"
    else if (target.eql(.linux_arm64))
        "aarch64-linux-gnu"
    else if (target.eql(.windows_x64))
        "x86_64-windows-gnu"
    else if (target.eql(.windows_arm64))
        "aarch64-windows-gnu"
    else
        return error.LinkFailed;
    var arguments: std.ArrayList([]const u8) = .empty;
    try arguments.appendSlice(allocator, &.{ linker_path, "cc", "-target", triple, object_path, "-o", output_path });
    if (target.eql(.linux_x64)) try arguments.appendSlice(allocator, &.{
        "-L/usr/lib/x86_64-linux-gnu",
        "-L/lib/x86_64-linux-gnu",
        "-L/usr/lib64",
        "-L/lib64",
        "-L/usr/local/lib",
    });
    if (target.eql(.linux_arm64)) try arguments.appendSlice(allocator, &.{
        "-L/usr/lib/aarch64-linux-gnu",
        "-L/lib/aarch64-linux-gnu",
        "-L/usr/lib64",
        "-L/lib64",
        "-L/usr/local/lib",
    });
    var archive_directories: std.ArrayList([]const u8) = .empty;
    for (providers) |provider| if (provider.archive) |archive| {
        const directory = std.fs.path.dirname(archive) orelse continue;
        var duplicate = false;
        for (archive_directories.items) |existing| if (std.mem.eql(u8, existing, directory)) {
            duplicate = true;
            break;
        };
        if (!duplicate) try archive_directories.append(allocator, directory);
    };
    std.mem.sort([]const u8, archive_directories.items, {}, stringLessThan);
    for (archive_directories.items) |directory| {
        try arguments.append(allocator, try std.fmt.allocPrint(allocator, "-L{s}", .{directory}));
    }
    for (providers) |provider| if (provider.archive) |archive| try arguments.append(allocator, archive);
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
    // Keep COFF relocation and provider linking. Only the startup changes: the
    // normal Windows path needs UCRT, not Zig's entire MinGW compatibility CRT.
    // This object is a compiler runtime payload, like the float/deep-copy
    // runtimes, and is removed after linking instead of creating another cache.
    const startup_path = if (target.eql(.windows_arm64) and !WindowsStartup.requiresRuntime(libraries.items))
        try std.fmt.allocPrint(allocator, "{s}.startup.obj", .{object_path})
    else
        null;
    defer if (startup_path) |path| Io.Dir.cwd().deleteFile(io, path) catch {};
    var result = if (startup_path) |path| fast: {
        {
            const file = try Io.Dir.cwd().createFile(io, path, .{});
            defer file.close(io);
            try file.writeStreamingAll(io, @import("windows_startup_object").object_bytes);
        }
        var direct: std.ArrayList([]const u8) = .empty;
        try direct.appendSlice(allocator, arguments.items);
        try direct.appendSlice(allocator, &.{ "-nostdlib", "-Wl,-e,silex_windows_start", path, "-lucrtbase", "-lkernel32" });
        break :fast try std.process.run(allocator, io, .{ .argv = direct.items });
    } else try std.process.run(allocator, io, .{ .argv = arguments.items });
    if (startup_path != null) {
        // A successful link can still contain GNU constructors or pseudo
        // relocations. Inspect the linker's tables before publishing/executing.
        var compatibility = if (succeeded(result.term)) inspect: {
            const file = try Io.Dir.cwd().openFile(io, output_path, .{});
            defer file.close(io);
            break :inspect try WindowsStartup.requiresCompatibility(file, io);
        } else false;
        if (!succeeded(result.term) and std.mem.indexOf(u8, result.stderr, "undefined symbol:") != null) {
            for (providers) |provider| if (provider.archive != null) {
                compatibility = true;
                break;
            };
        }
        if (compatibility) {
            result = try std.process.run(allocator, io, .{ .argv = arguments.items });
        }
    }
    switch (result.term) {
        .exited => |code| if (code == 0) return,
        else => {},
    }
    if (result.stdout.len != 0) std.debug.print("{s}", .{result.stdout});
    if (result.stderr.len != 0) std.debug.print("{s}", .{result.stderr});
    std.debug.print("silex: native linker for {s} terminated with {any}\n", .{ target.name(), result.term });
    return error.LinkFailed;
}

fn succeeded(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
}

fn stringLessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}
