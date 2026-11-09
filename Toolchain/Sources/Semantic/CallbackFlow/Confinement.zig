const std = @import("std");
const Ir = @import("../../Ir.zig");
const A = std.mem.Allocator;
const Id = u32;
const Edge = struct { target: Id, next: ?Id };
const Function = struct { values: []Id, locals: []Id, returned: Id };

// A flow-insensitive, field-sensitive sufficient proof. Every nominal instance
// shares its type's fields; no strong update or destruction removes a flow.
// A negative answer is only lack of proof, never a source diagnostic.
pub const Graph = struct {
    a: A,
    p: Ir.Program,
    heads: std.ArrayList(?Id) = .empty,
    edges: std.ArrayList(Edge) = .empty,
    functions: []Function,
    nominal: []Id,
    fields: [][]Id,
    payloads: [][][]Id,
    globals: []Id,
    unknown_exit: Id,
    fn node(g: *Graph) !Id {
        const id: Id = @intCast(g.heads.items.len);
        try g.heads.append(g.a, null);
        return id;
    }
    fn edge(g: *Graph, from: Id, to: Id) !void {
        if (from == to) return;
        const id: Id = @intCast(g.edges.items.len);
        try g.edges.append(g.a, .{ .target = to, .next = g.heads.items[from] });
        g.heads.items[from] = id;
    }
    fn alias(g: *Graph, x: Id, y: Id) !void {
        try g.edge(x, y);
        try g.edge(y, x);
    }
    fn ids(g: *Graph, count: usize) ![]Id {
        const result = try g.a.alloc(Id, count);
        for (result) |*id| id.* = try g.node();
        return result;
    }
    fn typed(g: *Graph, id: Id, t: Ir.Type) !void {
        if (structure(t)) |index| {
            if (g.p.structures[index].collection) |c| {
                // Collection contents flow with their values, not with every
                // other instance of uint[] (which can hold opaque addresses).
                var element = c.element;
                for (0..g.p.structures.len) |_| {
                    const child = structure(element) orelse break;
                    if (g.p.structures[child].collection) |nested| {
                        element = nested.element;
                        continue;
                    }
                    try g.edge(g.nominal[child], id);
                    break;
                }
            } else try g.alias(g.nominal[index], id);
        }
    }
    fn reference(g: *Graph, from: Id, to: Id, t: Ir.Type) !void {
        try g.edge(from, to);
        if (t == .address or t.isInteger() or callable(t) or (structure(t) != null and g.p.structures[structure(t).?].collection != null)) try g.edge(to, from);
    }
    fn call(g: *Graph, caller: usize, target: usize, args: []const usize, offset: usize, result: ?usize) !void {
        const source = g.functions[caller];
        const dest = g.functions[target];
        const f = g.p.functions[target];
        std.debug.assert(offset + args.len <= dest.values.len);
        for (args, 0..) |arg, i| try g.reference(source.values[arg], dest.values[offset + i], f.value_types[offset + i]);
        if (result) |r| {
            try g.reference(dest.returned, source.values[r], g.p.functions[caller].value_types[r]);
        }
    }
    pub fn init(a: A, p: Ir.Program) !Graph {
        var g: Graph = .{ .a = a, .p = p, .functions = try a.alloc(Function, p.functions.len), .nominal = undefined, .fields = try a.alloc([]Id, p.structures.len), .payloads = try a.alloc([][]Id, p.enums.len), .globals = undefined, .unknown_exit = undefined };
        g.unknown_exit = try g.node();
        g.nominal = try g.ids(p.structures.len);
        g.globals = try g.ids(p.globals.len);
        for (p.structures, 0..) |s, i| g.fields[i] = try g.ids(s.fields.len);
        for (p.enums, 0..) |en, i| {
            g.payloads[i] = try a.alloc([]Id, en.variants.len);
            for (en.variants, 0..) |v, j| {
                g.payloads[i][j] = try g.ids(v.associated_types.len);
                for (v.associated_types, g.payloads[i][j]) |t, id| {
                    try g.typed(id, t);
                    try g.edge(id, g.nominal[en.type_index]);
                }
            }
        }
        for (p.structures, 0..) |s, i| {
            for (s.fields, g.fields[i]) |field, id| {
                try g.typed(id, field.type);
                try g.edge(id, g.nominal[i]);
            }
            if (s.base) |base| {
                try g.edge(g.nominal[i], g.nominal[base]);
                for (g.fields[base], 0..) |id, field| try g.alias(id, g.fields[i][field]);
            }
            for (s.conformances) |protocol| try g.edge(g.nominal[i], g.nominal[protocol]);
        }
        for (p.globals, g.globals) |global, id| try g.typed(id, global.type);
        for (p.functions, 0..) |f, i| {
            g.functions[i] = .{ .values = try g.ids(f.value_types.len), .locals = try g.ids(f.local_types.len), .returned = try g.node() };
            for (f.value_types, g.functions[i].values) |t, id| try g.typed(id, t);
            for (f.local_types, g.functions[i].locals) |t, id| try g.typed(id, t);
            try g.typed(g.functions[i].returned, f.return_type);
        }
        const refs = try a.alloc(std.ArrayList(usize), p.function_types.len);
        @memset(refs, .empty);
        for (p.functions) |f| for (f.blocks) |b| for (b.instructions) |op| if (op == .function_reference) {
            const v = op.function_reference;
            const signature = f.value_types[v.result].functionIndex().?;
            if (std.mem.indexOfScalar(usize, refs[signature].items, v.function) == null) try refs[signature].append(a, v.function);
        };
        const targets = try a.alloc(std.ArrayList(usize), p.function_types.len);
        @memset(targets, .empty);
        for (p.function_types, 0..) |signature, i| for (p.function_types, 0..) |other, j| {
            if (signature.return_type != other.return_type or !std.mem.eql(Ir.Type, signature.parameter_types, other.parameter_types)) continue;
            for (refs[j].items) |target| if (std.mem.indexOfScalar(usize, targets[i].items, target) == null) try targets[i].append(a, target);
        };
        for (p.functions, 0..) |f, i| {
            const v = g.functions[i].values;
            const l = g.functions[i].locals;
            if (f.blocks.len == 0) {
                for (v[0 .. f.capture_types.len + f.parameter_types.len]) |id| try g.edge(id, g.unknown_exit);
                try g.edge(g.functions[i].returned, g.unknown_exit);
            }
            for (f.blocks) |b| {
                for (b.instructions) |op| switch (op) {
                    inline .copy, .deep_copy, .class_cast, .optional_some, .optional_unwrap => |x| {
                        try g.alias(v[x.operand], v[x.result]);
                        if (callable(f.value_types[x.result]) != callable(f.value_types[x.operand])) try g.edge(v[x.result], g.unknown_exit);
                    },
                    .convert => |x| {
                        try g.edge(v[x.operand], v[x.result]);
                        if (x.source == .address or x.target == .address) try g.edge(v[x.result], v[x.operand]);
                        if ((callable(x.target) != callable(x.source)) or (structure(x.target) != null and structure(x.source) == null)) try g.edge(v[x.result], g.unknown_exit);
                    },
                    .protocol_init => |x| try g.edge(v[x.operand], v[x.result]),
                    // A conformer's own nominal fields carry every loan it
                    // can expose; extraction excludes the other conformers.
                    .protocol_extract => {},
                    .global_load => |x| try g.reference(g.globals[x.global], v[x.result], f.value_types[x.result]),
                    .global_store => |x| try g.reference(v[x.operand], g.globals[x.global], p.globals[x.global].type),
                    .local_address => |x| try g.alias(l[x.local], v[x.result]),
                    .local_store => |x| try g.reference(v[x.operand], l[x.local], f.local_types[x.local]),
                    .local_load => |x| try g.reference(l[x.local], v[x.result], f.value_types[x.result]),
                    .reference_optional => |x| try g.alias(v[x.reference], v[x.result]),
                    .reference_store => |x| try g.reference(v[x.operand], v[x.reference], f.value_types[x.operand]),
                    .reference_load => |x| try g.alias(v[x.reference], v[x.result]),
                    .reference_field => |x| {
                        const field = g.fields[x.structure][x.field];
                        try g.alias(field, v[x.result]);
                        try g.edge(v[x.result], v[x.reference]);
                    },
                    .structure_init => |x| for (x.fields, 0..) |arg, field| try g.reference(v[arg], g.fields[x.structure][field], p.structures[x.structure].fields[field].type),
                    .field_store => |x| {
                        const s = structure(f.value_types[x.base]).?;
                        try g.reference(v[x.replacement], g.fields[s][x.field], p.structures[s].fields[x.field].type);
                        try g.edge(v[x.base], v[x.result]);
                    },
                    .field_load => |x| {
                        const s = structure(f.value_types[x.base]).?;
                        try g.reference(g.fields[s][x.field], v[x.result], f.value_types[x.result]);
                    },
                    .enum_init => |x| for (x.values, 0..) |arg, n| try g.reference(v[arg], g.payloads[x.enumeration][x.variant][n], p.enums[x.enumeration].variants[x.variant].associated_types[n]),
                    .enum_payload => |x| {
                        const id = g.payloads[x.enumeration][x.variant][x.index];
                        try g.reference(id, v[x.result], f.value_types[x.result]);
                    },
                    .list_init => |x| for (x.values) |arg| try g.edge(v[arg], v[x.result]),
                    .collection_load => |x| try g.reference(v[x.collection], v[x.result], f.value_types[x.result]),
                    .collection_reference => |x| {
                        try g.alias(v[x.collection], v[x.result]);
                        if (x.reference) |ref| try g.edge(v[x.result], v[ref]);
                    },
                    .collection_replace => |x| {
                        try g.edge(v[x.collection], v[x.result]);
                        try g.edge(v[x.replacement], v[x.result]);
                    },
                    .list_edit => |x| {
                        try g.edge(v[x.collection], v[x.result]);
                        if (x.argument) |arg| try g.edge(v[arg], v[x.result]);
                        if (x.removed) |r| try g.reference(v[x.collection], v[r], f.value_types[r]);
                    },
                    inline .collection_view, .collection_slice => |x| {
                        try g.edge(v[x.collection], v[x.result]);
                        if (x.reference) |ref| try g.edge(v[x.result], v[ref]);
                    },
                    .function_reference => |x| {
                        for (x.captures, 0..) |arg, n| {
                            try g.edge(v[arg], v[x.result]);
                            try g.reference(v[arg], g.functions[x.function].values[n], p.functions[x.function].capture_types[n]);
                        }
                    },
                    .call => |x| try g.call(i, x.function, x.arguments, 0, x.result),
                    .dynamic_call => |x| {
                        try g.call(i, x.function, x.arguments, 0, x.result);
                        for (x.implementations) |impl| try g.call(i, impl.function, x.arguments, 0, x.result);
                    },
                    .indirect_call => |x| {
                        // An opaque creator's input can expose or return an
                        // alias. Follow that capability back through copies,
                        // fields and higher-order returns to the external input.
                        for (x.arguments) |arg| try g.edge(v[arg], v[x.callee]);
                        if (x.result) |r| try g.edge(v[r], v[x.callee]);
                        for (targets[f.value_types[x.callee].functionIndex().?].items) |target| try g.call(i, target, x.arguments, p.functions[target].capture_types.len, x.result);
                    },
                    .unary => |x| if (x.operator == .reference_address) {
                        try g.alias(v[x.operand], v[x.result]);
                    },
                    // Foreign code is not a Silex ownership transfer in the
                    // general solver. Explicit callable exports, raw stores
                    // and tainted opaque results keep that solver instead.
                    inline .boundary_call, .boundary_indirect_call => |x| {
                        for (x.arguments) |arg| if (callable(f.value_types[arg])) try g.edge(v[arg], g.unknown_exit);
                        if (x.result) |r| try g.edge(v[r], g.unknown_exit);
                    },
                    .address_store => |x| try g.edge(v[x.operand], g.unknown_exit),
                    .address_load => |x| try g.edge(v[x.result], g.unknown_exit),
                    .constant_int => |x| if (x.bits != 0 and (f.value_types[x.result] == .address or structure(f.value_types[x.result]) != null or callable(f.value_types[x.result]))) {
                        try g.edge(v[x.result], g.unknown_exit);
                    },
                    .storage_init, .constant_bool, .constant_float32, .constant_float64, .constant_str, .constant_bytes, .optional_null, .binary, .class_retain, .class_drop, .list_retain, .list_drop, .string_retain, .string_drop, .class_test, .protocol_test, .enum_test, .enum_raw, .collection_count, .string_address, .string_byte_count, .string_byte_at, .string_from_bytes, .string_count, .format_value, .string_concat, .print, .assert, .mutex_lock, .mutex_unlock => {},
                };
                if (b.terminator == .return_value) try g.reference(v[b.terminator.return_value], g.functions[i].returned, f.return_type);
            }
        }
        return g;
    }
    pub fn proven(g: Graph, a: A, root: usize) !bool {
        const f = g.p.functions[root];
        if (f.borrow_origins.len == 0) return false;
        for (f.borrow_origins) |origin| {
            var ended = false;
            for (f.borrow_ends) |end| ended = ended or std.mem.indexOfScalar(usize, end.lifetimes, origin.lifetime) != null;
            if (!ended) return false;
        }
        const seen = try a.alloc(bool, g.heads.items.len);
        @memset(seen, false);
        var work: std.ArrayList(Id) = .empty;
        for (f.blocks) |b| for (b.instructions) |op| if (op == .function_reference) {
            for (op.function_reference.captures) |arg| if (f.value_types[arg] == .address) {
                const id = g.functions[root].values[op.function_reference.result];
                if (!seen[id]) {
                    seen[id] = true;
                    try work.append(a, id);
                }
            };
        };
        var at: usize = 0;
        while (at < work.items.len) : (at += 1) {
            var edge_id = g.heads.items[work.items[at]];
            while (edge_id) |id| {
                const e = g.edges.items[id];
                if (!seen[e.target]) {
                    seen[e.target] = true;
                    try work.append(a, e.target);
                }
                edge_id = e.next;
            }
        }
        var safe = !seen[g.unknown_exit] and !seen[g.functions[root].returned];
        for (g.globals) |id| if (seen[id]) {
            safe = false;
        };
        for (g.functions[root].values[0 .. f.parameter_types.len + f.capture_types.len]) |id| if (seen[id]) {
            safe = false;
        };
        for (f.borrow_ends) |end| for (end.live) |binding| {
            const id = if (binding.local) |local| g.functions[root].locals[local] else g.functions[root].values[binding.value.?];
            if (seen[id]) safe = false;
        };
        return safe;
    }
};
fn structure(t: Ir.Type) ?usize {
    return @as(Ir.Type, @enumFromInt(@intFromEnum(t) & 0x00ffffff)).structureIndex();
}

fn callable(t: Ir.Type) bool {
    if (t.optionalChild()) |c| return callable(c);
    return t.functionIndex() != null;
}
