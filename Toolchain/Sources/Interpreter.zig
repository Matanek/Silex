const std = @import("std");
const Ir = @import("Ir.zig");
const Numeric = @import("Numeric.zig");

const Allocator = std.mem.Allocator;
const max_call_depth = 1024;

pub const Error = Allocator.Error || error{
    InvalidProgram,
    IntegerOverflow,
    DivisionByZero,
    CallStackOverflow,
    RuntimeTerminated,
    InvalidConversion,
    InvalidShift,
};

pub const Value = union(enum) {
    void,
    integer: i64,
    typed_integer: Numeric.Integer,
    float32: f32,
    float64: f64,
    boolean: bool,
    string: []const u8,
    structure: Structure,

    pub const Structure = struct {
        type: Ir.Type,
        fields: []const Value,
    };

    pub fn typeOf(self: Value) Ir.Type {
        return switch (self) {
            .void => .void,
            .integer => .int,
            .typed_integer => |value| value.type,
            .float32 => .float32,
            .float64 => .float64,
            .boolean => .bool,
            .string => .str,
            .structure => |value| value.type,
        };
    }
};

pub const RunResult = struct {
    exit_code: u8,
    stdout: []const u8,
    stderr: []const u8,
};

const Session = struct {
    allocator: Allocator,
    stdout: std.ArrayList(u8) = .empty,
    stderr: std.ArrayList(u8) = .empty,
    terminated: bool = false,
};

pub fn run(allocator: Allocator, program: Ir.Program) Error!u8 {
    return (try runCapture(allocator, program)).exit_code;
}

pub fn runCapture(allocator: Allocator, program: Ir.Program) Error!RunResult {
    var main: ?Ir.FunctionId = null;
    for (program.functions, 0..) |function, function_id| {
        if (!std.mem.eql(u8, function.name, "main")) continue;
        if (main != null) return error.InvalidProgram;
        main = function_id;
    }
    const function_id = main orelse return error.InvalidProgram;
    const function = program.functions[function_id];
    if (function.parameter_types.len != 0 or function.return_type != .void) return error.InvalidProgram;
    var session: Session = .{ .allocator = allocator };
    const result = invokeDepth(allocator, program, function_id, &.{}, 0, &session) catch |err| switch (err) {
        error.RuntimeTerminated => return .{
            .exit_code = 1,
            .stdout = try session.stdout.toOwnedSlice(allocator),
            .stderr = try session.stderr.toOwnedSlice(allocator),
        },
        else => |other| return other,
    };
    if (result != .void) return error.InvalidProgram;
    return .{
        .exit_code = 0,
        .stdout = try session.stdout.toOwnedSlice(allocator),
        .stderr = try session.stderr.toOwnedSlice(allocator),
    };
}

pub fn invoke(
    allocator: Allocator,
    program: Ir.Program,
    function: Ir.FunctionId,
    arguments: []const Value,
) Error!Value {
    var session: Session = .{ .allocator = allocator };
    return invokeDepth(allocator, program, function, arguments, 0, &session);
}

fn invokeDepth(
    allocator: Allocator,
    program: Ir.Program,
    function_id: Ir.FunctionId,
    arguments: []const Value,
    depth: usize,
    session: *Session,
) Error!Value {
    if (depth >= max_call_depth) return error.CallStackOverflow;
    if (function_id >= program.functions.len) return error.InvalidProgram;
    const function = program.functions[function_id];
    if (arguments.len != function.parameter_types.len or function.parameter_types.len > function.value_types.len) {
        return error.InvalidProgram;
    }

    const values = try allocator.alloc(?Value, function.value_types.len);
    defer allocator.free(values);
    @memset(values, null);
    const locals = try allocator.alloc(?Value, function.local_types.len);
    defer allocator.free(locals);
    @memset(locals, null);
    for (arguments, function.parameter_types, 0..) |argument, parameter_type, index| {
        if (argument.typeOf() != parameter_type) return error.InvalidProgram;
        values[index] = try cloneValue(allocator, argument);
    }

    var block_id: Ir.BlockId = 0;
    while (true) {
        if (block_id >= function.blocks.len) return error.InvalidProgram;
        const block = function.blocks[block_id];
        for (block.instructions) |instruction| {
            if (try executeInstruction(allocator, program, function, values, locals, instruction, depth, session)) |result| return result;
        }
        switch (block.terminator) {
            .jump => |target| block_id = target,
            .branch => |branch| block_id = if (try boolean(try load(values, branch.condition))) branch.then_block else branch.else_block,
            .return_value => |value_id| {
                const result = try load(values, value_id);
                if (result.typeOf() != function.return_type or function.return_type == .void) return error.InvalidProgram;
                return cloneValue(allocator, result);
            },
            .return_void => {
                if (function.return_type != .void) return error.InvalidProgram;
                return .void;
            },
            .panic => |panic_value| {
                const message = try string(try load(values, panic_value.message));
                try appendRuntimeError(session, program, panic_value.position, "", message);
                session.terminated = true;
                return error.RuntimeTerminated;
            },
        }
    }
}

