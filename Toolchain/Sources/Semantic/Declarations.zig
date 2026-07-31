const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Enums = @import("Enums.zig");
const Resources = @import("Resources.zig");
const Constructors = @import("Constructors.zig");
const Optionals = @import("Optionals.zig");
const Numeric = @import("../Numeric.zig");

const StructureState = enum { unseen, visiting, complete };

pub fn prepareStructures(self: anytype) ![]const Ir.Structure {
    for (self.program.structures, 0..) |structure, index| {
        for (self.program.structures[0..index]) |previous| if (std.mem.eql(u8, structure.name, previous.name)) {
            const message = try std.fmt.allocPrint(self.allocator, "structure '{s}' is already declared", .{structure.name});
            return self.fail(structure.name_position, message);
        };
        for (self.program.functions) |function| if (std.mem.eql(u8, structure.name, function.name)) {
            const message = try std.fmt.allocPrint(self.allocator, "declaration name '{s}' is already used by a function", .{structure.name});
            return self.fail(structure.name_position, message);
        };
        for (structure.fields, 0..) |field, field_index| {
            if (field.type == .void and !structure.tuple_placeholder) return self.fail(field.name_position, "a structure field cannot have type 'void'");
            for (structure.fields[0..field_index]) |previous| if (std.mem.eql(u8, field.name, previous.name)) {
                const message = try std.fmt.allocPrint(self.allocator, "field '{s}' is already declared in this structure", .{field.name});
                return self.fail(field.name_position, message);
            };
        }
    }

    const structures = try self.allocator.alloc(Ir.Structure, self.program.type_names.len);
    for (self.program.type_names, 0..) |name, type_index| {
        const declaration = findAstStructure(self, name) orelse {
            if (Enums.find(self, name) != null) {
                structures[type_index] = .{ .name = name, .fields = &.{} };
                continue;
            }
            const message = try std.fmt.allocPrint(self.allocator, "unknown nominal type '{s}'", .{name});
            return self.fail(.{ .offset = 0, .line = 1, .column = 1 }, message);
        };
        const fields = try self.allocator.alloc(Ir.StructureField, declaration.fields.len);
        for (declaration.fields, 0..) |field, field_index| fields[field_index] = .{
            .name = field.name,
            .type = field.type,
            .mutable = field.mutable,
        };
        structures[type_index] = .{
            .name = name,
            .fields = fields,
            .is_tuple = declaration.is_tuple,
            .tuple_named = declaration.tuple_named,
            .is_class = declaration.is_class,
            .is_static = declaration.is_static,
            .is_protocol = declaration.is_protocol,
            .conformances = try resolvedConformances(self, declaration),
            .base = if (declaration.base) |base| if (isProtocolType(self, base)) null else base.structureIndex() else null,
            .collection = declaration.collection,
        };
    }
    self.structures = structures;
    const inheritance_states = try self.allocator.alloc(StructureState, structures.len);
    @memset(inheritance_states, .unseen);
    for (structures, 0..) |structure, index| if (structure.is_class and !structure.is_protocol) {
        try validateInheritance(self, index, inheritance_states);
    };
    for (self.program.structures) |structure| if (!structure.is_protocol) for (structure.fields) |field| {
        try Resources.validateStoredType(self, field.type, field.position, "in a structure field");
        if (!field.mutable and Resources.containsClass(self, field.type)) {
            return self.fail(field.name_position, "a field that can reach a class reference must use 'var'");
        }
    };
    const states = try self.allocator.alloc(StructureState, structures.len);
    @memset(states, .unseen);
    for (structures, 0..) |structure, index| if (!structure.is_protocol) try validateStructureCycle(self, index, states);

    for (self.program.structures) |structure| for (structure.fields) |field| if (field.default) |default| {
        if (!Constructors.restrictedFieldDefault(self, default)) return self.fail(default.position, "field default must be a fundamental literal or structure aggregate");
        var builder: Model.FunctionBuilder = .{};
        try builder.blocks.append(self.allocator, .{});
        var value = try self.analyzeExpressionExpected(&builder, default, Optionals.expectedContext(field.type, default));
        if (value.type != field.type and self.canImplicitlyConvert(value.type, field.type)) {
            value = try self.coerce(&builder, value, field.type, default.position);
        }
        if (value.type != field.type) {
            const message = try std.fmt.allocPrint(self.allocator, "default for field '{s}' expects '{s}', found '{s}'", .{ field.name, self.typeName(field.type), self.typeName(value.type) });
            return self.fail(default.position, message);
        }
    };
    return structures;
}

