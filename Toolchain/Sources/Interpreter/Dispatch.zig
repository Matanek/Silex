const std = @import("std");
const Ir = @import("../Ir.zig");
const RuntimeValue = @import("Value.zig");

const Value = RuntimeValue.Value;

pub fn execute(
    allocator: std.mem.Allocator,
    program: Ir.Program,
    caller: Ir.Function,
    values: []?Value,
    call: Ir.Instruction.DynamicCall,
    depth: usize,
    session: anytype,
    invoke: anytype,
) !void {
    const receiver = try load(values, call.receiver);
    const dynamic_structure = switch (receiver) {
        .class => |class| class.instance.type.structureIndex() orelse return error.InvalidProgram,
        else => return error.InvalidProgram,
    };
    var function_id = call.function;
    for (call.implementations) |implementation| if (implementation.structure == dynamic_structure) {
        function_id = implementation.function;
        break;
    };
    if (function_id >= program.functions.len) return error.InvalidProgram;
    const callee = program.functions[function_id];
    if (call.arguments.len != callee.parameter_types.len) return error.InvalidProgram;
    const arguments = try allocator.alloc(Value, call.arguments.len);
    defer allocator.free(arguments);
    for (call.arguments, 0..) |argument, index| {
        arguments[index] = try load(values, argument);
        if (index == 0 and arguments[index] == .class) {
            arguments[index].class.static_type = callee.parameter_types[0];
        }
    }
    var result = try invoke(allocator, program, function_id, arguments, depth + 1, session);
    if (call.result) |result_id| {
        if (callee.return_type == .void or result == .void) return error.InvalidProgram;
        const target = caller.value_types[result_id];
        switch (result) {
            .class => |*class| class.static_type = target,
            .structure => |*structure| {
                structure.type = target;
                const target_index = target.structureIndex() orelse return error.InvalidProgram;
                if (structure.fields.len != 0 and structure.fields[0] == .class) {
                    structure.fields[0].class.static_type = program.structures[target_index].fields[0].type;
                }
            },
            else => {},
        }
        try store(caller, values, result_id, result);
    } else if (callee.return_type != .void or result != .void) return error.InvalidProgram;
}

fn load(values: []?Value, id: Ir.ValueId) !Value {
    if (id >= values.len) return error.InvalidProgram;
    return values[id] orelse error.InvalidProgram;
}

fn store(function: Ir.Function, values: []?Value, id: Ir.ValueId, value: Value) !void {
    if (id >= values.len or function.value_types[id] != value.typeOf()) return error.InvalidProgram;
    values[id] = value;
}