fn executeInstruction(
    allocator: Allocator,
    program: Ir.Program,
    function: Ir.Function,
    values: []?Value,
    locals: []?Value,
    instruction: Ir.Instruction,
    depth: usize,
    session: *Session,
) Error!?Value {
    switch (instruction) {
        .constant_int => |constant| {
            const type_value = function.value_types[constant.result];
            const value: Value = if (type_value == .int)
                .{ .integer = @bitCast(constant.bits) }
            else
                .{ .typed_integer = .{ .type = type_value, .bits = constant.bits } };
            try store(function, values, constant.result, value);
        },
        .constant_bool => |constant| try store(function, values, constant.result, .{ .boolean = constant.value }),
        .constant_str => |constant| try store(function, values, constant.result, .{ .string = constant.value }),
        .constant_float32 => |constant| try store(function, values, constant.result, .{ .float32 = @bitCast(constant.bits) }),
        .constant_float64 => |constant| try store(function, values, constant.result, .{ .float64 = @bitCast(constant.bits) }),
        .copy => |copy| try store(function, values, copy.result, try cloneValue(allocator, try load(values, copy.operand))),
        .structure_init => |initialization| {
            if (initialization.structure >= program.structures.len or
                initialization.fields.len != program.structures[initialization.structure].fields.len)
            {
                return error.InvalidProgram;
            }
            const fields = try allocator.alloc(Value, initialization.fields.len);
            for (initialization.fields, 0..) |field, index| {
                fields[index] = try cloneValue(allocator, try load(values, field));
                if (fields[index].typeOf() != program.structures[initialization.structure].fields[index].type) {
                    return error.InvalidProgram;
                }
            }
            try store(function, values, initialization.result, .{ .structure = .{
                .type = .structure(initialization.structure),
                .fields = fields,
            } });
        },
        .field_load => |field| {
            const aggregate = switch (try load(values, field.base)) {
                .structure => |value| value,
                else => return error.InvalidProgram,
            };
            if (field.field >= aggregate.fields.len) return error.InvalidProgram;
            try store(function, values, field.result, try cloneValue(allocator, aggregate.fields[field.field]));
        },
        .local_load => |local| {
            const value = try cloneValue(allocator, try loadLocal(function, locals, local.local));
            try store(function, values, local.result, value);
        },
        .local_store => |local| try storeLocal(
            function,
            locals,
            local.local,
            try cloneValue(allocator, try load(values, local.operand)),
        ),
        .convert => |conversion| {
            const operand = try load(values, conversion.operand);
            const converted = convert(operand, conversion.target, conversion.checked) catch |err| switch (err) {
                error.InvalidConversion => {
                    try appendRuntimeError(session, program, conversion.position, "", "invalid numeric conversion");
                    session.terminated = true;
                    return error.RuntimeTerminated;
                },
                else => |other| return other,
            };
            try store(function, values, conversion.result, converted);
        },
        .format_value => |format| {
            var text: std.ArrayList(u8) = .empty;
            try appendValueText(&text, allocator, try load(values, format.operand));
            try store(function, values, format.result, .{ .string = try text.toOwnedSlice(allocator) });
        },
        .string_concat => |concat| {
            const left = try string(try load(values, concat.left));
            const right = try string(try load(values, concat.right));
            const result = try allocator.alloc(u8, left.len + right.len);
            @memcpy(result[0..left.len], left);
            @memcpy(result[left.len..], right);
            try store(function, values, concat.result, .{ .string = result });
        },
        .string_count => |count| {
            const value = try string(try load(values, count.operand));
            const scalar_count = std.unicode.utf8CountCodepoints(value) catch return error.InvalidProgram;
            try store(function, values, count.result, .{ .integer = @intCast(scalar_count) });
        },
        .unary => |unary| {
            const operand = try load(values, unary.operand);
            const result = try negateValue(operand);
            try store(function, values, unary.result, result);
        },
        .binary => |binary| {
            const left = try load(values, binary.left);
            const right = try load(values, binary.right);
            const result = try calculate(binary.operator, left, right, function.value_types[binary.result]);
            try store(function, values, binary.result, result);
        },
        .call => |call| {
            if (call.function >= program.functions.len) return error.InvalidProgram;
            const callee = program.functions[call.function];
            if (call.arguments.len != callee.parameter_types.len) return error.InvalidProgram;
            const call_arguments = try allocator.alloc(Value, call.arguments.len);
            defer allocator.free(call_arguments);
            for (call.arguments, 0..) |argument, index| call_arguments[index] = try load(values, argument);
            const result = try invokeDepth(allocator, program, call.function, call_arguments, depth + 1, session);
            if (call.result) |result_id| {
                if (callee.return_type == .void or result == .void) return error.InvalidProgram;
                try store(function, values, result_id, result);
            } else if (callee.return_type != .void or result != .void) {
                return error.InvalidProgram;
            }
        },
        .print => |print_value| {
            try appendValueText(&session.stdout, session.allocator, try load(values, print_value.value));
            if (print_value.newline) try session.stdout.append(session.allocator, '\n');
        },
        .assert => |assertion| {
            const condition = try boolean(try load(values, assertion.condition));
            if (!condition) {
                const message = try string(try load(values, assertion.message));
                try appendRuntimeError(session, program, assertion.position, "assertion failed: ", message);
                session.terminated = true;
                return error.RuntimeTerminated;
            }
        },
    }
    return null;
}

