const std = @import("std");
const Lexer = @import("../Lexer.zig").Lexer;

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Signal = enum {
    use_path,
    member_or_qualified_path,
    cascade,
    safe_member,
    parenthesized_site,
    generic_or_comparison,
    label_or_type_annotation,
    indexed_or_collection_site,
    interpolation,
    extension,
    contribution,
    alias,
    public_visibility,
    package_visibility,
    module_visibility,
    local_visibility,
    protected_visibility,
    private_visibility,
};

pub const Report = struct {
    source_files: usize = 0,
    source_bytes: usize = 0,
    choice_sites: usize = 0,
    mapped_sites: usize = 0,
    fingerprint: u64 = 0,
    counts: [std.meta.fields(Signal).len]usize = [_]usize{0} ** std.meta.fields(Signal).len,

    pub fn count(self: Report, signal: Signal) usize {
        return self.counts[@intFromEnum(signal)];
    }
};

pub const ProofMapping = struct {
    signal: Signal,
    scenario: []const u8,
};

pub const SourceRecord = struct {
    path: []const u8,
    bytes: usize,
    first_site: usize,
    site_count: usize,
};

pub const Site = struct {
    path: []const u8,
    line: usize,
    column: usize,
    offset: usize,
    signal: Signal,
    scenario: []const u8,
};

pub const Inventory = struct {
    report: Report,
    sources: []const SourceRecord,
    sites: []const Site,
};

pub const proof_mappings = [_]ProofMapping{
    .{ .signal = .use_path, .scenario = "use-path-qualified" },
    .{ .signal = .member_or_qualified_path, .scenario = "member-local-incomplete-if" },
    .{ .signal = .cascade, .scenario = "cascade-local-incomplete" },
    .{ .signal = .safe_member, .scenario = "member-optional-safe-access" },
    .{ .signal = .parenthesized_site, .scenario = "call-argument-expression" },
    .{ .signal = .generic_or_comparison, .scenario = "member-specialized-generic" },
    .{ .signal = .label_or_type_annotation, .scenario = "call-label-middle" },
    .{ .signal = .indexed_or_collection_site, .scenario = "lexical-query-destructuring" },
    .{ .signal = .interpolation, .scenario = "editing-interpolation-expression" },
    .{ .signal = .extension, .scenario = "member-local-extension" },
    .{ .signal = .contribution, .scenario = "topology-catalog-fragment-field-chain" },
    .{ .signal = .alias, .scenario = "member-imported-alias" },
    .{ .signal = .public_visibility, .scenario = "visibility-imported-private-negative" },
    .{ .signal = .package_visibility, .scenario = "visibility-package-member" },
    .{ .signal = .module_visibility, .scenario = "visibility-module-member" },
    .{ .signal = .local_visibility, .scenario = "visibility-local-member" },
    .{ .signal = .protected_visibility, .scenario = "visibility-protected-member" },
    .{ .signal = .private_visibility, .scenario = "visibility-imported-private-negative" },
};

const corpus_roots = [_][]const u8{ "Silex", "Silex-Examples", "Packages", "Sandbox" };

pub fn auditWorkspace(allocator: Allocator, io: Io, workspace_root: []const u8) !Report {
    return (try inventoryWorkspace(allocator, io, workspace_root)).report;
}

pub fn inventoryWorkspace(allocator: Allocator, io: Io, workspace_root: []const u8) !Inventory {
    var paths: std.ArrayList([]const u8) = .empty;
    for (corpus_roots) |relative_root| {
        const full_root = try std.fs.path.join(allocator, &.{ workspace_root, relative_root });
        var directory = Io.Dir.cwd().openDir(io, full_root, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer directory.close(io);
        var walker = try directory.walk(allocator);
        defer walker.deinit();
        while (try walker.next(io)) |entry| {
            if (entry.kind == .directory and ignoredDirectory(entry.basename)) {
                walker.leave(io);
                continue;
            }
            if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".sx")) continue;
            try paths.append(allocator, try std.fs.path.join(allocator, &.{ relative_root, entry.path }));
        }
    }
    if (paths.items.len == 0) return error.EmptyCompletionCorpus;
    std.mem.sort([]const u8, paths.items, {}, lessThan);

    var report: Report = .{};
    var sources: std.ArrayList(SourceRecord) = .empty;
    var sites: std.ArrayList(Site) = .empty;
    var fingerprint = std.hash.Wyhash.init(0);
    for (paths.items) |relative_path| {
        const full_path = try std.fs.path.join(allocator, &.{ workspace_root, relative_path });
        const source = try Io.Dir.cwd().readFileAlloc(io, full_path, allocator, .limited(16 * 1024 * 1024));
        report.source_files += 1;
        report.source_bytes += source.len;
        fingerprint.update(relative_path);
        fingerprint.update(&.{0});
        fingerprint.update(source);
        fingerprint.update(&.{0});
        const first_site = sites.items.len;
        try classifySource(allocator, &report, &sites, relative_path, source);
        try sources.append(allocator, .{
            .path = relative_path,
            .bytes = source.len,
            .first_site = first_site,
            .site_count = sites.items.len - first_site,
        });
    }
    report.fingerprint = fingerprint.final();
    return .{
        .report = report,
        .sources = try sources.toOwnedSlice(allocator),
        .sites = try sites.toOwnedSlice(allocator),
    };
}

