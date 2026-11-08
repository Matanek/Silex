const std = @import("std");
const Ir = @import("../../Ir.zig");
const M = @import("Model.zig");
const Finalization = @import("Finalization.zig");
const A = std.mem.Allocator;
const Value = M.Value;

pub fn step(e: anytype, frame_id: usize, block: usize, index: usize, op: Ir.Instruction, state: *M.State) A.Error!void {
    try transfer(e, frame_id, block, index, op, state);
    if (!state.reachable) return;
    if (M.resultId(op)) |id| {
        const f = e.program.functions[e.frames.items[frame_id].function];
        var value = state.get(id);
        if (op != .storage_init and f.value_types[id] == .address and value.reference_domain == .bottom) {
            value.reference_domain = .unknown;
            try state.set(e.a, id, value);
        }
        if (op != .storage_init and f.value_types[id].optionalChild() != null and value.presence == .bottom) {
            value.presence = .unknown;
            try state.set(e.a, id, value);
        }
        if (op != .storage_init and value.scalar == .bottom and M.scalarType(e.program, f.value_types[id])) {
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
        .storage_init => {},
        .boundary_call, .boundary_indirect_call, .address_store => {
            // Foreign code and raw stores can mutate previously exposed cells.
            try e.invalidateMutableFacts(&state.memory);
            if (result) |id| try state.set(e.a, id, try e.unknownResult(frame_id, site, f.value_types[id], &state.memory));
        },
        .optional_null => |v| try state.set(e.a, v.result, .{ .presence = .absent }),
        .constant_int => |v| {
            if (v.bits == 0 and f.value_types[v.result].isInteger()) {
                try state.set(e.a, v.result, .{ .scalar = .{ .zero = f.value_types[v.result] } });
            } else if (v.bits != 0) try state.set(e.a, v.result, try e.unknownResult(frame_id, site, f.value_types[v.result], &state.memory));
        },
        .constant_float32 => |v| if (v.bits & 0x7fffffff == 0) {
            try state.set(e.a, v.result, .{ .scalar = .{ .zero = .float32 } });
        },
        .constant_float64 => |v| if (v.bits & 0x7fffffffffffffff == 0) {
            try state.set(e.a, v.result, .{ .scalar = .{ .zero = .float64 } });
        },
        .collection_count => |v| if (e.collectionLength(state.get(v.collection)) == 0) {
            try state.set(e.a, v.result, .{ .scalar = .{ .zero = .int } });
        },
        .constant_bool => |v| try state.set(e.a, v.result, .{ .scalar = .{ .boolean = v.value } }),
        .enum_test => |v| {
            const scalar = state.get(v.operand).scalar;
            if (scalar.matches(v.enumeration, v.variant)) |known| try state.set(e.a, v.result, .{ .scalar = .{ .boolean = known } });
        },
        .binary => |v| {
            const left = state.get(v.left);
            const right = state.get(v.right);
            if (left.scalar == .zero and right.scalar == .zero and left.scalar.zero == right.scalar.zero) {
                const scalar: M.Scalar = switch (v.operator) {
                    .less, .greater, .not_equal => .{ .boolean = false },
                    .less_equal, .greater_equal, .equal => .{ .boolean = true },
                    .add, .subtract, .multiply, .minimum, .maximum => .{ .zero = left.scalar.zero },
                    else => .unknown,
                };
                try state.set(e.a, v.result, .{ .scalar = scalar });
            }
            if (v.operator == .equal or v.operator == .not_equal) if (Value.controlEqual(e.program, left, right)) |known| {
                try state.set(e.a, v.result, .{ .scalar = .{ .boolean = if (v.operator == .equal) known else !known } });
            };
        },
        .class_retain => |v| try Finalization.retain(e, state.get(v.operand), v.ownership, &state.memory),
        .class_drop => |v| try Finalization.drop(e, frame_id, site, v, state.get(v.operand), &state.memory),
        .copy, .class_cast => |v| try state.set(e.a, v.result, state.get(v.operand)),
        .deep_copy => |v| {
            var copied: std.AutoHashMapUnmanaged(usize, usize) = .empty;
            try state.set(e.a, v.result, try copyGraph(e, .{ .frame = frame_id, .category = .copy, .value = v.result }, .{ .frame = frame_id, .category = .copy_summary, .value = v.result }, state.get(v.operand), &state.memory, &copied, frame.recursive or frame.repeated or e.inLoop(frame.function, block), .root));
        },
        .optional_some => |v| {
            var value = state.get(v.operand);
            value.presence = .present;
            try state.set(e.a, v.result, value);
        },
        .optional_unwrap => |v| {
            var value = state.get(v.operand);
            if (value.presence == .absent) {
                state.reachable = false;
                return;
            }
            value.presence = if (f.value_types[v.result].optionalChild() != null) .unknown else .bottom;
            try state.set(e.a, v.result, value);
        },
        .protocol_init => |v| {
            var value = state.get(v.operand);
            value.scalar = .unknown;
            if (!e.program.structures[v.structure].is_class) {
                value.scalar = .{ .protocol = v.structure };
            } else value.scalar = try @import("ClassBounds.zig").boxed(e, value, v.structure);

            try state.set(e.a, v.result, value);
        },
        .protocol_test => |v| {
            const scalar = state.get(v.operand).scalar;
            if (scalar.matches(null, v.structure)) |known| try state.set(e.a, v.result, .{ .scalar = .{ .boolean = known } });
        },
        .protocol_extract => |v| {
            var value = state.get(v.operand);
            value.scalar = .bottom;
            try state.set(e.a, v.result, value);
        },
        .local_address => |v| {
            var address_value = try e.address(.{ .object = frame.locals, .field = v.local });
            address_value.reference_domain = .root;
            try state.set(e.a, v.result, address_value);
        },
        .local_store => |v| {
            if (frame.unaliased_locals[v.local]) {
                try state.set(e.a, f.value_types.len + v.local, state.get(v.operand));
            } else {
                try e.write(&state.memory, .{ .object = frame.locals, .field = v.local }, state.get(v.operand), true);
            }
        },
        .local_load => |v| {
            const value = if (frame.unaliased_locals[v.local]) state.get(f.value_types.len + v.local) else state.memory.get(.{ .object = frame.locals, .field = v.local }) orelse Value{};
            try state.set(e.a, v.result, value);
        },
        .reference_load => |v| try state.set(e.a, v.result, try loadReference(e, frame_id, state, state.get(v.reference), f.value_types[v.result])),
        .reference_store => |v| try storeReference(e, frame_id, state, state.get(v.reference), state.get(v.operand)),
        .reference_optional => |v| try state.set(e.a, v.result, state.get(v.reference)),
        .reference_field => |v| {
            const base = try loadReference(e, frame_id, state, state.get(v.reference), .structure(v.structure));
            var value: Value = .{};
            for (base.nodes) |node| value = try Value.join(value, try e.address(.{ .object = node, .field = v.field }), e.a);
            value.reference_domain = if (e.program.structures[v.structure].is_class) .edge else state.get(v.reference).reference_domain;
            try state.set(e.a, v.result, value);
        },
        .global_load => |v| try state.set(e.a, v.result, try e.unknown(&state.memory, .{ .object = e.globals, .field = v.global }, f.value_types[v.result])),
        .global_store => |v| try e.write(&state.memory, .{ .object = e.globals, .field = v.global }, state.get(v.operand), true),
        .structure_init => |v| {
            if (M.capable(e.capable, f.value_types[v.result])) {
                const object = try e.object(frame_id, .object, v.result, f.value_types[v.result], frame.recursive or frame.repeated or e.inLoop(frame.function, block));
                try Finalization.initialize(e, &state.memory, object);
                for (v.fields, 0..) |field, n| try e.write(&state.memory, .{ .object = object, .field = n }, state.get(field), true);
                try state.set(e.a, v.result, try Value.one(e.a, object));
            }
        },
        .enum_init => |v| {
            if (M.capable(e.capable, f.value_types[v.result])) {
                const object = try e.node(.{ .frame = frame_id, .category = .object, .value = v.result }, .{ .object = .{
                    .type = f.value_types[v.result],
                    .many = frame.recursive or frame.repeated or e.inLoop(frame.function, block),
                    .enum_tag = if (e.options.payload_tags) .{ .enumeration = v.enumeration, .variant = v.variant } else null,
                } });
                for (v.values, 0..) |field, n| try e.write(&state.memory, .{ .object = object, .field = n }, state.get(field), true);
                try state.set(e.a, v.result, try Value.one(e.a, object));
            }
            if (e.options.payload_tags or v.values.len == 0) {
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
            if (type_index != null and !e.program.structures[type_index.?].is_class) base = try shallow(e, frame_id, v.result, base, &state.memory, frame.recursive or frame.repeated or e.inLoop(frame.function, block));
            for (base.nodes) |object| try e.write(&state.memory, .{ .object = object, .field = v.field }, state.get(v.replacement), base.nodes.len == 1);
            try state.set(e.a, v.result, base);
        },
        .list_init => |v| {
            if (M.capable(e.capable, f.value_types[v.result])) {
                const object = try e.objectWithLength(frame_id, .object, v.result, f.value_types[v.result], frame.recursive or frame.repeated or e.inLoop(frame.function, block), v.values.len);
                for (v.values, 0..) |element, n| try e.write(&state.memory, .{ .object = object, .field = n }, state.get(element), true);
                try state.set(e.a, v.result, try Value.one(e.a, object));
            }
        },
        .collection_load => |v| {
            const key = integer(f, v.index) orelse M.wildcard;
            try state.set(e.a, v.result, if (key == M.wildcard) try e.elements(&state.memory, state.get(v.collection)) else try e.field(&state.memory, state.get(v.collection), key, f.value_types[v.result]));
        },
        .collection_reference => |v| {
            const key = integer(f, v.index) orelse M.wildcard;
            var value: Value = .{};
            for (state.get(v.collection).nodes) |object| value = try Value.join(value, try e.address(.{ .object = object, .field = key }), e.a);
            value.reference_domain = if (v.ownership == .edge) .edge else .root;
            try state.set(e.a, v.result, value);
        },
        .collection_replace => |v| {
            const base = try shallow(e, frame_id, v.result, state.get(v.collection), &state.memory, frame.recursive or frame.repeated or e.inLoop(frame.function, block));
            const key = integer(f, v.index) orelse M.wildcard;
            for (base.nodes) |object| try e.write(&state.memory, .{ .object = object, .field = key }, state.get(v.replacement), key != M.wildcard);
            try state.set(e.a, v.result, base);
        },
        .collection_view, .collection_slice => |v| {
            if (M.capable(e.capable, f.value_types[v.result])) {
                const base = try e.object(frame_id, .object, v.result, f.value_types[v.result], frame.recursive or frame.repeated or e.inLoop(frame.function, block));
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
            if (M.capable(e.capable, f.value_types[v.result]) and try @import("CollectionEdits.zig").precise(e, frame_id, block, v, state, if (v.index) |position| integer(f, position) else null)) return;
            const old = state.get(v.collection);
            if (v.removed) |removed| try state.set(e.a, removed, try e.elements(&state.memory, old));
            if (!M.capable(e.capable, f.value_types[v.result])) return;
            const object = try e.object(frame_id, .object, v.result, f.value_types[v.result], frame.recursive or frame.repeated or e.inLoop(frame.function, block));
            var elements: Value = .{};
            if (v.kind != .clear) {
                elements = try e.elements(&state.memory, old);
                if (v.argument) |arg| elements = try Value.join(elements, if (v.kind == .append_sequence) try e.elements(&state.memory, state.get(arg)) else state.get(arg), e.a);
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
            const node = try e.node(.{ .frame = frame_id, .category = .callable, .value = v.result }, .{ .callable = .{ .function = v.function, .loans = try loans.toOwnedSlice(e.a), .many = frame.recursive or frame.repeated or e.inLoop(frame.function, block) } });
            for (v.captures, 0..) |capture, n| try e.write(&state.memory, .{ .object = node, .field = n }, state.get(capture), true);
            try state.set(e.a, v.result, try Value.one(e.a, node));
        },
        .call => |v| {
            const output = try e.invoke(frame_id, site, v.function, try arguments(e.a, state, v.arguments), &state.memory);
            if (output.no_return) {
                state.reachable = false;
                return;
            }
            if (v.result) |id| try state.set(e.a, id, output);
        },
        .indirect_call => |v| {
            const output = try e.indirect(frame_id, site, state.get(v.callee), try arguments(e.a, state, v.arguments), if (v.result) |result_id| f.value_types[result_id] else .void, &state.memory);
            if (output.no_return) {
                state.reachable = false;
                return;
            }
            if (v.result) |id| try state.set(e.a, id, output);
        },
        .dynamic_call => |v| {
            const args = try arguments(e.a, state, v.arguments);
            var output: Value = .{ .no_return = true };
            var memory: M.Memory = .empty;
            var branch = try M.cloneMemory(e.a, state.memory);
            output = try e.invoke(frame_id, site, v.function, args, &branch);
            if (!output.no_return) _ = try M.joinMemory(e.a, &memory, branch);
            for (v.implementations) |implementation| {
                branch = try M.cloneMemory(e.a, state.memory);
                const alternative = try e.invoke(frame_id, site, implementation.function, args, &branch);
                output = try Value.join(output, alternative, e.a);
                if (!alternative.no_return) _ = try M.joinMemory(e.a, &memory, branch);
            }
            state.memory = memory;
            if (output.no_return) {
                state.reachable = false;
                return;
            }
            if (v.result) |id| try state.set(e.a, id, output);
        },
        // These preserve identity in Silex pointer projections. Native scalar
        // arithmetic and foreign effects are not executable in this analysis.
        .convert => |v| {
            const target = f.value_types[v.result];
            const source = f.value_types[v.operand];
            const opaque_function = M.unknownValue(e.program, target).unknown_callable and !M.unknownValue(e.program, source).unknown_callable;
            if (state.get(v.operand).scalar == .zero and target.isNumeric()) {
                try state.set(e.a, v.result, .{ .scalar = .{ .zero = target } });
            } else if (opaque_function or (M.capable(e.capable, target) and !M.capable(e.capable, source))) try state.set(e.a, v.result, try e.unknownResult(frame_id, site, target, &state.memory)) else try state.set(e.a, v.result, state.get(v.operand));
        },
        .unary => |v| switch (v.operator) {
            .negate => if (state.get(v.operand).scalar == .zero) {
                try state.set(e.a, v.result, state.get(v.operand));
            },
            .reference_address => {
                var address_value = state.get(v.operand);
                address_value.reference_domain = .root;
                try state.set(e.a, v.result, address_value);
            },
            .reference_is_edge => switch (state.get(v.operand).reference_domain) {
                .root, .edge => |known| try state.set(e.a, v.result, .{ .scalar = .{ .boolean = known == .edge } }),
                else => {},
            },
        },
        else => if (result) |id| try state.set(e.a, id, try e.unknownResult(frame_id, site, f.value_types[id], &state.memory)),
    }
}
fn arguments(a: A, state: *M.State, ids: []const usize) ![]Value {
    const values = try a.alloc(Value, ids.len);
    for (ids, values) |id, *value| value.* = state.get(id);
    return values;
}
fn shallow(e: anytype, frame: usize, result: usize, value: Value, memory: *M.Memory, many: bool) A.Error!Value {
    if (value.nodes.len == 0) return .{};
    const object = try e.objectWithLength(frame, .object, result, null, many, e.collectionLength(value));
    var copied: std.ArrayList(struct { key: usize, value: Value }) = .empty;
    var it = memory.iterator();
    while (it.next()) |entry| if (std.mem.indexOfScalar(usize, value.nodes, entry.key_ptr.object) != null) {
        try copied.append(e.a, .{ .key = entry.key_ptr.field, .value = entry.value_ptr.* });
    };
    for (copied.items) |field| try e.write(memory, .{ .object = object, .field = field.key }, field.value, value.nodes.len == 1);
    return Value.one(e.a, object);
}
fn copyGraph(e: anytype, context: M.Site, allocation: M.Site, value: Value, memory: *M.Memory, copied: *std.AutoHashMapUnmanaged(usize, usize), repeated: bool, ownership: Ir.Ownership) A.Error!Value {
    var result: Value = .{ .reference_domain = value.reference_domain, .scalar = value.scalar, .unknown_callable = value.unknown_callable, .region = value.region, .presence = value.presence, .no_return = value.no_return };
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

fn privateLocal(e: anytype, frame_id: usize, cell: M.Cell) ?usize {
    const frame = e.frames.items[frame_id];
    if (cell.object == frame.locals and cell.field < frame.unaliased_locals.len and frame.unaliased_locals[cell.field]) return cell.field;
    return null;
}
fn loadReference(e: anytype, frame_id: usize, state: *M.State, reference: Value, t: Ir.Type) !Value {
    var result: Value = .{};
    const f = e.program.functions[e.frames.items[frame_id].function];
    for (reference.nodes) |id| if (e.nodes.items[id] == .address) {
        const cell = e.nodes.items[id].address;
        const value = if (privateLocal(e, frame_id, cell)) |local| state.get(f.value_types.len + local) else try e.unknown(&state.memory, cell, t);
        result = try Value.join(result, value, e.a);
    };
    return result;
}
fn storeReference(e: anytype, frame_id: usize, state: *M.State, reference: Value, value: Value) !void {
    const f = e.program.functions[e.frames.items[frame_id].function];
    for (reference.nodes) |id| if (e.nodes.items[id] == .address) {
        const cell = e.nodes.items[id].address;
        const strong = reference.nodes.len == 1 and cell.field != M.wildcard;
        if (privateLocal(e, frame_id, cell)) |local| {
            const index = f.value_types.len + local;
            try state.set(e.a, index, if (strong) value else try Value.join(state.get(index), value, e.a));
        } else try e.write(&state.memory, cell, value, strong);
    };
}