fn store(function: Ir.Function, values: []?Value, id: Ir.ValueId, value: Value) Error!void {
    if (id >= values.len or function.value_types[id] != value.typeOf()) return error.InvalidProgram;
    values[id] = value;
}

fn load(values: []const ?Value, id: Ir.ValueId) Error!Value {
    if (id >= values.len) return error.InvalidProgram;
    return values[id] orelse error.InvalidProgram;
}

fn cloneValue(allocator: Allocator, value: Value) Error!Value {
    return switch (value) {
        .structure => |aggregate| cloned: {
            const fields = try allocator.alloc(Value, aggregate.fields.len);
            for (aggregate.fields, 0..) |field, index| fields[index] = try cloneValue(allocator, field);
            break :cloned .{ .structure = .{ .type = aggregate.type, .fields = fields } };
        },
        else => value,
    };
}

fn storeLocal(function: Ir.Function, locals: []?Value, id: Ir.LocalId, value: Value) Error!void {
    if (id >= locals.len or function.local_types[id] != value.typeOf()) return error.InvalidProgram;
    locals[id] = value;
}

fn loadLocal(function: Ir.Function, locals: []const ?Value, id: Ir.LocalId) Error!Value {
    if (id >= locals.len) return error.InvalidProgram;
    const value = locals[id] orelse return error.InvalidProgram;
    if (function.local_types[id] != value.typeOf()) return error.InvalidProgram;
    return value;
}

fn integer(value: Value) Error!i64 {
    return switch (value) {
        .integer => |result| result,
        else => error.InvalidProgram,
    };
}

fn numericInteger(value: Value) Error!Numeric.Integer {
    return switch (value) {
        .integer => |result| .{ .type = .int, .bits = @bitCast(result) },
        .typed_integer => |result| result,
        else => error.InvalidProgram,
    };
}

fn negate(value: i64) Error!i64 {
    if (value == std.math.minInt(i64)) return error.IntegerOverflow;
    return -value;
}

fn negateValue(value: Value) Error!Value {
    const type_value = value.typeOf();
    if (type_value.isFloat()) return switch (value) {
        .float32 => |number| .{ .float32 = -number },
        .float64 => |number| .{ .float64 = -number },
        else => error.InvalidProgram,
    };
    const number = try numericInteger(value);
    if (!number.type.isSignedInteger()) {
        if (number.bits != 0) return error.IntegerOverflow;
        return .{ .typed_integer = number };
    }
    const signed = number.signed();
    if (signed == Numeric.integerMin(number.type)) return error.IntegerOverflow;
    const bits: u64 = @bitCast(-signed);
    return if (number.type == .int) .{ .integer = @bitCast(bits) } else .{
        .typed_integer = .{ .type = number.type, .bits = Numeric.normalize(bits, number.type) },
    };
}

fn calculate(operator: Ir.BinaryOperator, left: Value, right: Value, result_type: Ir.Type) Error!Value {
    if ((operator == .equal or operator == .not_equal) and !left.typeOf().isNumeric()) {
        const result = try equal(left, right);
        return .{ .boolean = if (operator == .equal) result else !result };
    }
    if (left.typeOf().isFloat()) return calculateFloat(operator, left, right, result_type);
    const left_integer = try numericInteger(left);
    const right_integer = try numericInteger(right);
    return switch (operator) {
        .add, .subtract, .multiply, .divide, .remainder => integerArithmetic(operator, left_integer, right_integer),
        .bit_and => integerResult(left_integer.type, left_integer.bits & right_integer.bits),
        .bit_xor => integerResult(left_integer.type, left_integer.bits ^ right_integer.bits),
        .shift_left, .shift_right => shiftInteger(operator, left_integer, right_integer),
        .less => .{ .boolean = integerLess(left_integer, right_integer) },
        .less_equal => .{ .boolean = !integerLess(right_integer, left_integer) },
        .greater => .{ .boolean = integerLess(right_integer, left_integer) },
        .greater_equal => .{ .boolean = !integerLess(left_integer, right_integer) },
        .equal => .{ .boolean = try equal(left, right) },
        .not_equal => .{ .boolean = !try equal(left, right) },
    };
}

