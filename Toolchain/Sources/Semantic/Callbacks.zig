const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Borrowing = @import("Borrowing.zig");
const Collections = @import("Collections.zig");
const MutableReferences = @import("MutableReferences.zig");
const Optionals = @import("Optionals.zig");
const Support = @import("Support.zig");

pub fn prepare(self: anytype) ![]const Ir.FunctionType {
    const result = try self.allocator.alloc(Ir.FunctionType, self.program.function_types.len);
    for (self.program.function_types, 0..) |function_type, index| {
        const parameters = try self.allocator.alloc(Ir.Type, function_type.parameters.len);
        for (function_type.parameters, 0..) |parameter, parameter_index| {
            parameters[parameter_index] = Collections.loweredBorrowType(self.structures, parameter.mode, parameter.type);
        }
        result[index] = .{
            .parameter_types = parameters,
            .return_type = Collections.loweredBorrowType(self.structures, function_type.return_mode, function_type.return_type),
        };
    }
    return result;
}

pub fn reference(self: anytype, builder: anytype, position: anytype, name: []const u8, expected: Ast.Type) !?Model.TypedValue {
    const signature_index = expected.functionIndex() orelse return null;
    if (signature_index >= self.program.function_types.len) return error.InvalidSource;
    const signature = self.program.function_types[signature_index];
    var selected: ?Ir.FunctionId = null;
    for (self.program.functions, 0..) |function, function_id| {
        if (!nameMatches(function.name, name) or !visible(self, function, position.file) or !matches(signature, function)) continue;
        if (selected != null) {
            const message = try std.fmt.allocPrint(self.allocator, "function reference '{s}' is ambiguous for the expected callback type", .{name});
            return self.fail(position, message);
        }
        selected = function_id;
    }
    const function_id = selected orelse return null;
    const result = try self.newValue(builder, expected);
    try self.emit(builder, .{ .function_reference = .{ .result = result, .function = function_id } });
    return .{ .type = expected, .value = result };
}

pub fn inferredReference(self: anytype, builder: anytype, position: anytype, name: []const u8) !?Model.TypedValue {
    var selected_function: ?Ir.FunctionId = null;
    var selected_type: ?Ast.Type = null;
    for (self.program.functions, 0..) |function, function_id| {
        if (!nameMatches(function.name, name) or !visible(self, function, position.file)) continue;
        var function_type: ?Ast.Type = null;
        for (self.program.function_types, 0..) |signature, signature_index| if (matches(signature, function)) {
            function_type = .function(signature_index);
            break;
        };
        if (function_type == null or selected_function != null) return null;
        selected_function = function_id;
        selected_type = function_type;
    }
    const function_id = selected_function orelse return null;
    const type_value = selected_type.?;
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .function_reference = .{ .result = result, .function = function_id } });
    return .{ .type = type_value, .value = result };
}

pub const CallResult = struct { value: ?Model.TypedValue };

