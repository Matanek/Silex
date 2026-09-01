const std = @import("std");
const Packages = @import("Packages.zig");
const TargetModule = @import("Target.zig");

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
    const result = try std.process.run(allocator, io, .{ .argv = arguments.items });
    switch (result.term) {
        .exited => |code| if (code == 0) return,
        else => {},
    }
    if (result.stderr.len != 0) std.debug.print("{s}", .{result.stderr});
    return error.LinkFailed;
}

fn stringLessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}
