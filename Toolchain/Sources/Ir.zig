const std = @import("std");
const Types = @import("Types.zig");
const Source = @import("Source.zig");
const Strings = @import("Strings.zig");

const Allocator = std.mem.Allocator;

pub const Type = Types.Type;
pub const FunctionId = usize;
pub const ValueId = usize;
pub const LocalId = usize;
pub const BlockId = usize;
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
    bit_and,
    bit_xor,
    shift_left,
    shift_right,

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
            .bit_and => "and",
            .bit_xor => "xor",
            .shift_left => "shl",
            .shift_right => "shr",
        };
    }
};

pub const Instruction = union(enum) {
    constant_int: ConstantInt,
    constant_bool: ConstantBool,
    constant_str: ConstantStr,
    constant_float32: ConstantFloat32,
    constant_float64: ConstantFloat64,
    copy: Copy,
    structure_init: StructureInit,
    field_load: FieldLoad,
    local_load: LocalLoad,
    local_store: LocalStore,
    convert: Convert,
    format_value: FormatValue,
    string_concat: StringConcat,
    string_count: StringCount,
    unary: Unary,
    binary: Binary,
    call: Call,
    print: Print,
    assert: Assert,

    pub const ConstantInt = struct {
        result: ValueId,
        bits: u64,
    };

    pub const ConstantBool = struct {
        result: ValueId,
        value: bool,
    };

    pub const ConstantStr = struct {
        result: ValueId,
        value: []const u8,
    };

    pub const ConstantFloat32 = struct {
        result: ValueId,
        bits: u32,
    };

    pub const ConstantFloat64 = struct {
        result: ValueId,
        bits: u64,
    };

    pub const Copy = struct {
        result: ValueId,
        operand: ValueId,
    };

    pub const StructureInit = struct {
        result: ValueId,
        structure: usize,
        fields: []const ValueId,
    };

    pub const FieldLoad = struct {
        result: ValueId,
        base: ValueId,
        field: usize,
    };

    pub const LocalLoad = struct {
        result: ValueId,
        local: LocalId,
    };

    pub const LocalStore = struct {
        local: LocalId,
        operand: ValueId,
    };

    pub const Convert = struct {
        result: ValueId,
        operand: ValueId,
        source: Type,
        target: Type,
        position: Source.Position,
        checked: bool,
    };

    pub const FormatValue = struct {
        result: ValueId,
        operand: ValueId,
    };

    pub const StringConcat = struct {
        result: ValueId,
        left: ValueId,
        right: ValueId,
    };

    pub const StringCount = struct {
        result: ValueId,
        operand: ValueId,
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

    pub const Print = struct {
        value: ValueId,
        newline: bool,
    };

    pub const Panic = struct {
        message: ValueId,
        position: Source.Position,
    };
};

pub const Terminator = union(enum) {
    jump: BlockId,
    branch: Branch,
    return_value: ValueId,
    return_void,
    panic: Instruction.Panic,

    pub const Branch = struct {
        condition: ValueId,
        then_block: BlockId,
        else_block: BlockId,
    };
};

pub const Block = struct {
    instructions: []const Instruction,
    terminator: Terminator,
};

pub const Function = struct {
    name: []const u8,
    parameter_types: []const Type,
    return_type: Type,
    value_types: []const Type,
    local_types: []const Type = &.{},
    blocks: []const Block,
};

pub const StructureField = struct {
    name: []const u8,
    type: Type,
    mutable: bool,
};

pub const Structure = struct {
    name: []const u8,
    fields: []const StructureField,
};

pub const Program = struct {
    structures: []const Structure = &.{},
    functions: []const Function,
    files: []const []const u8 = &.{"<source>"},
};

pub fn writeText(allocator: Allocator, program: Program) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    for (program.structures, 0..) |structure, structure_index| {
        if (structure_index != 0) try output.append(allocator, '\n');
        try output.appendSlice(allocator, "struct @");
        try output.appendSlice(allocator, structure.name);
        try output.appendSlice(allocator, " {\n");
        for (structure.fields) |field| {
            try output.appendSlice(allocator, if (field.mutable) "    var ." else "    let .");
            try output.appendSlice(allocator, field.name);
            try output.append(allocator, ':');
            try appendType(&output, allocator, program, field.type);
            try output.append(allocator, '\n');
        }
        try output.appendSlice(allocator, "}\n");
    }
    for (program.functions, 0..) |function, function_index| {
        if (function_index != 0 or program.structures.len != 0) try output.append(allocator, '\n');
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
        try output.appendSlice(allocator, " {\n");
        for (function.blocks, 0..) |block, block_id| {
            try appendBlockName(&output, allocator, block_id);
            try output.appendSlice(allocator, ":\n");
            for (block.instructions) |instruction| {
                try output.appendSlice(allocator, "    ");
                try writeInstruction(&output, allocator, program, function, instruction);
                try output.append(allocator, '\n');
            }
            try output.appendSlice(allocator, "    ");
            try writeTerminator(&output, allocator, function, block.terminator, function.blocks.len);
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
            try appendInteger(output, allocator, constant.bits, function.value_types[constant.result]);
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
        .constant_float32 => |constant| {
            try appendResult(output, allocator, function, constant.result);
            try output.appendSlice(allocator, "const ");
            try appendFloat(output, allocator, @as(f64, @floatCast(@as(f32, @bitCast(constant.bits)))));
        },
        .constant_float64 => |constant| {
            try appendResult(output, allocator, function, constant.result);
            try output.appendSlice(allocator, "const ");
            try appendFloat(output, allocator, @as(f64, @bitCast(constant.bits)));
        },
        .copy => |copy| {
            try appendResult(output, allocator, function, copy.result);
            try output.appendSlice(allocator, "copy ");
            try appendValueChecked(output, allocator, function, copy.operand);
        },
        .structure_init => |initialization| {
            if (initialization.structure >= program.structures.len or
                initialization.fields.len != program.structures[initialization.structure].fields.len or
                initialization.result >= function.value_types.len or
                function.value_types[initialization.result] != Type.structure(initialization.structure))
            {
                return error.InvalidProgram;
            }
            try appendResult(output, allocator, function, initialization.result);
            try output.appendSlice(allocator, "struct.init @");
            try output.appendSlice(allocator, program.structures[initialization.structure].name);
            try output.append(allocator, '(');
            for (initialization.fields, 0..) |field, index| {
                if (field >= function.value_types.len or
                    function.value_types[field] != program.structures[initialization.structure].fields[index].type)
                {
                    return error.InvalidProgram;
                }
                if (index != 0) try output.appendSlice(allocator, ", ");
                try output.appendSlice(allocator, ".");
                try output.appendSlice(allocator, program.structures[initialization.structure].fields[index].name);
                try output.appendSlice(allocator, "=");
                try appendValueChecked(output, allocator, function, field);
            }
            try output.append(allocator, ')');
        },
        .field_load => |load| {
            if (load.base >= function.value_types.len) return error.InvalidProgram;
            const structure_index = function.value_types[load.base].structureIndex() orelse return error.InvalidProgram;
            if (structure_index >= program.structures.len or load.field >= program.structures[structure_index].fields.len) {
                return error.InvalidProgram;
            }
            if (load.result >= function.value_types.len or
                function.value_types[load.result] != program.structures[structure_index].fields[load.field].type)
            {
                return error.InvalidProgram;
            }
            try appendResult(output, allocator, function, load.result);
            try output.appendSlice(allocator, "field ");
            try appendValueChecked(output, allocator, function, load.base);
            try output.appendSlice(allocator, ", .");
            try output.appendSlice(allocator, program.structures[structure_index].fields[load.field].name);
        },
        .local_load => |load| {
            try appendResult(output, allocator, function, load.result);
            try output.appendSlice(allocator, "load ");
            try appendLocalChecked(output, allocator, function, load.local);
            if (function.local_types[load.local] != function.value_types[load.result]) return error.InvalidProgram;
        },
        .local_store => |store| {
            try output.appendSlice(allocator, "store ");
            try appendLocalChecked(output, allocator, function, store.local);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, store.operand);
            if (function.local_types[store.local] != function.value_types[store.operand]) return error.InvalidProgram;
        },
        .convert => |conversion| {
            try appendResult(output, allocator, function, conversion.result);
            try output.appendSlice(allocator, "convert ");
            try appendValueChecked(output, allocator, function, conversion.operand);
            try output.appendSlice(allocator, " to ");
            try output.appendSlice(allocator, conversion.target.name());
        },
        .format_value => |format| {
            try appendResult(output, allocator, function, format.result);
            try output.appendSlice(allocator, "format ");
            try appendValueChecked(output, allocator, function, format.operand);
        },
        .string_concat => |concat| {
            try appendResult(output, allocator, function, concat.result);
            try output.appendSlice(allocator, "str.concat ");
            try appendValueChecked(output, allocator, function, concat.left);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, concat.right);
        },
        .string_count => |count| {
            try appendResult(output, allocator, function, count.result);
            try output.appendSlice(allocator, "str.count ");
            try appendValueChecked(output, allocator, function, count.operand);
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
        .print => |print_value| {
            try output.appendSlice(allocator, "print ");
            try appendValueChecked(output, allocator, function, print_value.value);
            if (!print_value.newline) try output.appendSlice(allocator, " without-newline");
        },
        .assert => |assertion| {
            try output.appendSlice(allocator, "assert ");
            try appendValueChecked(output, allocator, function, assertion.condition);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, assertion.message);
        },
    }
}

