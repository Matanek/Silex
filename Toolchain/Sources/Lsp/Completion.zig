const Types = @import("Types.zig");
const std = Types.std;
const build_options = Types.build_options;
const Ast = Types.Ast;
const Formatter = Types.Formatter;
const Frontend = Types.Frontend;
const LexerModule = Types.LexerModule;
const Lint = Types.Lint;
const ModuleDiscovery = Types.ModuleDiscovery;
const ModuleManifest = Types.ModuleManifest;
const ParserModule = Types.ParserModule;
const ProjectModule = Types.ProjectModule;
const Semantic = Types.Semantic;
const Source = Types.Source;
const StandardLibrary = Types.StandardLibrary;
const SourceGraph = Types.SourceGraph;
const SymbolIndex = Types.SymbolIndex;
const Allocator = Types.Allocator;
const Io = Types.Io;
const protocol_version = Types.protocol_version;
const max_message_size = Types.max_message_size;
const completion_trigger_characters = Types.completion_trigger_characters;
const semantic_token_types = Types.semantic_token_types;
const module_analysis_directory = Types.module_analysis_directory;
const Document = Types.Document;
const ProjectState = Types.ProjectState;
const VersionStamp = Types.VersionStamp;
const ProjectAffinity = Types.ProjectAffinity;
const ModuleAnalysisProject = Types.ModuleAnalysisProject;
const CompletionItem = Types.CompletionItem;
const SignatureInformation = Types.SignatureInformation;
const SignatureParameter = Types.SignatureParameter;
const SignatureHelpResult = Types.SignatureHelpResult;
const SemanticTokenKind = Types.SemanticTokenKind;
const SemanticTokenSpan = Types.SemanticTokenSpan;
const SemanticTokens = Types.SemanticTokens;
const Location = Types.Location;
const RenameEdit = Types.RenameEdit;
const TextDocumentEdit = Types.TextDocumentEdit;
const MarkupContent = Types.MarkupContent;
const Hover = Types.Hover;
const PreparedRename = Types.PreparedRename;
const WorkspaceEdit = Types.WorkspaceEdit;
const RequestContext = Types.RequestContext;
const RenameError = Types.RenameError;
const QualifiedCompletionContext = Types.QualifiedCompletionContext;
const ModuleExportScope = Types.ModuleExportScope;
const Position = Types.Position;
const Range = Types.Range;
const PositionEncoding = Types.PositionEncoding;
const TextEdit = Types.TextEdit;
const FormattingOutcome = Types.FormattingOutcome;
const Diagnostic = Types.Diagnostic;
const Request = Types.Request;

pub fn lastPathSegment(_: anytype, path: []const u8) []const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, path, '.') orelse return path;
    return path[separator + 1 ..];
}

pub fn firstPathSegment(_: anytype, path: []const u8) []const u8 {
    const separator = std.mem.indexOfScalar(u8, path, '.') orelse return path;
    return path[0..separator];
}

pub fn moduleExportCompletionItems(
    self: anytype,
    allocator: Allocator,
    io: Io,
    uri: []const u8,
    module_path: []const u8,
    context: QualifiedCompletionContext,
    scope: ModuleExportScope,
) ![]const CompletionItem {
    const source_path = try self.filePathFromUri(allocator, uri) orelse
        return try allocator.alloc(CompletionItem, 0);
    const project_root = std.fs.path.dirname(source_path) orelse
        return try allocator.alloc(CompletionItem, 0);
    const module_root = try self.moduleCompletionRoot(allocator, io, project_root, module_path) orelse
        return try allocator.alloc(CompletionItem, 0);
    var items: std.ArrayList(CompletionItem) = .empty;
    const module_directory = try self.moduleDirectoryPath(allocator, module_root, module_path);
    if (scope == .use_path or scope == .qualified_expression) {
        var directory = Io.Dir.cwd().openDir(io, module_directory, .{ .iterate = true }) catch null;
        if (directory) |*opened| {
            defer opened.close(io);
            var iterator = opened.iterateAssumeFirstIteration();
            while (iterator.next(io) catch null) |entry| {
                const child_name = if (entry.kind == .directory and ModuleDiscovery.isDirectoryName(entry.name))
                    entry.name
                else if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".sx")) block: {
                    const stem = entry.name[0 .. entry.name.len - ".sx".len];
                    if (!ModuleDiscovery.isModuleName(stem)) continue;
                    break :block self.firstPathSegment(stem);
                } else continue;
                if (!std.mem.startsWith(u8, child_name, context.prefix)) continue;
                if (scope == .qualified_expression) {
                    const child_path = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ module_path, child_name });
                    if (!try self.namespaceHasPublicApiOrChildren(allocator, io, module_root, child_path)) continue;
                }
                try self.appendModuleExportCompletion(
                    allocator,
                    &items,
                    context.qualifier,
                    child_name,
                    9,
                    "Silex child namespace",
                );
            }
        }
        try self.appendCompactChildCompletions(
            allocator,
            io,
            module_root,
            module_path,
            context,
            scope,
            &items,
        );
    }

    const module_sources = try self.namespaceSourcePaths(allocator, io, module_root, module_path);
    for (module_sources) |module_source_path| {
        const module_source = Io.Dir.cwd().readFileAlloc(
            io,
            module_source_path,
            allocator,
            .limited(max_message_size),
        ) catch continue;
        var parser = ParserModule.Parser.init(allocator, module_source);
        const program = parser.parse() catch continue;

        for (program.structures) |structure| {
            if (std.mem.eql(u8, structure.name, self.lastPathSegment(module_path))) continue;
            if (!structure.is_public or !std.mem.startsWith(u8, structure.name, context.prefix)) continue;
            try self.appendModuleExportCompletion(
                allocator,
                &items,
                context.qualifier,
                structure.name,
                22,
                "Silex public structure",
            );
        }
        for (program.enums) |enumeration| {
            if (std.mem.eql(u8, enumeration.name, self.lastPathSegment(module_path))) continue;
            if (!enumeration.is_public or !std.mem.startsWith(u8, enumeration.name, context.prefix)) continue;
            try self.appendModuleExportCompletion(
                allocator,
                &items,
                context.qualifier,
                enumeration.name,
                13,
                "Silex public enum",
            );
        }
        for (program.protocols) |protocol| {
            if (std.mem.eql(u8, protocol.name, self.lastPathSegment(module_path))) continue;
            if (!protocol.is_public or !std.mem.startsWith(u8, protocol.name, context.prefix)) continue;
            try self.appendModuleExportCompletion(
                allocator,
                &items,
                context.qualifier,
                protocol.name,
                8,
                "Silex public protocol",
            );
        }
        for (program.uses) |use_value| {
            if (!use_value.is_public or use_value.target != .type) continue;
            const alias = use_value.alias.?;
            if (!std.mem.startsWith(u8, alias, context.prefix)) continue;
            try self.appendModuleExportCompletion(
                allocator,
                &items,
                context.qualifier,
                alias,
                7,
                "Silex public type alias",
            );
        }
        if (!context.type_only) {
            for (program.functions) |function| {
                if (std.mem.eql(u8, function.name, self.lastPathSegment(module_path))) continue;
                if (!function.is_public or !std.mem.startsWith(u8, function.name, context.prefix)) continue;
                try self.appendModuleExportCompletion(
                    allocator,
                    &items,
                    context.qualifier,
                    function.name,
                    3,
                    try SymbolIndex.functionDetail(allocator, function),
                );
            }
        }
    }

    std.mem.sort(CompletionItem, items.items, {}, struct {
        fn lessThan(_: void, left: CompletionItem, right: CompletionItem) bool {
            return std.mem.lessThan(u8, left.label, right.label);
        }
    }.lessThan);
    return try items.toOwnedSlice(allocator);
}

