const std = @import("std");
const Ir = @import("../Ir.zig");
const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Release = @import("Release.zig");

const helpers =
    \\func endpoints(values:@int[..]) int { return values[0] + values[-1] }
    \\func evaluate(value:int) int {
    \\    let values:int[] = [value, 3, value + 1, 7]
    \\    let view = @values[0:values.count()]
    \\    return endpoints(view)
    \\}
;

test "late scalar closure revisits cleaned leaves and respects disabling" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(helpers ++
        \\func main() {
        \\    var value = 1
        \\    var index = 0
        \\    while index < 5000 { value = evaluate(value % 997); index++ }
        \\    print(value)
        \\}
    );
    const early = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true, .stop_after = .ssa_value_simplification });
    const final = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true });
    const disabled = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true, .disabled = .value_inlining });
    try std.testing.expectEqual(@as(usize, 1), mainCalls(early));
    try std.testing.expectEqual(@as(usize, 0), mainCalls(final));
    try std.testing.expect(mainCalls(disabled) > 0);
    const raw = try Interpreter.runCapture(allocator, compilation.ir);
    const optimized = try Interpreter.runCapture(allocator, final);
    try std.testing.expectEqualStrings(raw.stdout, optimized.stdout);
}

test "late scalar closure preserves unused initializer failure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(helpers ++
        \\func main() { print(evaluate(9223372036854775807)) }
    );
    const final = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true });
    try std.testing.expectEqual(@as(usize, 0), mainCalls(final));
    try std.testing.expectError(error.IntegerOverflow, Interpreter.runCapture(allocator, compilation.ir));
    try std.testing.expectError(error.IntegerOverflow, Interpreter.runCapture(allocator, final));
}

test "late scalar closure leaves ordered effects out of the revisit" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func observe(value:int) int { print(value); return value + 1 }
        \\func main() { print(observe(2)) }
    );
    const final = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true });
    try std.testing.expectEqual(@as(usize, 1), mainCalls(final));
    const result = try Interpreter.runCapture(allocator, final);
    try std.testing.expectEqualStrings("2\n3\n", result.stdout);
}

fn mainCalls(program: Ir.Program) usize {
    var count: usize = 0;
    for (program.functions) |function| {
        if (!std.mem.eql(u8, function.name, "main")) continue;
        for (function.blocks) |block| for (block.instructions) |instruction| {
            if (instruction == .call) count += 1;
        };
    }
    return count;
}