pub fn requireRepresentative(report: Report) !void {
    if (report.choice_sites == 0 or report.choice_sites != report.mapped_sites) {
        return error.UnmappedCorpusSite;
    }
    inline for (std.meta.fields(Signal)) |field| {
        const signal: Signal = @enumFromInt(field.value);
        if (report.count(signal) == 0) return error.MissingCorpusSignal;
    }
}

pub fn proofForSignal(signal: Signal) []const u8 {
    for (proof_mappings) |mapping| if (mapping.signal == signal) return mapping.scenario;
    unreachable;
}

pub fn signalName(signal: Signal) []const u8 {
    return switch (signal) {
        .use_path => "use_path",
        .member_or_qualified_path => "member_or_qualified_path",
        .cascade => "cascade",
        .safe_member => "safe_member",
        .parenthesized_site => "parenthesized_site",
        .generic_or_comparison => "generic_or_comparison",
        .label_or_type_annotation => "label_or_type_annotation",
        .indexed_or_collection_site => "indexed_or_collection_site",
        .interpolation => "interpolation",
        .extension => "extension",
        .contribution => "contribution",
        .alias => "alias",
        .public_visibility => "public_visibility",
        .package_visibility => "package_visibility",
        .module_visibility => "module_visibility",
        .local_visibility => "local_visibility",
        .protected_visibility => "protected_visibility",
        .private_visibility => "private_visibility",
    };
}

fn classifySource(
    allocator: Allocator,
    report: *Report,
    sites: *std.ArrayList(Site),
    relative_path: []const u8,
    source: []const u8,
) !void {
    var lexer = Lexer.init(source);
    while (true) {
        const token = try lexer.next();
        const signal: Signal = switch (token.tag) {
            .keyword_use => .use_path,
            .dot => .member_or_qualified_path,
            .dot_dot => .cascade,
            .question_dot => .safe_member,
            .left_parenthesis => .parenthesized_site,
            .less => .generic_or_comparison,
            .colon => .label_or_type_annotation,
            .left_bracket => .indexed_or_collection_site,
            .interpolation_start => .interpolation,
            .keyword_extend => .extension,
            .keyword_contribute => .contribution,
            .keyword_as => .alias,
            .keyword_public => .public_visibility,
            .keyword_package => .package_visibility,
            .keyword_module => .module_visibility,
            .keyword_local => .local_visibility,
            .keyword_protected => .protected_visibility,
            .keyword_private => .private_visibility,
            .end => return,
            else => continue,
        };
        increment(report, signal);
        const scenario = proofForSignal(signal);
        // The list owns only records; paths and proof identifiers are owned by
        // the caller's arena or static storage.
        try sites.append(allocator, .{
            .path = relative_path,
            .line = token.position.line,
            .column = token.position.column,
            .offset = token.position.offset,
            .signal = signal,
            .scenario = scenario,
        });
        report.choice_sites += 1;
        report.mapped_sites += 1;
    }
}

fn increment(report: *Report, signal: Signal) void {
    report.counts[@intFromEnum(signal)] += 1;
}

fn ignoredDirectory(name: []const u8) bool {
    const ignored = [_][]const u8{
        ".git",
        ".zig-cache",
        ".specs",
        ".archives",
        "zig-out",
        "node_modules",
        "Vendors",
    };
    for (ignored) |candidate| if (std.mem.eql(u8, name, candidate)) return true;
    return false;
}

fn lessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}

test "corpus audit is deterministic and its representative gate detects omissions" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Packages/Fixture");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Packages/Fixture/All.sx",
        .data =
        \\public class Surface<T> {
        \\    package var shared:int
        \\    module var same_module:int
        \\    local var same_file:int
        \\    protected var inherited:int
        \\    private var hidden:int
        \\}
        \\use Api.Surface as Alias
        \\extend Surface<int> { func inspect() { print("$(self.shared)") } }
        \\contribute Api.Catalog { public use Api.Surface.Surface as Surface }
        \\func probe(value:?Surface<int>, values:[Surface<int>]) {
        \\    value?.inspect()
        \\    values[0]..shared = 1
        \\}
        ,
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const root = try std.fs.path.join(arena.allocator(), &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const inventory = try inventoryWorkspace(arena.allocator(), std.testing.io, root);
    const first = inventory.report;
    const repeated = try auditWorkspace(arena.allocator(), std.testing.io, root);
    try std.testing.expectEqual(first, repeated);
    try requireRepresentative(first);
    try std.testing.expectEqual(@as(usize, 1), inventory.sources.len);
    try std.testing.expectEqual(first.choice_sites, inventory.sites.len);
    try std.testing.expectEqual(first.choice_sites, inventory.sources[0].site_count);
    for (inventory.sites) |site| {
        try std.testing.expectEqualStrings(inventory.sources[0].path, site.path);
        try std.testing.expectEqualStrings(proofForSignal(site.signal), site.scenario);
        try std.testing.expect(site.line > 0);
        try std.testing.expect(site.column > 0);
    }

    var missing = first;
    missing.counts[@intFromEnum(Signal.cascade)] = 0;
    try std.testing.expectError(error.MissingCorpusSignal, requireRepresentative(missing));
    var unmapped = first;
    unmapped.mapped_sites -= 1;
    try std.testing.expectError(error.UnmappedCorpusSite, requireRepresentative(unmapped));
}
