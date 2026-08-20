const std = @import("std");
const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");
const Arguments = @import("Arguments.zig");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const Support = @import("Support.zig");
const Visibility = @import("Visibility.zig");
const Optionals = @import("Optionals.zig");
const Model = @import("Model.zig");
const Resources = @import("Resources.zig");
const ShaderAssets = @import("../ShaderAssets.zig");
const GenericSyntax = @import("../Parser/Generics.zig");
const StaticInitialization = @import("StaticInitialization.zig");
const EvaluateError = Source.Error || std.mem.Allocator.Error;

pub const Field = struct {
    global: usize,
    owner: usize,
    declaration: Ast.StructureField,
};

pub fn ownerIndex(self: anytype, name: []const u8) ?usize {
    for (self.program.structures, 0..) |structure, index| if (std.mem.eql(u8, structure.name, name)) return index;
    if (self.resolveStructureIndex(name)) |nominal| if (nominal < self.structures.len) {
        for (self.program.structures, 0..) |structure, index| {
            if (std.mem.eql(u8, structure.name, self.structures[nominal].name)) return index;
        }
    };
    var suffix_match: ?usize = null;
    for (self.program.structures, 0..) |structure, index| {
        if (!std.mem.endsWith(u8, structure.name, name) or structure.name.len == name.len or
            structure.name[structure.name.len - name.len - 1] != '.') continue;
        if (suffix_match != null) return null;
        suffix_match = index;
    }
    return suffix_match;
}

pub fn prepare(self: anytype) ![]const Ir.Global {
    var field_count: usize = 0;
    for (self.program.structures) |structure| field_count += structure.static_fields.len;
    var evaluation = Evaluation{
        .states = try self.allocator.alloc(Evaluation.State, field_count),
        .values = try self.allocator.alloc(Constant, field_count),
    };
    @memset(evaluation.states, .pending);

    var globals: std.ArrayList(Ir.Global) = .empty;
    var global: usize = 0;
    for (self.program.structures) |structure| for (structure.static_fields) |field| {
        if (StaticInitialization.requiresRuntime(self, field.type)) {
            try globals.append(self.allocator, .{
                .name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ structure.name, field.name }),
                .type = field.type,
                .mutable = field.mutable,
                .runtime_initialized = true,
            });
            global += 1;
            continue;
        }
        if (!supportedType(self, field.type)) return self.fail(field.name_position, "static field type is not supported by the bootstrap runtime yet");
        const value = try evaluateField(self, &evaluation, global);
        const bits = try flattenConstant(self, value);
        try globals.append(self.allocator, .{
            .name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ structure.name, field.name }),
            .type = field.type,
            .mutable = field.mutable,
            .bits = if (bits.len == 0) 0 else bits[0],
            .extra_bits = if (bits.len <= 1) &.{} else bits[1..],
        });
        global += 1;
    };
    return globals.toOwnedSlice(self.allocator);
}

pub fn find(self: anytype, structure_index: usize, name: []const u8) ?Field {
    var global: usize = 0;
    for (self.program.structures, 0..) |structure, owner| {
        for (structure.static_fields) |field| {
            if (owner == structure_index and std.mem.eql(u8, field.name, name)) return .{
                .global = global,
                .owner = owner,
                .declaration = field,
            };
            global += 1;
        }
    }
    return null;
}

pub fn analyzeLoad(self: anytype, builder: anytype, structure_index: usize, name: []const u8, position: @import("../Source.zig").Position) !?@import("Model.zig").TypedValue {
    const field = find(self, structure_index, name) orelse return null;
    if (self.static_initialization_limit) |limit| if (self.globals[field.global].runtime_initialized and field.global >= limit) {
        return self.fail(position, "runtime static initializer can only read runtime fields declared earlier");
    };
    if (!Visibility.memberVisible(self, field.owner, field.declaration, position)) {
        const message = try std.fmt.allocPrint(self.allocator, "static field '{s}' is {s} and unavailable here", .{ name, Visibility.name(field.declaration) });
        return self.fail(position, message);
    }
    if (!field.declaration.mutable and (field.declaration.type.isNumeric() or field.declaration.type == .bool)) {
        const result = try self.newValue(builder, field.declaration.type);
        const bits = self.globals[field.global].bits;
        const instruction: Ir.Instruction = if (field.declaration.type.isInteger())
            .{ .constant_int = .{ .result = result, .bits = bits } }
        else if (field.declaration.type == .float32)
            .{ .constant_float32 = .{ .result = result, .bits = @intCast(bits) } }
        else if (field.declaration.type == .float64)
            .{ .constant_float64 = .{ .result = result, .bits = bits } }
        else
            .{ .constant_bool = .{ .result = result, .value = bits != 0 } };
        try self.emit(builder, instruction);
        return .{ .type = field.declaration.type, .value = result };
    }
    const result = try self.newValue(builder, field.declaration.type);
    try self.emit(builder, .{ .global_load = .{ .result = result, .global = field.global } });
    return .{ .type = field.declaration.type, .value = result };
}

pub fn analyzeCall(self: anytype, builder: anytype, structure_index: usize, call: Ast.Expression.Call) !?Model.TypedValue {
    const structure = self.program.structures[structure_index];
    if (try ShaderAssets.analyze(self, builder, structure_index, call)) |value| return value;
    if (call.named_arguments.len != 0) return analyzeNamedCall(self, builder, structure_index, call);
    var candidates: std.ArrayList(usize) = .empty;
    for (structure.methods, 0..) |method, index| {
        if (!method.is_static or !std.mem.eql(u8, method.name, call.name)) continue;
        if (!Visibility.memberVisible(self, structure_index, method, call.name_position)) continue;
        if (Support.acceptsArity(method.parameters, call.arguments.len)) try candidates.append(self.allocator, index);
    }
    if (candidates.items.len == 0) return self.fail(call.name_position, "type has no visible static method accepting these arguments");
    var arguments: std.ArrayList(Model.TypedValue) = .empty;
    for (call.arguments, 0..) |argument, index| {
        const expected = if (candidates.items.len == 1)
            Optionals.expectedContext(structure.methods[candidates.items[0]].parameters[index].type, argument)
        else
            null;
        try arguments.append(self.allocator, try self.analyzeExpressionExpected(builder, argument, expected));
    }
    var selected: ?usize = null;
    var best_cost: usize = std.math.maxInt(usize);
    for (candidates.items) |method_index| {
        const method = structure.methods[method_index];
        var cost: usize = 0;
        for (method.parameters[0..arguments.items.len], arguments.items) |parameter, argument| {
            if (!self.canImplicitlyConvert(argument.type, parameter.type)) break;
            if (argument.type != parameter.type) cost += 1;
        } else if (cost < best_cost) {
            selected = method_index;
            best_cost = cost;
        }
    }
    const method_index = selected orelse return self.fail(call.name_position, "no static method overload matches the argument types");
    const method = structure.methods[method_index];
    var ids: std.ArrayList(Ir.ValueId) = .empty;
    for (arguments.items, method.parameters[0..arguments.items.len], call.arguments) |argument, parameter, source| {
        if (parameter.mode != .value) return self.fail(source.position, "borrowed static method parameters are not supported yet");
        const converted = try self.coerce(builder, argument, parameter.type, source.position);
        if (Resources.requiresRetain(self, parameter.type) and !converted.transferred) try Resources.retainValue(self, builder, parameter.type, converted.value);
        try ids.append(self.allocator, converted.value);
    }
    for (method.parameters[arguments.items.len..]) |parameter| try ids.append(self.allocator, (try self.analyzeParameterDefault(builder, parameter)).value);
    const result = if (method.return_type == .void) null else try self.newValue(builder, method.return_type);
    try self.emit(builder, .{ .call = .{
        .result = result,
        .function = methodFunctionId(self.program, structure_index, method_index),
        .arguments = try ids.toOwnedSlice(self.allocator),
    } });
    return if (result) |value| .{ .type = method.return_type, .value = value, .transferred = Resources.ownsValue(self, method.return_type) } else null;
}

