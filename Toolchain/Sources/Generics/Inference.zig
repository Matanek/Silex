const Types = @import("Types.zig");
const Support = @import("Support.zig");
const std = Types.std;
const Ast = Types.Ast;
const Source = Types.Source;
const Allocator = Types.Allocator;
const SpecializeError = Types.SpecializeError;
const functionIsVisible = Support.functionIsVisible;
const fileSetContains = Support.fileSetContains;
const methodOwnerMatches = Support.methodOwnerMatches;
const positionsEqual = Support.positionsEqual;

pub const CallableFrame = struct {
    local_count: usize,
    frame_start: usize,
};

const InferredCandidate = struct {
    template: *const Ast.Function,
    target: ?[]const u8 = null,
    arguments: []const Ast.TypeName,
};

fn inferredCandidatesContain(candidates: []const InferredCandidate, candidate: InferredCandidate) bool {
    for (candidates) |existing| {
        if (!positionsEqual(existing.template.name_position, candidate.template.name_position)) continue;
        if ((existing.target == null) != (candidate.target == null)) continue;
        if (existing.target) |target| {
            if (!std.mem.eql(u8, target, candidate.target.?)) continue;
        }
        if (existing.arguments.len != candidate.arguments.len) continue;
        var arguments_match = true;
        for (existing.arguments, candidate.arguments) |left, right| {
            if (!typeNamesEqual(left, right)) arguments_match = false;
        }
        if (arguments_match) return true;
    }
    return false;
}

pub fn beginInferenceCallable(self: anytype) CallableFrame {
    const frame = CallableFrame{
        .local_count = self.inferred_locals.items.len,
        .frame_start = self.inference_frame_start,
    };
    self.inference_frame_start = self.inferred_locals.items.len;
    return frame;
}

pub fn endInferenceCallable(self: anytype, frame: CallableFrame) void {
    self.inferred_locals.shrinkRetainingCapacity(frame.local_count);
    self.inference_frame_start = frame.frame_start;
}

pub fn addInferredLocal(self: anytype, name: []const u8, type_value: Ast.TypeName) Allocator.Error!void {
    try self.inferred_locals.append(self.allocator, .{ .name = name, .type = type_value });
}

pub fn inferredLocalType(self: anytype, name: []const u8) ?Ast.TypeName {
    var index = self.inferred_locals.items.len;
    while (index > self.inference_frame_start) {
        index -= 1;
        const local = self.inferred_locals.items[index];
        if (std.mem.eql(u8, local.name, name)) return local.type;
    }
    return null;
}

pub fn typeNamesEqual(left: Ast.TypeName, right: Ast.TypeName) bool {
    if (std.meta.activeTag(left) != std.meta.activeTag(right)) return false;
    return switch (left) {
        .structure => |name| std.mem.eql(u8, name, right.structure),
        .generic_structure => |generic| genericTypesEqual(generic, right.generic_structure),
        .type_parameter => |name| std.mem.eql(u8, name, right.type_parameter),
        .list => |element| typeNamesEqual(element.*, right.list.*),
        .fixed_array => |array| std.mem.eql(u8, array.length, right.fixed_array.length) and
            typeNamesEqual(array.element.*, right.fixed_array.element.*),
        .view => |element| typeNamesEqual(element.*, right.view.*),
        .reference => |reference| reference.mutable == right.reference.mutable and
            typeNamesEqual(reference.target.*, right.reference.target.*),
        .function => |function| functionTypesEqual(function, right.function),
        .optional => |contained| typeNamesEqual(contained.*, right.optional.*),
        else => true,
    };
}

fn genericTypesEqual(left: Ast.TypeName.GenericStructure, right: Ast.TypeName.GenericStructure) bool {
    if (!std.mem.eql(u8, left.name, right.name) or left.arguments.len != right.arguments.len) return false;
    for (left.arguments, right.arguments) |left_argument, right_argument| {
        if (!typeNamesEqual(left_argument, right_argument)) return false;
    }
    return true;
}

