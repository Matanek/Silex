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
    const starts = try allocator.alloc(usize, function.blocks.len);
    var next_instruction: usize = 0;
    for (function.blocks, 0..) |block, block_id| {
        starts[block_id] = next_instruction;
        next_instruction += block.instructions.len + 1;
    }
    for (function.blocks) |block| {
        for (block.instructions) |instruction| {
            try instructions.append(allocator, try lowerInstruction(allocator, program, strings, function, instruction));
        }
        try instructions.append(allocator, try lowerTerminator(allocator, program, strings, block.terminator, starts));
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
            .bits = constant.bits,
            .type = function.value_types[constant.result],
        } },
        .constant_bool => |constant| .{ .constant_bool = .{
            .result = try Machine.checkedSlot(constant.result),
            .value = constant.value,
        } },
        .constant_str => |constant| .{ .constant_str = .{
            .result = try Machine.checkedSlot(constant.result),
            .string = try internString(allocator, strings, constant.value),
        } },
        .constant_float32 => |constant| .{ .constant_float32 = .{
            .result = try Machine.checkedSlot(constant.result),
            .bits = constant.bits,
        } },
        .constant_float64 => |constant| .{ .constant_float64 = .{
            .result = try Machine.checkedSlot(constant.result),
            .bits = constant.bits,
        } },
        .copy => |copy| .{ .copy = .{
            .result = try Machine.checkedSlot(copy.result),
            .operand = try Machine.checkedSlot(copy.operand),
        } },
        .convert => |conversion| .{ .convert = .{
            .result = try Machine.checkedSlot(conversion.result),
            .operand = try Machine.checkedSlot(conversion.operand),
            .source = conversion.source,
            .target = conversion.target,
            .checked = conversion.checked,
            .header = try internString(
                allocator,
                strings,
                try runtimeConversionHeader(allocator, program, conversion.position),
            ),
        } },
        .format_value => |format| .{ .format_value = .{
            .result = try Machine.checkedSlot(format.result),
            .operand = try Machine.checkedSlot(format.operand),
            .kind = try printKind(function.value_types[format.operand]),
        } },
        .string_concat => |concat| .{ .string_concat = .{
            .result = try Machine.checkedSlot(concat.result),
            .left = try Machine.checkedSlot(concat.left),
            .right = try Machine.checkedSlot(concat.right),
        } },
        .string_count => |count| .{ .string_count = .{
            .result = try Machine.checkedSlot(count.result),
            .operand = try Machine.checkedSlot(count.operand),
        } },
        .unary => |unary| .{ .unary = .{
            .result = try Machine.checkedSlot(unary.result),
            .operator = switch (unary.operator) {
                .negate => .negate,
            },
            .operand = try Machine.checkedSlot(unary.operand),
            .type = function.value_types[unary.result],
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
                .bit_and => .bit_and,
                .bit_xor => .bit_xor,
                .shift_left => .shift_left,
                .shift_right => .shift_right,
            },
            .left = try Machine.checkedSlot(binary.left),
            .right = try Machine.checkedSlot(binary.right),
            .type = function.value_types[binary.left],
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
            .value = try Machine.checkedSlot(value.value),
            .kind = try printKind(function.value_types[value.value]),
            .newline = value.newline,
        } },
        .assert => |assertion| .{ .assert = .{
            .condition = try Machine.checkedSlot(assertion.condition),
            .message = try Machine.checkedSlot(assertion.message),
            .header = try internString(allocator, strings, try runtimeHeader(allocator, program, assertion.position, true)),
        } },
    };
}

fn printKind(type_value: Ir.Type) Machine.Error!Machine.PrintKind {
    return switch (type_value) {
        .int8, .int16, .int32, .int => .signed_integer,
        .uint8, .uint16, .uint32, .uint => .unsigned_integer,
        .float32 => .float32,
        .float64 => .float64,
        .bool => .boolean,
        .str => .string,
        else => error.UnsupportedType,
    };
}

fn lowerTerminator(
    allocator: Allocator,
    program: Ir.Program,
    strings: *std.ArrayList([]const u8),
    terminator: Ir.Terminator,
    starts: []const usize,
) Machine.Error!Machine.Instruction {
    return switch (terminator) {
        .jump => |target| .{ .jump = starts[target] },
        .branch => |branch| .{ .branch = .{
            .condition = try Machine.checkedSlot(branch.condition),
            .then_instruction = starts[branch.then_block],
            .else_instruction = starts[branch.else_block],
        } },
        .return_value => |value| .{ .return_value = try Machine.checkedSlot(value) },
        .return_void => .return_void,
        .panic => |panic_value| .{ .panic = .{
            .message = try Machine.checkedSlot(panic_value.message),
            .header = try internString(allocator, strings, try runtimeHeader(allocator, program, panic_value.position, false)),
        } },
    };
}

fn requireExecutableReturnType(type_value: Ir.Type) Machine.Error!void {
    switch (type_value) {
        .void, .int8, .int16, .int32, .int, .uint8, .uint16, .uint32, .uint, .float32, .float64, .bool, .str => {},
    }
}

fn requireExecutableValueType(type_value: Ir.Type) Machine.Error!void {
    switch (type_value) {
        .int8, .int16, .int32, .int, .uint8, .uint16, .uint32, .uint, .float32, .float64, .bool, .str => {},
        .void => return error.UnsupportedType,
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

fn runtimeConversionHeader(
    allocator: Allocator,
    program: Ir.Program,
    position: @import("../Source.zig").Position,
) Allocator.Error![]const u8 {
    const path = if (position.file < program.files.len) program.files[position.file] else "<source>";
    return std.fmt.allocPrint(
        allocator,
        "{s}:{d}:{d}: runtime error: invalid numeric conversion\n",
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
        .blocks = &.{.{ .instructions = &.{}, .terminator = .return_void }},
    }};
    _ = try lower(allocator, .{ .functions = &functions });
}
