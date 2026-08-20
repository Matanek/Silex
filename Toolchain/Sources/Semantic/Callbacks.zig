const std = @import("std");
const ModuleScopes = @import("../ModuleScopes.zig");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Borrowing = @import("Borrowing.zig");
const Collections = @import("Collections.zig");
const MutableReferences = @import("MutableReferences.zig");
const Optionals = @import("Optionals.zig");
const Support = @import("Support.zig");
const Resources = @import("Resources.zig");
const Visibility = @import("Visibility.zig");
const Inheritance = @import("Inheritance.zig");

pub const BoundMethod = struct {
    owner: usize,
    method_index: usize,
    function_type: Ast.Type,
};

pub fn memberReference(
    self: anytype,
    builder: anytype,
    access: Ast.Expression.FieldAccess,
    expected: ?Ast.Type,
) !?Model.TypedValue {
    if (access.safe) return null;
    if (access.base.value == .identifier and Support.findBinding(builder.bindings.items, access.base.value.identifier) == null) return null;
    if (access.base.value == .field_access and rootBinding(builder.bindings.items, access.base) == null) return null;
    if (inferType(self, builder, access.base)) |known_type| if (known_type.structureIndex()) |known_structure| {
        if (known_structure >= self.structures.len) return null;
    };

    const base = try self.analyzeExpression(builder, access.base);
    const structure_index = base.type.structureIndex() orelse return @as(?Model.TypedValue, try self.analyzeFieldValue(builder, access, base));
    if (structure_index >= self.program.structures.len) return null;
    const candidates = try Inheritance.methodCandidates(self, self.allocator, structure_index, access.name);

    var field_type: ?Ast.Type = null;
    for (self.structures[structure_index].fields) |field| if (std.mem.eql(u8, field.name, access.name)) {
        field_type = field.type;
        break;
    };

    var selected: ?Inheritance.MethodCandidate = null;
    var selected_type: ?Ast.Type = null;
    for (candidates) |candidate| {
        if (!Visibility.memberVisible(self, candidate.owner, candidate.method, access.name_position)) continue;
        if (candidate.method.return_mode != .value) continue;
        const function_type = functionTypeForMethod(self.program, candidate.method, expected);
        if (expected != null and function_type == null) continue;
        if (selected != null) {
            const message = try std.fmt.allocPrint(self.allocator, "method reference '{s}' is ambiguous", .{access.name});
            return self.fail(access.name_position, message);
        }
        selected = candidate;
        selected_type = function_type;
    }

    const field_matches = if (expected) |target| field_type != null and field_type.? == target else field_type != null;
    if (selected == null) return @as(?Model.TypedValue, try self.analyzeFieldValue(builder, access, base));
    if (selected_type == null) return self.fail(access.name_position, "method reference has no representable callback signature");
    if (field_matches) {
        const message = try std.fmt.allocPrint(self.allocator, "member reference '{s}' is ambiguous between a stored field and a method", .{access.name});
        return self.fail(access.name_position, message);
    }

    const method = selected.?.method;
    const flat = flatMethodIndex(self.program, selected.?.owner, selected.?.index);
    const mutating = self.method_mutability[flat];
    if (mutating) switch (access.base.value) {
        .identifier, .field_access, .index_access => {},
        else => return self.fail(access.name_position, "a bound mutating method requires a stable mutable receiver place"),
    };
    const receiver_reference = if (mutating) mutable: {
        const prepared = try MutableReferences.prepare(self, builder, access.base, base.type);
        if (prepared.temporary != null) return self.fail(access.name_position, "a bound mutating method requires a stable mutable receiver place");
        break :mutable prepared.reference;
    } else try readReference(self, builder, access.base, base);

    const wrapper_index = self.bound_methods.items.len;
    try self.bound_methods.append(self.allocator, .{
        .owner = selected.?.owner,
        .method_index = selected.?.index,
        .function_type = selected_type.?,
    });
    const wrapper = boundWrapperBase(self.program) + wrapper_index;
    const result = try self.newValue(builder, selected_type.?);
    try self.emit(builder, .{ .function_reference = .{
        .result = result,
        .function = wrapper,
        .captures = try self.allocator.dupe(Ir.ValueId, &.{receiver_reference}),
    } });
    _ = method;
    const lexical_borrows = if (Borrowing.rootName(access.base)) |root|
        try self.allocator.dupe(Model.LexicalBorrow, &.{.{ .root = root, .mode = if (mutating) .mutable else .read }})
    else
        &.{};
    return .{
        .type = selected_type.?,
        .value = result,
        .lexical_captures = true,
        .lexical_borrows = lexical_borrows,
    };
}

fn readReference(self: anytype, builder: anytype, expression: *const Ast.Expression, value: Model.TypedValue) !Ir.ValueId {
    if (expression.value == .identifier) if (Support.findBinding(builder.bindings.items, expression.value.identifier)) |binding| {
        if (binding.reference) |existing_reference| return existing_reference;
        if (binding.local) |local| {
            const local_reference = try self.newValue(builder, .address);
            try self.emit(builder, .{ .local_address = .{ .result = local_reference, .local = local } });
            return local_reference;
        }
    };
    const local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, value.type);
    try self.emit(builder, .{ .local_store = .{ .local = local, .operand = value.value } });
    const local_reference = try self.newValue(builder, .address);
    try self.emit(builder, .{ .local_address = .{ .result = local_reference, .local = local } });
    return local_reference;
}