fn functionTypesEqual(left: Ast.TypeName.FunctionType, right: Ast.TypeName.FunctionType) bool {
    if (left.deferred != right.deferred or left.isolated != right.isolated or
        left.parameters.len != right.parameters.len or
        left.parameter_modes.len != right.parameter_modes.len or
        (left.return_type == null) != (right.return_type == null)) return false;
    for (left.parameters, right.parameters) |left_parameter, right_parameter| {
        if (!typeNamesEqual(left_parameter, right_parameter)) return false;
    }
    for (left.parameter_modes, right.parameter_modes) |left_mode, right_mode| {
        if (left_mode != right_mode) return false;
    }
    if (left.return_type) |return_type| {
        if (!typeNamesEqual(return_type.*, right.return_type.?.*)) return false;
    }
    return true;
}

fn returnTypeName(value: Ast.ReturnType) Ast.TypeName {
    return switch (value) {
        .void => .void,
        .int => .int,
        .int8 => .int8,
        .int16 => .int16,
        .int32 => .int32,
        .int64 => .int64,
        .uint => .uint,
        .uint8 => .uint8,
        .uint16 => .uint16,
        .uint32 => .uint32,
        .uint64 => .uint64,
        .float => .float,
        .float32 => .float32,
        .float64 => .float64,
        .bool => .bool,
        .str => .str,
        .structure => |name| .{ .structure = name },
        .generic_structure => |generic| .{ .generic_structure = generic },
        .type_parameter => |name| .{ .type_parameter = name },
        .list => |element| .{ .list = element },
        .fixed_array => |array| .{ .fixed_array = array },
        .view => |element| .{ .view = element },
        .reference => |reference| .{ .reference = reference },
        .function => |function| .{ .function = function },
        .optional => |contained| .{ .optional = contained },
    };
}

fn availableStructure(self: anytype, name: []const u8) ?*const Ast.Structure {
    for (self.structures.items) |*structure| {
        if (std.mem.eql(u8, structure.name, name)) return structure;
    }
    for (self.program.structures) |*structure| {
        if (std.mem.eql(u8, structure.name, name)) return structure;
    }
    return null;
}

fn inferredSequenceType(self: anytype, values: []const *Ast.Expression) Allocator.Error!?Ast.TypeName {
    if (values.len == 0) return null;
    const first = try inferExpressionType(self, values[0]) orelse return null;
    for (values[1..]) |value| {
        const element = try inferExpressionType(self, value) orelse return null;
        if (!typeNamesEqual(first, element)) return null;
    }
    const element = try self.allocator.create(Ast.TypeName);
    element.* = first;
    return Ast.TypeName{ .list = element };
}

