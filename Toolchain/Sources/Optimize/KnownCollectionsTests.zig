const std = @import("std");
const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Release = @import("Release.zig");
const Ir = @import("../Ir.zig");
const KnownCollections = @import("KnownCollections.zig");

test "known collection snapshots stop at aliases calls lifetime and redefinitions" {
    const position = @import("../Source.zig").Position{ .offset = 0, .line = 1, .column = 1 };
    const barriers = [_]?Ir.Instruction{
        null,
        .{ .reference_store = .{ .reference = 0, .operand = 1 } },
        .{ .call = .{ .result = null, .function = 1, .arguments = &.{ 0, 1 } } },
        .{ .collection_replace = .{ .result = 7, .collection = 5, .index = 2, .replacement = 1, .position = position } },
        .{ .list_drop = .{ .operand = 4 } },
        .{ .local_store = .{ .local = 0, .operand = 1 } },
        .{ .copy = .{ .result = 1, .operand = 2 } },
    };
    for (barriers) |barrier| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        try instructions.appendSlice(allocator, &.{
            .{ .constant_int = .{ .result = 2, .bits = 0 } },
            .{ .constant_int = .{ .result = 3, .bits = 2 } },
            .{ .list_init = .{ .result = 4, .values = &.{ 1, 1 } } },
            .{ .collection_view = .{ .result = 5, .collection = 4, .start = 2, .end = 3 } },
        });
        if (barrier) |instruction| try instructions.append(allocator, instruction);
        try instructions.append(allocator, .{ .collection_load = .{ .result = 6, .collection = 5, .index = 2, .position = position } });
        const function: Ir.Function = .{
            .name = "snapshot",
            .parameter_types = &.{ .address, .int },
            .return_type = .int,
            .local_types = &.{.int},
            .value_types = &.{ .address, .int, .int, .int, Ir.Type.structure(0), Ir.Type.structure(1), .int, Ir.Type.structure(1) },
            .blocks = &.{.{ .instructions = instructions.items, .terminator = .{ .return_value = 6 } }},
        };
        const program: Ir.Program = .{ .structures = &.{
            .{ .name = "int[]", .fields = &.{}, .collection = .{ .element = .int, .length = null, .view = false } },
            .{ .name = "int[..]", .fields = &.{}, .collection = .{ .element = .int, .length = null, .view = true } },
        }, .functions = &.{function} };
        const optimized = try KnownCollections.optimize(allocator, program, function);
        const last = optimized.blocks[0].instructions[instructions.items.len - 1];
        if (barrier == null) {
            try std.testing.expect(last == .copy);
            // The same derivation cannot be reused across a control boundary.
            var split = function;
            split.blocks = &.{
                .{ .instructions = instructions.items[0..4], .terminator = .{ .jump = 1 } },
                .{ .instructions = instructions.items[4..], .terminator = .{ .return_value = 6 } },
            };
            const separate = try KnownCollections.optimize(allocator, program, split);
            try std.testing.expect(separate.blocks[1].instructions[0] == .collection_load);
        } else {
            try std.testing.expect(last == .collection_load);
            try std.testing.expect(last.collection_load.checked);
        }
    }
}

test "known views preserve invalid indices and empty view failures" {
    const cases = [_][]const u8{
        "let values:int[] = [3, 5]; let view = @values[0:2]; print(view[2])",
        "let values:int[] = [3, 5]; let view = @values[0:2]; print(view[-3])",
        "let values:int[] = [3, 5]; let view = @values[2:1]; print(view[0])",
        "let values:int[] = [3, 5]; let view = @values[0:2]; print(view[9223372036854775807 + 1])",
    };
    for (cases) |body| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var frontend = Frontend.Frontend.init(allocator);
        const source = try std.fmt.allocPrint(allocator, "func main() {{ {s} }}", .{body});
        const compilation = try frontend.compile(source);
        const optimized = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true });
        const before = Interpreter.runCapture(allocator, compilation.ir) catch |expected| {
            try std.testing.expectError(expected, Interpreter.runCapture(allocator, optimized));
            continue;
        };
        const after = try Interpreter.runCapture(allocator, optimized);
        try std.testing.expect(before.exit_code != 0);
        try std.testing.expectEqual(before.exit_code, after.exit_code);
        try std.testing.expectEqualStrings(before.stdout, after.stdout);
        try std.testing.expectEqualStrings(before.stderr, after.stderr);
    }
}

test "release forwards known view elements after helper inlining" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func select(values:@int[..], index:int) int {
        \\    return values[index] + values[-1]
        \\}
        \\func main() {
        \\    let values:int[] = [3, 5, 8, 13]
        \\    let view = @values[0:values.count()]
        \\    print(select(view, 1))
        \\}
    );
    const optimized = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true });
    const result = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("18\n", result.stdout);
    const without = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .disabled = .reference_memory_elision });
    try std.testing.expectEqual(@as(usize, 0), loads(optimized, "main"));
    try std.testing.expectEqual(@as(usize, 2), loads(without, "main"));
}

