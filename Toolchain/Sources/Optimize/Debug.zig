const std = @import("std");
const Ir = @import("../Ir.zig");
const Release = @import("Release.zig");

// Keep Debug preparation bounded to local simplification and straight-line
// value helpers. CFG inlining, ranges, global SSA cleanup and register
// allocation remain outside this policy. Every existing safety check keeps
// its source position unless local facts prove it unnecessary.
pub fn prepare(allocator: std.mem.Allocator, program: Ir.Program, worker_count: u16) !Ir.Program {
    return Release.optimizeWithOptions(allocator, program, .{
        .worker_count = worker_count,
        .verify_each_pass = true,
        .disabled = .control_flow_inlining,
        .stop_after = .local_simplification_post,
    });
}
