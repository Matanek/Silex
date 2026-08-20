const std = @import("std");
const builtin = @import("builtin");
const Ast = @import("../Ast.zig");
const Modules = @import("../Modules.zig");
const ModuleScopes = @import("../ModuleScopes.zig");
const PackageTestFixtures = @import("../Packages/TestFixtures.zig");
const TargetModule = @import("../Target.zig");
const ParserModule = @import("../Parser.zig");
const Completion = @import("Completion.zig");
const LexerModule = @import("../Lexer.zig");
const ProjectIndex = @import("ProjectIndex.zig");
const Types = @import("Types.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

const CompletionKind = struct {
    const method: u8 = 2;
    const function: u8 = 3;
    const field: u8 = 5;
    const class: u8 = 7;
    const interface: u8 = 8;
    const module: u8 = 9;
    const enum_type: u8 = 13;
    const enum_member: u8 = 20;
    const structure: u8 = 22;
};

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
    static_receiver: bool = false,
    inside_extension: bool = false,
};

const IndexedProject = ProjectIndex.IndexedProject;

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
    return itemsAtForTarget(
        allocator,
        io,
        global_packages_root,
        TargetModule.Target.host() orelse .macos_arm64,
        root_uri,
        document_uri,
        documents,
        source,
        cursor,
    );
}

pub fn itemsAtForTarget(
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    selected_target: TargetModule.Target,
    root_uri: ?[]const u8,
    document_uri: []const u8,
    documents: []const Types.Document,
    source: []const u8,
    cursor: usize,
) !?[]const Types.CompletionItem {
    const document_path = try pathFromUri(allocator, document_uri);
    const root_hint = if (root_uri) |uri| try pathFromUri(allocator, uri) else null;
    const root = try projectRoot(allocator, io, document_path, root_hint);
    const project = try indexProject(allocator, io, global_packages_root, selected_target, root, document_path);
    const query = try queryAt(allocator, source, cursor, project, io, documents);
    if (query == null) return null;
    const completing_use_path = std.meta.activeTag(query.?) == .use_path;

    var ranked: std.ArrayList(RankedItem) = .empty;
    switch (query.?) {
        .use_path => |path| try appendPathItems(allocator, io, documents, project, path, null, cursor, &ranked),
        .qualifier => |qualified| {
            try appendPathItems(allocator, io, documents, project, .{
                .qualifier = qualified.path,
                .prefix = qualified.prefix,
                .type_only = qualified.type_only,
            }, source, qualified.cursor, &ranked);
            if (!qualified.type_only) try appendImportedMembers(
                allocator,
                io,
                documents,
                project,
                source,
                .{
                    .type_path = qualified.path,
                    .prefix = qualified.prefix,
                    .cursor = qualified.cursor,
                    .static_receiver = true,
                },
                &ranked,
            );
        },
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
        if (completing_use_path) {
            result[index].insertText = entry.item.label;
            result[index].insertTextFormat = null;
        } else {
            result[index].insertText = try Completion.insertTextForAt(allocator, entry.item, source, cursor);
            result[index].insertTextFormat = Completion.insertTextFormatForAt(entry.item, source, cursor);
        }
    }
    const expanded = try Completion.expandOptionalCallVariants(allocator, result, source, cursor);
    const unique = Completion.deduplicateCallableShapes(expanded);
    Completion.disambiguateCallableLabels(unique);
    return unique;
}

pub fn parameterItemsAtForTarget(
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    selected_target: TargetModule.Target,
    root_uri: ?[]const u8,
    document_uri: []const u8,
    documents: []const Types.Document,
    source: []const u8,
    cursor: usize,
) ![]const Types.CompletionItem {
    const call = try Completion.activeCallAt(allocator, source, cursor) orelse
        return allocator.alloc(Types.CompletionItem, 0);
    const lookup_source = try Completion.sourceForParameterLookup(allocator, source, cursor, call);
    const callables = (try itemsAtForTarget(
        allocator,
        io,
        global_packages_root,
        selected_target,
        root_uri,
        document_uri,
        documents,
        lookup_source,
        call.callee_end,
    )) orelse return allocator.alloc(Types.CompletionItem, 0);
    return Completion.parameterItemsFromCallables(allocator, callables, call);
}

pub fn hasProjectReferenceForTarget(
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    selected_target: TargetModule.Target,
    root_uri: ?[]const u8,
    document_uri: []const u8,
    source: []const u8,
) !bool {
    if (root_uri == null) return false;
    const program = try parseCurrent(allocator, source) orelse return false;
    const document_path = try pathFromUri(allocator, document_uri);
    const root_hint = if (root_uri) |uri| try pathFromUri(allocator, uri) else null;
    const root = try projectRoot(allocator, io, document_path, root_hint);
    const project = try indexProject(allocator, io, global_packages_root, selected_target, root, document_path);
    var lexer = LexerModule.Lexer.init(source);
    while (true) {
        const token = lexer.next() catch return false;
        if (token.tag == .end) return false;
        if (token.tag != .identifier) continue;
        const separator = lexer.next() catch return false;
        if (separator.tag != .dot) {
            const incomplete_expression = switch (separator.tag) {
                .end, .right_brace, .right_parenthesis, .comma, .semicolon => true,
                else => false,
            };
            if (incomplete_expression and try accessibleRootMatches(allocator, io, project, token.lexeme)) return true;
            continue;
        }
        if (hasLocalNominal(program, token.lexeme)) continue;
        if (contextualProvider(project, token.lexeme) != null) return true;
        if ((findProvider(project.index, token.lexeme) != null or project.index.isNamespace(token.lexeme)) and
            try modulePathVisible(allocator, io, &.{}, project, token.lexeme)) return true;
    }
}

pub fn importedReceiverTypeAt(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    source: []const u8,
    cursor: usize,
) !?[]const u8 {
    const query = try queryAt(allocator, source, cursor, project, io, documents) orelse return null;
    return switch (query) {
        .imported_member => |member| member.type_path,
        else => null,
    };
}

fn accessibleRootMatches(allocator: Allocator, io: Io, project: IndexedProject, prefix: []const u8) !bool {
    if (prefix.len == 0) return false;
    for (project.index.providers) |provider| {
        if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) continue;
        const separator = std.mem.indexOfScalar(u8, provider.name, '.') orelse provider.name.len;
        const root = provider.name[0..separator];
        if (!std.mem.startsWith(u8, root, prefix)) continue;
        if (try modulePathVisible(allocator, io, &.{}, project, root)) return true;
    }
    return false;
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
    return scopeItemsAtForTarget(
        allocator,
        io,
        global_packages_root,
        TargetModule.Target.host() orelse .macos_arm64,
        root_uri,
        document_uri,
        documents,
        source,
        cursor,
    );
}

pub fn assignmentExpectedTypeAtForTarget(
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    selected_target: TargetModule.Target,
    root_uri: ?[]const u8,
    document_uri: []const u8,
    documents: []const Types.Document,
    source: []const u8,
    cursor: usize,
) !?[]const u8 {
    if (cursor > source.len) return null;
    const prefix_start = prefixStart(source, cursor);
    const assignment = assignmentFieldAt(source, prefix_start) orelse return null;
    const program = try parseCurrentAtScope(allocator, source, cursor, prefix_start, false, false) orelse return null;
    const document_path = try pathFromUri(allocator, document_uri);
    const root_hint = if (root_uri) |uri| try pathFromUri(allocator, uri) else null;
    const root = try projectRoot(allocator, io, document_path, root_hint);
    const project = try indexProject(allocator, io, global_packages_root, selected_target, root, document_path);

    const receiver_type = if (Completion.qualifiedCall(assignment.receiver)) |call|
        try importedQualifiedCallReturnTypePath(allocator, io, documents, project, program, call)
    else if (Completion.directCall(assignment.receiver)) |call|
        try importedConstructorCallTypePath(allocator, io, documents, project, program, call)
    else
        try importedFieldReceiverTypePath(
            allocator,
            io,
            documents,
            project,
            program,
            source,
            cursor,
            assignment.receiver,
        );
    const imported_receiver = receiver_type orelse return null;
    const imported_expected = try importedFieldTypePath(
        allocator,
        io,
        documents,
        project,
        imported_receiver,
        assignment.field,
    ) orelse return null;
    return try localTypePath(allocator, program, imported_expected);
}

const AssignmentField = struct {
    receiver: []const u8,
    field: []const u8,
};

fn assignmentFieldAt(source: []const u8, prefix_start: usize) ?AssignmentField {
    var tokens: [128]LexerModule.Token = undefined;
    var count: usize = 0;
    var lexer = LexerModule.Lexer.init(source[0..prefix_start]);
    while (true) {
        const token = lexer.next() catch return null;
        if (token.tag == .end) break;
        if (count == tokens.len) return null;
        tokens[count] = token;
        count += 1;
    }
    if (count < 3 or tokens[count - 1].tag != .equal or tokens[count - 2].tag != .identifier) return null;
    const separator = tokens[count - 3];
    if (separator.tag != .dot and separator.tag != .dot_dot) return null;
    const receiver = if (separator.tag == .dot_dot)
        Completion.cascadeReceiver(source, separator.start)
    else
        Completion.memberReceiver(source, separator.start);
    return .{
        .receiver = receiver orelse return null,
        .field = tokens[count - 2].lexeme,
    };
}

test "recognize a cascade field assignment before its value" {
    const source =
        \\func main() {
        \\    Components.Overlay2D(10)
        \\        ..position =
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "\n}").?;
    const assignment = assignmentFieldAt(source, cursor) orelse return error.MissingAssignmentField;
    try std.testing.expectEqualStrings("Components.Overlay2D(10)", assignment.receiver);
    try std.testing.expectEqualStrings("position", assignment.field);
}

fn localTypePath(allocator: Allocator, program: Ast.Program, imported_path: []const u8) ![]const u8 {
    for (program.uses) |use| {
        if (!std.mem.startsWith(u8, imported_path, use.path)) continue;
        if (imported_path.len != use.path.len and imported_path[use.path.len] != '.') continue;
        const local = use.alias orelse lastSegment(use.path);
        if (imported_path.len == use.path.len) return local;
        return std.fmt.allocPrint(allocator, "{s}{s}", .{ local, imported_path[use.path.len..] });
    }
    return imported_path;
}

pub fn scopeItemsAtForTarget(
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    selected_target: TargetModule.Target,
    root_uri: ?[]const u8,
    document_uri: []const u8,
    documents: []const Types.Document,
    source: []const u8,
    cursor: usize,
) ![]const Types.CompletionItem {
    return scopeItemsAtForTargetExpected(
        allocator,
        io,
        global_packages_root,
        selected_target,
        root_uri,
        document_uri,
        documents,
        source,
        cursor,
        null,
    );
}

