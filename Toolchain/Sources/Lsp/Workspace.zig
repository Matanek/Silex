const std = @import("std");
const Ast = @import("../Ast.zig");
const Modules = @import("../Modules.zig");
const Packages = @import("../Packages.zig");
const ParserModule = @import("../Parser.zig");
const Completion = @import("Completion.zig");
const LexerModule = @import("../Lexer.zig");
const Types = @import("Types.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

const Query = union(enum) {
    use_path: PathQuery,
    qualifier: QualifierQuery,
    imported_member: ImportedMemberQuery,
};

const PathQuery = struct {
    qualifier: []const u8,
    prefix: []const u8,
    type_only: bool = false,
};

const QualifierQuery = struct {
    path: []const u8,
    prefix: []const u8,
    cursor: usize,
    type_only: bool,
};

const ImportedMemberQuery = struct {
    type_path: []const u8,
    prefix: []const u8,
    cursor: usize,
    inside_extension: bool = false,
};

const IndexedProject = struct {
    graph: Packages.Graph,
    index: Modules.Index,
    current_owner: usize,
    current_path: []const u8,
};

const RankedItem = struct {
    item: Types.CompletionItem,
    priority: u8,
};

pub fn itemsAt(
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    root_uri: ?[]const u8,
    document_uri: []const u8,
    documents: []const Types.Document,
    source: []const u8,
    cursor: usize,
) !?[]const Types.CompletionItem {
    const document_path = try pathFromUri(allocator, document_uri);
    const root_hint = if (root_uri) |uri| try pathFromUri(allocator, uri) else null;
    const root = try projectRoot(allocator, io, document_path, root_hint);
    const project = try indexProject(allocator, io, global_packages_root, root, document_path);
    const query = try queryAt(allocator, source, cursor, project, io, documents);
    if (query == null) return null;

    var ranked: std.ArrayList(RankedItem) = .empty;
    switch (query.?) {
        .use_path => |path| try appendPathItems(allocator, io, documents, project, path, null, cursor, &ranked),
        .qualifier => |qualified| try appendPathItems(allocator, io, documents, project, .{
            .qualifier = qualified.path,
            .prefix = qualified.prefix,
            .type_only = qualified.type_only,
        }, source, qualified.cursor, &ranked),
        .imported_member => |member| try appendImportedMembers(
            allocator,
            io,
            documents,
            project,
            source,
            member,
            &ranked,
        ),
    }
    std.mem.sort(RankedItem, ranked.items, {}, rankedLessThan);
    const result = try allocator.alloc(Types.CompletionItem, ranked.items.len);
    for (ranked.items, 0..) |entry, index| {
        result[index] = entry.item;
        result[index].sortText = try std.fmt.allocPrint(allocator, "{d:0>3}-{d:0>6}", .{ entry.priority, index });
        result[index].filterText = entry.item.label;
        result[index].insertText = try Completion.insertTextFor(allocator, entry.item);
        result[index].insertTextFormat = Completion.insertTextFormatFor(entry.item);
    }
    return result;
}

pub fn scopeItemsAt(
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    root_uri: ?[]const u8,
    document_uri: []const u8,
    documents: []const Types.Document,
    source: []const u8,
    cursor: usize,
) ![]const Types.CompletionItem {
    if (cursor > source.len) return allocator.alloc(Types.CompletionItem, 0);
    const prefix_start = prefixStart(source, cursor);
    const prefix = source[prefix_start..cursor];
    const type_only = isTypePrefix(source, prefix_start);
    const program = try parseCurrentAtScope(allocator, source, cursor, prefix_start, type_only) orelse
        return allocator.alloc(Types.CompletionItem, 0);
    if (program.uses.len == 0) return allocator.alloc(Types.CompletionItem, 0);
    const document_path = try pathFromUri(allocator, document_uri);
    const root_hint = if (root_uri) |uri| try pathFromUri(allocator, uri) else null;
    const root = try projectRoot(allocator, io, document_path, root_hint);
    const project = try indexProject(allocator, io, global_packages_root, root, document_path);

    var ranked: std.ArrayList(RankedItem) = .empty;
    for (program.uses) |use| {
        const label = use.alias orelse lastSegment(use.path);
        if (!matchesPrefix(label, prefix)) continue;
        if (fundamentalAliasTarget(program, use, 0)) |type_target| {
            if (type_only) try appendRanked(allocator, &ranked, .{
                .label = label,
                .kind = 22,
                .detail = try std.fmt.allocPrint(allocator, "type {s} = {s}", .{ label, type_target.name() }),
            }, 18, false);
            continue;
        }
        if (declarationTarget(project.index, use.path)) |target| {
            const provider = project.index.providers[target.provider];
            if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) continue;
            const loaded = try loadProgram(allocator, io, documents, provider) orelse continue;
            var matched = false;
            for (loaded.program.structures) |structure| {
                if (!std.mem.eql(u8, structure.name, target.declaration)) continue;
                if (!structure.is_public) continue;
                if (type_only or structure.constructors.len == 0) {
                    try appendRanked(allocator, &ranked, .{
                        .label = label,
                        .kind = 22,
                        .detail = if (type_only)
                            try std.fmt.allocPrint(allocator, "struct {s}", .{structure.name})
                        else
                            try std.fmt.allocPrint(allocator, "{s}() {s}", .{ structure.name, structure.name }),
                    }, if (type_only) 18 else 30, false);
                } else for (structure.constructors) |constructor| {
                    if (!Completion.callAcceptsParameters(source, cursor, loaded.program, constructor.parameters)) continue;
                    try appendRanked(allocator, &ranked, .{
                        .label = label,
                        .kind = 22,
                        .detail = try Completion.constructorSignature(
                            allocator,
                            loaded.source,
                            loaded.program,
                            structure.name,
                            constructor,
                        ),
                    }, 30, true);
                }
                matched = true;
            }
            if (!type_only) for (loaded.program.functions) |function| {
                if (!std.mem.eql(u8, function.name, target.declaration)) continue;
                if (function.is_internal) continue;
                if (provider.owner != project.current_owner and !function.is_public) continue;
                if (!Completion.callAcceptsParameters(source, cursor, loaded.program, function.parameters)) continue;
                try appendRanked(allocator, &ranked, .{
                    .label = label,
                    .kind = 3,
                    .detail = try Completion.functionSignature(allocator, loaded.source, loaded.program, function),
                }, 35, true);
                matched = true;
            };
            if (!matched) for (loaded.program.uses) |exported| {
                if (!exported.is_public or exported.alias == null or
                    !std.mem.eql(u8, exported.alias.?, target.declaration)) continue;
                if (fundamentalAliasTarget(loaded.program, exported, 0)) |type_target| {
                    if (type_only) try appendRanked(allocator, &ranked, .{
                        .label = label,
                        .kind = 22,
                        .detail = try std.fmt.allocPrint(allocator, "type {s} = {s}", .{ label, type_target.name() }),
                    }, 18, false);
                    matched = type_only;
                    continue;
                }
                const before = ranked.items.len;
                try appendReexportTarget(
                    allocator,
                    io,
                    documents,
                    project,
                    exported.path,
                    label,
                    prefix,
                    if (type_only) null else source,
                    cursor,
                    &ranked,
                    0,
                    type_only,
                );
                matched = ranked.items.len != before;
            };
            if (matched) continue;
        }
        if (findProvider(project.index, use.path) != null or project.index.isNamespace(use.path)) {
            try appendRanked(allocator, &ranked, .{
                .label = label,
                .kind = 9,
                .detail = "Silex imported module namespace",
            }, 20, false);
        }
    }
    std.mem.sort(RankedItem, ranked.items, {}, rankedLessThan);
    const result = try allocator.alloc(Types.CompletionItem, ranked.items.len);
    for (ranked.items, 0..) |entry, index| {
        result[index] = entry.item;
        result[index].sortText = try std.fmt.allocPrint(allocator, "{d:0>3}-{d:0>6}", .{ entry.priority, index });
        result[index].filterText = entry.item.label;
        result[index].insertText = try Completion.insertTextFor(allocator, entry.item);
        result[index].insertTextFormat = Completion.insertTextFormatFor(entry.item);
    }
    return result;
}