pub fn inferExpressionType(self: anytype, expression: *const Ast.Expression) Allocator.Error!?Ast.TypeName {
    return switch (expression.value) {
        .integer => .int,
        .floating => .float,
        .boolean => .bool,
        .string => .str,
        .null => null,
        .identifier => |name| self.inferredLocalType(name),
        .self => self.inference_self_type,
        .sequence_literal => |values| try inferredSequenceType(self, values),
        .structure_initializer => |initializer| .{ .structure = initializer.name },
        .class_initializer => |initializer| .{ .structure = initializer.name },
        .conversion => |conversion| conversion.target_type,
        .move_expression => |move_value| try inferExpressionType(self, move_value.operand),
        .borrow_expression => |borrow| borrow_type: {
            const target = try inferExpressionType(self, borrow.operand) orelse break :borrow_type null;
            const pointer = try self.allocator.create(Ast.TypeName);
            pointer.* = target;
            break :borrow_type Ast.TypeName{ .reference = .{ .target = pointer, .mutable = false } };
        },
        .unary => |unary| switch (unary.operator) {
            .logical_not => .bool,
            .borrow => borrow_type: {
                const target = try inferExpressionType(self, unary.operand) orelse break :borrow_type null;
                const pointer = try self.allocator.create(Ast.TypeName);
                pointer.* = target;
                break :borrow_type Ast.TypeName{ .reference = .{ .target = pointer, .mutable = false } };
            },
            .dereference => dereference: {
                const operand = try inferExpressionType(self, unary.operand) orelse break :dereference null;
                if (operand != .reference) break :dereference null;
                break :dereference operand.reference.target.*;
            },
            .numeric_negate => try inferExpressionType(self, unary.operand),
        },
        .lambda => |lambda| lambda_type: {
            var parameters: std.ArrayList(Ast.TypeName) = .empty;
            var modes: std.ArrayList(Ast.ParameterMode) = .empty;
            for (lambda.parameters) |parameter| {
                try parameters.append(self.allocator, parameter.type);
                try modes.append(self.allocator, parameter.mode);
            }
            const return_type = if (lambda.return_type == .void) null else value: {
                const pointer = try self.allocator.create(Ast.TypeName);
                pointer.* = returnTypeName(lambda.return_type);
                break :value pointer;
            };
            break :lambda_type Ast.TypeName{ .function = .{
                .deferred = lambda.deferred,
                .isolated = lambda.isolated,
                .parameters = try parameters.toOwnedSlice(self.allocator),
                .parameter_modes = try modes.toOwnedSlice(self.allocator),
                .return_type = return_type,
            } };
        },
        .call => |call| call_type: {
            for (self.functions.items) |function| {
                if (std.mem.eql(u8, function.name, call.name) and parametersAcceptArity(function.parameters, call.arguments.len)) {
                    break :call_type returnTypeName(function.return_type);
                }
            }
            if (availableStructure(self, call.name) != null) break :call_type Ast.TypeName{ .structure = call.name };
            break :call_type null;
        },
        .static_method_call => |call| method_type: {
            const owner_name = switch (call.owner) {
                .structure => |name| name,
                else => break :method_type null,
            };
            const structure = availableStructure(self, owner_name) orelse break :method_type null;
            for (structure.methods) |method| {
                if (method.is_static and std.mem.eql(u8, method.name, call.name) and parametersAcceptArity(method.parameters, call.arguments.len)) {
                    break :method_type returnTypeName(method.return_type);
                }
            }
            break :method_type null;
        },
        .method_call => |call| method_type: {
            const object_type = try inferExpressionType(self, call.object) orelse break :method_type null;
            const owner_name = structureName(object_type) orelse break :method_type null;
            if (availableStructure(self, owner_name)) |structure| {
                for (structure.methods) |method| {
                    if (!method.is_static and std.mem.eql(u8, method.name, call.name) and parametersAcceptArity(method.parameters, call.arguments.len)) {
                        break :method_type returnTypeName(method.return_type);
                    }
                }
            }
            for (self.method_specializations.items) |specialization| {
                if (!std.mem.eql(u8, specialization.target_name, owner_name) or
                    !std.mem.eql(u8, specialization.name, call.name)) continue;
                const method = specialization.method orelse continue;
                break :method_type returnTypeName(method.return_type);
            }
            break :method_type null;
        },
        .member_access => |member| member_type: {
            const object_type = try inferExpressionType(self, member.object) orelse break :member_type null;
            const owner_name = structureName(object_type) orelse break :member_type null;
            const structure = availableStructure(self, owner_name) orelse break :member_type null;
            for (structure.fields) |field| {
                if (std.mem.eql(u8, field.name, member.name)) break :member_type field.type;
            }
            break :member_type null;
        },
        .static_field_access => |access| field_type: {
            const owner_name = switch (access.owner) {
                .structure => |name| name,
                else => break :field_type null,
            };
            const structure = availableStructure(self, owner_name) orelse break :field_type null;
            for (structure.fields) |field| {
                if (field.is_static and std.mem.eql(u8, field.name, access.name)) break :field_type field.type;
            }
            break :field_type null;
        },
        .index_access => |access| index_type: {
            const object_type = try inferExpressionType(self, access.object) orelse break :index_type null;
            break :index_type switch (object_type) {
                .list => |element| element.*,
                .fixed_array => |array| array.element.*,
                .view => |element| element.*,
                else => null,
            };
        },
        .binary => |binary| binary_type: {
            switch (binary.operator) {
                .logical_or, .logical_and, .equal, .not_equal, .less, .less_equal, .greater, .greater_equal => break :binary_type .bool,
                else => {},
            }
            const left = try inferExpressionType(self, binary.left) orelse break :binary_type null;
            const right = try inferExpressionType(self, binary.right) orelse break :binary_type null;
            if (typeNamesEqual(left, right)) break :binary_type left;
            break :binary_type null;
        },
        else => null,
    };
}

