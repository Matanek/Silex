const std = @import("std");
const Ir = @import("Ir.zig");

const Allocator = std.mem.Allocator;

/// Computes the conservative cycle capability of every IR structure once.
/// Non-class structures are false because only class identity can close a
/// reference cycle; value containers are traversed from their owning class.
pub fn analyze(allocator: Allocator, program: Ir.Program) Allocator.Error![]bool {
    const result = try allocator.alloc(bool, program.structures.len);
    @memset(result, false);
    for (program.structures, 0..) |structure, index| {
        if (structure.is_class) result[index] = try mayCycle(allocator, program, index);
    }
    return result;
}

pub fn mayCycle(allocator: Allocator, program: Ir.Program, index: usize) Allocator.Error!bool {
    // Class identity is the only cyclic storage. Value containers merely carry
    // edges; their copied elements retain once per owner in portable IR.
    const visited = try allocator.alloc(bool, program.structures.len);
    defer allocator.free(visited);
    @memset(visited, false);
    return reaches(program, .structure(index), index, true, visited);
}

fn reaches(program: Ir.Program, value: Ir.Type, target: usize, initial: bool, visited: []bool) bool {
    if (value.optionalChild()) |child| return reaches(program, child, target, false, visited);
    if (value.functionIndex() != null) return true;
    const index = value.structureIndex() orelse return false;
    if (index >= program.structures.len) return false;
    if (!initial and index == target) return true;
    if (visited[index]) return false;
    visited[index] = true;
    const structure = program.structures[index];
    if (structure.is_protocol) return true;
    if (structure.is_class) {
        // A field declared as a base class can point to any derived instance,
        // including the candidate itself or a subtype that adds a back edge.
        for (program.structures, 0..) |candidate, candidate_index| {
            if (!candidate.is_class or !isAncestor(program, index, candidate_index)) continue;
            if (!initial and candidate_index == target) return true;
            for (candidate.fields) |field| if (reaches(program, field.type, target, false, visited)) return true;
        }
        return false;
    }
    if (structure.collection) |collection| return !collection.view and reaches(program, collection.element, target, false, visited);
    if (enumByStructure(program, index)) |enumeration| {
        for (enumeration.variants) |variant| for (variant.associated_types) |child| {
            if (reaches(program, child, target, false, visited)) return true;
        };
    }
    for (structure.fields) |field| if (reaches(program, field.type, target, false, visited)) return true;
    return false;
}

fn isAncestor(program: Ir.Program, ancestor: usize, derived: usize) bool {
    var current: ?usize = derived;
    var visited: usize = 0;
    while (current) |index| {
        if (index >= program.structures.len or visited >= program.structures.len) return false;
        if (index == ancestor) return true;
        current = program.structures[index].base;
        visited += 1;
    }
    return false;
}

fn enumByStructure(program: Ir.Program, structure_index: usize) ?Ir.Enum {
    for (program.enums) |enumeration| if (enumeration.type_index == structure_index) return enumeration;
    return null;
}

test "cycle analysis separates acyclic classes from direct and contained cycles" {
    const acyclic: Ir.Program = .{
        .structures = &.{.{
            .name = "Acyclic",
            .fields = &.{.{ .name = "value", .type = .int, .mutable = true }},
            .is_class = true,
        }},
        .functions = &.{},
    };
    try std.testing.expect(!try mayCycle(std.testing.allocator, acyclic, 0));

    const direct: Ir.Program = .{
        .structures = &.{.{
            .name = "Direct",
            .fields = &.{.{ .name = "next", .type = .structure(0), .mutable = true }},
            .is_class = true,
        }},
        .functions = &.{},
    };
    try std.testing.expect(try mayCycle(std.testing.allocator, direct, 0));

    const contained: Ir.Program = .{
        .structures = &.{
            .{
                .name = "Contained",
                .fields = &.{.{ .name = "items", .type = .structure(1), .mutable = true }},
                .is_class = true,
            },
            .{
                .name = "ContainedList",
                .fields = &.{},
                .collection = .{ .element = .structure(0), .length = null },
            },
        },
        .functions = &.{},
    };
    try std.testing.expect(try mayCycle(std.testing.allocator, contained, 0));
}

test "cycle analysis remains conservative for dynamic edges and subclasses" {
    const dynamic: Ir.Program = .{
        .structures = &.{
            .{
                .name = "ClosureOwner",
                .fields = &.{.{ .name = "callback", .type = .function(0), .mutable = true }},
                .is_class = true,
            },
            .{ .name = "Protocol", .fields = &.{}, .is_protocol = true },
            .{
                .name = "ProtocolOwner",
                .fields = &.{.{ .name = "value", .type = .structure(1), .mutable = true }},
                .is_class = true,
            },
        },
        .functions = &.{},
    };
    try std.testing.expect(try mayCycle(std.testing.allocator, dynamic, 0));
    try std.testing.expect(try mayCycle(std.testing.allocator, dynamic, 2));

    const hierarchy: Ir.Program = .{
        .structures = &.{
            .{
                .name = "Base",
                .fields = &.{.{ .name = "value", .type = .int, .mutable = true }},
                .is_class = true,
            },
            .{
                .name = "Derived",
                .fields = &.{.{ .name = "back", .type = .structure(0), .mutable = true }},
                .is_class = true,
                .base = 0,
            },
        },
        .functions = &.{},
    };
    try std.testing.expect(try mayCycle(std.testing.allocator, hierarchy, 0));
}