fn isTypePrefix(source: []const u8, prefix_start: usize) bool {
    const before = std.mem.trimEnd(u8, source[0..prefix_start], " \t\r\n");
    if (before.len == 0) return false;
    if (before[before.len - 1] == ':') return true;
    const word_start = prefixStart(before, before.len);
    const owner = before[word_start..];
    return std.mem.eql(u8, owner, "as") or std.mem.eql(u8, owner, "extend");
}

fn queryAt(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
    project: IndexedProject,
    io: Io,
    documents: []const Types.Document,
) !?Query {
    if (cursor > source.len) return null;
    const prefix_start = prefixStart(source, cursor);
    const prefix = source[prefix_start..cursor];
    const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..prefix_start], '\n')) |newline| newline + 1 else 0;
    const line = std.mem.trimStart(u8, source[line_start..prefix_start], " \t");
    const after_use = if (std.mem.startsWith(u8, line, "use "))
        line["use ".len..]
    else
        null;
    if (after_use) |path_before_prefix| return .{ .use_path = .{
        .qualifier = trimPathQualifier(path_before_prefix),
        .prefix = prefix,
    } };

    if (prefix_start == 0 or source[prefix_start - 1] != '.') return null;
    const receiver = simpleReceiver(source, prefix_start - 1) orelse return null;
    const current_program = try parseCurrentAtCompletion(
        allocator,
        source,
        cursor,
        prefix,
        isQualifiedTypePrefix(source, prefix_start),
    );
    if (current_program) |program| {
        if (findUseByAlias(program, receiver)) |use| {
            return .{ .qualifier = .{
                .path = use.path,
                .prefix = prefix,
                .cursor = cursor,
                .type_only = isQualifiedTypePrefix(source, prefix_start),
            } };
        }
        if (try declaredTypePath(allocator, source, cursor, receiver)) |type_path| {
            if (try importedTypePath(allocator, program, project, type_path)) |resolved| {
                return .{ .imported_member = .{ .type_path = resolved, .prefix = prefix, .cursor = cursor } };
            }
        }
        if (std.mem.eql(u8, receiver, "self")) {
            if (extensionTargetAt(source, program, cursor)) |type_path| {
                if (try importedTypePath(allocator, program, project, type_path)) |resolved| {
                    return .{ .imported_member = .{
                        .type_path = resolved,
                        .prefix = prefix,
                        .cursor = cursor,
                        .inside_extension = true,
                    } };
                }
            }
        }
    }
    _ = io;
    _ = documents;
    return null;
}