fn structureName(value: Ast.TypeName) ?[]const u8 {
    return switch (value) {
        .structure => |name| name,
        .reference => |reference| structureName(reference.target.*),
        else => null,
    };
}

fn argumentType(self: anytype, expression: *const Ast.Expression, mode: Ast.ParameterMode) Allocator.Error!?Ast.TypeName {
    const inferred = try inferExpressionType(self, expression) orelse return null;
    if (mode == .value) return inferred;
    return if (inferred == .reference) inferred.reference.target.* else inferred;
}

fn specializationArguments(self: anytype, actual: Ast.TypeName, template_name: []const u8) ?[]const Ast.TypeName {
    const name = switch (actual) {
        .structure => |value| value,
        else => return null,
    };
    for (self.structure_specializations.items) |specialization| {
        if (std.mem.eql(u8, specialization.name, name) and std.mem.eql(u8, specialization.template_name, template_name)) {
            return specialization.arguments;
        }
    }
    for (self.enum_specializations.items) |specialization| {
        if (std.mem.eql(u8, specialization.name, name) and std.mem.eql(u8, specialization.template_name, template_name)) {
            return specialization.arguments;
        }
    }
    return null;
}

fn bindType(
    self: anytype,
    pattern: Ast.TypeName,
    actual: Ast.TypeName,
    parameters: []const Ast.TypeParameter,
    inferred: []?Ast.TypeName,
) bool {
    switch (pattern) {
        .structure => |name| {
            for (parameters, 0..) |parameter, index| {
                if (!std.mem.eql(u8, parameter.name, name)) continue;
                if (inferred[index]) |existing| return typeNamesEqual(existing, actual);
                inferred[index] = actual;
                return true;
            }
            return typesCompatible(pattern, actual);
        },
        .type_parameter => |name| {
            for (parameters, 0..) |parameter, index| {
                if (!std.mem.eql(u8, parameter.name, name)) continue;
                if (inferred[index]) |existing| return typeNamesEqual(existing, actual);
                inferred[index] = actual;
                return true;
            }
            return false;
        },
        .generic_structure => |generic| {
            const actual_arguments = if (actual == .generic_structure and std.mem.eql(u8, actual.generic_structure.name, generic.name))
                actual.generic_structure.arguments
            else
                specializationArguments(self, actual, generic.name) orelse return false;
            if (generic.arguments.len != actual_arguments.len) return false;
            for (generic.arguments, actual_arguments) |pattern_argument, actual_argument| {
                if (!bindType(self, pattern_argument, actual_argument, parameters, inferred)) return false;
            }
            return true;
        },
        .list => |element| return actual == .list and bindType(self, element.*, actual.list.*, parameters, inferred),
        .fixed_array => |array| return actual == .fixed_array and
            std.mem.eql(u8, array.length, actual.fixed_array.length) and
            bindType(self, array.element.*, actual.fixed_array.element.*, parameters, inferred),
        .view => |element| return actual == .view and bindType(self, element.*, actual.view.*, parameters, inferred),
        .reference => |reference| return actual == .reference and reference.mutable == actual.reference.mutable and
            bindType(self, reference.target.*, actual.reference.target.*, parameters, inferred),
        .optional => |contained| {
            if (actual == .optional) return bindType(self, contained.*, actual.optional.*, parameters, inferred);
            return bindType(self, contained.*, actual, parameters, inferred);
        },
        .function => |function| {
            if (actual != .function or function.deferred != actual.function.deferred or
                (!function.isolated and actual.function.isolated) or
                function.parameters.len != actual.function.parameters.len or
                (function.return_type == null) != (actual.function.return_type == null)) return false;
            for (function.parameters, actual.function.parameters) |pattern_parameter, actual_parameter| {
                if (!bindType(self, pattern_parameter, actual_parameter, parameters, inferred)) return false;
            }
            if (function.return_type) |return_type| {
                if (!bindType(self, return_type.*, actual.function.return_type.?.*, parameters, inferred)) return false;
            }
            return true;
        },
        else => return typesCompatible(pattern, actual),
    }
}