fn appendType(output: *std.ArrayList(u8), allocator: Allocator, program: Program, type_value: Type) Error!void {
    if (type_value.structureIndex()) |index| {
        if (index >= program.structures.len) return error.InvalidProgram;
        try output.append(allocator, '@');
        return output.appendSlice(allocator, program.structures[index].name);
    }
    try output.appendSlice(allocator, type_value.name());
}

fn writeTerminator(
    output: *std.ArrayList(u8),
    allocator: Allocator,
    function: Function,
    terminator: Terminator,
    block_count: usize,
) Error!void {
    switch (terminator) {
        .jump => |target| {
            if (target >= block_count) return error.InvalidProgram;
            try output.appendSlice(allocator, "jump ");
            try appendBlockName(output, allocator, target);
        },
        .branch => |branch| {
            if (branch.then_block >= block_count or branch.else_block >= block_count) return error.InvalidProgram;
            try output.appendSlice(allocator, "branch ");
            try appendValueChecked(output, allocator, function, branch.condition);
            try output.appendSlice(allocator, ", ");
            try appendBlockName(output, allocator, branch.then_block);
            try output.appendSlice(allocator, ", ");
            try appendBlockName(output, allocator, branch.else_block);
        },
        .return_value => |value| {
            try output.appendSlice(allocator, "return ");
            try appendValueChecked(output, allocator, function, value);
        },
        .return_void => try output.appendSlice(allocator, "return"),
        .panic => |panic_value| {
            try output.appendSlice(allocator, "panic ");
            try appendValueChecked(output, allocator, function, panic_value.message);
        },
    }
}

