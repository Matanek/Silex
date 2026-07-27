const std = @import("std");
const Ast = @import("Ast.zig");
const Source = @import("Source.zig");
const Types = @import("Types.zig");

const Allocator = std.mem.Allocator;

pub const Owner = union(enum) {
    project,
    package: []const u8,

    pub fn eql(left: Owner, right: Owner) bool {
        return switch (left) {
            .project => right == .project,
            .package => |name| switch (right) {
                .project => false,
                .package => |other| std.mem.eql(u8, name, other),
            },
        };
    }
};

pub const DeclarationId = struct {
    owner: Owner,
    module: []const u8,
    name: []const u8,
    parameter_types: []const Types.Type,

    pub fn eql(left: DeclarationId, right: DeclarationId) bool {
        return left.owner.eql(right.owner) and
            std.mem.eql(u8, left.module, right.module) and
            std.mem.eql(u8, left.name, right.name) and
            std.mem.eql(Types.Type, left.parameter_types, right.parameter_types);
    }
};

pub const Function = struct {
    export_name: []const u8,
    id: DeclarationId,
    type_parameters: []const []const u8 = &.{},
    return_type: Types.Type,
    position: Source.Position,
    required_parameters: usize = 0,
};

pub const TypeId = struct {
    owner: Owner,
    module: []const u8,
    name: []const u8,

    pub fn eql(left: TypeId, right: TypeId) bool {
        return left.owner.eql(right.owner) and
            std.mem.eql(u8, left.module, right.module) and
            std.mem.eql(u8, left.name, right.name);
    }
};

pub const StructureField = struct {
    is_static: bool = false,
    name: []const u8,
    type: Types.Type,
    mutable: bool,
};

pub const Constructor = struct {
    parameter_types: []const Types.Type,
    required_parameters: usize = 0,
};

pub const Method = struct {
    is_static: bool = false,
    name: []const u8,
    type_parameters: []const []const u8 = &.{},
    parameter_types: []const Types.Type,
    return_type: Types.Type,
    required_parameters: usize = 0,
};

pub const Structure = struct {
    export_name: []const u8,
    id: TypeId,
    type_parameters: []const []const u8 = &.{},
    is_class: bool = false,
    base: ?Types.Type = null,
    fields: []const StructureField,
    constructors: []const Constructor,
    methods: []const Method,
    position: Source.Position,
};

pub const EnumVariant = struct {
    name: []const u8,
    associated_types: []const Types.Type,
    raw_value: ?Ast.EnumRawValue = null,
};

pub const Enum = struct {
    export_name: []const u8,
    id: TypeId,
    type_parameters: []const []const u8 = &.{},
    variants: []const EnumVariant,
    raw_type: ?Types.Type = null,
    position: Source.Position,
};

pub const TypeAlias = struct {
    name: []const u8,
    target: Types.Type,
};

pub const Module = struct {
    owner: Owner,
    name: []const u8,
    structures: []const Structure,
    enums: []const Enum = &.{},
    functions: []const Function,
    type_aliases: []const TypeAlias = &.{},
};

pub fn build(
    allocator: Allocator,
    owner: Owner,
    module_name: []const u8,
    program: Ast.Program,
) Allocator.Error!Module {
    const type_map = try allocator.alloc(Types.Type, program.type_names.len);
    defer allocator.free(type_map);
    for (type_map, 0..) |*mapped, index| mapped.* = .structure(index);
    return buildMapped(allocator, owner, module_name, program, type_map);
}

pub fn buildMapped(
    allocator: Allocator,
    owner: Owner,
    module_name: []const u8,
    program: Ast.Program,
    type_map: []const Types.Type,
) Allocator.Error!Module {
    return buildMappedGenerics(allocator, owner, module_name, program, type_map, &.{});
}