fn analyzeNamedCall(self: anytype, builder: anytype, structure_index: usize, call: Ast.Expression.Call) !?Model.TypedValue {
    const structure = self.program.structures[structure_index];
    var candidates: std.ArrayList(usize) = .empty;
    var first_problem: ?Arguments.Problem = null;
    var template: ?[]const ?*Ast.Expression = null;
    for (structure.methods, 0..) |method, index| {
        if (!method.is_static or !std.mem.eql(u8, method.name, call.name)) continue;
        if (!Visibility.memberVisible(self, structure_index, method, call.name_position)) continue;
        switch (try Arguments.map(self.allocator, method.parameters, call.arguments, call.named_arguments)) {
            .arguments => |mapped| {
                try candidates.append(self.allocator, index);
                if (template == null) template = mapped;
            },
            .problem => |problem| {
                if (first_problem == null) first_problem = problem;
            },
        }
    }
    if (candidates.items.len == 0) {
        const problem = first_problem orelse .too_many;
        const message = switch (problem) {
            .too_many => "type has no visible static method accepting these arguments",
            .unknown => |argument| try std.fmt.allocPrint(self.allocator, "unknown parameter label '{s}'", .{argument.name}),
            .duplicate => |argument| try std.fmt.allocPrint(self.allocator, "parameter '{s}' is provided more than once", .{argument.name}),
            .missing => |parameter| try std.fmt.allocPrint(self.allocator, "required parameter '{s}' is missing", .{parameter.name}),
        };
        const position = switch (problem) {
            .unknown => |a| a.position,
            .duplicate => |a| a.position,
            else => call.name_position,
        };
        return self.fail(position, message);
    }
    const sources = template.?;
    const typed = try self.allocator.alloc(?Model.TypedValue, sources.len);
    @memset(typed, null);
    for (sources, 0..) |maybe_source, index| {
        const source = maybe_source orelse continue;
        const expected = if (candidates.items.len == 1) Optionals.expectedContext(structure.methods[candidates.items[0]].parameters[index].type, source) else null;
        typed[index] = try self.analyzeExpressionExpected(builder, source, expected);
    }
    var selected: ?usize = null;
    var best_cost: usize = std.math.maxInt(usize);
    var ambiguous = false;
    for (candidates.items) |index| {
        const method = structure.methods[index];
        const mapped = (try Arguments.map(self.allocator, method.parameters, call.arguments, call.named_arguments)).arguments;
        var cost: usize = 0;
        for (mapped, 0..) |maybe_source, parameter_index| {
            if (maybe_source == null) continue;
            const argument = typed[parameter_index].?;
            if (!self.canImplicitlyConvert(argument.type, method.parameters[parameter_index].type)) break;
            if (argument.type != method.parameters[parameter_index].type) cost += 1;
        } else if (cost < best_cost) {
            selected = index;
            best_cost = cost;
            ambiguous = false;
        } else if (cost == best_cost) ambiguous = true;
    }
    if (ambiguous) return self.fail(call.name_position, "call to static method is ambiguous");
    const method_index = selected orelse return self.fail(call.name_position, "no static method overload matches the argument types");
    const method = structure.methods[method_index];
    const mapped = (try Arguments.map(self.allocator, method.parameters, call.arguments, call.named_arguments)).arguments;
    var ids: std.ArrayList(Ir.ValueId) = .empty;
    for (method.parameters, mapped, 0..) |parameter, maybe_source, index| {
        const source = maybe_source orelse {
            try ids.append(self.allocator, (try self.analyzeParameterDefault(builder, parameter)).value);
            continue;
        };
        if (parameter.mode != .value) return self.fail(source.position, "borrowed static method parameters are not supported yet");
        const converted = try self.coerce(builder, typed[index].?, parameter.type, source.position);
        if (Resources.requiresRetain(self, parameter.type) and !converted.transferred) try Resources.retainValue(self, builder, parameter.type, converted.value);
        try ids.append(self.allocator, converted.value);
    }
    const result = if (method.return_type == .void) null else try self.newValue(builder, method.return_type);
    try self.emit(builder, .{ .call = .{ .result = result, .function = methodFunctionId(self.program, structure_index, method_index), .arguments = try ids.toOwnedSlice(self.allocator) } });
    return if (result) |value| .{ .type = method.return_type, .value = value, .transferred = Resources.ownsValue(self, method.return_type) } else null;
}

fn methodFunctionId(program: Ast.Program, structure_index: usize, method_index: usize) Ir.FunctionId {
    var result = program.functions.len;
    for (program.structures) |structure| result += structure.constructors.len;
    for (program.structures[0..structure_index]) |structure| {
        if (!structure.is_protocol) result += structure.methods.len;
    }
    return result + method_index;
}

fn supportedType(self: anytype, type_value: Ast.Type) bool {
    if (type_value.isNumeric() or type_value == .bool) return true;
    if (type_value.optionalChild()) |child| return isClassType(self, child);
    return supportedValueStructure(self, type_value, 0);
}

