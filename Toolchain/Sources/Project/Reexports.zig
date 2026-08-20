const std = @import("std");
const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");

pub const State = enum { fresh, loading, loaded };

pub const Binding = struct {
    alias: []const u8,
    path: []const u8,
    module: ?usize,
    declaration: ?[]const u8,
    type_alias: ?Ast.Type = null,
    type_name: ?[]const u8 = null,
    is_public: bool = false,
    position: Source.Position,
};

pub const CatalogContribution = struct {
    contributor: usize,
    target: usize,
    use: Ast.Use,
};

pub const Unit = struct {
    state: State = .fresh,
    program: ?Ast.Program = null,
    bindings: []const Binding = &.{},
    activated_modules: []const usize = &.{},
    fragments: []const usize = &.{},
};

pub const DeclarationKind = enum { function, structure, enumeration };

pub const Target = struct {
    module: usize,
    declaration: []const u8,
};

pub fn resolve(
    units: []const Unit,
    module: usize,
    name: []const u8,
    kind: DeclarationKind,
    visiting: []bool,
) error{ReexportCycle}!?Target {
    @memset(visiting, false);
    return resolveInner(units, module, name, kind, visiting);
}

fn resolveInner(
    units: []const Unit,
    module: usize,
    name: []const u8,
    kind: DeclarationKind,
    visiting: []bool,
) error{ReexportCycle}!?Target {
    const own_fragment = [_]usize{module};
    const fragments = if (units[module].fragments.len == 0)
        own_fragment[0..]
    else
        units[module].fragments;
    for (fragments) |fragment| {
        if (visiting[fragment]) return error.ReexportCycle;
        visiting[fragment] = true;
    }
    defer {
        for (fragments) |fragment| visiting[fragment] = false;
    }

    for (fragments) |fragment| {
        const program = units[fragment].program orelse continue;
        switch (kind) {
            .function => {
                for (program.functions) |function| {
                    if (std.mem.eql(u8, function.name, name) and function.is_public) {
                        return .{ .module = fragment, .declaration = name };
                    }
                }
            },
            .structure => for (program.structures) |structure| {
                if (std.mem.eql(u8, structure.name, name) and structureExported(program, structure)) {
                    return .{ .module = fragment, .declaration = name };
                }
            },
            .enumeration => for (program.enums) |enumeration| {
                if (std.mem.eql(u8, enumeration.name, name) and enumeration.is_public) {
                    return .{ .module = fragment, .declaration = name };
                }
            },
        }
    }
    for (fragments) |fragment| {
        for (units[fragment].bindings) |binding| {
            if (!binding.is_public or !std.mem.eql(u8, binding.alias, name)) continue;
            if (binding.module == null or binding.declaration == null) return null;
            return resolveInner(units, binding.module.?, binding.declaration.?, kind, visiting);
        }
    }
    return null;
}

pub fn structureExported(program: Ast.Program, structure: Ast.Structure) bool {
    if (!structure.is_public) return false;
    var enclosing = structure.enclosing;
    var depth: usize = 0;
    while (enclosing) |owner_name| : (depth += 1) {
        if (depth > program.structures.len) return false;
        for (program.structures) |owner| {
            if (!std.mem.eql(u8, owner.name, owner_name)) continue;
            if (!owner.is_public) return false;
            enclosing = owner.enclosing;
            break;
        } else return false;
    }
    return true;
}
