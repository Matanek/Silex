const std = @import("std");
const Ir = @import("Ir.zig");

pub const Error = error{InvalidProgram};

pub fn run(program: Ir.Program) Error!u8 {
    for (program.functions) |function| {
        if (!std.mem.eql(u8, function.name, "main")) continue;
        for (function.instructions) |instruction| switch (instruction) {
            .return_void => return 0,
        };
        return error.InvalidProgram;
    }
    return error.InvalidProgram;
}

test "empty main exits successfully" {
    const instructions = [_]Ir.Instruction{.return_void};
    const functions = [_]Ir.Function{.{
        .name = "main",
        .return_type = .void,
        .instructions = &instructions,
    }};
    try std.testing.expectEqual(@as(u8, 0), try run(.{ .functions = &functions }));
}
