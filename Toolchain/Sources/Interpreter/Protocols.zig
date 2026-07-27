const std = @import("std");
const Ir = @import("../Ir.zig");
const RuntimeValue = @import("Value.zig");

const Value = RuntimeValue.Value;

pub fn initialize(
    allocator: std.mem.Allocator,
    function: Ir.Function,
    values: []?Value,
    initialization: Ir.Instruction.ProtocolInit,
) !void {
    const operand = try load(values, initialization.operand);
    const dynamic_structure = switch (operand) {
        .structure => |value| value.type.structureIndex() orelse return error.InvalidProgram,
        .class => |value| value.instance.type.structureIndex() orelse return error.InvalidProgram,
        else => return error.InvalidProgram,
    };
    if (dynamic_structure != initialization.structure and operand != .class) return error.InvalidProgram;
    const concrete = try allocator.create(Value);
    concrete.* = try RuntimeValue.clone(allocator, operand);
    try store(function, values, initialization.result, .{ .protocol = .{
        .type = function.value_types[initialization.result],
        .concrete = concrete,
    } });
}

pub fn testValue(
    function: Ir.Function,
    values: []?Value,
    test_value: Ir.Instruction.ProtocolTest,
) !void {
    const protocol = switch (try load(values, test_value.operand)) {
        .protocol => |value| value,
        else => return error.InvalidProgram,
    };
    const dynamic_structure = switch (protocol.concrete.*) {
        .structure => |value| value.type.structureIndex() orelse return error.InvalidProgram,
        .class => |value| value.instance.type.structureIndex() orelse return error.InvalidProgram,
        else => return error.InvalidProgram,
    };
    try store(function, values, test_value.result, .{ .boolean = dynamic_structure == test_value.structure });
}

pub fn extract(
    allocator: std.mem.Allocator,
    function: Ir.Function,
    values: []?Value,
    extraction: Ir.Instruction.ProtocolExtract,
) !void {
    const protocol = switch (try load(values, extraction.operand)) {
        .protocol => |value| value,
        else => return error.InvalidProgram,
    };
    var concrete = try RuntimeValue.clone(allocator, protocol.concrete.*);
    switch (concrete) {
        .class => |*value| value.static_type = .structure(extraction.structure),
        .structure => |value| if (value.type != Ir.Type.structure(extraction.structure)) return error.InvalidProgram,
        else => return error.InvalidProgram,
    }
    try store(function, values, extraction.result, concrete);
}

fn load(values: []const ?Value, id: Ir.ValueId) !Value {
    if (id >= values.len) return error.InvalidProgram;
    return values[id] orelse error.InvalidProgram;
}

fn store(function: Ir.Function, values: []?Value, id: Ir.ValueId, value: Value) !void {
    if (id >= values.len or function.value_types[id] != value.typeOf()) return error.InvalidProgram;
    values[id] = value;
}