fn integerArithmetic(operator: Ir.BinaryOperator, left: Numeric.Integer, right: Numeric.Integer) Error!Value {
    if (left.type != right.type) return error.InvalidProgram;
    if (left.type.isSignedInteger()) {
        const a: i128 = left.signed();
        const b: i128 = right.signed();
        if ((operator == .divide or operator == .remainder) and b == 0) return error.DivisionByZero;
        if ((operator == .divide or operator == .remainder) and
            a == Numeric.integerMin(left.type) and b == -1) return error.IntegerOverflow;
        const result: i128 = switch (operator) {
            .add => a + b,
            .subtract => a - b,
            .multiply => a * b,
            .divide => @divTrunc(a, b),
            .remainder => @rem(a, b),
            else => unreachable,
        };
        if (result < Numeric.integerMin(left.type) or result > Numeric.integerMax(left.type)) return error.IntegerOverflow;
        return integerResult(left.type, @bitCast(@as(i64, @intCast(result))));
    }

    const a: u128 = left.bits;
    const b: u128 = right.bits;
    if ((operator == .divide or operator == .remainder) and b == 0) return error.DivisionByZero;
    if (operator == .subtract and b > a) return error.IntegerOverflow;
    const result: u128 = switch (operator) {
        .add => a + b,
        .subtract => a - b,
        .multiply => a * b,
        .divide => a / b,
        .remainder => a % b,
        else => unreachable,
    };
    if (result > Numeric.integerMax(left.type)) return error.IntegerOverflow;
    return integerResult(left.type, @intCast(result));
}

fn integerResult(type_value: Ir.Type, bits: u64) Value {
    const normalized = Numeric.normalize(bits, type_value);
    return if (type_value == .int)
        .{ .integer = @bitCast(normalized) }
    else
        .{ .typed_integer = .{ .type = type_value, .bits = normalized } };
}

fn integerLess(left: Numeric.Integer, right: Numeric.Integer) bool {
    std.debug.assert(left.type == right.type);
    return if (left.type.isSignedInteger()) left.signed() < right.signed() else left.bits < right.bits;
}

fn shiftInteger(operator: Ir.BinaryOperator, left: Numeric.Integer, right: Numeric.Integer) Error!Value {
    const count: u64 = if (right.type.isSignedInteger()) count: {
        const signed = right.signed();
        if (signed < 0) return error.InvalidShift;
        break :count @intCast(signed);
    } else right.bits;
    if (count >= left.type.bitWidth()) return error.InvalidShift;
    const shifted = if (operator == .shift_left) left.bits << @intCast(count) else left.bits >> @intCast(count);
    return integerResult(left.type, shifted);
}

fn calculateFloat(operator: Ir.BinaryOperator, left: Value, right: Value, result_type: Ir.Type) Error!Value {
    if (left.typeOf() != right.typeOf()) return error.InvalidProgram;
    if (left.typeOf() == .float32) {
        const a = left.float32;
        const b = right.float32;
        return switch (operator) {
            .add => .{ .float32 = a + b },
            .subtract => .{ .float32 = a - b },
            .multiply => .{ .float32 = a * b },
            .divide => .{ .float32 = a / b },
            .less => .{ .boolean = a < b },
            .less_equal => .{ .boolean = a <= b },
            .greater => .{ .boolean = a > b },
            .greater_equal => .{ .boolean = a >= b },
            .equal => .{ .boolean = a == b },
            .not_equal => .{ .boolean = a != b },
            else => error.InvalidProgram,
        };
    }
    _ = result_type;
    const a = left.float64;
    const b = right.float64;
    return switch (operator) {
        .add => .{ .float64 = a + b },
        .subtract => .{ .float64 = a - b },
        .multiply => .{ .float64 = a * b },
        .divide => .{ .float64 = a / b },
        .less => .{ .boolean = a < b },
        .less_equal => .{ .boolean = a <= b },
        .greater => .{ .boolean = a > b },
        .greater_equal => .{ .boolean = a >= b },
        .equal => .{ .boolean = a == b },
        .not_equal => .{ .boolean = a != b },
        else => error.InvalidProgram,
    };
}

fn convert(value: Value, target: Ir.Type, checked: bool) Error!Value {
    const source = value.typeOf();
    if (source == target) return value;
    if (source.isInteger() and target.isInteger()) {
        const number = try numericInteger(value);
        if (target.isSignedInteger()) {
            const signed: i128 = if (source.isSignedInteger()) number.signed() else number.bits;
            if (signed < Numeric.integerMin(target) or signed > Numeric.integerMax(target)) return error.InvalidConversion;
            return integerResult(target, @bitCast(@as(i64, @intCast(signed))));
        }
        if (source.isSignedInteger() and number.signed() < 0) return error.InvalidConversion;
        if (number.bits > Numeric.integerMax(target)) return error.InvalidConversion;
        return integerResult(target, number.bits);
    }
    if (source.isInteger() and target.isFloat()) {
        const number = try numericInteger(value);
        if (target == .float32) {
            const result: f32 = if (source.isSignedInteger()) @floatFromInt(number.signed()) else @floatFromInt(number.bits);
            const exact: f64 = if (source.isSignedInteger()) @floatFromInt(number.signed()) else @floatFromInt(number.bits);
            if (checked and @as(f64, result) != exact) return error.InvalidConversion;
            return .{ .float32 = result };
        }
        const result: f64 = if (source.isSignedInteger()) @floatFromInt(number.signed()) else @floatFromInt(number.bits);
        if (source.isSignedInteger()) {
            if (checked and @as(i128, @intFromFloat(result)) != number.signed()) return error.InvalidConversion;
        } else if (checked and @as(u128, @intFromFloat(result)) != number.bits) return error.InvalidConversion;
        return .{ .float64 = result };
    }
    if (source == .float32 and target == .float64) return .{ .float64 = @floatCast(value.float32) };
    if (source == .float64 and target == .float32) {
        const result: f32 = @floatCast(value.float64);
        if (@as(f64, @floatCast(result)) != value.float64) return error.InvalidConversion;
        return .{ .float32 = result };
    }
    if (source.isFloat() and target.isInteger()) {
        const number: f64 = if (source == .float32) value.float32 else value.float64;
        if (!std.math.isFinite(number) or @trunc(number) != number) return error.InvalidConversion;
        if (target.isSignedInteger()) {
            const lower: f64 = @floatFromInt(Numeric.integerMin(target));
            const upper_exclusive: f64 = @floatFromInt(@as(i128, Numeric.integerMax(target)) + 1);
            if (number < lower or number >= upper_exclusive) return error.InvalidConversion;
            return integerResult(target, @bitCast(@as(i64, @intFromFloat(number))));
        }
        if (number < 0 or number >= @as(f64, @floatFromInt(@as(u128, Numeric.integerMax(target)) + 1))) return error.InvalidConversion;
        return integerResult(target, @intFromFloat(number));
    }
    return error.InvalidConversion;
}