fn typesCompatible(expected: Ast.TypeName, actual: Ast.TypeName) bool {
    if (typeNamesEqual(expected, actual)) return true;
    if (expected == .optional) return typesCompatible(expected.optional.*, actual);
    if (isFloat(expected) and (isFloat(actual) or isInteger(actual))) return true;
    if (integerInfo(expected)) |expected_integer| {
        const actual_integer = integerInfo(actual) orelse return false;
        return expected_integer.signed == actual_integer.signed and expected_integer.bits >= actual_integer.bits;
    }
    return false;
}

const IntegerInfo = struct { signed: bool, bits: u8 };

fn integerInfo(value: Ast.TypeName) ?IntegerInfo {
    return switch (value) {
        .int, .int64 => .{ .signed = true, .bits = 64 },
        .int8 => .{ .signed = true, .bits = 8 },
        .int16 => .{ .signed = true, .bits = 16 },
        .int32 => .{ .signed = true, .bits = 32 },
        .uint, .uint64 => .{ .signed = false, .bits = 64 },
        .uint8 => .{ .signed = false, .bits = 8 },
        .uint16 => .{ .signed = false, .bits = 16 },
        .uint32 => .{ .signed = false, .bits = 32 },
        else => null,
    };
}

fn isInteger(value: Ast.TypeName) bool {
    return integerInfo(value) != null;
}

fn isFloat(value: Ast.TypeName) bool {
    return value == .float or value == .float32 or value == .float64;
}

fn inferArguments(
    self: anytype,
    template: *const Ast.Function,
    expressions: []const *Ast.Expression,
) Allocator.Error!?[]const Ast.TypeName {
    if (!parametersAcceptArity(template.parameters, expressions.len)) return null;
    const inferred = try self.allocator.alloc(?Ast.TypeName, template.type_parameters.len);
    @memset(inferred, null);
    for (template.parameters[0..expressions.len], expressions) |parameter, expression| {
        const actual = try argumentType(self, expression, parameter.mode) orelse return null;
        if (!bindType(self, parameter.type, actual, template.type_parameters, inferred)) return null;
    }
    var arguments = try self.allocator.alloc(Ast.TypeName, inferred.len);
    for (inferred, 0..) |argument, index| arguments[index] = argument orelse return null;
    return arguments;
}

fn requiredParameterCount(parameters: []const Ast.Parameter) usize {
    for (parameters, 0..) |parameter, index| {
        if (parameter.default_value != null) return index;
    }
    return parameters.len;
}

fn parametersAcceptArity(parameters: []const Ast.Parameter, argument_count: usize) bool {
    return argument_count >= requiredParameterCount(parameters) and argument_count <= parameters.len;
}

fn concreteFunctionCompatible(
    self: anytype,
    name: []const u8,
    expressions: []const *Ast.Expression,
    visible_declarations: ?[]const Source.Position,
) Allocator.Error!bool {
    for (self.program.functions) |function| {
        if (function.type_parameters.len != 0 or !std.mem.eql(u8, function.name, name) or
            !functionIsVisible(function, visible_declarations) or !parametersAcceptArity(function.parameters, expressions.len)) continue;
        var compatible = true;
        for (function.parameters[0..expressions.len], expressions) |parameter, expression| {
            const actual = try argumentType(self, expression, parameter.mode) orelse return true;
            if (!typesCompatible(parameter.type, actual)) compatible = false;
        }
        if (compatible) return true;
    }
    return false;
}

