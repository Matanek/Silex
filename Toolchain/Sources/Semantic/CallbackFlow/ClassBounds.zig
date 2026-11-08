const std = @import("std");
const Ir = @import("../../Ir.zig");
const M = @import("Model.zig");
const A = std.mem.Allocator;

pub fn subtype(p: Ir.Program, candidate: usize, base: usize) bool {
    var current: ?usize = candidate;
    while (current) |id| : (current = p.structures[id].base) if (id == base) return true;
    return false;
}

pub fn program(a: A, p: Ir.Program) ![]const []const usize {
    const result = try a.alloc([]const usize, p.structures.len);
    for (p.structures, 0..) |structure, id| {
        var alternatives: std.ArrayList(usize) = .empty;
        if (structure.is_class) for (p.structures, 0..) |candidate, index| {
            if (candidate.is_class and subtype(p, index, id)) try alternatives.append(a, index);
        };
        result[id] = try alternatives.toOwnedSlice(a);
    }
    return result;
}

pub fn boxed(e: anytype, value: M.Value, declared: usize) !M.Scalar {
    if (e.class_tags.len == 0) e.class_tags = try program(e.storage, e.program);
    var tags: std.ArrayList(usize) = .empty;
    if (value.nodes.len == 0) try tags.appendSlice(e.a, e.class_tags[declared]);
    for (value.nodes) |id| {
        const node = e.nodes.items[id];
        if (node != .object) return .unknown;
        const index = (node.object.type orelse return .unknown).structureIndex() orelse return .unknown;
        if (!e.program.structures[index].is_class) return .unknown;
        if (node.object.unknown_parent == null) try tags.append(e.a, index) else try tags.appendSlice(e.a, e.class_tags[index]);
    }
    std.mem.sort(usize, tags.items, {}, std.sort.asc(usize));
    var count: usize = 0;
    for (tags.items) |tag| if (count == 0 or tags.items[count - 1] != tag) {
        tags.items[count] = tag;
        count += 1;
    };
    if (count == 0) return .unknown;
    if (count == 1) return .{ .protocol = tags.items[0] };
    return .{ .choices = .{ .enumeration = null, .values = tags.items[0..count] } };
}
