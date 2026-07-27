const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");

pub const Field = struct {
    owner: usize,
    local: usize,
    flattened: usize,
    declaration: Ast.StructureField,
};

pub fn directBase(self: anytype, structure_index: usize) ?usize {
    if (structure_index >= self.structures.len) return null;
    return self.structures[structure_index].base;
}

pub fn canUpcast(self: anytype, source: Ast.Type, target: Ast.Type) bool {
    const source_index = source.structureIndex() orelse return false;
    const target_index = target.structureIndex() orelse return false;
    if (source_index >= self.structures.len or target_index >= self.structures.len) return false;
    if (!self.structures[source_index].is_class or !self.structures[target_index].is_class) return false;
    var current = self.structures[source_index].base;
    while (current) |index| {
        if (index == target_index) return true;
        current = self.structures[index].base;
    }
    return false;
}

pub fn isDescendant(self: anytype, candidate: usize, ancestor: usize) bool {
    if (candidate == ancestor) return true;
    if (candidate >= self.structures.len) return false;
    var current = self.structures[candidate].base;
    while (current) |index| {
        if (index == ancestor) return true;
        current = self.structures[index].base;
    }
    return false;
}

pub fn fieldByIndex(self: anytype, structure_index: usize, flattened: usize) ?Field {
    if (structure_index >= self.structures.len or flattened >= self.structures[structure_index].fields.len) return null;
    const base = self.structures[structure_index].base;
    const base_count = if (base) |index| self.structures[index].fields.len else 0;
    if (base) |index| if (flattened < base_count) return fieldByIndex(self, index, flattened);
    const local = flattened - base_count;
    const declaration = findDeclaration(self, structure_index) orelse return null;
    if (local >= declaration.fields.len) return null;
    return .{ .owner = structure_index, .local = local, .flattened = flattened, .declaration = declaration.fields[local] };
}

pub fn fieldByName(self: anytype, structure_index: usize, name: []const u8) ?Field {
    if (structure_index >= self.structures.len) return null;
    for (self.structures[structure_index].fields, 0..) |field, index| {
        if (std.mem.eql(u8, field.name, name)) return fieldByIndex(self, structure_index, index);
    }
    return null;
}

pub fn methodOwner(self: anytype, structure_index: usize, name: []const u8) ?usize {
    var current: ?usize = structure_index;
    while (current) |index| {
        const declaration = findDeclaration(self, index) orelse return null;
        for (declaration.methods) |method| if (!method.is_static and std.mem.eql(u8, method.name, name)) return index;
        current = self.structures[index].base;
    }
    return null;
}

pub const MethodCandidate = struct { owner: usize, index: usize, method: Ast.Function };

pub fn methodCandidates(self: anytype, allocator: std.mem.Allocator, structure_index: usize, name: []const u8) ![]const MethodCandidate {
    var result: std.ArrayList(MethodCandidate) = .empty;
    var current: ?usize = structure_index;
    while (current) |owner| : (current = self.structures[owner].base) {
        const declaration = findDeclaration(self, owner) orelse break;
        for (declaration.methods, 0..) |method, method_index| {
            if (method.is_static or !std.mem.eql(u8, method.name, name)) continue;
            if (method.extension != null and owner != structure_index) continue;
            var replaced = false;
            for (result.items) |existing| if (existing.method.extension == null and method.extension == null and sameSignature(existing.method, method)) {
                replaced = true;
                break;
            };
            if (!replaced) try result.append(allocator, .{ .owner = owner, .index = method_index, .method = method });
        }
    }
    return result.toOwnedSlice(allocator);
}

