const std = @import("std");
const Ast = @import("../Ast.zig");
const Modules = @import("../Modules.zig");
const ParserModule = @import("../Parser.zig");
const Source = @import("../Source.zig");
const TargetModule = @import("../Target.zig");
const Completion = @import("Completion.zig");
const ProjectIndex = @import("ProjectIndex.zig");
const Protocol = @import("Protocol.zig");
const Types = @import("Types.zig");
const Workspace = @import("Workspace.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

const DeclarationTarget = struct {
    provider: usize,
    declaration: []const u8,
};

pub fn definitionAtForTarget(
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    selected_target: TargetModule.Target,
    root_uri: ?[]const u8,
    document_uri: []const u8,
    documents: []const Types.Document,
    source: []const u8,
    cursor: usize,
    encoding: Types.PositionEncoding,
) !?Types.Location {
    const request = qualifiedPathAt(source, cursor) orelse return null;
    var parser = ParserModule.Parser.init(allocator, source);
    const program = parser.parse() catch return null;
    const document_path = try ProjectIndex.pathFromUri(allocator, document_uri);
    if (std.mem.indexOfScalar(u8, request.path, '.') == null) {
        for (program.functions) |function| {
            if (!std.mem.eql(u8, function.name, request.path)) continue;
            return location(
                allocator,
                document_path,
                source,
                function.name_position,
                function.name.len,
                encoding,
            );
        }
    }
    if (std.mem.lastIndexOfScalar(u8, request.path, '.')) |separator| {
        const receiver = request.path[0..separator];
        const member_name = request.path[separator + 1 ..];
        if (Completion.resolveReceiverType(allocator, source, program, request.end, receiver)) |receiver_type| {
            for (program.structures) |structure| {
                if (!std.mem.eql(u8, structure.name, receiver_type)) continue;
                for (structure.methods) |method| if (std.mem.eql(u8, method.name, member_name)) {
                    return location(allocator, document_path, source, method.name_position, method.name.len, encoding);
                };
                for (structure.fields) |field| if (std.mem.eql(u8, field.name, member_name)) {
                    return location(allocator, document_path, source, field.name_position, field.name.len, encoding);
                };
                break;
            }
        }
    }
    const root_hint = if (root_uri) |uri| try ProjectIndex.pathFromUri(allocator, uri) else null;
    const root = try ProjectIndex.projectRoot(allocator, io, document_path, root_hint);
    const project = try ProjectIndex.index(
        allocator,
        io,
        global_packages_root,
        selected_target,
        root,
        document_path,
    );
    const member = lastSegment(request.path);
    const resolved_path = if (try Workspace.importedReceiverTypeAt(
        allocator,
        io,
        documents,
        project,
        source,
        request.end,
    )) |receiver_type|
        try std.fmt.allocPrint(allocator, "{s}.{s}", .{ receiver_type, member })
    else
        try resolveImportedPath(allocator, program, request.path);
    return definitionForPath(allocator, io, documents, project, resolved_path, encoding, 0);
}

fn definitionForPath(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: ProjectIndex.IndexedProject,
    path: []const u8,
    encoding: Types.PositionEncoding,
    depth: usize,
) !?Types.Location {
    if (depth > 16) return null;
    const target = declarationTarget(project.index, path) orelse return null;
    const provider = project.index.providers[target.provider];
    if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) return null;
    const loaded = try ProjectIndex.loadProgram(allocator, io, documents, provider) orelse return null;
    if (declarationPosition(loaded.program, provider, target.declaration, project.current_owner)) |definition| {
        return location(allocator, provider.path, loaded.source, definition.position, definition.name.len, encoding);
    }
    for (loaded.program.uses) |use| {
        const alias = use.alias orelse lastSegment(use.path);
        if (!std.mem.eql(u8, alias, target.declaration)) continue;
        if (!use.is_public and provider.owner != project.current_owner) return null;
        return definitionForPath(allocator, io, documents, project, use.path, encoding, depth + 1);
    }
    return null;
}

const Definition = struct {
    position: Source.Position,
    name: []const u8,
};

