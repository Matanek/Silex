const std = @import("std");
const Ast = @import("../Ast.zig");

const component_store_name = "GFX.ECS.ComponentStore";
const world_name = "GFX.ECS.World";

pub fn intrinsicForSpecialization(
    self: anytype,
    structure_type: Ast.Type,
    method_name: []const u8,
    arguments: []const Ast.Type,
) ?Ast.FunctionIntrinsic {
    if (arguments.len != 1) return null;
    const structure = self.structureForType(structure_type) orelse return null;
    if (std.mem.eql(u8, structure.name, component_store_name) and std.mem.eql(u8, method_name, "get_mut")) {
        return .component_get_mut;
    }
    if (std.mem.eql(u8, structure.name, world_name) and std.mem.eql(u8, method_name, "query_get_mut")) {
        return .world_component_get_mut;
    }
    return null;
}
