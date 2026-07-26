const std = @import("std");
const Ast = @import("../Ast.zig");
const Reexports = @import("Reexports.zig");

pub const Composition = struct {
    types: []const Ast.GenericType,
    maps: []const []const Ast.Type,
};

pub fn compose(
    allocator: std.mem.Allocator,
    units: []const Reexports.Unit,
    type_maps: []const []const Ast.Type,
) std.mem.Allocator.Error!Composition {
    var types: std.ArrayList(Ast.GenericType) = .empty;
    const maps = try allocator.alloc([]const Ast.Type, units.len);
    @memset(maps, &.{});
    for (units, 0..) |unit, module| {
        const program = unit.program orelse continue;
        const map = try allocator.alloc(Ast.Type, program.generic_types.len);
        for (program.generic_types, 0..) |generic, index| {
            const arguments = try allocator.alloc(Ast.Type, generic.arguments.len);
            for (generic.arguments, 0..) |argument, argument_index| {
                arguments[argument_index] = remap(argument, type_maps[module], map[0..index]);
            }
            const candidate: Ast.GenericType = .{
                .position = generic.position,
                .base = remap(generic.base, type_maps[module], map[0..index]),
                .arguments = arguments,
            };
            var found: ?usize = null;
            for (types.items, 0..) |existing, existing_index| {
                if (existing.base == candidate.base and std.mem.eql(Ast.Type, existing.arguments, candidate.arguments)) {
                    found = existing_index;
                    break;
                }
            }
            const generic_index = found orelse value: {
                const next = types.items.len;
                try types.append(allocator, candidate);
                break :value next;
            };
            map[index] = .genericInstantiation(generic_index);
        }
        maps[module] = map;
    }
    return .{ .types = try types.toOwnedSlice(allocator), .maps = maps };
}

pub fn remap(type_value: Ast.Type, type_map: []const Ast.Type, generic_map: []const Ast.Type) Ast.Type {
    if (type_value.optionalChild()) |child| return .optional(remap(child, type_map, generic_map));
    if (type_value.genericInstantiationIndex()) |index| {
        return if (index < generic_map.len) generic_map[index] else type_value;
    }
    const index = type_value.structureIndex() orelse return type_value;
    if (index >= type_map.len) return type_value;
    const mapped = type_map[index];
    if (mapped.genericInstantiationIndex()) |generic_index| {
        return if (generic_index < generic_map.len) generic_map[generic_index] else mapped;
    }
    return mapped;
}
