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
};

pub const Module = struct {
    owner: Owner,
    name: []const u8,
    functions: []const Function,
};

pub fn build(
    allocator: Allocator,
    owner: Owner,
    module_name: []const u8,
    program: Ast.Program,
) Allocator.Error!Module {
    var functions: std.ArrayList(Function) = .empty;
    for (program.functions) |function| {
        if (!function.is_public) continue;
        const parameter_types = try allocator.alloc(Types.Type, function.parameters.len);
        for (function.parameters, 0..) |parameter, index| parameter_types[index] = parameter.type;
        try functions.append(allocator, .{
            .id = .{
                .owner = owner,
                .module = module_name,
                .name = function.name,
                .parameter_types = parameter_types,
            },
            .return_type = function.return_type,
            .position = function.position,
        });
    }
    return .{ .owner = owner, .name = module_name, .functions = try functions.toOwnedSlice(allocator) };
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
