const std = @import("std");

pub fn snapshot(allocator: std.mem.Allocator, bindings: anytype, count: usize) ![]bool {
    const state = try allocator.alloc(bool, count);
    for (bindings[0..count], state) |binding, *available| available.* = binding.available;
    return state;
}

pub fn restore(bindings: anytype, state: []const bool) void {
    for (bindings[0..state.len], state) |*binding, available| binding.available = available;
}

pub fn merge(target: []bool, state: []const bool) void {
    for (target, state) |*available, incoming| available.* = available.* and incoming;
}

pub fn requireHeader(self: anytype, bindings: anytype, header: []const bool, position: @import("../Source.zig").Position) !void {
    for (bindings[0..header.len], header) |binding, expected| {
        if (binding.available == expected) continue;
        const message = try std.fmt.allocPrint(
            self.allocator,
            "loop must restore availability of '{s}' before its next iteration",
            .{binding.name},
        );
        return self.fail(position, message);
    }
}
