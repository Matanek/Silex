const std = @import("std");
const Types = @import("Types.zig");
const Source = @import("Source.zig");
const Strings = @import("Strings.zig");

const Allocator = std.mem.Allocator;

pub const Type = Types.Type;
pub const FunctionId = usize;
pub const ValueId = usize;
pub const Error = Allocator.Error || error{InvalidProgram};

pub const UnaryOperator = enum {
    negate,

    fn name(self: UnaryOperator) []const u8 {
        return switch (self) {
            .negate => "neg",
        };
    }
};

pub const BinaryOperator = enum {
    add,
    subtract,
    multiply,
    divide,
    remainder,
    less,
    less_equal,
    greater,
    greater_equal,
    equal,
    not_equal,

    fn name(self: BinaryOperator) []const u8 {
        return switch (self) {
            .add => "add",
            .subtract => "sub",
            .multiply => "mul",
            .divide => "div",
            .remainder => "rem",
            .less => "lt",
            .less_equal => "le",
            .greater => "gt",
            .greater_equal => "ge",
            .equal => "eq",
            .not_equal => "ne",
        };
    }
};

pub const Instruction = union(enum) {
    constant_int: ConstantInt,
    constant_bool: ConstantBool,
    constant_str: ConstantStr,
    unary: Unary,
    binary: Binary,
    call: Call,
    print: ValueId,
    assert: Assert,
    panic: Panic,
    return_value: ValueId,
    return_void,

    pub const ConstantInt = struct {
        result: ValueId,
        value: i64,
    };

    pub const ConstantBool = struct {
        result: ValueId,
        value: bool,
    };

    pub const ConstantStr = struct {
        result: ValueId,
        value: []const u8,
    };

    pub const Unary = struct {
        result: ValueId,
        operator: UnaryOperator,
        operand: ValueId,
    };

    pub const Binary = struct {
        result: ValueId,
        operator: BinaryOperator,
        left: ValueId,
        right: ValueId,
    };

    pub const Call = struct {
        result: ?ValueId,
        function: FunctionId,
        arguments: []const ValueId,
    };

    pub const Assert = struct {
        condition: ValueId,
        message: ValueId,
        position: Source.Position,
    };

    pub const Panic = struct {
        message: ValueId,
        position: Source.Position,
    };
};

pub const Function = struct {
    name: []const u8,
    parameter_types: []const Type,
    return_type: Type,
    value_types: []const Type,
    instructions: []const Instruction,
};

pub const Program = struct {
    functions: []const Function,
    files: []const []const u8 = &.{"<source>"},
};

pub fn writeText(allocator: Allocator, program: Program) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    for (program.functions, 0..) |function, function_index| {
        if (function_index != 0) try output.append(allocator, '\n');
        try output.appendSlice(allocator, "func @");
        try output.appendSlice(allocator, function.name);
        try output.append(allocator, '(');
        for (function.parameter_types, 0..) |parameter_type, index| {
            if (index != 0) try output.appendSlice(allocator, ", ");
            try appendValue(&output, allocator, index);
            try output.append(allocator, ':');
            try output.appendSlice(allocator, parameter_type.name());
        }
        try output.appendSlice(allocator, ") -> ");
        try output.appendSlice(allocator, function.return_type.name());
        try output.appendSlice(allocator, " {\nentry:\n");
        for (function.instructions) |instruction| {
            try output.appendSlice(allocator, "    ");
            try writeInstruction(&output, allocator, program, function, instruction);
            try output.append(allocator, '\n');
        }
        try output.appendSlice(allocator, "}\n");
    }
    return output.toOwnedSlice(allocator);
}

