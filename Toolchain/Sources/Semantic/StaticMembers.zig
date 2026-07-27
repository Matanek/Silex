const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const Support = @import("Support.zig");
const Visibility = @import("Visibility.zig");
const Optionals = @import("Optionals.zig");
const Model = @import("Model.zig");

pub const Field = struct {
    global: usize,
    owner: usize,
    declaration: Ast.StructureField,
};

pub fn ownerIndex(self: anytype, name: []const u8) ?usize {
    for (self.program.structures, 0..) |structure, index| if (std.mem.eql(u8, structure.name, name)) return index;
    const nominal = self.structureIndex(name) orelse return null;
    if (nominal >= self.structures.len) return null;
    for (self.program.structures, 0..) |structure, index| {
        if (std.mem.eql(u8, structure.name, self.structures[nominal].name)) return index;
    }
    return null;
}

pub fn prepare(self: anytype) ![]const Ir.Global {
    var globals: std.ArrayList(Ir.Global) = .empty;
    for (self.program.structures, 0..) |structure, owner| for (structure.static_fields) |field| {
        if (!supportedType(field.type)) return self.fail(field.name_position, "static field type is not supported by the bootstrap runtime yet");
        try globals.append(self.allocator, .{
            .name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ structure.name, field.name }),
            .type = field.type,
            .mutable = field.mutable,
            .bits = try initializerBits(self, field),
        });
        _ = owner;
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
    if (!Visibility.memberVisible(self, field.owner, field.declaration, position)) {
        const message = try std.fmt.allocPrint(self.allocator, "static field '{s}' is {s} and unavailable here", .{ name, Visibility.name(field.declaration) });
        return self.fail(position, message);
    }
    const result = try self.newValue(builder, field.declaration.type);
    try self.emit(builder, .{ .global_load = .{ .result = result, .global = field.global } });
    return .{ .type = field.declaration.type, .value = result };
}

pub fn analyzeCall(self: anytype, builder: anytype, structure_index: usize, call: Ast.Expression.Call) !?Model.TypedValue {
    const structure = self.program.structures[structure_index];
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
        try ids.append(self.allocator, (try self.coerce(builder, argument, parameter.type, source.position)).value);
    }
    for (method.parameters[arguments.items.len..]) |parameter| try ids.append(self.allocator, (try self.analyzeParameterDefault(builder, parameter)).value);
    const result = if (method.return_type == .void) null else try self.newValue(builder, method.return_type);
    try self.emit(builder, .{ .call = .{
        .result = result,
        .function = methodFunctionId(self.program, structure_index, method_index),
        .arguments = try ids.toOwnedSlice(self.allocator),
    } });
    return if (result) |value| .{ .type = method.return_type, .value = value } else null;
}

fn methodFunctionId(program: Ast.Program, structure_index: usize, method_index: usize) Ir.FunctionId {
    var result = program.functions.len;
    for (program.structures) |structure| result += structure.constructors.len;
    for (program.structures[0..structure_index]) |structure| result += structure.methods.len;
    return result + method_index;
}

fn supportedType(type_value: Ast.Type) bool {
    return type_value.isNumeric() or type_value == .bool;
}

fn initializerBits(self: anytype, field: Ast.StructureField) !u64 {
    const expression = field.default orelse return 0;
    return switch (expression.value) {
        .integer => |lexeme| integer: {
            const magnitude = try Support.parseIntegerMagnitude(self, lexeme, expression.position);
            if (!field.type.isInteger() or !Numeric.fitsMagnitude(magnitude, false, field.type)) return self.fail(expression.position, "static initializer does not fit its field type");
            break :integer Numeric.fromMagnitude(magnitude, false, field.type).bits;
        },
        .floating => |lexeme| floating: {
            const normalized = try Support.removeSeparators(self.allocator, lexeme);
            break :floating if (field.type == .float32)
                @as(u64, @as(u32, @bitCast(std.fmt.parseFloat(f32, normalized) catch return self.fail(expression.position, "invalid static float initializer"))))
            else if (field.type == .float64)
                @bitCast(std.fmt.parseFloat(f64, normalized) catch return self.fail(expression.position, "invalid static float initializer"))
            else
                return self.fail(expression.position, "static initializer type does not match its field");
        },
        .boolean => |value| if (field.type == .bool) @intFromBool(value) else return self.fail(expression.position, "static initializer type does not match its field"),
        .unary => |unary| negative: {
            if (unary.operator != .negate or unary.operand.value != .integer or !field.type.isSignedInteger()) return self.fail(expression.position, "static initializer must be a deterministic literal");
            const magnitude = try Support.parseIntegerMagnitude(self, unary.operand.value.integer, unary.operand.position);
            if (!Numeric.fitsMagnitude(magnitude, true, field.type)) return self.fail(expression.position, "static initializer does not fit its field type");
            break :negative Numeric.fromMagnitude(magnitude, true, field.type).bits;
        },
        else => self.fail(expression.position, "static initializer must be a deterministic intrinsic value"),
    };
}
