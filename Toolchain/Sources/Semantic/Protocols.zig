const std = @import("std");
const Ast = @import("../Ast.zig");
const Inheritance = @import("Inheritance.zig");

pub fn materializeFieldWitnesses(allocator: std.mem.Allocator, source: Ast.Program) !Ast.Program {
    const structures = try allocator.alloc(Ast.Structure, source.structures.len);
    @memcpy(structures, source.structures);
    for (structures) |*structure| {
        if (structure.is_protocol) continue;
        var methods: std.ArrayList(Ast.Function) = .empty;
        try methods.appendSlice(allocator, structure.methods);
        var protocols: std.ArrayList(Ast.Structure) = .empty;
        if (structure.base) |base| if (protocolDeclaration(source, base)) |protocol| try protocols.append(allocator, protocol);
        for (structure.conformances) |conformance| if (protocolDeclaration(source, conformance)) |protocol| {
            try protocols.append(allocator, protocol);
        };
        for (structure.extension_conformances) |conformance| if (protocolDeclaration(source, conformance.protocol)) |protocol| {
            try protocols.append(allocator, protocol);
        };
        for (protocols.items) |protocol| for (protocol.methods) |requirement| {
            const accessor = requirement.accessor orelse continue;
            var implemented = false;
            for (methods.items) |method| if (Inheritance.sameSignature(method, requirement)) {
                implemented = true;
                break;
            };
            if (implemented) continue;
            const field = findStoredField(source, structure.*, accessor.property) orelse continue;
            if (accessor.kind == .get) {
                if (field.type != requirement.return_type) continue;
                try methods.append(allocator, try storedGetter(allocator, structure.name, field, requirement));
            } else {
                if (!field.mutable or requirement.parameters.len != 1 or field.type != requirement.parameters[0].type) continue;
                try methods.append(allocator, try storedSetter(allocator, structure.name, field, requirement));
            }
        };
        structure.methods = try methods.toOwnedSlice(allocator);
    }
    var result = source;
    result.structures = structures;
    return result;
}

fn protocolDeclaration(program: Ast.Program, type_value: Ast.Type) ?Ast.Structure {
    const index = type_value.structureIndex() orelse return null;
    if (index >= program.type_names.len) return null;
    for (program.structures) |structure| if (structure.is_protocol and std.mem.eql(u8, structure.name, program.type_names[index])) return structure;
    return null;
}

fn findStoredField(program: Ast.Program, structure: Ast.Structure, name: []const u8) ?Ast.StructureField {
    for (structure.fields) |field| if (field.property == null and std.mem.eql(u8, field.name, name)) return field;
    if (structure.base) |base| {
        const index = base.structureIndex() orelse return null;
        if (index >= program.type_names.len) return null;
        for (program.structures) |candidate| if (std.mem.eql(u8, candidate.name, program.type_names[index])) {
            return findStoredField(program, candidate, name);
        };
    }
    return null;
}

fn storedGetter(allocator: std.mem.Allocator, owner: []const u8, field: Ast.StructureField, requirement: Ast.Function) !Ast.Function {
    const self_expression = try allocator.create(Ast.Expression);
    self_expression.* = .{ .position = field.name_position, .value = .{ .identifier = "self" } };
    const field_expression = try allocator.create(Ast.Expression);
    field_expression.* = .{ .position = field.name_position, .value = .{ .field_access = .{
        .base = self_expression,
        .name = field.name,
        .name_position = field.name_position,
    } } };
    const statements = try allocator.alloc(Ast.Statement, 1);
    statements[0] = .{ .return_statement = .{ .position = field.name_position, .value = field_expression } };
    var method = requirement;
    method.position = field.position;
    method.name_position = field.name_position;
    method.accessor = .{ .owner = owner, .property = field.name, .kind = .get, .synthetic = true };
    method.statements = statements;
    return method;
}

