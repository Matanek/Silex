const std = @import("std");
const Packages = @import("Packages.zig");
const TargetModule = @import("Target.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Error = Allocator.Error || error{LinkFailed};

pub fn executable(
    allocator: Allocator,
    io: Io,
    target: TargetModule.Target,
    object_path: []const u8,
    output_path: []const u8,
    providers: []const Packages.BoundaryProvider,
) !void {
    const triple = if (target.eql(.linux_x64))
        "x86_64-linux-gnu"
    else if (target.eql(.windows_x64))
        "x86_64-windows-gnu"
    else if (target.eql(.windows_arm64))
        "aarch64-windows-gnu"
    else
        return error.LinkFailed;
    var arguments: std.ArrayList([]const u8) = .empty;
    try arguments.appendSlice(allocator, &.{ "zig", "cc", "-target", triple, object_path, "-o", output_path });
    for (providers) |provider| try arguments.append(allocator, provider.archive);
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