fn indexProject(
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    root: []const u8,
    document_path: []const u8,
) !IndexedProject {
    var resolver = Packages.Resolver.init(allocator, io, global_packages_root);
    const graph = try resolver.resolve(root);
    var indexes: std.ArrayList(Modules.Index) = .empty;
    for (graph.packages, 0..) |package, owner| {
        for (package.module_roots) |module_root| {
            var discovered = try Modules.discoverOwned(allocator, io, module_root, package.name, owner);
            if (owner == 0) discovered = try excludePackageSources(allocator, discovered, graph.packages[1..]);
            try indexes.append(allocator, discovered);
        }
    }
    const index = try Modules.combine(allocator, indexes.items);
    var current_owner: usize = 0;
    for (index.providers) |provider| if (samePath(provider.path, document_path)) {
        current_owner = provider.owner;
        break;
    };
    return .{ .graph = graph, .index = index, .current_owner = current_owner, .current_path = document_path };
}

fn excludePackageSources(
    allocator: Allocator,
    index: Modules.Index,
    packages: []const Packages.Package,
) !Modules.Index {
    var providers: std.ArrayList(Modules.Provider) = .empty;
    for (index.providers) |provider| {
        var excluded = false;
        for (packages) |package| if (pathInside(provider.path, package.root)) {
            excluded = true;
            break;
        };
        if (!excluded) try providers.append(allocator, provider);
    }
    return .{ .providers = try providers.toOwnedSlice(allocator) };
}

fn appendPathItems(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    query: PathQuery,
    call_source: ?[]const u8,
    call_cursor: usize,
    ranked: *std.ArrayList(RankedItem),
) !void {
    const child_prefix = if (query.qualifier.len == 0)
        ""
    else
        try std.fmt.allocPrint(allocator, "{s}.", .{query.qualifier});

    for (project.index.providers) |provider| {
        if (samePath(provider.path, project.current_path)) continue;
        if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) continue;
        if (!std.mem.startsWith(u8, provider.name, child_prefix)) continue;
        const remainder = provider.name[child_prefix.len..];
        if (remainder.len == 0) continue;
        const end = std.mem.indexOfScalar(u8, remainder, '.') orelse remainder.len;
        const child = remainder[0..end];
        if (!matchesPrefix(child, query.prefix)) continue;
        try appendRanked(allocator, ranked, .{
            .label = child,
            .kind = 9,
            .detail = if (end == remainder.len) "Silex module" else "Silex module namespace",
        }, 0, false);
    }

    const provider = findProvider(project.index, query.qualifier) orelse return;
    if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) return;
    const loaded = try loadProgram(allocator, io, documents, provider) orelse return;
    for (loaded.program.structures) |structure| {
        if (!structure.is_public) continue;
        if (!matchesPrefix(structure.name, query.prefix)) continue;
        if (query.type_only or call_source == null) {
            try appendRanked(allocator, ranked, .{
                .label = structure.name,
                .kind = 22,
                .detail = try std.fmt.allocPrint(allocator, "{s} {s}", .{
                    if (structure.is_class) "class" else "struct",
                    structure.name,
                }),
            }, 10, false);
        } else if (structure.constructors.len == 0) {
            try appendRanked(allocator, ranked, .{
                .label = structure.name,
                .kind = 22,
                .detail = try std.fmt.allocPrint(allocator, "{s}() {s}", .{ structure.name, structure.name }),
            }, 10, false);
        } else for (structure.constructors) |constructor| {
            if (!Completion.callAcceptsParameters(
                call_source.?,
                call_cursor,
                loaded.program,
                constructor.parameters,
            )) continue;
            try appendRanked(allocator, ranked, .{
                .label = structure.name,
                .kind = 22,
                .detail = try Completion.constructorSignature(
                    allocator,
                    loaded.source,
                    loaded.program,
                    structure.name,
                    constructor,
                ),
            }, 10, true);
        }
    }
    for (loaded.program.enums) |enumeration| {
        if (!enumeration.is_public or !matchesPrefix(enumeration.name, query.prefix)) continue;
        try appendRanked(allocator, ranked, .{
            .label = enumeration.name,
            .kind = 13,
            .detail = try std.fmt.allocPrint(allocator, "enum {s}", .{enumeration.name}),
        }, 10, false);
    }
    if (!query.type_only) {
        for (loaded.program.functions) |function| {
            if (function.is_internal) continue;
            if (provider.owner != project.current_owner and !function.is_public) continue;
            if (call_source) |text| if (!Completion.callAcceptsParameters(
                text,
                call_cursor,
                loaded.program,
                function.parameters,
            )) continue;
            if (!matchesPrefix(function.name, query.prefix)) continue;
            try appendRanked(allocator, ranked, .{
                .label = function.name,
                .kind = 3,
                .detail = try Completion.functionSignature(allocator, loaded.source, loaded.program, function),
            }, 10, true);
        }
    }
    for (loaded.program.uses) |exported| {
        if (!exported.is_public or exported.alias == null or
            !matchesPrefix(exported.alias.?, query.prefix)) continue;
        if (fundamentalAliasTarget(loaded.program, exported, 0)) |type_target| {
            if (query.type_only or call_source == null) try appendRanked(allocator, ranked, .{
                .label = exported.alias.?,
                .kind = 22,
                .detail = try std.fmt.allocPrint(allocator, "type {s} = {s}", .{
                    exported.alias.?,
                    type_target.name(),
                }),
            }, 10, false);
            continue;
        }
        try appendReexportTarget(
            allocator,
            io,
            documents,
            project,
            exported.path,
            exported.alias.?,
            query.prefix,
            call_source,
            call_cursor,
            ranked,
            0,
            query.type_only,
        );
    }
}