fn storedSetter(allocator: std.mem.Allocator, owner: []const u8, field: Ast.StructureField, requirement: Ast.Function) !Ast.Function {
    const self_expression = try allocator.create(Ast.Expression);
    self_expression.* = .{ .position = field.name_position, .value = .{ .identifier = "self" } };
    const field_expression = try allocator.create(Ast.Expression);
    field_expression.* = .{ .position = field.name_position, .value = .{ .field_access = .{
        .base = self_expression,
        .name = field.name,
        .name_position = field.name_position,
    } } };
    const value_expression = try allocator.create(Ast.Expression);
    value_expression.* = .{ .position = field.name_position, .value = .{ .identifier = requirement.parameters[0].name } };
    const assignment_fields = try allocator.alloc(Ast.AssignmentTarget.Field, 1);
    assignment_fields[0] = .{ .name_position = field.name_position, .name = field.name };
    const statements = try allocator.alloc(Ast.Statement, 1);
    statements[0] = .{ .assignment_statement = .{
        .position = field.name_position,
        .target = .{
            .source = field_expression,
            .name_position = field.name_position,
            .name = "self",
            .fields = assignment_fields,
        },
        .operator = .assign,
        .value = value_expression,
    } };
    var method = requirement;
    method.position = field.position;
    method.name_position = field.name_position;
    method.accessor = .{ .owner = owner, .property = field.name, .kind = .set, .synthetic = true };
    method.statements = statements;
    return method;
}

pub fn validate(self: anytype) !void {
    for (self.program.structures, 0..) |declaration, structure_index| {
        if (declaration.is_protocol) continue;
        var seen: std.ArrayList(usize) = .empty;
        if (declaration.base) |relation| if (protocolIndex(self, relation)) |protocol_index| {
            try validateOne(self, structure_index, declaration, protocol_index, declaration.name_position);
            try seen.append(self.allocator, protocol_index);
        };
        for (declaration.conformances) |relation| {
            const protocol_index = protocolIndex(self, relation) orelse {
                return self.fail(declaration.name_position, "a conformance entry must name a protocol");
            };
            for (seen.items) |existing| if (existing == protocol_index) {
                const message = try std.fmt.allocPrint(self.allocator, "type '{s}' declares protocol '{s}' more than once", .{
                    declaration.name,
                    self.structures[protocol_index].name,
                });
                return self.fail(declaration.name_position, message);
            };
            try validateOne(self, structure_index, declaration, protocol_index, declaration.name_position);
            try seen.append(self.allocator, protocol_index);
        }
        for (declaration.extension_conformances) |relation| {
            const protocol_index = protocolIndex(self, relation.protocol) orelse {
                return self.fail(relation.position, "an extension conformance must name a protocol");
            };
            try validateOne(self, structure_index, declaration, protocol_index, relation.position);
        }
    }
}

pub fn conforms(self: anytype, structure_index: usize, protocol_index: usize) bool {
    var current: ?usize = structure_index;
    while (current) |candidate| : (current = self.structures[candidate].base) {
        const declaration = Inheritance.findDeclaration(self, candidate) orelse return false;
        if (declaration.base) |relation| if (protocolIndex(self, relation) == protocol_index) return true;
        for (declaration.conformances) |relation| if (protocolIndex(self, relation) == protocol_index) return true;
        if (candidate == structure_index) for (declaration.extension_conformances) |relation| {
            if (protocolIndex(self, relation.protocol) == protocol_index) return true;
        };
    }
    return false;
}

fn validateOne(self: anytype, structure_index: usize, declaration: Ast.Structure, protocol_index: usize, position: @import("../Source.zig").Position) !void {
    const protocol = Inheritance.findDeclaration(self, protocol_index) orelse return error.InvalidSource;
    for (protocol.methods) |requirement| {
        const implementation = findMethod(self, structure_index, requirement, position) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "type '{s}' does not implement protocol requirement '{s}.{s}'", .{
                declaration.name,
                protocol.name,
                requirement.name,
            });
            return self.fail(declaration.name_position, message);
        };
        _ = implementation;
    }
}

fn findMethod(self: anytype, structure_index: usize, requirement: Ast.Function, position: @import("../Source.zig").Position) ?Ast.Function {
    var current: ?usize = structure_index;
    while (current) |candidate| : (current = self.structures[candidate].base) {
        const declaration = Inheritance.findDeclaration(self, candidate) orelse return null;
        for (declaration.methods) |method| {
            if (method.is_static or method.type_parameters.len != 0) continue;
            if (method.extension) |extension| {
                var active = false;
                for (extension.visible_files) |file| if (file == position.file) {
                    active = true;
                    break;
                };
                if (!active) continue;
            }
            if (Inheritance.sameSignature(method, requirement)) return method;
        }
    }
    return null;
}

fn protocolIndex(self: anytype, type_value: Ast.Type) ?usize {
    const index = type_value.structureIndex() orelse return null;
    if (index >= self.structures.len or !self.structures[index].is_protocol) return null;
    return index;
}
