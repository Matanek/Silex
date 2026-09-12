const std = @import("std");
const Ir = @import("../Ir.zig");
const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Release = @import("Release.zig");
const DominatedValues = @import("DominatedValues.zig");

test "dominated values handle shuffled blocks and unreachable predecessors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const aggregate = Ir.Type.structure(0);
    const function: Ir.Function = .{
        .name = "shuffled",
        .parameter_types = &.{ aggregate, .bool },
        .return_type = .float64,
        .value_types = &.{ aggregate, .bool, .float64, .float64, .float64, .float64 },
        .blocks = &.{
            .{ .instructions = &.{.{ .field_load = .{ .result = 2, .base = 0, .field = 0 } }}, .terminator = .{ .branch = .{ .condition = 1, .then_block = 3, .else_block = 1 } } },
            .{ .instructions = &.{.{ .field_load = .{ .result = 3, .base = 0, .field = 0 } }}, .terminator = .{ .return_value = 3 } },
            .{ .instructions = &.{.{ .field_load = .{ .result = 4, .base = 0, .field = 0 } }}, .terminator = .{ .jump = 1 } },
            .{ .instructions = &.{.{ .field_load = .{ .result = 5, .base = 0, .field = 0 } }}, .terminator = .{ .jump = 1 } },
        },
    };
    const program: Ir.Program = .{ .structures = &.{.{ .name = "Value", .fields = &.{.{ .name = "x", .type = .float64, .mutable = true }} }}, .functions = &.{function} };
    const optimized = try DominatedValues.optimize(arena.allocator(), program, function);
    try std.testing.expect(optimized.blocks[1].instructions[0] == .copy);
    try std.testing.expect(optimized.blocks[3].instructions[0] == .copy);
    try std.testing.expect(optimized.blocks[2].instructions[0] == .field_load);
}

test "dominated values preserve conditional availability and loop entry" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const function: Ir.Function = .{
        .name = "loop",
        .parameter_types = &.{ .int, .int, .bool },
        .return_type = .int,
        .value_types = &.{ .int, .int, .bool, .int, .int },
        .blocks = &.{
            .{ .instructions = &.{}, .terminator = .{ .branch = .{ .condition = 2, .then_block = 1, .else_block = 2 } } },
            .{ .instructions = &.{.{ .binary = .{ .result = 3, .operator = .divide, .left = 0, .right = 1 } }}, .terminator = .{ .jump = 2 } },
            .{ .instructions = &.{.{ .binary = .{ .result = 4, .operator = .divide, .left = 0, .right = 1 } }}, .terminator = .{ .branch = .{ .condition = 2, .then_block = 1, .else_block = 3 } } },
            .{ .instructions = &.{}, .terminator = .{ .return_value = 4 } },
        },
    };
    const optimized = try DominatedValues.optimize(arena.allocator(), .{ .functions = &.{function} }, function);
    try std.testing.expect(optimized.blocks[2].instructions[0] == .binary);
    try std.testing.expect(optimized.blocks[1].instructions[0] == .binary);
}

test "dominated fields preserve aliases signed zero and partial availability" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Pair { var x:float64; var y:float64 }
        \\func evaluate(input:@Pair, flag:bool) float64 {
        \\    let first = copy input.x
        \\    var total = first
        \\    if flag { total += input.y }
        \\    return total + input.x
        \\}
        \\func partial(input:@Pair, flag:bool) float64 {
        \\    if flag { if input.x < 0.0 { return -1.0 } }
        \\    return input.x
        \\}
        \\func aliasing(input:&Pair, alias:&Pair) float64 {
        \\    let before = copy input.x
        \\    alias.x = 9.0
        \\    return before + input.x
        \\}
        \\func main() {
        \\    var value = Pair(x:2.0, y:3.0)
        \\    print(evaluate(value, true) == 7.0)
        \\    print(evaluate(value, false) == 4.0)
        \\    print(partial(value, true) == 2.0)
        \\    print(aliasing(value, value) == 11.0)
        \\    print(1.0 / evaluate(Pair(x:-0.0), false) < 0.0)
        \\}
    );
    const optimized = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true });
    const disabled = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true, .disabled = .ssa_value_simplification });
    const before = try Interpreter.runCapture(allocator, compilation.ir);
    const after = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("true\ntrue\ntrue\ntrue\ntrue\n", before.stdout);
    try std.testing.expectEqualStrings(before.stdout, after.stdout);
    try std.testing.expectEqual(@as(usize, 3), fields(disabled, "evaluate"));
    try std.testing.expectEqual(@as(usize, 2), fields(optimized, "evaluate"));
    try std.testing.expectEqual(@as(usize, 2), fields(optimized, "partial"));
}

