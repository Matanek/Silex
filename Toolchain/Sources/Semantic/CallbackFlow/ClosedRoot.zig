const std = @import("std");
const Ir = @import("../../Ir.zig");
const M = @import("Model.zig");
const A = std.mem.Allocator;

const Flags = packed struct {
    external: bool = false,
    loan: bool = false,
    fn add(self: *Flags, other: Flags) bool {
        const changed = (other.external and !self.external) or (other.loan and !self.loan);
        self.external = self.external or other.external;
        self.loan = self.loan or other.loan;
        return changed;
    }
};

pub fn eligible(p: Ir.Program, root: usize) bool {
    const f = p.functions[root];
    if (f.return_type != .void or f.parameter_types.len != 0 or f.capture_types.len != 0 or f.borrow_origins.len == 0) return false;
    for (f.borrow_ends) |end| if (end.live.len != 0) return false;
    for (f.borrow_origins) |origin| {
        var ended = false;
        for (f.borrow_ends) |end| ended = ended or std.mem.indexOfScalar(usize, end.lifetimes, origin.lifetime) != null;
        if (!ended) return false;
    }
    return true;
}

// Sufficient confinement proof, never a replacement for the general solver.
// With no surviving lexical binding, input, global carrier or external loan
// recipient, a void root cannot publish its environments. Native opaque
// addresses remain distinct from references to possible loan carriers.
pub fn proven(a: A, p: Ir.Program, capable: M.Capabilities, root: usize) !bool {
    if (!eligible(p, root)) return false;
    for (p.globals) |g| if (M.capable(capable, g.type)) return false;
    // Distinct reference modes cannot be identified from their lowered
    // addresses. An unequal carrier classification keeps the general solver.
    for (p.function_types, 0..) |first, i| {
        if (!M.addressInterface(first)) continue;
        for (p.function_types, 0..) |second, j| {
            if (capable.functions[i] != capable.functions[j] and M.sameInterface(first, second)) return false;
        }
    }

    const references = try a.alloc(std.ArrayList(usize), p.function_types.len);
    @memset(references, .empty);
    for (p.functions) |other| for (other.blocks) |b| for (b.instructions) |op| if (op == .function_reference) {
        const ref = op.function_reference;
        const signature = other.value_types[ref.result].functionIndex().?;
        if (std.mem.indexOfScalar(usize, references[signature].items, ref.function) == null) try references[signature].append(a, ref.function);
    };
    const reached = try a.alloc(bool, p.functions.len);
    @memset(reached, false);
    reached[root] = true;
    const values = try a.alloc([]Flags, p.functions.len);
    const locals = try a.alloc([]Flags, p.functions.len);
    const addressed = try a.alloc([]bool, p.functions.len);
    const returned = try a.alloc(Flags, p.functions.len);
    @memset(returned, .{});
    for (p.functions, 0..) |other, i| {
        values[i] = try a.alloc(Flags, other.value_types.len);
        locals[i] = try a.alloc(Flags, other.local_types.len);
        addressed[i] = try a.alloc(bool, other.local_types.len);
        @memset(values[i], .{});
        @memset(locals[i], .{});
        @memset(addressed[i], false);
        for (other.blocks) |b| for (b.instructions) |op| if (op == .local_address) {
            addressed[i][op.local_address.local] = true;
        };
    }
    var changed = true;
    while (changed) {
        changed = false;
        for (p.functions, 0..) |other, i| {
            if (!reached[i]) continue;
            if (other.blocks.len == 0) {
                if (M.capable(capable, other.return_type) or other.return_type == .address or callable(other.return_type)) return false;
                for (other.parameter_types) |t| if (M.capable(capable, t) or t == .address) return false;
                for (values[i][0 .. other.capture_types.len + other.parameter_types.len]) |input| if (input.loan) return false;
            }
            for (other.blocks) |b| {
                for (b.instructions) |op| {
                    var produced: Flags = .{};
                    switch (op) {
                        .constant_int => |v| {
                            if (v.bits != 0 and (M.capable(capable, other.value_types[v.result]) or callable(other.value_types[v.result]))) return false;
                            produced.external = other.value_types[v.result] == .address and v.bits != 0;
                        },
                        .storage_init, .constant_bool, .constant_float32, .constant_float64, .constant_str, .constant_bytes, .optional_null => {},
                        inline .copy, .deep_copy, .class_cast => |v| produced = values[i][v.operand],
                        inline .optional_some, .optional_unwrap => |v| produced = values[i][v.operand],
                        .protocol_init => |v| produced = values[i][v.operand],
                        .protocol_extract => |v| produced = values[i][v.operand],
                        .local_address => |v| produced.loan = M.capable(capable, other.local_types[v.local]) or locals[i][v.local].loan,
                        .local_store => |v| changed = locals[i][v.local].add(values[i][v.operand]) or changed,
                        .local_load => |v| {
                            produced = locals[i][v.local];
                            // An address slot can be overwritten through a
                            // forwarded reference, including by another call.
                            // Do not infer its pointee from direct SSA stores.
                            if (other.value_types[v.result] == .address and addressed[i][v.local]) produced.external = true;
                        },
                        .reference_optional => |v| produced = values[i][v.reference],
                        .reference_field => |v| {
                            if (capable.structures[v.structure] and values[i][v.reference].external) return false;
                            produced = .{ .external = values[i][v.reference].external, .loan = M.capable(capable, p.structures[v.structure].fields[v.field].type) };
                        },
                        .reference_load => |v| {
                            if (M.capable(capable, other.value_types[v.result]) and values[i][v.reference].external) return false;
                            if (other.value_types[v.result] == .address) produced = .{ .external = true, .loan = values[i][v.reference].loan };
                        },
                        .reference_store => |v| {
                            if (values[i][v.operand].loan or (M.capable(capable, other.value_types[v.operand]) and values[i][v.reference].external)) return false;
                        },
                        .collection_reference => |v| {
                            const collection = p.structures[other.value_types[v.collection].structureIndex().?].collection.?;
                            produced.loan = M.capable(capable, collection.element);
                        },
                        inline .global_load, .field_load, .collection_load, .enum_payload => |v| produced.external = other.value_types[v.result] == .address,
                        .global_store => |v| if (M.capable(capable, other.value_types[v.operand]) or values[i][v.operand].loan) return false,
                        .address_load => |v| {
                            if (M.capable(capable, other.value_types[v.result]) or callable(other.value_types[v.result]) or values[i][v.address].loan) return false;
                            produced = .{ .external = other.value_types[v.result] == .address, .loan = values[i][v.address].loan };
                        },
                        .address_store => |v| if (M.capable(capable, other.value_types[v.operand]) or values[i][v.operand].loan) return false,
                        .convert => |v| {
                            if (M.capable(capable, v.source) != M.capable(capable, v.target)) return false;
                            if (v.source != v.target and (callable(v.source) or callable(v.target))) return false;
                            if (values[i][v.operand].loan and v.target != .address) return false;
                            produced = values[i][v.operand];
                            if (v.target == .address and v.source != .address) produced.external = true;
                        },
                        .unary => |v| if (v.operator != .reference_is_edge) {
                            produced = values[i][v.operand];
                        },
                        .binary => |v| if (other.value_types[v.result] != .bool) {
                            produced = values[i][v.left];
                            _ = produced.add(values[i][v.right]);
                        },
                        .structure_init => |v| for (v.fields) |value| {
                            if (values[i][value].loan) return false;
                        },
                        .enum_init => |v| for (v.values) |value| {
                            if (values[i][value].loan) return false;
                        },
                        .list_init => |v| for (v.values) |value| {
                            if (values[i][value].loan) return false;
                        },
                        .field_store => |v| if (values[i][v.replacement].loan) return false,
                        .collection_replace => |v| if (values[i][v.replacement].loan) return false,
                        .list_edit => |v| if (v.argument) |arg| {
                            if (values[i][arg].loan) return false;
                        },
                        .function_reference => |v| {
                            if (!reached[v.function]) {
                                reached[v.function] = true;
                                changed = true;
                            }
                            for (v.captures, 0..) |capture, n| changed = values[v.function][n].add(values[i][capture]) or changed;
                        },
                        .call => |v| {
                            changed = connect(p, values, reached, i, v.function, v.arguments, 0) or changed;
                            produced = returned[v.function];
                        },
                        .dynamic_call => |v| {
                            changed = connect(p, values, reached, i, v.function, v.arguments, 0) or changed;
                            _ = produced.add(returned[v.function]);
                            for (v.implementations) |impl| {
                                changed = connect(p, values, reached, i, impl.function, v.arguments, 0) or changed;
                                _ = produced.add(returned[impl.function]);
                            }
                        },
                        .indirect_call => |v| {
                            if (!M.capable(capable, other.value_types[v.callee])) for (v.arguments) |arg| {
                                if (values[i][arg].loan) return false;
                            };
                            const signature = p.function_types[other.value_types[v.callee].functionIndex().?];
                            for (references, 0..) |targets, signature_id| {
                                if (!M.sameInterface(signature, p.function_types[signature_id])) continue;
                                for (targets.items) |target| {
                                    changed = connect(p, values, reached, i, target, v.arguments, p.functions[target].capture_types.len) or changed;
                                    _ = produced.add(returned[target]);
                                }
                            }
                        },
                        .class_drop => |v| for (v.plans) |plan| {
                            if (!capable.structures[plan.structure]) continue;
                            for (plan.functions) |fin| changed = connect(p, values, reached, i, fin.function, &.{v.operand}, 0) or changed;
                        },
                        .boundary_call => |v| {
                            for (v.arguments) |arg| if (M.capable(capable, other.value_types[arg]) or values[i][arg].loan) return false;
                            if (v.result) |result| {
                                if (M.capable(capable, other.value_types[result]) or callable(other.value_types[result])) return false;
                                produced.external = other.value_types[result] == .address;
                            }
                        },
                        .boundary_indirect_call => |v| {
                            // A native function pointer is not a Silex closure.
                            // Its callee, arguments and result must still be
                            // unable to transport this origin's loan.
                            if (values[i][v.callee].loan or M.capable(capable, other.value_types[v.callee])) return false;
                            for (v.arguments) |arg| if (M.capable(capable, other.value_types[arg]) or values[i][arg].loan) return false;
                            if (v.result) |result| {
                                if (M.capable(capable, other.value_types[result]) or callable(other.value_types[result])) return false;
                                produced.external = other.value_types[result] == .address;
                            }
                        },
                        .string_address => produced.external = true,
                        .format_value => |v| if (values[i][v.operand].loan or M.capable(capable, other.value_types[v.operand])) return false,
                        .string_concat => |v| if (values[i][v.left].loan or values[i][v.right].loan) return false,
                        .print => |v| if (values[i][v.value].loan or M.capable(capable, other.value_types[v.value])) return false,
                        .class_retain, .list_retain, .list_drop, .string_retain, .string_drop, .class_test, .protocol_test, .enum_test, .enum_raw, .collection_count, .collection_view, .collection_slice, .string_byte_count, .string_byte_at, .string_from_bytes, .string_count, .assert, .mutex_lock, .mutex_unlock => {},
                    }
                    if (M.resultId(op)) |result| changed = values[i][result].add(produced) or changed;
                }
                if (b.terminator == .return_value) changed = returned[i].add(values[i][b.terminator.return_value]) or changed;
            }
        }
    }
    return true;
}

fn connect(p: Ir.Program, values: [][]Flags, reached: []bool, caller: usize, target: usize, args: []const usize, offset: usize) bool {
    _ = p;
    var changed = !reached[target];
    reached[target] = true;
    for (args, 0..) |arg, i| changed = values[target][offset + i].add(values[caller][arg]) or changed;
    return changed;
}

fn callable(t: Ir.Type) bool {
    if (t.optionalChild()) |child| return callable(child);
    return t.functionIndex() != null;
}
