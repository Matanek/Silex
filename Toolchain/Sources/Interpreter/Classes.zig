const std = @import("std");
const Value = @import("Value.zig").Value;

pub const Entry = struct {
    instance: *Value.Structure,
    roots: usize = 0,
    dropped: bool = false,
};

pub fn register(allocator: std.mem.Allocator, heap: *std.ArrayList(Entry), instance: *Value.Structure) !void {
    try heap.append(allocator, .{ .instance = instance });
}

pub fn retain(heap: []Entry, instance: *Value.Structure) !void {
    const entry = find(heap, instance) orelse return error.InvalidProgram;
    if (entry.dropped) return error.InvalidProgram;
    entry.roots += 1;
}

pub fn release(heap: []Entry, instance: *Value.Structure) !bool {
    const entry = find(heap, instance) orelse return error.InvalidProgram;
    if (entry.dropped) return false;
    if (entry.roots != 0) entry.roots -= 1;
    if (entry.roots != 0) return false;
    entry.dropped = true;
    return true;
}

fn find(heap: []Entry, instance: *Value.Structure) ?*Entry {
    for (heap) |*entry| if (entry.instance == instance) return entry;
    return null;
}
