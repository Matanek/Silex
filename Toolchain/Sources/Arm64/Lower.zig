const std = @import("std");
const Ir = @import("../Ir.zig");
const Machine = @import("Machine.zig");

const Allocator = std.mem.Allocator;

pub fn lower(allocator: Allocator, program: Ir.Program) Machine.Error!Machine.Program {
    var functions: std.ArrayList(Machine.Function) = .empty;
    var strings: std.ArrayList([]const u8) = .empty;
    try strings.append(allocator, "\n");
    try strings.append(allocator, "true");
    try strings.append(allocator, "false");
    for (program.functions) |function| {
        try functions.append(allocator, try lowerFunction(allocator, program, &strings, function));
    }
    const result: Machine.Program = .{
        .functions = try functions.toOwnedSlice(allocator),
        .strings = try strings.toOwnedSlice(allocator),
    };
    try Machine.validate(result);
    return result;
}

fn lowerFunction(
    allocator: Allocator,
    program: Ir.Program,
    strings: *std.ArrayList([]const u8),
    function: Ir.Function,
) Machine.Error!Machine.Function {
    const parameter_count = try Machine.checkedArgumentCount(function.parameter_types.len);
    const slot_count = try Machine.checkedSlot(function.value_types.len);
    try requireExecutableReturnType(function.return_type);
    for (function.parameter_types) |type_value| try requireExecutableValueType(type_value);
    for (function.value_types) |type_value| try requireExecutableValueType(type_value);

    var instructions: std.ArrayList(Machine.Instruction) = .empty;
    for (function.instructions) |instruction| {
        try instructions.append(allocator, try lowerInstruction(allocator, program, strings, function, instruction));
    }
    return .{
        .name = function.name,
        .parameter_count = parameter_count,
        .return_type = function.return_type,
        .slot_count = slot_count,
        .frame_size = try Machine.frameSize(slot_count),
        .instructions = try instructions.toOwnedSlice(allocator),
    };
}

fn lowerInstruction(
    allocator: Allocator,
    program: Ir.Program,
    strings: *std.ArrayList([]const u8),
    function: Ir.Function,
    instruction: Ir.Instruction,
) Machine.Error!Machine.Instruction {
    return switch (instruction) {
        .constant_int => |constant| .{ .constant_int = .{
            .result = try Machine.checkedSlot(constant.result),
            .value = constant.value,
        } },
        .constant_bool => |constant| .{ .constant_bool = .{
            .result = try Machine.checkedSlot(constant.result),
            .value = constant.value,
        } },
        .constant_str => |constant| .{ .constant_str = .{
            .result = try Machine.checkedSlot(constant.result),
            .string = try internString(allocator, strings, constant.value),
        } },
        .unary => |unary| .{ .unary = .{
            .result = try Machine.checkedSlot(unary.result),
            .operator = switch (unary.operator) {
                .negate => .negate,
            },
            .operand = try Machine.checkedSlot(unary.operand),
        } },
        .binary => |binary| .{ .binary = .{
            .result = try Machine.checkedSlot(binary.result),
            .operator = switch (binary.operator) {
                .add => .add,
                .subtract => .subtract,
                .multiply => .multiply,
                .divide => .divide,
                .remainder => .remainder,
                .less => .less,
                .less_equal => .less_equal,
                .greater => .greater,
                .greater_equal => .greater_equal,
                .equal => .equal,
                .not_equal => .not_equal,
            },
            .left = try Machine.checkedSlot(binary.left),
            .right = try Machine.checkedSlot(binary.right),
        } },
        .call => |call| call: {
            _ = try Machine.checkedArgumentCount(call.arguments.len);
            const arguments = try allocator.alloc(Machine.Slot, call.arguments.len);
            for (call.arguments, 0..) |argument, index| arguments[index] = try Machine.checkedSlot(argument);
            break :call .{ .call = .{
                .result = if (call.result) |result| try Machine.checkedSlot(result) else null,
                .function = call.function,
                .arguments = arguments,
            } };
        },
        .print => |value| .{ .print = .{
            .value = try Machine.checkedSlot(value),
            .kind = switch (function.value_types[value]) {
                .int => .integer,
                .bool => .boolean,
                .str => .string,
                else => return error.UnsupportedType,
            },
        } },
        .assert => |assertion| .{ .assert = .{
            .condition = try Machine.checkedSlot(assertion.condition),
            .message = try Machine.checkedSlot(assertion.message),
            .header = try internString(allocator, strings, try runtimeHeader(allocator, program, assertion.position, true)),
        } },
        .panic => |panic_value| .{ .panic = .{
            .message = try Machine.checkedSlot(panic_value.message),
            .header = try internString(allocator, strings, try runtimeHeader(allocator, program, panic_value.position, false)),
        } },
        .return_value => |value| .{ .return_value = try Machine.checkedSlot(value) },
        .return_void => .return_void,
    };
}

