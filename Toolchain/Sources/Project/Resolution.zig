const std = @import("std");
const Modules = @import("../Modules.zig");
const ModuleScopes = @import("../ModuleScopes.zig");
const Source = @import("../Source.zig");
const Fragments = @import("Fragments.zig");
const Names = @import("Names.zig");
const Reexports = @import("Reexports.zig");

const Target = Reexports.Target;

pub fn structureCandidate(self: anytype, module: usize, name: []const u8) !?Target {
    if (Fragments.contextualOrigin(name)) |origin| if (!Fragments.hasBindingAlias(self.units, module, Fragments.label(origin)) and
        Names.findStructure(self.units[module].program.?, Fragments.label(origin)) == null and
        Names.findEnum(self.units[module].program.?, Fragments.label(origin)) == null)
    {
        const target = try requireContextualTarget(self, module, name, origin);
        if (Names.findStructure(self.units[target.module].program.?, target.declaration) != null) return target;
        return null;
    };
    if (Names.findStructure(self.units[module].program.?, name) != null) return .{ .module = module, .declaration = name };
    if (std.mem.indexOfScalar(u8, name, '.') != null) return self.targetForCall(module, name);
    for (self.units[module].bindings) |binding| {
        if (!std.mem.eql(u8, binding.alias, name)) continue;
        const target_module = binding.module orelse continue;
        return .{
            .module = target_module,
            .declaration = binding.declaration orelse Names.lastSegment(self.index.providers[target_module].name),
        };
    }
    if (try self.resolveTypeAlias(module, name, Names.expressionPosition(module), false)) |target| {
        return switch (target) {
            .fundamental => null,
            .structure => |structure| structure,
            .enumeration => null,
        };
    }
    return null;
}

pub fn enumCandidate(self: anytype, module: usize, name: []const u8) !?Target {
    if (Fragments.contextualOrigin(name)) |origin| if (!Fragments.hasBindingAlias(self.units, module, Fragments.label(origin)) and
        Names.findStructure(self.units[module].program.?, Fragments.label(origin)) == null and
        Names.findEnum(self.units[module].program.?, Fragments.label(origin)) == null)
    {
        const target = try requireContextualTarget(self, module, name, origin);
        if (Names.findEnum(self.units[target.module].program.?, target.declaration) != null) return target;
        return null;
    };
    if (Names.findEnum(self.units[module].program.?, name) != null) return .{ .module = module, .declaration = name };
    if (std.mem.indexOfScalar(u8, name, '.') != null) return self.targetForCall(module, name);
    for (self.units[module].bindings) |binding| {
        if (!std.mem.eql(u8, binding.alias, name)) continue;
        const target_module = binding.module orelse continue;
        return .{
            .module = target_module,
            .declaration = binding.declaration orelse Names.lastSegment(self.index.providers[target_module].name),
        };
    }
    if (try self.resolveTypeAlias(module, name, Names.expressionPosition(module), false)) |target| {
        return switch (target) {
            .fundamental, .structure => null,
            .enumeration => |enumeration| enumeration,
        };
    }
    return null;
}

pub fn requireContextualTarget(
    self: anytype,
    module: usize,
    path: []const u8,
    origin: Modules.Origin,
) !Target {
    if (Fragments.contextualTarget(self.index, module, path)) |target| return target;
    const message = try std.fmt.allocPrint(
        self.allocator,
        "module '{s}' has no {s} fragment for {s}",
        .{ self.index.providers[module].name, Fragments.label(origin), self.target.name() },
    );
    return self.fail(Names.expressionPosition(module), message);
}

pub fn structureTarget(self: anytype, module: usize, name: []const u8) !?Target {
    const target = try structureCandidate(self, module, name) orelse return null;
    if (self.units[target.module].state != .loaded) return null;
    if (Names.findStructure(self.units[target.module].program.?, target.declaration) != null) return target;
    return self.resolveReexport(
        target.module,
        target.declaration,
        .structure,
        try self.allocator.alloc(bool, self.units.len),
    );
}

pub fn enumTarget(self: anytype, module: usize, name: []const u8) !?Target {
    const target = try enumCandidate(self, module, name) orelse return null;
    if (self.units[target.module].state != .loaded) return null;
    if (Names.findEnum(self.units[target.module].program.?, target.declaration) != null) return target;
    return self.resolveReexport(
        target.module,
        target.declaration,
        .enumeration,
        try self.allocator.alloc(bool, self.units.len),
    );
}

pub fn enumReceiverTarget(self: anytype, module: usize, name: []const u8) !?Target {
    const separator = std.mem.indexOfScalar(u8, name, '.');
    if (separator == null) return enumTarget(self, module, name);
    if (try self.targetForCall(module, name)) |target| {
        if (self.units[target.module].state != .loaded) return null;
        if (try enumTarget(self, target.module, target.declaration)) |enumeration| return enumeration;
    }
    for (self.index.providers, 0..) |_, target_module| {
        if (self.units[target_module].state != .loaded) continue;
        for (self.units[target_module].program.?.enums) |enumeration| {
            const target: Target = .{ .module = target_module, .declaration = enumeration.name };
            const canonical = try Names.nominal(self.allocator, try self.enumModule(target), enumeration.name);
            if (std.mem.eql(u8, canonical, name)) return target;
        }
    }
    return null;
}