pub fn scopeItemsAtForTargetExpected(
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    selected_target: TargetModule.Target,
    root_uri: ?[]const u8,
    document_uri: []const u8,
    documents: []const Types.Document,
    source: []const u8,
    cursor: usize,
    expected_type: ?[]const u8,
) ![]const Types.CompletionItem {
    if (cursor > source.len) return allocator.alloc(Types.CompletionItem, 0);
    const prefix_start = prefixStart(source, cursor);
    const prefix = source[prefix_start..cursor];
    const type_only = try Completion.isTypePositionAt(allocator, source, prefix_start);
    const return_expression = try Completion.isReturnExpressionAt(allocator, source, cursor);
    const aggregate = try Completion.aggregateContextAt(allocator, source, cursor);
    const program = try parseCurrentAtScope(allocator, source, cursor, prefix_start, type_only, aggregate != null) orelse
        return allocator.alloc(Types.CompletionItem, 0);
    const wants_platform = !type_only and matchesPrefix("Platform", prefix) and
        !hasLocalNominal(program, "Platform") and findUseByAlias(program, "Platform") == null;
    const wants_target = !type_only and matchesPrefix("Target", prefix) and
        !hasLocalNominal(program, "Target") and findUseByAlias(program, "Target") == null;
    const wants_direct_path = prefix.len != 0;
    if (program.uses.len == 0 and !wants_platform and !wants_target and !type_only and !return_expression and
        !wants_direct_path)
    {
        return allocator.alloc(Types.CompletionItem, 0);
    }
    const document_path = try pathFromUri(allocator, document_uri);
    const root_hint = if (root_uri) |uri| try pathFromUri(allocator, uri) else null;
    const root = try projectRoot(allocator, io, document_path, root_hint);
    const project = try indexProject(allocator, io, global_packages_root, selected_target, root, document_path);

    var ranked: std.ArrayList(RankedItem) = .empty;
    if (aggregate) |context| {
        var native_initializer = false;
        for (program.structures) |structure| if (std.mem.eql(u8, structure.name, context.type_name) and
            structure.constructors.len == 0)
        {
            native_initializer = true;
            break;
        };
        if (findUseByAlias(program, context.type_name)) |use| {
            if (declarationTarget(project.index, use.path)) |target| {
                const provider = project.index.providers[target.provider];
                if (project.graph.canAccess(project.current_owner, provider.owner, provider.name)) {
                    if (try loadProgram(allocator, io, documents, provider)) |loaded| {
                        for (loaded.program.structures) |structure| {
                            if (!structure.is_public or !std.mem.eql(u8, structure.name, target.declaration) or
                                structure.constructors.len != 0) continue;
                            native_initializer = true;
                            for (structure.fields) |field| {
                                if (!importedMemberVisible(project, provider, field) or
                                    Completion.suppliedAggregateField(context, field.name) or
                                    !matchesPrefix(field.name, prefix)) continue;
                                try appendRanked(allocator, &ranked, .{
                                    .label = field.name,
                                    .kind = CompletionKind.field,
                                    .detail = try std.fmt.allocPrint(allocator, "{s}:{s}", .{
                                        field.name,
                                        Completion.typeName(loaded.program, field.type),
                                    }),
                                }, 0, false);
                            }
                            break;
                        }
                    }
                }
            }
        }
        if (native_initializer) {
            std.mem.sort(RankedItem, ranked.items, {}, rankedLessThan);
            const result = try allocator.alloc(Types.CompletionItem, ranked.items.len);
            for (ranked.items, 0..) |entry, index| {
                result[index] = entry.item;
                result[index].sortText = try std.fmt.allocPrint(allocator, "{d:0>3}-{d:0>6}", .{ entry.priority, index });
                result[index].filterText = entry.item.label;
                result[index].insertText = entry.item.label;
            }
            Completion.disambiguateCallableLabels(result);
            return result;
        }
    }
    if (wants_platform and contextualProvider(project, "Platform") != null) {
        try appendRanked(allocator, &ranked, .{
            .label = "Platform",
            .kind = CompletionKind.module,
            .detail = "Silex contextual platform fragment",
        }, 16, false);
    }
    if (wants_target and contextualProvider(project, "Target") != null) {
        try appendRanked(allocator, &ranked, .{
            .label = "Target",
            .kind = CompletionKind.module,
            .detail = "Silex contextual target fragment",
        }, 16, false);
    }
    if (type_only) try appendPathItems(
        allocator,
        io,
        documents,
        project,
        .{ .qualifier = "", .prefix = prefix, .type_only = true },
        source,
        cursor,
        &ranked,
    );
    if (return_expression) try appendPathItems(
        allocator,
        io,
        documents,
        project,
        .{ .qualifier = "", .prefix = prefix },
        null,
        cursor,
        &ranked,
    );
    if (wants_direct_path and !type_only and !return_expression) try appendPathItems(
        allocator,
        io,
        documents,
        project,
        .{ .qualifier = "", .prefix = prefix },
        source,
        cursor,
        &ranked,
    );
    for (program.uses) |use| {
        const label = use.alias orelse lastSegment(use.path);
        if (!matchesPrefix(label, prefix)) continue;
        if (expected_type) |expected| {
            if (!std.mem.eql(u8, expected, label) and
                !(expected.len > label.len and std.mem.startsWith(u8, expected, label) and expected[label.len] == '.')) continue;
        }
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
                if (structure.is_local or (!structure.is_public and !providerInCurrentModule(project, provider))) continue;
                if (type_only or structure.is_protocol or structure.is_static) {
                    try appendRanked(allocator, &ranked, .{
                        .label = label,
                        .kind = nominalCompletionKind(structure),
                        .detail = try nominalCompletionDetail(allocator, structure),
                    }, 18, false);
                } else if (structure.constructors.len == 0) {
                    try appendRanked(allocator, &ranked, .{
                        .label = label,
                        .kind = nominalCompletionKind(structure),
                        .detail = try std.fmt.allocPrint(allocator, "{s}() {s}", .{ structure.name, structure.name }),
                    }, 30, false);
                } else for (structure.constructors) |constructor| {
                    if (!Completion.callAcceptsParameters(source, cursor, loaded.program, constructor.parameters)) continue;
                    try appendRanked(allocator, &ranked, .{
                        .label = label,
                        .kind = nominalCompletionKind(structure),
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
                if (function.is_local) continue;
                if (function.is_internal) {
                    if (!project.graph.canAccessPackage(project.current_owner, provider.owner)) continue;
                } else if (!function.is_public and !providerInCurrentModule(project, provider)) continue;
                if (!Completion.callAcceptsParameters(source, cursor, loaded.program, function.parameters)) continue;
                try appendRanked(allocator, &ranked, .{
                    .label = label,
                    .kind = CompletionKind.function,
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
            if (!try modulePathVisible(allocator, io, documents, project, use.path)) continue;
            try appendRanked(allocator, &ranked, .{
                .label = label,
                .kind = CompletionKind.module,
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
        result[index].insertText = try Completion.insertTextForAt(allocator, entry.item, source, cursor);
        result[index].insertTextFormat = Completion.insertTextFormatForAt(entry.item, source, cursor);
    }
    const expanded = try Completion.expandOptionalCallVariants(allocator, result, source, cursor);
    const unique = Completion.deduplicateCallableShapes(expanded);
    Completion.disambiguateCallableLabels(unique);
    return unique;
}

fn hasLocalNominal(program: Ast.Program, name: []const u8) bool {
    for (program.structures) |structure| if (std.mem.eql(u8, structure.name, name)) return true;
    for (program.enums) |enumeration| if (std.mem.eql(u8, enumeration.name, name)) return true;
    return false;
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
    const cascade = prefix_start >= 2 and source[prefix_start - 2] == '.';
    const receiver = (if (cascade)
        Completion.cascadeReceiver(source, prefix_start - 2)
    else
        Completion.memberReceiver(source, prefix_start - 1)) orelse return null;
    const qualified_type = try Completion.isQualifiedTypePositionAt(allocator, source, prefix_start);
    const current_program = try parseCurrentAtCompletion(
        allocator,
        source,
        cursor,
        prefix,
        qualified_type,
    );
    if (current_program) |program| {
        if (findUseByAlias(program, receiver)) |use| {
            if (findProvider(project.index, use.path) == null and
                !project.index.isNamespace(use.path) and
                declarationTarget(project.index, use.path) != null)
            {
                return .{ .imported_member = .{
                    .type_path = use.path,
                    .prefix = prefix,
                    .cursor = cursor,
                    .static_receiver = true,
                } };
            }
            return .{ .qualifier = .{
                .path = use.path,
                .prefix = prefix,
                .cursor = cursor,
                .type_only = qualified_type,
            } };
        }
        if ((std.mem.eql(u8, receiver, "Platform") or std.mem.eql(u8, receiver, "Target")) and
            !hasLocalNominal(program, receiver))
        {
            return .{ .qualifier = .{
                .path = receiver,
                .prefix = prefix,
                .cursor = cursor,
                .type_only = qualified_type,
            } };
        }
        if ((findProvider(project.index, receiver) != null or project.index.isNamespace(receiver)) and
            try modulePathVisible(allocator, io, documents, project, receiver))
        {
            return .{ .qualifier = .{
                .path = receiver,
                .prefix = prefix,
                .cursor = cursor,
                .type_only = qualified_type,
            } };
        }
        if (Completion.qualifiedCall(receiver)) |call| {
            if (try importedQualifiedCallReturnTypePath(
                allocator,
                io,
                documents,
                project,
                program,
                call,
            )) |type_path| return .{ .imported_member = .{
                .type_path = type_path,
                .prefix = prefix,
                .cursor = cursor,
            } };
            if (try importedInstanceCallReturnTypePath(
                allocator,
                io,
                documents,
                project,
                program,
                source,
                cursor,
                call,
            )) |type_path| return .{ .imported_member = .{
                .type_path = type_path,
                .prefix = prefix,
                .cursor = cursor,
            } };
        }
        if (Completion.directCall(receiver)) |call| {
            if (try importedConstructorCallTypePath(
                allocator,
                io,
                documents,
                project,
                program,
                call,
            )) |type_path| return .{ .imported_member = .{
                .type_path = type_path,
                .prefix = prefix,
                .cursor = cursor,
            } };
        }
        if (try importedTypePath(allocator, program, project, Completion.nominalReceiverName(receiver))) |type_path| {
            return .{ .imported_member = .{
                .type_path = type_path,
                .prefix = prefix,
                .cursor = cursor,
                .static_receiver = true,
            } };
        }
        if (Completion.resolveReceiverType(allocator, source, program, cursor, receiver)) |local_type| {
            if (try importedNominalTypePath(allocator, io, documents, program, project, local_type)) |resolved| {
                return .{ .imported_member = .{ .type_path = resolved, .prefix = prefix, .cursor = cursor } };
            }
        }
        if (try declaredCallReturnTypePath(
            allocator,
            io,
            documents,
            project,
            program,
            source,
            cursor,
            receiver,
        )) |type_path| return .{ .imported_member = .{
            .type_path = type_path,
            .prefix = prefix,
            .cursor = cursor,
        } };
        if (try importedFieldReceiverTypePath(
            allocator,
            io,
            documents,
            project,
            program,
            source,
            cursor,
            receiver,
        )) |type_path| return .{ .imported_member = .{
            .type_path = type_path,
            .prefix = prefix,
            .cursor = cursor,
        } };
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
    // Keep qualified package paths usable while the surrounding source is
    // temporarily unparsable, as happens between accepting a call snippet and
    // finishing one of its arguments. Namespaces expose their children, while
    // declarations expose their static members (including enum variants).
    if ((findProvider(project.index, receiver) != null or project.index.isNamespace(receiver)) and
        try modulePathVisible(allocator, io, documents, project, receiver))
    {
        return .{ .qualifier = .{
            .path = receiver,
            .prefix = prefix,
            .cursor = cursor,
            .type_only = qualified_type,
        } };
    }
    if (declarationTarget(project.index, receiver)) |target| {
        const provider = project.index.providers[target.provider];
        if (project.graph.canAccess(project.current_owner, provider.owner, provider.name)) {
            return .{ .imported_member = .{
                .type_path = receiver,
                .prefix = prefix,
                .cursor = cursor,
                .static_receiver = true,
            } };
        }
    }
    return null;
}

fn indexProject(
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    target: TargetModule.Target,
    root: []const u8,
    document_path: []const u8,
) !IndexedProject {
    if (builtin.is_test) try PackageTestFixtures.prepareWorkspaceLinks(allocator, io, root);
    return ProjectIndex.index(allocator, io, global_packages_root, target, root, document_path);
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
    const type_priority: u8 = 5;
    const child_prefix = if (query.qualifier.len == 0)
        ""
    else
        try std.fmt.allocPrint(allocator, "{s}.", .{query.qualifier});
    const contextual_provider = contextualProvider(project, query.qualifier);
    const exact_provider = if (contextual_provider) |provider_index|
        project.index.providers[provider_index]
    else
        findProvider(project.index, query.qualifier);
    const exact_loaded = if (exact_provider) |provider|
        if (project.graph.canAccess(project.current_owner, provider.owner, provider.name))
            try loadProgram(allocator, io, documents, provider)
        else
            null
    else
        null;
    const module_context = if (exact_provider) |provider|
        providerInCurrentModule(project, provider)
    else
        false;
    const child_priority: u8 = if (call_source != null and exact_provider != null) 30 else 0;

    for (project.index.providers) |provider| {
        if (samePath(provider.path, project.current_path)) continue;
        if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) continue;
        if (!std.mem.startsWith(u8, provider.name, child_prefix)) continue;
        const remainder = provider.name[child_prefix.len..];
        if (remainder.len == 0) continue;
        const end = std.mem.indexOfScalar(u8, remainder, '.') orelse remainder.len;
        const child = remainder[0..end];
        if (!matchesPrefix(child, query.prefix)) continue;
        const child_path = if (query.qualifier.len == 0)
            child
        else
            try std.fmt.allocPrint(allocator, "{s}.{s}", .{ query.qualifier, child });
        if (!try modulePathVisible(allocator, io, documents, project, child_path)) continue;
        if ((query.type_only or call_source != null) and end == remainder.len and
            (exact_loaded == null or !hasPublicDeclaration(exact_loaded.?.program, child)) and
            try appendPrincipalType(
                allocator,
                io,
                documents,
                provider,
                child,
                call_source,
                call_cursor,
                ranked,
                type_priority,
                query.type_only,
            )) continue;
        try appendRanked(allocator, ranked, .{
            .label = child,
            .kind = CompletionKind.module,
            .detail = if (end == remainder.len) "Silex module" else "Silex module namespace",
        }, child_priority, false);
    }

    if (exact_provider == null) return;
    for (project.index.providers, 0..) |provider, provider_index| {
        if (contextual_provider != null) {
            if (provider_index != contextual_provider.?) continue;
        } else if (!std.mem.eql(u8, provider.name, query.qualifier)) continue;
        if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) continue;
        const loaded = try loadProgram(allocator, io, documents, provider) orelse continue;
        for (loaded.program.structures) |structure| {
            if (structure.is_local) continue;
            if (structure.is_internal) {
                if (!project.graph.canAccessPackage(project.current_owner, provider.owner)) continue;
            } else if (!module_context and contextual_provider == null and !structure.is_public) continue;
            if (!matchesPrefix(structure.name, query.prefix)) continue;
            if (query.type_only or call_source == null) {
                try appendRanked(allocator, ranked, .{
                    .label = structure.name,
                    .kind = nominalCompletionKind(structure),
                    .detail = try nominalCompletionDetail(allocator, structure),
                }, type_priority, false);
            } else if (structure.is_protocol or structure.is_static) {
                try appendRanked(allocator, ranked, .{
                    .label = structure.name,
                    .kind = nominalCompletionKind(structure),
                    .detail = try nominalCompletionDetail(allocator, structure),
                }, type_priority, false);
            } else if (structure.constructors.len == 0) {
                try appendRanked(allocator, ranked, .{
                    .label = structure.name,
                    .kind = nominalCompletionKind(structure),
                    .detail = try std.fmt.allocPrint(allocator, "{s}() {s}", .{ structure.name, structure.name }),
                }, type_priority, false);
            } else for (structure.constructors) |constructor| {
                if (!Completion.callAcceptsParameters(
                    call_source.?,
                    call_cursor,
                    loaded.program,
                    constructor.parameters,
                )) continue;
                try appendRanked(allocator, ranked, .{
                    .label = structure.name,
                    .kind = nominalCompletionKind(structure),
                    .detail = try Completion.constructorSignature(
                        allocator,
                        loaded.source,
                        loaded.program,
                        structure.name,
                        constructor,
                    ),
                }, type_priority, true);
            }
        }
        for (loaded.program.enums) |enumeration| {
            if (enumeration.is_local or !matchesPrefix(enumeration.name, query.prefix)) continue;
            if (enumeration.is_internal) {
                if (!project.graph.canAccessPackage(project.current_owner, provider.owner)) continue;
            } else if (!module_context and contextual_provider == null and !enumeration.is_public) continue;
            try appendRanked(allocator, ranked, .{
                .label = enumeration.name,
                .kind = CompletionKind.enum_type,
                .detail = try std.fmt.allocPrint(allocator, "enum {s}", .{enumeration.name}),
            }, type_priority, false);
        }
        if (!query.type_only) {
            for (loaded.program.functions) |function| {
                if (function.is_local) continue;
                if (function.is_internal) {
                    if (!project.graph.canAccessPackage(project.current_owner, provider.owner)) continue;
                } else if (!module_context and contextual_provider == null and !function.is_public) continue;
                if (call_source) |text| if (!Completion.callAcceptsParameters(
                    text,
                    call_cursor,
                    loaded.program,
                    function.parameters,
                )) continue;
                if (!matchesPrefix(function.name, query.prefix)) continue;
                try appendRanked(allocator, ranked, .{
                    .label = function.name,
                    .kind = CompletionKind.function,
                    .detail = try Completion.functionSignature(allocator, loaded.source, loaded.program, function),
                }, 10, true);
            }
        }
        if (contextual_provider != null) continue;
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
                }, type_priority, false);
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
    if (contextual_provider == null) if (exact_provider) |provider| {
        var contributed_aliases: std.ArrayList([]const u8) = .empty;
        const catalog_uses = try ProjectIndex.catalogUses(allocator, io, documents, project, provider);
        for (catalog_uses) |catalog_use| {
            const alias = catalog_use.use.alias orelse continue;
            if (!matchesPrefix(alias, query.prefix)) continue;
            if (!try catalogAliasAvailable(
                allocator,
                io,
                documents,
                project,
                provider,
                alias,
                contributed_aliases.items,
            )) continue;
            try contributed_aliases.append(allocator, alias);
            try appendReexportTarget(
                allocator,
                io,
                documents,
                project,
                catalog_use.use.path,
                alias,
                query.prefix,
                call_source,
                call_cursor,
                ranked,
                0,
                query.type_only,
            );
        }
    };
}

fn catalogAliasAvailable(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    catalog_provider: Modules.Provider,
    alias: []const u8,
    contributed_aliases: []const []const u8,
) !bool {
    for (contributed_aliases) |existing| if (std.mem.eql(u8, existing, alias)) return false;
    const child = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ catalog_provider.name, alias });
    if (project.index.isNamespace(child)) return false;
    for (project.index.providers) |provider| {
        if (!std.mem.eql(u8, provider.name, catalog_provider.name) or provider.owner != catalog_provider.owner) continue;
        const loaded = try loadProgram(allocator, io, documents, provider) orelse continue;
        if (hasPublicDeclaration(loaded.program, alias)) return false;
    }
    return true;
}

fn contextualProvider(project: IndexedProject, qualifier: []const u8) ?usize {
    const origin: Modules.Origin = if (std.mem.eql(u8, qualifier, "Platform"))
        .platform
    else if (std.mem.eql(u8, qualifier, "Target"))
        .target
    else
        return null;
    var current: ?Modules.Provider = null;
    for (project.index.providers) |provider| {
        if (samePath(provider.path, project.current_path)) {
            current = provider;
            break;
        }
    }
    const source = current orelse return null;
    for (project.index.providers, 0..) |provider, index| {
        if (provider.owner == source.owner and provider.origin == origin and std.mem.eql(u8, provider.name, source.name)) return index;
    }
    return null;
}

fn hasPublicDeclaration(program: Ast.Program, name: []const u8) bool {
    for (program.structures) |structure| {
        if (structure.is_public and std.mem.eql(u8, structure.name, name)) return true;
    }
    for (program.enums) |enumeration| {
        if (enumeration.is_public and std.mem.eql(u8, enumeration.name, name)) return true;
    }
    for (program.functions) |function| {
        if (function.is_public and std.mem.eql(u8, function.name, name)) return true;
    }
    for (program.uses) |use| {
        if (use.is_public and use.alias != null and std.mem.eql(u8, use.alias.?, name)) return true;
    }
    return false;
}

fn hasVisibleApi(graph: @import("../Packages.zig").Graph, current_owner: usize, provider_owner: usize, program: Ast.Program) bool {
    const package_visible = graph.canAccessPackage(current_owner, provider_owner);
    for (program.structures) |structure| if (structure.is_public or (package_visible and structure.is_internal)) return true;
    for (program.enums) |enumeration| if (enumeration.is_public or (package_visible and enumeration.is_internal)) return true;
    for (program.functions) |function| if (function.is_public or (package_visible and function.is_internal)) return true;
    for (program.uses) |use| if (use.is_public and use.alias != null) return true;
    for (program.extensions) |extension| {
        if (extension.conformances.len != 0) return true;
        for (extension.methods) |method| if (method.is_public or (package_visible and method.is_internal)) return true;
    }
    return false;
}

fn modulePathVisible(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    path: []const u8,
) !bool {
    for (project.index.providers) |provider| {
        const matches = std.mem.eql(u8, provider.name, path) or
            (provider.name.len > path.len and std.mem.startsWith(u8, provider.name, path) and
                provider.name[path.len] == '.');
        if (!matches or !project.graph.canAccess(project.current_owner, provider.owner, provider.name)) continue;
        if (provider.owner == project.current_owner) return true;
        const loaded = try loadProgram(allocator, io, documents, provider) orelse continue;
        if (hasVisibleApi(project.graph, project.current_owner, provider.owner, loaded.program)) return true;
    }
    return false;
}

fn nominalCompletionKind(structure: Ast.Structure) u8 {
    if (structure.is_protocol) return CompletionKind.interface;
    if (structure.is_class) return CompletionKind.class;
    return CompletionKind.structure;
}

fn nominalCompletionDetail(allocator: Allocator, structure: Ast.Structure) ![]const u8 {
    const declaration = if (structure.is_protocol)
        "protocol"
    else if (structure.is_static and structure.is_class)
        "static class"
    else if (structure.is_static)
        "static struct"
    else if (structure.is_class)
        "class"
    else
        "struct";
    return std.fmt.allocPrint(allocator, "{s} {s}", .{ declaration, structure.name });
}

fn appendPrincipalType(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    provider: Modules.Provider,
    name: []const u8,
    call_source: ?[]const u8,
    call_cursor: usize,
    ranked: *std.ArrayList(RankedItem),
    priority: u8,
    type_only: bool,
) !bool {
    const loaded = try loadProgram(allocator, io, documents, provider) orelse return false;
    for (loaded.program.structures) |structure| {
        if (!structure.is_public or !std.mem.eql(u8, structure.name, name)) continue;
        if (type_only or structure.is_protocol or structure.is_static) {
            try appendRanked(allocator, ranked, .{
                .label = name,
                .kind = nominalCompletionKind(structure),
                .detail = try nominalCompletionDetail(allocator, structure),
            }, priority, false);
        } else if (structure.constructors.len == 0) {
            try appendRanked(allocator, ranked, .{
                .label = name,
                .kind = nominalCompletionKind(structure),
                .detail = try std.fmt.allocPrint(allocator, "{s}() {s}", .{ name, name }),
            }, priority, false);
        } else for (structure.constructors) |constructor| {
            if (!Completion.callAcceptsParameters(call_source.?, call_cursor, loaded.program, constructor.parameters)) continue;
            try appendRanked(allocator, ranked, .{
                .label = name,
                .kind = nominalCompletionKind(structure),
                .detail = try Completion.constructorSignature(
                    allocator,
                    loaded.source,
                    loaded.program,
                    name,
                    constructor,
                ),
            }, priority, true);
        }
        return true;
    }
    for (loaded.program.enums) |enumeration| {
        if (!enumeration.is_public or !std.mem.eql(u8, enumeration.name, name)) continue;
        try appendRanked(allocator, ranked, .{
            .label = name,
            .kind = CompletionKind.enum_type,
            .detail = try std.fmt.allocPrint(allocator, "enum {s}", .{name}),
        }, priority, false);
        return true;
    }
    return false;
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
        if (type_only or call_source == null or structure.is_protocol or structure.is_static) {
            try appendRanked(allocator, ranked, .{
                .label = label,
                .kind = nominalCompletionKind(structure),
                .detail = try nominalCompletionDetail(allocator, structure),
            }, 5, false);
        } else if (structure.constructors.len == 0) {
            try appendRanked(allocator, ranked, .{
                .label = label,
                .kind = nominalCompletionKind(structure),
                .detail = try std.fmt.allocPrint(allocator, "{s}() {s}", .{ label, label }),
            }, 5, false);
        } else for (structure.constructors) |constructor| {
            if (!Completion.callAcceptsParameters(call_source.?, call_cursor, loaded.program, constructor.parameters)) continue;
            try appendRanked(allocator, ranked, .{
                .label = label,
                .kind = nominalCompletionKind(structure),
                .detail = try Completion.constructorSignature(
                    allocator,
                    loaded.source,
                    loaded.program,
                    label,
                    constructor,
                ),
            }, 5, true);
        }
        return;
    }
    for (loaded.program.enums) |enumeration| {
        if (!enumeration.is_public or !std.mem.eql(u8, enumeration.name, target.declaration)) continue;
        try appendRanked(allocator, ranked, .{
            .label = label,
            .kind = CompletionKind.enum_type,
            .detail = try std.fmt.allocPrint(allocator, "enum {s}", .{enumeration.name}),
        }, 5, false);
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
                .kind = CompletionKind.function,
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
            }, 5, false);
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
    return appendImportedMembersDepth(allocator, io, documents, project, current_source, query, ranked, 0);
}

fn appendImportedMembersDepth(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    current_source: []const u8,
    query: ImportedMemberQuery,
    ranked: *std.ArrayList(RankedItem),
    depth: usize,
) !void {
    if (depth > project.index.providers.len) return;
    const target = declarationTarget(project.index, query.type_path) orelse return;
    const provider = project.index.providers[target.provider];
    if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) return;
    const loaded = try loadProgram(allocator, io, documents, provider) orelse return;
    for (loaded.program.structures) |structure| {
        if (!std.mem.eql(u8, structure.name, target.declaration)) continue;
        if (!structure.is_public) return;
        if (query.static_receiver) {
            for (structure.static_fields) |field| {
                if (!importedMemberVisible(project, provider, field)) continue;
                if (!std.mem.startsWith(u8, field.name, query.prefix)) continue;
                try appendRanked(allocator, ranked, .{
                    .label = field.name,
                    .kind = CompletionKind.field,
                    .detail = try std.fmt.allocPrint(allocator, "static {s}:{s}", .{
                        field.name,
                        Completion.typeName(loaded.program, field.type),
                    }),
                }, Completion.memberFieldPriority, false);
            }
            for (structure.methods) |method| {
                if (!method.is_static or !importedMemberVisible(project, provider, method)) continue;
                if (!std.mem.startsWith(u8, method.name, query.prefix)) continue;
                if (!Completion.callAcceptsParameters(
                    current_source,
                    query.cursor,
                    loaded.program,
                    method.parameters,
                )) continue;
                try appendRanked(allocator, ranked, .{
                    .label = method.name,
                    .kind = CompletionKind.method,
                    .detail = try Completion.functionSignature(allocator, loaded.source, loaded.program, method),
                }, Completion.memberMethodPriority, true);
            }
            return;
        }
        for (structure.fields) |field| {
            if (!importedMemberVisible(project, provider, field)) continue;
            if (!std.mem.startsWith(u8, field.name, query.prefix)) continue;
            try appendRanked(allocator, ranked, .{
                .label = field.name,
                .kind = CompletionKind.field,
                .detail = try std.fmt.allocPrint(allocator, "{s}:{s}", .{
                    field.name,
                    Completion.typeName(loaded.program, field.type),
                }),
            }, Completion.memberFieldPriority, false);
        }
        for (structure.methods) |method| {
            if (method.is_static or !importedMemberVisible(project, provider, method)) continue;
            if (!std.mem.startsWith(u8, method.name, query.prefix)) continue;
            if (!Completion.callAcceptsParameters(
                current_source,
                query.cursor,
                loaded.program,
                method.parameters,
            )) continue;
            try appendRanked(allocator, ranked, .{
                .label = method.name,
                .kind = CompletionKind.method,
                .detail = try Completion.functionSignature(allocator, loaded.source, loaded.program, method),
            }, Completion.memberMethodPriority, true);
        }
        try appendProviderExtensionMethods(
            allocator,
            project,
            current_source,
            query,
            loaded,
            structure,
            provider,
            ranked,
        );
        try appendCurrentExtensionMethods(
            allocator,
            project,
            current_source,
            query,
            ranked,
        );
        return;
    }
    for (loaded.program.enums) |enumeration| {
        if (!std.mem.eql(u8, enumeration.name, target.declaration)) continue;
        if (!enumeration.is_public or !query.static_receiver) return;
        for (enumeration.variants) |variant| {
            if (!std.mem.startsWith(u8, variant.name, query.prefix)) continue;
            try appendRanked(allocator, ranked, .{
                .label = variant.name,
                .kind = CompletionKind.enum_member,
                .detail = try Completion.variantSignature(allocator, loaded.program, enumeration, variant),
            }, 0, variant.associated_types.len != 0);
        }
        return;
    }
    for (loaded.program.uses) |exported| {
        if (!exported.is_public or exported.alias == null or
            !std.mem.eql(u8, exported.alias.?, target.declaration)) continue;
        var resolved = query;
        resolved.type_path = exported.path;
        return appendImportedMembersDepth(
            allocator,
            io,
            documents,
            project,
            current_source,
            resolved,
            ranked,
            depth + 1,
        );
    }
}