fn supportedValueStructure(self: anytype, type_value: Ast.Type, depth: usize) bool {
    if (depth >= 64) return false;
    const index = type_value.structureIndex() orelse return false;
    if (index >= self.structures.len) return false;
    const structure = self.structures[index];
    if (structure.is_class or structure.is_protocol or structure.is_static or structure.collection != null or structure.fields.len == 0) return false;
    for (structure.fields) |field| {
        if (field.type.isNumeric() or field.type == .bool) continue;
        if (!supportedValueStructure(self, field.type, depth + 1)) return false;
    }
    return true;
}

fn isClassType(self: anytype, type_value: Ast.Type) bool {
    const index = type_value.structureIndex() orelse return false;
    return index < self.structures.len and self.structures[index].is_class;
}

const Constant = struct {
    type: Ast.Type,
    bits: u64 = 0,
    fields: []const Constant = &.{},
};

fn flattenConstant(self: anytype, value: Constant) ![]const u64 {
    var bits: std.ArrayList(u64) = .empty;
    try appendConstantBits(self, &bits, value);
    return bits.toOwnedSlice(self.allocator);
}

fn appendConstantBits(self: anytype, bits: *std.ArrayList(u64), value: Constant) !void {
    if (value.fields.len == 0) {
        try bits.append(self.allocator, value.bits);
        return;
    }
    for (value.fields) |field| try appendConstantBits(self, bits, field);
}

const Evaluation = struct {
    const State = enum { pending, evaluating, resolved };

    states: []State,
    values: []Constant,
    call_depth: usize = 0,
};

const Local = struct {
    name: []const u8,
    value: Constant,
};

fn evaluateField(self: anytype, evaluation: *Evaluation, global: usize) EvaluateError!Constant {
    switch (evaluation.states[global]) {
        .resolved => return evaluation.values[global],
        .evaluating => {
            const entry = fieldAt(self.program, global) orelse return error.InvalidSource;
            return self.fail(entry.field.name_position, "static initializer dependency forms a cycle");
        },
        .pending => {},
    }
    const entry = fieldAt(self.program, global) orelse return error.InvalidSource;
    evaluation.states[global] = .evaluating;
    errdefer evaluation.states[global] = .pending;

    const previous_member = self.member_context;
    const previous_owner = self.owner_context;
    self.member_context = entry.owner;
    self.owner_context = self.program.structures[entry.owner].owner;
    defer {
        self.member_context = previous_member;
        self.owner_context = previous_owner;
    }

    const value = if (entry.field.default) |expression|
        try evaluateExpression(self, evaluation, expression, entry.field.type, &.{})
    else
        try zeroConstant(self, entry.field.type);
    evaluation.values[global] = value;
    evaluation.states[global] = .resolved;
    return value;
}

const FieldEntry = struct {
    owner: usize,
    field: Ast.StructureField,
};

fn fieldAt(program: Ast.Program, target: usize) ?FieldEntry {
    var global: usize = 0;
    for (program.structures, 0..) |structure, owner| for (structure.static_fields) |field| {
        if (global == target) return .{ .owner = owner, .field = field };
        global += 1;
    };
    return null;
}

fn evaluateExpression(
    self: anytype,
    evaluation: *Evaluation,
    expression: *const Ast.Expression,
    expected: ?Ast.Type,
    locals: []const Local,
) EvaluateError!Constant {
    var value = switch (expression.value) {
        .integer => |lexeme| try integerLiteral(self, lexeme, expected, expression.position),
        .floating => |lexeme| try floatingLiteral(self, lexeme, expected, expression.position),
        .boolean => |boolean| Constant{ .type = .bool, .bits = @intFromBool(boolean) },
        .null_value => null_value: {
            const target = expected orelse return self.fail(expression.position, "constant null requires an optional context");
            if (target.optionalChild() == null) return self.fail(expression.position, "static initializer type does not match its field");
            break :null_value Constant{ .type = target, .bits = 0 };
        },
        .identifier => |name| identifier: {
            for (locals) |local_value| if (std.mem.eql(u8, local_value.name, name)) break :identifier local_value.value;
            return self.fail(expression.position, "constant expression can only read immutable local values and static let fields");
        },
        .field_access => |access| try evaluateFieldAccess(self, evaluation, access, locals),
        .unary => |unary| try evaluateUnary(self, evaluation, unary, expected, locals),
        .binary => |binary| try evaluateBinary(self, evaluation, binary, expected, locals),
        .conversion => |conversion| conversion: {
            const operand = try evaluateExpression(self, evaluation, conversion.operand, null, locals);
            if (!operand.type.isNumeric() or !conversion.target.isNumeric()) {
                return self.fail(conversion.operator_position, "'as' requires numeric source and target types");
            }
            break :conversion try convertConstant(self, operand, conversion.target, conversion.operator_position, true);
        },
        .call => |call| try evaluateCall(self, evaluation, call, locals),
        else => return self.fail(expression.position, "static initializer is not a compile-time intrinsic expression"),
    };
    if (expected) |target| if (value.type != target) {
        if (!self.canImplicitlyConvert(value.type, target)) return self.fail(expression.position, "static initializer type does not match its field");
        value = try convertConstant(self, value, target, expression.position, false);
    };
    return value;
}

fn zeroConstant(self: anytype, type_value: Ast.Type) EvaluateError!Constant {
    if (type_value.isNumeric() or type_value == .bool or type_value.optionalChild() != null) {
        return .{ .type = type_value };
    }
    const structure_index = type_value.structureIndex() orelse return error.InvalidSource;
    if (structure_index >= self.structures.len) return error.InvalidSource;
    const fields = try self.allocator.alloc(Constant, self.structures[structure_index].fields.len);
    for (self.structures[structure_index].fields, 0..) |field, index| fields[index] = try zeroConstant(self, field.type);
    return .{ .type = type_value, .fields = fields };
}

fn integerLiteral(self: anytype, lexeme: []const u8, expected: ?Ast.Type, position: Source.Position) EvaluateError!Constant {
    const target = if (expected != null and expected.?.isInteger()) expected.? else Ast.Type.int;
    const magnitude = try Support.parseIntegerMagnitude(self, lexeme, position);
    if (!Numeric.fitsMagnitude(magnitude, false, target)) return self.fail(position, "static initializer does not fit its field type");
    return .{ .type = target, .bits = Numeric.fromMagnitude(magnitude, false, target).bits };
}

fn floatingLiteral(self: anytype, lexeme: []const u8, expected: ?Ast.Type, position: Source.Position) EvaluateError!Constant {
    const target = if (expected != null and expected.?.isFloat()) expected.? else Ast.Type.float32;
    const normalized = try Support.removeSeparators(self.allocator, lexeme);
    return if (target == .float32)
        .{ .type = .float32, .bits = @as(u32, @bitCast(std.fmt.parseFloat(f32, normalized) catch return self.fail(position, "invalid static float initializer"))) }
    else if (target == .float64)
        .{ .type = .float64, .bits = @bitCast(std.fmt.parseFloat(f64, normalized) catch return self.fail(position, "invalid static float initializer")) }
    else
        self.fail(position, "static initializer type does not match its field");
}