fn appendReexportTarget(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    target_path: []const u8,
    label: []const u8,
    prefix: []const u8,
    call_source: ?[]const u8,
    call_cursor: usize,
    ranked: *std.ArrayList(RankedItem),
    depth: usize,
    type_only: bool,
) !void {
    if (depth > project.index.providers.len or !matchesPrefix(label, prefix)) return;
    const target = declarationTarget(project.index, target_path) orelse return;
    const provider = project.index.providers[target.provider];
    if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) return;
    const loaded = try loadProgram(allocator, io, documents, provider) orelse return;
    for (loaded.program.structures) |structure| {
        if (!structure.is_public or !std.mem.eql(u8, structure.name, target.declaration)) continue;
        if (type_only or call_source == null) {
            try appendRanked(allocator, ranked, .{
                .label = label,
                .kind = 22,
                .detail = try std.fmt.allocPrint(allocator, "struct {s}", .{structure.name}),
            }, 10, false);
        } else if (structure.constructors.len == 0) {
            try appendRanked(allocator, ranked, .{
                .label = label,
                .kind = 22,
                .detail = try std.fmt.allocPrint(allocator, "{s}() {s}", .{ label, label }),
            }, 10, false);
        } else for (structure.constructors) |constructor| {
            if (!Completion.callAcceptsParameters(call_source.?, call_cursor, loaded.program, constructor.parameters)) continue;
            try appendRanked(allocator, ranked, .{
                .label = label,
                .kind = 22,
                .detail = try Completion.constructorSignature(
                    allocator,
                    loaded.source,
                    loaded.program,
                    label,
                    constructor,
                ),
            }, 10, true);
        }
        return;
    }
    for (loaded.program.enums) |enumeration| {
        if (!enumeration.is_public or !std.mem.eql(u8, enumeration.name, target.declaration)) continue;
        try appendRanked(allocator, ranked, .{
            .label = label,
            .kind = 13,
            .detail = try std.fmt.allocPrint(allocator, "enum {s}", .{enumeration.name}),
        }, 10, false);
        return;
    }
    var found_function = false;
    if (!type_only) {
        for (loaded.program.functions) |function| {
            if (!function.is_public or !std.mem.eql(u8, function.name, target.declaration)) continue;
            if (call_source) |text| if (!Completion.callAcceptsParameters(
                text,
                call_cursor,
                loaded.program,
                function.parameters,
            )) continue;
            try appendRanked(allocator, ranked, .{
                .label = label,
                .kind = 3,
                .detail = try Completion.functionSignature(allocator, loaded.source, loaded.program, function),
            }, 10, true);
            found_function = true;
        }
    }
    if (found_function) return;
    for (loaded.program.uses) |exported| {
        if (!exported.is_public or exported.alias == null or
            !std.mem.eql(u8, exported.alias.?, target.declaration)) continue;
        if (fundamentalAliasTarget(loaded.program, exported, 0)) |type_target| {
            if (type_only or call_source == null) try appendRanked(allocator, ranked, .{
                .label = label,
                .kind = 22,
                .detail = try std.fmt.allocPrint(allocator, "type {s} = {s}", .{ label, type_target.name() }),
            }, 10, false);
            return;
        }
        return appendReexportTarget(
            allocator,
            io,
            documents,
            project,
            exported.path,
            label,
            prefix,
            call_source,
            call_cursor,
            ranked,
            depth + 1,
            type_only,
        );
    }
}

fn fundamentalAliasTarget(program: Ast.Program, use: Ast.Use, depth: usize) ?Ast.Type {
    if (use.type_target) |target| return if (target.structureIndex() == null) target else null;
    if (depth > program.uses.len or use.path.len == 0 or std.mem.indexOfScalar(u8, use.path, '.') != null) return null;
    for (program.uses) |candidate| {
        if (candidate.alias == null or !std.mem.eql(u8, candidate.alias.?, use.path)) continue;
        return fundamentalAliasTarget(program, candidate, depth + 1);
    }
    return null;
}

fn appendImportedMembers(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    current_source: []const u8,
    query: ImportedMemberQuery,
    ranked: *std.ArrayList(RankedItem),
) !void {
    const target = declarationTarget(project.index, query.type_path) orelse return;
    const provider = project.index.providers[target.provider];
    if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) return;
    const loaded = try loadProgram(allocator, io, documents, provider) orelse return;
    for (loaded.program.structures) |structure| {
        if (!std.mem.eql(u8, structure.name, target.declaration)) continue;
        if (!structure.is_public) return;
        for (structure.fields) |field| {
            if (field.is_internal or field.is_private or field.is_protected) continue;
            if (!std.mem.startsWith(u8, field.name, query.prefix)) continue;
            try appendRanked(allocator, ranked, .{
                .label = field.name,
                .kind = 5,
                .detail = try std.fmt.allocPrint(allocator, "{s}:{s}", .{
                    field.name,
                    Completion.typeName(loaded.program, field.type),
                }),
            }, 0, false);
        }
        for (structure.methods) |method| {
            if (method.is_static or method.is_internal or method.is_private or method.is_protected) continue;
            if (!std.mem.startsWith(u8, method.name, query.prefix)) continue;
            if (!Completion.callAcceptsParameters(
                current_source,
                query.cursor,
                loaded.program,
                method.parameters,
            )) continue;
            try appendRanked(allocator, ranked, .{
                .label = method.name,
                .kind = 2,
                .detail = try Completion.functionSignature(allocator, loaded.source, loaded.program, method),
            }, 0, true);
        }
        try appendCurrentExtensionMethods(
            allocator,
            project,
            current_source,
            query,
            structure,
            ranked,
        );
        return;
    }
}