fn boolean(value: Value) Error!bool {
    return switch (value) {
        .boolean => |result| result,
        else => error.InvalidProgram,
    };
}

fn string(value: Value) Error![]const u8 {
    return switch (value) {
        .string => |result| result,
        else => error.InvalidProgram,
    };
}

fn equal(left: Value, right: Value) Error!bool {
    if (left.typeOf() != right.typeOf()) return error.InvalidProgram;
    return switch (left) {
        .integer => |value| value == right.integer,
        .typed_integer => |value| value.bits == right.typed_integer.bits and value.type == right.typed_integer.type,
        .float32 => |value| value == right.float32,
        .float64 => |value| value == right.float64,
        .string => |value| std.mem.eql(u8, value, right.string),
        .boolean => |value| value == right.boolean,
        .structure => |aggregate| structure: {
            if (aggregate.fields.len != right.structure.fields.len) return error.InvalidProgram;
            for (aggregate.fields, right.structure.fields) |left_field, right_field| {
                if (!try equal(left_field, right_field)) break :structure false;
            }
            break :structure true;
        },
        .void => error.InvalidProgram,
    };
}

fn appendValueText(output: *std.ArrayList(u8), allocator: Allocator, value: Value) Error!void {
    switch (value) {
        .integer => |number| {
            var buffer: [32]u8 = undefined;
            const text = std.fmt.bufPrint(&buffer, "{d}", .{number}) catch unreachable;
            try output.appendSlice(allocator, text);
        },
        .typed_integer => |number| {
            var buffer: [32]u8 = undefined;
            const text = if (number.type.isSignedInteger())
                std.fmt.bufPrint(&buffer, "{d}", .{number.signed()}) catch unreachable
            else
                std.fmt.bufPrint(&buffer, "{d}", .{number.bits}) catch unreachable;
            try output.appendSlice(allocator, text);
        },
        .float32 => |number| try appendFloat(output, allocator, number),
        .float64 => |number| try appendFloat(output, allocator, number),
        .boolean => |flag| try output.appendSlice(allocator, if (flag) "true" else "false"),
        .string => |text| try output.appendSlice(allocator, text),
        .structure => return error.InvalidProgram,
        .void => return error.InvalidProgram,
    }
}

fn appendFloat(output: *std.ArrayList(u8), allocator: Allocator, number: anytype) Error!void {
    if (std.math.isNan(number)) return output.appendSlice(allocator, "nan");
    if (std.math.isPositiveInf(number)) return output.appendSlice(allocator, "inf");
    if (std.math.isNegativeInf(number)) return output.appendSlice(allocator, "-inf");
    if (number == 0) {
        return output.appendSlice(allocator, if (std.math.signbit(number)) "-0.0" else "0.0");
    }
    var buffer: [std.fmt.float.bufferSize(.decimal, f64)]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{d}", .{number}) catch unreachable;
    try output.appendSlice(allocator, text);
    if (std.mem.indexOfAny(u8, text, ".eE") == null) try output.appendSlice(allocator, ".0");
}

fn appendRuntimeError(
    session: *Session,
    program: Ir.Program,
    position: @import("Source.zig").Position,
    prefix: []const u8,
    message: []const u8,
) Error!void {
    const path = if (position.file < program.files.len) program.files[position.file] else "<source>";
    const header = try std.fmt.allocPrint(
        session.allocator,
        "{s}:{d}:{d}: runtime error: {s}",
        .{ path, position.line, position.column, prefix },
    );
    try session.stderr.appendSlice(session.allocator, header);
    try session.stderr.appendSlice(session.allocator, message);
    try session.stderr.append(session.allocator, '\n');
}

fn checkedAdd(left: i64, right: i64) Error!i64 {
    const result = @addWithOverflow(left, right);
    if (result[1] != 0) return error.IntegerOverflow;
    return result[0];
}

fn checkedSubtract(left: i64, right: i64) Error!i64 {
    const result = @subWithOverflow(left, right);
    if (result[1] != 0) return error.IntegerOverflow;
    return result[0];
}

