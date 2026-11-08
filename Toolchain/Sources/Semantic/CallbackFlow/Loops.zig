const std = @import("std");
const Ir = @import("../../Ir.zig");
// A backward numbered edge may be an acyclic join. Only a path from a block
// back to itself makes that allocation/call site dynamically repeatable.
pub fn program(a: std.mem.Allocator, p: Ir.Program) ![]const []const bool {
    const result = try a.alloc([]const bool, p.functions.len);
    for (p.functions, result) |f, *out| out.* = try blocks(a, f);
    return result;
}
pub fn blocks(a: std.mem.Allocator, f: Ir.Function) ![]const bool {
    const result = try a.alloc(bool, f.blocks.len);
    @memset(result, false);
    const visited = try a.alloc(bool, f.blocks.len);
    defer a.free(visited);
    const queue = try a.alloc(usize, f.blocks.len);
    defer a.free(queue);
    for (result, 0..) |*out, start| {
        @memset(visited, false);
        var len: usize = 1;
        queue[0] = start;
        visited[start] = true;
        var head: usize = 0;
        while (head < len and !out.*) : (head += 1) {
            var targets: [2]usize = undefined;
            const count: usize = switch (f.blocks[queue[head]].terminator) {
                .jump => |target| v: {
                    targets[0] = target;
                    break :v 1;
                },
                .branch => |branch| v: {
                    targets = .{ branch.then_block, branch.else_block };
                    break :v 2;
                },
                else => 0,
            };
            for (targets[0..count]) |target| {
                if (target == start) {
                    out.* = true;
                    break;
                }
                if (!visited[target]) {
                    visited[target] = true;
                    queue[len] = target;
                    len += 1;
                }
            }
        }
    }
    return result;
}
test "callback loops do not classify a backward acyclic join as repetition" {
    const f: Ir.Function = .{ .name = "join", .parameter_types = &.{}, .return_type = .void, .value_types = &.{}, .blocks = &.{
        .{ .instructions = &.{}, .terminator = .{ .jump = 2 } },
        .{ .instructions = &.{}, .terminator = .return_void },
        .{ .instructions = &.{}, .terminator = .{ .jump = 1 } },
    } };
    const actual = try blocks(std.testing.allocator, f);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(bool, &.{ false, false, false }, actual);
}
test "callback loops mark the complete cycle and exclude its exit" {
    const f: Ir.Function = .{ .name = "loop", .parameter_types = &.{}, .return_type = .void, .value_types = &.{}, .blocks = &.{
        .{ .instructions = &.{}, .terminator = .{ .jump = 2 } },
        .{ .instructions = &.{}, .terminator = .{ .jump = 2 } },
        .{ .instructions = &.{}, .terminator = .{ .branch = .{ .condition = 0, .then_block = 1, .else_block = 3 } } },
        .{ .instructions = &.{}, .terminator = .return_void },
    } };
    const actual = try blocks(std.testing.allocator, f);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(bool, &.{ false, true, true, false }, actual);
}
test "callback loops recognize a self edge" {
    const f: Ir.Function = .{ .name = "self", .parameter_types = &.{}, .return_type = .void, .value_types = &.{}, .blocks = &.{.{ .instructions = &.{}, .terminator = .{ .jump = 0 } }} };
    const actual = try blocks(std.testing.allocator, f);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(bool, &.{true}, actual);
}
