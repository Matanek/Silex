const std = @import("std");
const Frontend = @import("../Frontend.zig");
const Ir = @import("../Ir.zig");
const Lower = @import("Lower.zig");
const Machine = @import("Machine.zig");

const Allocator = std.mem.Allocator;

fn compile(allocator: Allocator, source: []const u8) !Machine.Program {
    var frontend = Frontend.Frontend.init(allocator);
    return Lower.lower(allocator, (try frontend.compile(source)).ir);
}

test "Debug copy cleanup preserves calls snapshots and source locations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const before = try compile(allocator,
        \\func evaluate(value:int) int {
        \\    var source = value
        \\    let snapshot = source
        \\    let unused = snapshot
        \\    source = 7
        \\    return snapshot * 2 + source
        \\}
        \\func entry(value:int) int { return evaluate(value) }
        \\func main() { print(entry(5)) }
    );
    const after = try Lower.simplifyDebugCopies(allocator, before);
    try std.testing.expect(after.debug);
    try std.testing.expectEqual(before.functions.len, after.functions.len);
    var before_copies: usize = 0;
    var after_copies: usize = 0;
    for (before.functions, after.functions) |original, cleaned| {
        try std.testing.expectEqual(original.slot_count, cleaned.slot_count);
        try std.testing.expectEqual(original.frame_size, cleaned.frame_size);
        try std.testing.expectEqualDeep(original.source_position, cleaned.source_position);
        try std.testing.expectEqual(cleaned.instructions.len, cleaned.instruction_positions.len);
        var before_calls: usize = 0;
        var after_calls: usize = 0;
        for (original.instructions) |instruction| {
            if (instruction == .copy or instruction == .copy_range) before_copies += 1;
            if (instruction == .call) before_calls += 1;
        }
        for (cleaned.instructions, cleaned.instruction_positions) |instruction, position| {
            if (instruction == .copy or instruction == .copy_range) after_copies += 1;
            if (instruction == .call) after_calls += 1;
            if (position) |actual| {
                var found = false;
                for (original.instruction_positions) |previous| {
                    if (previous) |expected| if (std.meta.eql(actual, expected)) {
                        found = true;
                        break;
                    };
                }
                try std.testing.expect(found);
            }
        }
        try std.testing.expectEqual(before_calls, after_calls);
    }
    try std.testing.expect(after_copies < before_copies);
    if (@import("builtin").os.tag == .macos and @import("builtin").cpu.arch == .aarch64) {
        for ([_]Machine.Program{ before, after }) |program| {
            const result = try @import("Runner.zig").invoke(allocator, program, 1, &.{5});
            try std.testing.expectEqual(Machine.Status.success, result.status);
            try std.testing.expectEqual(@as(i64, 17), result.value);
        }
    }
}