fn checkedMultiply(left: i64, right: i64) Error!i64 {
    const result = @mulWithOverflow(left, right);
    if (result[1] != 0) return error.IntegerOverflow;
    return result[0];
}

fn checkedDivide(left: i64, right: i64) Error!i64 {
    if (right == 0) return error.DivisionByZero;
    if (left == std.math.minInt(i64) and right == -1) return error.IntegerOverflow;
    return @divTrunc(left, right);
}

fn checkedRemainder(left: i64, right: i64) Error!i64 {
    if (right == 0) return error.DivisionByZero;
    if (left == std.math.minInt(i64) and right == -1) return 0;
    return @rem(left, right);
}

fn compile(source: []const u8, allocator: Allocator) !Ir.Program {
    var frontend = @import("Frontend.zig").Frontend.init(allocator);
    return (try frontend.compile(source)).ir;
}

test "interpret answer as 42 and run main successfully" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func answer() int {
        \\    return 40 + 2
        \\}
        \\func main() {
        \\    answer()
        \\}
    , allocator);
    const answer = try invoke(allocator, program, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqual(@as(u8, 0), try run(allocator, program));
}

test "interpret parameters booleans nested calls and arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func combine(left:int, right:int) int {
        \\    return (left * 3 + right) / 2 % 10
        \\}
        \\func nested() int { return combine(combine(4, 2), -2) }
        \\func invert(value:int) int { return -value }
        \\func truth() bool { return true }
        \\func main() { nested(); truth() }
    , allocator);
    try std.testing.expectEqual(@as(i64, 7), (try invoke(allocator, program, 0, &.{ .{ .integer = 4 }, .{ .integer = 2 } })).integer);
    try std.testing.expectEqual(@as(i64, 9), (try invoke(allocator, program, 1, &.{})).integer);
    try std.testing.expectEqual(@as(i64, -7), (try invoke(allocator, program, 2, &.{.{ .integer = 7 }})).integer);
    try std.testing.expect((try invoke(allocator, program, 3, &.{})).boolean);
    try std.testing.expectEqual(@as(u8, 0), try run(allocator, program));
}

test "report checked arithmetic errors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const overflow = try compile(
        "func value() int { return 9223372036854775807 + 1 } func main() {}",
        allocator,
    );
    try std.testing.expectError(error.IntegerOverflow, invoke(allocator, overflow, 0, &.{}));

    const division = try compile("func value() int { return 1 / 0 } func main() {}", allocator);
    try std.testing.expectError(error.DivisionByZero, invoke(allocator, division, 0, &.{}));

    const negation = try compile(
        "func value() int { let minimum = -9223372036854775808; return -minimum } func main() {}",
        allocator,
    );
    try std.testing.expectError(error.IntegerOverflow, invoke(allocator, negation, 0, &.{}));
}

test "limit recursive call depth" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile("func recurse() int { return recurse() } func main() {}", allocator);
    try std.testing.expectError(error.CallStackOverflow, invoke(allocator, program, 0, &.{}));
}

test "reject inconsistent typed IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const blocks = [_]Ir.Block{.{ .instructions = &.{}, .terminator = .return_void }};
    const functions = [_]Ir.Function{.{
        .name = "value",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{},
        .blocks = &blocks,
    }};
    try std.testing.expectError(error.InvalidProgram, invoke(arena.allocator(), .{ .functions = &functions }, 0, &.{}));
}

test "execute UTF-8 strings through parameters returns and intrinsic values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func identity(value:str) str { return value }
        \\func empty() str { let value:str; return value }
        \\func main() {
        \\    print(identity("Silex\n\u{1f525}\0ok"))
        \\    print(empty())
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualSlices(u8, "Silex\n🔥\x00ok\n\n", result.stdout);
    try std.testing.expectEqualStrings("", result.stderr);
}

test "execute alternatives and short-circuit logical operands" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("Frontend.zig").Frontend.init(allocator);
    const program = (try frontend.compile(
        \\func observed() bool { print("evaluated"); return true }
        \\func main() {
        \\    if false && observed() { print("bad") }
        \\    elif true || observed() { print("selected") }
        \\    else { print("bad") }
        \\}
    )).ir;
    const result = try runCapture(allocator, program);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("selected\n", result.stdout);
    try std.testing.expectEqualStrings("", result.stderr);
}

test "execute integer families floats conversions and unsigned bit operations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("Frontend.zig").Frontend.init(allocator);
    const program = (try frontend.compile(
        \\func preserve(value:uint16) uint16 { return value }
        \\func half(value:float64) float64 { return value / 2.0 }
        \\func main() {
        \\    let minimum:int8 = -128
        \\    let maximum:uint = 18446744073709551615
        \\    let flags:uint8 = 0x81
        \\    let byte:uint8 = (255 as uint8) ^ (15 as uint8)
        \\    print(minimum)
        \\    print(maximum)
        \\    print(preserve(65535))
        \\    print(flags >> 7)
        \\    print(byte)
        \\    print(half(5.0))
        \\}
    )).ir;
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings(
        "-128\n18446744073709551615\n65535\n1\n240\n2.5\n",
        result.stdout,
    );
}