pub fn buildMappedGenerics(
    allocator: Allocator,
    owner: Owner,
    module_name: []const u8,
    program: Ast.Program,
    type_map: []const Types.Type,
    generic_map: []const Types.Type,
) Allocator.Error!Module {
    var structures: std.ArrayList(Structure) = .empty;
    for (program.structures) |structure| {
        if (!structure.is_public) continue;
        var fields: std.ArrayList(StructureField) = .empty;
        for (structure.fields) |field| {
            if (!field.is_public or field.is_internal) continue;
            try fields.append(allocator, .{
                .name = field.name,
                .type = mappedType(field.type, type_map, generic_map),
                .mutable = field.mutable,
            });
        }
        for (structure.static_fields) |field| {
            if (!field.is_public or field.is_internal) continue;
            try fields.append(allocator, .{
                .is_static = true,
                .name = field.name,
                .type = mappedType(field.type, type_map, generic_map),
                .mutable = field.mutable,
            });
        }
        var constructors: std.ArrayList(Constructor) = .empty;
        for (structure.constructors) |constructor| {
            if (!constructor.is_public or constructor.is_internal) continue;
            const parameters = try allocator.alloc(Types.Type, constructor.parameters.len);
            for (constructor.parameters, 0..) |parameter, parameter_index| {
                parameters[parameter_index] = mappedType(parameter.type, type_map, generic_map);
            }
            try constructors.append(allocator, .{
                .parameter_types = parameters,
                .required_parameters = requiredParameterCount(constructor.parameters),
            });
        }
        var methods: std.ArrayList(Method) = .empty;
        for (structure.methods) |method| {
            if (!method.is_public or method.is_internal) continue;
            const parameters = try allocator.alloc(Types.Type, method.parameters.len);
            for (method.parameters, 0..) |parameter, parameter_index| {
                parameters[parameter_index] = mappedType(parameter.type, type_map, generic_map);
            }
            const method_type_parameters = try allocator.alloc([]const u8, method.type_parameters.len);
            for (method.type_parameters, 0..) |parameter, index| method_type_parameters[index] = parameter.name;
            try methods.append(allocator, .{
                .is_static = method.is_static,
                .name = method.name,
                .type_parameters = method_type_parameters,
                .parameter_types = parameters,
                .return_type = mappedType(method.return_type, type_map, generic_map),
                .required_parameters = requiredParameterCount(method.parameters),
            });
        }
        const type_parameters = try allocator.alloc([]const u8, structure.type_parameters.len);
        for (structure.type_parameters, 0..) |parameter, index| type_parameters[index] = parameter.name;
        try structures.append(allocator, .{
            .export_name = structure.name,
            .id = .{ .owner = owner, .module = module_name, .name = structure.name },
            .type_parameters = type_parameters,
            .is_class = structure.is_class,
            .base = if (structure.base) |base| mappedType(base, type_map, generic_map) else null,
            .fields = try fields.toOwnedSlice(allocator),
            .constructors = try constructors.toOwnedSlice(allocator),
            .methods = try methods.toOwnedSlice(allocator),
            .position = structure.position,
        });
    }
    var functions: std.ArrayList(Function) = .empty;
    var enums: std.ArrayList(Enum) = .empty;
    for (program.enums) |enumeration| {
        if (!enumeration.is_public or std.mem.eql(u8, enumeration.name, "Result")) continue;
        const variants = try allocator.alloc(EnumVariant, enumeration.variants.len);
        for (enumeration.variants, 0..) |variant, variant_index| {
            const associated_types = try allocator.alloc(Types.Type, variant.associated_types.len);
            for (variant.associated_types, 0..) |associated_type, type_index| {
                associated_types[type_index] = mappedType(associated_type, type_map, generic_map);
            }
            variants[variant_index] = .{ .name = variant.name, .associated_types = associated_types, .raw_value = variant.raw_value };
        }
        const type_parameters = try allocator.alloc([]const u8, enumeration.type_parameters.len);
        for (enumeration.type_parameters, 0..) |parameter, index| type_parameters[index] = parameter.name;
        try enums.append(allocator, .{
            .export_name = enumeration.name,
            .id = .{ .owner = owner, .module = module_name, .name = enumeration.name },
            .type_parameters = type_parameters,
            .variants = variants,
            .raw_type = enumeration.raw_type,
            .position = enumeration.position,
        });
    }
    for (program.functions) |function| {
        if (!function.is_public) continue;
        const parameter_types = try allocator.alloc(Types.Type, function.parameters.len);
        for (function.parameters, 0..) |parameter, index| parameter_types[index] = mappedType(parameter.type, type_map, generic_map);
        const type_parameters = try allocator.alloc([]const u8, function.type_parameters.len);
        for (function.type_parameters, 0..) |parameter, index| type_parameters[index] = parameter.name;
        try functions.append(allocator, .{
            .export_name = function.name,
            .id = .{
                .owner = owner,
                .module = module_name,
                .name = function.name,
                .parameter_types = parameter_types,
            },
            .type_parameters = type_parameters,
            .return_type = mappedType(function.return_type, type_map, generic_map),
            .position = function.position,
            .required_parameters = requiredParameterCount(function.parameters),
        });
    }
    return .{
        .owner = owner,
        .name = module_name,
        .structures = try structures.toOwnedSlice(allocator),
        .enums = try enums.toOwnedSlice(allocator),
        .functions = try functions.toOwnedSlice(allocator),
        .type_aliases = &.{},
    };
}

