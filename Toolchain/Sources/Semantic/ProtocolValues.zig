const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");

pub fn index(self: anytype, type_value: Ast.Type) ?usize {
    const type_index = type_value.structureIndex() orelse return null;
    if (type_index >= self.structures.len or !self.structures[type_index].is_protocol) return null;
    return type_index;
}

pub fn conforms(self: anytype, structure_index: usize, protocol_index: usize) bool {
    var current: ?usize = structure_index;
    while (current) |candidate| : (current = self.structures[candidate].base) {
        for (self.structures[candidate].conformances) |conformance| if (conformance == protocol_index) return true;
    }
    return false;
}

pub fn canErase(self: anytype, source: Ast.Type, target: Ast.Type) bool {
    const protocol_index = index(self, target) orelse return false;
    const structure_index = source.structureIndex() orelse return false;
    return structure_index < self.structures.len and !self.structures[structure_index].is_protocol and
        conforms(self, structure_index, protocol_index);
}

pub fn erase(
    self: anytype,
    builder: anytype,
    value: Model.TypedValue,
    target: Ast.Type,
    position: @import("../Source.zig").Position,
) !Model.TypedValue {
    const structure_index = value.type.structureIndex() orelse return error.InvalidSource;
    if (!self.structures[structure_index].is_class and @import("Resources.zig").isNoncopyable(self, value.type)) {
        return self.fail(position, "a noncopyable structure cannot be erased into a dynamic protocol value");
    }
    const result = try self.newValue(builder, target);
    try self.emit(builder, .{ .protocol_init = .{
        .result = result,
        .operand = value.value,
        .structure = structure_index,
    } });
    return .{ .type = target, .value = result };
}

pub fn conformers(self: anytype, protocol_index: usize) ![]const usize {
    var result: std.ArrayList(usize) = .empty;
    for (self.structures, 0..) |structure, structure_index| {
        if (structure.is_protocol or structure.is_static or !conforms(self, structure_index, protocol_index)) continue;
        try result.append(self.allocator, structure_index);
    }
    return result.toOwnedSlice(self.allocator);
}

pub const Implementation = struct {
    owner: usize,
    index: usize,
    method: Ast.Function,
};

pub fn implementation(self: anytype, structure_index: usize, requirement: Ast.Function) ?Implementation {
    var current: ?usize = structure_index;
    while (current) |candidate| : (current = self.structures[candidate].base) {
        const declaration = @import("Inheritance.zig").findDeclaration(self, candidate) orelse return null;
        for (declaration.methods, 0..) |method, method_index| {
            if (method.is_static or method.type_parameters.len != 0) continue;
            if (@import("Inheritance.zig").sameSignature(method, requirement)) return .{
                .owner = candidate,
                .index = method_index,
                .method = method,
            };
        }
    }
    return null;
}

pub fn emitTest(self: anytype, builder: anytype, protocol: Ir.ValueId, structure: usize) !Ir.ValueId {
    const result = try self.newValue(builder, .bool);
    try self.emit(builder, .{ .protocol_test = .{ .result = result, .operand = protocol, .structure = structure } });
    return result;
}

pub fn emitExtract(self: anytype, builder: anytype, protocol: Ir.ValueId, structure: usize) !Ir.ValueId {
    const result = try self.newValue(builder, Ast.Type.structure(structure));
    try self.emit(builder, .{ .protocol_extract = .{ .result = result, .operand = protocol, .structure = structure } });
    return result;
}