fn evaluateFieldAccess(
    self: anytype,
    evaluation: *Evaluation,
    access: Ast.Expression.FieldAccess,
    locals: []const Local,
) EvaluateError!Constant {
    if (access.base.value == .identifier) {
        for (locals) |local_value| if (std.mem.eql(u8, local_value.name, access.base.value.identifier)) {
            return constantField(self, local_value.value, access.name, access.name_position);
        };
    }
    if (access.base.value == .field_access or access.base.value == .call) {
        const base = try evaluateExpression(self, evaluation, access.base, null, locals);
        if (base.fields.len != 0) return constantField(self, base, access.name, access.name_position);
    }
    const owner_name = (try GenericSyntax.qualifiedName(self.allocator, access.base)) orelse
        return self.fail(access.name_position, "constant expression can only read type-qualified static let fields");
    const owner = ownerIndex(self, owner_name) orelse
        return self.fail(access.name_position, "constant expression refers to an unknown static field owner");
    if (!Visibility.typeVisible(self, owner, access.name_position)) return self.fail(access.name_position, "static field owner is unavailable in this context");
    const field = find(self, owner, access.name) orelse {
        const message = try std.fmt.allocPrint(self.allocator, "type has no static field named '{s}'", .{access.name});
        return self.fail(access.name_position, message);
    };
    if (!Visibility.memberVisible(self, field.owner, field.declaration, access.name_position)) {
        const message = try std.fmt.allocPrint(self.allocator, "static field '{s}' is {s} and unavailable here", .{ access.name, Visibility.name(field.declaration) });
        return self.fail(access.name_position, message);
    }
    if (field.declaration.mutable) {
        const message = try std.fmt.allocPrint(self.allocator, "static initializer cannot read mutable static field '{s}'", .{access.name});
        return self.fail(access.name_position, message);
    }
    return evaluateField(self, evaluation, field.global);
}

fn constantField(self: anytype, value: Constant, name: []const u8, position: Source.Position) EvaluateError!Constant {
    const structure_index = value.type.structureIndex() orelse
        return self.fail(position, "compile-time field access requires a structure value");
    if (structure_index >= self.structures.len or value.fields.len != self.structures[structure_index].fields.len) {
        return error.InvalidSource;
    }
    for (self.structures[structure_index].fields, 0..) |field, index| {
        if (std.mem.eql(u8, field.name, name)) return value.fields[index];
    }
    return self.fail(position, "compile-time structure value has no field with this name");
}

fn evaluateUnary(self: anytype, evaluation: *Evaluation, unary: Ast.Expression.Unary, expected: ?Ast.Type, locals: []const Local) EvaluateError!Constant {
    if (unary.operator == .logical_not) {
        const operand = try evaluateExpression(self, evaluation, unary.operand, .bool, locals);
        return .{ .type = .bool, .bits = @intFromBool(operand.bits == 0) };
    }
    if (unary.operator != .negate) return self.fail(unary.operator_position, "static initializer uses a non-constant unary operator");
    const operand = try evaluateExpression(self, evaluation, unary.operand, if (expected != null and expected.?.isNumeric()) expected else null, locals);
    if (operand.type == .float32) return .{ .type = .float32, .bits = @as(u32, @bitCast(-@as(f32, @bitCast(@as(u32, @intCast(operand.bits)))))) };
    if (operand.type == .float64) return .{ .type = .float64, .bits = @bitCast(-@as(f64, @bitCast(operand.bits))) };
    if (!operand.type.isSignedInteger()) return self.fail(unary.operator_position, "operator '-' requires a signed intrinsic value in a static initializer");
    const signed = Numeric.signExtend(operand.bits, operand.type.bitWidth());
    const number: i64 = @bitCast(signed);
    if (number == Numeric.integerMin(operand.type)) return self.fail(unary.operator_position, "static initializer integer operation overflows");
    return .{ .type = operand.type, .bits = Numeric.normalize(@bitCast(-number), operand.type) };
}

fn evaluateBinary(self: anytype, evaluation: *Evaluation, binary: Ast.Expression.Binary, expected: ?Ast.Type, locals: []const Local) EvaluateError!Constant {
    if (binary.operator == .logical_and or binary.operator == .logical_or) {
        const left = try evaluateExpression(self, evaluation, binary.left, .bool, locals);
        if (binary.operator == .logical_and and left.bits == 0) return .{ .type = .bool, .bits = 0 };
        if (binary.operator == .logical_or and left.bits != 0) return .{ .type = .bool, .bits = 1 };
        return evaluateExpression(self, evaluation, binary.right, .bool, locals);
    }
    if (binary.operator == .coalesce) return self.fail(binary.operator_position, "static initializer does not support optional coalescing yet");

    const left_hint = if (expected != null and expected.?.isNumeric() and Support.isNumericLiteral(binary.left)) expected else null;
    var left = try evaluateExpression(self, evaluation, binary.left, left_hint, locals);
    const right_hint = if (Support.isNumericLiteral(binary.right))
        (if (expected != null and expected.?.isNumeric()) expected else if (left.type.isNumeric()) left.type else null)
    else
        null;
    var right = try evaluateExpression(self, evaluation, binary.right, right_hint, locals);
    const shift = binary.operator == .shift_left or binary.operator == .shift_right;
    if (left.type.isNumeric() and right.type.isNumeric() and !shift) if (Numeric.commonNumeric(left.type, right.type)) |common| {
        left = try convertConstant(self, left, common, binary.left.position, false);
        right = try convertConstant(self, right, common, binary.right.position, false);
    };
    return calculateBinary(self, binary, left, right);
}

