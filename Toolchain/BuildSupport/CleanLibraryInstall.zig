const std = @import("std");

const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.InvalidArguments;

    const target = args[1];
    if (!std.mem.eql(u8, std.fs.path.basename(target), "silex")) {
        return error.InvalidTarget;
    }
    const parent = std.fs.path.dirname(target) orelse return error.InvalidTarget;
    if (!std.mem.eql(u8, std.fs.path.basename(parent), "lib")) {
        return error.InvalidTarget;
    }

    try Io.Dir.cwd().deleteTree(init.io, target);
}