fn writeInstruction(
    output: *std.ArrayList(u8),
    allocator: Allocator,
    program: Program,
    function: Function,
    instruction: Instruction,
) Error!void {
    switch (instruction) {
        .constant_int => |constant| {
            try appendResult(output, allocator, function, constant.result);
            try output.appendSlice(allocator, "const ");
            try appendInt(output, allocator, constant.value);
        },
        .constant_bool => |constant| {
            try appendResult(output, allocator, function, constant.result);
            try output.appendSlice(allocator, if (constant.value) "const true" else "const false");
        },
        .constant_str => |constant| {
            try appendResult(output, allocator, function, constant.result);
            try output.appendSlice(allocator, "const ");
            try Strings.appendQuoted(output, allocator, constant.value);
        },
        .unary => |unary| {
            try appendResult(output, allocator, function, unary.result);
            try output.appendSlice(allocator, unary.operator.name());
            try output.append(allocator, ' ');
            try appendValueChecked(output, allocator, function, unary.operand);
        },
        .binary => |binary| {
            try appendResult(output, allocator, function, binary.result);
            try output.appendSlice(allocator, binary.operator.name());
            try output.append(allocator, ' ');
            try appendValueChecked(output, allocator, function, binary.left);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, binary.right);
        },
        .call => |call| {
            if (call.function >= program.functions.len) return error.InvalidProgram;
            if (call.result) |result| try appendResult(output, allocator, function, result);
            try output.appendSlice(allocator, "call @");
            try output.appendSlice(allocator, program.functions[call.function].name);
            try output.append(allocator, '(');
            for (call.arguments, 0..) |argument, index| {
                if (index != 0) try output.appendSlice(allocator, ", ");
                try appendValueChecked(output, allocator, function, argument);
            }
            try output.append(allocator, ')');
        },
        .print => |value| {
            try output.appendSlice(allocator, "print ");
            try appendValueChecked(output, allocator, function, value);
        },
        .assert => |assertion| {
            try output.appendSlice(allocator, "assert ");
            try appendValueChecked(output, allocator, function, assertion.condition);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, assertion.message);
        },
        .panic => |panic_value| {
            try output.appendSlice(allocator, "panic ");
            try appendValueChecked(output, allocator, function, panic_value.message);
        },
        .return_value => |value| {
            try output.appendSlice(allocator, "return ");
            try appendValueChecked(output, allocator, function, value);
        },
        .return_void => try output.appendSlice(allocator, "return"),
    }
}

fn appendResult(output: *std.ArrayList(u8), allocator: Allocator, function: Function, result: ValueId) Error!void {
    if (result >= function.value_types.len) return error.InvalidProgram;
    try appendValue(output, allocator, result);
    try output.append(allocator, ':');
    try output.appendSlice(allocator, function.value_types[result].name());
    try output.appendSlice(allocator, " = ");
}

fn appendValueChecked(output: *std.ArrayList(u8), allocator: Allocator, function: Function, value: ValueId) Error!void {
    if (value >= function.value_types.len) return error.InvalidProgram;
    try appendValue(output, allocator, value);
}

fn appendValue(output: *std.ArrayList(u8), allocator: Allocator, value: ValueId) Allocator.Error!void {
    var buffer: [32]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "%{d}", .{value}) catch unreachable;
    try output.appendSlice(allocator, text);
}

fn appendInt(output: *std.ArrayList(u8), allocator: Allocator, value: i64) Allocator.Error!void {
    var buffer: [32]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch unreachable;
    try output.appendSlice(allocator, text);
}

test "write deterministic typed IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const answer_value_types = [_]Type{ .int, .int, .int };
    const answer_instructions = [_]Instruction{
        .{ .constant_int = .{ .result = 0, .value = 40 } },
        .{ .constant_int = .{ .result = 1, .value = 2 } },
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
        .{ .return_value = 2 },
    };
    const main_value_types = [_]Type{.int};
    const main_instructions = [_]Instruction{
        .{ .call = .{ .result = 0, .function = 0, .arguments = &.{} } },
        .return_void,
    };
    const functions = [_]Function{
        .{
            .name = "answer",
            .parameter_types = &.{},
            .return_type = .int,
            .value_types = &answer_value_types,
            .instructions = &answer_instructions,
        },
        .{
            .name = "main",
            .parameter_types = &.{},
            .return_type = .void,
            .value_types = &main_value_types,
            .instructions = &main_instructions,
        },
    };
    const text = try writeText(arena.allocator(), .{ .functions = &functions });
    try std.testing.expectEqualStrings(
        \\func @answer() -> int {
        \\entry:
        \\    %0:int = const 40
        \\    %1:int = const 2
        \\    %2:int = add %0, %1
        \\    return %2
        \\}
        \\
        \\func @main() -> void {
        \\entry:
        \\    %0:int = call @answer()
        \\    return
        \\}
        \\
    , text);
}