fn appendProviderExtensionMethods(
    allocator: Allocator,
    project: IndexedProject,
    source: []const u8,
    query: ImportedMemberQuery,
    loaded: LoadedProgram,
    target: Ast.Structure,
    provider: Modules.Provider,
    ranked: *std.ArrayList(RankedItem),
) !void {
    for (loaded.program.extensions) |extension| {
        const local_target = Completion.typeName(loaded.program, extension.target);
        const matches_local_target = std.mem.indexOfScalar(u8, local_target, '.') == null and
            std.mem.eql(u8, local_target, target.name);
        const matches_imported_target = if (matches_local_target)
            true
        else if (try importedTypePath(allocator, loaded.program, project, local_target)) |resolved|
            std.mem.eql(u8, resolved, query.type_path)
        else
            false;
        if (!matches_imported_target) continue;
        for (extension.methods) |method| {
            if (method.is_static) continue;
            if (method.visibility_explicit) {
                if (!importedMemberVisible(project, provider, method)) continue;
            } else if (!importedMemberVisible(project, provider, target)) continue;
            if (!std.mem.startsWith(u8, method.name, query.prefix)) continue;
            if (!Completion.callAcceptsParameters(source, query.cursor, loaded.program, method.parameters)) continue;
            try appendRanked(allocator, ranked, .{
                .label = method.name,
                .kind = 2,
                .detail = try Completion.functionSignature(allocator, loaded.source, loaded.program, method),
            }, Completion.memberMethodPriority, true);
        }
    }
}

