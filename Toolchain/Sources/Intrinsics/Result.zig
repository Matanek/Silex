const std = @import("std");
const Ast = @import("../Ast.zig");

const position = @import("../Source.zig").Position{ .offset = 0, .line = 1, .column = 1 };
const parameters = [_]Ast.TypeParameter{
    .{ .position = position, .name = "T" },
    .{ .position = position, .name = "E" },
};
const success_types = [_]Ast.Type{.genericParameter(0)};
const failure_types = [_]Ast.Type{.genericParameter(1)};
const variants = [_]Ast.EnumVariant{
    .{ .position = position, .name = "success", .associated_types = &success_types },
    .{ .position = position, .name = "failure", .associated_types = &failure_types },
};

pub const name = "Result";

pub fn install(allocator: std.mem.Allocator, source: Ast.Program) std.mem.Allocator.Error!Ast.Program {
    var program = source;
    for (program.enums) |enumeration| if (std.mem.eql(u8, enumeration.name, name)) return program;

    var names = std.ArrayList([]const u8).empty;
    try names.appendSlice(allocator, program.type_names);
    var found = false;
    for (names.items) |candidate| if (std.mem.eql(u8, candidate, name)) {
        found = true;
        break;
    };
    if (!found) try names.append(allocator, name);
    program.type_names = try names.toOwnedSlice(allocator);

    var enums = std.ArrayList(Ast.Enum).empty;
    try enums.appendSlice(allocator, program.enums);
    try enums.append(allocator, .{
        .is_public = true,
        .position = position,
        .name_position = position,
        .name = name,
        .type_parameters = &parameters,
        .variants = &variants,
    });
    program.enums = try enums.toOwnedSlice(allocator);
    return program;
}

pub fn acceptsArguments(template: Ast.Enum, arguments: []const Ast.Type) bool {
    if (!std.mem.eql(u8, template.name, name) or arguments.len != 2) return false;
    return arguments[1] != .void;
}

pub fn hasVoidSuccess(enumeration: Ast.Enum, variant: Ast.EnumVariant, associated_types: []const Ast.Type) bool {
    return std.mem.startsWith(u8, enumeration.name, "Result<") and
        std.mem.eql(u8, variant.name, "success") and
        associated_types.len == 1 and associated_types[0] == .void;
}

pub fn isConcrete(enumeration: anytype) bool {
    return std.mem.startsWith(u8, enumeration.name, "Result<");
}

pub fn successType(enumeration: anytype) ?Ast.Type {
    if (!isConcrete(enumeration)) return null;
    for (enumeration.variants) |variant| if (std.mem.eql(u8, variant.name, "success")) {
        return if (variant.associated_types.len == 0) .void else variant.associated_types[0];
    };
    return null;
}

pub fn errorType(enumeration: anytype) ?Ast.Type {
    if (!isConcrete(enumeration)) return null;
    for (enumeration.variants) |variant| if (std.mem.eql(u8, variant.name, "failure") and variant.associated_types.len == 1) {
        return variant.associated_types[0];
    };
    return null;
}