fn requireExecutableReturnType(type_value: Ir.Type) Machine.Error!void {
    switch (type_value) {
        .void, .int, .bool, .str => {},
        .float32 => return error.UnsupportedType,
    }
}

fn requireExecutableValueType(type_value: Ir.Type) Machine.Error!void {
    switch (type_value) {
        .int, .bool, .str => {},
        .void, .float32 => return error.UnsupportedType,
    }
}

fn internString(
    allocator: Allocator,
    strings: *std.ArrayList([]const u8),
    value: []const u8,
) Allocator.Error!usize {
    for (strings.items, 0..) |existing, index| {
        if (std.mem.eql(u8, existing, value)) return index;
    }
    const index = strings.items.len;
    try strings.append(allocator, value);
    return index;
}

fn runtimeHeader(
    allocator: Allocator,
    program: Ir.Program,
    position: @import("../Source.zig").Position,
    assertion: bool,
) Allocator.Error![]const u8 {
    const path = if (position.file < program.files.len) program.files[position.file] else "<source>";
    return if (assertion)
        std.fmt.allocPrint(
            allocator,
            "{s}:{d}:{d}: runtime error: assertion failed: ",
            .{ path, position.line, position.column },
        )
    else
        std.fmt.allocPrint(
            allocator,
            "{s}:{d}:{d}: runtime error: ",
            .{ path, position.line, position.column },
        );
}

fn compile(allocator: Allocator, source: []const u8) !Machine.Program {
    var frontend = @import("../Frontend.zig").Frontend.init(allocator);
    return lower(allocator, (try frontend.compile(source)).ir);
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
    try std.testing.expectEqual(@as(u4, 2), program.functions[0].parameter_count);
    try std.testing.expectEqual(@as(u12, 3), program.functions[0].slot_count);
    try std.testing.expectEqual(@as(u16, 32), program.functions[0].frame_size);
    try std.testing.expectEqual(Machine.BinaryOperator.add, program.functions[0].instructions[0].binary.operator);
    try std.testing.expectEqual(@as(Machine.Slot, 0), program.functions[0].instructions[0].binary.left);
    try std.testing.expectEqual(@as(Machine.FunctionId, 0), program.functions[1].instructions[2].call.function);
    try std.testing.expectEqual(@as(Machine.Slot, 2), program.functions[1].instructions[2].call.result.?);
    try std.testing.expectEqual(@as(Machine.FunctionId, 1), program.functions[2].instructions[0].call.function);
}

test "reject target limits before encoding" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("../Frontend.zig").Frontend.init(allocator);
    const compilation = try frontend.compile(
        "func many(a:int,b:int,c:int,d:int,e:int,f:int,g:int,h:int,i:int) int { return a } func main() {}",
    );
    try std.testing.expectError(error.TooManyArguments, lower(allocator, compilation.ir));

    const functions = [_]Ir.Function{.{
        .name = "floating",
        .parameter_types = &.{.float32},
        .return_type = .void,
        .value_types = &.{.float32},
        .instructions = &.{.return_void},
    }};
    try std.testing.expectError(error.UnsupportedType, lower(allocator, .{ .functions = &functions }));
}
