const std = @import("std");
const Ast = @import("Ast.zig");
const Source = @import("Source.zig");

pub const Merger = struct {
    allocator: std.mem.Allocator,
    diagnostic: ?Source.Diagnostic = null,

    pub fn init(allocator: std.mem.Allocator) Merger {
        return .{ .allocator = allocator };
    }

    pub fn merge(self: *Merger, source: Ast.Program, allow_generic_methods: bool, allow_conformances: bool) !Ast.Program {
        var program = source;
        const structures = try self.allocator.dupe(Ast.Structure, source.structures);
        for (source.extensions) |extension| {
            if (extension.conformances.len != 0 and !allow_conformances) {
                return self.fail(extension.target_position, "protocol conformance through an extension is not supported yet");
            }
            if (extension.target.genericInstantiationIndex() != null) {
                return self.fail(extension.target_position, "generic extension targets and specializations are not supported");
            }
            const target_index = extension.target.structureIndex() orelse {
                return self.fail(extension.target_position, "an extension target must be a nominal structure or class");
            };
            if (target_index >= source.type_names.len) return self.fail(extension.target_position, "unknown extension target");
            const target_name = source.type_names[target_index];
            const structure_index = findStructure(structures, target_name) orelse {
                return self.fail(extension.target_position, "an extension cannot target an enum, scalar, or collection");
            };
            const target = structures[structure_index];
            if (target.is_protocol) return self.fail(extension.target_position, "a protocol cannot be extended");
            if (target.is_static) return self.fail(extension.target_position, "a static class cannot be extended");
            if (target.collection != null) return self.fail(extension.target_position, "a collection type cannot be extended");
            if (target.type_parameters.len != 0) {
                return self.fail(extension.target_position, "generic extension targets and specializations are not supported");
            }
            const visible_files = if (extension.visible_files.len != 0)
                extension.visible_files
            else
                try self.allocator.dupe(usize, &.{extension.position.file});
            var conformances: std.ArrayList(Ast.ExtensionConformance) = .empty;
            try conformances.appendSlice(self.allocator, target.extension_conformances);
            for (extension.conformances) |relation| {
                const protocol_index = relation.structureIndex() orelse {
                    return self.fail(extension.target_position, "an extension conformance must name a protocol");
                };
                const protocol_name = if (protocol_index < source.type_names.len) source.type_names[protocol_index] else {
                    return self.fail(extension.target_position, "an extension conformance must name a protocol");
                };
                const protocol_structure_index = findStructure(structures, protocol_name) orelse {
                    return self.fail(extension.target_position, "an extension conformance must name a protocol");
                };
                if (!structures[protocol_structure_index].is_protocol) {
                    return self.fail(extension.target_position, "an extension conformance must name a protocol");
                }
                if (declaresConformance(target, relation)) {
                    const message = try std.fmt.allocPrint(self.allocator, "type '{s}' already conforms to protocol '{s}'", .{ target.name, protocol_name });
                    return self.fail(extension.target_position, message);
                }
                for (conformances.items) |existing| if (existing.protocol == relation) {
                    const message = try std.fmt.allocPrint(self.allocator, "extension conformance of '{s}' to '{s}' from '{s}' conflicts with '{s}'", .{
                        target.name,
                        protocol_name,
                        extension.provider,
                        existing.provider,
                    });
                    return self.fail(extension.target_position, message);
                };
                try conformances.append(self.allocator, .{
                    .protocol = relation,
                    .position = extension.target_position,
                    .provider = extension.provider,
                    .visible_files = visible_files,
                });
            }
            structures[structure_index].extension_conformances = try conformances.toOwnedSlice(self.allocator);
            var methods: std.ArrayList(Ast.Function) = .empty;
            try methods.appendSlice(self.allocator, target.methods);
            for (extension.methods) |source_method| {
                if (source_method.type_parameters.len != 0 and !allow_generic_methods) {
                    return self.fail(source_method.name_position, "generic extension methods are not supported yet");
                }
                var method = source_method;
                if (!method.visibility_explicit) {
                    method.is_public = !target.is_class;
                    method.is_private = target.is_class;
                } else if (!target.is_class and method.is_private) {
                    return self.fail(method.name_position, "structure extension methods only support public or internal visibility");
                }
                method.extension = .{ .provider = extension.provider, .visible_files = visible_files };
                for (methods.items) |existing| {
                    if (!sameSignature(existing, method)) continue;
                    if (existing.extension) |other| {
                        if (!overlap(other.visible_files, visible_files)) continue;
                        const message = try std.fmt.allocPrint(self.allocator, "extension method '{s}' from '{s}' conflicts with '{s}' on type '{s}'", .{
                            method.name,
                            extension.provider,
                            other.provider,
                            target.name,
                        });
                        return self.fail(method.name_position, message);
                    }
                    const message = try std.fmt.allocPrint(self.allocator, "extension method '{s}' conflicts with a method declared by type '{s}'", .{ method.name, target.name });
                    return self.fail(method.name_position, message);
                }
                try methods.append(self.allocator, method);
            }
            structures[structure_index].methods = try methods.toOwnedSlice(self.allocator);
        }
        program.structures = structures;
        program.extensions = &.{};
        return program;
    }

    fn fail(self: *Merger, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

fn declaresConformance(target: Ast.Structure, protocol: Ast.Type) bool {
    if (target.base == protocol) return true;
    for (target.conformances) |relation| if (relation == protocol) return true;
    return false;
}

fn findStructure(structures: []const Ast.Structure, name: []const u8) ?usize {
    for (structures, 0..) |structure, index| if (std.mem.eql(u8, structure.name, name)) return index;
    return null;
}

fn sameSignature(left: Ast.Function, right: Ast.Function) bool {
    if (left.is_static != right.is_static or !std.mem.eql(u8, left.name, right.name) or left.parameters.len != right.parameters.len or
        left.return_type != right.return_type or left.return_mode != right.return_mode or left.type_parameters.len != right.type_parameters.len) return false;
    for (left.parameters, right.parameters) |left_parameter, right_parameter| {
        if (left_parameter.type != right_parameter.type or left_parameter.mode != right_parameter.mode) return false;
    }
    return true;
}

fn overlap(left: []const usize, right: []const usize) bool {
    for (left) |left_file| for (right) |right_file| if (left_file == right_file) return true;
    return false;
}
