const std = @import("std");
const Allocator = std.mem.Allocator;

/// An explicit replacement of an external closure anchor, not an equivalence
/// claim. The original revision and its sealed sources remain authoritative.
pub const Reconciliation = struct {
    candidate_revision: []const u8,
    common_ancestor: []const u8,
    historical_tree: []const u8,
    candidate_tree: []const u8,
    delta_sha256: []const u8,
    reason: []const u8,
};

pub fn audit(repository: []const u8, original: []const u8, record: Reconciliation) !void {
    if (std.mem.eql(u8, repository, "Silex") or record.reason.len == 0 or
        std.mem.eql(u8, original, record.candidate_revision)) return error.InvalidReconciliation;
    for ([_][]const u8{ record.candidate_revision, record.common_ancestor, record.historical_tree, record.candidate_tree }) |value|
        if (!hex(value, 40)) return error.InvalidReconciliation;
    if (!hex(record.delta_sha256, 64)) return error.InvalidReconciliation;
}

pub fn validate(
    allocator: Allocator,
    io: std.Io,
    root: []const u8,
    original: []const u8,
    record: Reconciliation,
) !void {
    try ancestor(allocator, io, root, record.candidate_revision);
    const common = try command(allocator, io, root, &.{ "merge-base", original, record.candidate_revision });
    if (!std.mem.eql(u8, std.mem.trim(u8, common, "\r\n"), record.common_ancestor))
        return error.ReconciliationAncestorMismatch;
    try tree(allocator, io, root, original, record.historical_tree);
    try tree(allocator, io, root, record.candidate_revision, record.candidate_tree);
    const delta = try command(allocator, io, root, &.{
        "diff",            "--no-ext-diff",   "--no-textconv",          "--no-color",            "--no-renames", "--full-index", "--binary",
        "--src-prefix=a/", "--dst-prefix=b/", "--diff-algorithm=myers", "--no-indent-heuristic", "--unified=3",  original,       record.candidate_revision,
        "--",
    });
    if (!std.mem.eql(u8, &sha256(delta), record.delta_sha256)) return error.ReconciliationDeltaMismatch;
}

pub fn ancestor(allocator: Allocator, io: std.Io, root: []const u8, revision: []const u8) !void {
    _ = try command(allocator, io, root, &.{ "merge-base", "--is-ancestor", revision, "HEAD" });
}

pub fn source(
    allocator: Allocator,
    io: std.Io,
    root: []const u8,
    revision: []const u8,
    path: []const u8,
    expected: []const u8,
) !void {
    const object = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ revision, path });
    const bytes = try command(allocator, io, root, &.{ "show", object });
    if (!std.mem.eql(u8, &sha256(bytes), expected)) return error.HistoricalProofSourceMismatch;
}

fn tree(allocator: Allocator, io: std.Io, root: []const u8, revision: []const u8, expected: []const u8) !void {
    const object = try std.fmt.allocPrint(allocator, "{s}^{{tree}}", .{revision});
    const actual = try command(allocator, io, root, &.{ "rev-parse", object });
    if (!std.mem.eql(u8, std.mem.trim(u8, actual, "\r\n"), expected)) return error.ReconciliationTreeMismatch;
}