fn calculateBinary(self: anytype, binary: Ast.Expression.Binary, left: Constant, right: Constant) EvaluateError!Constant {
    const equality = binary.operator == .equal or binary.operator == .not_equal;
    const ordering = binary.operator == .less or binary.operator == .less_equal or binary.operator == .greater or binary.operator == .greater_equal;
    const bitwise = binary.operator == .bit_and or binary.operator == .bit_xor;
    const shift = binary.operator == .shift_left or binary.operator == .shift_right;
    const valid = if (bitwise)
        left.type == right.type and left.type.isInteger() and !left.type.isSignedInteger()
    else if (shift)
        left.type.isInteger() and !left.type.isSignedInteger() and right.type.isInteger()
    else if (equality or ordering)
        left.type == right.type and (left.type.isNumeric() or left.type == .bool)
    else
        left.type == right.type and left.type.isNumeric() and (!left.type.isFloat() or binary.operator != .remainder);
    if (!valid) {
        const message = try std.fmt.allocPrint(self.allocator, "operator '{s}' does not accept '{s}' and '{s}' in a static initializer", .{ Support.binaryOperatorText(binary.operator), left.type.name(), right.type.name() });
        return self.fail(binary.operator_position, message);
    }
    if (left.type == .bool) {
        const equal = left.bits == right.bits;
        return .{ .type = .bool, .bits = @intFromBool(if (binary.operator == .equal) equal else !equal) };
    }
    if (left.type.isFloat()) return calculateFloat(self, binary, left, right);
    return calculateInteger(self, binary, left, right);
}

fn calculateInteger(self: anytype, binary: Ast.Expression.Binary, left: Constant, right: Constant) EvaluateError!Constant {
    const result_type: Ast.Type = switch (binary.operator) {
        .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => .bool,
        else => left.type,
    };
    const less = if (left.type.isSignedInteger())
        @as(i64, @bitCast(Numeric.signExtend(left.bits, left.type.bitWidth()))) < @as(i64, @bitCast(Numeric.signExtend(right.bits, right.type.bitWidth())))
    else
        left.bits < right.bits;
    switch (binary.operator) {
        .less => return .{ .type = .bool, .bits = @intFromBool(less) },
        .less_equal => return .{ .type = .bool, .bits = @intFromBool(less or left.bits == right.bits) },
        .greater => return .{ .type = .bool, .bits = @intFromBool(!less and left.bits != right.bits) },
        .greater_equal => return .{ .type = .bool, .bits = @intFromBool(!less) },
        .equal => return .{ .type = .bool, .bits = @intFromBool(left.bits == right.bits) },
        .not_equal => return .{ .type = .bool, .bits = @intFromBool(left.bits != right.bits) },
        .bit_and => return .{ .type = result_type, .bits = Numeric.normalize(left.bits & right.bits, result_type) },
        .bit_xor => return .{ .type = result_type, .bits = Numeric.normalize(left.bits ^ right.bits, result_type) },
        .shift_left, .shift_right => {
            const count: u64 = if (right.type.isSignedInteger()) count: {
                const signed: i64 = @bitCast(Numeric.signExtend(right.bits, right.type.bitWidth()));
                if (signed < 0) return self.fail(binary.operator_position, "static initializer uses an invalid shift count");
                break :count @intCast(signed);
            } else right.bits;
            if (count >= left.type.bitWidth()) return self.fail(binary.operator_position, "static initializer uses an invalid shift count");
            const bits = if (binary.operator == .shift_left) left.bits << @intCast(count) else left.bits >> @intCast(count);
            return .{ .type = left.type, .bits = Numeric.normalize(bits, left.type) };
        },
        else => {},
    }
    if (left.type.isSignedInteger()) {
        const a: i128 = @as(i64, @bitCast(Numeric.signExtend(left.bits, left.type.bitWidth())));
        const b: i128 = @as(i64, @bitCast(Numeric.signExtend(right.bits, right.type.bitWidth())));
        if ((binary.operator == .divide or binary.operator == .remainder) and b == 0) return self.fail(binary.operator_position, "static initializer divides by zero");
        const result: i128 = switch (binary.operator) {
            .add => a + b,
            .subtract => a - b,
            .multiply => a * b,
            .divide => @divTrunc(a, b),
            .remainder => @rem(a, b),
            else => unreachable,
        };
        if (result < Numeric.integerMin(left.type) or result > Numeric.integerMax(left.type)) return self.fail(binary.operator_position, "static initializer integer operation overflows");
        return .{ .type = left.type, .bits = Numeric.normalize(@bitCast(@as(i64, @intCast(result))), left.type) };
    }
    const a: u128 = left.bits;
    const b: u128 = right.bits;
    if ((binary.operator == .divide or binary.operator == .remainder) and b == 0) return self.fail(binary.operator_position, "static initializer divides by zero");
    if (binary.operator == .subtract and b > a) return self.fail(binary.operator_position, "static initializer integer operation overflows");
    const result: u128 = switch (binary.operator) {
        .add => a + b,
        .subtract => a - b,
        .multiply => a * b,
        .divide => a / b,
        .remainder => a % b,
        else => unreachable,
    };
    if (result > Numeric.integerMax(left.type)) return self.fail(binary.operator_position, "static initializer integer operation overflows");
    return .{ .type = left.type, .bits = @intCast(result) };
}

fn calculateFloat(self: anytype, binary: Ast.Expression.Binary, left: Constant, right: Constant) EvaluateError!Constant {
    if (left.type == .float32) {
        const a: f32 = @bitCast(@as(u32, @intCast(left.bits)));
        const b: f32 = @bitCast(@as(u32, @intCast(right.bits)));
        return switch (binary.operator) {
            .add => .{ .type = .float32, .bits = @as(u32, @bitCast(a + b)) },
            .subtract => .{ .type = .float32, .bits = @as(u32, @bitCast(a - b)) },
            .multiply => .{ .type = .float32, .bits = @as(u32, @bitCast(a * b)) },
            .divide => .{ .type = .float32, .bits = @as(u32, @bitCast(a / b)) },
            .less => .{ .type = .bool, .bits = @intFromBool(a < b) },
            .less_equal => .{ .type = .bool, .bits = @intFromBool(a <= b) },
            .greater => .{ .type = .bool, .bits = @intFromBool(a > b) },
            .greater_equal => .{ .type = .bool, .bits = @intFromBool(a >= b) },
            .equal => .{ .type = .bool, .bits = @intFromBool(a == b) },
            .not_equal => .{ .type = .bool, .bits = @intFromBool(a != b) },
            else => self.fail(binary.operator_position, "unsupported floating operation in static initializer"),
        };
    }
    const a: f64 = @bitCast(left.bits);
    const b: f64 = @bitCast(right.bits);
    return switch (binary.operator) {
        .add => .{ .type = .float64, .bits = @bitCast(a + b) },
        .subtract => .{ .type = .float64, .bits = @bitCast(a - b) },
        .multiply => .{ .type = .float64, .bits = @bitCast(a * b) },
        .divide => .{ .type = .float64, .bits = @bitCast(a / b) },
        .less => .{ .type = .bool, .bits = @intFromBool(a < b) },
        .less_equal => .{ .type = .bool, .bits = @intFromBool(a <= b) },
        .greater => .{ .type = .bool, .bits = @intFromBool(a > b) },
        .greater_equal => .{ .type = .bool, .bits = @intFromBool(a >= b) },
        .equal => .{ .type = .bool, .bits = @intFromBool(a == b) },
        .not_equal => .{ .type = .bool, .bits = @intFromBool(a != b) },
        else => self.fail(binary.operator_position, "unsupported floating operation in static initializer"),
    };
}

