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
    id: DeclarationId,
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
    name: []const u8,
    type: Types.Type,
    mutable: bool,
};

pub const Constructor = struct {
    parameter_types: []const Types.Type,
    required_parameters: usize = 0,
};

pub const Method = struct {
    name: []const u8,
    parameter_types: []const Types.Type,
    return_type: Types.Type,
    required_parameters: usize = 0,
};

pub const Structure = struct {
    id: TypeId,
    fields: []const StructureField,
    constructors: []const Constructor,
    methods: []const Method,
    position: Source.Position,
};

pub const Module = struct {
    owner: Owner,
    name: []const u8,
    structures: []const Structure,
    functions: []const Function,
};

pub fn build(
    allocator: Allocator,
    owner: Owner,
    module_name: []const u8,
    program: Ast.Program,
) Allocator.Error!Module {
    const type_map = try allocator.alloc(usize, program.type_names.len);
    defer allocator.free(type_map);
    for (type_map, 0..) |*mapped, index| mapped.* = index;
    return buildMapped(allocator, owner, module_name, program, type_map);
}

pub fn buildMapped(
    allocator: Allocator,
    owner: Owner,
    module_name: []const u8,
    program: Ast.Program,
    type_map: []const usize,
) Allocator.Error!Module {
    var structures: std.ArrayList(Structure) = .empty;
    for (program.structures) |structure| {
        if (!structure.is_public) continue;
        const fields = try allocator.alloc(StructureField, structure.fields.len);
        for (structure.fields, 0..) |field, index| fields[index] = .{
            .name = field.name,
            .type = mappedType(field.type, type_map),
            .mutable = field.mutable,
        };
        const constructors = try allocator.alloc(Constructor, structure.constructors.len);
        for (structure.constructors, 0..) |constructor, constructor_index| {
            const parameters = try allocator.alloc(Types.Type, constructor.parameters.len);
            for (constructor.parameters, 0..) |parameter, parameter_index| {
                parameters[parameter_index] = mappedType(parameter.type, type_map);
            }
            constructors[constructor_index] = .{
                .parameter_types = parameters,
                .required_parameters = requiredParameterCount(constructor.parameters),
            };
        }
        const methods = try allocator.alloc(Method, structure.methods.len);
        for (structure.methods, 0..) |method, method_index| {
            const parameters = try allocator.alloc(Types.Type, method.parameters.len);
            for (method.parameters, 0..) |parameter, parameter_index| {
                parameters[parameter_index] = mappedType(parameter.type, type_map);
            }
            methods[method_index] = .{
                .name = method.name,
                .parameter_types = parameters,
                .return_type = mappedType(method.return_type, type_map),
                .required_parameters = requiredParameterCount(method.parameters),
            };
        }
        try structures.append(allocator, .{
            .id = .{ .owner = owner, .module = module_name, .name = structure.name },
            .fields = fields,
            .constructors = constructors,
            .methods = methods,
            .position = structure.position,
        });
    }
    var functions: std.ArrayList(Function) = .empty;
    for (program.functions) |function| {
        if (!function.is_public) continue;
        const parameter_types = try allocator.alloc(Types.Type, function.parameters.len);
        for (function.parameters, 0..) |parameter, index| parameter_types[index] = mappedType(parameter.type, type_map);
        try functions.append(allocator, .{
            .id = .{
                .owner = owner,
                .module = module_name,
                .name = function.name,
                .parameter_types = parameter_types,
            },
            .return_type = mappedType(function.return_type, type_map),
            .position = function.position,
            .required_parameters = requiredParameterCount(function.parameters),
        });
    }
    return .{
        .owner = owner,
        .name = module_name,
        .structures = try structures.toOwnedSlice(allocator),
        .functions = try functions.toOwnedSlice(allocator),
    };
}

fn requiredParameterCount(parameters: []const Ast.Parameter) usize {
    for (parameters, 0..) |parameter, index| {
        if (parameter.default != null) return index;
    }
    return parameters.len;
}

fn mappedType(type_value: Types.Type, type_map: []const usize) Types.Type {
    const index = type_value.structureIndex() orelse return type_value;
    return if (index < type_map.len) .structure(type_map[index]) else type_value;
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