pub fn moduleCompletionRoot(
    self: anytype,
    allocator: Allocator,
    io: Io,
    project_root: []const u8,
    module_path: []const u8,
) !?[]const u8 {
    const library_root = StandardLibrary.root(allocator, io) catch {
        return if (StandardLibrary.isReservedModule(module_path)) null else project_root;
    };
    if (StandardLibrary.isReservedModule(module_path)) return library_root;

    if (try self.lspNamespaceExists(allocator, io, project_root, module_path)) return project_root;
    if (try self.lspNamespaceExists(allocator, io, library_root, module_path)) return library_root;
    return project_root;
}

pub fn completionNamespaceExists(
    self: anytype,
    allocator: Allocator,
    io: Io,
    uri: []const u8,
    module_path: []const u8,
) !bool {
    const source_path = try self.filePathFromUri(allocator, uri) orelse return false;
    const project_root = std.fs.path.dirname(source_path) orelse return false;
    const root = try self.moduleCompletionRoot(allocator, io, project_root, module_path) orelse return false;
    return self.lspNamespaceExists(allocator, io, root, module_path);
}

pub fn lspNamespaceExists(self: anytype, allocator: Allocator, io: Io, root: []const u8, module_path: []const u8) !bool {
    const directory = try self.moduleDirectoryPath(allocator, root, module_path);
    if (try self.lspDirectoryExists(io, directory)) return true;
    if ((try self.namespaceSourcePaths(allocator, io, root, module_path)).len != 0) return true;
    return self.lspCompactDescendantExists(allocator, io, root, module_path);
}

pub fn lspCompactDescendantExists(self: anytype, allocator: Allocator, io: Io, root: []const u8, module_path: []const u8) !bool {
    var stem_start: usize = 0;
    while (true) {
        const prefix = if (stem_start == 0) "" else module_path[0 .. stem_start - 1];
        const stem = module_path[stem_start..];
        const physical_parent = if (prefix.len == 0) root else try self.moduleDirectoryPath(allocator, root, prefix);
        var directory = Io.Dir.cwd().openDir(io, physical_parent, .{ .iterate = true }) catch null;
        if (directory) |*opened| {
            defer opened.close(io);
            var iterator = opened.iterateAssumeFirstIteration();
            while (iterator.next(io) catch null) |entry| {
                if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".sx")) continue;
                const source_stem = entry.name[0 .. entry.name.len - ".sx".len];
                if (source_stem.len > stem.len and std.mem.startsWith(u8, source_stem, stem) and source_stem[stem.len] == '.') {
                    return true;
                }
            }
        }
        const separator = std.mem.indexOfScalarPos(u8, module_path, stem_start, '.') orelse break;
        stem_start = separator + 1;
    }
    return false;
}

pub fn appendCompactChildCompletions(
    self: anytype,
    allocator: Allocator,
    io: Io,
    root: []const u8,
    module_path: []const u8,
    context: QualifiedCompletionContext,
    scope: ModuleExportScope,
    items: *std.ArrayList(CompletionItem),
) !void {
    var stem_start: usize = 0;
    while (true) {
        const prefix = if (stem_start == 0) "" else module_path[0 .. stem_start - 1];
        const stem = module_path[stem_start..];
        const physical_parent = if (prefix.len == 0) root else try self.moduleDirectoryPath(allocator, root, prefix);
        var directory = Io.Dir.cwd().openDir(io, physical_parent, .{ .iterate = true }) catch null;
        if (directory) |*opened| {
            defer opened.close(io);
            var iterator = opened.iterateAssumeFirstIteration();
            while (iterator.next(io) catch null) |entry| {
                if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".sx")) continue;
                const source_stem = entry.name[0 .. entry.name.len - ".sx".len];
                if (source_stem.len <= stem.len or !std.mem.startsWith(u8, source_stem, stem) or source_stem[stem.len] != '.') continue;
                const child_name = self.firstPathSegment(source_stem[stem.len + 1 ..]);
                if (!std.mem.startsWith(u8, child_name, context.prefix)) continue;
                if (scope == .qualified_expression) {
                    const child_path = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ module_path, child_name });
                    if (!try self.namespaceHasPublicApiOrChildren(allocator, io, root, child_path)) continue;
                }
                try self.appendModuleExportCompletion(
                    allocator,
                    items,
                    context.qualifier,
                    child_name,
                    9,
                    "Silex child namespace",
                );
            }
        }
        const separator = std.mem.indexOfScalarPos(u8, module_path, stem_start, '.') orelse break;
        stem_start = separator + 1;
    }
}

pub fn namespaceHasPublicApiOrChildren(
    self: anytype,
    allocator: Allocator,
    io: Io,
    root: []const u8,
    module_path: []const u8,
) !bool {
    const directory = try self.moduleDirectoryPath(allocator, root, module_path);
    if (try self.lspDirectoryExists(io, directory)) return true;
    if (try self.lspCompactDescendantExists(allocator, io, root, module_path)) return true;
    const sources = try self.namespaceSourcePaths(allocator, io, root, module_path);
    for (sources) |source_path| {
        const source = Io.Dir.cwd().readFileAlloc(io, source_path, allocator, .limited(max_message_size)) catch continue;
        var parser = ParserModule.Parser.init(allocator, source);
        const program = parser.parse() catch continue;
        for (program.structures) |structure| if (structure.is_public) return true;
        for (program.enums) |enumeration| if (enumeration.is_public) return true;
        for (program.protocols) |protocol| if (protocol.is_public) return true;
        for (program.functions) |function| if (function.is_public) return true;
        for (program.uses) |use_value| if (use_value.is_public) return true;
    }
    return false;
}

