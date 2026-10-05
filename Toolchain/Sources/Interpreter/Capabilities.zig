const std = @import("std");
const Boundary = @import("../Boundary.zig");
const Ir = @import("../Ir.zig");
const Interpreter = @import("../Interpreter.zig");
const ProgramScope = @import("../ProgramScope.zig");

/// Imported provider metadata is not an execution requirement. Check only
/// direct provider calls retained by the conservative entry-point closure.
/// Indirect foreign calls remain guarded by the interpreter's runtime dispatch.
pub fn firstUnsupported(
    allocator: std.mem.Allocator,
    program: Ir.Program,
    boundaries: []const Boundary.Function,
) !?Boundary.Function {
    const scope = try ProgramScope.executable(allocator, program);
    for (scope.program.functions) |function| {
        for (function.blocks) |block| {
            for (block.instructions) |instruction| {
                switch (instruction) {
                    .boundary_call => |call| {
                        if (call.function >= boundaries.len) return error.InvalidProgram;
                        const boundary = boundaries[call.function];
                        if (!Interpreter.supportsBoundary(boundary)) return boundary;
                    },
                    else => {},
                }
            }
        }
    }
    return null;
}

const unsupported: Boundary.Function = .{
    .name = "open",
    .source_name = "__open",
    .provider = "Boundary.System",
    .parameters = &.{},
    .return_type = .void,
    .package_private = true,
};
const foreign_instructions = [_]Ir.Instruction{.{ .boundary_call = .{
    .result = null,
    .function = 0,
    .arguments = &.{},
} }};

fn expectCapability(main_instructions: []const Ir.Instruction, expected: bool) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const functions = [_]Ir.Function{
        .{ .name = "main", .parameter_types = &.{}, .return_type = .void, .value_types = &.{.uint}, .blocks = &.{.{ .instructions = main_instructions, .terminator = .return_void }} },
        .{ .name = "foreign_helper", .parameter_types = &.{}, .return_type = .void, .value_types = &.{}, .blocks = &.{.{ .instructions = &foreign_instructions, .terminator = .return_void }} },
    };
    const found = try firstUnsupported(arena.allocator(), .{ .functions = &functions }, &.{unsupported});
    try std.testing.expectEqual(expected, found != null);
    if (found) |boundary| try std.testing.expectEqualStrings("__open", boundary.source_name);
}

test "interpreter capability ignores imported but unreachable foreign calls" {
    try expectCapability(&.{}, false);
}

test "interpreter capability rejects transitively reachable foreign calls" {
    const calls = [_]Ir.Instruction{.{ .call = .{ .result = null, .function = 1, .arguments = &.{} } }};
    try expectCapability(&calls, true);
}

test "interpreter capability retains referenced callbacks conservatively" {
    const callbacks = [_]Ir.Instruction{.{ .function_reference = .{ .result = 0, .function = 1 } }};
    try expectCapability(&callbacks, true);
}

test "interpreter capability accepts programs without foreign requirements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const functions = [_]Ir.Function{.{
        .name = "main",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = &.{},
        .blocks = &.{.{ .instructions = &.{}, .terminator = .return_void }},
    }};
    try std.testing.expectEqual(@as(?Boundary.Function, null), try firstUnsupported(arena.allocator(), .{ .functions = &functions }, &.{unsupported}));
}