fn command(allocator: Allocator, io: std.Io, root: []const u8, args: []const []const u8) ![]const u8 {
    const argv = try std.mem.concat(allocator, []const u8, &.{ &.{ "git", "-C", root }, args });
    const result = try std.process.run(allocator, io, .{
        .argv = argv,
        .stdout_limit = .limited(16 * 1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
    });
    if (result.term != .exited or result.term.exited != 0) return error.UnavailableQualificationHistory;
    return result.stdout;
}

fn sha256(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

fn hex(value: []const u8, length: usize) bool {
    if (value.len != length) return false;
    for (value) |byte| if (!std.ascii.isHex(byte)) return false;
    return true;
}

test "reconciliation binds divergent history and historical source independently of current bytes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const io = std.testing.io;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const relative = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root = try std.Io.Dir.cwd().realPathFileAlloc(io, relative, allocator);
    _ = try command(allocator, io, root, &.{ "init", "-b", "main" });
    try temporary.dir.writeFile(io, .{ .sub_path = "Source.sx", .data = "base\n" });
    try commit(allocator, io, root);
    const base = std.mem.trim(u8, try command(allocator, io, root, &.{ "rev-parse", "HEAD" }), "\r\n");
    _ = try command(allocator, io, root, &.{ "checkout", "-b", "historical" });
    try temporary.dir.writeFile(io, .{ .sub_path = "Source.sx", .data = "historical\n" });
    try commit(allocator, io, root);
    const original = std.mem.trim(u8, try command(allocator, io, root, &.{ "rev-parse", "HEAD" }), "\r\n");
    const old_tree = std.mem.trim(u8, try command(allocator, io, root, &.{ "rev-parse", "HEAD^{tree}" }), "\r\n");
    _ = try command(allocator, io, root, &.{ "checkout", "main" });
    try temporary.dir.writeFile(io, .{ .sub_path = "Source.sx", .data = "candidate\n" });
    try commit(allocator, io, root);
    const candidate = std.mem.trim(u8, try command(allocator, io, root, &.{ "rev-parse", "HEAD" }), "\r\n");
    const new_tree = std.mem.trim(u8, try command(allocator, io, root, &.{ "rev-parse", "HEAD^{tree}" }), "\r\n");
    const delta = try command(allocator, io, root, &.{
        "diff",            "--no-ext-diff",   "--no-textconv",          "--no-color",            "--no-renames", "--full-index", "--binary",
        "--src-prefix=a/", "--dst-prefix=b/", "--diff-algorithm=myers", "--no-indent-heuristic", "--unified=3",  original,       candidate,
        "--",
    });
    const digest = sha256(delta);
    const record: Reconciliation = .{
        .candidate_revision = candidate,
        .common_ancestor = base,
        .historical_tree = old_tree,
        .candidate_tree = new_tree,
        .delta_sha256 = &digest,
        .reason = "Explicitly reviewed external API delta",
    };
    try audit("Packages/Example", original, record);
    try validate(allocator, io, root, original, record);
    try std.testing.expectError(error.UnavailableQualificationHistory, ancestor(allocator, io, root, original));
    try source(allocator, io, root, original, "Source.sx", &sha256("historical\n"));
    try std.testing.expectError(error.HistoricalProofSourceMismatch, source(allocator, io, root, original, "Source.sx", &sha256("candidate\n")));
    try std.testing.expectError(error.InvalidReconciliation, audit("Silex", original, record));
    var invalid = record;
    invalid.candidate_revision = original;
    try std.testing.expectError(error.UnavailableQualificationHistory, validate(allocator, io, root, original, invalid));
    invalid = record;
    invalid.common_ancestor = candidate;
    try std.testing.expectError(error.ReconciliationAncestorMismatch, validate(allocator, io, root, original, invalid));
    invalid = record;
    invalid.historical_tree = new_tree;
    try std.testing.expectError(error.ReconciliationTreeMismatch, validate(allocator, io, root, original, invalid));
    invalid = record;
    invalid.candidate_tree = old_tree;
    try std.testing.expectError(error.ReconciliationTreeMismatch, validate(allocator, io, root, original, invalid));
    invalid = record;
    invalid.delta_sha256 = &sha256("unreviewed delta");
    try std.testing.expectError(error.ReconciliationDeltaMismatch, validate(allocator, io, root, original, invalid));
}

fn commit(allocator: Allocator, io: std.Io, root: []const u8) !void {
    _ = try command(allocator, io, root, &.{ "add", "Source.sx" });
    _ = try command(allocator, io, root, &.{
        "-c",     "user.name=Oracle test", "-c",      "user.email=oracle@example.invalid",
        "-c",     "commit.gpgsign=false",  "-c",      "core.hooksPath=/dev/null",
        "commit", "-m",                    "Fixture",
    });
}
