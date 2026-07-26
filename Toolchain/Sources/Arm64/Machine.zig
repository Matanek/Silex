const std = @import("std");
const Types = @import("../Types.zig");

const Allocator = std.mem.Allocator;

pub const max_register_arguments = 8;
pub const max_slots = 4095;
pub const slot_size = 8;

pub const FunctionId = usize;
pub const Slot = u12;
pub const Error = Allocator.Error || error{
    InvalidMachineProgram,
    TooManyArguments,
    FrameTooLarge,
    UnsupportedType,
};

pub const Status = enum(u8) {
    success = 0,
    integer_overflow = 1,
    division_by_zero = 2,
    runtime_failure = 3,
};

pub const UnaryOperator = enum {
    negate,
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
    bit_and,
    bit_xor,
    shift_left,
    shift_right,
};

pub const PrintKind = enum { signed_integer, unsigned_integer, float32, float64, boolean, string };

pub const Instruction = union(enum) {
    constant_int: ConstantInt,
    constant_bool: ConstantBool,
    constant_str: ConstantStr,
    constant_float32: ConstantFloat32,
    constant_float64: ConstantFloat64,
    copy: Copy,
    convert: Convert,
    format_value: FormatValue,
    string_concat: StringConcat,
    string_count: StringCount,
    unary: Unary,
    binary: Binary,
    call: Call,
    print: Print,
    assert: Assert,
    panic: Panic,
    return_value: Slot,
    return_void,
    jump: usize,
    branch: Branch,

    pub const ConstantInt = struct {
        result: Slot,
        bits: u64,
        type: Types.Type = .int,
    };

    pub const ConstantBool = struct {
        result: Slot,
        value: bool,
    };

    pub const ConstantStr = struct {
        result: Slot,
        string: usize,
    };

    pub const ConstantFloat32 = struct {
        result: Slot,
        bits: u32,
    };

    pub const ConstantFloat64 = struct {
        result: Slot,
        bits: u64,
    };

    pub const Copy = struct {
        result: Slot,
        operand: Slot,
    };

    pub const Convert = struct {
        result: Slot,
        operand: Slot,
        source: Types.Type,
        target: Types.Type,
        header: usize,
        checked: bool,
    };

    pub const FormatValue = struct {
        result: Slot,
        operand: Slot,
        kind: PrintKind,
    };

    pub const StringConcat = struct {
        result: Slot,
        left: Slot,
        right: Slot,
    };

    pub const StringCount = struct {
        result: Slot,
        operand: Slot,
    };

    pub const Unary = struct {
        result: Slot,
        operator: UnaryOperator,
        operand: Slot,
        type: Types.Type = .int,
    };

    pub const Binary = struct {
        result: Slot,
        operator: BinaryOperator,
        left: Slot,
        right: Slot,
        type: Types.Type = .int,
    };

    pub const Call = struct {
        result: ?Slot,
        function: FunctionId,
        arguments: []const Slot,
    };

    pub const Print = struct {
        value: Slot,
        kind: PrintKind,
        newline: bool,
    };

    pub const Assert = struct {
        condition: Slot,
        message: Slot,
        header: usize,
    };

    pub const Panic = struct {
        message: Slot,
        header: usize,
    };

    pub const Branch = struct {
        condition: Slot,
        then_instruction: usize,
        else_instruction: usize,
    };
};

pub const Function = struct {
    name: []const u8,
    parameter_count: u4,
    return_type: Types.Type,
    slot_count: u12,
    frame_size: u16,
    instructions: []const Instruction,
};

pub const Program = struct {
    functions: []const Function,
    strings: []const []const u8 = &.{},
};

pub fn checkedSlot(value: usize) Error!Slot {
    if (value > max_slots) return error.FrameTooLarge;
    return @intCast(value);
}

pub fn checkedArgumentCount(value: usize) Error!u4 {
    if (value > max_register_arguments) return error.TooManyArguments;
    return @intCast(value);
}

pub fn frameSize(slots: usize) Error!u16 {
    if (slots > max_slots) return error.FrameTooLarge;
    const bytes = slots * slot_size;
    return @intCast(std.mem.alignForward(usize, bytes, 16));
}

pub fn slotOffset(slot: Slot) u16 {
    return @as(u16, slot) * slot_size;
}

