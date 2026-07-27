const std = @import("std");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const Value = @import("Value.zig").Value;

pub fn initialize(allocator: std.mem.Allocator, globals: []const Ir.Global) ![]Value {
    const values = try allocator.alloc(Value, globals.len);
    for (globals, 0..) |global, index| values[index] = switch (global.type) {
        .int => .{ .integer = @bitCast(global.bits) },
        .int8, .int16, .int32, .uint8, .uint16, .uint32, .uint => .{ .typed_integer = .{ .type = global.type, .bits = Numeric.normalize(global.bits, global.type) } },
        .bool => .{ .boolean = global.bits != 0 },
        .float32 => .{ .float32 = @bitCast(@as(u32, @truncate(global.bits))) },
        .float64 => .{ .float64 = @bitCast(global.bits) },
        else => return error.InvalidProgram,
    };
    return values;
}

pub fn load(allocator: std.mem.Allocator, globals: []Value, instruction: Ir.Instruction.GlobalLoad) !Value {
    if (instruction.global >= globals.len) return error.InvalidProgram;
    return @import("Value.zig").clone(allocator, globals[instruction.global]);
}

pub fn store(allocator: std.mem.Allocator, program: Ir.Program, globals: []Value, instruction: Ir.Instruction.GlobalStore, value: Value) !void {
    if (instruction.global >= globals.len or !program.globals[instruction.global].mutable or
        value.typeOf() != program.globals[instruction.global].type) return error.InvalidProgram;
    globals[instruction.global] = try @import("Value.zig").clone(allocator, value);
}