pub fn namespaceSourcePaths(
    self: anytype,
    allocator: Allocator,
    io: Io,
    root: []const u8,
    module_path: []const u8,
) ![]const []const u8 {
    var sources: std.ArrayList([]const u8) = .empty;
    var stem_start: usize = 0;
    while (true) {
        const prefix = if (stem_start == 0) "" else module_path[0 .. stem_start - 1];
        const stem = module_path[stem_start..];
        const filename = try std.fmt.allocPrint(allocator, "{s}.sx", .{stem});
        const source_path = if (prefix.len == 0)
            try std.fs.path.join(allocator, &.{ root, filename })
        else
            try std.fs.path.join(allocator, &.{ try self.moduleDirectoryPath(allocator, root, prefix), filename });
        const stat = Io.Dir.cwd().statFile(io, source_path, .{}) catch null;
        if (stat != null and stat.?.kind == .file) try sources.append(allocator, source_path);
        const separator = std.mem.indexOfScalarPos(u8, module_path, stem_start, '.') orelse break;
        stem_start = separator + 1;
    }
    return sources.toOwnedSlice(allocator);
}

pub fn lspDirectoryExists(_: anytype, io: Io, path: []const u8) !bool {
    var directory = Io.Dir.cwd().openDir(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return false,
        else => |other| return other,
    };
    directory.close(io);
    return true;
}

pub fn appendModuleExportCompletion(
    self: anytype,
    allocator: Allocator,
    items: *std.ArrayList(CompletionItem),
    qualifier: []const u8,
    name: []const u8,
    kind: u8,
    detail: []const u8,
) !void {
    const label = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ qualifier, name });
    const insertion = try allocator.dupe(u8, name);
    const candidate: CompletionItem = .{
        .label = label,
        .kind = kind,
        .detail = detail,
        .insertText = insertion,
        .filterText = insertion,
    };
    if (self.containsEquivalentCompletion(items.items, candidate)) return;
    try items.append(allocator, candidate);
}

pub fn unqualifiedModuleCompletionItems(
    self: anytype,
    allocator: Allocator,
    qualified: []const CompletionItem,
) ![]const CompletionItem {
    var items: std.ArrayList(CompletionItem) = .empty;
    for (qualified) |candidate| {
        const name = candidate.insertText orelse self.lastPathSegment(candidate.label);
        var item = candidate;
        item.label = name;
        item.insertText = name;
        item.filterText = name;
        if (self.containsEquivalentCompletion(items.items, item)) continue;
        try items.append(allocator, item);
    }
    return items.toOwnedSlice(allocator);
}

pub fn moduleDirectoryPath(_: anytype, allocator: Allocator, root: []const u8, module_path: []const u8) ![]const u8 {
    const relative_path = try allocator.dupe(u8, module_path);
    for (relative_path) |*character| {
        if (character.* == '.') character.* = std.fs.path.sep;
    }
    return std.fs.path.join(allocator, &.{ root, relative_path });
}

pub fn localModuleCompletionItems(
    self: anytype,
    allocator: Allocator,
    io: Io,
    uri: []const u8,
    prefix: []const u8,
) ![]const CompletionItem {
    const source_path = try self.filePathFromUri(allocator, uri) orelse
        return try allocator.alloc(CompletionItem, 0);
    const project_root = std.fs.path.dirname(source_path) orelse
        return try allocator.alloc(CompletionItem, 0);

    var items: std.ArrayList(CompletionItem) = .empty;
    try self.collectRootModules(allocator, io, project_root, prefix, "Silex local module", &items);
    if (StandardLibrary.root(allocator, io) catch null) |standard_library_root| {
        try self.collectRootModules(allocator, io, standard_library_root, prefix, "Silex standard module", &items);
    }
    std.mem.sort(CompletionItem, items.items, {}, struct {
        fn lessThan(_: void, left: CompletionItem, right: CompletionItem) bool {
            return std.mem.lessThan(u8, left.label, right.label);
        }
    }.lessThan);
    return try items.toOwnedSlice(allocator);
}

pub fn useCompletionItems(
    self: anytype,
    allocator: Allocator,
    io: Io,
    uri: []const u8,
    source: []const u8,
    prefix: []const u8,
) ![]const CompletionItem {
    var items: std.ArrayList(CompletionItem) = .empty;
    if (std.mem.lastIndexOfScalar(u8, prefix, '.')) |separator| {
        const qualifier = prefix[0..separator];
        const module_path = try self.usedModulePath(allocator, source, qualifier) orelse qualifier;
        const exports = try self.moduleExportCompletionItems(
            allocator,
            io,
            uri,
            module_path,
            .{
                .qualifier = qualifier,
                .prefix = prefix[separator + 1 ..],
                .type_only = false,
            },
            .use_path,
        );
        const children = try self.unqualifiedModuleCompletionItems(allocator, exports);
        try items.appendSlice(allocator, children);
    } else {
        const modules = try self.localModuleCompletionItems(allocator, io, uri, prefix);
        try items.appendSlice(allocator, modules);
    }

    std.mem.sort(CompletionItem, items.items, {}, struct {
        fn lessThan(_: void, left: CompletionItem, right: CompletionItem) bool {
            return std.mem.lessThan(u8, left.label, right.label);
        }
    }.lessThan);
    return items.toOwnedSlice(allocator);
}

