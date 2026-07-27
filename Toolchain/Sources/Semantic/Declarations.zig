const std = @import("std");
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
            if (field.type == .void) return self.fail(field.name_position, "a structure field cannot have type 'void'");
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
            .is_class = declaration.is_class,
            .collection = declaration.collection,
        };
    }
    self.structures = structures;
    for (self.program.structures) |structure| for (structure.fields) |field| {
        try Resources.validateStoredType(self, field.type, field.position, "in a structure field");
        if (!field.mutable and Resources.containsClass(self, field.type)) {
            return self.fail(field.name_position, "a field that can reach a class reference must use 'var'");
        }
    };
    const states = try self.allocator.alloc(StructureState, structures.len);
    @memset(states, .unseen);
    for (structures, 0..) |_, index| try validateStructureCycle(self, index, states);

    for (self.program.structures) |structure| for (structure.fields) |field| if (field.default) |default| {
        if (!Constructors.restrictedFieldDefault(self, default)) return self.fail(default.position, "field default must be a fundamental literal or structure aggregate");
        var builder: Model.FunctionBuilder = .{};
        try builder.blocks.append(self.allocator, .{});
        var value = try self.analyzeExpressionExpected(&builder, default, Optionals.expectedContext(field.type, default));
        if (value.type != field.type and (Numeric.canWiden(value.type, field.type) or Optionals.canConvert(value.type, field.type))) {
            value = try self.coerce(&builder, value, field.type, default.position);
        }
        if (value.type != field.type) {
            const message = try std.fmt.allocPrint(self.allocator, "default for field '{s}' expects '{s}', found '{s}'", .{ field.name, self.typeName(field.type), self.typeName(value.type) });
            return self.fail(default.position, message);
        }
    };
    return structures;
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