fn appendCurrentExtensionMethods(
    allocator: Allocator,
    project: IndexedProject,
    source: []const u8,
    query: ImportedMemberQuery,
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
            if (method.is_private and !query.inside_extension) continue;
            if (!Completion.callAcceptsParameters(source, query.cursor, program, method.parameters)) continue;
            try appendRanked(allocator, ranked, .{
                .label = method.name,
                .kind = 2,
                .detail = try Completion.functionSignature(allocator, source, program, method),
            }, Completion.memberMethodPriority, true);
        }
    }
}

const LoadedProgram = ProjectIndex.LoadedProgram;

fn loadProgram(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    provider: Modules.Provider,
) !?LoadedProgram {
    return ProjectIndex.loadProgram(allocator, io, documents, provider);
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
    if (try Completion.recoverCascadeForParsing(allocator, source, cursor)) |recovered| {
        if (try parseCurrent(allocator, recovered)) |program| return program;
    }
    const completion_line_start = if (std.mem.lastIndexOfScalar(u8, source[0..cursor], '\n')) |newline| newline + 1 else 0;
    const before_cursor = std.mem.trim(u8, source[completion_line_start..cursor], " \t\r");
    const control_body_missing = Completion.lineStartsControlCondition(before_cursor) and
        !blockFollowsCursor(source, cursor);
    const placeholder = if (type_position)
        if (prefix.len == 0) "__Completion" else ""
    else if (Completion.callFollows(source, cursor))
        if (prefix.len == 0) "__completion" else ""
    else if (prefix.len == 0)
        if (control_body_missing) "__completion() {}" else "__completion()"
    else
        "()";
    const recovered = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
        source[0..cursor],
        placeholder,
        source[cursor..],
    });
    if (try parseCurrent(allocator, recovered)) |program| return program;
    if (!type_position or prefix.len > cursor) return null;

    const prefix_start = cursor - prefix.len;
    const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..prefix_start], '\n')) |newline|
        newline + 1
    else
        0;

    const line_end = if (std.mem.indexOfScalarPos(u8, source, cursor, '\n')) |newline|
        newline + 1
    else
        source.len;
    const without_incomplete_declaration = try std.fmt.allocPrint(allocator, "{s}{s}", .{
        source[0..line_start],
        source[line_end..],
    });
    return parseCurrent(allocator, without_incomplete_declaration);
}