pub fn visibleUseCompletionItems(
    self: anytype,
    allocator: Allocator,
    io: Io,
    uri: []const u8,
    source: []const u8,
) ![]const CompletionItem {
    var items: std.ArrayList(CompletionItem) = .empty;
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |source_line| {
        var line = std.mem.trim(u8, source_line, " \t\r");
        if (self.directiveBody(line, "public")) |public_body| line = public_body;
        var declaration = self.directiveBody(line, "use") orelse continue;
        if (std.mem.indexOf(u8, declaration, "//")) |comment| declaration = declaration[0..comment];

        var words = std.mem.tokenizeAny(u8, declaration, " \t\r");
        const raw_target = words.next() orelse continue;
        const target = std.mem.trimEnd(u8, raw_target, ";");
        if (target.len == 0) continue;
        const separator = words.next();
        const raw_alias = if (separator != null and std.mem.eql(u8, separator.?, "as")) words.next() else null;
        const alias = if (raw_alias) |value| std.mem.trimEnd(u8, value, ";") else null;
        const visible_name = alias orelse self.lastPathSegment(target);
        if (!self.validIdentifier(visible_name) or self.containsCompletion(items.items, visible_name)) continue;

        var module_path = true;
        for (target) |character| {
            if (!self.isIdentifierContinue(character) and character != '.') {
                module_path = false;
                break;
            }
        }
        var found = false;
        if (module_path) {
            const candidates = try self.useCompletionItems(allocator, io, uri, source, target);
            const target_name = self.lastPathSegment(target);
            for (candidates) |candidate| {
                if (!std.mem.eql(u8, candidate.label, target_name)) continue;
                var item = candidate;
                item.label = visible_name;
                item.insertText = visible_name;
                item.filterText = visible_name;
                try items.append(allocator, item);
                found = true;
                break;
            }
        }
        if (!found and alias != null) try items.append(allocator, .{
            .label = visible_name,
            .kind = 7,
            .detail = "Silex used type",
            .insertText = visible_name,
            .filterText = visible_name,
        });
    }
    return items.toOwnedSlice(allocator);
}

pub fn visibleUseTarget(self: anytype, source: []const u8, visible_name: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |source_line| {
        var line = std.mem.trim(u8, source_line, " \t\r");
        if (self.directiveBody(line, "public")) |public_body| line = public_body;
        var declaration = self.directiveBody(line, "use") orelse continue;
        if (std.mem.indexOf(u8, declaration, "//")) |comment| declaration = declaration[0..comment];

        var words = std.mem.tokenizeAny(u8, declaration, " \t\r");
        const raw_target = words.next() orelse continue;
        const target = std.mem.trimEnd(u8, raw_target, ";");
        if (target.len == 0) continue;
        const separator = words.next();
        const raw_alias = if (separator != null and std.mem.eql(u8, separator.?, "as")) words.next() else null;
        const alias = if (raw_alias) |value| std.mem.trimEnd(u8, value, ";") else null;
        if (std.mem.eql(u8, alias orelse self.lastPathSegment(target), visible_name)) return target;
    }
    return null;
}

pub fn importedTypeStaticCompletionItems(
    self: anytype,
    allocator: Allocator,
    io: Io,
    uri: []const u8,
    source: []const u8,
    visible_name: []const u8,
    prefix: []const u8,
) !?[]const CompletionItem {
    const target = self.visibleUseTarget(source, visible_name) orelse
        try self.usedModulePath(allocator, source, visible_name) orelse return null;
    const separator = std.mem.lastIndexOfScalar(u8, target, '.') orelse return null;
    const type_name = target[separator + 1 ..];
    if (type_name.len == 0) return null;
    const source_path = try self.filePathFromUri(allocator, uri) orelse return null;
    const project_root = std.fs.path.dirname(source_path) orelse return null;

    if (try staticCompletionItemsFromModule(
        self,
        allocator,
        io,
        project_root,
        target,
        type_name,
        prefix,
    )) |items| return items;

    return staticCompletionItemsFromModule(
        self,
        allocator,
        io,
        project_root,
        target[0..separator],
        type_name,
        prefix,
    );
}

fn staticCompletionItemsFromModule(
    self: anytype,
    allocator: Allocator,
    io: Io,
    project_root: []const u8,
    module_path: []const u8,
    type_name: []const u8,
    prefix: []const u8,
) !?[]const CompletionItem {
    const module_root = try self.moduleCompletionRoot(allocator, io, project_root, module_path) orelse return null;
    const module_sources = try self.namespaceSourcePaths(allocator, io, module_root, module_path);

    for (module_sources) |module_source_path| {
        const module_source = Io.Dir.cwd().readFileAlloc(
            io,
            module_source_path,
            allocator,
            .limited(max_message_size),
        ) catch continue;
        var parser = ParserModule.Parser.init(allocator, module_source);
        const program = parser.parse() catch continue;
        var path: std.ArrayList([]const u8) = .empty;
        var path_iterator = std.mem.splitScalar(u8, type_name, '.');
        while (path_iterator.next()) |segment| try path.append(allocator, segment);
        if (findPublicParsedStructure(program.structures, path.items, 0)) |structure| {
            var items: std.ArrayList(CompletionItem) = .empty;
            for (structure.structures) |nested| {
                if (nested.member_visibility != .public_access or
                    !std.mem.startsWith(u8, nested.name, prefix) or self.containsCompletion(items.items, nested.name)) continue;
                try items.append(allocator, .{
                    .label = nested.name,
                    .kind = 7,
                    .detail = if (nested.is_static_class)
                        "Silex public nested static class"
                    else if (nested.is_class)
                        "Silex public nested class"
                    else
                        "Silex public nested struct",
                });
            }
            for (structure.fields) |field| {
                if (!field.is_static or field.visibility != .public_access or
                    !std.mem.startsWith(u8, field.name, prefix) or self.containsCompletion(items.items, field.name))
                {
                    continue;
                }
                try items.append(allocator, .{
                    .label = field.name,
                    .kind = 5,
                    .detail = "Silex public static field",
                });
            }
            for (structure.methods) |method| {
                if (!method.is_static or method.member_visibility != .public_access or
                    !std.mem.startsWith(u8, method.name, prefix)) continue;
                const candidate: CompletionItem = .{
                    .label = method.name,
                    .kind = 3,
                    .detail = try SymbolIndex.functionDetail(allocator, method),
                };
                if (self.containsEquivalentCompletion(items.items, candidate)) continue;
                try items.append(allocator, candidate);
            }
            return try items.toOwnedSlice(allocator);
        }
    }
    return null;
}

const CurrentLambdaParameter = struct {
    name: []const u8,
    type_name: []const u8,
};

const ActiveLambdaParameter = struct {
    value: CurrentLambdaParameter,
    scope_depth: usize,
};

fn appendCurrentLambdaParameter(
    allocator: Allocator,
    pending: *std.ArrayList(CurrentLambdaParameter),
    name: ?[]const u8,
    type_name: ?[]const u8,
) !void {
    if (name == null or type_name == null) return;
    try pending.append(allocator, .{ .name = name.?, .type_name = type_name.? });
}

