const std = @import("std");
const Ir = @import("../../Ir.zig");
const Operands = @import("../../Optimize/ValueOperands.zig");
// A local address consumed only by loads/stores, ownership tests or a class
// field projection cannot expose the invocation's storage. A class projection
// crosses the indirection: its result refers to the heap object, not this slot.
// Captures, forwarding, address masking and unknown uses remain shared.
pub fn privateCells(a: std.mem.Allocator, p: Ir.Program, function: usize) ![]const bool {
    const f = p.functions[function];
    const counts = try a.alloc(usize, f.value_types.len);
    @memset(counts, 0);
    const allowed = try a.alloc(usize, f.value_types.len);
    @memset(allowed, 0);
    const result = try a.alloc(bool, f.local_types.len);
    @memset(result, true);
    for (f.blocks) |b| {
        for (b.instructions) |op| {
            Operands.countUses(op, counts);
            switch (op) {
                .reference_load => |v| allowed[v.reference] += 1,
                .reference_store => |v| allowed[v.reference] += 1,
                .reference_field => |v| if (p.structures[v.structure].is_class) {
                    allowed[v.reference] += 1;
                },
                .unary => |v| if (v.operator == .reference_is_edge) {
                    allowed[v.operand] += 1;
                },
                else => {},
            }
        }
        Operands.countTerminatorUses(b.terminator, counts);
    }
    for (f.blocks) |b| for (b.instructions) |op| if (op == .local_address) {
        const v = op.local_address;
        if (counts[v.result] != allowed[v.result]) result[v.local] = false;
    };
    return result;
}