fn blockFollowsCursor(source: []const u8, cursor: usize) bool {
    var index = cursor;
    while (index < source.len and (source[index] == ' ' or source[index] == '\t' or source[index] == '\r' or
        source[index] == '\n')) index += 1;
    return index < source.len and source[index] == '{';
}

fn parseCurrentAtScope(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
    prefix_start: usize,
    type_only: bool,
    aggregate_field: bool,
) !?Ast.Program {
    if (try parseCurrent(allocator, source)) |program| return program;
    const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..prefix_start], '\n')) |newline|
        newline + 1
    else
        0;
    const before_prefix = std.mem.trim(u8, source[line_start..prefix_start], " \t\r");
    const placeholder = if (aggregate_field)
        "__completion:true"
    else if (type_only)
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
    if (try parseCurrent(allocator, recovered)) |program| return program;
    const line_end = if (std.mem.indexOfScalarPos(u8, source, cursor, '\n')) |newline|
        newline + 1
    else
        source.len;
    const without_incomplete_declaration = try std.fmt.allocPrint(allocator, "{s}{s}", .{
        source[0..line_start],
        source[line_end..],
    });
    return parseCurrent(allocator, without_incomplete_declaration);
}

fn findUseByAlias(program: Ast.Program, alias: []const u8) ?Ast.Use {
    for (program.uses) |use| {
        const local = use.alias orelse lastSegment(use.path);
        if (std.mem.eql(u8, local, alias)) return use;
    }
    return null;
}

fn importedFieldReceiverTypePath(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    program: Ast.Program,
    source: []const u8,
    cursor: usize,
    receiver: []const u8,
) !?[]const u8 {
    const separator = std.mem.indexOfScalar(u8, receiver, '.') orelse receiver.len;
    const root = receiver[0..separator];
    const local_type = Completion.resolveReceiverType(allocator, source, program, cursor, root) orelse return null;
    var resolved = try importedTypePath(allocator, program, project, local_type) orelse return null;
    var field_start = separator;
    while (field_start < receiver.len) {
        field_start += 1;
        const field_end = std.mem.indexOfScalarPos(u8, receiver, field_start, '.') orelse receiver.len;
        resolved = try importedFieldTypePath(
            allocator,
            io,
            documents,
            project,
            resolved,
            receiver[field_start..field_end],
        ) orelse return null;
        field_start = field_end;
    }
    return resolved;
}

fn importedFieldTypePath(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    type_path: []const u8,
    field_name: []const u8,
) !?[]const u8 {
    const target = declarationTarget(project.index, type_path) orelse return null;
    const provider = project.index.providers[target.provider];
    if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) return null;
    const loaded = try loadProgram(allocator, io, documents, provider) orelse return null;
    for (loaded.program.structures) |structure| {
        if (!std.mem.eql(u8, structure.name, target.declaration)) continue;
        for (structure.fields) |field| {
            if (!std.mem.eql(u8, field.name, field_name)) continue;
            const local_type = Completion.typeName(loaded.program, field.type);
            return importedTypePath(allocator, loaded.program, project, local_type);
        }
        return null;
    }
    return null;
}

fn importedConstructorCallTypePath(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    current: Ast.Program,
    call: Completion.DirectCall,
) !?[]const u8 {
    const use = findUseByAlias(current, call.name) orelse return null;
    const target = declarationTarget(project.index, use.path) orelse return null;
    const provider = project.index.providers[target.provider];
    if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) return null;
    const loaded = try loadProgram(allocator, io, documents, provider) orelse return null;
    for (loaded.program.structures) |structure| {
        if (!structure.is_public or structure.is_protocol or structure.is_static or
            !std.mem.eql(u8, structure.name, target.declaration)) continue;
        if (structure.constructors.len == 0) return if (call.arity == 0) use.path else null;
        for (structure.constructors) |constructor| {
            if (!importedMemberVisible(project, provider, constructor)) continue;
            if (parametersAcceptArity(constructor.parameters, call.arity)) return use.path;
        }
        return null;
    }
    return null;
}

fn declaredCallReturnTypePath(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    current: Ast.Program,
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
    var index: usize = 0;
    while (index + 4 < tokens.items.len) : (index += 1) {
        if (tokens.items[index].tag != .keyword_let and tokens.items[index].tag != .keyword_var) continue;
        if (tokens.items[index + 1].tag != .identifier or
            !std.mem.eql(u8, tokens.items[index + 1].lexeme, receiver) or
            tokens.items[index + 2].tag != .equal or
            tokens.items[index + 3].tag != .identifier) continue;

        if (tokens.items[index + 4].tag == .left_parenthesis) {
            const arity = callArity(tokens.items, index + 4) orelse continue;
            var result: ?[]const u8 = null;
            for (current.functions) |function| {
                if (!std.mem.eql(u8, function.name, tokens.items[index + 3].lexeme) or
                    !parametersAcceptArity(function.parameters, arity)) continue;
                const local_type = returnTypeName(current, function.return_type) orelse continue;
                const resolved = try importedTypePath(allocator, current, project, local_type) orelse continue;
                if (result != null and !std.mem.eql(u8, result.?, resolved)) return null;
                result = resolved;
            }
            return result;
        }

        if (index + 6 >= tokens.items.len or
            tokens.items[index + 4].tag != .dot or
            tokens.items[index + 5].tag != .identifier or
            tokens.items[index + 6].tag != .left_parenthesis) continue;

        const owner_alias = tokens.items[index + 3].lexeme;
        const method_name = tokens.items[index + 5].lexeme;
        const arguments = callArity(tokens.items, index + 6) orelse continue;

        return importedQualifiedCallReturnTypePath(
            allocator,
            io,
            documents,
            project,
            current,
            .{ .owner = owner_alias, .name = method_name, .arity = arguments },
        );
    }
    return null;
}

fn callArity(tokens: []const LexerModule.Token, opening: usize) ?usize {
    var depth: usize = 1;
    var arguments: usize = 0;
    var has_argument = false;
    var index = opening + 1;
    while (index < tokens.len) : (index += 1) switch (tokens[index].tag) {
        .left_parenthesis => {
            if (depth == 1) has_argument = true;
            depth += 1;
        },
        .right_parenthesis => {
            depth -|= 1;
            if (depth == 0) return arguments + @intFromBool(has_argument);
        },
        .comma => if (depth == 1) {
            arguments += 1;
        },
        else => {
            if (depth == 1) has_argument = true;
        },
    };
    return null;
}

fn importedQualifiedCallReturnTypePath(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    current: Ast.Program,
    call: Completion.QualifiedCall,
) !?[]const u8 {
    const owner_path = try importedTypePath(allocator, current, project, call.owner) orelse return null;
    const target = declarationTarget(project.index, owner_path) orelse return null;
    const provider = project.index.providers[target.provider];
    if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) return null;
    const loaded = try loadProgram(allocator, io, documents, provider) orelse return null;
    var return_name: ?[]const u8 = null;

    for (loaded.program.functions) |function| {
        if (function.is_local or !std.mem.eql(u8, function.name, call.name) or
            !parametersAcceptArity(function.parameters, call.arity)) continue;
        if (function.is_internal) {
            if (!project.graph.canAccessPackage(project.current_owner, provider.owner)) continue;
        } else if (!function.is_public and !providerInCurrentModule(project, provider)) continue;
        const candidate = returnTypeName(loaded.program, function.return_type) orelse continue;
        if (return_name != null and !std.mem.eql(u8, return_name.?, candidate)) return null;
        return_name = candidate;
    }
    for (loaded.program.structures) |structure| {
        if (!std.mem.eql(u8, structure.name, target.declaration) or !structure.is_public) continue;
        for (structure.methods) |method| {
            if (!method.is_static or !importedMemberVisible(project, provider, method) or
                !std.mem.eql(u8, method.name, call.name) or
                !parametersAcceptArity(method.parameters, call.arity)) continue;
            const candidate = returnTypeName(loaded.program, method.return_type) orelse continue;
            if (return_name != null and !std.mem.eql(u8, return_name.?, candidate)) return null;
            return_name = candidate;
        }
    }
    if (return_name == null) for (loaded.program.uses) |exported| {
        if (!exported.is_public or exported.alias == null or
            !std.mem.eql(u8, exported.alias.?, call.name)) continue;
        const exported_target = declarationTarget(project.index, exported.path) orelse continue;
        const exported_provider = project.index.providers[exported_target.provider];
        if (!project.graph.canAccess(project.current_owner, exported_provider.owner, exported_provider.name)) continue;
        const exported_program = try loadProgram(allocator, io, documents, exported_provider) orelse continue;
        for (exported_program.program.structures) |structure| {
            if (!structure.is_public or structure.is_protocol or structure.is_static or
                !std.mem.eql(u8, structure.name, exported_target.declaration)) continue;
            if (structure.constructors.len == 0) return if (call.arity == 0) exported.path else null;
            for (structure.constructors) |constructor| {
                if (!importedMemberVisible(project, exported_provider, constructor)) continue;
                if (parametersAcceptArity(constructor.parameters, call.arity)) return exported.path;
            }
        }
    };
    const name = return_name orelse return null;
    if (try importedTypePath(allocator, loaded.program, project, name)) |resolved| return resolved;
    if (std.mem.indexOfScalar(u8, name, '.') != null and declarationTarget(project.index, name) != null) return name;
    if (std.mem.eql(u8, name, target.declaration)) return owner_path;
    const qualified: []const u8 = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ provider.name, name });
    return qualified;
}

fn importedInstanceCallReturnTypePath(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    current: Ast.Program,
    source: []const u8,
    cursor: usize,
    call: Completion.QualifiedCall,
) !?[]const u8 {
    const local_type = Completion.resolveReceiverType(allocator, source, current, cursor, call.owner) orelse return null;
    var owner_path = try importedTypePath(allocator, current, project, local_type) orelse return null;
    var depth: usize = 0;
    while (depth <= project.index.providers.len) : (depth += 1) {
        const target = declarationTarget(project.index, owner_path) orelse return null;
        const provider = project.index.providers[target.provider];
        if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) return null;
        const loaded = try loadProgram(allocator, io, documents, provider) orelse return null;
        var matched_structure = false;
        for (loaded.program.structures) |structure| {
            if (!structure.is_public or !std.mem.eql(u8, structure.name, target.declaration)) continue;
            matched_structure = true;
            var return_name: ?[]const u8 = null;
            for (structure.methods) |method| {
                if (method.is_static or !importedMemberVisible(project, provider, method) or
                    !std.mem.eql(u8, method.name, call.name) or
                    !parametersAcceptArity(method.parameters, call.arity)) continue;
                const candidate = returnTypeName(loaded.program, method.return_type) orelse continue;
                if (return_name != null and !std.mem.eql(u8, return_name.?, candidate)) return null;
                return_name = candidate;
            }
            const name = return_name orelse return null;
            if (try importedTypePath(allocator, loaded.program, project, name)) |resolved| return resolved;
            if (std.mem.indexOfScalar(u8, name, '.') != null and declarationTarget(project.index, name) != null) return name;
            if (std.mem.eql(u8, name, target.declaration)) return owner_path;
            return try std.fmt.allocPrint(allocator, "{s}.{s}", .{ provider.name, name });
        }
        if (matched_structure) return null;
        var reexport: ?[]const u8 = null;
        for (loaded.program.uses) |use| {
            if (!use.is_public or use.alias == null or
                !std.mem.eql(u8, use.alias.?, target.declaration)) continue;
            reexport = use.path;
            break;
        }
        owner_path = reexport orelse return null;
    }
    return null;
}