pub fn call(self: anytype, builder: anytype, call_value: Ast.Expression.Call) !?CallResult {
    const callee = if (call_value.receiver) |receiver| receiver_value: {
        const receiver_type = inferType(self, builder, receiver) orelse return null;
        const structure_index = receiver_type.structureIndex() orelse return null;
        if (structure_index >= self.structures.len) return null;
        const field_name = if (std.mem.lastIndexOfScalar(u8, call_value.name, '.')) |dot| call_value.name[dot + 1 ..] else call_value.name;
        var callback_field = false;
        for (self.structures[structure_index].fields) |field| if (std.mem.eql(u8, field.name, field_name) and field.type.functionIndex() != null) {
            callback_field = true;
            break;
        };
        if (!callback_field) return null;
        var field_expression: Ast.Expression = .{
            .position = call_value.name_position,
            .value = .{ .field_access = .{ .base = receiver, .name_position = call_value.name_position, .name = field_name } },
        };
        break :receiver_value try self.analyzeExpression(builder, &field_expression);
    } else direct: {
        const binding = findBinding(builder.bindings.items, call_value.name) orelse return null;
        if (binding.type.functionIndex() == null) return null;
        break :direct try Borrowing.analyzeIdentifier(self, builder, call_value.name_position, binding.name);
    };

    if (call_value.type_arguments.len != 0 or call_value.named_arguments.len != 0) return self.fail(call_value.name_position, "callback calls use positional arguments");
    const signature_index = callee.type.functionIndex() orelse return error.InvalidSource;
    if (signature_index >= self.program.function_types.len) return error.InvalidSource;
    const signature = self.program.function_types[signature_index];
    if (call_value.arguments.len != signature.parameters.len) {
        const message = try std.fmt.allocPrint(self.allocator, "callback expects {d} arguments, found {d}", .{ signature.parameters.len, call_value.arguments.len });
        return self.fail(call_value.name_position, message);
    }

    const parameters = try self.allocator.alloc(Ast.Parameter, signature.parameters.len);
    for (signature.parameters, 0..) |parameter, index| parameters[index] = .{
        .position = call_value.arguments[index].position,
        .name = "callback argument",
        .type = parameter.type,
        .mode = parameter.mode,
    };
    try Borrowing.validateReadArguments(self, parameters, call_value.arguments);

    var arguments: std.ArrayList(Ir.ValueId) = .empty;
    var mutable_arguments: std.ArrayList(MutableArgument) = .empty;
    for (call_value.arguments, signature.parameters, 0..) |expression, parameter, index| {
        const argument = try self.analyzeExpressionExpected(builder, expression, Optionals.expectedContext(parameter.type, expression));
        if (!self.canImplicitlyConvert(argument.type, parameter.type)) {
            const message = try std.fmt.allocPrint(self.allocator, "argument {d} of callback expects '{s}', found '{s}'", .{ index + 1, self.typeName(parameter.type), self.typeName(argument.type) });
            return self.fail(expression.position, message);
        }
        if (parameter.mode == .mutable) {
            const prepared = try MutableReferences.prepare(self, builder, expression, parameter.type);
            try mutable_arguments.append(self.allocator, .{ .prepared = prepared });
            try arguments.append(self.allocator, prepared.reference);
        } else {
            if (parameter.mode == .value) try Borrowing.requireOwned(self, argument, expression.position, "passed by value");
            const converted = try self.coerce(builder, argument, parameter.type, expression.position);
            try arguments.append(self.allocator, converted.value);
        }
    }
    if (signature.return_mode != .value) return self.fail(call_value.name_position, "borrowed callback returns are not executable yet");
    const result = if (signature.return_type == .void) null else try self.newValue(builder, signature.return_type);
    try self.emit(builder, .{ .indirect_call = .{ .result = result, .callee = callee.value, .arguments = try arguments.toOwnedSlice(self.allocator) } });
    for (mutable_arguments.items) |argument| try MutableReferences.writeBack(self, builder, argument.prepared);
    return .{ .value = if (result) |value| .{ .type = signature.return_type, .value = value } else null };
}

const MutableArgument = struct { prepared: MutableReferences.Prepared };

fn inferType(self: anytype, builder: anytype, expression: *const Ast.Expression) ?Ast.Type {
    return switch (expression.value) {
        .identifier => |name| if (Support.findBinding(builder.bindings.items, name)) |binding| binding.type else null,
        .field_access => |access| field_value: {
            const base = inferType(self, builder, access.base) orelse break :field_value null;
            const structure_index = base.structureIndex() orelse break :field_value null;
            if (structure_index >= self.structures.len) break :field_value null;
            for (self.structures[structure_index].fields) |field| if (std.mem.eql(u8, field.name, access.name)) break :field_value field.type;
            break :field_value null;
        },
        else => null,
    };
}

fn matches(signature: Ast.FunctionType, function: Ast.Function) bool {
    if (signature.return_type != function.return_type or signature.return_mode != function.return_mode or signature.parameters.len != function.parameters.len) return false;
    for (signature.parameters, function.parameters) |expected, actual| {
        if (expected.type != actual.type or expected.mode != actual.mode) return false;
    }
    return true;
}

fn visible(self: anytype, function: Ast.Function, file: usize) bool {
    if (function.is_internal) return function.position.file == file;
    if (function.is_public or function.position.file == file) return true;
    const context = self.module_context orelse return false;
    const separator = std.mem.lastIndexOfScalar(u8, function.name, '.') orelse return false;
    return std.mem.eql(u8, logicalModule(function.name[0..separator]), logicalModule(context));
}

fn logicalModule(module: []const u8) []const u8 {
    if (std.mem.endsWith(u8, module, ".$Platform")) return module[0 .. module.len - ".$Platform".len];
    if (std.mem.endsWith(u8, module, ".$Target")) return module[0 .. module.len - ".$Target".len];
    return module;
}

fn nameMatches(candidate: []const u8, requested: []const u8) bool {
    if (std.mem.eql(u8, candidate, requested)) return true;
    if (!std.mem.endsWith(u8, candidate, requested) or candidate.len == requested.len) return false;
    return candidate[candidate.len - requested.len - 1] == '.';
}

fn findBinding(bindings: []const Model.Binding, requested: []const u8) ?Model.Binding {
    if (Support.findBinding(bindings, requested)) |binding| return binding;
    const dot = std.mem.lastIndexOfScalar(u8, requested, '.') orelse return null;
    return Support.findBinding(bindings, requested[dot + 1 ..]);
}
