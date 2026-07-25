const std = @import("std");
const Ir = @import("Ir.zig");

const Allocator = std.mem.Allocator;
const max_call_depth = 1024;

pub const Error = Allocator.Error || error{
    InvalidProgram,
    IntegerOverflow,
    DivisionByZero,
    CallStackOverflow,
};

pub const Value = union(enum) {
    void,
    integer: i64,
    boolean: bool,

    pub fn typeOf(self: Value) Ir.Type {
        return switch (self) {
            .void => .void,
            .integer => .int,
            .boolean => .bool,
        };
    }
};

pub fn run(allocator: Allocator, program: Ir.Program) Error!u8 {
    var main: ?Ir.FunctionId = null;
    for (program.functions, 0..) |function, function_id| {
        if (!std.mem.eql(u8, function.name, "main")) continue;
        if (main != null) return error.InvalidProgram;
        main = function_id;
    }
    const function_id = main orelse return error.InvalidProgram;
    const function = program.functions[function_id];
    if (function.parameter_types.len != 0 or function.return_type != .void) return error.InvalidProgram;
    const result = try invokeDepth(allocator, program, function_id, &.{}, 0);
    if (result != .void) return error.InvalidProgram;
    return 0;
}

pub fn invoke(
    allocator: Allocator,
    program: Ir.Program,
    function: Ir.FunctionId,
    arguments: []const Value,
) Error!Value {
    return invokeDepth(allocator, program, function, arguments, 0);
}

fn invokeDepth(
    allocator: Allocator,
    program: Ir.Program,
    function_id: Ir.FunctionId,
    arguments: []const Value,
    depth: usize,
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
    for (arguments, function.parameter_types, 0..) |argument, parameter_type, index| {
        if (argument.typeOf() != parameter_type) return error.InvalidProgram;
        values[index] = argument;
    }

    for (function.instructions) |instruction| switch (instruction) {
        .constant_int => |constant| try store(function, values, constant.result, .{ .integer = constant.value }),
        .constant_bool => |constant| try store(function, values, constant.result, .{ .boolean = constant.value }),
        .unary => |unary| {
            const operand = try load(values, unary.operand);
            const result: Value = switch (unary.operator) {
                .negate => .{ .integer = try negate(try integer(operand)) },
            };
            try store(function, values, unary.result, result);
        },
        .binary => |binary| {
            const left = try integer(try load(values, binary.left));
            const right = try integer(try load(values, binary.right));
            const result = try calculate(binary.operator, left, right);
            try store(function, values, binary.result, .{ .integer = result });
        },
        .call => |call| {
            if (call.function >= program.functions.len) return error.InvalidProgram;
            const callee = program.functions[call.function];
            if (call.arguments.len != callee.parameter_types.len) return error.InvalidProgram;
            const call_arguments = try allocator.alloc(Value, call.arguments.len);
            defer allocator.free(call_arguments);
            for (call.arguments, 0..) |argument, index| call_arguments[index] = try load(values, argument);
            const result = try invokeDepth(allocator, program, call.function, call_arguments, depth + 1);
            if (call.result) |result_id| {
                if (callee.return_type == .void or result == .void) return error.InvalidProgram;
                try store(function, values, result_id, result);
            } else if (callee.return_type != .void or result != .void) {
                return error.InvalidProgram;
            }
        },
        .return_value => |value_id| {
            const result = try load(values, value_id);
            if (result.typeOf() != function.return_type or function.return_type == .void) return error.InvalidProgram;
            return result;
        },
        .return_void => {
            if (function.return_type != .void) return error.InvalidProgram;
            return .void;
        },
    };
    return error.InvalidProgram;
}

fn store(function: Ir.Function, values: []?Value, id: Ir.ValueId, value: Value) Error!void {
    if (id >= values.len or function.value_types[id] != value.typeOf()) return error.InvalidProgram;
    values[id] = value;
}

fn load(values: []const ?Value, id: Ir.ValueId) Error!Value {
    if (id >= values.len) return error.InvalidProgram;
    return values[id] orelse error.InvalidProgram;
}

fn integer(value: Value) Error!i64 {
    return switch (value) {
        .integer => |result| result,
        else => error.InvalidProgram,
    };
}

fn negate(value: i64) Error!i64 {
    if (value == std.math.minInt(i64)) return error.IntegerOverflow;
    return -value;
}

fn calculate(operator: Ir.BinaryOperator, left: i64, right: i64) Error!i64 {
    return switch (operator) {
        .add => checkedAdd(left, right),
        .subtract => checkedSubtract(left, right),
        .multiply => checkedMultiply(left, right),
        .divide => checkedDivide(left, right),
        .remainder => checkedRemainder(left, right),
    };
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
    const instructions = [_]Ir.Instruction{.return_void};
    const functions = [_]Ir.Function{.{
        .name = "value",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{},
        .instructions = &instructions,
    }};
    try std.testing.expectError(error.InvalidProgram, invoke(arena.allocator(), .{ .functions = &functions }, 0, &.{}));
}
