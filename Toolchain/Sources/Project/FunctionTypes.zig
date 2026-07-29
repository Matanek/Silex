const std = @import("std");
const Ast = @import("../Ast.zig");
const GenericTypes = @import("GenericTypes.zig");
const Reexports = @import("Reexports.zig");

pub fn modeSpelling(mode: Ast.Parameter.Mode) []const u8 {
    return switch (mode) {
        .value => "",
        .read => "@",
        .mutable => "&",
    };
}

pub const Composition = struct {
    types: []const Ast.FunctionType,
    maps: []const []const Ast.Type,
};

pub fn compose(
    allocator: std.mem.Allocator,
    units: []const Reexports.Unit,
    type_maps: []const []const Ast.Type,
    generic_maps: []const []const Ast.Type,
) std.mem.Allocator.Error!Composition {
    var types: std.ArrayList(Ast.FunctionType) = .empty;
    const maps = try allocator.alloc([]const Ast.Type, units.len);
    @memset(maps, &.{});
    for (units, 0..) |unit, module| {
        const program = unit.program orelse continue;
        const map = try allocator.alloc(Ast.Type, program.function_types.len);
        for (program.function_types, 0..) |function_type, index| {
            const parameters = try allocator.alloc(Ast.FunctionType.ParameterType, function_type.parameters.len);
            for (function_type.parameters, 0..) |parameter, parameter_index| parameters[parameter_index] = .{
                .type = remap(parameter.type, type_maps[module], generic_maps[module], map[0..index]),
                .mode = parameter.mode,
            };
            const candidate: Ast.FunctionType = .{
                .parameters = parameters,
                .return_type = remap(function_type.return_type, type_maps[module], generic_maps[module], map[0..index]),
                .return_mode = function_type.return_mode,
            };
            var found: ?usize = null;
            for (types.items, 0..) |existing, existing_index| if (equal(existing, candidate)) {
                found = existing_index;
                break;
            };
            const function_index = found orelse value: {
                const next = types.items.len;
                try types.append(allocator, candidate);
                break :value next;
            };
            map[index] = .function(function_index);
        }
        maps[module] = map;
    }
    return .{ .types = try types.toOwnedSlice(allocator), .maps = maps };
}

pub fn remap(type_value: Ast.Type, type_map: []const Ast.Type, generic_map: []const Ast.Type, function_map: []const Ast.Type) Ast.Type {
    if (type_value.optionalChild()) |child| return .optional(remap(child, type_map, generic_map, function_map));
    if (type_value.functionIndex()) |index| return if (index < function_map.len) function_map[index] else type_value;
    return GenericTypes.remap(type_value, type_map, generic_map);
}

pub fn equal(left: Ast.FunctionType, right: Ast.FunctionType) bool {
    if (left.return_type != right.return_type or left.return_mode != right.return_mode or left.parameters.len != right.parameters.len) return false;
    for (left.parameters, right.parameters) |left_parameter, right_parameter| {
        if (left_parameter.type != right_parameter.type or left_parameter.mode != right_parameter.mode) return false;
    }
    return true;
}
