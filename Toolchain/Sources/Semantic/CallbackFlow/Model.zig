const std = @import("std");
const Ir = @import("../../Ir.zig");
const Store = @import("Store.zig").Store;
pub const Allocator = std.mem.Allocator;
pub const Scalar = union(enum) {
    bottom,
    unknown,
    boolean: bool,
    zero: Ir.Type,
    protocol: usize,
    variant: struct { enumeration: usize, variant: usize },
    choices: struct { enumeration: ?usize, values: []const usize },
    const Tags = struct { enumeration: ?usize, values: []const usize };
    pub fn tags(self: Scalar, one: *[1]usize) ?Tags {
        return switch (self) {
            .protocol => |v| t: {
                one[0] = v;
                break :t .{ .enumeration = null, .values = one };
            },
            .variant => |v| t: {
                one[0] = v.variant;
                break :t .{ .enumeration = v.enumeration, .values = one };
            },
            .choices => |v| .{ .enumeration = v.enumeration, .values = v.values },
            else => null,
        };
    }
    pub fn isProtocol(self: Scalar) bool {
        return self == .protocol or (self == .choices and self.choices.enumeration == null);
    }
    pub fn eql(a: Scalar, b: Scalar) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        if (a == .choices) return a.choices.enumeration == b.choices.enumeration and std.mem.eql(usize, a.choices.values, b.choices.values);
        return std.meta.eql(a, b);
    }
    pub fn join(a: Scalar, b: Scalar, allocator: Allocator) !Scalar {
        if (a == .bottom) return b;
        if (b == .bottom or eql(a, b)) return a;
        var x: [1]usize = undefined;
        var y: [1]usize = undefined;
        const first = a.tags(&x) orelse return .unknown;
        const second = b.tags(&y) orelse return .unknown;
        if (first.enumeration != second.enumeration) return .unknown;
        var values: std.ArrayList(usize) = .empty;
        var i: usize = 0;
        var j: usize = 0;
        while (i < first.values.len or j < second.values.len) {
            const next = if (j == second.values.len or (i < first.values.len and first.values[i] < second.values[j])) v: {
                const v = first.values[i];
                i += 1;
                break :v v;
            } else v: {
                const v = second.values[j];
                j += 1;
                break :v v;
            };
            if (values.items.len == 0 or values.items[values.items.len - 1] != next) try values.append(allocator, next);
        }
        return .{ .choices = .{ .enumeration = first.enumeration, .values = try values.toOwnedSlice(allocator) } };
    }
    pub fn equal(a: Scalar, b: Scalar) ?bool {
        if (a == .boolean and b == .boolean) return a.boolean == b.boolean;
        if (a == .zero and b == .zero and a.zero == b.zero) return true;
        var x: [1]usize = undefined;
        var y: [1]usize = undefined;
        const first = a.tags(&x) orelse return null;
        const second = b.tags(&y) orelse return null;
        if (first.enumeration == null or second.enumeration == null) return null;
        if (first.enumeration != second.enumeration) return false;
        var overlap = false;
        for (first.values) |v| overlap = overlap or std.mem.indexOfScalar(usize, second.values, v) != null;
        if (!overlap) return false;
        if (first.values.len == 1 and second.values.len == 1) return true;
        return null;
    }
    pub fn matches(self: Scalar, enumeration: ?usize, value: usize) ?bool {
        var one: [1]usize = undefined;
        const ts = self.tags(&one) orelse return null;
        if (ts.enumeration != enumeration) return false;
        if (std.mem.indexOfScalar(usize, ts.values, value) == null) return false;
        return if (ts.values.len == 1) true else null;
    }
};
pub fn scalarType(program: Ir.Program, t: Ir.Type) bool {
    if (t.optionalChild()) |child| return scalarType(program, child);
    if (t == .bool or t.isNumeric()) return true;
    const index = t.structureIndex() orelse return false;
    if (protocolType(program, t)) return true;
    for (program.enums) |e| if (e.type_index == index) return true;
    return false;
}
pub fn protocolType(program: Ir.Program, t: Ir.Type) bool {
    if (t.optionalChild()) |child| return protocolType(program, child);
    const index = t.structureIndex() orelse return false;
    return program.structures[index].is_protocol;
}
pub const Presence = enum {
    bottom,
    absent,
    present,
    unknown,
    pub fn join(a: Presence, b: Presence) Presence {
        if (a == .bottom) return b;
        if (b == .bottom or a == b) return a;
        return .unknown;
    }
};
pub const ReferenceDomain = enum {
    bottom,
    root,
    edge,
    unknown,
    pub fn join(a: ReferenceDomain, b: ReferenceDomain) ReferenceDomain {
        if (a == .bottom) return b;
        if (b == .bottom or a == b) return a;
        return .unknown;
    }
};
pub const Value = struct {
    reference_domain: ReferenceDomain = .bottom,
    presence: Presence = .bottom,
    no_return: bool = false,
    nodes: []const usize = &.{},
    scalar: Scalar = .bottom,
    unknown_callable: bool = false,
    region: ?*anyopaque = null,
    pub fn one(a: Allocator, node: usize) !Value {
        return .{ .nodes = try a.dupe(usize, &.{node}), .region = a.ptr };
    }
    pub fn own(self: Value, a: Allocator) !Value {
        if (self.region == a.ptr or (self.nodes.len == 0 and self.scalar != .choices)) return self;
        var scalar = self.scalar;
        if (scalar == .choices) scalar.choices.values = try a.dupe(usize, scalar.choices.values);
        return .{ .nodes = try a.dupe(usize, self.nodes), .region = a.ptr, .scalar = scalar, .unknown_callable = self.unknown_callable, .no_return = self.no_return, .presence = self.presence, .reference_domain = self.reference_domain };
    }
    pub fn promote(self: Value, from: Allocator, to: Allocator) !Value {
        return if (self.region == from.ptr) self.own(to) else self;
    }
    pub fn eql(a: Value, b: Value) bool {
        return std.mem.eql(usize, a.nodes, b.nodes) and Scalar.eql(a.scalar, b.scalar) and a.unknown_callable == b.unknown_callable and a.no_return == b.no_return and a.presence == b.presence and a.reference_domain == b.reference_domain;
    }
    pub fn controlEqual(a: Value, b: Value) ?bool {
        if (a.presence != .bottom or b.presence != .bottom) {
            if (a.presence == .absent) return switch (b.presence) {
                .absent => true,
                .present => false,
                else => null,
            };
            if (b.presence == .absent) return switch (a.presence) {
                .present => false,
                else => null,
            };
            if (a.presence != .present or b.presence != .present) return null;
        }
        return Scalar.equal(a.scalar, b.scalar);
    }
    // Values are immutable: branch snapshots never share a mutable set buffer.
    pub fn join(a: Value, b: Value, allocator: Allocator) !Value {
        if (a.no_return) return b;
        if (b.no_return) return a;
        var result = try joinNodes(a, b, allocator);
        result.scalar = try Scalar.join(a.scalar, b.scalar, allocator);
        if (result.scalar == .choices) {
            result.nodes = try allocator.dupe(usize, result.nodes);
            result.scalar.choices.values = try allocator.dupe(usize, result.scalar.choices.values);
            result.region = allocator.ptr;
        }
        result.unknown_callable = a.unknown_callable or b.unknown_callable;
        result.presence = Presence.join(a.presence, b.presence);
        result.reference_domain = ReferenceDomain.join(a.reference_domain, b.reference_domain);
        return result;
    }
    fn joinNodes(a: Value, b: Value, allocator: Allocator) !Value {
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
pub fn unknownValue(program: Ir.Program, t: Ir.Type) Value {
    if (t.optionalChild()) |child| {
        var value = unknownValue(program, child);
        value.presence = .unknown;
        return value;
    }
    return .{ .reference_domain = if (t == .address) .unknown else .bottom, .scalar = if (scalarType(program, t)) .unknown else .bottom, .unknown_callable = t.functionIndex() != null };
}
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
    object: struct { type: ?Ir.Type, many: bool, unknown_parent: ?usize = null, external: bool = false, length: ?usize = null },
    address: Cell,
    callable: struct { function: usize, loans: []const Loan, many: bool },
};
pub const Category = enum { local, object, address, callable, unknown, copy, copy_field, copy_summary, call_result };
pub const Site = struct { frame: usize, category: Category, value: usize, extra: usize = 0, kind: enum { any, object, callable } = .any };
pub const Frame = struct {
    context_boundary: usize = 0,
    function: usize,
    parent: ?usize,
    site: usize,
    locals: usize,
    unaliased_locals: []const bool = &.{},
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
    reachable: bool = true,
    values: Store(usize, Value) = .empty,
    memory: Memory,
    pub fn get(self: State, id: usize) Value {
        return self.values.get(id) orelse .{};
    }
    pub fn set(self: *State, a: Allocator, id: usize, value: Value) !void {
        if (value.nodes.len == 0 and value.scalar == .bottom and !value.unknown_callable and value.presence == .bottom and self.values.get(id) == null) return;
        try self.values.put(a, id, value);
    }
    pub fn clone(self: State, _: Allocator) !State {
        return self;
    }
    pub fn join(self: *State, a: Allocator, other: State) !bool {
        if (!other.reachable) return false;
        if (!self.reachable) {
            self.* = other;
            return true;
        }
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
pub const Capabilities = struct {
    structures: []bool,
    functions: []bool,
};
pub fn capable(flags: Capabilities, t: Ir.Type) bool {
    if (t.optionalChild()) |child| return capable(flags, child);
    if (t.functionIndex()) |index| return index < flags.functions.len and flags.functions[index];
    const index = t.structureIndex() orelse return false;
    return index < flags.structures.len and flags.structures[index];
}
pub fn emptyTypes(a: Allocator, program: Ir.Program) !Capabilities {
    const structures = try a.alloc(bool, program.structures.len);
    const functions = try a.alloc(bool, program.function_types.len);
    @memset(structures, false);
    @memset(functions, false);
    return .{ .structures = structures, .functions = functions };
}
pub fn capableTypes(a: Allocator, program: Ir.Program) !Capabilities {
    const flags = try emptyTypes(a, program);
    @memset(flags.functions, true);
    expandTypes(flags, program);
    return flags;
}
// Close carriers and callable interfaces together. An interface that can accept
// or return a relevant value also needs its concrete targets preserved. Function
// indices are interned before borrow modes and nominal types lower to addresses;
// comparing only the lowered ABI would merge unrelated interfaces again.
pub fn expandTypes(flags: Capabilities, program: Ir.Program) void {
    var changed = true;
    while (changed) {
        changed = false;
        for (program.function_types, 0..) |signature, i| {
            if (flags.functions[i]) continue;
            var value = capable(flags, if (signature.return_type == .address and signature.logical_return_type != .void) signature.logical_return_type else signature.return_type);
            for (program.function_types, 0..) |other, j| {
                if (flags.functions[j] and !addressInterface(signature) and !addressInterface(other) and sameInterface(signature, other)) value = true;
            }
            const logical = signature.logical_parameter_types;
            for (signature.parameter_types, 0..) |t, n| value = value or
                (if (n < logical.len) capable(flags, logical[n]) else t == .address or capable(flags, t));
            if (value) {
                flags.functions[i] = true;
                changed = true;
            }
        }
        for (program.structures, 0..) |s, i| {
            var value = false;
            for (s.fields) |field| value = value or capable(flags, field.type);
            if (s.collection) |c| value = value or capable(flags, c.element);
            for (program.enums) |e| if (e.type_index == i) {
                for (e.variants) |v| for (v.associated_types) |t| {
                    value = value or capable(flags, t);
                };
            };
            for (s.conformances) |protocol| if (flags.structures[i] and !flags.structures[protocol]) {
                flags.structures[protocol] = true;
                changed = true;
            };
            if (s.base) |base| if (flags.structures[i] and !flags.structures[base]) {
                flags.structures[base] = true;
                changed = true;
            };
            if (value and !flags.structures[i]) {
                flags.structures[i] = true;
                changed = true;
            }
        }
    }
}

// Only address-free interfaces can establish alias identity after lowering:
// @/& modes share an address representation and must keep their own indices.
pub fn addressInterface(signature: Ir.FunctionType) bool {
    if (addressType(signature.return_type)) return true;
    for (signature.parameter_types) |t| if (addressType(t)) return true;
    return false;
}
fn addressType(t: Ir.Type) bool {
    if (t.optionalChild()) |child| return addressType(child);
    return t == .address;
}
// A conservative relation for call reachability. It is deliberately weaker
// than source function-type equality when reference modes have been lowered.
pub fn sameInterface(first: Ir.FunctionType, second: Ir.FunctionType) bool {
    if (first.return_type != second.return_type or !std.mem.eql(Ir.Type, first.parameter_types, second.parameter_types)) return false;
    if (first.return_type == .address and first.logical_return_type != .void and second.logical_return_type != .void and first.logical_return_type != second.logical_return_type) return false;
    for (first.parameter_types, 0..) |_, i| {
        if (i < first.logical_parameter_types.len and i < second.logical_parameter_types.len and first.logical_parameter_types[i] != second.logical_parameter_types[i]) return false;
    }
    return true;
}
