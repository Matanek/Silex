const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Resources = @import("Resources.zig");
const ProtocolValues = @import("ProtocolValues.zig");

// Recursive value graphs must recurse at execution, not during IR emission.
// Classes and callable captures already have their own resource boundaries.
pub fn prepare(self: anytype) ![]const bool {
    const recursive = try self.allocator.alloc(bool, self.structures.len);
    @memset(recursive, false);
    const visited = try self.allocator.alloc(bool, self.structures.len);
    for (self.structures, 0..) |structure, index| {
        if (structure.is_class or structure.is_static) continue;
        if (!structure.is_protocol) {
            @memset(visited, false);
            visited[index] = true;
            if (structure.collection) |collection| {
                recursive[index] = !collection.view and reaches(self, collection.element, index, visited);
            } else {
                for (self.enums) |enumeration| {
                    if (enumeration.type_index != index) continue;
                    for (enumeration.variants) |variant| for (variant.associated_types) |payload| {
                        if (reaches(self, payload, index, visited)) recursive[index] = true;
                    };
                }
                for (structure.fields) |field| {
                    if (reaches(self, field.type, index, visited)) recursive[index] = true;
                }
            }
            continue;
        }
        @memset(visited, false);
        visited[index] = true;
        if (inlineCycle(self, .structure(index), index, visited, true)) {
            const declaration = @import("Inheritance.zig").findDeclaration(self, index) orelse return error.InvalidSource;
            return self.fail(declaration.name_position, "recursive protocol values must cross a class or dynamic-array field");
        }
        @memset(visited, false);
        visited[index] = true;
        for (try ProtocolValues.conformers(self, index)) |conformer| {
            if (reaches(self, .structure(conformer), index, visited)) {
                recursive[index] = true;
                break;
            }
        }
    }
    return recursive;
}

fn reaches(self: anytype, type_value: Ast.Type, target: usize, visited: []bool) bool {
    if (type_value.optionalChild()) |child| return reaches(self, child, target, visited);
    const index = type_value.structureIndex() orelse return false;
    if (index == target) return true;
    if (index >= self.structures.len or visited[index]) return false;
    visited[index] = true;
    const structure = self.structures[index];
    if (structure.is_class) return false;
    if (structure.is_protocol) {
        for (self.structures, 0..) |candidate, conformer| {
            if (candidate.is_protocol or candidate.is_static) continue;
            if (ProtocolValues.conforms(self, conformer, index) and reaches(self, .structure(conformer), target, visited)) return true;
        }
        return false;
    }
    if (structure.collection) |collection| return !collection.view and reaches(self, collection.element, target, visited);
    for (self.enums) |enumeration| {
        if (enumeration.type_index != index) continue;
        for (enumeration.variants) |variant| for (variant.associated_types) |payload| {
            if (reaches(self, payload, target, visited)) return true;
        };
        return false;
    }
    for (structure.fields) |field| if (reaches(self, field.type, target, visited)) return true;
    return false;
}

pub fn count(self: anytype) usize {
    var result: usize = 0;
    for (self.recursive_value_resources) |recursive| if (recursive) {
        result += 6;
    };
    return result;
}

pub fn functionId(self: anytype, protocol: usize, retain: bool, ownership: Ir.Ownership, invoke_drop: bool) Ir.FunctionId {
    var result = @import("Callbacks.zig").boundWrapperBase(self.program);
    for (self.recursive_value_resources[0..protocol]) |recursive| if (recursive) {
        result += 6;
    };
    return result + operation(retain, ownership, invoke_drop);
}

fn operation(retain: bool, ownership: Ir.Ownership, invoke_drop: bool) usize {
    const kind: usize = if (retain) 0 else if (invoke_drop) 1 else 2;
    return kind * 2 + @intFromBool(ownership == .edge);
}

pub fn analyze(self: anytype, protocol: usize, retain: bool, ownership: Ir.Ownership, invoke_drop: bool) !Ir.Function {
    const type_value = Ast.Type.structure(protocol);
    var builder: Model.FunctionBuilder = .{ .return_type = .void };
    try builder.blocks.append(self.allocator, .{});
    try builder.value_types.append(self.allocator, type_value);
    if (self.structures[protocol].is_protocol) {
        try Resources.emitProtocolResourceBody(self, &builder, protocol, 0, retain, ownership, invoke_drop);
    } else if (retain) {
        try Resources.retainValueBody(self, &builder, type_value, 0, ownership);
    } else {
        try Resources.emitDropBody(self, &builder, type_value, 0, ownership, invoke_drop);
    }
    self.terminate(&builder, .return_void);
    const blocks = try self.allocator.alloc(Ir.Block, builder.blocks.items.len);
    for (builder.blocks.items, 0..) |*block, index| blocks[index] = .{
        .instructions = try block.instructions.toOwnedSlice(self.allocator),
        .instruction_positions = try block.instruction_positions.toOwnedSlice(self.allocator),
        .terminator = block.terminator orelse return error.InvalidSource,
        .terminator_position = block.terminator_position,
    };
    return .{
        .name = try std.fmt.allocPrint(self.allocator, "{s}.$resource{d}", .{ self.structures[protocol].name, operation(retain, ownership, invoke_drop) }),
        .parameter_types = try self.allocator.dupe(Ast.Type, &.{type_value}),
        .return_type = .void,
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .borrow_origins = try builder.borrow_origins.toOwnedSlice(self.allocator),
        .borrow_ends = try builder.borrow_ends.toOwnedSlice(self.allocator),
        .blocks = blocks,
    };
}

fn inlineCycle(self: anytype, type_value: Ast.Type, target: usize, visited: []bool, first: bool) bool {
    if (type_value.optionalChild()) |child| return inlineCycle(self, child, target, visited, false);
    const index = type_value.structureIndex() orelse return false;
    if (!first and index == target) return true;
    if (index >= self.structures.len or (!first and visited[index])) return false;
    visited[index] = true;
    const structure = self.structures[index];
    if (structure.is_class) return false;
    if (structure.is_protocol) {
        for (self.structures, 0..) |candidate, conformer| {
            if (candidate.is_protocol or candidate.is_static) continue;
            if (ProtocolValues.conforms(self, conformer, index) and inlineCycle(self, .structure(conformer), target, visited, false)) return true;
        }
        return false;
    }
    if (structure.collection) |collection| {
        if (collection.view or collection.length == null) return false;
        return inlineCycle(self, collection.element, target, visited, false);
    }
    for (self.enums) |enumeration| {
        if (enumeration.type_index != index) continue;
        for (enumeration.variants) |variant| for (variant.associated_types) |payload| {
            if (inlineCycle(self, payload, target, visited, false)) return true;
        };
        return false;
    }
    for (structure.fields) |field| if (inlineCycle(self, field.type, target, visited, false)) return true;
    return false;
}
