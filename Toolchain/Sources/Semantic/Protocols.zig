const std = @import("std");
const Ast = @import("../Ast.zig");
const Inheritance = @import("Inheritance.zig");

pub fn validate(self: anytype) !void {
    for (self.program.structures, 0..) |declaration, structure_index| {
        if (declaration.is_protocol) continue;
        var seen: std.ArrayList(usize) = .empty;
        if (declaration.base) |relation| if (protocolIndex(self, relation)) |protocol_index| {
            try validateOne(self, structure_index, declaration, protocol_index, declaration.name_position);
            try seen.append(self.allocator, protocol_index);
        };
        for (declaration.conformances) |relation| {
            const protocol_index = protocolIndex(self, relation) orelse {
                return self.fail(declaration.name_position, "a conformance entry must name a protocol");
            };
            for (seen.items) |existing| if (existing == protocol_index) {
                const message = try std.fmt.allocPrint(self.allocator, "type '{s}' declares protocol '{s}' more than once", .{
                    declaration.name,
                    self.structures[protocol_index].name,
                });
                return self.fail(declaration.name_position, message);
            };
            try validateOne(self, structure_index, declaration, protocol_index, declaration.name_position);
            try seen.append(self.allocator, protocol_index);
        }
        for (declaration.extension_conformances) |relation| {
            const protocol_index = protocolIndex(self, relation.protocol) orelse {
                return self.fail(relation.position, "an extension conformance must name a protocol");
            };
            try validateOne(self, structure_index, declaration, protocol_index, relation.position);
        }
    }
}

pub fn conforms(self: anytype, structure_index: usize, protocol_index: usize) bool {
    var current: ?usize = structure_index;
    while (current) |candidate| : (current = self.structures[candidate].base) {
        const declaration = Inheritance.findDeclaration(self, candidate) orelse return false;
        if (declaration.base) |relation| if (protocolIndex(self, relation) == protocol_index) return true;
        for (declaration.conformances) |relation| if (protocolIndex(self, relation) == protocol_index) return true;
        if (candidate == structure_index) for (declaration.extension_conformances) |relation| {
            if (protocolIndex(self, relation.protocol) == protocol_index) return true;
        };
    }
    return false;
}

fn validateOne(self: anytype, structure_index: usize, declaration: Ast.Structure, protocol_index: usize, position: @import("../Source.zig").Position) !void {
    const protocol = Inheritance.findDeclaration(self, protocol_index) orelse return error.InvalidSource;
    for (protocol.methods) |requirement| {
        const implementation = findMethod(self, structure_index, requirement, position) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "type '{s}' does not implement protocol requirement '{s}.{s}'", .{
                declaration.name,
                protocol.name,
                requirement.name,
            });
            return self.fail(declaration.name_position, message);
        };
        if (!implementation.is_public) {
            const message = try std.fmt.allocPrint(self.allocator, "method '{s}' satisfying protocol '{s}' must be public", .{
                implementation.name,
                protocol.name,
            });
            return self.fail(implementation.name_position, message);
        }
    }
}

fn findMethod(self: anytype, structure_index: usize, requirement: Ast.Function, position: @import("../Source.zig").Position) ?Ast.Function {
    var current: ?usize = structure_index;
    while (current) |candidate| : (current = self.structures[candidate].base) {
        const declaration = Inheritance.findDeclaration(self, candidate) orelse return null;
        for (declaration.methods) |method| {
            if (method.is_static or method.type_parameters.len != 0) continue;
            if (method.extension) |extension| {
                var active = false;
                for (extension.visible_files) |file| if (file == position.file) {
                    active = true;
                    break;
                };
                if (!active) continue;
            }
            if (Inheritance.sameSignature(method, requirement)) return method;
        }
    }
    return null;
}

fn protocolIndex(self: anytype, type_value: Ast.Type) ?usize {
    const index = type_value.structureIndex() orelse return null;
    if (index >= self.structures.len or !self.structures[index].is_protocol) return null;
    return index;
}