fn appendCurrentExtensionMethods(
    allocator: Allocator,
    project: IndexedProject,
    source: []const u8,
    query: ImportedMemberQuery,
    target: Ast.Structure,
    ranked: *std.ArrayList(RankedItem),
) !void {
    const program = try parseCurrentAtCompletion(
        allocator,
        source,
        query.cursor,
        query.prefix,
        false,
    ) orelse return;
    for (program.extensions) |extension| {
        const local_target = Completion.typeName(program, extension.target);
        const resolved = try importedTypePath(allocator, program, project, local_target) orelse continue;
        if (!std.mem.eql(u8, resolved, query.type_path)) continue;
        for (extension.methods) |method| {
            if (method.is_static or !std.mem.startsWith(u8, method.name, query.prefix)) continue;
            const private_by_default = target.is_class and !method.visibility_explicit;
            if ((method.is_private or private_by_default) and !query.inside_extension) continue;
            if (!Completion.callAcceptsParameters(source, query.cursor, program, method.parameters)) continue;
            try appendRanked(allocator, ranked, .{
                .label = method.name,
                .kind = 2,
                .detail = try Completion.functionSignature(allocator, source, program, method),
            }, 0, true);
        }
    }
}

const LoadedProgram = struct { source: []const u8, program: Ast.Program };

fn loadProgram(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    provider: Modules.Provider,
) !?LoadedProgram {
    var source: ?[]const u8 = null;
    for (documents) |document| {
        const path = pathFromUri(allocator, document.uri) catch continue;
        if (samePath(path, provider.path)) {
            source = document.text;
            break;
        }
    }
    if (source) |overlay| {
        var parser = ParserModule.Parser.init(allocator, overlay);
        if (parser.parse()) |program| return .{ .source = overlay, .program = program } else |_| {}
    }
    const disk = Io.Dir.cwd().readFileAlloc(io, provider.path, allocator, .limited(1024 * 1024)) catch return null;
    var parser = ParserModule.Parser.init(allocator, disk);
    const program = parser.parse() catch return null;
    return .{ .source = disk, .program = program };
}

fn parseCurrent(allocator: Allocator, source: []const u8) !?Ast.Program {
    var parser = ParserModule.Parser.init(allocator, source);
    return parser.parse() catch null;
}

fn parseCurrentAtCompletion(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
    prefix: []const u8,
    type_position: bool,
) !?Ast.Program {
    if (try parseCurrent(allocator, source)) |program| return program;
    const placeholder = if (type_position)
        if (prefix.len == 0) "__Completion" else ""
    else if (prefix.len == 0)
        "__completion()"
    else
        "()";
    const recovered = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
        source[0..cursor],
        placeholder,
        source[cursor..],
    });
    return parseCurrent(allocator, recovered);
}

fn parseCurrentAtScope(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
    prefix_start: usize,
    type_only: bool,
) !?Ast.Program {
    if (try parseCurrent(allocator, source)) |program| return program;
    const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..prefix_start], '\n')) |newline|
        newline + 1
    else
        0;
    const before_prefix = std.mem.trim(u8, source[line_start..prefix_start], " \t\r");
    const placeholder = if (type_only)
        "int"
    else if (before_prefix.len == 0)
        "print(true)"
    else
        "true";
    const recovered = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
        source[0..prefix_start],
        placeholder,
        source[cursor..],
    });
    return parseCurrent(allocator, recovered);
}

fn findUseByAlias(program: Ast.Program, alias: []const u8) ?Ast.Use {
    for (program.uses) |use| {
        const local = use.alias orelse lastSegment(use.path);
        if (std.mem.eql(u8, local, alias)) return use;
    }
    return null;
}

fn declaredTypePath(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
    receiver: []const u8,
) !?[]const u8 {
    var tokens: std.ArrayList(LexerModule.Token) = .empty;
    var lexer = LexerModule.Lexer.init(source[0..cursor]);
    while (true) {
        const token = lexer.next() catch break;
        if (token.tag == .end) break;
        try tokens.append(allocator, token);
    }
    var found: ?[]const u8 = null;
    var index: usize = 0;
    while (index + 2 < tokens.items.len) : (index += 1) {
        if (tokens.items[index].tag != .keyword_let and tokens.items[index].tag != .keyword_var) continue;
        if (tokens.items[index + 1].tag != .identifier or
            !std.mem.eql(u8, tokens.items[index + 1].lexeme, receiver)) continue;
        const operator = tokens.items[index + 2].tag;
        if (operator != .colon and operator != .equal) continue;
        const start = index + 3;
        if (start >= tokens.items.len or tokens.items[start].tag != .identifier) continue;
        var end = start;
        while (end + 2 < tokens.items.len and tokens.items[end + 1].tag == .dot and
            tokens.items[end + 2].tag == .identifier)
        {
            end += 2;
        }
        if (operator == .equal and (end + 1 >= tokens.items.len or tokens.items[end + 1].tag != .left_parenthesis)) continue;
        found = try joinQualified(allocator, tokens.items[start .. end + 1]);
    }
    return found;
}

fn importedTypePath(
    allocator: Allocator,
    program: Ast.Program,
    project: IndexedProject,
    local_path: []const u8,
) !?[]const u8 {
    const separator = std.mem.indexOfScalar(u8, local_path, '.');
    const first = if (separator) |index| local_path[0..index] else local_path;
    const use = findUseByAlias(program, first) orelse return null;
    const suffix = if (separator) |index| local_path[index + 1 ..] else "";
    const full = if (suffix.len == 0)
        use.path
    else
        try std.fmt.allocPrint(allocator, "{s}.{s}", .{ use.path, suffix });
    return if (declarationTarget(project.index, full) != null) full else null;
}