test "execute immutable UTF-8 string operations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("Frontend.zig").Frontend.init(allocator);
    const program = (try frontend.compile(
        \\func join(left:str, right:str) str { return left + right }
        \\func main() {
        \\    let greeting = join("Bonjour, ", "Silex")
        \\    print(greeting)
        \\    print(greeting == "Bonjour, Silex")
        \\    print("Aé🔥".count())
        \\    print("A\0B".count())
        \\}
    )).ir;
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("Bonjour, Silex\ntrue\n3\n3\n", result.stdout);
}

test "format IEEE floating special values deterministically" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("Frontend.zig").Frontend.init(allocator);
    const program = (try frontend.compile(
        \\func main() {
        \\    let zero:float64 = 0.0
        \\    print(-zero)
        \\    print(1.0 / zero)
        \\    print(-1.0 / zero)
        \\    print(zero / zero)
        \\}
    )).ir;
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("-0.0\ninf\n-inf\nnan\n", result.stdout);
}

test "interpolate values and print multiple arguments without separators" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func observed(value:int) int { print("observed"); return value }
        \\func main() {
        \\    let value = 21
        \\    let message = "Value: $(value * 2), $(true), $(1.5), $value, ${value}, $$(value)"
        \\    print("Before ", observed(value), ": ", message)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualSlices(
        u8,
        "observed\nBefore 21: Value: 42, true, 1.5, $value, ${value}, $(value)\n",
        result.stdout,
    );
}

test "print reference values once and in source order" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func square(value:int) int { return value * value }
        \\func main() {
        \\    print("answer")
        \\    print(square(5))
        \\    print(true)
        \\    print(false)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("answer\n25\ntrue\nfalse\n", result.stdout);
}

test "execute mutable locals and evaluate assignments once" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func observed() int { print("observed"); return 42 }
        \\func main() {
        \\    var signed:int8
        \\    var unsigned:uint64
        \\    var decimal:float64
        \\    var enabled:bool
        \\    var message:str
        \\    signed = -8
        \\    unsigned = 18446744073709551615
        \\    decimal = 2.5
        \\    enabled = true
        \\    message = "Value: $(observed())"
        \\    print(signed, " ", unsigned, " ", decimal, " ", enabled, " ", message)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("observed\n-8 18446744073709551615 2.5 true Value: 42\n", result.stdout);
}

test "execute structure defaults nested aggregates and chained reads" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\struct Position {
        \\    var x:int
        \\    let layer:int = 7
        \\}
        \\struct Entity {
        \\    var position:Position = Position(x:5)
        \\    var name:str
        \\}
        \\func main() {
        \\    let empty = Entity()
        \\    let configured = Entity(name:"Ada", position:Position(x:42,),)
        \\    print(empty.position.x, " ", empty.position.layer, " ", empty.name)
        \\    print(configured.name, " ", configured.position.x, " ", configured.position.layer)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("5 7 \nAda 42 7\n", result.stdout);
}

test "transport and recursively compare structure values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\struct Point { var x:int; var label:str }
        \\struct Pair { var first:Point; var second:Point }
        \\func identity(value:Pair) Pair { return value }
        \\func nested(value:Pair) Pair { return identity(identity(value)) }
        \\func main() {
        \\    var original = Pair(first:Point(x:1, label:"A\0B"), second:Point(x:2, label:"C"))
        \\    let copied = nested(original)
        \\    original = Pair()
        \\    print(copied == Pair(first:Point(x:1, label:"A\0B"), second:Point(x:2, label:"C")))
        \\    print(original != copied)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("true\ntrue\n", result.stdout);
}

test "mutate nested fields once while preserving independent copies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\struct Score { var value:int; var label:str }
        \\struct Player { var score:Score; var reserve:int }
        \\func observed() int { print("observed"); return 2 }
        \\func main() {
        \\    var player = Player(score:Score(value:10, label:"A"), reserve:7)
        \\    let copy = player
        \\    player.score.value += observed()
        \\    player.score.value *= 3
        \\    player.score.value -= 6
        \\    player.score.value /= 3
        \\    player.score.value++
        \\    player.score.value--
        \\    player.score.label = "B"
        \\    print(player.score.value, " ", player.score.label, " ", player.reserve)
        \\    print(copy.score.value, " ", copy.score.label, " ", copy.reserve)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("observed\n10 B 7\n10 A 7\n", result.stdout);
}

test "execute overloaded value constructors and implicit self return" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\struct Position {
        \\    let x:int
        \\    let y:int
        \\    var label:str = "point"
        \\    init(x:int, y:int) { self.x = x; self.y = y }
        \\    init(enabled:bool) {
        \\        if enabled { self.x = 20 } else { self.x = 0 }
        \\        self.y = 22
        \\    }
        \\}
        \\func main() {
        \\    let first = Position(10, 5)
        \\    let second = Position(true)
        \\    print(first.x, " ", first.y, " ", first.label)
        \\    print(second.x + second.y)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("10 5 point\n42\n", result.stdout);
}

