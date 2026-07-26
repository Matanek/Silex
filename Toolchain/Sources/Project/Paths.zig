const std = @import("std");

pub fn findRoot(allocator: std.mem.Allocator, io: std.Io, input_path: []const u8) anyerror![]const u8 {
    var directory = std.fs.path.dirname(input_path) orelse ".";
    while (true) {
        const manifest = try std.fs.path.join(allocator, &.{ directory, "Package.json" });
        if (fileExists(io, manifest)) return directory;
        const next = std.fs.path.dirname(directory) orelse return std.fs.path.dirname(input_path) orelse ".";
        if (std.mem.eql(u8, next, directory)) return std.fs.path.dirname(input_path) orelse ".";
        directory = next;
    }
}

fn fileExists(io: std.Io, path: []const u8) bool {
    _ = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return true;
}
