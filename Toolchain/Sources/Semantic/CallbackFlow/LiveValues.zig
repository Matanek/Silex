// Block-entry liveness includes local slots and implicit proof uses.
const std = @import("std");
const Ir = @import("../../Ir.zig");
const M = @import("Model.zig");
const Operands = @import("../../Optimize/ValueOperands.zig");
const A = std.mem.Allocator;
pub const Cache = struct {
    allocator: A,
    program: Ir.Program,
    entries: []?[]const []const bool,
    pub fn init(a: A, p: Ir.Program) !Cache {
        const entries = try a.alloc(?[]const []const bool, p.functions.len);
        @memset(entries, null);
        return .{ .allocator = a, .program = p, .entries = entries };
    }
    pub fn get(self: *Cache, id: usize) ![]const []const bool {
        if (self.entries[id]) |entry| return entry;
        const result = try function(self.allocator, self.program.functions[id]);
        self.entries[id] = result;
        return result;
    }
};
fn function(a: A, f: Ir.Function) ![]const []const bool {
    var scratch = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer scratch.deinit();
    const temporary = scratch.allocator();
    const n = f.value_types.len;
    const keep = try temporary.alloc(bool, n);
    @memset(keep, false);
    for (0..f.capture_types.len + f.parameter_types.len) |i| keep[i] = true;
    for (f.borrow_ends) |end| for (end.live) |binding| if (binding.value) |id| {
        keep[id] = true;
    };
    for (f.blocks) |b| for (b.instructions) |op| switch (op) {
        .enum_test => |v| keep[v.operand] = true,
        .protocol_test => |v| keep[v.operand] = true,
        else => {},
    };
    const live = try a.alloc([]bool, f.blocks.len);
    const definitions = try temporary.alloc([]bool, f.blocks.len);
    const uses = try temporary.alloc([]bool, f.blocks.len);
    const counts = try temporary.alloc(usize, n);
    for (f.blocks, 0..) |b, block| {
        live[block] = try a.dupe(bool, keep);
        definitions[block] = try temporary.alloc(bool, n);
        uses[block] = try temporary.alloc(bool, n);
        @memset(definitions[block], false);
        @memset(uses[block], false);
        @memset(counts, 0);
        for (b.instructions) |op| {
            Operands.countUses(op, counts);
            if (M.resultId(op)) |id| {
                if (counts[id] != 0 and !definitions[block][id]) uses[block][id] = true;
                definitions[block][id] = true;
            }
        }
        Operands.countTerminatorUses(b.terminator, counts);
        for (0..n) |i| if (counts[i] != 0 and !definitions[block][i]) {
            uses[block][i] = true;
        };
        for (0..n) |i| live[block][i] = live[block][i] or uses[block][i];
    }
    var changed = true;
    while (changed) {
        changed = false;
        var reverse = f.blocks.len;
        while (reverse > 0) {
            reverse -= 1;
            const block = reverse;
            const edges: []const usize = switch (f.blocks[block].terminator) {
                .jump => |target| &.{target},
                .branch => |branch| &.{ branch.then_block, branch.else_block },
                else => &.{},
            };
            for (edges) |successor| for (0..n) |i| if (!definitions[block][i] and live[successor][i] and !live[block][i]) {
                live[block][i] = true;
                changed = true;
            };
        }
    }
    const result = try a.alloc([]const bool, live.len);
    for (live, result) |entry, *out| out.* = entry;
    return result;
}
