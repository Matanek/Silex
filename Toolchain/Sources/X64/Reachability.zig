const std = @import("std");
const Machine = @import("../Arm64/Machine.zig");

const Allocator = std.mem.Allocator;

pub fn find(allocator: Allocator, program: Machine.Program, main: usize) Allocator.Error![]bool {
    const reachable = try allocator.alloc(bool, program.functions.len);
    @memset(reachable, false);
    reachable[main] = true;
    var changed = true;
    while (changed) {
        changed = false;
        for (program.functions, 0..) |function, function_id| {
            if (!reachable[function_id]) continue;
            for (function.instructions) |instruction| switch (instruction) {
                .call => |call| mark(reachable, call.function, &changed),
                .function_address => |address| mark(reachable, address.function, &changed),
                .dynamic_call => |call| {
                    mark(reachable, call.function, &changed);
                    for (call.implementations) |implementation| mark(reachable, implementation.function, &changed);
                },
                .class_drop => |drop| for (drop.plans) |plan| for (plan.functions) |finalizer| mark(reachable, finalizer, &changed),
                else => {},
            };
        }
    }
    return reachable;
}

fn mark(reachable: []bool, function: usize, changed: *bool) void {
    if (function >= reachable.len or reachable[function]) return;
    reachable[function] = true;
    changed.* = true;
}