fn returnTypeName(program: Ast.Program, source_type: Ast.Type) ?[]const u8 {
    const type_value = source_type.optionalChild() orelse source_type;
    if (type_value.genericInstantiationIndex()) |index| {
        if (index >= program.generic_types.len) return null;
        return Completion.typeName(program, program.generic_types[index].base);
    }
    return if (type_value.structureIndex() != null) Completion.typeName(program, type_value) else null;
}

fn parametersAcceptArity(parameters: []const Ast.Parameter, arity: usize) bool {
    var required = parameters.len;
    for (parameters, 0..) |parameter, parameter_index| if (parameter.default != null) {
        required = parameter_index;
        break;
    };
    return arity >= required and arity <= parameters.len;
}

fn importedTypePath(
    allocator: Allocator,
    program: Ast.Program,
    project: IndexedProject,
    local_path: []const u8,
) !?[]const u8 {
    if (declarationTarget(project.index, local_path)) |target| {
        const provider = project.index.providers[target.provider];
        if (project.graph.canAccess(project.current_owner, provider.owner, provider.name)) return local_path;
    }
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

fn importedNominalTypePath(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    program: Ast.Program,
    project: IndexedProject,
    local_path: []const u8,
) !?[]const u8 {
    const resolved = try importedTypePath(allocator, program, project, local_path) orelse return null;
    return if (try importedPathIsNominal(allocator, io, documents, project, resolved, 0)) resolved else null;
}

fn importedPathIsNominal(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    path: []const u8,
    depth: usize,
) !bool {
    if (depth > project.index.providers.len) return false;
    const target = declarationTarget(project.index, path) orelse return false;
    const provider = project.index.providers[target.provider];
    if (!project.graph.canAccess(project.current_owner, provider.owner, provider.name)) return false;
    const loaded = try loadProgram(allocator, io, documents, provider) orelse return false;
    for (loaded.program.structures) |structure| {
        if (std.mem.eql(u8, structure.name, target.declaration)) return true;
    }
    for (loaded.program.enums) |enumeration| {
        if (std.mem.eql(u8, enumeration.name, target.declaration)) return true;
    }
    for (loaded.program.uses) |use| {
        if (!use.is_public or use.alias == null or !std.mem.eql(u8, use.alias.?, target.declaration)) continue;
        return importedPathIsNominal(allocator, io, documents, project, use.path, depth + 1);
    }
    return false;
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
    if (Completion.isReservedCompilerName(item.label)) return;
    for (ranked.items, 0..) |existing, index| {
        if (!std.mem.eql(u8, existing.item.label, item.label)) continue;
        if (existing.item.kind == CompletionKind.module and item.kind != CompletionKind.module) {
            ranked.items[index] = .{ .item = item, .priority = priority };
            return;
        }
        if (existing.item.kind != CompletionKind.module and item.kind == CompletionKind.module) return;
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

fn trimPathQualifier(path: []const u8) []const u8 {
    return std.mem.trimEnd(u8, path, " \t.");
}

fn prefixStart(source: []const u8, cursor: usize) usize {
    var start = cursor;
    while (start != 0 and (std.ascii.isAlphanumeric(source[start - 1]) or source[start - 1] == '_')) start -= 1;
    return start;
}

fn matchesPrefix(label: []const u8, prefix: []const u8) bool {
    return std.mem.indexOf(u8, label, prefix) != null;
}

fn lastSegment(path: []const u8) []const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, path, '.') orelse return path;
    return path[separator + 1 ..];
}

fn importedMemberVisible(project: IndexedProject, provider: Modules.Provider, member: anytype) bool {
    if (member.is_public) return true;
    if (member.is_local or member.is_private or member.is_protected) return false;
    if (member.is_internal) return project.graph.canAccessPackage(project.current_owner, provider.owner);
    return providerInCurrentModule(project, provider);
}

fn providerInCurrentModule(project: IndexedProject, provider: Modules.Provider) bool {
    for (project.index.providers) |current| {
        if (!samePath(current.path, project.current_path)) continue;
        return current.owner == provider.owner and
            ModuleScopes.sameProviders(project.index.providers, current.name, provider.name);
    }
    return false;
}

fn projectRoot(allocator: Allocator, io: Io, document_path: []const u8, root_hint: ?[]const u8) ![]const u8 {
    return ProjectIndex.projectRoot(allocator, io, document_path, root_hint);
}

pub fn pathFromUri(allocator: Allocator, uri: []const u8) ![]const u8 {
    return ProjectIndex.pathFromUri(allocator, uri);
}

fn samePath(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, std.mem.trimEnd(u8, left, "/"), std.mem.trimEnd(u8, right, "/"));
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
        .data = "struct Hidden {} public struct Visible {} package func inside() int { return 1 }",
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
    const visible = items[labelIndex(items, "Visible").?];
    try std.testing.expectEqualStrings("Visible", visible.insertText.?);
    try std.testing.expect(visible.insertTextFormat == null);

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
        \\    local var hidden_value:int
        \\    package var package_value:int
        \\    var value:int
        \\    init(value:int) { self.value = value }
        \\    local func hidden_method() int { return self.hidden_value }
        \\    package func package_method() int { return self.package_value }
        \\    func to_str() str { return "vector" }
        \\}
        \\public protocol Operation { func execute() }
        \\public class BuildHandle<T> {
        \\    func complete() T { panic("unused") }
        \\    func complete(callback:func(T)) {}
        \\}
        \\public class BuildWaitHandle<T> {
        \\    func complete() {}
        \\}
        \\public static class Builder {
        \\    func build<T>(value:T) BuildHandle<T> { panic("unused") }
        \\    func build<T>(value:T, callback:func(T)) BuildWaitHandle<T> { panic("unused") }
        \\}
        \\public func add(left:int, right:int = 1) int { return left + right }
        \\public func add(value:str) str { return value }
        \\func hidden() int { return 0 }
        \\package func package_only() int { return 0 }
        \\local func file_only() int { return 0 }
    ;
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Module/Operations.sx",
        .data = operations_source,
    });
    try temporary.dir.createDirPath(std.testing.io, "Math/Module/Operations");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Module/Operations/Platform.sx",
        .data = "func spawn() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Module/Operations/Visible.sx",
        .data = "public func open() {}",
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
    try std.testing.expect(hasLabel(import_items, "Operation"));
    try std.testing.expect(hasLabel(import_items, "add"));
    try std.testing.expect(hasLabel(import_items, "Visible"));
    try std.testing.expect(!hasLabel(import_items, "Platform"));
    try std.testing.expect(!hasLabel(import_items, "hidden"));
    try std.testing.expect(!hasLabel(import_items, "package_only"));
    try std.testing.expect(!hasLabel(import_items, "file_only"));
    const operation_item = import_items[labelIndex(import_items, "Operation").?];
    try std.testing.expectEqual(CompletionKind.interface, operation_item.kind);
    try std.testing.expectEqualStrings("protocol Operation", operation_item.detail);

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
    try std.testing.expect(!hasLabel(qualifier_items, "package_only"));
    try std.testing.expectEqual(@as(usize, 1), labelCount(qualifier_items, "add"));
    var saw_complete_add = false;
    for (qualifier_items) |item| if (completionNameMatches(item, "add") and
        std.mem.indexOf(u8, item.detail, "right:int = 1") != null)
    {
        saw_complete_add = true;
    };
    try std.testing.expect(saw_complete_add);

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
    try std.testing.expect(!hasLabel(member_items, "package_value"));
    try std.testing.expect(!hasLabel(member_items, "package_method"));

    const cascade_source =
        \\use Math.Operations
        \\func main() {
        \\    var pos = Operations.Vector(1)
        \\        ..
        \\}
    ;
    const cascade_cursor = std.mem.indexOf(u8, cascade_source, "..\n").? + "..".len;
    const cascade_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        cascade_source,
        cascade_cursor,
    )).?;
    try std.testing.expect(hasLabel(cascade_items, "to_str"));
    try std.testing.expect(!hasLabel(cascade_items, "add"));
    try std.testing.expect(!hasLabel(cascade_items, "if"));
    try std.testing.expect(!hasLabel(cascade_items, "hidden_value"));
    try std.testing.expect(!hasLabel(cascade_items, "hidden_method"));
    try std.testing.expect(!hasLabel(cascade_items, "package_value"));
    try std.testing.expect(!hasLabel(cascade_items, "package_method"));

    const static_source =
        \\use Math.Operations.Builder
        \\func main() { Builder. }
    ;
    const static_cursor = std.mem.indexOf(u8, static_source, "Builder.").? + "Builder.".len;
    const static_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        static_source,
        static_cursor,
    )).?;
    try std.testing.expectEqual(@as(usize, 2), labelCount(static_items, "build"));
    try std.testing.expect(!hasLabel(static_items, "to_str"));

    const wait_handle_source =
        \\use Math.Operations.Builder
        \\struct Work {}
        \\func main() {
        \\    var handle = Builder.build(Work(), func(value:Work) {})
        \\    handle.
        \\}
    ;
    const wait_handle_cursor = std.mem.indexOf(u8, wait_handle_source, "handle.").? + "handle.".len;
    const wait_handle_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        wait_handle_source,
        wait_handle_cursor,
    )).?;
    try std.testing.expect(hasLabel(wait_handle_items, "complete"));

    const task_handle_source =
        \\use Math.Operations.Builder
        \\struct Work {}
        \\func main() {
        \\    var handle = Builder.build(Work())
        \\    handle.
        \\}
    ;
    const task_handle_cursor = std.mem.indexOf(u8, task_handle_source, "handle.").? + "handle.".len;
    const task_handle_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        task_handle_source,
        task_handle_cursor,
    )).?;
    try std.testing.expectEqual(@as(usize, 2), labelCount(task_handle_items, "complete"));

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