fn convertConstant(self: anytype, value: Constant, target: Ast.Type, position: Source.Position, checked: bool) EvaluateError!Constant {
    if (value.type == target) return value;
    if (!value.type.isNumeric() or !target.isNumeric()) return self.fail(position, "static initializer type does not match its field");
    if (value.type.isInteger() and target.isInteger()) {
        if (target.isSignedInteger()) {
            const signed: i128 = if (value.type.isSignedInteger()) @as(i64, @bitCast(Numeric.signExtend(value.bits, value.type.bitWidth()))) else value.bits;
            if (signed < Numeric.integerMin(target) or signed > Numeric.integerMax(target)) return self.fail(position, "static initializer numeric conversion is outside its target range");
            return .{ .type = target, .bits = Numeric.normalize(@bitCast(@as(i64, @intCast(signed))), target) };
        }
        if (value.type.isSignedInteger() and @as(i64, @bitCast(Numeric.signExtend(value.bits, value.type.bitWidth()))) < 0) return self.fail(position, "static initializer numeric conversion is outside its target range");
        if (value.bits > Numeric.integerMax(target)) return self.fail(position, "static initializer numeric conversion is outside its target range");
        return .{ .type = target, .bits = Numeric.normalize(value.bits, target) };
    }
    if (value.type.isInteger() and target.isFloat()) {
        const signed: i64 = if (value.type.isSignedInteger()) @bitCast(Numeric.signExtend(value.bits, value.type.bitWidth())) else 0;
        if (target == .float32) {
            const result: f32 = if (value.type.isSignedInteger()) @floatFromInt(signed) else @floatFromInt(value.bits);
            const exact: f64 = if (value.type.isSignedInteger()) @floatFromInt(signed) else @floatFromInt(value.bits);
            if (checked and @as(f64, result) != exact) return self.fail(position, "static initializer numeric conversion loses information");
            return .{ .type = .float32, .bits = @as(u32, @bitCast(result)) };
        }
        const result: f64 = if (value.type.isSignedInteger()) @floatFromInt(signed) else @floatFromInt(value.bits);
        if (checked) {
            if (value.type.isSignedInteger()) {
                if (@as(i128, @intFromFloat(result)) != signed) return self.fail(position, "static initializer numeric conversion loses information");
            } else if (@as(u128, @intFromFloat(result)) != value.bits) return self.fail(position, "static initializer numeric conversion loses information");
        }
        return .{ .type = .float64, .bits = @bitCast(result) };
    }
    if (value.type == .float32 and target == .float64) {
        const result: f64 = @floatCast(@as(f32, @bitCast(@as(u32, @intCast(value.bits)))));
        return .{ .type = .float64, .bits = @bitCast(result) };
    }
    if (value.type == .float64 and target == .float32) {
        const source: f64 = @bitCast(value.bits);
        const result: f32 = @floatCast(source);
        if (checked and @as(f64, @floatCast(result)) != source) return self.fail(position, "static initializer numeric conversion loses information");
        return .{ .type = .float32, .bits = @as(u32, @bitCast(result)) };
    }
    const number: f64 = if (value.type == .float32) @floatCast(@as(f32, @bitCast(@as(u32, @intCast(value.bits))))) else @bitCast(value.bits);
    if (!std.math.isFinite(number) or @trunc(number) != number) return self.fail(position, "static initializer numeric conversion is outside its target range");
    if (target.isSignedInteger()) {
        const lower: f64 = @floatFromInt(Numeric.integerMin(target));
        const upper: f64 = @floatFromInt(@as(i128, Numeric.integerMax(target)) + 1);
        if (number < lower or number >= upper) return self.fail(position, "static initializer numeric conversion is outside its target range");
        return .{ .type = target, .bits = Numeric.normalize(@bitCast(@as(i64, @intFromFloat(number))), target) };
    }
    if (number < 0 or number >= @as(f64, @floatFromInt(@as(u128, Numeric.integerMax(target)) + 1))) return self.fail(position, "static initializer numeric conversion is outside its target range");
    return .{ .type = target, .bits = Numeric.normalize(@intFromFloat(number), target) };
}

fn evaluateCall(self: anytype, evaluation: *Evaluation, call: Ast.Expression.Call, locals: []const Local) EvaluateError!Constant {
    if (try constructorTarget(self, call)) |structure_index| {
        return evaluateConstructor(self, evaluation, structure_index, call, locals);
    }
    var candidates: std.ArrayList(Callable) = .empty;
    if (call.receiver) |receiver| {
        const owner_name = (try GenericSyntax.qualifiedName(self.allocator, receiver)) orelse
            return self.fail(call.name_position, "static initializer can only call type-qualified static methods");
        const owner = ownerIndex(self, owner_name) orelse
            return self.fail(call.name_position, "static initializer call has an unknown type receiver");
        for (self.program.structures[owner].methods) |method| {
            if (!method.is_static or !std.mem.eql(u8, method.name, call.name)) continue;
            if (!Visibility.memberVisible(self, owner, method, call.name_position)) continue;
            if (call.named_arguments.len == 0 and !Support.acceptsArity(method.parameters, call.arguments.len)) continue;
            if (call.named_arguments.len != 0 and (try Arguments.map(self.allocator, method.parameters, call.arguments, call.named_arguments)) == .problem) continue;
            try candidates.append(self.allocator, .{ .function = method, .owner = owner });
        }
    } else {
        for (self.program.functions) |function| {
            if (function.is_anonymous or !std.mem.eql(u8, function.name, call.name) or !Support.functionVisible(self.packages, self.module_scope_roots, call, function)) continue;
            if (call.named_arguments.len == 0 and !Support.acceptsArity(function.parameters, call.arguments.len)) continue;
            if (call.named_arguments.len != 0 and (try Arguments.map(self.allocator, function.parameters, call.arguments, call.named_arguments)) == .problem) continue;
            try candidates.append(self.allocator, .{ .function = function });
        }
    }
    if (candidates.items.len == 0) return self.fail(call.name_position, "static initializer call has no visible overload accepting these arguments");
    const selected = try selectCallable(self, evaluation, candidates.items, call, locals);
    if (!constantFunctionShape(selected.function)) return self.fail(call.name_position, "static initializer calls a function that is not compile-time evaluable");
    return evaluateFunction(self, evaluation, selected, call, locals);
}

