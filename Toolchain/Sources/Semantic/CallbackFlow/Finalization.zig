const std = @import("std");
const Ir = @import("../../Ir.zig");
const M = @import("Model.zig");
const A = std.mem.Allocator;

pub fn initialize(e: anytype, memory: *M.Memory, object: usize) A.Error!void {
    const node = e.nodes.items[object];
    if (node != .object) return;
    const t = node.object.type orelse return;
    const index = t.structureIndex() orelse return;
    if (!e.program.structures[index].is_class) return;
    const value: M.Owner = .{};
    try memory.owners.put(e.a, object, if (e.many(object)) (memory.owners.get(object) orelse value).join(value) else value);
}

pub fn initializeUnknown(e: anytype, memory: *M.Memory, object: usize, root: bool) A.Error!void {
    try memory.owners.put(e.a, object, .{ .roots = .{ .low = if (root) 1 else 0, .high = M.wildcard }, .edges = .{ .high = M.wildcard } });
}

/// Only a bound method owns a class capture. Lexical address environments do
/// not acquire ownership of the bindings they borrow.
fn receivers(e: anytype, value: M.Value, memory: M.Memory) A.Error!M.Value {
    var result: M.Value = .{};
    for (value.nodes) |id| switch (e.nodes.items[id]) {
        .object => |o| {
            const index = (o.type orelse continue).structureIndex() orelse continue;
            if (e.program.structures[index].is_class) result = try M.Value.join(result, try M.Value.one(e.a, id), e.a);
        },
        .callable => |c| {
            const captures = e.program.functions[c.function].capture_types;
            if (captures.len != 1) continue;
            const index = captures[0].structureIndex() orelse continue;
            if (e.program.structures[index].is_class) result = try M.Value.join(result, memory.get(.{ .object = id, .field = 0 }) orelse .{}, e.a);
        },
        else => {},
    };
    return result;
}
pub fn retain(e: anytype, value: M.Value, ownership: Ir.Ownership, memory: *M.Memory) A.Error!void {
    const classes = try receivers(e, value, memory.*);
    for (classes.nodes) |id| {
        const before = memory.owners.get(id) orelse M.Owner{};
        var after = before;
        switch (ownership) {
            .root => after.roots = after.roots.add(),
            .edge => after.edges = after.edges.add(),
        }
        try memory.owners.put(e.a, id, if (classes.nodes.len == 1 and !e.many(id)) after else before.join(after));
    }
}
pub fn drop(e: anytype, frame: usize, site: usize, op: Ir.Instruction.ClassDrop, value: M.Value, memory: *M.Memory) A.Error!void {
    const classes = try receivers(e, value, memory.*);
    for (classes.nodes) |id| {
        const before = memory.owners.get(id) orelse M.Owner{};
        if (before.lifetime == .finalized) continue;
        var after = before;
        switch (op.ownership) {
            .root => after.roots = after.roots.sub(),
            .edge => after.edges = after.edges.sub(),
        }
        const unique = classes.nodes.len == 1 and !e.many(id);
        if (!unique) after = before.join(after);
        try memory.owners.put(e.a, id, after);
        if (after.roots.low != 0) continue;
        if (after.edges.low != 0) {
            if (op.skip_cycle) continue;
            var visited: std.AutoHashMapUnmanaged(usize, void) = .empty;
            if (!try cycle(e, id, id, memory.*, &visited, true)) continue;
        }
        const definite = unique and after.lifetime == .live and after.roots.high == 0 and after.edges.high == 0;
        var merged: M.Memory = if (definite) .empty else try M.cloneMemory(e.a, memory.*);
        var any = false;
        const object = e.nodes.items[id].object;
        const concrete: ?usize = if (object.unknown_parent == null) (if (object.type) |t| t.structureIndex() else null) else null;
        for (op.plans) |plan| {
            if (concrete != null and concrete.? != plan.structure) continue;
            any = true;
            var branch = try M.cloneMemory(e.a, memory.*);
            var dead = after;
            dead.lifetime = .finalized;
            try branch.owners.put(e.a, id, dead);
            for (plan.functions) |finalizer| _ = try e.invoke(frame, site, finalizer.function, &.{try M.Value.one(e.a, id)}, &branch);
            _ = try M.joinMemory(e.a, &merged, branch);
        }
        if (any) memory.* = merged;
    }
}
// A rooted reference prevents collection. Without a root, an edge prevents
// collection only when the may-graph cannot contain a cycle through this object.
// Missing external fields are unknown, never evidence of acyclicity.
fn cycle(e: anytype, origin: usize, current: usize, memory: M.Memory, visited: *std.AutoHashMapUnmanaged(usize, void), first: bool) A.Error!bool {
    if (!first and current == origin) return true;
    if (visited.contains(current)) return false;
    try visited.put(e.a, current, {});
    switch (e.nodes.items[current]) {
        .address => return false,
        .object => |o| if (o.unknown_parent != null) {
            return true;
        },
        else => {},
    }
    var it = memory.fields(current);
    while (it.next()) |entry| {
        for (entry.value_ptr.nodes) |child| if (try cycle(e, origin, child, memory, visited, false)) return true;
    }
    return false;
}
