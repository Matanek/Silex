const std = @import("std");
const builtin = @import("builtin");

const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Ir = @import("../Ir.zig");
const Lower = @import("Lower.zig");
const Machine = @import("Machine.zig");
const Numeric = @import("../Numeric.zig");
const Runner = @import("Runner.zig");

const Allocator = std.mem.Allocator;

fn compare(
    allocator: Allocator,
    ir: Ir.Program,
    machine: Machine.Program,
    function_name: []const u8,
    arguments: []const Interpreter.Value,
) !void {
    const function = findFunction(ir, function_name) orelse return error.TestUnexpectedResult;

    var native_arguments = [_]i64{0} ** Machine.max_register_arguments;
    for (arguments, 0..) |argument, index| {
        native_arguments[index] = switch (argument) {
            .integer => |value| value,
            .typed_integer => |value| if (value.type.isSignedInteger()) value.signed() else @bitCast(value.bits),
            .float32 => |value| @bitCast(@as(u64, @as(u32, @bitCast(value)))),
            .float64 => |value| @bitCast(@as(u64, @bitCast(value))),
            .boolean => |value| @intFromBool(value),
            .string => return error.UnsupportedType,
            .void => return error.TestUnexpectedResult,
        };
    }
    const native = try Runner.invoke(allocator, machine, function, native_arguments[0..arguments.len]);

    const reference = Interpreter.invoke(allocator, ir, function, arguments) catch |err| {
        const expected: Machine.Status = switch (err) {
            error.IntegerOverflow => .integer_overflow,
            error.DivisionByZero => .division_by_zero,
            error.InvalidShift => .integer_overflow,
            else => return err,
        };
        try std.testing.expectEqual(expected, native.status);
        return;
    };

    try std.testing.expectEqual(Machine.Status.success, native.status);
    switch (reference) {
        .integer => |value| try std.testing.expectEqual(value, native.value),
        .typed_integer => |value| try std.testing.expectEqual(
            if (value.type.isSignedInteger()) value.signed() else @as(i64, @bitCast(value.bits)),
            native.value,
        ),
        .float32 => |value| try std.testing.expectEqual(
            @as(u32, @bitCast(value)),
            @as(u32, @truncate(@as(u64, @bitCast(native.value)))),
        ),
        .float64 => |value| try std.testing.expectEqual(
            @as(u64, @bitCast(value)),
            @as(u64, @bitCast(native.value)),
        ),
        .boolean => |value| try std.testing.expectEqual(@as(i64, @intFromBool(value)), native.value),
        .string => return error.UnsupportedType,
        .void => try std.testing.expectEqual(@as(i64, 0), native.value),
    }
}

fn findFunction(program: Ir.Program, name: []const u8) ?Ir.FunctionId {
    for (program.functions, 0..) |function, id| {
        if (std.mem.eql(u8, function.name, name)) return id;
    }
    return null;
}

test "native ARM64 agrees with the reference interpreter on fundamental values" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func constant() int { return 42 }
        \\func arithmetic(left:int, right:int) int {
        \\    return ((left + right) * 3 - 2) / 2 % 11
        \\}
        \\func nested() int { return arithmetic(7, 4) + constant() }
        \\func negate(value:int) int { return -value }
        \\func echo(flag:bool) bool { return flag }
        \\func exactRemainder() int { return -9223372036854775808 % -1 }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);

    try compare(allocator, compilation.ir, machine, "constant", &.{});
    try compare(allocator, compilation.ir, machine, "arithmetic", &.{
        .{ .integer = 7 },
        .{ .integer = 4 },
    });
    try compare(allocator, compilation.ir, machine, "nested", &.{});
    try compare(allocator, compilation.ir, machine, "negate", &.{.{ .integer = -7 }});
    try compare(allocator, compilation.ir, machine, "echo", &.{.{ .boolean = true }});
    try compare(allocator, compilation.ir, machine, "echo", &.{.{ .boolean = false }});
    try compare(allocator, compilation.ir, machine, "exactRemainder", &.{});
}