fn declarationPosition(
    program: Ast.Program,
    provider: Modules.Provider,
    declaration: []const u8,
    current_owner: usize,
) ?Definition {
    const separator = std.mem.indexOfScalar(u8, declaration, '.');
    const nominal_name = if (separator) |index| declaration[0..index] else declaration;
    const member_name = if (separator) |index| declaration[index + 1 ..] else null;

    for (program.structures) |structure| {
        const principal_member = member_name == null and
            std.mem.eql(u8, structure.name, lastSegment(provider.name)) and
            !std.mem.eql(u8, structure.name, nominal_name);
        if (!std.mem.eql(u8, structure.name, nominal_name) and !principal_member) continue;
        if (!visible(structure.is_public, structure.is_internal, structure.is_local, provider, current_owner)) return null;
        const requested_member = member_name orelse if (principal_member) nominal_name else return .{
            .position = structure.name_position,
            .name = structure.name,
        };
        for (structure.fields) |field| if (std.mem.eql(u8, field.name, requested_member) and
            memberVisible(field.is_local, field.is_internal, field.is_private, field.is_protected, provider, current_owner)) return .{
            .position = field.name_position,
            .name = field.name,
        };
        for (structure.static_fields) |field| if (std.mem.eql(u8, field.name, requested_member) and
            memberVisible(field.is_local, field.is_internal, field.is_private, field.is_protected, provider, current_owner)) return .{
            .position = field.name_position,
            .name = field.name,
        };
        for (structure.methods) |method| if (std.mem.eql(u8, method.name, requested_member) and
            memberVisible(method.is_local, method.is_internal, method.is_private, method.is_protected, provider, current_owner)) return .{
            .position = method.name_position,
            .name = method.name,
        };
        break;
    }
    for (program.enums) |enumeration| {
        const principal_member = member_name == null and
            std.mem.eql(u8, enumeration.name, lastSegment(provider.name)) and
            !std.mem.eql(u8, enumeration.name, nominal_name);
        if (!std.mem.eql(u8, enumeration.name, nominal_name) and !principal_member) continue;
        if (!visible(enumeration.is_public, enumeration.is_internal, enumeration.is_local, provider, current_owner)) return null;
        const requested_member = member_name orelse if (principal_member) nominal_name else return .{
            .position = enumeration.name_position,
            .name = enumeration.name,
        };
        for (enumeration.variants) |variant| if (std.mem.eql(u8, variant.name, requested_member)) return .{
            .position = variant.position,
            .name = variant.name,
        };
        break;
    }
    for (program.functions) |function| {
        if (!std.mem.eql(u8, function.name, declaration)) continue;
        if (!visible(function.is_public, function.is_internal, function.is_local, provider, current_owner)) return null;
        return .{ .position = function.name_position, .name = function.name };
    }
    const target_name = if (member_name != null)
        nominal_name
    else if (std.mem.eql(u8, lastSegment(provider.name), nominal_name))
        nominal_name
    else
        lastSegment(provider.name);
    const requested_member = member_name orelse nominal_name;
    for (program.extensions) |extension| {
        if (!std.mem.eql(u8, Completion.typeName(program, extension.target), target_name)) continue;
        for (extension.methods) |method| {
            if (!std.mem.eql(u8, method.name, requested_member)) continue;
            if (!memberVisible(
                method.is_local,
                method.is_internal,
                method.is_private,
                method.is_protected,
                provider,
                current_owner,
            )) return null;
            return .{ .position = method.name_position, .name = method.name };
        }
    }
    return null;
}

fn visible(
    is_public: bool,
    is_internal: bool,
    is_local: bool,
    provider: Modules.Provider,
    current_owner: usize,
) bool {
    if (is_local) return provider.owner == current_owner;
    if (is_internal) return provider.owner == current_owner;
    return is_public or provider.owner == current_owner;
}

fn memberVisible(
    is_local: bool,
    is_internal: bool,
    is_private: bool,
    is_protected: bool,
    provider: Modules.Provider,
    current_owner: usize,
) bool {
    if (is_local or is_private or is_protected) return false;
    return !is_internal or provider.owner == current_owner;
}

fn resolveImportedPath(allocator: Allocator, program: Ast.Program, path: []const u8) ![]const u8 {
    const separator = std.mem.indexOfScalar(u8, path, '.') orelse path.len;
    const root = path[0..separator];
    for (program.uses) |use| {
        const alias = use.alias orelse lastSegment(use.path);
        if (!std.mem.eql(u8, alias, root)) continue;
        return if (separator == path.len)
            use.path
        else
            std.fmt.allocPrint(allocator, "{s}{s}", .{ use.path, path[separator..] });
    }
    return path;
}

const RequestedPath = struct {
    path: []const u8,
    end: usize,
};

fn qualifiedPathAt(source: []const u8, requested_cursor: usize) ?RequestedPath {
    if (source.len == 0 or requested_cursor > source.len) return null;
    var cursor = requested_cursor;
    if (cursor == source.len or !identifierCharacter(source[cursor])) {
        if (cursor == 0 or !identifierCharacter(source[cursor - 1])) return null;
        cursor -= 1;
    }
    var start = cursor;
    while (start != 0 and identifierCharacter(source[start - 1])) start -= 1;
    var end = cursor + 1;
    while (end < source.len and identifierCharacter(source[end])) end += 1;
    while (start >= 2 and source[start - 1] == '.') {
        var previous = start - 1;
        while (previous != 0 and identifierCharacter(source[previous - 1])) previous -= 1;
        if (previous == start - 1) break;
        start = previous;
    }
    return .{ .path = source[start..end], .end = end };
}

fn identifierCharacter(character: u8) bool {
    return std.ascii.isAlphanumeric(character) or character == '_';
}

fn declarationTarget(index: Modules.Index, path: []const u8) ?DeclarationTarget {
    var best: ?DeclarationTarget = null;
    var best_length: usize = 0;
    for (index.providers, 0..) |provider, provider_index| {
        if (std.mem.eql(u8, path, provider.name)) {
            return .{ .provider = provider_index, .declaration = lastSegment(provider.name) };
        }
        if (path.len <= provider.name.len or !std.mem.startsWith(u8, path, provider.name) or
            path[provider.name.len] != '.') continue;
        if (provider.name.len <= best_length) continue;
        best_length = provider.name.len;
        best = .{ .provider = provider_index, .declaration = path[provider.name.len + 1 ..] };
    }
    return best;
}

fn location(
    allocator: Allocator,
    path: []const u8,
    source: []const u8,
    position: Source.Position,
    name_length: usize,
    encoding: Types.PositionEncoding,
) !?Types.Location {
    const start = Protocol.positionAtByteOffset(source, position.offset, encoding) orelse return null;
    const end = Protocol.positionAtByteOffset(source, @min(source.len, position.offset + name_length), encoding) orelse return null;
    return .{
        .uri = try Protocol.uriFromPath(allocator, path),
        .range = .{ .start = start, .end = end },
    };
}

fn lastSegment(path: []const u8) []const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, path, '.') orelse return path;
    return path[separator + 1 ..];
}