fn constructorTarget(self: anytype, call: Ast.Expression.Call) !?usize {
    if (call.receiver) |receiver| {
        const receiver_name = (try GenericSyntax.qualifiedName(self.allocator, receiver)) orelse return null;
        const qualified = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ receiver_name, call.name });
        return self.resolveStructureIndex(qualified);
    }
    return self.resolveStructureIndex(call.name);
}

fn evaluateConstructor(
    self: anytype,
    evaluation: *Evaluation,
    structure_index: usize,
    call: Ast.Expression.Call,
    caller_locals: []const Local,
) EvaluateError!Constant {
    if (structure_index >= self.structures.len) return error.InvalidSource;
    const runtime_structure = self.structures[structure_index];
    const declaration = astStructure(self.program, runtime_structure.name) orelse return error.InvalidSource;
    if (!Visibility.typeVisible(self, structure_index, call.name_position)) {
        return self.fail(call.name_position, "static initializer constructor type is unavailable here");
    }
    if (!supportedValueStructure(self, .structure(structure_index), 0) or declaration.base != null) {
        return self.fail(call.name_position, "static initializer can only construct plain compile-time value structures");
    }
    if (declaration.constructors.len == 0) {
        return evaluateAggregateInitializer(self, evaluation, structure_index, declaration, call, caller_locals);
    }

    var candidates: std.ArrayList(usize) = .empty;
    for (declaration.constructors, 0..) |constructor, index| {
        if (!Visibility.memberVisible(self, structure_index, constructor, call.name_position)) continue;
        if (try mappedArguments(self, constructor.parameters, call)) |_| try candidates.append(self.allocator, index);
    }
    if (candidates.items.len == 0) return self.fail(call.name_position, "static initializer constructor has no visible overload accepting these arguments");

    var selected: ?usize = null;
    var best_cost: usize = std.math.maxInt(usize);
    var ambiguous = false;
    for (candidates.items) |index| {
        const constructor = declaration.constructors[index];
        const mapped = (try mappedArguments(self, constructor.parameters, call)).?;
        var cost: usize = 0;
        for (constructor.parameters, mapped) |parameter, maybe_argument| {
            const argument = maybe_argument orelse continue;
            const value = try evaluateExpression(self, evaluation, argument, null, caller_locals);
            if (!self.canImplicitlyConvert(value.type, parameter.type)) break;
            if (value.type != parameter.type) cost += 1;
        } else if (cost < best_cost) {
            selected = index;
            best_cost = cost;
            ambiguous = false;
        } else if (cost == best_cost) ambiguous = true;
    }
    if (ambiguous) return self.fail(call.name_position, "static initializer constructor call is ambiguous");
    const constructor_index = selected orelse return self.fail(call.name_position, "no static initializer constructor matches the argument types");
    const constructor = declaration.constructors[constructor_index];
    const mapped = (try mappedArguments(self, constructor.parameters, call)).?;

    var bindings: std.ArrayList(Local) = .empty;
    for (constructor.parameters, mapped) |parameter, maybe_argument| {
        if (parameter.mode != .value) return self.fail(call.name_position, "compile-time constructors require value parameters");
        const source = maybe_argument orelse parameter.default orelse
            return self.fail(call.name_position, "static initializer constructor call is missing an argument");
        const source_locals = if (maybe_argument != null) caller_locals else bindings.items;
        const value = try evaluateExpression(self, evaluation, source, parameter.type, source_locals);
        try bindings.append(self.allocator, .{ .name = parameter.name, .value = value });
    }

    var result = try initializeStructureFields(self, evaluation, structure_index, declaration, bindings.items);
    try bindings.append(self.allocator, .{ .name = "self", .value = result });
    for (constructor.statements) |statement| switch (statement) {
        .variable_declaration => |local| {
            if (local.mutable or local.initializer == null or local.destructuring.len != 0) {
                return self.fail(local.position, "static initializer constructor is not compile-time evaluable");
            }
            const value = try evaluateExpression(self, evaluation, local.initializer.?, local.annotation, bindings.items);
            try bindings.append(self.allocator, .{ .name = local.name, .value = value });
        },
        .assignment_statement => |assignment| {
            if (!std.mem.eql(u8, assignment.target.name, "self") or assignment.target.fields.len != 1 or
                assignment.target.indices.len != 0 or assignment.target.indexed_fields.len != 0 or
                assignment.operator != .assign or assignment.value == null)
            {
                return self.fail(assignment.position, "static initializer constructor is not compile-time evaluable");
            }
            const field_name = assignment.target.fields[0].name;
            var field_index: ?usize = null;
            for (runtime_structure.fields, 0..) |field, index| if (std.mem.eql(u8, field.name, field_name)) {
                field_index = index;
                break;
            };
            const index = field_index orelse return error.InvalidSource;
            const value = try evaluateExpression(self, evaluation, assignment.value.?, runtime_structure.fields[index].type, bindings.items);
            const fields = try self.allocator.dupe(Constant, result.fields);
            fields[index] = value;
            result.fields = fields;
            for (bindings.items) |*binding| {
                if (std.mem.eql(u8, binding.name, "self")) binding.value = result;
            }
        },
        else => return self.fail(statement.position(), "static initializer constructor is not compile-time evaluable"),
    };
    return result;
}

fn evaluateAggregateInitializer(
    self: anytype,
    evaluation: *Evaluation,
    structure_index: usize,
    declaration: Ast.Structure,
    call: Ast.Expression.Call,
    locals: []const Local,
) EvaluateError!Constant {
    if (call.arguments.len != 0) return self.fail(call.name_position, "compile-time aggregate initializer requires named fields");
    for (call.named_arguments, 0..) |argument, argument_index| {
        for (call.named_arguments[0..argument_index]) |previous| {
            if (std.mem.eql(u8, previous.name, argument.name)) {
                return self.fail(argument.position, "compile-time aggregate field is provided more than once");
            }
        }
        var known = false;
        for (declaration.fields) |field| if (std.mem.eql(u8, field.name, argument.name)) {
            if (!Visibility.memberVisible(self, structure_index, field, argument.position)) {
                return self.fail(argument.position, "compile-time aggregate field is unavailable here");
            }
            known = true;
            break;
        };
        if (!known) return self.fail(argument.position, "compile-time aggregate initializer names an unknown field");
    }
    const fields = try self.allocator.alloc(Constant, declaration.fields.len);
    for (declaration.fields, 0..) |field, index| {
        var source = field.default;
        for (call.named_arguments) |argument| {
            if (std.mem.eql(u8, field.name, argument.name)) source = argument.value;
        }
        fields[index] = if (source) |expression|
            try evaluateExpression(self, evaluation, expression, field.type, locals)
        else
            try zeroConstant(self, field.type);
    }
    return .{ .type = .structure(structure_index), .fields = fields };
}