test "native ARM64 agrees with checked arithmetic failures" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func addOverflow() int { return 9223372036854775807 + 1 }
        \\func subtractOverflow() int { return -9223372036854775808 - 1 }
        \\func multiplyOverflow() int { return 9223372036854775807 * 2 }
        \\func divideByZero() int { return 42 / 0 }
        \\func remainderByZero() int { return 42 % 0 }
        \\func divideOverflow() int { return -9223372036854775808 / -1 }
        \\func negateOverflow() int {
        \\    let minimum = -9223372036854775808
        \\    return -minimum
        \\}
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);

    try compare(allocator, compilation.ir, machine, "addOverflow", &.{});
    try compare(allocator, compilation.ir, machine, "subtractOverflow", &.{});
    try compare(allocator, compilation.ir, machine, "multiplyOverflow", &.{});
    try compare(allocator, compilation.ir, machine, "divideByZero", &.{});
    try compare(allocator, compilation.ir, machine, "remainderByZero", &.{});
    try compare(allocator, compilation.ir, machine, "divideOverflow", &.{});
    try compare(allocator, compilation.ir, machine, "negateOverflow", &.{});
}

test "native ARM64 agrees on narrow and unsigned integer domains" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func add8(left:int8, right:int8) int8 { return left + right }
        \\func subtract8(left:uint8, right:uint8) uint8 { return left - right }
        \\func shift(value:uint8, count:int8) uint8 { return value << count }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "add8", &.{
        .{ .typed_integer = Numeric.fromMagnitude(120, false, .int8) },
        .{ .typed_integer = Numeric.fromMagnitude(7, false, .int8) },
    });
    try compare(allocator, compilation.ir, machine, "add8", &.{
        .{ .typed_integer = Numeric.fromMagnitude(120, false, .int8) },
        .{ .typed_integer = Numeric.fromMagnitude(8, false, .int8) },
    });
    try compare(allocator, compilation.ir, machine, "subtract8", &.{
        .{ .typed_integer = Numeric.fromMagnitude(0, false, .uint8) },
        .{ .typed_integer = Numeric.fromMagnitude(1, false, .uint8) },
    });
    try compare(allocator, compilation.ir, machine, "shift", &.{
        .{ .typed_integer = Numeric.fromMagnitude(1, false, .uint8) },
        .{ .typed_integer = Numeric.fromMagnitude(8, false, .int8) },
    });
}

test "native ARM64 preserves IEEE arithmetic comparisons arguments and returns" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func identity32(value:float32) float32 { return value }
        \\func identity64(value:float64) float64 { return value }
        \\func arithmetic32(left:float32, right:float32) float32 { return left * right + left / right }
        \\func arithmetic64(left:float64, right:float64) float64 { return left * right + left / right }
        \\func less32(left:float32, right:float32) bool { return left < right }
        \\func unequal64(left:float64, right:float64) bool { return left != right }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "arithmetic32", &.{
        .{ .float32 = 1.25 },
        .{ .float32 = 3.5 },
    });
    try compare(allocator, compilation.ir, machine, "arithmetic64", &.{
        .{ .float64 = 1.0e-300 },
        .{ .float64 = 2.0 },
    });
    try compare(allocator, compilation.ir, machine, "identity32", &.{.{ .float32 = @bitCast(@as(u32, 1)) }});
    try compare(allocator, compilation.ir, machine, "identity64", &.{.{ .float64 = -0.0 }});
    try compare(allocator, compilation.ir, machine, "identity64", &.{.{ .float64 = std.math.inf(f64) }});
    try compare(allocator, compilation.ir, machine, "identity64", &.{.{ .float64 = std.math.nan(f64) }});
    try compare(allocator, compilation.ir, machine, "less32", &.{
        .{ .float32 = std.math.nan(f32) },
        .{ .float32 = 1.0 },
    });
    try compare(allocator, compilation.ir, machine, "unequal64", &.{
        .{ .float64 = std.math.nan(f64) },
        .{ .float64 = 1.0 },
    });
}
