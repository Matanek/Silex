const std = @import("std");
const Ast = @import("../Ast.zig");
const Modules = @import("../Modules.zig");
const Completion = @import("Completion.zig");
const ProjectIndex = @import("ProjectIndex.zig");
const Types = @import("Types.zig");
const Workspace = @import("Workspace.zig");

/// A source declaration, never a generated helper. Keeping its original program
/// preserves parameter types, labels and definition positions across providers.
pub const Method = struct {
    provider: Modules.Provider,
    loaded: ProjectIndex.LoadedProgram,
    structure: Ast.Structure,
    receiver: []const u8,
    function: Ast.Function,
    signature: []const u8,
    is_default: bool,
    is_extension: bool = false,
    ambiguous: bool = false,
};

pub fn defaults(
    allocator: std.mem.Allocator,
    io: std.Io,
    documents: []const Types.Document,
    project: ProjectIndex.IndexedProject,
    current: ProjectIndex.LoadedProgram,
    receiver: []const u8,
) ![]const Method {
    const provider = ProjectIndex.currentProvider(project) orelse return &.{};
    var resolver = Resolver{ .allocator = allocator, .io = io, .documents = documents, .project = project };
    const root_path = try Workspace.providerTypePath(allocator, project, current.program, provider, Completion.nominalReceiverName(receiver));
    resolver.extensions = try ProjectIndex.activeExtensionProviders(allocator, io, documents, project, current, root_path);
    const methods = try resolver.walk(current, provider, receiver, 0);
    var result: std.ArrayList(Method) = .empty;
    for (methods) |method| {
        if (!method.is_default or method.ambiguous or
            !Workspace.importedMemberVisible(project, method.provider, method.structure) or
            !Workspace.importedMemberVisible(project, method.provider, method.function)) continue;
        try result.append(allocator, method);
    }
    return result.toOwnedSlice(allocator);
}

