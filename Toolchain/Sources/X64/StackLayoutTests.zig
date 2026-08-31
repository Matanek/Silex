const std = @import("std");
const Ir = @import("../Ir.zig");
const Lower = @import("../Arm64/Lower.zig");
const Machine = @import("../Arm64/Machine.zig");
const Encoder = @import("Encoder.zig");
const RegisterAllocation = @import("RegisterAllocation.zig");

test "emit X64 programs whose sequential values exceed the former slot ceiling" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const value_count = Machine.max_slots + 8;
    const types = try allocator.alloc(Ir.Type, value_count);
    @memset(types, .int);
    const instructions = try allocator.alloc(Ir.Instruction, value_count);
    for (instructions, 0..) |*instruction, value| {
        instruction.* = .{ .constant_int = .{ .result = value, .bits = value } };
    }
    const blocks = [_]Ir.Block{.{
        .instructions = instructions,
        .terminator = .{ .return_value = value_count - 1 },
    }};
    const ir: Ir.Program = .{ .functions = &.{.{
        .name = "main",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = types,
        .blocks = &blocks,
    }} };
    var machine = try Lower.lowerWithMode(allocator, ir, .release);
    try std.testing.expect(machine.functions[0].reuses_slots);
    try std.testing.expectEqual(@as(Machine.Slot, 1), machine.functions[0].slot_count);
    machine = try RegisterAllocation.allocateProgram(allocator, machine);
    try std.testing.expectEqual(@as(usize, 0), machine.functions[0].register_slots.len);

    const linux = try Encoder.encodeLinux(allocator, machine);
    defer linux.deinit(allocator);
    try std.testing.expect(linux.code.len != 0);
    const windows = try Encoder.encodeWindows(allocator, machine);
    defer windows.deinit(allocator);
    try std.testing.expect(windows.code.len != 0);
}
