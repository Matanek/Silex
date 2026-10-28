const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");

fn compileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "rounded floating conversion preserves IEEE boundaries and static evaluation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Constants {
        \\    static let precise:float64 = 0.1
        \\    static let rounded:float32 = round_float<float32>(Constants.precise)
        \\}
        \\func narrow(value:float64) float32 { return round_float<float32>(value:value) }
        \\func main() {
        \\    let integer:int64 = 16777217
        \\    assert(round_float<float32>(integer) == 16777216.0)
        \\    let precise:float64 = 0.1
        \\    assert(narrow(precise) == Constants.rounded)
        \\    assert((narrow(precise) as float64) != precise)
        \\    let even:float64 = 1.000000059604644775390625
        \\    let odd:float64 = 1.000000178813934326171875
        \\    assert(narrow(even) == 1.0)
        \\    assert(narrow(odd) == 1.0000002384185791015625)
        \\    assert(narrow(-even) == -1.0)
        \\    let smallest:float64 = 1.4012984643248170709237295832899161312802619418765e-45
        \\    assert((narrow(smallest) as float64) == smallest)
        \\    assert(narrow(smallest * 0.5) == 0.0)
        \\    assert((narrow(smallest * 1.5) as float64) == smallest * 2.0)
        \\    let negative = narrow(-smallest * 0.5)
        \\    assert(1.0 / negative < 0.0)
        \\    let huge:float64 = 1e300
        \\    let infinite = narrow(huge)
        \\    assert(infinite != 0.0 && infinite + infinite == infinite)
        \\    let zero:float64 = 0.0
        \\    let nan = narrow(zero / zero)
        \\    assert(nan != nan)
        \\    print("rounded")
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("rounded\n", result.stdout);
}

test "rounded floating conversion never removes a subsequent exact conversion check" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func convert(value:float64) float32 {
        \\    let rounded = round_float<float32>(value)
        \\    print("rounded")
        \\    let exact = value as float32
        \\    return rounded + exact
        \\}
        \\func main() { let precise:float64 = 0.1; print(convert(precise)) }
    );
    var checked: usize = 0;
    var rounded: usize = 0;
    for (compilation.ir.functions) |function| for (function.blocks) |block| for (block.instructions) |instruction| {
        if (instruction == .convert and instruction.convert.source == .float64 and instruction.convert.target == .float32) {
            if (instruction.convert.checked) checked += 1 else rounded += 1;
        }
    };
    try std.testing.expectEqual(@as(usize, 1), checked);
    try std.testing.expectEqual(@as(usize, 1), rounded);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expect(result.exit_code != 0);
    try std.testing.expectEqualStrings("rounded\n", result.stdout);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "invalid numeric conversion") != null);
}

test "rounded floating conversion rejects invalid targets values labels and declarations" {
    try compileError("func main() { print(round_float(1.0)) }", "round_float expects one explicit floating target type");
    try compileError("func main() { print(round_float<int>(1.0)) }", "round_float target must be float32 or float64");
    try compileError("func main() { print(round_float<float32>(true)) }", "round_float source must be numeric");
    try compileError("func main() { print(round_float<float32>()) }", "round_float expects one numeric value, optionally labeled 'value'");
    try compileError("func main() { print(round_float<float32>(other:1.0)) }", "round_float expects one numeric value, optionally labeled 'value'");
    try compileError("func round_float() {}", "'round_float' is a reserved intrinsic function name");
}

test "native rounded conversion preserves a following exact guard in Debug and Release" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    const Lower = @import("Arm64/Lower.zig");
    const Runner = @import("Arm64/Runner.zig");
    const Machine = @import("Arm64/Machine.zig");
    const Release = @import("Optimize/Release.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func rounded(value:float64) float32 { return round_float<float32>(value) }
        \\func checked(value:float64) float32 {
        \\    let rounded = round_float<float32>(value)
        \\    let exact = value as float32
        \\    return rounded + exact
        \\}
        \\func main() {}
    );
    for ([_]bool{ false, true }) |optimized| {
        const program = if (optimized) try Release.optimize(allocator, compilation.ir) else compilation.ir;
        const machine = try Lower.lowerWithMode(allocator, program, if (optimized) .release else .debug);
        var observed: usize = 0;
        for (program.functions, 0..) |function, index| {
            if (!std.mem.eql(u8, function.name, "rounded") and !std.mem.eql(u8, function.name, "checked")) continue;
            observed += 1;
            const result = try Runner.invoke(allocator, machine, index, &.{@bitCast(@as(f64, 0.1))});
            if (std.mem.eql(u8, function.name, "rounded")) {
                try std.testing.expectEqual(Machine.Status.success, result.status);
                try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, 0.1))), @as(u32, @truncate(@as(u64, @bitCast(result.value)))));
            } else try std.testing.expectEqual(Machine.Status.runtime_failure, result.status);
        }
        try std.testing.expectEqual(@as(usize, 2), observed);
    }
}
