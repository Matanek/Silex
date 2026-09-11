const std = @import("std");
const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Ir = @import("../Ir.zig");
const Release = @import("Release.zig");
const ScalarExpressions = @import("ScalarExpressions.zig");

test "scalar expressions reuse snapshots across stores but stop at calls" {
    const barriers = [_]?Ir.Instruction{
        null,
        .{ .reference_store = .{ .reference = 0, .operand = 3 } },
        .{ .call = .{ .result = null, .function = 1, .arguments = &.{0} } },
    };
    for (barriers, 0..) |barrier, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        try instructions.append(allocator, .{ .binary = .{ .result = 3, .operator = .multiply, .left = 1, .right = 2 } });
        if (barrier) |instruction| try instructions.append(allocator, instruction);
        try instructions.append(allocator, .{ .binary = .{ .result = 4, .operator = .multiply, .left = 1, .right = 2 } });
        const function: Ir.Function = .{
            .name = "snapshots",
            .parameter_types = &.{ .address, .float64, .float64 },
            .return_type = .float64,
            .local_types = &.{},
            .value_types = &.{ .address, .float64, .float64, .float64, .float64 },
            .blocks = &.{.{ .instructions = instructions.items, .terminator = .{ .return_value = 4 } }},
        };
        const optimized = try ScalarExpressions.optimize(allocator, function);
        const last = optimized.blocks[0].instructions[instructions.items.len - 1];
        try std.testing.expectEqual(index != 2, last == .copy);
        if (last == .copy) try std.testing.expectEqual(@as(Ir.ValueId, 3), last.copy.operand);
    }
}

test "scalar expressions retain operand order flags and edge redefinitions" {
    const variants = [_]Ir.Instruction.Binary{
        .{ .result = 3, .operator = .multiply, .left = 0, .right = 1 },
        .{ .result = 3, .operator = .multiply, .left = 1, .right = 0 },
        .{ .result = 3, .operator = .multiply, .left = 0, .right = 1, .checked = false },
        .{ .result = 3, .operator = .multiply, .left = 0, .right = 1, .left_non_negative = true },
    };
    for (variants, 0..) |variant, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        const function: Ir.Function = .{
            .name = "exact",
            .parameter_types = &.{ .float64, .float64 },
            .return_type = .float64,
            .local_types = &.{},
            .value_types = &.{ .float64, .float64, .float64, .float64 },
            .blocks = &.{.{ .instructions = &.{
                .{ .binary = .{ .result = 2, .operator = .multiply, .left = 0, .right = 1 } },
                .{ .binary = variant },
            }, .terminator = .{ .return_value = 3 } }},
        };
        const optimized = try ScalarExpressions.optimize(allocator, function);
        try std.testing.expectEqual(index == 0, optimized.blocks[0].instructions[1] == .copy);
    }

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const function: Ir.Function = .{
        .name = "edge_definition",
        .parameter_types = &.{ .int, .int },
        .return_type = .int,
        .local_types = &.{},
        .value_types = &.{ .int, .int, .int, .int },
        .blocks = &.{.{ .instructions = &.{
            .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
            .{ .copy = .{ .result = 0, .operand = 1 } },
            .{ .binary = .{ .result = 3, .operator = .add, .left = 0, .right = 1 } },
        }, .terminator = .{ .return_value = 3 } }},
    };
    const optimized = try ScalarExpressions.optimize(allocator, function);
    try std.testing.expect(optimized.blocks[0].instructions[2] == .binary);
}

test "scalar expressions do not infer availability across control flow" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const function: Ir.Function = .{
        .name = "blocks",
        .parameter_types = &.{ .int, .int },
        .return_type = .int,
        .local_types = &.{},
        .value_types = &.{ .int, .int, .int, .int },
        .blocks = &.{
            .{ .instructions = &.{.{ .binary = .{ .result = 2, .operator = .multiply, .left = 0, .right = 1 } }}, .terminator = .{ .jump = 1 } },
            .{ .instructions = &.{.{ .binary = .{ .result = 3, .operator = .multiply, .left = 0, .right = 1 } }}, .terminator = .{ .return_value = 3 } },
        },
    };
    const optimized = try ScalarExpressions.optimize(allocator, function);
    try std.testing.expect(optimized.blocks[1].instructions[0] == .binary);
}

test "release reuses identical scalar expressions without reassociation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func calculate(a:float64, b:float64) float64 {
        \\    let first = a * b
        \\    let second = a * b
        \\    return first + second
        \\}
        \\func main() {
        \\    print(calculate(1.5, 2.0) == 6.0)
        \\    print(1.0 / calculate(-0.0, 2.0) < 0.0)
        \\    let nan = calculate(0.0, 1.0 / 0.0)
        \\    print(nan != nan)
        \\}
    );
    const optimized = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true });
    const disabled = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .disabled = .ssa_value_simplification, .verify_each_pass = true });
    const before = try Interpreter.runCapture(allocator, compilation.ir);
    const after = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("true\ntrue\ntrue\n", before.stdout);
    try std.testing.expectEqualStrings(before.stdout, after.stdout);
    try std.testing.expectEqual(@as(usize, 2), products(disabled, "calculate"));
    try std.testing.expectEqual(@as(usize, 1), products(optimized, "calculate"));
}

fn products(program: Ir.Program, name: []const u8) usize {
    var count: usize = 0;
    for (program.functions) |function| {
        if (!std.mem.eql(u8, function.name, name)) continue;
        for (function.blocks) |block| for (block.instructions) |instruction| {
            if (instruction == .binary and instruction.binary.operator == .multiply) count += 1;
        };
    }
    return count;
}
