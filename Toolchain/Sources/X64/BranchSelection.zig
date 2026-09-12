const std = @import("std");
const Machine = @import("../Arm64/Machine.zig");
const Liveness = @import("../Arm64/ResidenceLiveness.zig");

pub fn comparison(function: Machine.Function, index: usize) ?Machine.Instruction.Binary {
    if (function.reuses_slots or index + 1 >= function.instructions.len) return null;
    const binary = switch (function.instructions[index]) {
        .binary => |value| value,
        else => return null,
    };
    if (binary.type == .str or condition(binary) == null) return null;
    const branch = switch (function.instructions[index + 1]) {
        .branch => |value| value,
        else => return null,
    };
    if (branch.condition != binary.result) return null;
    for (function.instructions, 0..) |instruction, use_index| {
        if (use_index != index + 1 and Liveness.instructionUses(instruction, binary.result)) return null;
        switch (instruction) {
            .local_address => |address| if (binary.result >= address.local and
                binary.result - address.local < address.width) return null,
            .jump => |target| if (target == index + 1) return null,
            .branch => |value| if (value.then_instruction == index + 1 or value.else_instruction == index + 1) return null,
            else => {},
        }
    }
    return binary;
}

// Near Jcc opcode after CMP or UCOMIS{S,D}. For FP less/equal/not-equal,
// the parity branch must be emitted before this ordered predicate.
pub fn condition(binary: Machine.Instruction.Binary) ?u8 {
    const signed = binary.type.isSignedInteger();
    return switch (binary.operator) {
        .less => if (signed) 0x8c else 0x82,
        .less_equal => if (signed) 0x8e else 0x86,
        .greater => if (signed) 0x8f else 0x87,
        .greater_equal => if (signed) 0x8d else 0x83,
        .equal => 0x84,
        .not_equal => 0x85,
        else => null,
    };
}

pub fn unorderedResult(binary: Machine.Instruction.Binary) ?bool {
    if (!binary.type.isFloat()) return null;
    return switch (binary.operator) {
        .less, .less_equal, .equal => false,
        .not_equal => true,
        else => null,
    };
}

test "branch fusion rejects shared booleans, independent entries, and reused slots" {
    var instructions = [_]Machine.Instruction{
        .{ .binary = .{ .left = 0, .right = 1, .result = 2, .operator = .less, .type = .float64 } },
        .{ .branch = .{ .condition = 2, .then_instruction = 2, .else_instruction = 3 } },
        .return_void,
        .return_void,
    };
    var function: Machine.Function = .{
        .name = "predicate",
        .parameter_count = 0,
        .slot_count = 3,
        .frame_size = 32,
        .return_type = .void,
        .instructions = &instructions,
    };
    try std.testing.expect(comparison(function, 0) != null);
    function.reuses_slots = true;
    try std.testing.expect(comparison(function, 0) == null);
    function.reuses_slots = false;
    instructions[3] = .{ .print = .{ .value = 2, .kind = .boolean, .newline = true } };
    try std.testing.expect(comparison(function, 0) == null);
    instructions[3] = .{ .local_address = .{ .result = 0, .local = 2, .width = 1 } };
    try std.testing.expect(comparison(function, 0) == null);
    instructions[3] = .{ .jump = 1 };
    try std.testing.expect(comparison(function, 0) == null);
    instructions[3] = .{ .jump = 0 };
    try std.testing.expect(comparison(function, 0) != null);
}
