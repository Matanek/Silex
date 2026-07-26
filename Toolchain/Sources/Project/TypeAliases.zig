const std = @import("std");
const Ast = @import("../Ast.zig");
const Reexports = @import("Reexports.zig");

pub const Target = union(enum) {
    fundamental: Ast.Type,
    structure: Reexports.Target,
};

pub const Visit = struct { module: usize, name: []const u8 };

pub fn resolve(
    units: []const Reexports.Unit,
    module: usize,
    name: []const u8,
    visits: []Visit,
) error{AliasCycle}!?Target {
    return resolveInner(units, module, name, visits, 0, false);
}

pub fn resolveExported(
    units: []const Reexports.Unit,
    module: usize,
    name: []const u8,
    visits: []Visit,
) error{AliasCycle}!?Target {
    return resolveInner(units, module, name, visits, 0, true);
}

fn resolveInner(
    units: []const Reexports.Unit,
    module: usize,
    name: []const u8,
    visits: []Visit,
    depth: usize,
    exported_only: bool,
) error{AliasCycle}!?Target {
    for (visits[0..depth]) |visit| {
        if (visit.module == module and std.mem.eql(u8, visit.name, name)) return error.AliasCycle;
    }
    visits[depth] = .{ .module = module, .name = name };
    const next_depth = depth + 1;

    const program = units[module].program orelse return null;
    for (program.structures) |structure| {
        if (std.mem.eql(u8, structure.name, name) and (!exported_only or structure.is_public)) {
            return .{ .structure = .{ .module = module, .declaration = name } };
        }
    }
    for (units[module].bindings) |binding| {
        if (!std.mem.eql(u8, binding.alias, name) or (exported_only and !binding.is_public)) continue;
        if (binding.type_alias) |type_value| {
            if (type_value.structureIndex()) |index| {
                if (index >= program.type_names.len) return null;
                return resolveInner(units, module, program.type_names[index], visits, next_depth, false);
            }
            return .{ .fundamental = type_value };
        }
        if (binding.type_name) |type_name| {
            return resolveInner(units, module, type_name, visits, next_depth, false);
        }
        const target_module = binding.module orelse return null;
        const declaration = binding.declaration orelse return null;
        return resolveInner(units, target_module, declaration, visits, next_depth, true);
    }
    return null;
}