fn resolvedConformances(self: anytype, declaration: Ast.Structure) ![]const usize {
    var result: std.ArrayList(usize) = .empty;
    if (declaration.base) |relation| if (isProtocolType(self, relation)) {
        try result.append(self.allocator, relation.structureIndex().?);
    };
    for (declaration.conformances) |relation| if (isProtocolType(self, relation)) {
        try result.append(self.allocator, relation.structureIndex().?);
    };
    for (declaration.extension_conformances) |relation| {
        try result.append(self.allocator, relation.protocol.structureIndex().?);
    }
    return result.toOwnedSlice(self.allocator);
}

fn validateInheritance(self: anytype, index: usize, states: []StructureState) !void {
    switch (states[index]) {
        .complete => return,
        .visiting => {
            const declaration = findAstStructure(self, self.structures[index].name).?;
            return self.fail(declaration.base_position, "class inheritance forms a cycle");
        },
        .unseen => states[index] = .visiting,
    }
    const declaration = findAstStructure(self, self.structures[index].name) orelse return error.InvalidSource;
    if (declaration.base != null and self.structures[index].base == null and !isProtocolType(self, declaration.base.?)) {
        return self.fail(declaration.base_position, "a class base must be a non-optional class type");
    }
    if (self.structures[index].base) |base_index| {
        if (base_index >= self.structures.len or !self.structures[base_index].is_class or self.structures[base_index].is_static) {
            return self.fail(declaration.base_position, "a class can only inherit from another class");
        }
        const base_declaration = findAstStructure(self, self.structures[base_index].name) orelse
            return self.fail(declaration.base_position, "base class is unavailable");
        if (base_declaration.is_local and base_declaration.position.file != declaration.position.file) {
            return self.fail(declaration.base_position, "local base class is unavailable outside its source file");
        }
        if (base_declaration.is_internal and base_declaration.owner != declaration.owner) {
            return self.fail(declaration.base_position, "internal base class is unavailable outside its package");
        }
        try validateInheritance(self, base_index, states);
        const inherited = self.structures[base_index].fields;
        for (declaration.fields) |field| for (inherited) |base_field| {
            if (std.mem.eql(u8, field.name, base_field.name)) {
                const message = try std.fmt.allocPrint(self.allocator, "field '{s}' is already inherited from a base class", .{field.name});
                return self.fail(field.name_position, message);
            }
        };
        const flattened = try self.allocator.alloc(Ir.StructureField, inherited.len + declaration.fields.len);
        @memcpy(flattened[0..inherited.len], inherited);
        @memcpy(flattened[inherited.len..], self.structures[index].fields);
        @constCast(&self.structures[index]).fields = flattened;
    }
    states[index] = .complete;
}

fn validateStructureCycle(self: anytype, index: usize, states: []StructureState) !void {
    if (self.structures[index].is_class) {
        states[index] = .complete;
        return;
    }
    switch (states[index]) {
        .complete => return,
        .visiting => {
            const message = try std.fmt.allocPrint(self.allocator, "structure '{s}' has a recursive value representation", .{self.structures[index].name});
            return self.fail(findAstStructure(self, self.structures[index].name).?.name_position, message);
        },
        .unseen => {},
    }
    states[index] = .visiting;
    for (self.structures[index].fields) |field| {
        const field_type = field.type.optionalChild() orelse field.type;
        if (field_type.structureIndex()) |nested| try validateStructureCycle(self, nested, states);
    }
    states[index] = .complete;
}

fn findAstStructure(self: anytype, name: []const u8) ?@import("../Ast.zig").Structure {
    for (self.program.structures) |structure| if (std.mem.eql(u8, structure.name, name)) return structure;
    return null;
}

fn isProtocolType(self: anytype, type_value: @import("../Ast.zig").Type) bool {
    const index = type_value.structureIndex() orelse return false;
    if (index >= self.program.type_names.len) return false;
    const declaration = findAstStructure(self, self.program.type_names[index]) orelse return false;
    return declaration.is_protocol;
}
