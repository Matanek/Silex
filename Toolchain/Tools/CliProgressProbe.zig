const std = @import("std");
const Progress = @import("cli_progress");

pub fn main(init: std.process.Init) !void {
    Progress.configure(init.environ_map);
    defer Progress.shutdown();
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 1 and std.mem.eql(u8, args[1], "install")) {
        var progress = Progress.Install.init(init.io);
        defer progress.finish();
        progress.package(.download, "Example", .{ .major = 1, .minor = 0, .patch = 0 });
        try std.Io.sleep(init.io, .fromMilliseconds(1300), .awake);
        progress.complete("Example", .{ .major = 1, .minor = 0, .patch = 0 }, true);
        progress.package(.install, "Second", null);
        try std.Io.sleep(init.io, .fromMilliseconds(300), .awake);
        progress.failed("Second", null, "test diagnostic");
        return;
    }
    var progress = Progress.Build.init(init.io);
    defer progress.finish();
    progress.source(.analyze, "Example.sx");
    try std.Io.sleep(init.io, .fromMilliseconds(300), .awake);
    progress.stage(.optimize);
    // Exercise animation while the caller does CPU work without yielding to Io.
    const deadline = std.Io.Clock.awake.now(init.io).nanoseconds + 1300 * std.time.ns_per_ms;
    while (std.Io.Clock.awake.now(init.io).nanoseconds < deadline) std.atomic.spinLoopHint();
    try progress.writeOutput("IR\n");
    std.debug.print("test diagnostic during progress\n", .{});
    try std.Io.sleep(init.io, .fromMilliseconds(300), .awake);
    progress.finish();
    Progress.shutdown();
    try std.Io.File.stdout().writeStreamingAll(init.io, "application output\n");
    try std.Io.sleep(init.io, .fromMilliseconds(300), .awake);
}