pub fn inferFunctionCall(
    self: anytype,
    name: []const u8,
    expressions: []const *Ast.Expression,
    visible_declarations: ?[]const Source.Position,
    position: Source.Position,
) SpecializeError!?[]const u8 {
    var has_generic = false;
    for (self.function_templates) |function| {
        if (function.type_parameters.len != 0 and std.mem.eql(u8, function.name, name) and
            functionIsVisible(function, visible_declarations)) has_generic = true;
    }
    if (!has_generic) return null;
    if (try concreteFunctionCompatible(self, name, expressions, visible_declarations)) return null;

    var candidates: std.ArrayList(InferredCandidate) = .empty;
    var constrained: ?InferredCandidate = null;
    for (self.function_templates) |*function| {
        if (function.type_parameters.len == 0 or !std.mem.eql(u8, function.name, name) or
            !functionIsVisible(function.*, visible_declarations)) continue;
        const arguments = try inferArguments(self, function, expressions) orelse continue;
        const candidate = InferredCandidate{ .template = function, .arguments = arguments };
        if (!self.typeArgumentsSatisfyConstraints(function.type_parameters, arguments, position.file)) {
            constrained = candidate;
            continue;
        }
        try candidates.append(self.allocator, candidate);
    }
    if (candidates.items.len == 0) {
        if (constrained) |candidate| try self.validateTypeArgumentConstraints(candidate.template.type_parameters, candidate.arguments, position);
        const message = try std.fmt.allocPrint(self.allocator, "generic function '{s}' cannot infer all type arguments; use explicit '<...>'", .{name});
        return self.fail(position, message);
    }
    if (candidates.items.len != 1) {
        const message = try std.fmt.allocPrint(self.allocator, "generic function '{s}' cannot infer unique type arguments; use explicit '<...>'", .{name});
        return self.fail(position, message);
    }
    const candidate = candidates.items[0];
    const specialized_name = try self.genericTypeName(name, candidate.arguments);
    try self.instantiateFunction(candidate.template.*, candidate.arguments, specialized_name, position);
    return specialized_name;
}

fn concreteMethodCompatible(
    self: anytype,
    owner_name: ?[]const u8,
    name: []const u8,
    expressions: []const *Ast.Expression,
    visibility_file: usize,
) Allocator.Error!bool {
    for (self.structures.items) |structure| {
        if (!methodOwnerMatches(self, owner_name, structure.name, true)) continue;
        for (structure.methods) |method| {
            if (method.type_parameters.len != 0 or method.is_static or !std.mem.eql(u8, method.name, name) or
                !parametersAcceptArity(method.parameters, expressions.len)) continue;
            var compatible = true;
            for (method.parameters[0..expressions.len], expressions) |parameter, expression| {
                const actual = try argumentType(self, expression, parameter.mode) orelse return true;
                if (!typesCompatible(parameter.type, actual)) compatible = false;
            }
            if (compatible) return true;
        }
    }
    for (self.program.extensions) |extension| {
        if (!methodOwnerMatches(self, owner_name, extension.target, false)) continue;
        for (extension.methods) |method| {
            if (method.type_parameters.len != 0 or method.is_static or !std.mem.eql(u8, method.name, name) or !parametersAcceptArity(method.parameters, expressions.len)) continue;
            if (method.extension_visible_files) |visible_files| {
                if (!fileSetContains(visible_files, visibility_file)) continue;
            }
            var compatible = true;
            for (method.parameters[0..expressions.len], expressions) |parameter, expression| {
                const actual = try argumentType(self, expression, parameter.mode) orelse return true;
                if (!typesCompatible(parameter.type, actual)) compatible = false;
            }
            if (compatible) return true;
        }
    }
    return false;
}