fn initializeStructureFields(
    self: anytype,
    evaluation: *Evaluation,
    structure_index: usize,
    declaration: Ast.Structure,
    locals: []const Local,
) EvaluateError!Constant {
    const fields = try self.allocator.alloc(Constant, declaration.fields.len);
    for (declaration.fields, 0..) |field, index| fields[index] = if (field.default) |expression|
        try evaluateExpression(self, evaluation, expression, field.type, locals)
    else
        try zeroConstant(self, field.type);
    return .{ .type = .structure(structure_index), .fields = fields };
}

fn mappedArguments(self: anytype, parameters: []const Ast.Parameter, call: Ast.Expression.Call) !?[]const ?*Ast.Expression {
    if (call.named_arguments.len != 0) return switch (try Arguments.map(self.allocator, parameters, call.arguments, call.named_arguments)) {
        .arguments => |arguments| arguments,
        .problem => null,
    };
    if (!Support.acceptsArity(parameters, call.arguments.len)) return null;
    const result = try self.allocator.alloc(?*Ast.Expression, parameters.len);
    @memset(result, null);
    for (call.arguments, 0..) |argument, index| result[index] = argument;
    return result;
}

fn astStructure(program: Ast.Program, name: []const u8) ?Ast.Structure {
    for (program.structures) |structure| if (std.mem.eql(u8, structure.name, name)) return structure;
    return null;
}

const Callable = struct {
    function: Ast.Function,
    owner: ?usize = null,
};

fn selectCallable(
    self: anytype,
    evaluation: *Evaluation,
    candidates: []const Callable,
    call: Ast.Expression.Call,
    locals: []const Local,
) EvaluateError!Callable {
    if (candidates.len == 1) return candidates[0];
    var selected: ?Callable = null;
    var best_cost: usize = std.math.maxInt(usize);
    var ambiguous = false;
    for (candidates) |candidate| {
        const mapped = if (call.named_arguments.len == 0) positional: {
            const values = try self.allocator.alloc(?*Ast.Expression, candidate.function.parameters.len);
            @memset(values, null);
            for (call.arguments, 0..) |argument, index| values[index] = argument;
            break :positional values;
        } else switch (try Arguments.map(self.allocator, candidate.function.parameters, call.arguments, call.named_arguments)) {
            .arguments => |arguments| arguments,
            .problem => continue,
        };
        var cost: usize = 0;
        for (candidate.function.parameters, mapped) |parameter, maybe_argument| {
            const argument = maybe_argument orelse continue;
            const value = try evaluateExpression(self, evaluation, argument, null, locals);
            if (!self.canImplicitlyConvert(value.type, parameter.type)) break;
            if (value.type != parameter.type) cost += 1;
        } else if (cost < best_cost) {
            selected = candidate;
            best_cost = cost;
            ambiguous = false;
        } else if (cost == best_cost) {
            ambiguous = true;
        }
    }
    if (selected == null) return self.fail(call.name_position, "no static initializer overload matches the argument types");
    if (ambiguous) return self.fail(call.name_position, "static initializer call is ambiguous");
    return selected.?;
}

fn constantFunctionShape(function: Ast.Function) bool {
    if (function.type_parameters.len != 0 or function.return_mode != .value or !constantType(function.return_type)) return false;
    for (function.parameters) |parameter| if (parameter.mode != .value or !constantType(parameter.type)) return false;
    if (function.statements.len == 0 or function.statements[function.statements.len - 1] != .return_statement) return false;
    for (function.statements[0 .. function.statements.len - 1]) |statement| switch (statement) {
        .variable_declaration => |declaration| {
            if (declaration.mutable or declaration.initializer == null or declaration.destructuring.len != 0) return false;
            if (declaration.annotation) |annotation| if (!constantType(annotation)) return false;
        },
        else => return false,
    };
    return function.statements[function.statements.len - 1].return_statement.value != null;
}

fn constantType(type_value: Ast.Type) bool {
    return type_value.isNumeric() or type_value == .bool;
}

fn evaluateFunction(
    self: anytype,
    evaluation: *Evaluation,
    callable: Callable,
    call: Ast.Expression.Call,
    caller_locals: []const Local,
) EvaluateError!Constant {
    if (evaluation.call_depth >= 64) return self.fail(call.name_position, "compile-time function evaluation exceeds its recursion limit");
    evaluation.call_depth += 1;
    defer evaluation.call_depth -= 1;

    const previous_member = self.member_context;
    const previous_owner = self.owner_context;
    if (callable.owner) |owner| {
        self.member_context = owner;
        self.owner_context = self.program.structures[owner].owner;
    }
    defer {
        self.member_context = previous_member;
        self.owner_context = previous_owner;
    }

    const mapped = if (call.named_arguments.len == 0) positional: {
        const values = try self.allocator.alloc(?*Ast.Expression, callable.function.parameters.len);
        @memset(values, null);
        for (call.arguments, 0..) |argument, index| values[index] = argument;
        break :positional values;
    } else switch (try Arguments.map(self.allocator, callable.function.parameters, call.arguments, call.named_arguments)) {
        .arguments => |arguments| arguments,
        .problem => return self.fail(call.name_position, "static initializer call arguments do not match the selected function"),
    };

    var bindings: std.ArrayList(Local) = .empty;
    for (callable.function.parameters, mapped) |parameter, maybe_argument| {
        const source = maybe_argument orelse parameter.default orelse
            return self.fail(call.name_position, "static initializer call is missing an argument");
        const source_locals = if (maybe_argument != null) caller_locals else bindings.items;
        const value = try evaluateExpression(self, evaluation, source, parameter.type, source_locals);
        try bindings.append(self.allocator, .{ .name = parameter.name, .value = value });
    }
    for (callable.function.statements[0 .. callable.function.statements.len - 1]) |statement| {
        const declaration = statement.variable_declaration;
        const initializer = declaration.initializer.?;
        const value = try evaluateExpression(self, evaluation, initializer, declaration.annotation, bindings.items);
        try bindings.append(self.allocator, .{ .name = declaration.name, .value = value });
    }
    const returned = callable.function.statements[callable.function.statements.len - 1].return_statement.value.?;
    return evaluateExpression(self, evaluation, returned, callable.function.return_type, bindings.items);
}