pub fn validateOverrides(self: anytype) !void {
    for (self.program.structures, 0..) |structure, structure_index| {
        if (!structure.is_class) continue;
        for (structure.methods, 0..) |method, method_index| {
            if (method.extension != null) continue;
            if (method.is_static) continue;
            const inherited = inheritedMethod(self, structure_index, method);
            if (method.is_override and inherited == null) {
                return self.fail(method.name_position, "override does not match an inherited method signature");
            }
            if (!method.is_override and inherited != null and (inherited.?.method.is_public or inherited.?.method.is_protected)) {
                return self.fail(method.name_position, "an overriding method must declare 'override'");
            }
            if (inherited) |base| {
                if (!base.method.is_public and !base.method.is_protected) {
                    return self.fail(method.name_position, "only public or protected methods can be overridden");
                }
                if (base.method.is_public and !method.is_public) {
                    return self.fail(method.name_position, "an override cannot reduce public visibility");
                }
                if (base.method.is_protected and !method.is_public and !method.is_protected) {
                    return self.fail(method.name_position, "an override cannot reduce protected visibility");
                }
                const method_flat = flatMethodIndex(self.program, structure_index, method_index);
                const base_flat = flatMethodIndex(self.program, base.owner, base.index);
                if (self.method_mutability[method_flat] and !self.method_mutability[base_flat]) {
                    return self.fail(method.name_position, "an override cannot introduce receiver mutation");
                }
            }
        }
    }
}

fn flatMethodIndex(program: Ast.Program, structure_index: usize, method_index: usize) usize {
    var result: usize = 0;
    for (program.structures[0..structure_index]) |structure| result += structure.methods.len;
    return result + method_index;
}

pub fn implementations(
    self: anytype,
    allocator: std.mem.Allocator,
    owner: usize,
    method_index: usize,
) ![]const Ir.Instruction.DynamicCall.Implementation {
    const slot = self.program.structures[owner].methods[method_index];
    if (slot.extension != null) return &.{};
    var result: std.ArrayList(Ir.Instruction.DynamicCall.Implementation) = .empty;
    for (self.program.structures, 0..) |_, candidate| {
        if (candidate == owner or !isDescendant(self, candidate, owner)) continue;
        if (effectiveOverride(self, candidate, owner, slot)) |function| try result.append(allocator, .{
            .structure = candidate,
            .function = function,
        });
    }
    return result.toOwnedSlice(allocator);
}

fn effectiveOverride(self: anytype, candidate: usize, owner: usize, slot: Ast.Function) ?Ir.FunctionId {
    var current: ?usize = candidate;
    while (current) |index| : (current = self.structures[index].base) {
        if (index == owner) return null;
        const declaration = findDeclaration(self, index) orelse return null;
        for (declaration.methods, 0..) |method, method_index| {
            if (method.is_override and sameSignature(method, slot)) return methodFunctionId(self.program, index, method_index);
        }
    }
    return null;
}

const InheritedMethod = struct { owner: usize, index: usize, method: Ast.Function };

fn inheritedMethod(self: anytype, structure_index: usize, method: Ast.Function) ?InheritedMethod {
    var current = self.structures[structure_index].base;
    while (current) |index| : (current = self.structures[index].base) {
        const declaration = findDeclaration(self, index) orelse return null;
        for (declaration.methods, 0..) |candidate, method_index| {
            if (candidate.extension != null) continue;
            if (!candidate.is_static and sameSignature(candidate, method)) return .{ .owner = index, .index = method_index, .method = candidate };
        }
    }
    return null;
}

pub fn sameSignature(left: Ast.Function, right: Ast.Function) bool {
    if (!std.mem.eql(u8, left.name, right.name) or left.parameters.len != right.parameters.len or
        left.return_type != right.return_type or left.return_mode != right.return_mode) return false;
    for (left.parameters, right.parameters) |left_parameter, right_parameter| {
        if (left_parameter.type != right_parameter.type or left_parameter.mode != right_parameter.mode) return false;
    }
    return true;
}

fn methodFunctionId(program: Ast.Program, structure_index: usize, method_index: usize) Ir.FunctionId {
    var result = program.functions.len;
    for (program.structures) |structure| result += structure.constructors.len;
    for (program.structures[0..structure_index]) |structure| {
        if (!structure.is_protocol) result += structure.methods.len;
    }
    return result + method_index;
}

pub fn findDeclaration(self: anytype, structure_index: usize) ?Ast.Structure {
    if (structure_index >= self.structures.len) return null;
    const name = self.structures[structure_index].name;
    for (self.program.structures) |structure| if (std.mem.eql(u8, structure.name, name)) return structure;
    return null;
}