fn currentLambdaParameters(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
) ![]const CurrentLambdaParameter {
    var lexer = LexerModule.Lexer.init(source);
    var active: std.ArrayList(ActiveLambdaParameter) = .empty;
    defer active.deinit(allocator);
    var pending: std.ArrayList(CurrentLambdaParameter) = .empty;
    defer pending.deinit(allocator);
    var brace_depth: usize = 0;
    var function_pending = false;
    var parsing_parameters = false;
    var parameter_depth: usize = 0;
    var awaiting_body = false;
    var parameter_name: ?[]const u8 = null;
    var parameter_type: ?[]const u8 = null;
    var after_colon = false;
    var type_segment_expected = false;

    while (true) {
        const token = lexer.next() catch break;
        if (token.tag == .end or token.start >= @min(cursor, source.len)) break;

        if (parsing_parameters) {
            switch (token.tag) {
                .left_parenthesis => parameter_depth += 1,
                .right_parenthesis => {
                    parameter_depth -|= 1;
                    if (parameter_depth == 0) {
                        try appendCurrentLambdaParameter(allocator, &pending, parameter_name, parameter_type);
                        parameter_name = null;
                        parameter_type = null;
                        after_colon = false;
                        type_segment_expected = false;
                        parsing_parameters = false;
                        awaiting_body = true;
                    }
                },
                .comma => if (parameter_depth == 1) {
                    try appendCurrentLambdaParameter(allocator, &pending, parameter_name, parameter_type);
                    parameter_name = null;
                    parameter_type = null;
                    after_colon = false;
                    type_segment_expected = false;
                },
                .colon => if (parameter_depth == 1 and parameter_name != null) {
                    after_colon = true;
                },
                .dot => if (parameter_depth == 1 and after_colon and parameter_type != null) {
                    type_segment_expected = true;
                },
                .identifier => if (parameter_depth == 1) {
                    if (parameter_name == null and !after_colon) {
                        parameter_name = token.lexeme;
                    } else if (after_colon and (parameter_type == null or type_segment_expected)) {
                        parameter_type = token.lexeme;
                        type_segment_expected = false;
                    }
                },
                else => if (parameter_depth == 1 and after_colon and parameter_type == null and
                    token.lexeme.len != 0 and std.ascii.isAlphabetic(token.lexeme[0]))
                {
                    parameter_type = token.lexeme;
                },
            }
            continue;
        }

        if (function_pending) {
            function_pending = false;
            if (token.tag == .left_parenthesis) {
                pending.clearRetainingCapacity();
                parsing_parameters = true;
                parameter_depth = 1;
                parameter_name = null;
                parameter_type = null;
                after_colon = false;
                type_segment_expected = false;
                continue;
            }
        }

        if (awaiting_body) switch (token.tag) {
            .equal, .comma, .right_parenthesis, .right_bracket, .semicolon => {
                awaiting_body = false;
                pending.clearRetainingCapacity();
            },
            else => {},
        };

        switch (token.tag) {
            .keyword_func => if (!awaiting_body) {
                function_pending = true;
            },
            .left_brace => {
                brace_depth += 1;
                if (awaiting_body) {
                    for (pending.items) |parameter| try active.append(allocator, .{
                        .value = parameter,
                        .scope_depth = brace_depth,
                    });
                    pending.clearRetainingCapacity();
                    awaiting_body = false;
                }
            },
            .right_brace => {
                var index = active.items.len;
                while (index > 0) {
                    index -= 1;
                    if (active.items[index].scope_depth == brace_depth) _ = active.orderedRemove(index);
                }
                brace_depth -|= 1;
            },
            else => {},
        }
    }

    const result = try allocator.alloc(CurrentLambdaParameter, active.items.len);
    for (active.items, result) |parameter, *destination| destination.* = parameter.value;
    return result;
}

pub fn currentLambdaParameterCompletionItems(
    self: anytype,
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
    prefix: []const u8,
) ![]const CompletionItem {
    const parameters = try currentLambdaParameters(allocator, source, cursor);
    defer allocator.free(parameters);
    var items: std.ArrayList(CompletionItem) = .empty;
    var index = parameters.len;
    while (index > 0) {
        index -= 1;
        const parameter = parameters[index];
        if (!std.mem.startsWith(u8, parameter.name, prefix) or self.containsCompletion(items.items, parameter.name)) continue;
        try items.append(allocator, .{
            .label = parameter.name,
            .kind = 6,
            .detail = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ parameter.name, parameter.type_name }),
        });
    }
    return items.toOwnedSlice(allocator);
}

pub fn currentLambdaParameterType(
    _: anytype,
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
    name: []const u8,
) !?[]const u8 {
    const parameters = try currentLambdaParameters(allocator, source, cursor);
    defer allocator.free(parameters);
    var index = parameters.len;
    while (index > 0) {
        index -= 1;
        if (std.mem.eql(u8, parameters[index].name, name)) return parameters[index].type_name;
    }
    return null;
}

const SelfCompletionScope = struct {
    opening: usize,
    depth: usize,
    name: []const u8,
    path: []const []const u8,
};

fn enclosingSelfCompletionScope(allocator: Allocator, source: []const u8, cursor: usize) !?SelfCompletionScope {
    var lexer = LexerModule.Lexer.init(source);
    var depth: usize = 0;
    var expects_structure_name = false;
    var pending_structure = false;
    var pending_structure_name: ?[]const u8 = null;
    var active_scopes: std.ArrayList(SelfCompletionScope) = .empty;

    while (true) {
        const token = lexer.next() catch return if (active_scopes.items.len == 0) null else active_scopes.items[active_scopes.items.len - 1];
        if (token.start >= @min(cursor, source.len)) return if (active_scopes.items.len == 0) null else active_scopes.items[active_scopes.items.len - 1];
        switch (token.tag) {
            .keyword_struct, .keyword_class => {
                expects_structure_name = true;
                pending_structure = false;
                pending_structure_name = null;
            },
            .identifier => {
                if (expects_structure_name) {
                    expects_structure_name = false;
                    pending_structure = true;
                    pending_structure_name = token.lexeme;
                }
            },
            .left_brace => {
                depth += 1;
                if (pending_structure) {
                    var path: std.ArrayList([]const u8) = .empty;
                    if (active_scopes.items.len != 0) try path.appendSlice(allocator, active_scopes.items[active_scopes.items.len - 1].path);
                    try path.append(allocator, pending_structure_name.?);
                    try active_scopes.append(allocator, .{
                        .opening = token.start,
                        .depth = depth,
                        .name = pending_structure_name.?,
                        .path = try path.toOwnedSlice(allocator),
                    });
                    pending_structure = false;
                    pending_structure_name = null;
                }
            },
            .right_brace => {
                if (active_scopes.items.len != 0 and active_scopes.items[active_scopes.items.len - 1].depth == depth) {
                    _ = active_scopes.pop();
                }
                depth -|= 1;
            },
            .end => return if (active_scopes.items.len == 0) null else active_scopes.items[active_scopes.items.len - 1],
            else => {},
        }
    }
}

