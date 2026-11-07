const std = @import("std");
const Ir = @import("../../Ir.zig");
const Store = @import("Store.zig").Store;
pub const Allocator = std.mem.Allocator;
pub const Value = struct {
    nodes: []const usize = &.{},
    region: ?*anyopaque = null,
    pub fn one(a: Allocator, node: usize) !Value {
        return .{ .nodes = try a.dupe(usize, &.{node}), .region = a.ptr };
    }
    pub fn own(self: Value, a: Allocator) !Value {
        if (self.nodes.len == 0 or self.region == a.ptr) return self;
        return .{ .nodes = try a.dupe(usize, self.nodes), .region = a.ptr };
    }
    pub fn promote(self: Value, from: Allocator, to: Allocator) !Value {
        return if (self.region == from.ptr) self.own(to) else self;
    }
    pub fn eql(a: Value, b: Value) bool {
        return std.mem.eql(usize, a.nodes, b.nodes);
    }
    // Values are immutable: branch snapshots never share a mutable set buffer.
    pub fn join(a: Value, b: Value, allocator: Allocator) !Value {
        if (a.nodes.len == 0) return b;
        if (b.nodes.len == 0 or eql(a, b)) return a;
        // A join already contained in its target must not allocate on every
        // fixed-point visit (different slices can denote the same subset).
        var subset = true;
        var scan: usize = 0;
        for (b.nodes) |node| {
            while (scan < a.nodes.len and a.nodes[scan] < node) scan += 1;
            if (scan == a.nodes.len or a.nodes[scan] != node) {
                subset = false;
                break;
            }
        }
        if (subset) return a;
        const out = try allocator.alloc(usize, a.nodes.len + b.nodes.len);
        var count: usize = 0;
        var i: usize = 0;
        var j: usize = 0;
        while (i < a.nodes.len or j < b.nodes.len) {
            const next = if (j == b.nodes.len or (i < a.nodes.len and a.nodes[i] < b.nodes[j])) v: {
                const v = a.nodes[i];
                i += 1;
                break :v v;
            } else v: {
                const v = b.nodes[j];
                j += 1;
                break :v v;
            };
            if (count == 0 or out[count - 1] != next) {
                out[count] = next;
                count += 1;
            }
        }
        return .{ .nodes = out[0..count], .region = allocator.ptr };
    }
};
pub const Cell = struct { object: usize, field: usize };
/// Reference-count intervals follow the explicit portable ownership IR. An
/// increasing upper bound widens to infinity at joins; the lower bound remains
/// a proof that an owner is still present, never an estimate.
pub const Count = struct {
    low: usize = 0,
    high: usize = 0,
    pub fn add(self: Count) Count {
        return .{ .low = self.low +| 1, .high = self.high +| 1 };
    }
    pub fn sub(self: Count) Count {
        return .{ .low = self.low -| 1, .high = if (self.high == wildcard) wildcard else self.high -| 1 };
    }
    pub fn join(self: Count, other: Count) Count {
        return .{ .low = @min(self.low, other.low), .high = if (self.high == other.high) self.high else wildcard };
    }
};
pub const Lifetime = enum { live, finalized, maybe };
pub const Owner = struct {
    roots: Count = .{},
    edges: Count = .{},
    // Uncertain destruction cannot erase effects.
    lifetime: Lifetime = .live,
    pub fn join(self: Owner, other: Owner) Owner {
        return .{ .roots = self.roots.join(other.roots), .edges = self.edges.join(other.edges), .lifetime = if (self.lifetime == other.lifetime) self.lifetime else .maybe };
    }
};
pub const Memory = struct {
    cells: Store(Cell, Value) = .empty,
    owners: Store(usize, Owner) = .empty,
    pub const empty: Memory = .{};
    pub fn promote(self: Memory, from: Allocator, to: Allocator) !Memory {
        return .{ .cells = try self.cells.promote(from, to), .owners = try self.owners.promote(from, to) };
    }

    pub fn get(self: Memory, key: Cell) ?Value {
        return self.cells.get(key);
    }
    pub fn put(self: *Memory, a: Allocator, key: Cell, value: Value) !void {
        try self.cells.put(a, key, value);
    }
    pub fn iterator(self: *const Memory) Store(Cell, Value).Iterator {
        return self.cells.iterator();
    }
    pub const Fields = struct {
        object: usize,
        entries: Store(Cell, Value).Iterator,
        pub fn next(self: *Fields) ?Store(Cell, Value).Iterator.Entry {
            const entry = self.entries.next() orelse return null;
            return if (entry.key_ptr.object == self.object) entry else null;
        }
    };
    pub fn fields(self: Memory, object: usize) Fields {
        return .{ .object = object, .entries = self.cells.iteratorFrom(.{ .object = object, .field = 0 }) };
    }
};
pub fn cloneMemory(_: Allocator, source: Memory) !Memory {
    return source;
}
pub fn joinMemory(a: Allocator, target: *Memory, source: Memory) !bool {
    var changed = false;
    if (target.cells.root == null) {
        changed = source.cells.root != null;
        target.cells = source.cells;
    } else if (target.cells.root != source.cells.root) {
        var it = source.cells.changedSince(target.cells);
        while (it.next()) |item| {
            const before = target.get(item.key_ptr.*);
            const joined = if (before) |v| try Value.join(v, item.value_ptr.*, a) else item.value_ptr.*;
            if (before == null or !Value.eql(before.?, joined)) {
                try target.put(a, item.key_ptr.*, joined);
                changed = true;
            }
        }
    }
    if (target.owners.root == null) {
        changed = source.owners.root != null or changed;
        target.owners = source.owners;
    } else if (target.owners.root != source.owners.root) {
        var it = source.owners.changedSince(target.owners);
        while (it.next()) |item| {
            const before = target.owners.get(item.key_ptr.*);
            const joined = if (before) |v| v.join(item.value_ptr.*) else item.value_ptr.*;
            if (before == null or !std.meta.eql(before.?, joined)) {
                try target.owners.put(a, item.key_ptr.*, joined);
                changed = true;
            }
        }
    }
    return changed;
}
// Incoming recursive effects outlive the descendant invocation. Materialize
// only changed entries in the ancestor, never retain the descendant's roots.
pub fn joinMemoryOwned(a: Allocator, target: *Memory, source: Memory) !bool {
    var changed = false;
    var cells = source.cells.changedSince(target.cells);
    while (cells.next()) |entry| {
        const before = target.get(entry.key_ptr.*);
        const joined = try Value.join(before orelse .{}, entry.value_ptr.*, a);
        if (before == null or !Value.eql(before.?, joined)) {
            try target.put(a, entry.key_ptr.*, try joined.own(a));
            changed = true;
        }
    }
    var owners = source.owners.changedSince(target.owners);
    while (owners.next()) |entry| {
        const before = target.owners.get(entry.key_ptr.*);
        const joined = if (before) |v| v.join(entry.value_ptr.*) else entry.value_ptr.*;
        if (before == null or !std.meta.eql(before.?, joined)) {
            try target.owners.put(a, entry.key_ptr.*, joined);
            changed = true;
        }
    }
    return changed;
}
pub const Loan = struct { frame: usize, lifetime: usize };
pub const Node = union(enum) {
    object: struct { type: ?Ir.Type, many: bool, unknown_parent: ?usize = null, external: bool = false },
    address: Cell,
    callable: struct { function: usize, loans: []const Loan, many: bool },
};
pub const Category = enum { local, object, address, callable, unknown, copy, copy_field, copy_summary };
pub const Site = struct { frame: usize, category: Category, value: usize, extra: usize = 0, kind: enum { any, object, callable } = .any };
pub const Frame = struct {
    function: usize,
    parent: ?usize,
    site: usize,
    locals: usize,
    allocator: Allocator = undefined,
    active: bool = false,
    recursive: bool = false,
    repeated: bool = false,
    arguments: []Value = &.{},
    incoming: Memory = .empty,
    returned: Value = .{},
    output: Memory = .empty,
    changed: bool = false,
};
pub const State = struct {
    values: Store(usize, Value) = .empty,
    memory: Memory,
    pub fn get(self: State, id: usize) Value {
        return self.values.get(id) orelse .{};
    }
    pub fn set(self: *State, a: Allocator, id: usize, value: Value) !void {
        if (value.nodes.len == 0 and self.values.get(id) == null) return;
        try self.values.put(a, id, value);
    }
    pub fn clone(self: State, _: Allocator) !State {
        return self;
    }
    pub fn join(self: *State, a: Allocator, other: State) !bool {
        var changed = try joinMemory(a, &self.memory, other.memory);
        if (self.values.root == null) {
            changed = other.values.root != null or changed;
            self.values = other.values;
        } else if (self.values.root != other.values.root) {
            var it = other.values.changedSince(self.values);
            while (it.next()) |entry| {
                const before = self.get(entry.key_ptr.*);
                const joined = try Value.join(before, entry.value_ptr.*, a);
                if (!Value.eql(before, joined)) {
                    try self.set(a, entry.key_ptr.*, joined);
                    changed = true;
                }
            }
        }
        return changed;
    }
};
pub const wildcard = std.math.maxInt(usize);
pub fn resultId(op: Ir.Instruction) ?usize {
    return switch (op) {
        inline else => |payload| if (@typeInfo(@TypeOf(payload)) == .@"struct" and @hasField(@TypeOf(payload), "result")) payload.result else null,
    };
}
pub fn capable(flags: []const bool, t: Ir.Type) bool {
    if (t.optionalChild()) |child| return capable(flags, child);
    if (t.functionIndex() != null) return true;
    const index = t.structureIndex() orelse return false;
    return index < flags.len and flags[index];
}
pub fn capableTypes(a: Allocator, program: Ir.Program) ![]bool {
    const flags = try a.alloc(bool, program.structures.len);
    @memset(flags, false);
    expandTypes(flags, program);
    return flags;
}
pub fn expandTypes(flags: []bool, program: Ir.Program) void {
    var changed = true;
    while (changed) {
        changed = false;
        for (program.structures, 0..) |s, i| {
            var value = false;
            for (s.fields) |field| value = value or capable(flags, field.type);
            if (s.collection) |c| value = value or capable(flags, c.element);
            for (program.enums) |e| if (e.type_index == i) {
                for (e.variants) |v| for (v.associated_types) |t| {
                    value = value or capable(flags, t);
                };
            };
            for (s.conformances) |protocol| if (flags[i] and !flags[protocol]) {
                flags[protocol] = true;
                changed = true;
            };
            if (s.base) |base| if (flags[i] and !flags[base]) {
                flags[base] = true;
                changed = true;
            };
            if (value and !flags[i]) {
                flags[i] = true;
                changed = true;
            }
        }
    }
}
