const std = @import("std");
const Ast = @import("Ast.zig");

const Allocator = std.mem.Allocator;

pub const Instruction = enum {
    return_void,
};

pub const Function = struct {
    name: []const u8,
    return_type: Ast.Type,
    instructions: []const Instruction,
};

pub const Program = struct {
    functions: []const Function,
};

pub fn lower(allocator: Allocator, ast: Ast.Program) Allocator.Error!Program {
    var functions: std.ArrayList(Function) = .empty;
    for (ast.functions) |function| {
        const instructions = try allocator.dupe(Instruction, &.{.return_void});
        try functions.append(allocator, .{
            .name = function.name,
            .return_type = function.return_type,
            .instructions = instructions,
        });
    }
    return .{ .functions = try functions.toOwnedSlice(allocator) };
}

pub fn writeText(allocator: Allocator, program: Program) Allocator.Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    for (program.functions, 0..) |function, index| {
        if (index != 0) try output.append(allocator, '\n');
        try output.appendSlice(allocator, "func @");
        try output.appendSlice(allocator, function.name);
        try output.appendSlice(allocator, "() -> ");
        try output.appendSlice(allocator, function.return_type.name());
        try output.appendSlice(allocator, " {\nentry:\n");
        for (function.instructions) |instruction| switch (instruction) {
            .return_void => try output.appendSlice(allocator, "    return\n"),
        };
        try output.appendSlice(allocator, "}\n");
    }
    return output.toOwnedSlice(allocator);
}

test "produce deterministic textual IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = @import("Parser.zig").Parser.init(allocator, "func main() {}");
    const text = try writeText(allocator, try lower(allocator, try parser.parse()));
    try std.testing.expectEqualStrings(
        \\func @main() -> void {
        \\entry:
        \\    return
        \\}
        \\
    , text);
}
