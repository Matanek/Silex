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
    fingerprint: u64 = 0,
    counts: [std.meta.fields(Signal).len]usize = [_]usize{0} ** std.meta.fields(Signal).len,

    pub fn count(self: Report, signal: Signal) usize {
        return self.counts[@intFromEnum(signal)];
    }
};

const corpus_roots = [_][]const u8{ "Silex", "Silex-Examples", "Packages", "Sandbox" };

pub fn auditWorkspace(allocator: Allocator, io: Io, workspace_root: []const u8) !Report {
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
        try classifySource(&report, source);
    }
    report.fingerprint = fingerprint.final();
    return report;
}

pub fn requireRepresentative(report: Report) !void {
    inline for (std.meta.fields(Signal)) |field| {
        const signal: Signal = @enumFromInt(field.value);
        if (report.count(signal) == 0) return error.MissingCorpusSignal;
    }
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

fn classifySource(report: *Report, source: []const u8) !void {
    var lexer = Lexer.init(source);
    while (true) {
        const token = try lexer.next();
        switch (token.tag) {
            .keyword_use => increment(report, .use_path),
            .dot => increment(report, .member_or_qualified_path),
            .dot_dot => increment(report, .cascade),
            .question_dot => increment(report, .safe_member),
            .left_parenthesis => increment(report, .parenthesized_site),
            .less => increment(report, .generic_or_comparison),
            .colon => increment(report, .label_or_type_annotation),
            .left_bracket => increment(report, .indexed_or_collection_site),
            .interpolation_start => increment(report, .interpolation),
            .keyword_extend => increment(report, .extension),
            .keyword_contribute => increment(report, .contribution),
            .keyword_as => increment(report, .alias),
            .keyword_public => increment(report, .public_visibility),
            .keyword_package => increment(report, .package_visibility),
            .keyword_module => increment(report, .module_visibility),
            .keyword_local => increment(report, .local_visibility),
            .keyword_protected => increment(report, .protected_visibility),
            .keyword_private => increment(report, .private_visibility),
            .end => return,
            else => {},
        }
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
    const first = try auditWorkspace(arena.allocator(), std.testing.io, root);
    const repeated = try auditWorkspace(arena.allocator(), std.testing.io, root);
    try std.testing.expectEqual(first, repeated);
    try requireRepresentative(first);

    var missing = first;
    missing.counts[@intFromEnum(Signal.cascade)] = 0;
    try std.testing.expectError(error.MissingCorpusSignal, requireRepresentative(missing));
}