fn extensionTargetAt(source: []const u8, program: Ast.Program, cursor: usize) ?[]const u8 {
    for (program.extensions) |extension| {
        for (extension.methods) |method| {
            if (!bodyContainsCursor(source, method.position.offset, cursor)) continue;
            return Completion.typeName(program, extension.target);
        }
    }
    return null;
}

fn bodyContainsCursor(source: []const u8, start: usize, cursor: usize) bool {
    if (cursor < start) return false;
    var lexer = LexerModule.Lexer.init(source);
    var started = false;
    var depth: usize = 0;
    while (true) {
        const token = lexer.next() catch return false;
        if (token.tag == .end) return started;
        if (token.start < start) continue;
        if (!started) {
            if (token.tag == .left_brace) {
                started = true;
                depth = 1;
            }
            continue;
        }
        if (token.start >= cursor) return depth != 0;
        switch (token.tag) {
            .left_brace => depth += 1,
            .right_brace => {
                depth -|= 1;
                if (depth == 0) return cursor <= token.end;
            },
            else => {},
        }
    }
}

const DeclarationTarget = struct { provider: usize, declaration: []const u8 };

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

fn appendRanked(
    allocator: Allocator,
    ranked: *std.ArrayList(RankedItem),
    item: Types.CompletionItem,
    priority: u8,
    overloaded: bool,
) !void {
    for (ranked.items, 0..) |existing, index| {
        if (!std.mem.eql(u8, existing.item.label, item.label)) continue;
        if (overloaded and existing.item.kind == item.kind and !std.mem.eql(u8, existing.item.detail, item.detail)) continue;
        if (priority < existing.priority) ranked.items[index] = .{ .item = item, .priority = priority };
        return;
    }
    try ranked.append(allocator, .{ .item = item, .priority = priority });
}

fn rankedLessThan(_: void, left: RankedItem, right: RankedItem) bool {
    if (left.priority != right.priority) return left.priority < right.priority;
    const labels = std.mem.order(u8, left.item.label, right.item.label);
    if (labels != .eq) return labels == .lt;
    return std.mem.lessThan(u8, left.item.detail, right.item.detail);
}

fn findProvider(index: Modules.Index, name: []const u8) ?Modules.Provider {
    for (index.providers) |provider| if (std.mem.eql(u8, provider.name, name)) return provider;
    return null;
}

fn joinQualified(allocator: Allocator, tokens: []const LexerModule.Token) ![]const u8 {
    var result: []const u8 = "";
    for (tokens) |token| {
        if (token.tag == .dot) continue;
        result = if (result.len == 0)
            token.lexeme
        else
            try std.fmt.allocPrint(allocator, "{s}.{s}", .{ result, token.lexeme });
    }
    return result;
}

fn trimPathQualifier(path: []const u8) []const u8 {
    return std.mem.trimEnd(u8, path, " \t.");
}

fn simpleReceiver(source: []const u8, dot: usize) ?[]const u8 {
    var start = dot;
    while (start != 0 and (std.ascii.isAlphanumeric(source[start - 1]) or source[start - 1] == '_')) start -= 1;
    return if (start == dot) null else source[start..dot];
}

fn prefixStart(source: []const u8, cursor: usize) usize {
    var start = cursor;
    while (start != 0 and (std.ascii.isAlphanumeric(source[start - 1]) or source[start - 1] == '_')) start -= 1;
    return start;
}

fn matchesPrefix(label: []const u8, prefix: []const u8) bool {
    return std.mem.indexOf(u8, label, prefix) != null;
}

fn isQualifiedTypePrefix(source: []const u8, prefix_start: usize) bool {
    var start = prefix_start;
    while (start != 0) {
        const character = source[start - 1];
        if (!std.ascii.isAlphanumeric(character) and character != '_' and character != '.') break;
        start -= 1;
    }
    return isTypePrefix(source, start);
}

fn lastSegment(path: []const u8) []const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, path, '.') orelse return path;
    return path[separator + 1 ..];
}

fn projectRoot(allocator: Allocator, io: Io, document_path: []const u8, root_hint: ?[]const u8) ![]const u8 {
    var directory = std.fs.path.dirname(document_path) orelse ".";
    const document_directory = directory;
    const boundary = root_hint orelse directory;
    while (true) {
        const manifest = try std.fs.path.join(allocator, &.{ directory, "Package.json" });
        if (fileExists(io, manifest)) return directory;
        if (samePath(directory, boundary)) return document_directory;
        const next = std.fs.path.dirname(directory) orelse return document_directory;
        if (!pathInside(directory, boundary) or std.mem.eql(u8, next, directory)) return document_directory;
        directory = next;
    }
}

pub fn pathFromUri(allocator: Allocator, uri: []const u8) ![]const u8 {
    const prefix = "file://";
    if (!std.mem.startsWith(u8, uri, prefix)) return allocator.dupe(u8, uri);
    const encoded = uri[prefix.len..];
    var decoded: std.ArrayList(u8) = .empty;
    var index: usize = 0;
    while (index < encoded.len) {
        if (encoded[index] == '%' and index + 2 < encoded.len) {
            const high = hex(encoded[index + 1]);
            const low = hex(encoded[index + 2]);
            if (high != null and low != null) {
                try decoded.append(allocator, high.? * 16 + low.?);
                index += 3;
                continue;
            }
        }
        try decoded.append(allocator, encoded[index]);
        index += 1;
    }
    return decoded.toOwnedSlice(allocator);
}

fn hex(character: u8) ?u8 {
    return switch (character) {
        '0'...'9' => character - '0',
        'a'...'f' => character - 'a' + 10,
        'A'...'F' => character - 'A' + 10,
        else => null,
    };
}

