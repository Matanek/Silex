const std = @import("std");
const Ir = @import("../../Ir.zig");
const M = @import("Model.zig");
const Finalization = @import("Finalization.zig");
const A = std.mem.Allocator;
const Value = M.Value;

pub fn step(e: anytype, frame_id: usize, block: usize, index: usize, op: Ir.Instruction, state: *M.State) A.Error!void {
    try transfer(e, frame_id, block, index, op, state);
    if (M.resultId(op)) |id| {
        const f = e.program.functions[e.frames.items[frame_id].function];
        var value = state.get(id);
        if (value.scalar == .bottom and M.scalarType(e.program, f.value_types[id])) {
            value.scalar = .unknown;
            try state.set(e.a, id, value);
        }
    }
}
fn transfer(e: anytype, frame_id: usize, block: usize, index: usize, op: Ir.Instruction, state: *M.State) A.Error!void {
    const frame = e.frames.items[frame_id];
    const f = e.program.functions[frame.function];
    const site = (block << 32) | index;
    const result = M.resultId(op);
    if (result) |id| try state.set(e.a, id, .{});
    switch (op) {
        .constant_bool => |v| try state.set(e.a, v.result, .{ .scalar = .{ .boolean = v.value } }),
        .enum_test => |v| {
            const scalar = state.get(v.operand).scalar;
            if (scalar == .variant) try state.set(e.a, v.result, .{ .scalar = .{ .boolean = scalar.variant.enumeration == v.enumeration and scalar.variant.variant == v.variant } });
        },
        .binary => |v| {
            const left = state.get(v.left).scalar;
            const right = state.get(v.right).scalar;
            if ((v.operator == .equal or v.operator == .not_equal) and (left == .boolean or left == .variant) and (right == .boolean or right == .variant)) {
                const equal = std.meta.eql(left, right);
                try state.set(e.a, v.result, .{ .scalar = .{ .boolean = if (v.operator == .equal) equal else !equal } });
            }
        },
        .class_retain => |v| try Finalization.retain(e, state.get(v.operand), v.ownership, &state.memory),
        .class_drop => |v| try Finalization.drop(e, frame_id, site, v, state.get(v.operand), &state.memory),
        .copy, .class_cast => |v| try state.set(e.a, v.result, state.get(v.operand)),
        .deep_copy => |v| {
            var copied: std.AutoHashMapUnmanaged(usize, usize) = .empty;
            try state.set(e.a, v.result, try copyGraph(e, .{ .frame = frame_id, .category = .copy, .value = v.result }, .{ .frame = frame_id, .category = .copy_summary, .value = v.result }, state.get(v.operand), &state.memory, &copied, frame.recursive or frame.repeated or inLoop(f, block), .root));
        },
        inline .optional_some, .optional_unwrap, .protocol_init, .protocol_extract => |v| try state.set(e.a, v.result, state.get(v.operand)),
        .local_address => |v| try state.set(e.a, v.result, try e.address(.{ .object = frame.locals, .field = v.local })),
        .local_store => |v| try e.write(&state.memory, .{ .object = frame.locals, .field = v.local }, state.get(v.operand), true),
        .local_load => |v| try state.set(e.a, v.result, state.memory.get(.{ .object = frame.locals, .field = v.local }) orelse .{}),
        .reference_load => |v| try state.set(e.a, v.result, try e.dereference(&state.memory, state.get(v.reference), f.value_types[v.result])),
        .reference_store => |v| try e.store(&state.memory, state.get(v.reference), state.get(v.operand)),
        .reference_optional => |v| try state.set(e.a, v.result, state.get(v.reference)),
        .reference_field => |v| {
            const base = try e.dereference(&state.memory, state.get(v.reference), .structure(v.structure));
            var value: Value = .{};
            for (base.nodes) |node| value = try Value.join(value, try e.address(.{ .object = node, .field = v.field }), e.a);
            try state.set(e.a, v.result, value);
        },
        .global_load => |v| try state.set(e.a, v.result, try e.unknown(&state.memory, .{ .object = e.globals, .field = v.global }, f.value_types[v.result])),
        .global_store => |v| try e.write(&state.memory, .{ .object = e.globals, .field = v.global }, state.get(v.operand), true),
        .structure_init => |v| {
            if (M.capable(e.capable, f.value_types[v.result])) {
                const object = try e.object(frame_id, .object, v.result, f.value_types[v.result], frame.recursive or frame.repeated or inLoop(f, block));
                try Finalization.initialize(e, &state.memory, object);
                for (v.fields, 0..) |field, n| try e.write(&state.memory, .{ .object = object, .field = n }, state.get(field), true);
                try state.set(e.a, v.result, try Value.one(e.a, object));
            }
        },
        .enum_init => |v| {
            if (M.capable(e.capable, f.value_types[v.result])) {
                const object = try e.object(frame_id, .object, v.result, f.value_types[v.result], frame.recursive or frame.repeated or inLoop(f, block));
                for (v.values, 0..) |field, n| try e.write(&state.memory, .{ .object = object, .field = n }, state.get(field), true);
                try state.set(e.a, v.result, try Value.one(e.a, object));
            }
            if (v.values.len == 0) {
                var value = state.get(v.result);
                value.scalar = .{ .variant = .{ .enumeration = v.enumeration, .variant = v.variant } };
                try state.set(e.a, v.result, value);
            }
        },
        .enum_payload => |v| try state.set(e.a, v.result, try e.field(&state.memory, state.get(v.operand), v.index, f.value_types[v.result])),
        .field_load => |v| try state.set(e.a, v.result, try e.field(&state.memory, state.get(v.base), v.field, f.value_types[v.result])),
        .field_store => |v| {
            var base = state.get(v.base);
            const type_index = f.value_types[v.base].structureIndex();
            if (type_index != null and !e.program.structures[type_index.?].is_class) base = try shallow(e, frame_id, v.result, base, &state.memory, frame.recursive or frame.repeated or inLoop(f, block));
            for (base.nodes) |object| try e.write(&state.memory, .{ .object = object, .field = v.field }, state.get(v.replacement), base.nodes.len == 1);
            try state.set(e.a, v.result, base);
        },
        .list_init => |v| {
            if (M.capable(e.capable, f.value_types[v.result])) {
                const object = try e.object(frame_id, .object, v.result, f.value_types[v.result], frame.recursive or frame.repeated or inLoop(f, block));
                for (v.values, 0..) |element, n| try e.write(&state.memory, .{ .object = object, .field = n }, state.get(element), true);
                try state.set(e.a, v.result, try Value.one(e.a, object));
            }
        },
        .collection_load => |v| {
            const key = integer(f, v.index) orelse M.wildcard;
            try state.set(e.a, v.result, if (key == M.wildcard) try e.elements(state.memory, state.get(v.collection)) else try e.field(&state.memory, state.get(v.collection), key, f.value_types[v.result]));
        },
        .collection_reference => |v| {
            const key = integer(f, v.index) orelse M.wildcard;
            var value: Value = .{};
            for (state.get(v.collection).nodes) |object| value = try Value.join(value, try e.address(.{ .object = object, .field = key }), e.a);
            try state.set(e.a, v.result, value);
        },
        .collection_replace => |v| {
            const base = try shallow(e, frame_id, v.result, state.get(v.collection), &state.memory, frame.recursive or frame.repeated or inLoop(f, block));
            const key = integer(f, v.index) orelse M.wildcard;
            for (base.nodes) |object| try e.write(&state.memory, .{ .object = object, .field = key }, state.get(v.replacement), key != M.wildcard);
            try state.set(e.a, v.result, base);
        },
        .collection_view, .collection_slice => |v| {
            if (M.capable(e.capable, f.value_types[v.result])) {
                const base = try e.object(frame_id, .object, v.result, f.value_types[v.result], frame.recursive or frame.repeated or inLoop(f, block));
                const start = integer(f, v.start);
                const end = integer(f, v.end);
                var fields: std.ArrayList(struct { key: usize, value: Value }) = .empty;
                var it = state.memory.iterator();
                while (it.next()) |entry| {
                    if (std.mem.indexOfScalar(usize, state.get(v.collection).nodes, entry.key_ptr.object) == null) continue;
                    const key = entry.key_ptr.field;
                    if (key != M.wildcard and start != null and end != null) {
                        if (key < start.? or key >= end.?) continue;
                        try fields.append(e.a, .{ .key = key - start.?, .value = entry.value_ptr.* });
                    } else try fields.append(e.a, .{ .key = M.wildcard, .value = entry.value_ptr.* });
                }
                for (fields.items) |field| try e.write(&state.memory, .{ .object = base, .field = field.key }, field.value, field.key != M.wildcard);
                try state.set(e.a, v.result, try Value.one(e.a, base));
            }
        },
        .list_edit => |v| {
            const old = state.get(v.collection);
            if (v.removed) |removed| try state.set(e.a, removed, try e.elements(state.memory, old));
            if (!M.capable(e.capable, f.value_types[v.result])) return;
            const object = try e.object(frame_id, .object, v.result, f.value_types[v.result], frame.recursive or frame.repeated or inLoop(f, block));
            var elements: Value = .{};
            if (v.kind != .clear) {
                elements = try e.elements(state.memory, old);
                if (v.argument) |arg| elements = try Value.join(elements, state.get(arg), e.a);
            }
            try e.write(&state.memory, .{ .object = object, .field = M.wildcard }, elements, true);
            try state.set(e.a, v.result, try Value.one(e.a, object));
        },
        .function_reference => |v| {
            var loans: std.ArrayList(M.Loan) = .empty;
            for (v.captures) |capture| {
                if (f.value_types[capture] != .address) continue;
                var found = false;
                for (f.borrow_origins) |origin| if (origin.reference == capture) {
                    try loans.append(e.a, .{ .frame = frame_id, .lifetime = origin.lifetime });
                    found = true;
                };
                if (!found) try loans.append(e.a, .{ .frame = frame_id, .lifetime = M.wildcard });
            }
            const node = try e.node(.{ .frame = frame_id, .category = .callable, .value = v.result }, .{ .callable = .{ .function = v.function, .loans = try loans.toOwnedSlice(e.a), .many = frame.recursive or frame.repeated or inLoop(f, block) } });
            for (v.captures, 0..) |capture, n| try e.write(&state.memory, .{ .object = node, .field = n }, state.get(capture), true);
            try state.set(e.a, v.result, try Value.one(e.a, node));
        },
        .call => |v| {
            const output = try e.invoke(frame_id, site, v.function, try arguments(e.a, state, v.arguments), &state.memory);
            if (v.result) |id| try state.set(e.a, id, output);
        },
        .indirect_call => |v| {
            const output = try e.indirect(frame_id, site, state.get(v.callee), try arguments(e.a, state, v.arguments), if (v.result) |result_id| f.value_types[result_id] else .void, &state.memory);
            if (v.result) |id| try state.set(e.a, id, output);
        },
        .dynamic_call => |v| {
            const args = try arguments(e.a, state, v.arguments);
            var output: Value = .{};
            var memory: M.Memory = .empty;
            var branch = try M.cloneMemory(e.a, state.memory);
            output = try e.invoke(frame_id, site, v.function, args, &branch);
            _ = try M.joinMemory(e.a, &memory, branch);
            for (v.implementations) |implementation| {
                branch = try M.cloneMemory(e.a, state.memory);
                output = try Value.join(output, try e.invoke(frame_id, site, implementation.function, args, &branch), e.a);
                _ = try M.joinMemory(e.a, &memory, branch);
            }
            state.memory = memory;
            if (v.result) |id| try state.set(e.a, id, output);
        },
        // These preserve identity in Silex pointer projections. Native scalar
        // arithmetic and foreign effects are not executable in this analysis.
        .convert => |v| try state.set(e.a, v.result, state.get(v.operand)),
        .unary => |v| if (v.operator == .reference_address) {
            try state.set(e.a, v.result, state.get(v.operand));
        },
        else => {},
    }
}
fn arguments(a: A, state: *M.State, ids: []const usize) ![]Value {
    const values = try a.alloc(Value, ids.len);
    for (ids, values) |id, *value| value.* = state.get(id);
    return values;
}
fn shallow(e: anytype, frame: usize, result: usize, value: Value, memory: *M.Memory, many: bool) A.Error!Value {
    if (value.nodes.len == 0) return .{};
    const object = try e.object(frame, .object, result, null, many);
    var copied: std.ArrayList(struct { key: usize, value: Value }) = .empty;
    var it = memory.iterator();
    while (it.next()) |entry| if (std.mem.indexOfScalar(usize, value.nodes, entry.key_ptr.object) != null) {
        try copied.append(e.a, .{ .key = entry.key_ptr.field, .value = entry.value_ptr.* });
    };
    for (copied.items) |field| try e.write(memory, .{ .object = object, .field = field.key }, field.value, value.nodes.len == 1);
    return Value.one(e.a, object);
}
fn copyGraph(e: anytype, context: M.Site, allocation: M.Site, value: Value, memory: *M.Memory, copied: *std.AutoHashMapUnmanaged(usize, usize), repeated: bool, ownership: Ir.Ownership) A.Error!Value {
    var result: Value = .{ .scalar = value.scalar };
    for (value.nodes) |old| {
        if (e.nodes.items[old] == .address) {
            result = try Value.join(result, try Value.one(e.a, old), e.a);
            continue;
        }
        var node = e.nodes.items[old];
        const is_class = if (node == .object and node.object.type != null) c: {
            const index = node.object.type.?.structureIndex() orelse break :c false;
            break :c e.program.structures[index].is_class;
        } else false;
        // Preserve shared class identity and terminate recursive summary graphs.
        // Ordinary value fields receive separate copies at each destination.
        const mapped = is_class or e.many(old) or node == .callable;
        if (mapped) if (copied.get(old)) |id| {
            const alias = try Value.one(e.a, id);
            try Finalization.retain(e, alias, ownership, memory);
            result = try Value.join(result, alias, e.a);
            continue;
        };
        const summary = repeated or e.many(old) or value.nodes.len != 1;
        switch (node) {
            .object => |*o| {
                o.many = o.many or summary;
                o.external = false;
            },
            .callable => |*c| c.many = c.many or summary,
            else => {},
        }
        var site = if (summary) allocation else context;
        site.kind = if (node == .callable) .callable else .object;
        site.extra = if (!summary) old else switch (node) {
            .callable => |c| c.function,
            .object => |o| if (o.type) |t| @intFromEnum(t) else 0,
            else => unreachable,
        };
        const id = try e.node(site, node);
        if (mapped) try copied.put(e.a, old, id);
        try Finalization.initialize(e, memory, id);
        var fields: std.ArrayList(struct { key: usize, value: Value }) = .empty;
        var it = memory.fields(old);
        while (it.next()) |entry| {
            try fields.append(e.a, .{ .key = entry.key_ptr.field, .value = entry.value_ptr.* });
        }
        for (fields.items) |field| {
            const child = try copyGraph(e, .{ .frame = id, .category = .copy_field, .value = field.key }, allocation, field.value, memory, copied, summary or field.key == M.wildcard, if (is_class) .edge else ownership);
            try e.write(memory, .{ .object = id, .field = field.key }, child, true);
        }
        const cloned = try Value.one(e.a, id);
        if (is_class) try Finalization.retain(e, cloned, ownership, memory);
        result = try Value.join(result, cloned, e.a);
    }
    return result;
}

fn integer(f: Ir.Function, id: usize) ?usize {
    for (f.blocks) |b| for (b.instructions) |op| if (op == .constant_int and op.constant_int.result == id) return std.math.cast(usize, op.constant_int.bits);
    return null;
}
pub fn inLoop(f: Ir.Function, block: usize) bool {
    for (f.blocks, 0..) |b, n| switch (b.terminator) {
        .jump => |target| if (target <= block and block <= n) {
            return true;
        },
        .branch => |branch| if ((branch.then_block <= block and block <= n) or (branch.else_block <= block and block <= n)) {
            return true;
        },
        else => {},
    };
    return false;
}
