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

test "lower answer and nested calls to deterministic machine slots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const program = try compile(arena.allocator(),
        \\func add(left:int, right:int) int { return left + right }
        \\func answer() int { return add(40, 2) }
        \\func main() { answer() }
    );
    try std.testing.expectEqual(@as(usize, 3), program.functions.len);
    try std.testing.expectEqual(@as(u12, 2), program.functions[0].parameter_count);
    try std.testing.expectEqual(@as(u12, 3), program.functions[0].slot_count);
    try std.testing.expectEqual(@as(u32, 32), program.functions[0].frame_size);
    try std.testing.expectEqual(Machine.BinaryOperator.add, program.functions[0].instructions[0].binary.operator);
    try std.testing.expectEqual(@as(Machine.Slot, 0), program.functions[0].instructions[0].binary.left);
    try std.testing.expectEqual(@as(Machine.FunctionId, 0), program.functions[1].instructions[2].call.function);
    try std.testing.expectEqual(@as(Machine.Slot, 2), program.functions[1].instructions[2].call.result.?.start);
    try std.testing.expectEqual(@as(Machine.FunctionId, 1), program.functions[2].instructions[0].call.function);
    try std.testing.expect(program.debug);
    try std.testing.expectEqual(@as(usize, 1), program.functions[0].source_position.?.line);
    try std.testing.expectEqual(@as(usize, 1), program.functions[0].instruction_positions[0].?.line);
    try std.testing.expectEqual(@as(usize, 3), program.functions[2].instruction_positions[0].?.line);
}

test "lower internal stack arguments before encoding" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        "func many(a:int,b:int,c:int,d:int,e:int,f:int,g:int,h:int,i:int) int { return i } func main() { many(1,2,3,4,5,6,7,8,9) }",
    );
    const lowered = try Lower.lower(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u12, 9), lowered.functions[0].parameter_count);
    try std.testing.expectEqual(@as(usize, 9), lowered.functions[1].instructions[9].call.arguments.len);

    const functions = [_]Ir.Function{.{
        .name = "floating",
        .parameter_types = &.{.float32},
        .return_type = .void,
        .value_types = &.{.float32},
        .blocks = &.{.{ .instructions = &.{}, .terminator = .return_void }},
    }};
    _ = try Lower.lower(allocator, .{ .functions = &functions });
}

test "lower abstract mutable locals after value slots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const program = try compile(arena.allocator(),
        \\func main() {
        \\    var value:int = 1
        \\    value = 42
        \\    print(value)
        \\}
    );
    const function = program.functions[0];
    try std.testing.expectEqual(@as(Machine.Slot, 4), function.slot_count);
    try std.testing.expectEqual(@as(Machine.Slot, 3), function.instructions[1].copy.result);
    try std.testing.expectEqual(@as(Machine.Slot, 3), function.instructions[3].copy.result);
    try std.testing.expectEqual(@as(Machine.Slot, 3), function.instructions[4].copy.operand);
}

test "lower trivial aggregate copies without the deep-copy runtime" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const program = try compile(arena.allocator(),
        \\struct Quaternion { let x:float; let y:float; let z:float; let w:float }
        \\class State { var value:int }
        \\func main() {
        \\    let rotation = Quaternion(x:0.0, y:0.0, z:0.0, w:1.0)
        \\    let rotation_copy = copy rotation
        \\    var state = State(value:1)
        \\    var state_copy = copy state
        \\}
    );
    var found_range = false;
    var found_deep = false;
    for (program.functions[0].instructions) |instruction| switch (instruction) {
        .copy_range => found_range = true,
        .deep_copy => found_deep = true,
        else => {},
    };
    try std.testing.expect(found_range);
    try std.testing.expect(found_deep);
}

test "bound lowering workers keep small programs direct" {
    try std.testing.expectEqual(@as(u16, 1), Lower.selectedWorkerCount(Lower.parallel_function_threshold - 1, 4));
    try std.testing.expectEqual(@as(u16, 2), Lower.selectedWorkerCount(Lower.parallel_function_threshold, 2));
    try std.testing.expectEqual(Lower.max_worker_count, Lower.selectedWorkerCount(Lower.parallel_function_threshold, std.math.maxInt(u16)));
}

test "parallel lowering preserves canonical machine output" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const function_count = Lower.parallel_function_threshold + 17;
    const functions = try allocator.alloc(Ir.Function, function_count);
    for (functions, 0..) |*function, index| {
        const instructions = try allocator.alloc(Ir.Instruction, 1);
        instructions[0] = .{ .constant_str = .{
            .result = 0,
            .value = try std.fmt.allocPrint(allocator, "parallel-{d}", .{index}),
        } };
        const blocks = try allocator.alloc(Ir.Block, 1);
        blocks[0] = .{ .instructions = instructions, .terminator = .return_void };
        function.* = .{
            .name = try std.fmt.allocPrint(allocator, "function_{d}", .{index}),
            .parameter_types = &.{},
            .return_type = .void,
            .value_types = &.{.str},
            .blocks = blocks,
        };
    }
    const program: Ir.Program = .{ .functions = functions };
    const single = try Lower.lowerWithBoundariesAndWorkers(allocator, program, &.{}, .release, 1);
    const pair = try Lower.lowerWithBoundariesAndWorkers(allocator, program, &.{}, .release, 2);
    const maximum = try Lower.lowerWithBoundariesAndWorkers(allocator, program, &.{}, .release, Lower.max_worker_count);
    const single_json = try std.json.Stringify.valueAlloc(allocator, single, .{});
    const pair_json = try std.json.Stringify.valueAlloc(allocator, pair, .{});
    const maximum_json = try std.json.Stringify.valueAlloc(allocator, maximum, .{});
    try std.testing.expectEqualStrings(single_json, pair_json);
    try std.testing.expectEqualStrings(single_json, maximum_json);
}
