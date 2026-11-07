const std = @import("std");
const Ir = @import("../../Ir.zig");
const Operands = @import("../../Optimize/ValueOperands.zig");
const A = std.mem.Allocator;

// A newly formed lexical environment has no outside alias when its SSA value
// is only invoked, dropped, or passed to a proven non-retaining parameter.
// Storage, copies, returned values, native calls and unknown higher-order
// forwarding deliberately fall back to the full ownership interpretation.
// Drops are harmless for lexical address captures: they own no class receiver.
// Parameter proofs grow from direct uses; recursive forwarding is not assumed.

pub fn origins(a: A, p: Ir.Program) ![]bool {
    const counts = try a.alloc([]usize, p.functions.len);
    const permitted = try a.alloc([]usize, p.functions.len);
    const safe = try a.alloc([]bool, p.functions.len);
    for (p.functions, 0..) |f, i| {
        counts[i] = try a.alloc(usize, f.value_types.len);
        permitted[i] = try a.alloc(usize, f.value_types.len);
        safe[i] = try a.alloc(bool, f.capture_types.len + f.parameter_types.len);
        @memset(counts[i], 0);
        @memset(safe[i], false);
        for (f.blocks) |b| {
            for (b.instructions) |op| Operands.countUses(op, counts[i]);
            Operands.countTerminatorUses(b.terminator, counts[i]);
        }
    }
    var changed = true;
    while (changed) {
        changed = false;
        for (p.functions, 0..) |f, i| {
            if (f.blocks.len == 0) continue;
            approved(f, safe, permitted[i]);
            for (safe[i], 0..) |*flag, input| {
                if (flag.* or f.value_types[input].functionIndex() == null) continue;
                if (permitted[i][input] == counts[i][input]) {
                    flag.* = true;
                    changed = true;
                }
            }
        }
    }
    const result = try a.alloc(bool, p.functions.len);
    for (p.functions, 0..) |f, i| {
        approved(f, safe, permitted[i]);
        result[i] = true;
        for (f.blocks) |b| for (b.instructions) |op| if (op == .function_reference) {
            var borrowed = false;
            for (op.function_reference.captures) |capture| borrowed = borrowed or f.value_types[capture] == .address;
            if (borrowed) {
                const value = op.function_reference.result;
                if (permitted[i][value] != counts[i][value]) result[i] = false;
                // A value explicitly live across a capture's scope end still
                // needs the lifetime proof, even if its eventual use is a call.
                for (f.borrow_ends) |end| for (end.live) |binding| {
                    if (binding.value == value) result[i] = false;
                };
            }
        };
    }
    return result;
}
fn approved(f: Ir.Function, safe: []const []bool, allowed: []usize) void {
    @memset(allowed, 0);
    for (f.blocks) |b| for (b.instructions) |op| switch (op) {
        .indirect_call => |v| {
            allowed[v.callee] += 1;
        },
        .call => |v| for (v.arguments, 0..) |arg, input| {
            if (input < safe[v.function].len and safe[v.function][input]) allowed[arg] += 1;
        },
        inline .class_retain, .class_drop => |v| {
            allowed[v.operand] += 1;
        },
        else => {},
    };
}
