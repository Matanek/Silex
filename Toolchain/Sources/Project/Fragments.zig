const std = @import("std");
const Modules = @import("../Modules.zig");
const Names = @import("Names.zig");
const Reexports = @import("Reexports.zig");

pub fn install(
    allocator: std.mem.Allocator,
    index: Modules.Index,
    units: []Reexports.Unit,
) std.mem.Allocator.Error!void {
    var start: usize = 0;
    while (start < index.providers.len) {
        var end = start + 1;
        while (end < index.providers.len and same(index, start, end)) end += 1;
        const fragments = try allocator.alloc(usize, end - start);
        for (fragments, start..) |*fragment, provider| fragment.* = provider;
        for (start..end) |provider| units[provider].fragments = fragments;
        start = end;
    }
}

pub fn same(index: Modules.Index, left: usize, right: usize) bool {
    const left_provider = index.providers[left];
    const right_provider = index.providers[right];
    return Modules.compositionOwner(left_provider) == Modules.compositionOwner(right_provider) and
        std.mem.eql(u8, left_provider.name, right_provider.name);
}

pub fn contextualTarget(index: Modules.Index, source: usize, path: []const u8) ?Reexports.Target {
    const separator = std.mem.indexOfScalar(u8, path, '.') orelse return null;
    const origin: Modules.Origin = if (std.mem.eql(u8, path[0..separator], "Platform"))
        .platform
    else if (std.mem.eql(u8, path[0..separator], "Target"))
        .target
    else
        return null;
    const declaration = path[separator + 1 ..];
    if (declaration.len == 0) return null;
    return .{ .module = findOrigin(index, source, origin) orelse return null, .declaration = declaration };
}

pub fn findOrigin(index: Modules.Index, source: usize, origin: Modules.Origin) ?usize {
    const provider = index.providers[source];
    for (index.providers, 0..) |candidate, target| {
        if (candidate.owner == provider.owner and candidate.origin == origin and std.mem.eql(u8, candidate.name, provider.name)) return target;
    }
    return null;
}

pub fn contextualOrigin(path: []const u8) ?Modules.Origin {
    const separator = std.mem.indexOfScalar(u8, path, '.') orelse return null;
    if (std.mem.eql(u8, path[0..separator], "Platform")) return .platform;
    if (std.mem.eql(u8, path[0..separator], "Target")) return .target;
    return null;
}

pub fn hasBindingAlias(units: []const Reexports.Unit, module: usize, alias: []const u8) bool {
    for (units[module].bindings) |binding| {
        if (std.mem.eql(u8, binding.alias, alias)) return true;
    }
    return false;
}

pub fn canonicalModuleName(allocator: std.mem.Allocator, provider: Modules.Provider) std.mem.Allocator.Error![]const u8 {
    return switch (provider.origin) {
        .portable, .entry => provider.name,
        .platform => std.fmt.allocPrint(allocator, "{s}.$Platform", .{provider.name}),
        .target => std.fmt.allocPrint(allocator, "{s}.$Target", .{provider.name}),
    };
}

pub fn label(origin: Modules.Origin) []const u8 {
    return switch (origin) {
        .portable => "Module",
        .platform => "Platform",
        .target => "Target",
        .entry => "entry",
    };
}

pub fn concatenate(
    allocator: std.mem.Allocator,
    comptime T: type,
    left: []const T,
    right: []const T,
) std.mem.Allocator.Error![]const T {
    const result = try allocator.alloc(T, left.len + right.len);
    @memcpy(result[0..left.len], left);
    @memcpy(result[left.len..], right);
    return result;
}

pub fn hasPublicDeclaration(
    index: Modules.Index,
    units: []const Reexports.Unit,
    module: usize,
    name: []const u8,
) bool {
    for (units, 0..) |unit, fragment| {
        if (!same(index, module, fragment)) continue;
        const program = unit.program orelse continue;
        for (program.functions) |function| {
            if (function.is_public and std.mem.eql(u8, function.name, name)) return true;
        }
        for (program.structures) |structure| {
            if (Reexports.structureExported(program, structure) and std.mem.eql(u8, structure.name, name)) return true;
        }
        for (program.enums) |enumeration| {
            if (enumeration.is_public and std.mem.eql(u8, enumeration.name, name)) return true;
        }
        for (unit.bindings) |binding| {
            if (binding.is_public and binding.declaration != null and std.mem.eql(u8, binding.alias, name)) return true;
        }
    }
    return false;
}

pub fn structureTarget(
    index: Modules.Index,
    units: []const Reexports.Unit,
    module: usize,
    name: []const u8,
) ?Reexports.Target {
    for (units, 0..) |unit, fragment| {
        if (!same(index, module, fragment)) continue;
        const program = unit.program orelse continue;
        if (Names.findStructure(program, name) != null) return .{ .module = fragment, .declaration = name };
    }
    return null;
}

pub fn enumTarget(
    index: Modules.Index,
    units: []const Reexports.Unit,
    module: usize,
    name: []const u8,
) ?Reexports.Target {
    for (units, 0..) |unit, fragment| {
        if (!same(index, module, fragment)) continue;
        const program = unit.program orelse continue;
        if (Names.findEnum(program, name) != null) return .{ .module = fragment, .declaration = name };
    }
    return null;
}

pub fn functionTarget(
    index: Modules.Index,
    units: []const Reexports.Unit,
    module: usize,
    name: []const u8,
) ?Reexports.Target {
    for (units, 0..) |unit, fragment| {
        if (!same(index, module, fragment)) continue;
        const program = unit.program orelse continue;
        for (program.functions) |function| {
            if (std.mem.eql(u8, function.name, name)) return .{ .module = fragment, .declaration = name };
        }
    }
    return null;
}

pub fn otherFunctionTarget(
    index: Modules.Index,
    units: []const Reexports.Unit,
    module: usize,
    name: []const u8,
) ?Reexports.Target {
    for (units, 0..) |unit, fragment| {
        if (fragment == module or !same(index, module, fragment)) continue;
        const program = unit.program orelse continue;
        for (program.functions) |function| {
            if (std.mem.eql(u8, function.name, name)) return .{ .module = fragment, .declaration = name };
        }
    }
    return null;
}