pub fn validate(program: Program) Error!void {
    for (program.functions) |function| {
        if (function.parameter_count > max_register_arguments) return error.TooManyArguments;
        if (function.frame_size != try frameSize(function.slot_count)) return error.InvalidMachineProgram;
        for (function.instructions) |instruction| switch (instruction) {
            .constant_int => |value| try requireSlot(function, value.result),
            .constant_bool => |value| try requireSlot(function, value.result),
            .constant_str => |value| {
                try requireSlot(function, value.result);
                if (value.string >= program.strings.len) return error.InvalidMachineProgram;
            },
            .constant_float32 => |value| try requireSlot(function, value.result),
            .constant_float64 => |value| try requireSlot(function, value.result),
            .copy => |value| {
                try requireSlot(function, value.result);
                try requireSlot(function, value.operand);
            },
            .convert => |value| {
                try requireSlot(function, value.result);
                try requireSlot(function, value.operand);
                if (value.header >= program.strings.len) return error.InvalidMachineProgram;
            },
            .format_value => |value| {
                try requireSlot(function, value.result);
                try requireSlot(function, value.operand);
            },
            .string_concat => |value| {
                try requireSlot(function, value.result);
                try requireSlot(function, value.left);
                try requireSlot(function, value.right);
            },
            .string_count => |value| {
                try requireSlot(function, value.result);
                try requireSlot(function, value.operand);
            },
            .unary => |value| {
                try requireSlot(function, value.result);
                try requireSlot(function, value.operand);
            },
            .binary => |value| {
                try requireSlot(function, value.result);
                try requireSlot(function, value.left);
                try requireSlot(function, value.right);
            },
            .call => |call| {
                if (call.function >= program.functions.len) return error.InvalidMachineProgram;
                if (call.arguments.len > max_register_arguments) return error.TooManyArguments;
                if (call.arguments.len != program.functions[call.function].parameter_count) return error.InvalidMachineProgram;
                if (call.result) |result| try requireSlot(function, result);
                for (call.arguments) |argument| try requireSlot(function, argument);
            },
            .print => |value| try requireSlot(function, value.value),
            .assert => |value| {
                try requireSlot(function, value.condition);
                try requireSlot(function, value.message);
                if (value.header >= program.strings.len) return error.InvalidMachineProgram;
            },
            .panic => |value| {
                try requireSlot(function, value.message);
                if (value.header >= program.strings.len) return error.InvalidMachineProgram;
            },
            .return_value => |value| try requireSlot(function, value),
            .return_void => {},
            .jump => |target| if (target >= function.instructions.len) return error.InvalidMachineProgram,
            .branch => |branch_value| {
                try requireSlot(function, branch_value.condition);
                if (branch_value.then_instruction >= function.instructions.len or
                    branch_value.else_instruction >= function.instructions.len) return error.InvalidMachineProgram;
            },
        };
    }
}

fn requireSlot(function: Function, slot: Slot) Error!void {
    if (slot >= function.slot_count) return error.InvalidMachineProgram;
}

test "allocate deterministic aligned stack homes" {
    try std.testing.expectEqual(@as(u16, 0), slotOffset(0));
    try std.testing.expectEqual(@as(u16, 16), slotOffset(2));
    try std.testing.expectEqual(@as(u16, 0), try frameSize(0));
    try std.testing.expectEqual(@as(u16, 16), try frameSize(1));
    try std.testing.expectEqual(@as(u16, 16), try frameSize(2));
    try std.testing.expectEqual(@as(u16, 32), try frameSize(3));
}

test "validate function identities calls and slots" {
    const arguments = [_]Slot{ 0, 1 };
    const add_instructions = [_]Instruction{
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
        .{ .return_value = 2 },
    };
    const main_instructions = [_]Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 40, .type = .int } },
        .{ .constant_int = .{ .result = 1, .bits = 2, .type = .int } },
        .{ .call = .{ .result = 2, .function = 0, .arguments = &arguments } },
        .return_void,
    };
    const functions = [_]Function{
        .{
            .name = "add",
            .parameter_count = 2,
            .return_type = .int,
            .slot_count = 3,
            .frame_size = try frameSize(3),
            .instructions = &add_instructions,
        },
        .{
            .name = "main",
            .parameter_count = 0,
            .return_type = .void,
            .slot_count = 3,
            .frame_size = try frameSize(3),
            .instructions = &main_instructions,
        },
    };
    try validate(.{ .functions = &functions });
}

test "reject unsupported frame and argument counts" {
    try std.testing.expectError(error.TooManyArguments, checkedArgumentCount(9));
    try std.testing.expectError(error.FrameTooLarge, checkedSlot(max_slots + 1));
}