test "release removes only unobserved scalar collection storage" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func evaluate(value:int) int {
        \\    let values:int[] = [value, 7]
        \\    let view = @values[0:2]
        \\    return view[0] + view[-1]
        \\}
        \\func escape(value:int) int[] { return [value, 7] }
        \\class Owner { var value:int }
        \\func owned(value:Owner) { var values:Owner[] = [value] }
        \\func main() { print(evaluate(1)) }
    );
    const result = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true });
    try std.testing.expectEqualStrings("8\n", (try Interpreter.runCapture(allocator, result)).stdout);
    for (result.functions) |function| {
        var storage: usize = 0;
        for (function.blocks) |block| for (block.instructions) |instruction| {
            if (instruction == .list_init or instruction == .list_drop or instruction == .list_retain or instruction == .collection_view) storage += 1;
        };
        if (std.mem.eql(u8, function.name, "evaluate")) try std.testing.expectEqual(@as(usize, 0), storage);
        if (std.mem.eql(u8, function.name, "escape") or std.mem.eql(u8, function.name, "owned")) {
            if (storage == 0) std.debug.print("unexpectedly removed storage in {s}:\n{s}\n", .{ function.name, try Ir.writeText(allocator, .{ .structures = result.structures, .functions = &.{function} }) });
            try std.testing.expect(storage != 0);
        }
    }
}

test "dead scalar collection storage preserves initializer failures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func discard(value:int) { let unused:int[] = [value + 1] }
        \\func main() { discard(9223372036854775807) }
    );
    const result = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true });
    const before = Interpreter.runCapture(allocator, compilation.ir) catch |expected| {
        try std.testing.expectError(expected, Interpreter.runCapture(allocator, result));
        return;
    };
    const after = try Interpreter.runCapture(allocator, result);
    try std.testing.expect(before.exit_code != 0);
    try std.testing.expectEqual(before.exit_code, after.exit_code);
    try std.testing.expectEqualStrings(before.stderr, after.stderr);
}

test "branching loop already proves nonnegative induction dividends" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func classify(rounds:int) int {
        \\    var value = 0
        \\    var index = 0
        \\    while index < rounds {
        \\        if index % 3 == 0 { value += index % 97 }
        \\        else { value -= index % 31 }
        \\        value %= 1000003
        \\        index++
        \\    }
        \\    return value
        \\}
        \\func main() { print(classify(50)) }
    );
    const optimized = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true });
    for (optimized.functions) |function| {
        if (!std.mem.eql(u8, function.name, "classify")) continue;
        var positive: usize = 0;
        var signed: usize = 0;
        for (function.blocks) |block| for (block.instructions) |instruction| {
            if (instruction != .binary or instruction.binary.operator != .remainder) continue;
            if (instruction.binary.left_non_negative) positive += 1 else signed += 1;
        };
        try std.testing.expectEqual(@as(usize, 3), positive);
        try std.testing.expectEqual(@as(usize, 1), signed);
        return;
    }
    return error.TestUnexpectedResult;
}

fn loads(program: Ir.Program, name: []const u8) usize {
    for (program.functions) |function| {
        if (!std.mem.eql(u8, function.name, name)) continue;
        var count: usize = 0;
        for (function.blocks) |block| for (block.instructions) |instruction| {
            if (instruction == .collection_load) count += 1;
        };
        return count;
    }
    return std.math.maxInt(usize);
}

test "known collection indices include secondary instruction definitions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const position = @import("../Source.zig").Position{ .offset = 0, .line = 1, .column = 1 };
    const list = Ir.Type.structure(0);
    const function: Ir.Function = .{
        .name = "secondary_result",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{ .int, .int, list, list, list, .int },
        .blocks = &.{.{ .instructions = &.{
            .{ .constant_int = .{ .result = 0, .bits = 0 } },
            .{ .constant_int = .{ .result = 1, .bits = 1 } },
            .{ .list_init = .{ .result = 2, .values = &.{1} } },
            .{ .list_edit = .{ .result = 3, .collection = 2, .kind = .take_last, .removed = 0, .position = position } },
            .{ .list_init = .{ .result = 4, .values = &.{1} } },
            .{ .collection_load = .{ .result = 5, .collection = 4, .index = 0, .position = position } },
        }, .terminator = .{ .return_value = 5 } }},
    };
    const program: Ir.Program = .{ .structures = &.{.{
        .name = "int[]",
        .fields = &.{},
        .collection = .{ .element = .int, .length = null, .view = false },
    }}, .functions = &.{function} };
    const result = try KnownCollections.optimize(allocator, program, function);
    try std.testing.expect(result.blocks[0].instructions[5] == .collection_load);
    try std.testing.expect(result.blocks[0].instructions[5].collection_load.checked);
}