test "dominated expressions retain their first checked failure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func evaluate(a:int, b:int, flag:bool) int {
        \\    let first = a / b
        \\    var result = first
        \\    if flag { result += 1 }
        \\    return result + a / b
        \\}
        \\func main() { print(evaluate(7, 0, false)) }
    );
    const optimized = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true });
    try std.testing.expectError(error.DivisionByZero, Interpreter.runCapture(allocator, compilation.ir));
    try std.testing.expectError(error.DivisionByZero, Interpreter.runCapture(allocator, optimized));
    var divisions: usize = 0;
    for (optimized.functions) |function| {
        if (!std.mem.eql(u8, function.name, "evaluate")) continue;
        for (function.blocks) |block| for (block.instructions) |instruction| {
            if (instruction == .binary and instruction.binary.operator == .divide) divisions += 1;
        };
    }
    try std.testing.expectEqual(@as(usize, 1), divisions);
}

fn fields(program: Ir.Program, name: []const u8) usize {
    var count: usize = 0;
    for (program.functions) |function| {
        if (!std.mem.eql(u8, function.name, name)) continue;
        for (function.blocks) |block| for (block.instructions) |instruction| {
            if (instruction == .field_load) count += 1;
        };
    }
    return count;
}

test "dominated expressions preserve ordered scalar output" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func evaluate(a:int, b:int, flag:bool) int {
        \\    let first = a / b
        \\    var result = first
        \\    if flag { print(1); result += 1 }
        \\    return result + a / b
        \\}
        \\func main() {
        \\    print(evaluate(12, 3, true) == 9)
        \\    print(evaluate(12, 3, false) == 8)
        \\}
    );
    const optimized = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true });
    const before = try Interpreter.runCapture(allocator, compilation.ir);
    const after = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("1\ntrue\ntrue\n", before.stdout);
    try std.testing.expectEqualStrings(before.stdout, after.stdout);
    var divisions: usize = 0;
    for (optimized.functions) |function| {
        if (!std.mem.eql(u8, function.name, "evaluate")) continue;
        for (function.blocks) |block| for (block.instructions) |instruction| {
            if (instruction == .binary and instruction.binary.operator == .divide) divisions += 1;
        };
    }
    try std.testing.expectEqual(@as(usize, 1), divisions);
}

test "dominated reference reads require stable parameters and a read-only region" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const aggregate: Ir.Structure = .{ .name = "Pair", .fields = &.{
        .{ .name = "x", .type = .float64, .mutable = true },
        .{ .name = "y", .type = .float64, .mutable = true },
    } };
    // Plain reuse, possible aliasing write, reassigned address parameter,
    // another root, another field, a call, and conditional availability.
    for (0..7) |variant| {
        var middle: std.ArrayList(Ir.Instruction) = .empty;
        switch (variant) {
            1 => try middle.append(allocator, .{ .reference_store = .{ .reference = 1, .operand = 4 } }),
            2 => try middle.append(allocator, .{ .local_store = .{ .local = 0, .operand = 1 } }),
            5 => try middle.append(allocator, .{ .call = .{ .function = 1, .arguments = &.{}, .result = null } }),
            else => {},
        }
        try middle.appendSlice(allocator, &.{
            .{ .reference_field = .{ .result = 5, .reference = if (variant == 3) 1 else 0, .structure = 0, .field = if (variant == 4) 1 else 0 } },
            .{ .reference_load = .{ .result = 6, .reference = 5 } },
        });
        const function: Ir.Function = .{
            .name = "reference_region",
            .parameter_types = &.{ .address, .address, .bool },
            .return_type = .float64,
            .value_types = &.{ .address, .address, .bool, .address, .float64, .address, .float64 },
            .blocks = &.{
                .{ .instructions = &.{}, .terminator = if (variant == 6) .{ .branch = .{ .condition = 2, .then_block = 1, .else_block = 2 } } else .{ .jump = 1 } },
                .{ .instructions = &.{
                    .{ .reference_field = .{ .result = 3, .reference = 0, .structure = 0, .field = 0 } },
                    .{ .reference_load = .{ .result = 4, .reference = 3 } },
                }, .terminator = .{ .jump = 2 } },
                .{ .instructions = middle.items, .terminator = .{ .return_value = 6 } },
            },
        };
        const optimized = try DominatedValues.optimize(allocator, .{ .structures = &.{aggregate}, .functions = &.{function} }, function);
        const last = optimized.blocks[2].instructions[optimized.blocks[2].instructions.len - 1];
        try std.testing.expectEqual(variant == 0, last == .copy);
        if (variant == 0) try std.testing.expectEqual(@as(Ir.ValueId, 4), last.copy.operand);
    }
}