const SelfMemberKind = enum { field, method };

pub fn currentSelfCompletionItems(
    self: anytype,
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
    prefix: []const u8,
) !?[]const CompletionItem {
    const scope = try enclosingSelfCompletionScope(allocator, source, cursor) orelse return null;
    const repaired = try self.blankLineAt(allocator, source, cursor);
    var parser = ParserModule.Parser.init(allocator, repaired);
    if (parser.parse() catch null) |program| {
        if (findParsedStructure(program.structures, scope.path, 0)) |structure| {
            var parsed_items: std.ArrayList(CompletionItem) = .empty;
            for (structure.fields) |field| {
                if (field.is_static or !std.mem.startsWith(u8, field.name, prefix) or
                    self.containsCompletion(parsed_items.items, field.name)) continue;
                try parsed_items.append(allocator, .{
                    .label = field.name,
                    .kind = 5,
                    .detail = "Silex instance field",
                });
            }
            for (structure.methods) |method| {
                if (method.is_static or !std.mem.startsWith(u8, method.name, prefix)) continue;
                const candidate: CompletionItem = .{
                    .label = method.name,
                    .kind = 3,
                    .detail = try SymbolIndex.functionDetail(allocator, method),
                };
                if (self.containsEquivalentCompletion(parsed_items.items, candidate)) continue;
                try parsed_items.append(allocator, candidate);
            }
            return try parsed_items.toOwnedSlice(allocator);
        }
    }

    var items: std.ArrayList(CompletionItem) = .empty;
    var lexer = LexerModule.Lexer.init(source);
    var depth: usize = 0;
    var inside_scope = false;
    var static_member = false;
    var expected_member: ?struct { kind: SelfMemberKind, is_static: bool } = null;

    while (true) {
        const token = lexer.next() catch break;
        if (token.tag == .left_brace) {
            depth += 1;
            if (token.start == scope.opening) inside_scope = true;
            continue;
        }
        if (token.tag == .right_brace) {
            if (inside_scope and depth == scope.depth) break;
            depth -|= 1;
            continue;
        }
        if (token.tag == .end) break;
        if (!inside_scope or depth != scope.depth) continue;

        if (expected_member) |expected| {
            expected_member = null;
            if (token.tag == .identifier and !expected.is_static and
                std.mem.startsWith(u8, token.lexeme, prefix) and
                !self.containsCompletion(items.items, token.lexeme))
            {
                try items.append(allocator, .{
                    .label = token.lexeme,
                    .kind = if (expected.kind == .field) 5 else 3,
                    .detail = if (expected.kind == .field)
                        "Silex instance field"
                    else
                        "Silex instance method",
                });
            }
            static_member = false;
            continue;
        }

        switch (token.tag) {
            .keyword_static => static_member = true,
            .keyword_let, .keyword_var => {
                expected_member = .{ .kind = .field, .is_static = static_member };
                static_member = false;
            },
            .keyword_func => {
                expected_member = .{ .kind = .method, .is_static = static_member };
                static_member = false;
            },
            .semicolon => static_member = false,
            else => {},
        }
    }
    return try items.toOwnedSlice(allocator);
}

fn findParsedStructure(
    structures: []const Ast.Structure,
    path: []const []const u8,
    index: usize,
) ?*const Ast.Structure {
    if (index >= path.len) return null;
    for (structures) |*structure| {
        if (!std.mem.eql(u8, structure.name, path[index])) continue;
        if (index + 1 == path.len) return structure;
        return findParsedStructure(structure.structures, path, index + 1);
    }
    return null;
}

const GenericTypeCompletionContext = struct {
    path: []const u8,
    prefix: []const u8,
};

pub fn genericTypeCompletionContext(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
) !?GenericTypeCompletionContext {
    var prefix_start = @min(cursor, source.len);
    while (prefix_start > 0 and std.ascii.isAlphanumeric(source[prefix_start - 1]) or
        prefix_start > 0 and source[prefix_start - 1] == '_')
    {
        prefix_start -= 1;
    }
    if (prefix_start == 0 or source[prefix_start - 1] != '.') return null;
    var end = prefix_start - 1;
    while (end > 0 and std.ascii.isWhitespace(source[end - 1])) end -= 1;
    var start = end;
    var depth: usize = 0;
    while (start > 0) {
        const character = source[start - 1];
        if (character == '>') {
            depth += 1;
            start -= 1;
            continue;
        }
        if (character == '<') {
            if (depth == 0) break;
            depth -= 1;
            start -= 1;
            continue;
        }
        if (depth != 0 or std.ascii.isAlphanumeric(character) or character == '_' or character == '.') {
            start -= 1;
            continue;
        }
        break;
    }
    if (depth != 0 or start == end) return null;

    var path: std.ArrayList(u8) = .empty;
    depth = 0;
    for (source[start..end]) |character| {
        if (character == '<') {
            depth += 1;
        } else if (character == '>') {
            depth -|= 1;
        } else if (depth == 0 and (std.ascii.isAlphanumeric(character) or character == '_' or character == '.')) {
            try path.append(allocator, character);
        }
    }
    if (path.items.len == 0) return null;
    return .{
        .path = try path.toOwnedSlice(allocator),
        .prefix = source[prefix_start..@min(cursor, source.len)],
    };
}

