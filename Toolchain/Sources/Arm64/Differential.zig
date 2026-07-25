const std = @import("std");
const builtin = @import("builtin");

const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Ir = @import("../Ir.zig");
const Lower = @import("Lower.zig");
const Machine = @import("Machine.zig");
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
            .boolean => |value| @intFromBool(value),
            .void => return error.TestUnexpectedResult,
        };
    }
    const native = try Runner.invoke(allocator, machine, function, native_arguments[0..arguments.len]);

    const reference = Interpreter.invoke(allocator, ir, function, arguments) catch |err| {
        const expected: Machine.Status = switch (err) {
            error.IntegerOverflow => .integer_overflow,
            error.DivisionByZero => .division_by_zero,
            else => return err,
        };
        try std.testing.expectEqual(expected, native.status);
        return;
    };

    try std.testing.expectEqual(Machine.Status.success, native.status);
    switch (reference) {
        .integer => |value| try std.testing.expectEqual(value, native.value),
        .boolean => |value| try std.testing.expectEqual(@as(i64, @intFromBool(value)), native.value),
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
