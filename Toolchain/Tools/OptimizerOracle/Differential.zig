const std = @import("std");
const Silex = @import("silex_optimizer_api");

pub const Result = struct {
    raw_ir: Silex.Ir.Program,
    optimized_ir: Silex.Ir.Program,
    execution: Execution,
};

pub const Error = error{SemanticMismatch};

pub const Execution = union(enum) {
    completed: Silex.Interpreter.RunResult,
    failed: anyerror,
};

pub fn verify(allocator: std.mem.Allocator, source: []const u8) !Result {
    var frontend = Silex.Frontend.init(allocator);
    const compilation = try frontend.compile(source);
    const raw = execute(allocator, compilation.ir);
    const optimized_ir = try Silex.ReleaseOptimizer.optimize(allocator, compilation.ir);
    const optimized = execute(allocator, optimized_ir);
    if (!equal(raw, optimized)) return error.SemanticMismatch;
    return .{
        .raw_ir = compilation.ir,
        .optimized_ir = optimized_ir,
        .execution = raw,
    };
}

fn execute(allocator: std.mem.Allocator, program: Silex.Ir.Program) Execution {
    return .{ .completed = Silex.Interpreter.runCapture(allocator, program) catch |err| return .{ .failed = err } };
}

fn equal(left: Execution, right: Execution) bool {
    return switch (left) {
        .failed => |left_error| switch (right) {
            .failed => |right_error| left_error == right_error,
            .completed => false,
        },
        .completed => |left_result| switch (right) {
            .failed => false,
            .completed => |right_result| left_result.exit_code == right_result.exit_code and
                std.mem.eql(u8, left_result.stdout, right_result.stdout) and
                std.mem.eql(u8, left_result.stderr, right_result.stderr),
        },
    };
}

test "release optimization preserves a numeric control-flow program" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try verify(arena.allocator(),
        \\func choose(value:int, condition:bool) int {
        \\    var result = value * 2
        \\    if condition { result += 7 } else { result -= 3 }
        \\    return result
        \\}
        \\func main() { print(choose(12, true)); print(choose(12, false)) }
    );
    try std.testing.expectEqualStrings("31\n21\n", result.execution.completed.stdout);
}

test "release optimization preserves defined integer failures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const overflow = try verify(arena.allocator(),
        \\func main() { let maximum = 9223372036854775807; print(maximum + 1) }
    );
    try std.testing.expectEqual(error.IntegerOverflow, overflow.execution.failed);

    const division = try verify(arena.allocator(),
        \\func main() { let zero = 0; print(42 / zero) }
    );
    try std.testing.expectEqual(error.DivisionByZero, division.execution.failed);
}