pub fn currentGenericTypeCompletionItems(
    self: anytype,
    allocator: Allocator,
    io: Io,
    uri: []const u8,
    source: []const u8,
    cursor: usize,
) !?[]const CompletionItem {
    const context = try genericTypeCompletionContext(allocator, source, cursor) orelse return null;
    const repaired = try self.blankLineAt(allocator, source, cursor);
    var parser = ParserModule.Parser.init(allocator, repaired);
    const program = parser.parse() catch return null;
    var segments: std.ArrayList([]const u8) = .empty;
    var iterator = std.mem.splitScalar(u8, context.path, '.');
    while (iterator.next()) |segment| try segments.append(allocator, segment);
    if (findParsedStructure(program.structures, segments.items, 0)) |structure| {
        const scope = try enclosingSelfCompletionScope(allocator, source, cursor);
        const same_family = scope != null and scope.?.path.len != 0 and segments.items.len != 0 and
            std.mem.eql(u8, scope.?.path[0], segments.items[0]);

        var items: std.ArrayList(CompletionItem) = .empty;
        for (structure.structures) |nested| {
            const visibility = nested.member_visibility orelse continue;
            if ((visibility == .private_access or visibility == .subclass) and !same_family) continue;
            try items.append(allocator, .{
                .label = nested.name,
                .kind = 7,
                .detail = if (nested.is_static_class)
                    "Silex nested static class"
                else if (nested.is_class)
                    "Silex nested class"
                else
                    "Silex nested struct",
            });
        }
        for (structure.fields) |field| {
            if (!field.is_static) continue;
            if ((field.visibility == .private_access or field.visibility == .subclass) and !same_family) continue;
            try items.append(allocator, .{
                .label = field.name,
                .kind = 5,
                .detail = "Silex static field",
            });
        }
        for (structure.methods) |method| {
            if (!method.is_static) continue;
            const visibility = method.member_visibility orelse continue;
            if ((visibility == .private_access or visibility == .subclass) and !same_family) continue;
            const candidate: CompletionItem = .{
                .label = method.name,
                .kind = 3,
                .detail = try SymbolIndex.functionDetail(allocator, method),
            };
            if (!self.containsEquivalentCompletion(items.items, candidate)) try items.append(allocator, candidate);
        }
        return try items.toOwnedSlice(allocator);
    }

    const root_name = segments.items[0];
    const target = self.visibleUseTarget(source, root_name) orelse return null;
    const separator = std.mem.lastIndexOfScalar(u8, target, '.') orelse return null;
    var resolved_path: std.ArrayList(u8) = .empty;
    try resolved_path.appendSlice(allocator, target[separator + 1 ..]);
    for (segments.items[1..]) |segment| {
        try resolved_path.append(allocator, '.');
        try resolved_path.appendSlice(allocator, segment);
    }
    const source_path = try self.filePathFromUri(allocator, uri) orelse return null;
    const project_root = std.fs.path.dirname(source_path) orelse return null;
    if (try staticCompletionItemsFromModule(
        self,
        allocator,
        io,
        project_root,
        target,
        resolved_path.items,
        context.prefix,
    )) |items| {
        if (items.len != 0) return items;
    }
    const fallback = try staticCompletionItemsFromModule(
        self,
        allocator,
        io,
        project_root,
        target[0..separator],
        resolved_path.items,
        context.prefix,
    );
    if (fallback) |items| if (items.len != 0) return items;
    return null;
}

fn findPublicParsedStructure(
    structures: []const Ast.Structure,
    path: []const []const u8,
    index: usize,
) ?*const Ast.Structure {
    if (index >= path.len) return null;
    for (structures) |*structure| {
        if (!std.mem.eql(u8, structure.name, path[index])) continue;
        if (index == 0) {
            if (!structure.is_public) return null;
        } else if (structure.member_visibility != .public_access) return null;
        if (index + 1 == path.len) return structure;
        return findPublicParsedStructure(structure.structures, path, index + 1);
    }
    return null;
}

pub fn collectRootModules(
    self: anytype,
    allocator: Allocator,
    io: Io,
    directory_path: []const u8,
    prefix: []const u8,
    detail: []const u8,
    items: *std.ArrayList(CompletionItem),
) !void {
    var directory = Io.Dir.cwd().openDir(io, directory_path, .{ .iterate = true }) catch return;
    defer directory.close(io);

    var child_directories: std.ArrayList([]const u8) = .empty;
    var source_stems: std.ArrayList([]const u8) = .empty;
    var iterator = directory.iterateAssumeFirstIteration();
    while (iterator.next(io) catch null) |entry| {
        if (entry.kind == .directory and ModuleDiscovery.isDirectoryName(entry.name)) {
            try child_directories.append(allocator, try allocator.dupe(u8, entry.name));
        } else if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".sx")) {
            const stem = entry.name[0 .. entry.name.len - ".sx".len];
            if (ModuleDiscovery.isModuleName(stem)) try source_stems.append(allocator, try allocator.dupe(u8, stem));
        }
    }

    for (child_directories.items) |child_name| {
        if (std.mem.startsWith(u8, child_name, prefix) and !self.containsCompletion(items.items, child_name)) {
            try items.append(allocator, .{
                .label = child_name,
                .kind = 9,
                .detail = detail,
                .insertText = child_name,
                .filterText = child_name,
            });
        }
    }

    for (source_stems.items) |stem| {
        const child_name = self.firstPathSegment(stem);
        if (std.mem.startsWith(u8, child_name, prefix) and !self.containsCompletion(items.items, child_name)) {
            try items.append(allocator, .{
                .label = child_name,
                .kind = 9,
                .detail = detail,
                .insertText = child_name,
                .filterText = child_name,
            });
        }
    }
}

pub fn filePathFromUri(self: anytype, allocator: Allocator, uri: []const u8) !?[]const u8 {
    const scheme = "file://";
    if (!std.mem.startsWith(u8, uri, scheme)) return null;
    const encoded = uri[scheme.len..];
    var path: std.ArrayList(u8) = .empty;
    var index: usize = 0;
    while (index < encoded.len) {
        if (encoded[index] == '%' and index + 2 < encoded.len) {
            const high = self.hexDigit(encoded[index + 1]) orelse return null;
            const low = self.hexDigit(encoded[index + 2]) orelse return null;
            try path.append(allocator, high * 16 + low);
            index += 3;
        } else {
            try path.append(allocator, encoded[index]);
            index += 1;
        }
    }
    return try path.toOwnedSlice(allocator);
}

pub fn documentProjectRoot(self: anytype, allocator: Allocator, uri: []const u8) !?[]const u8 {
    const source_path = try self.filePathFromUri(allocator, uri) orelse return null;
    return std.fs.path.dirname(source_path);
}

pub fn hexDigit(_: anytype, character: u8) ?u8 {
    return switch (character) {
        '0'...'9' => character - '0',
        'a'...'f' => character - 'a' + 10,
        'A'...'F' => character - 'A' + 10,
        else => null,
    };
}

pub fn byteOffsetAtPosition(self: anytype, source: []const u8, position: Position) ?usize {
    return self.byteOffsetAtEncodedPosition(source, position, .utf16);
}

