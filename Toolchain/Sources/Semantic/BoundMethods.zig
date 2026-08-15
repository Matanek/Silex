const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Callbacks = @import("Callbacks.zig");
const Model = @import("Model.zig");

pub fn analyze(self: anytype, bound: Callbacks.BoundMethod) !Ir.Function {
    const method = self.program.structures[bound.owner].methods[bound.method_index];
    const signature_index = bound.function_type.functionIndex() orelse return error.InvalidSource;
    if (signature_index >= self.program.function_types.len) return error.InvalidSource;
    const signature = self.program.function_types[signature_index];
    const flat = flatMethodIndex(self.program, bound.owner, bound.method_index);
    const mutating = self.method_mutability[flat];
    if (method.return_mode != .value or signature.parameters.len > method.parameters.len) return error.InvalidSource;

    var builder: Model.FunctionBuilder = .{ .return_type = method.return_type };
    try builder.blocks.append(self.allocator, .{});
    try builder.value_types.append(self.allocator, .address);
    const parameter_types = try self.allocator.alloc(Ast.Type, signature.parameters.len);
    for (signature.parameters, 0..) |parameter, index| {
        parameter_types[index] = if (parameter.mode == .mutable) .address else parameter.type;
        try builder.value_types.append(self.allocator, parameter_types[index]);
    }

    const receiver_type = Ast.Type.structure(bound.owner);
    const receiver = try self.newValue(&builder, receiver_type);
    try self.emit(&builder, .{ .reference_load = .{ .result = receiver, .reference = 0 } });
    var arguments: std.ArrayList(Ir.ValueId) = .empty;
    try arguments.append(self.allocator, receiver);
    for (parameter_types, 0..) |_, index| try arguments.append(self.allocator, index + 1);
    for (method.parameters[parameter_types.len..]) |parameter| {
        if (parameter.default == null) return error.InvalidSource;
        try arguments.append(self.allocator, (try self.analyzeParameterDefault(&builder, parameter)).value);
    }

    const lowered_result = methodIrReturnType(self, bound.owner, flat, method);
    const call_result: ?Ir.ValueId = if (lowered_result == .void) null else try self.newValue(&builder, lowered_result);
    try self.emit(&builder, .{ .call = .{
        .result = call_result,
        .function = methodFunctionId(self.program, bound.owner, bound.method_index),
        .arguments = try arguments.toOwnedSlice(self.allocator),
    } });
    if (!mutating) {
        if (call_result) |result| self.terminate(&builder, .{ .return_value = result }) else self.terminate(&builder, .return_void);
    } else if (method.return_type == .void) {
        try self.emit(&builder, .{ .reference_store = .{ .reference = 0, .operand = call_result.? } });
        self.terminate(&builder, .return_void);
    } else {
        const updated = try self.newValue(&builder, receiver_type);
        try self.emit(&builder, .{ .field_load = .{ .result = updated, .base = call_result.?, .field = 0 } });
        try self.emit(&builder, .{ .reference_store = .{ .reference = 0, .operand = updated } });
        const value = try self.newValue(&builder, method.return_type);
        try self.emit(&builder, .{ .field_load = .{ .result = value, .base = call_result.?, .field = 1 } });
        self.terminate(&builder, .{ .return_value = value });
    }

    const blocks = try self.allocator.alloc(Ir.Block, 1);
    blocks[0] = .{
        .instructions = try builder.blocks.items[0].instructions.toOwnedSlice(self.allocator),
        .terminator = builder.blocks.items[0].terminator orelse return error.InvalidSource,
    };
    return .{
        .name = try std.fmt.allocPrint(self.allocator, "{s}.{s}#bound{d}", .{ self.program.structures[bound.owner].name, method.name, self.bound_methods.items.len }),
        .capture_types = try self.allocator.dupe(Ast.Type, &.{Ast.Type.address}),
        .parameter_types = parameter_types,
        .return_type = method.return_type,
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .blocks = blocks,
    };
}

fn methodIrReturnType(self: anytype, structure_index: usize, flat: usize, method: Ast.Function) Ast.Type {
    if (method.return_mode == .mutable) return .address;
    if (!self.method_mutability[flat]) return method.return_type;
    if (method.return_type == .void) return .structure(structure_index);
    return methodResultType(self.program, self.method_mutability, self.program.type_names.len, flat).?;
}

fn methodResultType(program: Ast.Program, mutating: []const bool, base_count: usize, target_flat: usize) ?Ast.Type {
    var result = base_count;
    var flat: usize = 0;
    for (program.structures) |structure| {
        for (structure.methods) |method| {
            if (flat == target_flat) return if (mutating[flat] and method.return_type != .void and method.return_mode != .mutable) .structure(result) else null;
            if (mutating[flat] and method.return_type != .void and method.return_mode != .mutable) result += 1;
            flat += 1;
        }
    }
    return null;
}

fn methodFunctionId(program: Ast.Program, structure_index: usize, method_index: usize) Ir.FunctionId {
    var result = program.functions.len;
    for (program.structures) |structure| result += structure.constructors.len;
    for (program.structures[0..structure_index]) |structure| if (!structure.is_protocol) {
        result += structure.methods.len;
    };
    return result + method_index;
}

fn flatMethodIndex(program: Ast.Program, structure_index: usize, method_index: usize) usize {
    var result = method_index;
    for (program.structures[0..structure_index]) |structure| result += structure.methods.len;
    return result;
}
