const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Optionals = @import("Optionals.zig");

pub fn prepare(self: anytype) ![]const Ir.Enum {
    const result = try self.allocator.alloc(Ir.Enum, self.program.enums.len);
    for (self.program.enums, 0..) |enumeration, enum_index| {
        const type_index = typeIndex(self.program, enumeration.name) orelse return self.fail(enumeration.name_position, "enum type is unavailable");
        const variants = try self.allocator.alloc(Ir.EnumVariant, enumeration.variants.len);
        for (enumeration.variants, 0..) |variant, variant_index| variants[variant_index] = .{
            .name = variant.name,
            .associated_types = variant.associated_types,
            .raw_value = if (variant.raw_value) |raw_value| switch (raw_value) {
                .integer => |value| .{ .integer = value },
                .string => |value| .{ .string = value },
            } else null,
        };
        result[enum_index] = .{
            .name = enumeration.name,
            .type_index = type_index,
            .raw_type = enumeration.raw_type,
            .variants = variants,
        };
    }
    return result;
}

pub fn find(self: anytype, name: []const u8) ?usize {
    for (self.program.enums, 0..) |enumeration, index| {
        if (std.mem.eql(u8, enumeration.name, name)) return index;
    }
    return null;
}

pub fn findByType(self: anytype, type_value: Ast.Type) ?usize {
    const type_index = type_value.structureIndex() orelse return null;
    for (self.enums, 0..) |enumeration, index| if (enumeration.type_index == type_index) return index;
    return null;
}

pub fn analyzeInitializer(self: anytype, builder: anytype, call: Ast.Expression.Call, enum_index: usize) !Model.TypedValue {
    const enumeration = self.program.enums[enum_index];
    if (enumeration.is_internal and call.name_position.file != enumeration.position.file) {
        const message = try std.fmt.allocPrint(self.allocator, "enum '{s}' is internal to its source file", .{enumeration.name});
        return self.fail(call.name_position, message);
    }
    var selected: ?usize = null;
    for (enumeration.variants, 0..) |variant, variant_index| {
        if (std.mem.eql(u8, variant.name, call.name)) selected = variant_index;
    }
    const variant_index = selected orelse {
        const message = try std.fmt.allocPrint(self.allocator, "enum '{s}' has no variant named '{s}'", .{ enumeration.name, call.name });
        return self.fail(call.name_position, message);
    };
    const variant = enumeration.variants[variant_index];
    if (call.arguments.len != variant.associated_types.len) {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "variant '{s}.{s}' expects {d} arguments, found {d}",
            .{ enumeration.name, variant.name, variant.associated_types.len, call.arguments.len },
        );
        return self.fail(call.name_position, message);
    }
    var values: std.ArrayList(Ir.ValueId) = .empty;
    for (call.arguments, variant.associated_types, 0..) |argument, expected, index| {
        var value = try self.analyzeExpressionExpected(builder, argument, Optionals.expectedContext(expected, argument));
        if (value.type != expected) value = try self.coerce(builder, value, expected, argument.position);
        if (value.type != expected) {
            const message = try std.fmt.allocPrint(self.allocator, "argument {d} of '{s}.{s}' expects '{s}', found '{s}'", .{
                index + 1, enumeration.name, variant.name, self.typeName(expected), self.typeName(value.type),
            });
            return self.fail(argument.position, message);
        }
        try values.append(self.allocator, value.value);
    }
    const result_type = Ast.Type.structure(typeIndex(self.program, enumeration.name).?);
    const result = try self.newValue(builder, result_type);
    try self.emit(builder, .{ .enum_init = .{
        .result = result,
        .enumeration = enum_index,
        .variant = variant_index,
        .values = try values.toOwnedSlice(self.allocator),
    } });
    return .{ .type = result_type, .value = result };
}

pub fn analyzeProperty(self: anytype, builder: anytype, base: Model.TypedValue, name: []const u8, position: @import("../Source.zig").Position) !?Model.TypedValue {
    const enum_index = findByType(self, base.type) orelse return null;
    if (!std.mem.eql(u8, name, "raw_value")) {
        const message = try std.fmt.allocPrint(self.allocator, "enum '{s}' has no property named '{s}'", .{ self.enums[enum_index].name, name });
        return self.fail(position, message);
    }
    const enumeration = self.enums[enum_index];
    const raw_type = enumeration.raw_type orelse return self.fail(position, "associated enum has no 'raw_value' property");
    const result = try self.newValue(builder, raw_type);
    try self.emit(builder, .{ .enum_raw = .{ .result = result, .operand = base.value, .enumeration = enum_index } });
    return .{ .type = raw_type, .value = result };
}

pub fn typeIndex(program: Ast.Program, name: []const u8) ?usize {
    for (program.type_names, 0..) |candidate, index| if (std.mem.eql(u8, candidate, name)) return index;
    return null;
}