fn pathInside(path: []const u8, directory: []const u8) bool {
    if (!std.mem.startsWith(u8, path, directory) or path.len <= directory.len) return false;
    return path[directory.len] == std.fs.path.sep;
}

fn samePath(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, std.mem.trimEnd(u8, left, "/"), std.mem.trimEnd(u8, right, "/"));
}

fn fileExists(io: Io, path: []const u8) bool {
    _ = Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return true;
}

test "complete simple modules before declarations in a use path" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Module2/SubModule");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Module1\nfunc main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Module1.sx",
        .data = "struct Hidden {} public struct Visible {} func inside() int { return 1 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Module1.SubModule.Foo.sx",
        .data = "func flat() int { return 2 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Module2/SubModule/Foo.sx",
        .data = "func nested() int { return 3 }",
    });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const source = "use Module1.";
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const items = (try itemsAt(allocator, std.testing.io, null, root_uri, uri, &.{}, source, source.len)).?;
    try std.testing.expectEqualStrings("SubModule", items[0].label);
    var found_inside = false;
    for (items) |item| {
        if (std.mem.eql(u8, item.label, "inside")) found_inside = true;
    }
    try std.testing.expect(found_inside);
    try std.testing.expect(hasLabel(items, "Visible"));
    try std.testing.expect(!hasLabel(items, "Hidden"));

    const namespace_source = "use Module2.";
    const namespace_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        namespace_source,
        namespace_source.len,
    )).?;
    try std.testing.expectEqual(@as(usize, 1), namespace_items.len);
    try std.testing.expectEqualStrings("SubModule", namespace_items[0].label);
}

test "complete loose local modules from the document directory with a wider workspace root" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Sandbox/Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Sandbox/Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Sandbox/Math/Vec3.sx",
        .data = "public struct Vec3 {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Unrelated.sx",
        .data = "public func ignore() {}",
    });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const sandbox = try std.fs.path.join(allocator, &.{ root, "Sandbox" });
    const main_path = try std.fs.path.join(allocator, &.{ sandbox, "Main.sx" });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    const empty_source = "use ";
    const empty_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        empty_source,
        empty_source.len,
    )).?;
    try std.testing.expect(hasLabel(empty_items, "Math"));
    try std.testing.expect(!hasLabel(empty_items, "Main"));
    try std.testing.expect(!hasLabel(empty_items, "Unrelated"));

    const prefixed_source = "use M";
    const prefixed_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        prefixed_source,
        prefixed_source.len,
    )).?;
    try std.testing.expectEqual(@as(usize, 1), prefixed_items.len);
    try std.testing.expectEqualStrings("Math", prefixed_items[0].label);

    const qualified_source =
        \\use Math
        \\func main() {
        \\    var value = Math.
        \\}
    ;
    const qualified_cursor = std.mem.indexOf(u8, qualified_source, "Math.").? + "Math.".len;
    const qualified_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        qualified_source,
        qualified_cursor,
    )).?;
    try std.testing.expect(hasLabel(qualified_items, "Vec3"));
}

