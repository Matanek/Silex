const std = @import("std");
const Ir = @import("../../Ir.zig");
const M = @import("Model.zig");
pub const Predicate = struct { operand: usize, enumeration: ?usize, tag: usize };
pub fn program(a: std.mem.Allocator, p: Ir.Program) ![]const []const ?Predicate {
    const result = try a.alloc([]const ?Predicate, p.functions.len);
    for (p.functions, result) |f, *out| out.* = try function(a, f);
    return result;
}
fn function(a: std.mem.Allocator, f: Ir.Function) ![]const ?Predicate {
    const map = try std.heap.page_allocator.alloc(?Predicate, f.value_types.len);
    defer std.heap.page_allocator.free(map);
    @memset(map, null);
    for (f.blocks) |block| for (block.instructions) |op| switch (op) {
        .protocol_test => |v| map[v.result] = .{ .operand = v.operand, .enumeration = null, .tag = v.structure },
        .enum_test => |v| map[v.result] = .{ .operand = v.operand, .enumeration = v.enumeration, .tag = v.variant },
        else => {},
    };
    const result = try a.alloc(?Predicate, f.blocks.len);
    for (f.blocks, result) |block, *out| out.* = switch (block.terminator) {
        .branch => |v| map[v.condition],
        else => null,
    };
    return result;
}
pub fn apply(e: anytype, frame: usize, block: usize, taken: bool, state: *M.State) !bool {
    if (e.predicates.len == 0) return true;
    const predicate = e.predicates[e.frames.items[frame].function][block] orelse return true;
    var value = state.get(predicate.operand);
    var one: [1]usize = undefined;
    const tags = value.scalar.tags(&one) orelse return true;
    if (tags.enumeration != predicate.enumeration) return true;
    var values: std.ArrayList(usize) = .empty;
    for (tags.values) |tag| if ((tag == predicate.tag) == taken) try values.append(e.a, tag);
    if (values.items.len == 0) return false;
    value.scalar = if (values.items.len == 1) (if (tags.enumeration) |enumeration| .{ .variant = .{ .enumeration = enumeration, .variant = values.items[0] } } else .{ .protocol = values.items[0] }) else .{ .choices = .{ .enumeration = tags.enumeration, .values = try values.toOwnedSlice(e.a) } };
    if (predicate.enumeration == null) {
        var nodes: std.ArrayList(usize) = .empty;
        for (value.nodes) |id| {
            const n = e.nodes.items[id];
            var keep = true;
            if (n == .object) if (n.object.type) |t| if (t.structureIndex()) |index| {
                const structure = e.program.structures[index];
                if (!structure.is_protocol) {
                    if (!structure.is_class or n.object.unknown_parent == null) keep = (index == predicate.tag) == taken else if (taken) keep = @import("ClassBounds.zig").subtype(e.program, predicate.tag, index) else if (index == predicate.tag and e.class_tags.len != 0 and e.class_tags[index].len == 1) keep = false;
                }
            };
            if (keep) try nodes.append(e.a, id);
        }
        value.nodes = try nodes.toOwnedSlice(e.a);
    } else {
        var nodes: std.ArrayList(usize) = .empty;
        for (value.nodes) |id| {
            const node = e.nodes.items[id];
            if (node == .object) if (node.object.enum_tag) |tag| {
                if (tag.enumeration == predicate.enumeration.? and ((tag.variant == predicate.tag) != taken)) continue;
            };
            try nodes.append(e.a, id);
        }
        value.nodes = try nodes.toOwnedSlice(e.a);
    }
    value.region = e.a.ptr;
    try state.set(e.a, predicate.operand, value);
    return true;
}