pub fn normalizePosition(
    self: anytype,
    source: []const u8,
    position: ?Position,
    encoding: PositionEncoding,
) ?Position {
    const requested = position orelse return null;
    const offset = self.byteOffsetAtEncodedPosition(source, requested, encoding) orelse return null;
    return self.encodedPositionAtByteOffset(source, offset, .utf16);
}

pub fn byteOffsetAtEncodedPosition(
    self: anytype,
    source: []const u8,
    position: Position,
    encoding: PositionEncoding,
) ?usize {
    var offset: usize = 0;
    var line: usize = 0;
    while (line < position.line) : (line += 1) {
        const newline = std.mem.indexOfScalarPos(u8, source, offset, '\n') orelse return null;
        offset = newline + 1;
    }

    var units: usize = 0;
    while (offset < source.len and source[offset] != '\n' and units < position.character) {
        const sequence_length = self.utf8SequenceLength(source[offset]);
        units += switch (encoding) {
            .utf8 => sequence_length,
            .utf16 => if (sequence_length == 4) 2 else 1,
            .utf32 => 1,
        };
        offset += @min(sequence_length, source.len - offset);
    }
    return if (units == position.character) offset else null;
}

pub fn encodedPositionAtByteOffset(
    self: anytype,
    source: []const u8,
    requested_offset: usize,
    encoding: PositionEncoding,
) ?Position {
    if (requested_offset > source.len) return null;
    var position: Position = .{ .line = 0, .character = 0 };
    var offset: usize = 0;
    while (offset < requested_offset) {
        if (source[offset] == '\n') {
            position.line += 1;
            position.character = 0;
            offset += 1;
            continue;
        }
        const sequence_length = self.utf8SequenceLength(source[offset]);
        if (offset + sequence_length > requested_offset) return null;
        position.character += switch (encoding) {
            .utf8 => sequence_length,
            .utf16 => if (sequence_length == 4) 2 else 1,
            .utf32 => 1,
        };
        offset += sequence_length;
    }
    return position;
}

pub fn documentEndPosition(self: anytype, source: []const u8, encoding: PositionEncoding) Position {
    return self.encodedPositionAtByteOffset(source, source.len, encoding).?;
}

pub fn utf8SequenceLength(_: anytype, first_byte: u8) usize {
    if (first_byte & 0x80 == 0) return 1;
    if (first_byte & 0xe0 == 0xc0) return 2;
    if (first_byte & 0xf0 == 0xe0) return 3;
    if (first_byte & 0xf8 == 0xf0) return 4;
    return 1;
}

pub fn isIdentifierContinue(_: anytype, character: u8) bool {
    return std.ascii.isAlphanumeric(character) or character == '_';
}

pub fn containsCompletion(_: anytype, items: []const CompletionItem, label: []const u8) bool {
    for (items) |item| if (std.mem.eql(u8, item.label, label)) return true;
    return false;
}

pub fn containsEquivalentCompletion(_: anytype, items: []const CompletionItem, candidate: CompletionItem) bool {
    const callable = candidate.kind == 3 or candidate.kind == 4;
    for (items) |item| {
        if (!std.mem.eql(u8, item.label, candidate.label)) continue;
        if (!callable or (item.kind != 3 and item.kind != 4)) return true;
        if (std.mem.eql(u8, item.detail, candidate.detail)) return true;
    }
    return false;
}

pub fn expectSemanticTokenAt(
    self: anytype,
    source: []const u8,
    data: []const u32,
    byte_offset: usize,
    byte_length: usize,
    expected: SemanticTokenKind,
) !void {
    const requested = self.encodedPositionAtByteOffset(source, byte_offset, .utf16) orelse
        return error.TestUnexpectedResult;
    const requested_end = self.encodedPositionAtByteOffset(source, byte_offset + byte_length, .utf16) orelse
        return error.TestUnexpectedResult;
    var line: usize = 0;
    var start: usize = 0;
    var index: usize = 0;
    while (index + 4 < data.len) : (index += 5) {
        const delta_line: usize = data[index];
        line += delta_line;
        start = if (delta_line == 0) start + data[index + 1] else data[index + 1];
        if (line != requested.line or start != requested.character) continue;
        try std.testing.expectEqual(requested_end.character - requested.character, data[index + 2]);
        try std.testing.expectEqual(@intFromEnum(expected), data[index + 3]);
        return;
    }
    return error.TestUnexpectedResult;
}

pub const language_completions = [_]CompletionItem{
    .{ .label = "func", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "struct", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "class", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "protocol", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "extend", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "enum", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "init", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "drop", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "super", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "override", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "static", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "assert", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "panic", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "let", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "var", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "if", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "elif", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "else", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "while", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "mutex", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "match", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "return", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "try", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "move", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "deferred", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "use", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "private", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "internal", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "protected", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "public", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "as", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "self", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "true", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "false", .kind = 14, .detail = "Silex keyword" },
    .{ .label = "print", .kind = 3, .detail = "Silex builtin" },
    .{ .label = "map_error", .kind = 3, .detail = "Silex intrinsic function" },
    .{ .label = "dispatch_callbacks", .kind = 3, .detail = "Silex intrinsic function" },
    .{ .label = "Result", .kind = 7, .detail = "Silex intrinsic type" },
    .{ .label = "void", .kind = 7, .detail = "Silex type" },
    .{ .label = "bool", .kind = 7, .detail = "Silex type" },
    .{ .label = "int", .kind = 7, .detail = "Silex type" },
    .{ .label = "int8", .kind = 7, .detail = "Silex type" },
    .{ .label = "int16", .kind = 7, .detail = "Silex type" },
    .{ .label = "int32", .kind = 7, .detail = "Silex type" },
    .{ .label = "int64", .kind = 7, .detail = "Silex type" },
    .{ .label = "uint", .kind = 7, .detail = "Silex type" },
    .{ .label = "uint8", .kind = 7, .detail = "Silex type" },
    .{ .label = "uint16", .kind = 7, .detail = "Silex type" },
    .{ .label = "uint32", .kind = 7, .detail = "Silex type" },
    .{ .label = "uint64", .kind = 7, .detail = "Silex type" },
    .{ .label = "float", .kind = 7, .detail = "Silex type" },
    .{ .label = "float32", .kind = 7, .detail = "Silex type" },
    .{ .label = "float64", .kind = 7, .detail = "Silex type" },
    .{ .label = "str", .kind = 7, .detail = "Silex type" },
};