fn rootBinding(bindings: []const Model.Binding, expression: *const Ast.Expression) ?Model.Binding {
    return switch (expression.value) {
        .identifier => |name| Support.findBinding(bindings, name),
        .field_access => |field| rootBinding(bindings, field.base),
        .index_access => |index| rootBinding(bindings, index.base),
        else => null,
    };
}

fn functionTypeForMethod(program: Ast.Program, method: Ast.Function, expected: ?Ast.Type) ?Ast.Type {
    if (expected) |target| {
        const index = target.functionIndex() orelse return null;
        if (index >= program.function_types.len or !callableMatches(program.function_types[index], method)) return null;
        return target;
    }
    var found: ?Ast.Type = null;
    for (program.function_types, 0..) |signature, index| if (matches(signature, method)) {
        if (found != null) return null;
        found = .function(index);
    };
    return found;
}

fn flatMethodIndex(program: Ast.Program, structure_index: usize, method_index: usize) usize {
    var result = method_index;
    for (program.structures[0..structure_index]) |structure| result += structure.methods.len;
    return result;
}

fn callableMatches(signature: Ast.FunctionType, method: Ast.Function) bool {
    if (signature.return_type != method.return_type or signature.return_mode != method.return_mode or signature.parameters.len > method.parameters.len) return false;
    for (signature.parameters, method.parameters[0..signature.parameters.len]) |expected, actual| {
        if (expected.type != actual.type or expected.mode != actual.mode) return false;
    }
    for (method.parameters[signature.parameters.len..]) |parameter| if (parameter.default == null) return false;
    return true;
}

pub fn boundWrapperBase(program: Ast.Program) Ir.FunctionId {
    var result = program.functions.len;
    for (program.structures) |structure| if (!structure.is_protocol) {
        result += structure.constructors.len;
    };
    for (program.structures) |structure| {
        if (!structure.is_protocol) result += structure.methods.len;
    }
    for (program.structures) |structure| {
        if (structure.drop != null) result += 1;
    }
    for (program.structures) |structure| {
        if (structure.is_class and !structure.is_static) result += 1;
    }
    return result;
}

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
    for (self.program.structures, 0..) |structure, structure_index| {
        if (structure.is_protocol) continue;
        for (structure.methods, 0..) |method, method_index| {
            if (!method.is_static or !staticMethodNameMatches(structure.name, method.name, name) or
                !Visibility.memberVisible(self, structure_index, method, position) or !matches(signature, method)) continue;
            if (selected != null) {
                const message = try std.fmt.allocPrint(self.allocator, "function reference '{s}' is ambiguous for the expected callback type", .{name});
                return self.fail(position, message);
            }
            selected = methodFunctionId(self.program, structure_index, method_index);
        }
    }
    const function_id = selected orelse return null;
    const result = try self.newValue(builder, expected);
    const captures = try self.prepareAnonymousCaptures(builder, function_id);
    try self.emit(builder, .{ .function_reference = .{ .result = result, .function = function_id, .captures = captures } });
    return .{ .type = expected, .value = result, .lexical_captures = captures.len != 0 };
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
    const captures = try self.prepareAnonymousCaptures(builder, function_id);
    try self.emit(builder, .{ .function_reference = .{ .result = result, .function = function_id, .captures = captures } });
    return .{ .type = type_value, .value = result, .lexical_captures = captures.len != 0 };
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
            if (parameter.mode == .value and Resources.requiresRetain(self, parameter.type)) {
                try Resources.retainValue(self, builder, parameter.type, converted.value);
            }
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
    if (function.is_local) return function.position.file == file;
    if (function.is_public or function.position.file == file) return true;
    if (function.is_internal) return Visibility.packageVisible(self, function.owner);
    if ((self.owner_context orelse return false) != function.owner) return false;
    const context = self.module_context orelse return false;
    const separator = std.mem.lastIndexOfScalar(u8, function.name, '.') orelse return false;
    return ModuleScopes.same(self.module_scope_roots, function.name[0..separator], context);
}

fn nameMatches(candidate: []const u8, requested: []const u8) bool {
    if (std.mem.eql(u8, candidate, requested)) return true;
    if (!std.mem.endsWith(u8, candidate, requested) or candidate.len == requested.len) return false;
    return candidate[candidate.len - requested.len - 1] == '.';
}

fn staticMethodNameMatches(structure: []const u8, method: []const u8, requested: []const u8) bool {
    const dot = std.mem.lastIndexOfScalar(u8, requested, '.') orelse return false;
    return std.mem.eql(u8, requested[dot + 1 ..], method) and nameMatches(structure, requested[0..dot]);
}

fn methodFunctionId(program: Ast.Program, structure_index: usize, method_index: usize) Ir.FunctionId {
    var result = program.functions.len;
    for (program.structures) |structure| result += structure.constructors.len;
    for (program.structures[0..structure_index]) |structure| if (!structure.is_protocol) {
        result += structure.methods.len;
    };
    return result + method_index;
}

fn findBinding(bindings: []const Model.Binding, requested: []const u8) ?Model.Binding {
    if (Support.findBinding(bindings, requested)) |binding| return binding;
    const dot = std.mem.lastIndexOfScalar(u8, requested, '.') orelse return null;
    return Support.findBinding(bindings, requested[dot + 1 ..]);
}