const Resolver = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    documents: []const Types.Document,
    project: ProjectIndex.IndexedProject,
    extensions: []const ProjectIndex.ActiveExtensionProvider = &.{},

    fn walk(self: *Resolver, loaded: ProjectIndex.LoadedProgram, provider: Modules.Provider, receiver: []const u8, depth: usize) anyerror![]const Method {
        if (depth > 128) return &.{};
        const structure = Completion.localStructure(loaded.program, receiver) orelse {
            const target_path = try Workspace.providerTypePath(self.allocator, self.project, loaded.program, provider, Completion.nominalReceiverName(receiver));
            return self.path(target_path, depth + 1);
        };
        var result: std.ArrayList(Method) = .empty;
        for (structure.methods) |method| {
            if (method.is_static or method.accessor != null or method.protocol_witness != null) continue;
            if (structure.is_protocol and !method.protocol_default) continue;
            try result.append(self.allocator, .{
                .provider = provider,
                .loaded = loaded,
                .structure = structure,
                .receiver = receiver,
                .function = method,
                .signature = try self.signature(loaded.program, provider, structure, receiver, method),
                .is_default = structure.is_protocol and method.protocol_default,
            });
        }
        if (structure.base) |base| {
            const base_type = try Completion.specializedTypeName(self.allocator, loaded.program, structure, receiver, base);
            try self.merge(&result, try self.walk(loaded, provider, base_type, depth + 1), false);
        }
        const own_path = try ProjectIndex.nominalIdentityPath(self.allocator, self.project, try Workspace.providerTypePath(self.allocator, self.project, loaded.program, provider, structure.name));
        for (self.extensions) |entry| for (entry.loaded.program.extensions) |extension| {
            const extension_path = try ProjectIndex.nominalIdentityPath(self.allocator, self.project, try Workspace.providerTypePath(self.allocator, self.project, entry.loaded.program, entry.provider, Completion.typeName(entry.loaded.program, extension.target)));
            if (!std.mem.eql(u8, own_path, extension_path)) continue;
            for (extension.methods) |method| {
                if (method.is_static or method.accessor != null) continue;
                const candidate: Method = .{ .provider = entry.provider, .loaded = entry.loaded, .structure = structure, .receiver = receiver, .function = method, .is_default = false, .is_extension = true, .signature = try self.signature(entry.loaded.program, entry.provider, structure, receiver, method) };
                try self.merge(&result, &.{candidate}, false);
            }
            for (extension.conformances) |relation| try self.mergeConformance(&result, try self.walk(entry.loaded, entry.provider, Completion.typeName(entry.loaded.program, relation), depth + 1), entry.loaded, entry.provider);
        };
        for (structure.conformances) |conformance| {
            try self.mergeConformance(&result, try self.walk(loaded, provider, Completion.typeName(loaded.program, conformance), depth + 1), loaded, provider);
        }
        for (structure.extension_conformances) |relation| try self.mergeConformance(&result, try self.walk(loaded, provider, Completion.typeName(loaded.program, relation.protocol), depth + 1), loaded, provider);
        return result.toOwnedSlice(self.allocator);
    }

    fn path(self: *Resolver, requested: []const u8, depth: usize) anyerror![]const Method {
        if (depth > 128) return &.{};
        const target = Workspace.declarationTarget(self.project.index, requested) orelse return &.{};
        const module_name = self.project.index.providers[target.provider].name;
        for (self.project.index.providers) |provider| {
            if (!std.mem.eql(u8, provider.name, module_name) or
                !self.project.graph.canAccess(self.project.current_owner, provider.owner, provider.name)) continue;
            const loaded = try ProjectIndex.loadProgram(self.allocator, self.io, self.documents, provider) orelse continue;
            if (Completion.localStructure(loaded.program, target.declaration)) |_| return self.walk(loaded, provider, target.declaration, depth + 1);
            for (loaded.program.uses) |use| {
                const alias = use.alias orelse lastSegment(use.path);
                if (!use.is_public or !std.mem.eql(u8, alias, target.declaration)) continue;
                return self.path(try ProjectIndex.canonicalUsePath(self.allocator, self.project, provider, use.path), depth + 1);
            }
        }
        return &.{};
    }

    fn merge(self: *Resolver, result: *std.ArrayList(Method), inherited: []const Method, conformance: bool) !void {
        for (inherited) |candidate| {
            if (conformance and !candidate.is_default) continue;
            var found = false;
            for (result.items) |*existing| {
                if (!std.mem.eql(u8, existing.signature, candidate.signature)) continue;
                // A concrete declaration (including a base implementation) wins.
                // Two unrelated protocol defaults cannot select one arbitrarily.
                if (conformance and existing.is_default and
                    (!std.mem.eql(u8, existing.provider.path, candidate.provider.path) or
                        existing.function.name_position.offset != candidate.function.name_position.offset)) existing.ambiguous = true;
                found = true;
                break;
            }
            if (!found) try result.append(self.allocator, candidate);
        }
    }

    fn mergeConformance(self: *Resolver, result: *std.ArrayList(Method), inherited: []const Method, loaded: ProjectIndex.LoadedProgram, provider: Modules.Provider) !void {
        var scope: ?[]const ProjectIndex.ActiveExtensionProvider = null;
        for (inherited) |candidate| for (result.items) |*existing| {
            if (!existing.is_extension or !std.mem.eql(u8, existing.signature, candidate.signature)) continue;
            if (scope == null) {
                var project = self.project;
                project.current_path = provider.path;
                project.current_owner = provider.owner;
                scope = try ProjectIndex.activeExtensionProviders(self.allocator, self.io, self.documents, project, loaded, null);
            }
            var active = false;
            for (scope.?) |entry| if (std.mem.eql(u8, entry.provider.path, existing.provider.path)) {
                active = true;
                break;
            };
            // Conformance belongs to its declaring source. An extension activated
            // only by the later caller cannot displace that source's default.
            if (!active) existing.* = candidate;
        };
        try self.merge(result, inherited, true);
    }

    fn signature(self: *Resolver, program: Ast.Program, provider: Modules.Provider, structure: Ast.Structure, receiver: []const u8, method: Ast.Function) ![]const u8 {
        var value = try std.fmt.allocPrint(self.allocator, "{s}<{d}>(", .{ method.name, method.type_parameters.len });
        for (method.parameters) |parameter| {
            value = try std.fmt.allocPrint(self.allocator, "{s}{s}:{s};", .{ value, @tagName(parameter.mode), try self.memberTypeIdentity(program, provider, structure, receiver, parameter.type) });
        }
        return std.fmt.allocPrint(self.allocator, "{s}){s}:{s}", .{ value, @tagName(method.return_mode), try self.memberTypeIdentity(program, provider, structure, receiver, method.return_type) });
    }

    fn memberTypeIdentity(self: *Resolver, program: Ast.Program, provider: Modules.Provider, structure: Ast.Structure, receiver: []const u8, value: Ast.Type) anyerror![]const u8 {
        var direct = value;
        var depth: usize = 0;
        while (direct.optionalChild()) |child| {
            direct = child;
            depth += 1;
        }
        if (direct.functionIndex()) |index| {
            if (index >= program.function_types.len) return error.InvalidFunctionType;
            const signature_value = program.function_types[index];
            var text = try self.allocator.dupe(u8, "func(");
            for (signature_value.parameters) |parameter| text = try std.fmt.allocPrint(self.allocator, "{s}{s}:{s};", .{
                text, @tagName(parameter.mode), try self.memberTypeIdentity(program, provider, structure, receiver, parameter.type),
            });
            text = try std.fmt.allocPrint(self.allocator, "{s}){s}:{s}", .{ text, @tagName(signature_value.return_mode), try self.memberTypeIdentity(program, provider, structure, receiver, signature_value.return_type) });
            for (0..depth) |_| text = try std.fmt.allocPrint(self.allocator, "{s}?", .{text});
            return text;
        }
        return self.typeIdentity(program, provider, try Completion.specializedTypeName(self.allocator, program, structure, receiver, value));
    }

    fn typeIdentity(self: *Resolver, program: Ast.Program, provider: Modules.Provider, spelling: []const u8) ![]const u8 {
        // Type spellings consist of nominal/primitive words and punctuation.
        // Qualify nominal words; parameter labels never participate in identity.
        var result: std.Io.Writer.Allocating = .init(self.allocator);
        var start: usize = 0;
        while (start < spelling.len) {
            if (!std.ascii.isAlphabetic(spelling[start]) and spelling[start] != '_') {
                try result.writer.writeByte(spelling[start]);
                start += 1;
                continue;
            }
            var end = start + 1;
            while (end < spelling.len and (std.ascii.isAlphanumeric(spelling[end]) or spelling[end] == '_' or spelling[end] == '.')) : (end += 1) {}
            const word = spelling[start..end];
            const primitive = std.meta.stringToEnum(Ast.Type, word) != null or std.mem.eql(u8, word, "float") or std.mem.eql(u8, word, "int64") or std.mem.eql(u8, word, "uint64");
            try result.writer.writeAll(if (primitive) word else try Workspace.providerTypePath(self.allocator, self.project, program, provider, word));
            start = end;
        }
        return result.toOwnedSlice();
    }
};

fn lastSegment(name: []const u8) []const u8 {
    return if (std.mem.lastIndexOfScalar(u8, name, '.')) |dot| name[dot + 1 ..] else name;
}