test "complete imported application members in a cascade" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module/Window");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Application.sx",
        .data =
        \\public intrinsic class Resources { func insert() }
        \\public enum Schedule { startup; update }
        \\public class Application {
        \\    func install() Application { return self }
        \\    func resources() Resources { return Resources() }
        \\    func add_system(schedule:Schedule, callback:func()) Application { return self }
        \\    func add_system<System>(schedule:Schedule, callback:System) Application { panic("unspecialized") }
        \\    func run() int { return 0 }
        \\    package func __silex_add_system() Application { return self }
        \\    package func __silex_run_query() {}
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/@Module.sx",
        .data =
        \\public use GFX.Application
        \\public use GFX.Application.Schedule
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Window/@Module.sx",
        .data =
        \\public class Window {
        \\    init(settings:int = 0) {}
        \\    func show() {}
        \\}
        ,
    });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const source =
        \\use GFX.Application
        \\func main() {
        \\    var app = Application()
        \\        ..
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "..\n").? + "..".len;
    const items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        source,
        cursor,
    )).?;
    try std.testing.expect(hasLabel(items, "install"));
    try std.testing.expectEqualStrings(
        "add_system(${1:schedule}, ${2:callback})$0",
        items[labelIndex(items, "add_system").?].insertText.?,
    );
    try std.testing.expectEqual(@as(usize, 1), labelCount(items, "add_system"));
    try std.testing.expect(hasLabel(items, "run"));
    try std.testing.expect(!hasLabel(items, "if"));
    try std.testing.expect(!hasLabel(items, "__silex_add_system"));
    try std.testing.expect(!hasLabel(items, "__silex_run_query"));

    const resources_source =
        \\use GFX
        \\func main() {
        \\    let application = GFX.Application()
        \\    application.resources().
        \\}
    ;
    const resources_cursor = std.mem.indexOf(u8, resources_source, "resources().").? + "resources().".len;
    const resources_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        resources_source,
        resources_cursor,
    )).?;
    try std.testing.expect(hasLabel(resources_items, "insert"));
    try std.testing.expect(!hasLabel(resources_items, "GFX"));

    const direct_source =
        \\func main() {
        \\    var window = GFX.Window()
        \\        ..
        \\}
    ;
    const direct_cursor = std.mem.indexOf(u8, direct_source, "..\n").? + "..".len;
    const direct_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        direct_source,
        direct_cursor,
    )).?;
    try std.testing.expect(hasLabel(direct_items, "show"));

    const conditional_source =
        \\use GFX.Application
        \\func main() {
        \\    let app = Application()
        \\    if app.
        \\}
    ;
    const conditional_cursor = std.mem.indexOf(u8, conditional_source, "app.\n").? + "app.".len;
    const conditional_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        conditional_source,
        conditional_cursor,
    )).?;
    try std.testing.expect(hasLabel(conditional_items, "install"));
    try std.testing.expect(hasLabel(conditional_items, "run"));

    const optional_constructor_source = "func main() { let window = GFX.Wind }";
    const optional_constructor_cursor = std.mem.indexOf(u8, optional_constructor_source, "Wind }").? + "Wind".len;
    const optional_constructor_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        optional_constructor_source,
        optional_constructor_cursor,
    )).?;
    try std.testing.expectEqual(@as(usize, 2), labelCount(optional_constructor_items, "Window"));
    var saw_empty_constructor = false;
    var saw_explicit_constructor = false;
    for (optional_constructor_items) |item| {
        if (item.filterText == null or !std.mem.eql(u8, item.filterText.?, "Window")) continue;
        saw_empty_constructor = saw_empty_constructor or std.mem.eql(u8, item.insertText.?, "Window()");
        saw_explicit_constructor = saw_explicit_constructor or std.mem.indexOf(u8, item.insertText.?, "${1:settings}") != null;
        try std.testing.expect(std.mem.indexOf(u8, item.insertText.?, "settings:") == null);
    }
    try std.testing.expect(saw_empty_constructor);
    try std.testing.expect(saw_explicit_constructor);

    const reexported_enum_source =
        \\use GFX
        \\func callback() {}
        \\func main() {
        \\    GFX.Application()
        \\        ..add_system(schedule:GFX.Schedule., callback:callback)
        \\}
    ;
    const reexported_enum_cursor = std.mem.indexOf(u8, reexported_enum_source, "GFX.Schedule.").? +
        "GFX.Schedule.".len;
    const reexported_enum_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        reexported_enum_source,
        reexported_enum_cursor,
    )).?;
    try std.testing.expect(hasLabel(reexported_enum_items, "startup"));
    try std.testing.expect(hasLabel(reexported_enum_items, "update"));

    const invalid_named_tail_source =
        \\use GFX
        \\func callback() {}
        \\func main() {
        \\    GFX.Application()
        \\        ..add_system(schedule:GFX.Schedule., callback)
        \\        ..run()
        \\}
    ;
    const invalid_named_tail_cursor = std.mem.indexOf(u8, invalid_named_tail_source, "schedule:").? +
        "schedule:".len;
    const invalid_named_tail_items = try scopeItemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        invalid_named_tail_source,
        invalid_named_tail_cursor,
    );
    try std.testing.expect(hasLabel(invalid_named_tail_items, "GFX"));

    const invalid_qualified_cursor = std.mem.indexOf(u8, invalid_named_tail_source, "schedule:GFX.").? +
        "schedule:GFX.".len;
    const invalid_qualified_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        invalid_named_tail_source,
        invalid_qualified_cursor,
    )).?;
    try std.testing.expect(hasLabel(invalid_qualified_items, "Schedule"));

    const invalid_declaration_cursor = std.mem.indexOf(
        u8,
        invalid_named_tail_source,
        "schedule:GFX.Schedule.",
    ).? + "schedule:GFX.Schedule.".len;
    const invalid_declaration_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        invalid_named_tail_source,
        invalid_declaration_cursor,
    )).?;
    try std.testing.expect(hasLabel(invalid_declaration_items, "startup"));
    try std.testing.expect(hasLabel(invalid_declaration_items, "update"));

    const nested_source =
        \\use GFX.Application
        \\struct Settings { var title:str }
        \\struct WindowPlugin {}
        \\func main() {
        \\    Application()
        \\        ..install(WindowPlugin(Settings()
        \\            ..title = "Silex"
        \\        ))
        \\        ..
        \\        ..run()
        \\}
    ;
    const nested_cursor = std.mem.indexOf(u8, nested_source, "        ..\n").? + "        ..".len;
    const nested_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        nested_source,
        nested_cursor,
    )).?;
    try std.testing.expect(hasLabel(nested_items, "install"));
    try std.testing.expect(hasLabel(nested_items, "run"));
    try std.testing.expect(!hasLabel(nested_items, "title"));
}

test "complete remaining fields of an imported aggregate inside a cascade" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Window.sx",
        .data =
        \\public struct Settings {
        \\    let title:str = "Window"
        \\    let width:int = 1280
        \\    let height:int = 720
        \\    let resizable:bool = true
        \\    let fullscreen:bool = false
        \\    let borderless:bool = false
        \\    let high_pixel_density:bool = true
        \\    let hidden:bool = false
        \\}
        ,
    });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const source =
        \\use GFX.Window.Settings as WindowSettings
        \\func main() {
        \\    Application()
        \\        ..install(WindowPlugin(WindowSettings(
        \\            title:"Silex",
        \\            width:1024,
        \\            height:640,
        \\            re
        \\        )))
        \\        ..run()
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "re\n").? + "re".len;
    const items = try scopeItemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        source,
        cursor,
    );
    try std.testing.expect(hasLabel(items, "resizable"));
    try std.testing.expect(!hasLabel(items, "title"));
    try std.testing.expect(!hasLabel(items, "width"));
    try std.testing.expect(!hasLabel(items, "height"));
    try std.testing.expect(hasLabel(items, "fullscreen"));
    try std.testing.expect(!hasLabel(items, "hidden"));

    const first_source =
        \\use GFX.Window.Settings as WindowSettings
        \\func main() {
        \\    let settings = WindowSettings(re)
        \\}
    ;
    const first_cursor = std.mem.indexOf(u8, first_source, "WindowSettings(re)").? + "WindowSettings(re".len;
    const first_items = try scopeItemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        first_source,
        first_cursor,
    );
    try std.testing.expect(hasLabel(first_items, "resizable"));
    try std.testing.expect(!hasLabel(first_items, "hidden"));
}

test "complete imported settings fields from a nested constructor cascade" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module/Plugins");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Window.sx",
        .data =
        \\public struct Settings {
        \\    var title:str = "Window"
        \\    var width:int = 1280
        \\    var height:int = 720
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Plugins/WindowPlugin.sx",
        .data =
        \\public use GFX.Window.Settings as Settings
        \\public struct WindowPlugin {}
        ,
    });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const source =
        \\use GFX.Plugins.WindowPlugin
        \\func main() {
        \\    Application()
        \\        ..install(WindowPlugin(WindowPlugin.Settings()
        \\            ..
        \\        ))
        \\        ..run()
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "            ..\n").? + "            ..".len;
    const items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        source,
        cursor,
    )).?;
    try std.testing.expect(hasLabel(items, "title"));
    try std.testing.expect(hasLabel(items, "width"));
    try std.testing.expect(hasLabel(items, "height"));
    try std.testing.expect(!hasLabel(items, "return"));
}

test "complete imported members on borrowed function parameters" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Input.sx",
        .data =
        \\public class State {
        \\    func is_quit_requested() bool { return false }
        \\}
        \\public class Input {
        \\    func is_quit_requested() bool { return false }
        \\    func update() {}
        \\}
        \\public struct Entry<Key, Value> {
        \\    let key:Key
        \\    let value:Value
        \\}
        ,
    });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const source =
        \\use GFX.Input
        \\func advance_frame(input:@Input) {
        \\    input.
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "input.\n").? + "input.".len;
    const items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        source,
        cursor,
    )).?;
    try std.testing.expect(hasLabel(items, "is_quit_requested"));
    try std.testing.expect(hasLabel(items, "update"));
    try std.testing.expect(!hasLabel(items, "if"));

    const state_source =
        \\use GFX.Input
        \\use GFX.Input.State as InputState
        \\func advance_frame(input:@InputState) {
        \\    input.
        \\}
    ;
    const state_cursor = std.mem.indexOf(u8, state_source, "input.\n").? + "input.".len;
    const state_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        state_source,
        state_cursor,
    )).?;
    try std.testing.expect(hasLabel(state_items, "is_quit_requested"));
    try std.testing.expect(!hasLabel(state_items, "update"));
    try std.testing.expect(!hasLabel(state_items, "if"));

    const entry_source =
        \\use GFX.Input.Entry
        \\func passing(entry:@Entry<str, int>) bool {
        \\    entry.
        \\    return true
        \\}
    ;
    const entry_cursor = std.mem.indexOf(u8, entry_source, "entry.\n").? + "entry.".len;
    const entry_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        entry_source,
        entry_cursor,
    )).?;
    try std.testing.expect(hasLabel(entry_items, "key"));
    try std.testing.expect(hasLabel(entry_items, "value"));
    try std.testing.expect(!hasLabel(entry_items, "update"));
}

test "complete a module facade together with its child namespace" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "STD/Module/Math");
    try temporary.dir.createDirPath(std.testing.io, "STD/Platform/MacOS/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"STD\":\"=0.1.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"0.1.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/@module.sx",
        .data = "public func root() int { return 1 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/Math/@module.sx",
        .data = "public func answer() int { return 42 }\npublic func Vec3() int { return 0 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/Math/Point.sx",
        .data = "public struct Point { var x:int; var y:int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/Math/Vec3.sx",
        .data = "public struct Vec3 { var value:int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/Randomizer.sx",
        .data =
        \\public class Randomizer {
        \\    init() {}
        \\    init(seed:int) {}
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Platform/MacOS/Module/Randomizer.sx",
        .data = "func system_seed() int { return 1 }",
    });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const source = "func main() { STD.Math. }";
    const cursor = std.mem.indexOf(u8, source, "STD.Math. }").? + "STD.Math.".len;
    const items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        source,
        cursor,
    )).?;

    try std.testing.expect(hasLabel(items, "answer"));
    try std.testing.expect(hasLabel(items, "Point"));
    try std.testing.expectEqualStrings("Point", items[0].label);
    try std.testing.expectEqual(@as(u8, 22), items[0].kind);
    try std.testing.expectEqual(@as(usize, 1), labelCount(items, "Vec3"));
    const vec3 = items[labelIndex(items, "Vec3").?];
    try std.testing.expectEqual(@as(u8, 3), vec3.kind);

    const imported_namespace_source =
        \\use STD.Math
        \\func main() {
        \\    var value = Randomizer()
        \\        ..seed(Math.)
        \\}
    ;
    const imported_namespace_cursor = std.mem.indexOf(u8, imported_namespace_source, "Math.)").? +
        "Math.".len;
    const imported_namespace_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        imported_namespace_source,
        imported_namespace_cursor,
    )).?;
    try std.testing.expect(hasLabel(imported_namespace_items, "Point"));
    try std.testing.expect(hasLabel(imported_namespace_items, "Vec3"));

    const root_source = "func main() { STD. }";
    const root_cursor = std.mem.indexOf(u8, root_source, "STD. }").? + "STD.".len;
    const root_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        root_source,
        root_cursor,
    )).?;
    try std.testing.expect(hasLabel(root_items, "root"));
    try std.testing.expect(hasLabel(root_items, "Math"));
    try std.testing.expect(hasLabel(root_items, "Randomizer()"));
    try std.testing.expect(hasLabel(root_items, "Randomizer(seed:int)"));

    const package_prefix_source = "func main() { var value = S }";
    const package_prefix_cursor = std.mem.indexOf(u8, package_prefix_source, "S }").? + 1;
    const package_prefix_items = try scopeItemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        package_prefix_source,
        package_prefix_cursor,
    );
    try std.testing.expect(hasLabel(package_prefix_items, "STD"));
}