fn requiredParameterCount(parameters: []const Ast.Parameter) usize {
    for (parameters, 0..) |parameter, index| {
        if (parameter.default != null) return index;
    }
    return parameters.len;
}

fn mappedType(type_value: Types.Type, type_map: []const Types.Type, generic_map: []const Types.Type) Types.Type {
    if (type_value.optionalChild()) |child| return .optional(mappedType(child, type_map, generic_map));
    if (type_value.genericInstantiationIndex()) |index| {
        return if (index < generic_map.len) generic_map[index] else type_value;
    }
    const index = type_value.structureIndex() orelse return type_value;
    return if (index < type_map.len) type_map[index] else type_value;
}

test "build stable typed identities from public declarations only" {
    const first_parameters = [_]Ast.Parameter{
        .{ .position = .{ .offset = 0, .line = 1, .column = 1 }, .name = "value", .type = .int },
    };
    const second_parameters = [_]Ast.Parameter{
        .{ .position = .{ .offset = 0, .line = 1, .column = 1 }, .name = "value", .type = .bool },
    };
    const functions = [_]Ast.Function{
        .{
            .is_public = true,
            .position = .{ .offset = 0, .line = 1, .column = 1 },
            .name_position = .{ .offset = 12, .line = 1, .column = 13 },
            .name = "convert",
            .parameters = &first_parameters,
            .return_type = .int,
            .statements = &.{},
        },
        .{
            .position = .{ .offset = 0, .line = 2, .column = 1 },
            .name_position = .{ .offset = 5, .line = 2, .column = 6 },
            .name = "hidden",
            .parameters = &.{},
            .return_type = .void,
            .statements = &.{},
        },
        .{
            .is_public = true,
            .position = .{ .offset = 0, .line = 3, .column = 1 },
            .name_position = .{ .offset = 12, .line = 3, .column = 13 },
            .name = "convert",
            .parameters = &second_parameters,
            .return_type = .bool,
            .statements = &.{},
        },
    };
    const interface = try build(std.testing.allocator, .project, "Math.Convert", .{ .functions = &functions });
    defer {
        for (interface.functions) |function| std.testing.allocator.free(function.id.parameter_types);
        std.testing.allocator.free(interface.functions);
    }

    try std.testing.expectEqual(@as(usize, 2), interface.functions.len);
    try std.testing.expect(interface.functions[0].id.eql(.{
        .owner = .project,
        .module = "Math.Convert",
        .name = "convert",
        .parameter_types = &.{.int},
    }));
    try std.testing.expect(!interface.functions[0].id.eql(interface.functions[1].id));
}

test "build public nominal structure contracts without layout" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const fields = [_]Ast.StructureField{.{
        .position = .{ .offset = 0, .line = 2, .column = 5 },
        .name_position = .{ .offset = 11, .line = 2, .column = 12 },
        .name = "x",
        .mutable = true,
        .type = .int,
        .default = null,
    }};
    const structures = [_]Ast.Structure{.{
        .is_public = true,
        .position = .{ .offset = 0, .line = 1, .column = 1 },
        .name_position = .{ .offset = 14, .line = 1, .column = 15 },
        .name = "Vec2",
        .fields = &fields,
    }};
    const interface = try build(arena.allocator(), .project, "Geometry.Vec2", .{
        .type_names = &.{"Vec2"},
        .structures = &structures,
        .functions = &.{},
    });
    try std.testing.expectEqual(@as(usize, 1), interface.structures.len);
    try std.testing.expect(interface.structures[0].id.eql(.{
        .owner = .project,
        .module = "Geometry.Vec2",
        .name = "Vec2",
    }));
    try std.testing.expectEqual(Types.Type.int, interface.structures[0].fields[0].type);
}
