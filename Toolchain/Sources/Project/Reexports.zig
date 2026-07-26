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

pub const Unit = struct {
    state: State = .fresh,
    program: ?Ast.Program = null,
    bindings: []const Binding = &.{},
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
    if (visiting[module]) return error.ReexportCycle;
    visiting[module] = true;
    defer visiting[module] = false;

    const program = units[module].program orelse return null;
    switch (kind) {
        .function => {
            for (program.functions) |function| {
                if (std.mem.eql(u8, function.name, name) and function.is_public) {
                    return .{ .module = module, .declaration = name };
                }
            }
        },
        .structure => for (program.structures) |structure| {
            if (std.mem.eql(u8, structure.name, name) and structure.is_public) {
                return .{ .module = module, .declaration = name };
            }
        },
        .enumeration => for (program.enums) |enumeration| {
            if (std.mem.eql(u8, enumeration.name, name) and enumeration.is_public) {
                return .{ .module = module, .declaration = name };
            }
        },
    }
    for (units[module].bindings) |binding| {
        if (!binding.is_public or !std.mem.eql(u8, binding.alias, name)) continue;
        if (binding.module == null or binding.declaration == null) return null;
        return resolveInner(units, binding.module.?, binding.declaration.?, kind, visiting);
    }
    return null;
}