test "complete public package APIs module aliases members and overlays" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Math/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations
        \\func main() {
        \\    let pos = Operations.Vector(1)
        \\    print(pos.to_str())
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Package.json",
        .data = "{\"name\":\"Math\",\"version\":\"1.0.0\"}",
    });
    const operations_source =
        \\public struct Vector {
        \\    internal var hidden_value:int
        \\    var value:int
        \\    init(value:int) { self.value = value }
        \\    internal func hidden_method() int { return self.hidden_value }
        \\    func to_str() str { return "vector" }
        \\}
        \\public func add(left:int, right:int = 1) int { return left + right }
        \\public func add(value:str) str { return value }
        \\func hidden() int { return 0 }
        \\internal func file_only() int { return 0 }
    ;
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Module/Operations.sx",
        .data = operations_source,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Module/Facade.sx",
        .data =
        \\public use Math.Operations.Vector as Vector
        \\public use Math.Operations.add as add
        \\use int as BaseInteger
        \\public use BaseInteger as Integer
        ,
    });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const operations_path = try std.fs.path.join(allocator, &.{ root, "Math", "Module", "Operations.sx" });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    const import_source = "use Math.Operations.";
    const import_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        import_source,
        import_source.len,
    )).?;
    try std.testing.expect(hasLabel(import_items, "Vector"));
    try std.testing.expect(hasLabel(import_items, "add"));
    try std.testing.expect(!hasLabel(import_items, "hidden"));
    try std.testing.expect(!hasLabel(import_items, "file_only"));

    const facade_source = "use Math.Facade.";
    const facade_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        facade_source,
        facade_source.len,
    )).?;
    try std.testing.expect(hasLabel(facade_items, "Vector"));
    try std.testing.expect(hasLabel(facade_items, "add"));
    try std.testing.expect(hasLabel(facade_items, "Integer"));
    try std.testing.expect(!hasLabel(facade_items, "hidden"));

    const qualifier_source =
        \\use Math.Operations
        \\func main() { print(Operations.add(1, 2)) }
    ;
    const qualifier_cursor = std.mem.indexOf(u8, qualifier_source, "Operations.add").? + "Operations.a".len;
    const qualifier_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        qualifier_source,
        qualifier_cursor,
    )).?;
    try std.testing.expect(hasLabel(qualifier_items, "add"));
    try std.testing.expect(!hasLabel(qualifier_items, "hidden"));
    try std.testing.expectEqual(@as(usize, 1), labelCount(qualifier_items, "add"));
    try std.testing.expect(std.mem.indexOf(
        u8,
        qualifier_items[labelIndex(qualifier_items, "add").?].detail,
        "right:int = 1",
    ) != null);

    const constructor_source =
        \\use Math.Operations
        \\func main() { print(Operations.Vector(1).value) }
    ;
    const constructor_name_cursor = std.mem.indexOf(u8, constructor_source, "Operations.Vector").? +
        "Operations.Vec".len;
    const constructor_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        constructor_source,
        constructor_name_cursor,
    )).?;
    try std.testing.expectEqual(@as(usize, 1), labelCount(constructor_items, "Vector"));
    try std.testing.expectEqualStrings("Vector(value:int) Vector", constructor_items[0].detail);

    const member_source =
        \\use Math.Operations
        \\func main() {
        \\    let pos = Operations.Vector(1)
        \\    print(pos.to_str())
        \\}
    ;
    const member_cursor = std.mem.indexOf(u8, member_source, "pos.to_str").? + "pos.t".len;
    const member_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        member_source,
        member_cursor,
    )).?;
    try std.testing.expect(hasLabel(member_items, "to_str"));
    try std.testing.expect(!hasLabel(member_items, "add"));
    try std.testing.expect(!hasLabel(member_items, "hidden_value"));
    try std.testing.expect(!hasLabel(member_items, "hidden_method"));

    const overlay_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{operations_path});
    const overlays = [_]Types.Document{.{
        .uri = overlay_uri,
        .text = "public func average() int { return 42 }",
        .version = 2,
    }};
    const overlay_source = "use Math.Operations.a";
    const overlay_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &overlays,
        overlay_source,
        overlay_source.len,
    )).?;
    try std.testing.expect(hasLabel(overlay_items, "average"));
    try std.testing.expect(!hasLabel(overlay_items, "add"));

    const disk_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        overlay_source,
        overlay_source.len,
    )).?;
    try std.testing.expect(hasLabel(disk_items, "add"));
    try std.testing.expect(!hasLabel(disk_items, "average"));

    const imported_type_source =
        \\use Math.Operations.Vector as ImportedVector
        \\func consume(value:ImportedVector) {}
    ;
    const imported_type_cursor = std.mem.indexOf(u8, imported_type_source, "ImportedVector) ").? + 1;
    const imported_types = try scopeItemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        imported_type_source,
        imported_type_cursor,
    );
    try std.testing.expect(hasLabel(imported_types, "ImportedVector"));

    const incomplete_imported_type_source =
        \\use Math.Operations.Vector as ImportedVector
        \\func consume(value:) {}
    ;
    const incomplete_imported_type_cursor = std.mem.indexOf(u8, incomplete_imported_type_source, "value:").? +
        "value:".len;
    const incomplete_imported_types = try scopeItemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        incomplete_imported_type_source,
        incomplete_imported_type_cursor,
    );
    try std.testing.expect(hasLabel(incomplete_imported_types, "ImportedVector"));

    const qualified_imported_type_source =
        \\use Math.Operations
        \\func consume(value:Operations.) {}
    ;
    const qualified_imported_type_cursor = std.mem.indexOf(u8, qualified_imported_type_source, "Operations.").? +
        "Operations.".len;
    const qualified_imported_types = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        qualified_imported_type_source,
        qualified_imported_type_cursor,
    )).?;
    try std.testing.expect(hasLabel(qualified_imported_types, "Vector"));
    try std.testing.expect(!hasLabel(qualified_imported_types, "add"));

    const imported_function_source =
        \\use Math.Operations.add as imported_add
        \\func main() { print(imported_add(1)) }
    ;
    const imported_function_cursor = std.mem.indexOf(u8, imported_function_source, "imported_add(1)").? + 4;
    const imported_functions = try scopeItemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        imported_function_source,
        imported_function_cursor,
    );
    try std.testing.expect(hasLabel(imported_functions, "imported_add"));

    const imported_alias_source =
        \\use Math.Facade.Integer as Number
        \\func consume(value:Number) {}
    ;
    const imported_alias_cursor = std.mem.indexOf(u8, imported_alias_source, "Number) ").? + 1;
    const imported_aliases = try scopeItemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        imported_alias_source,
        imported_alias_cursor,
    );
    try std.testing.expect(hasLabel(imported_aliases, "Number"));
}

fn hasLabel(items: []const Types.CompletionItem, label: []const u8) bool {
    for (items) |item| if (std.mem.eql(u8, item.label, label)) return true;
    return false;
}

test "workspace indexes the selected package target root" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Bridge/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Platform/macos-arm64/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Platform/linux-x64-gnu/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data = "{\"name\":\"Bridge\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Module/Public.sx", .data = "" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/macos-arm64/Module/Implementation.sx",
        .data = "",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/linux-x64-gnu/Module/LinuxOnly.sx",
        .data = "this source is deliberately invalid",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{path});
    const source = "use Bridge.";
    const items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        source,
        source.len,
    )).?;
    try std.testing.expect(hasLabel(items, "Public"));
    try std.testing.expect(hasLabel(items, "Implementation"));
    try std.testing.expect(!hasLabel(items, "LinuxOnly"));
}

fn labelCount(items: []const Types.CompletionItem, label: []const u8) usize {
    var count: usize = 0;
    for (items) |item| if (std.mem.eql(u8, item.label, label)) {
        count += 1;
    };
    return count;
}

fn labelIndex(items: []const Types.CompletionItem, label: []const u8) ?usize {
    for (items, 0..) |item, index| if (std.mem.eql(u8, item.label, label)) return index;
    return null;
}