pub fn functionTarget(self: anytype, target: Target) !?Target {
    if (Fragments.functionTarget(self.index, self.units, target.module, target.declaration)) |function| return function;
    return self.resolveReexport(
        target.module,
        target.declaration,
        .function,
        try self.allocator.alloc(bool, self.units.len),
    );
}

pub fn resolveStructure(self: anytype, module: usize, name: []const u8, position: Source.Position) !Target {
    const target = try structureTarget(self, module, name) orelse {
        const message = try std.fmt.allocPrint(self.allocator, "unknown structure type '{s}'", .{name});
        return self.fail(position, message);
    };
    try requirePublicStructure(self, module, target, position);
    return target;
}

pub fn resolveEnum(self: anytype, module: usize, name: []const u8, position: Source.Position) !Target {
    const target = try enumTarget(self, module, name) orelse {
        const message = try std.fmt.allocPrint(self.allocator, "unknown enum type '{s}'", .{name});
        return self.fail(position, message);
    };
    try requirePublicEnum(self, module, target, position);
    return target;
}

pub fn requirePublicStructure(self: anytype, source_module: usize, target: Target, position: Source.Position) !void {
    if (source_module == target.module) return;
    const target_program = self.units[target.module].program.?;
    const structure = Names.findStructure(target_program, target.declaration).?;
    if (structure.is_internal and canAccessPackage(self, source_module, target.module)) return;
    if (!structure.is_local and !structure.is_internal and sameModuleScope(self, source_module, target.module)) return;
    if (Reexports.structureExported(target_program, structure)) return;
    const message = if (structure.is_local)
        try std.fmt.allocPrint(self.allocator, "structure '{s}' is local to its source file", .{target.declaration})
    else if (structure.is_internal)
        try std.fmt.allocPrint(
            self.allocator,
            "structure '{s}' is package-visible and unavailable outside package '{s}'",
            .{ target.declaration, self.packages.label(self.index.providers[target.module].owner) },
        )
    else
        try std.fmt.allocPrint(self.allocator, "structure '{s}' is module-visible and unavailable outside its module", .{target.declaration});
    return self.fail(position, message);
}

pub fn requirePublicEnum(self: anytype, source_module: usize, target: Target, position: Source.Position) !void {
    if (source_module == target.module) return;
    const enumeration = Names.findEnum(self.units[target.module].program.?, target.declaration).?;
    if (enumeration.is_internal and canAccessPackage(self, source_module, target.module)) return;
    if (!enumeration.is_local and !enumeration.is_internal and sameModuleScope(self, source_module, target.module)) return;
    if (enumeration.is_public) return;
    const message = if (enumeration.is_local)
        try std.fmt.allocPrint(self.allocator, "enum '{s}' is local to its source file", .{target.declaration})
    else if (enumeration.is_internal)
        try std.fmt.allocPrint(
            self.allocator,
            "enum '{s}' is package-visible and unavailable outside package '{s}'",
            .{ target.declaration, self.packages.label(self.index.providers[target.module].owner) },
        )
    else
        try std.fmt.allocPrint(self.allocator, "enum '{s}' is module-visible and unavailable outside its module", .{target.declaration});
    return self.fail(position, message);
}

fn canAccessPackage(self: anytype, accessor_module: usize, provider_module: usize) bool {
    return self.packages.canAccessPackage(
        self.index.providers[accessor_module].owner,
        self.index.providers[provider_module].owner,
    );
}

fn sameModuleScope(self: anytype, left: usize, right: usize) bool {
    return ModuleScopes.same(
        self.module_scope_roots,
        self.index.providers[left].name,
        self.index.providers[right].name,
    );
}

pub fn functionModule(self: anytype, target: Target) ![]const u8 {
    const program = self.units[target.module].program.?;
    for (program.functions) |function| {
        if (std.mem.eql(u8, function.name, target.declaration)) {
            return if (function.is_public) self.index.providers[target.module].name else self.canonicalModule(target.module);
        }
    }
    return self.canonicalModule(target.module);
}

pub fn structureModule(self: anytype, target: Target) ![]const u8 {
    const program = self.units[target.module].program.?;
    const structure = Names.findStructure(program, target.declaration) orelse return self.canonicalModule(target.module);
    return if (Reexports.structureExported(program, structure)) self.index.providers[target.module].name else self.canonicalModule(target.module);
}

pub fn enumModule(self: anytype, target: Target) ![]const u8 {
    const enumeration = Names.findEnum(self.units[target.module].program.?, target.declaration) orelse return self.canonicalModule(target.module);
    return if (enumeration.is_public) self.index.providers[target.module].name else self.canonicalModule(target.module);
}

pub fn nominalModule(self: anytype, target: Target) ![]const u8 {
    return if (Names.findStructure(self.units[target.module].program.?, target.declaration) != null)
        structureModule(self, target)
    else
        enumModule(self, target);
}
