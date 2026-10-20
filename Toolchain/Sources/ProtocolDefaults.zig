const std = @import("std");
const Ast = @import("Ast.zig");
const Source = @import("Source.zig");

pub fn present(program: Ast.Program) bool {
    for (program.structures) |structure| if (structure.is_protocol) {
        for (structure.methods) |method| if (method.protocol_default) return true;
    };
    return false;
}

// Expose signatures before generic inference. Bodies remain nominal protocol
// code; a conformer never instantiates a template against its own members.
pub const Expander = struct {
    allocator: std.mem.Allocator,
    diagnostic: ?Source.Diagnostic = null,
    program: Ast.Program = undefined,
    structures: []Ast.Structure = &.{},
    visited: []u8 = &.{},

    pub fn expand(self: *Expander, source: Ast.Program) (Source.Error || std.mem.Allocator.Error)!Ast.Program {
        if (!present(source)) return source;
        self.program = source;
        self.structures = try self.allocator.dupe(Ast.Structure, source.structures);
        self.visited = try self.allocator.alloc(u8, source.structures.len);
        @memset(self.visited, 0);
        for (self.structures, 0..) |_, index| try self.prepare(index);
        var result = source;
        result.structures = self.structures;
        return result;
    }

    fn declaration(self: *Expander, type_value: Ast.Type) ?usize {
        const index = type_value.structureIndex() orelse return null;
        if (index >= self.program.type_names.len) return null;
        for (self.structures, 0..) |candidate, ordinal| {
            if (std.mem.eql(u8, candidate.name, self.program.type_names[index])) return ordinal;
        }
        return null;
    }

    fn prepare(self: *Expander, index: usize) (Source.Error || std.mem.Allocator.Error)!void {
        if (self.visited[index] != 0) return; // Inheritance validation owns cycles.
        self.visited[index] = 1;
        const structure = self.structures[index];
        if (structure.is_protocol) return;
        if (structure.base) |base| if (self.declaration(base)) |parent| {
            if (!self.structures[parent].is_protocol) try self.prepare(parent);
        };
        var methods: std.ArrayList(Ast.Function) = .empty;
        try methods.appendSlice(self.allocator, structure.methods);
        if (structure.base) |base| try self.append(index, &methods, base, null, structure.name_position.file);
        for (structure.conformances) |protocol| try self.append(index, &methods, protocol, null, structure.name_position.file);
        for (structure.extension_conformances) |relation| try self.append(index, &methods, relation.protocol, .{
            .provider = relation.provider,
            .visible_files = relation.visible_files,
        }, relation.position.file);
        self.structures[index].methods = try methods.toOwnedSlice(self.allocator);
        self.visited[index] = 2;
    }

    fn append(
        self: *Expander,
        index: usize,
        methods: *std.ArrayList(Ast.Function),
        relation: Ast.Type,
        extension: ?Ast.ExtensionMethod,
        file: usize,
    ) (Source.Error || std.mem.Allocator.Error)!void {
        const protocol_index = self.declaration(relation) orelse return;
        const protocol = self.structures[protocol_index];
        if (!protocol.is_protocol) return;
        for (protocol.methods, 0..) |requirement, ordinal| {
            if (!requirement.protocol_default) continue;
            if (self.inherited(index, requirement, file)) continue;
            var existing: ?usize = null;
            for (methods.items, 0..) |method, slot| if (!method.is_static and method.type_parameters.len == 0 and sameSignature(method, requirement)) {
                if (!activeAt(method, file)) continue;
                existing = slot;
                break;
            };
            if (existing) |slot| {
                const method = methods.items[slot];
                if (method.protocol_witness) |origin| {
                    if (!std.mem.eql(u8, origin.protocol, protocol.name) or origin.method != ordinal) {
                        self.diagnostic = .{
                            .position = self.structures[index].name_position,
                            .message = try std.fmt.allocPrint(self.allocator, "type '{s}' has conflicting defaults for method '{s}'; implement it explicitly", .{ self.structures[index].name, requirement.name }),
                        };
                        return error.InvalidSource;
                    }
                }
                continue;
            }
            var method = requirement;
            method.protocol_default = false;
            method.protocol_witness = .{ .protocol = protocol.name, .method = ordinal, .file = file };
            method.extension = extension;
            method.statements = &.{};
            try methods.append(self.allocator, method);
        }
    }

    fn inherited(self: *Expander, index: usize, requirement: Ast.Function, file: usize) bool {
        var current = self.structures[index].base;
        var remaining = self.structures.len;
        while (current) |base| {
            if (remaining == 0) return false;
            remaining -= 1;
            const parent = self.declaration(base) orelse return false;
            const declaration_value = self.structures[parent];
            if (declaration_value.is_protocol) return false;
            for (declaration_value.methods) |method| if (!method.is_static and activeAt(method, file) and sameSignature(method, requirement)) return true;
            current = declaration_value.base;
        }
        return false;
    }
};

fn activeAt(method: Ast.Function, file: usize) bool {
    const extension = method.extension orelse return true;
    for (extension.visible_files) |visible| if (visible == file) return true;
    return false;
}

fn sameSignature(left: Ast.Function, right: Ast.Function) bool {
    if (!std.mem.eql(u8, left.name, right.name) or left.parameters.len != right.parameters.len or
        left.return_type != right.return_type or left.return_mode != right.return_mode) return false;
    for (left.parameters, right.parameters) |a, b| if (a.type != b.type or a.mode != b.mode) return false;
    return true;
}