test "respect closed package namespaces during completion" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX.UI/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"GFX\":\"=1.0.0\",\"GFX.UI\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.UI/Package.json",
        .data = "{\"name\":\"GFX.UI\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.UI/Module/Button.sx",
        .data = "public struct Button {}",
    });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const source = "use GFX.UI.";

    try std.testing.expectError(
        error.InvalidPackageGraph,
        itemsAt(allocator, std.testing.io, null, root_uri, uri, &.{}, source, source.len),
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":[\"GFX.UI\"]}",
    });
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
    try std.testing.expect(hasLabel(items, "Button"));
}

fn hasLabel(items: []const Types.CompletionItem, label: []const u8) bool {
    for (items) |item| if (completionNameMatches(item, label)) return true;
    return false;
}

test "workspace indexes the selected package platform root" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Bridge/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Platform/MacOS/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Platform/Linux/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Platform/Windows/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Target/macos-arm64/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Target/linux-x64/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data = "{\"name\":\"Bridge\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Public.sx",
        .data = "public func visible() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Combined.sx",
        .data = "public func portable() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/MacOS/Module/Combined.sx",
        .data = "public func macos_fragment() {}\nfunc platform_module() {}\npackage func platform_package() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/Linux/Module/Combined.sx",
        .data = "public func linux_fragment() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/MacOS/Module/Implementation.sx",
        .data = "public func macos() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/Linux/Module/LinuxOnly.sx",
        .data = "public func linux() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Target/macos-arm64/Module/MacTarget.sx",
        .data = "public func macos_target() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Target/macos-arm64/Module/Combined.sx",
        .data = "func target_private() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Target/linux-x64/Module/LinuxTarget.sx",
        .data = "public func linux_target() {}",
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
    try std.testing.expect(hasLabel(items, "MacTarget"));
    try std.testing.expect(!hasLabel(items, "LinuxOnly"));

    const linux_items = (try itemsAtForTarget(
        allocator,
        std.testing.io,
        null,
        .linux_x64,
        root_uri,
        uri,
        &.{},
        source,
        source.len,
    )).?;
    try std.testing.expect(hasLabel(linux_items, "Public"));
    try std.testing.expect(hasLabel(linux_items, "LinuxOnly"));
    try std.testing.expect(hasLabel(linux_items, "LinuxTarget"));
    try std.testing.expect(!hasLabel(linux_items, "Implementation"));
    try std.testing.expect(!hasLabel(linux_items, "MacTarget"));

    const portable_source = "use Bridge.Combined\nfunc main() { Combined.p }";
    const portable_cursor = std.mem.indexOf(u8, portable_source, " }").?;
    const portable_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        portable_source,
        portable_cursor,
    )).?;
    try std.testing.expect(hasLabel(portable_items, "portable"));
    const platform_source = "use Bridge.Combined\nfunc main() { Combined.fragment }";
    const platform_cursor = std.mem.indexOf(u8, platform_source, " }").?;
    const platform_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        platform_source,
        platform_cursor,
    )).?;
    try std.testing.expect(hasLabel(platform_items, "macos_fragment"));
    try std.testing.expect(!hasLabel(platform_items, "linux_fragment"));

    const combined_path = try std.fs.path.join(allocator, &.{ root, "Bridge", "Module", "Combined.sx" });
    const combined_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{combined_path});
    try std.testing.expect(try hasProjectReferenceForTarget(
        allocator,
        std.testing.io,
        null,
        .macos_arm64,
        root_uri,
        combined_uri,
        "func portable() { Platform.macos_fragment() }",
    ));
    try std.testing.expect(!try hasProjectReferenceForTarget(
        allocator,
        std.testing.io,
        null,
        .macos_arm64,
        root_uri,
        combined_uri,
        "struct Platform {}\nfunc portable() { Platform.missing() }",
    ));
    try std.testing.expect(try hasProjectReferenceForTarget(
        allocator,
        std.testing.io,
        null,
        .macos_arm64,
        root_uri,
        uri,
        "func main() { Bridge.Combined.portable() }",
    ));
    try std.testing.expect(try hasProjectReferenceForTarget(
        allocator,
        std.testing.io,
        null,
        .macos_arm64,
        root_uri,
        uri,
        "func main() { var value = B }",
    ));
    const contextual_scope_source = "func portable() {\n    Pla\n}";
    const contextual_scope_cursor = std.mem.indexOf(u8, contextual_scope_source, "\n}").?;
    const contextual_scope_items = try scopeItemsAtForTarget(
        allocator,
        std.testing.io,
        null,
        .macos_arm64,
        root_uri,
        combined_uri,
        &.{},
        contextual_scope_source,
        contextual_scope_cursor,
    );
    try std.testing.expect(hasLabel(contextual_scope_items, "Platform"));
    try std.testing.expect(!hasLabel(contextual_scope_items, "Target"));
    const contextual_platform_source = "func portable() { Platform. }";
    const contextual_platform_cursor = std.mem.indexOf(u8, contextual_platform_source, " }").?;
    const contextual_platform_items = (try itemsAtForTarget(
        allocator,
        std.testing.io,
        null,
        .macos_arm64,
        root_uri,
        combined_uri,
        &.{},
        contextual_platform_source,
        contextual_platform_cursor,
    )).?;
    try std.testing.expect(hasLabel(contextual_platform_items, "macos_fragment"));
    try std.testing.expect(hasLabel(contextual_platform_items, "platform_module"));
    try std.testing.expect(hasLabel(contextual_platform_items, "platform_package"));
    try std.testing.expect(!hasLabel(contextual_platform_items, "portable"));

    const contextual_target_source = "func portable() { Target. }";
    const contextual_target_cursor = std.mem.indexOf(u8, contextual_target_source, " }").?;
    const contextual_target_items = (try itemsAtForTarget(
        allocator,
        std.testing.io,
        null,
        .macos_arm64,
        root_uri,
        combined_uri,
        &.{},
        contextual_target_source,
        contextual_target_cursor,
    )).?;
    try std.testing.expect(hasLabel(contextual_target_items, "target_private"));
    try std.testing.expect(!hasLabel(contextual_target_items, "platform_module"));
}

fn labelCount(items: []const Types.CompletionItem, label: []const u8) usize {
    var count: usize = 0;
    for (items) |item| if (completionNameMatches(item, label)) {
        count += 1;
    };
    return count;
}

fn labelIndex(items: []const Types.CompletionItem, label: []const u8) ?usize {
    for (items, 0..) |item, index| if (completionNameMatches(item, label)) return index;
    return null;
}

fn completionNameMatches(item: Types.CompletionItem, label: []const u8) bool {
    return std.mem.eql(u8, item.label, label) or
        (item.filterText != null and std.mem.eql(u8, item.filterText.?, label));
}

test "prefer every callable overload over a homonymous module" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const module: Types.CompletionItem = .{ .label = "Randomizer", .kind = CompletionKind.module, .detail = "Silex module" };
    const empty: Types.CompletionItem = .{ .label = "Randomizer", .kind = CompletionKind.class, .detail = "Randomizer() Randomizer" };
    const seeded: Types.CompletionItem = .{ .label = "Randomizer", .kind = CompletionKind.class, .detail = "Randomizer(seed:int) Randomizer" };

    var module_first: std.ArrayList(RankedItem) = .empty;
    try appendRanked(allocator, &module_first, module, 0, false);
    try appendRanked(allocator, &module_first, empty, 5, true);
    try appendRanked(allocator, &module_first, seeded, 5, true);
    try std.testing.expectEqual(@as(usize, 2), module_first.items.len);
    for (module_first.items) |item| try std.testing.expect(item.item.kind == CompletionKind.class);

    var module_last: std.ArrayList(RankedItem) = .empty;
    try appendRanked(allocator, &module_last, empty, 5, true);
    try appendRanked(allocator, &module_last, seeded, 5, true);
    try appendRanked(allocator, &module_last, module, 0, false);
    try std.testing.expectEqual(@as(usize, 2), module_last.items.len);
    for (module_last.items) |item| try std.testing.expect(item.item.kind == CompletionKind.class);
}

test "complete representative GFX members at their package and module boundaries" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GFX/Module/Canvas");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Canvas/@Module.sx",
        .data =
        \\public class Font {
        \\    init() {}
        \\    func load() int { return 0 }
        \\    package func cached_face_count() int { return 1 }
        \\    module func cached_face() int { return 2 }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GFX/Module/Probe.sx", .data = "" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GFX/Module/Canvas/Rasterizer.sx", .data = "" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "" });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const source =
        \\use GFX.Canvas.Font
        \\func main() { let font = Font(); font. }
    ;
    const cursor = std.mem.indexOf(u8, source, "font.").? + "font.".len;

    const consumer_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const consumer_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{consumer_path});
    const consumer_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        consumer_uri,
        &.{},
        source,
        cursor,
    )).?;
    try std.testing.expect(hasLabel(consumer_items, "load"));
    try std.testing.expect(!hasLabel(consumer_items, "cached_face_count"));
    try std.testing.expect(!hasLabel(consumer_items, "cached_face"));

    const probe_path = try std.fs.path.join(allocator, &.{ root, "GFX", "Module", "Probe.sx" });
    const probe_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{probe_path});
    const probe_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        probe_uri,
        &.{},
        source,
        cursor,
    )).?;
    try std.testing.expect(hasLabel(probe_items, "load"));
    try std.testing.expect(hasLabel(probe_items, "cached_face_count"));
    try std.testing.expect(!hasLabel(probe_items, "cached_face"));

    const rasterizer_path = try std.fs.path.join(allocator, &.{ root, "GFX", "Module", "Canvas", "Rasterizer.sx" });
    const rasterizer_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{rasterizer_path});
    const rasterizer_items = (try itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        rasterizer_uri,
        &.{},
        source,
        cursor,
    )).?;
    try std.testing.expect(hasLabel(rasterizer_items, "load"));
    try std.testing.expect(hasLabel(rasterizer_items, "cached_face_count"));
    try std.testing.expect(hasLabel(rasterizer_items, "cached_face"));
}