test "execute mutating nonmutating overloaded and chained methods" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\struct Counter {
        \\    var value:int
        \\    func increment() { self.value++ }
        \\    func forward() { self.increment() }
        \\    func add(amount:int) int { self.value += amount; return self.value }
        \\    func choose(amount:int) { self.value += amount }
        \\    func choose(enabled:bool) { if enabled { self.increment() } }
        \\    func current() int { return self.value }
        \\    func copy() Counter { return self }
        \\}
        \\func observed() int { print("observed"); return 2 }
        \\func make() Counter { print("make"); return Counter(value:40) }
        \\func main() {
        \\    var counter = Counter(value:1)
        \\    counter.forward()
        \\    let returned = counter.add(observed())
        \\    counter.choose(true)
        \\    counter.choose(3)
        \\    let immutable = counter
        \\    print(returned, " ", counter.current(), " ", immutable.copy().current())
        \\    print(make().current())
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("observed\n4 8 8\nmake\n40\n", result.stdout);
}

test "evaluate function constructor and method defaults at each omitted argument" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func observed() int { print("default"); return 2 }
        \\func selected(value:int = observed()) int { return value }
        \\struct Box {
        \\    var value:int
        \\    init(value:int = 40) { self.value = value }
        \\    func plus(value:int = 2) int { return self.value + value }
        \\    func bump(value:int = 1) { self.value += value }
        \\    func forward() { self.bump() }
        \\}
        \\func main() {
        \\    let box = Box()
        \\    print(box.plus())
        \\    print(selected(), " ", selected(), " ", selected(42))
        \\    var mutable = Box(40)
        \\    mutable.forward()
        \\    print(mutable.value)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("42\ndefault\ndefault\n2 2 42\n41\n", result.stdout);
}

test "execute while with zero iterations nested break and continue" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func main() {
        \\    var untouched = 7
        \\    while false { untouched = 0 }
        \\    var outer = 0
        \\    var score = 0
        \\    while outer < 3 {
        \\        outer = outer + 1
        \\        var inner = 0
        \\        while inner < 4 {
        \\            inner = inner + 1
        \\            if inner == 2 { continue }
        \\            if inner == 4 { break }
        \\            score = score + 1
        \\        }
        \\    }
        \\    print(untouched, " ", outer, " ", score)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("7 3 6\n", result.stdout);
}

test "execute compound assignments once across numeric families" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func observed() int8 { print("observed"); return 2 }
        \\func main() {
        \\    var signed:int8 = 10
        \\    signed += observed()
        \\    signed *= 3
        \\    signed -= 6
        \\    signed /= 3
        \\    signed++
        \\    signed--
        \\    var unsigned:uint16 = 40
        \\    unsigned++
        \\    unsigned -= 1
        \\    var decimal:float64 = 1.5
        \\    decimal += 0.5
        \\    decimal *= 4.0
        \\    decimal -= 2.0
        \\    decimal /= 3.0
        \\    print(signed, " ", unsigned, " ", decimal)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("observed\n10 40 2.0\n", result.stdout);
}

test "compound assignments preserve checked arithmetic failures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const overflow = try compile(
        "func value() int { var result = 9223372036854775807; result++; return result } func main() {}",
        allocator,
    );
    try std.testing.expectError(error.IntegerOverflow, invoke(allocator, overflow, 0, &.{}));

    const division = try compile(
        "func value() int { var result = 1; result /= 0; return result } func main() {}",
        allocator,
    );
    try std.testing.expectError(error.DivisionByZero, invoke(allocator, division, 0, &.{}));
}

test "print evaluates a nested effectful call exactly once" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func observed() int {
        \\    print("inside")
        \\    return 42
        \\}
        \\func main() { print(observed()) }
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("inside\n42\n", result.stdout);
}

test "compare fundamental values with defined precedence" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func main() {
        \\    print(1 + 2 * 3 < 8 == true)
        \\    print(4 <= 4)
        \\    print(5 > 9)
        \\    print(false != true)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("true\ntrue\nfalse\ntrue\n", result.stdout);
}

test "assert and panic return structured runtime output" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var assertion = try compile(
        \\func main() {
        \\    print("before")
        \\    assert(false, "planned failure")
        \\    print("after")
        \\}
    , allocator);
    assertion.files = &.{"Sandbox/Main.sx"};
    const failed = try runCapture(allocator, assertion);
    try std.testing.expectEqual(@as(u8, 1), failed.exit_code);
    try std.testing.expectEqualStrings("before\n", failed.stdout);
    try std.testing.expectEqualStrings(
        "Sandbox/Main.sx:3:5: runtime error: assertion failed: planned failure\n",
        failed.stderr,
    );

    var panic_program = try compile("func value() int { panic(\"literal panic\") } func main() { value() }", allocator);
    panic_program.files = &.{"Main.sx"};
    const panicked = try runCapture(allocator, panic_program);
    try std.testing.expectEqual(@as(u8, 1), panicked.exit_code);
    try std.testing.expectEqualStrings("Main.sx:1:20: runtime error: literal panic\n", panicked.stderr);
}