pub fn inferMethodCall(
    self: anytype,
    object: *const Ast.Expression,
    name: []const u8,
    expressions: []const *Ast.Expression,
    visibility_file: usize,
    position: Source.Position,
) SpecializeError!?[]const u8 {
    const owner_type = try inferExpressionType(self, object);
    const owner_name = if (owner_type) |type_value| structureName(type_value) else null;
    var candidates: std.ArrayList(InferredCandidate) = .empty;
    var constrained: ?InferredCandidate = null;
    var has_generic = false;

    for (self.program.structures) |structure| {
        if (!methodOwnerMatches(self, owner_name, structure.name, true)) continue;
        for (structure.methods) |*method| {
            if (method.type_parameters.len == 0 or method.is_static or !std.mem.eql(u8, method.name, name)) continue;
            has_generic = true;
            const arguments = try inferArguments(self, method, expressions) orelse continue;
            const candidate = InferredCandidate{ .template = method, .target = structure.name, .arguments = arguments };
            if (!self.typeArgumentsSatisfyConstraints(method.type_parameters, arguments, visibility_file)) {
                constrained = candidate;
                continue;
            }
            if (!inferredCandidatesContain(candidates.items, candidate)) try candidates.append(self.allocator, candidate);
        }
    }
    for (self.program.extensions) |extension| {
        if (!methodOwnerMatches(self, owner_name, extension.target, false)) continue;
        for (extension.methods) |*method| {
            if (method.type_parameters.len == 0 or method.is_static or !std.mem.eql(u8, method.name, name)) continue;
            if (method.extension_visible_files) |visible_files| {
                if (!fileSetContains(visible_files, visibility_file)) continue;
            }
            has_generic = true;
            const arguments = try inferArguments(self, method, expressions) orelse continue;
            const candidate = InferredCandidate{ .template = method, .target = extension.target, .arguments = arguments };
            if (!self.typeArgumentsSatisfyConstraints(method.type_parameters, arguments, visibility_file)) {
                constrained = candidate;
                continue;
            }
            if (!inferredCandidatesContain(candidates.items, candidate)) try candidates.append(self.allocator, candidate);
        }
    }
    if (!has_generic) return null;
    if (try concreteMethodCompatible(self, owner_name, name, expressions, visibility_file)) return null;
    if (candidates.items.len == 0) {
        if (constrained) |candidate| try self.validateTypeArgumentConstraints(candidate.template.type_parameters, candidate.arguments, position);
        const message = try std.fmt.allocPrint(self.allocator, "generic method '{s}' cannot infer all type arguments; use explicit '<...>'", .{name});
        return self.fail(position, message);
    }
    if (candidates.items.len != 1) {
        const message = try std.fmt.allocPrint(self.allocator, "generic method '{s}' cannot infer unique type arguments; use explicit '<...>'", .{name});
        return self.fail(position, message);
    }
    const candidate = candidates.items[0];
    const specialized_name = try self.genericTypeName(name, candidate.arguments);
    try self.instantiateMethod(candidate.target.?, candidate.template.*, candidate.arguments, specialized_name, position);
    return specialized_name;
}

