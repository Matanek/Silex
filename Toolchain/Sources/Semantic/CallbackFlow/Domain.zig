const std = @import("std");
const Ir = @import("../../Ir.zig");
const M = @import("Model.zig");
const A = std.mem.Allocator;

pub const Domain = struct { capable: M.Capabilities, relevant: []const bool, generators: []const bool };

pub fn forOrigin(a: A, p: Ir.Program, source: usize) !Domain {
    const capable = try M.emptyTypes(a, p);
    const origin = p.functions[source];
    for (origin.blocks) |b| for (b.instructions) |op| if (op == .function_reference) {
        for (op.function_reference.captures) |capture| if (origin.value_types[capture] == .address) {
            capable.functions[origin.value_types[op.function_reference.result].functionIndex().?] = true;
        };
    };
    var effects: []const bool = undefined;
    while (true) {
        M.expandTypes(capable, p);
        effects = try globalEffects(a, p, capable);
        var changed = false;
        for (p.functions) |f| for (f.blocks) |b| for (b.instructions) |op| switch (op) {
            .class_drop => |drop| for (drop.plans) |plan| {
                if (capable.structures[plan.structure]) continue;
                for (plan.functions) |finalizer| if (effects[finalizer.function]) {
                    capable.structures[plan.structure] = true;
                    changed = true;
                    break;
                };
            },
            .function_reference => |ref| {
                const signature = f.value_types[ref.result].functionIndex().?;
                if (capable.functions[signature]) continue;
                // A body that merely creates another local loan does not make
                // its public callable interface a carrier for this origin.
                var carries = effects[ref.function];
                for (ref.captures) |capture| {
                    carries = carries or M.capable(capable, f.value_types[capture]);
                    if (f.value_types[capture] != .address) continue;
                    var found = false;
                    for (f.borrow_origins) |loan| if (loan.reference == capture) {
                        found = true;
                        carries = carries or loan.type == .void or M.capable(capable, loan.type);
                    };
                    if (!found) carries = true;
                }
                if (carries) {
                    capable.functions[signature] = true;
                    changed = true;
                }
            },
            else => {},
        };
        if (!changed) break;
    }
    return .{ .capable = capable, .relevant = try relevantFunctions(a, p, capable), .generators = try generatingFunctions(a, p, capable, effects) };
}

// Effects on globals must keep concrete callable targets even for a zero-arg
// void notification. Direct, virtual, indirect and implicit finalizer calls
// close this relation; foreign effects remain outside this semantic model.
fn globalEffects(a: A, p: Ir.Program, capable: M.Capabilities) ![]const bool {
    const effects = try a.alloc(bool, p.functions.len);
    const signatures = try a.alloc(bool, p.function_types.len);
    @memset(effects, false);
    @memset(signatures, false);
    var changed = true;
    while (changed) {
        changed = false;
        for (p.functions, 0..) |f, id| {
            var effect = effects[id];
            for (f.blocks) |b| for (b.instructions) |op| switch (op) {
                .global_load => |v| effect = effect or M.capable(capable, f.value_types[v.result]),
                .global_store => |v| effect = effect or M.capable(capable, f.value_types[v.operand]),
                .call => |v| effect = effect or effects[v.function],
                .dynamic_call => |v| {
                    effect = effect or effects[v.function];
                    for (v.implementations) |impl| effect = effect or effects[impl.function];
                },
                .indirect_call => |v| if (f.value_types[v.callee].functionIndex()) |signature| {
                    effect = effect or signatures[signature];
                },
                .function_reference => |v| if (effects[v.function]) {
                    const signature = f.value_types[v.result].functionIndex().?;
                    if (!signatures[signature]) {
                        signatures[signature] = true;
                        changed = true;
                    }
                },
                .class_drop => |v| for (v.plans) |plan| {
                    for (plan.functions) |fin| effect = effect or effects[fin.function];
                },
                else => {},
            };
            if (effect and !effects[id]) {
                effects[id] = true;
                changed = true;
            }
        }
    }
    return effects;
}

fn relevantFunctions(a: A, p: Ir.Program, capable: M.Capabilities) ![]bool {
    const result = try a.alloc(bool, p.functions.len);
    @memset(result, false);
    for (p.functions, 0..) |f, i| {
        result[i] = f.return_type == .address;
        for (f.value_types) |t| if (M.capable(capable, t)) {
            result[i] = true;
            break;
        };
        for (f.blocks) |b| for (b.instructions) |op| if (op == .reference_store) {
            result[i] = result[i] or M.scalarType(p, f.value_types[op.reference_store.operand]);
        };
    }
    var changed = true;
    while (changed) {
        changed = false;
        for (p.functions, 0..) |f, i| {
            if (result[i]) continue;
            for (f.blocks) |b| for (b.instructions) |op| {
                var needed = false;
                switch (op) {
                    .call => |v| needed = result[v.function],
                    .function_reference => |v| needed = result[v.function],
                    .dynamic_call => |v| {
                        needed = result[v.function];
                        for (v.implementations) |impl| needed = needed or result[impl.function];
                    },
                    else => {},
                }
                if (needed) {
                    result[i] = true;
                    changed = true;
                }
            };
        }
    }
    return result;
}

fn generatingFunctions(a: A, p: Ir.Program, capable: M.Capabilities, effects: []const bool) ![]bool {
    const flags = try a.alloc(bool, p.functions.len);
    for (p.functions, 0..) |f, i| {
        flags[i] = effects[i] or f.return_type == .address or M.capable(capable, f.return_type);
        for (f.blocks) |b| for (b.instructions) |op| switch (op) {
            .function_reference => |v| {
                var lexical = false;
                for (v.captures) |capture| lexical = lexical or f.value_types[capture] == .address;
                // Local borrowed environments are checked at their own origin;
                // they cannot supply a surviving value without failing there.
                flags[i] = flags[i] or (!lexical and M.capable(capable, f.value_types[v.result]));
            },
            inline .structure_init, .enum_init, .list_init => |v| flags[i] = flags[i] or M.capable(capable, f.value_types[v.result]),
            .field_store => |v| flags[i] = flags[i] or M.capable(capable, f.value_types[v.replacement]),
            .reference_store => |v| flags[i] = flags[i] or M.capable(capable, f.value_types[v.operand]) or M.scalarType(p, f.value_types[v.operand]),
            .collection_replace => |v| flags[i] = flags[i] or M.capable(capable, f.value_types[v.replacement]),
            .list_edit => |v| if (v.argument) |argument| {
                flags[i] = flags[i] or M.capable(capable, f.value_types[argument]);
            },
            else => {},
        };
    }
    var changed = true;
    while (changed) {
        changed = false;
        for (p.functions, 0..) |f, i| {
            if (flags[i]) continue;
            var generate = false;
            for (f.blocks) |b| for (b.instructions) |op| switch (op) {
                .call => |v| generate = generate or flags[v.function],
                .dynamic_call => |v| {
                    generate = generate or flags[v.function];
                    for (v.implementations) |impl| generate = generate or flags[impl.function];
                },
                .class_drop => |v| for (v.plans) |plan| {
                    for (plan.functions) |fin| generate = generate or flags[fin.function];
                },
                else => {},
            };
            if (generate) {
                flags[i] = true;
                changed = true;
            }
        }
    }
    return flags;
}