fn appendBlockName(output: *std.ArrayList(u8), allocator: Allocator, block: BlockId) Allocator.Error!void {
    if (block == 0) return output.appendSlice(allocator, "entry");
    var buffer: [32]u8 = undefined;
    const name = std.fmt.bufPrint(&buffer, "bb{d}", .{block}) catch unreachable;
    try output.appendSlice(allocator, name);
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

fn appendLocalChecked(output: *std.ArrayList(u8), allocator: Allocator, function: Function, local: LocalId) Error!void {
    if (local >= function.local_types.len) return error.InvalidProgram;
    try output.append(allocator, '$');
    var buffer: [32]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{d}:{s}", .{ local, function.local_types[local].name() }) catch unreachable;
    try output.appendSlice(allocator, text);
}

fn appendValue(output: *std.ArrayList(u8), allocator: Allocator, value: ValueId) Allocator.Error!void {
    var buffer: [32]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "%{d}", .{value}) catch unreachable;
    try output.appendSlice(allocator, text);
}

fn appendInteger(output: *std.ArrayList(u8), allocator: Allocator, bits: u64, type_value: Type) Allocator.Error!void {
    var buffer: [32]u8 = undefined;
    const text = if (type_value.isSignedInteger())
        std.fmt.bufPrint(&buffer, "{d}", .{@as(i64, @bitCast(@import("Numeric.zig").signExtend(bits, type_value.bitWidth())))}) catch unreachable
    else
        std.fmt.bufPrint(&buffer, "{d}", .{bits}) catch unreachable;
    try output.appendSlice(allocator, text);
}

fn appendFloat(output: *std.ArrayList(u8), allocator: Allocator, value: f64) Allocator.Error!void {
    var buffer: [64]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch unreachable;
    try output.appendSlice(allocator, text);
}

test "write deterministic typed IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const answer_value_types = [_]Type{ .int, .int, .int };
    const answer_instructions = [_]Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 40 } },
        .{ .constant_int = .{ .result = 1, .bits = 2 } },
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
    };
    const main_value_types = [_]Type{.int};
    const main_instructions = [_]Instruction{.{ .call = .{ .result = 0, .function = 0, .arguments = &.{} } }};
    const functions = [_]Function{
        .{
            .name = "answer",
            .parameter_types = &.{},
            .return_type = .int,
            .value_types = &answer_value_types,
            .blocks = &.{.{ .instructions = &answer_instructions, .terminator = .{ .return_value = 2 } }},
        },
        .{
            .name = "main",
            .parameter_types = &.{},
            .return_type = .void,
            .value_types = &main_value_types,
            .blocks = &.{.{ .instructions = &main_instructions, .terminator = .return_void }},
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