fn concreteStaticMethodCompatible(
    self: anytype,
    owner_name: []const u8,
    name: []const u8,
    expressions: []const *Ast.Expression,
    visibility_file: usize,
) Allocator.Error!bool {
    for (self.structures.items) |structure| {
        if (!std.mem.eql(u8, owner_name, structure.name)) continue;
        for (structure.methods) |method| {
            if (method.type_parameters.len != 0 or !method.is_static or !std.mem.eql(u8, method.name, name) or
                !parametersAcceptArity(method.parameters, expressions.len)) continue;
            var compatible = true;
            for (method.parameters[0..expressions.len], expressions) |parameter, expression| {
                const actual = try argumentType(self, expression, parameter.mode) orelse return true;
                if (!typesCompatible(parameter.type, actual)) compatible = false;
            }
            if (compatible) return true;
        }
    }
    for (self.program.extensions) |extension| {
        if (!std.mem.eql(u8, owner_name, extension.target)) continue;
        for (extension.methods) |method| {
            if (method.type_parameters.len != 0 or !method.is_static or !std.mem.eql(u8, method.name, name) or
                !parametersAcceptArity(method.parameters, expressions.len)) continue;
            if (method.extension_visible_files) |visible_files| {
                if (!fileSetContains(visible_files, visibility_file)) continue;
            }
            var compatible = true;
            for (method.parameters[0..expressions.len], expressions) |parameter, expression| {
                const actual = try argumentType(self, expression, parameter.mode) orelse return true;
                if (!typesCompatible(parameter.type, actual)) compatible = false;
            }
            if (compatible) return true;
        }
    }
    return false;
}

pub fn inferStaticMethodCall(
    self: anytype,
    owner: Ast.TypeName,
    name: []const u8,
    expressions: []const *Ast.Expression,
    visibility_file: usize,
    position: Source.Position,
) SpecializeError!?[]const u8 {
    const owner_name = switch (owner) {
        .structure => |value| value,
        else => return null,
    };
    var candidates: std.ArrayList(InferredCandidate) = .empty;
    var constrained: ?InferredCandidate = null;
    var has_generic = false;
    for (self.program.structures) |structure| {
        if (!std.mem.eql(u8, owner_name, structure.name)) continue;
        for (structure.methods) |*method| {
            if (method.type_parameters.len == 0 or !method.is_static or !std.mem.eql(u8, method.name, name)) continue;
            has_generic = true;
            const arguments = try inferArguments(self, method, expressions) orelse continue;
            const candidate = InferredCandidate{ .template = method, .target = structure.name, .arguments = arguments };
            if (!self.typeArgumentsSatisfyConstraints(method.type_parameters, arguments, visibility_file)) {
                constrained = candidate;
                continue;
            }
            if (!inferredCandidatesContain(candidates.items, candidate)) try candidates.append(self.allocator, candidate);
        }
    }
    for (self.program.extensions) |extension| {
        if (!std.mem.eql(u8, owner_name, extension.target)) continue;
        for (extension.methods) |*method| {
            if (method.type_parameters.len == 0 or !method.is_static or !std.mem.eql(u8, method.name, name)) continue;
            if (method.extension_visible_files) |visible_files| {
                if (!fileSetContains(visible_files, visibility_file)) continue;
            }
            has_generic = true;
            const arguments = try inferArguments(self, method, expressions) orelse continue;
            const candidate = InferredCandidate{ .template = method, .target = extension.target, .arguments = arguments };
            if (!self.typeArgumentsSatisfyConstraints(method.type_parameters, arguments, visibility_file)) {
                constrained = candidate;
                continue;
            }
            if (!inferredCandidatesContain(candidates.items, candidate)) try candidates.append(self.allocator, candidate);
        }
    }
    if (!has_generic) return null;
    if (try concreteStaticMethodCompatible(self, owner_name, name, expressions, visibility_file)) return null;
    if (candidates.items.len == 0) {
        if (constrained) |candidate| try self.validateTypeArgumentConstraints(candidate.template.type_parameters, candidate.arguments, position);
        const message = try std.fmt.allocPrint(self.allocator, "generic static method '{s}' cannot infer all type arguments; use explicit '<...>'", .{name});
        return self.fail(position, message);
    }
    if (candidates.items.len != 1) {
        const message = try std.fmt.allocPrint(self.allocator, "generic static method '{s}' cannot infer unique type arguments; use explicit '<...>'", .{name});
        return self.fail(position, message);
    }
    const candidate = candidates.items[0];
    const specialized_name = try self.genericTypeName(name, candidate.arguments);
    try self.instantiateMethod(candidate.target.?, candidate.template.*, candidate.arguments, specialized_name, position);
    return specialized_name;
}
