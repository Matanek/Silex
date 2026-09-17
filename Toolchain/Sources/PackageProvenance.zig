const std = @import("std");
const Descriptor = @import("PackageDescriptor.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

fn ownerCharacter(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '-';
}
fn repoCharacter(byte: u8) bool {
    return ownerCharacter(byte) or byte == '_' or byte == '.';
}

pub fn repository(allocator: Allocator, raw: []const u8) ![]const u8 {
    const remote = std.mem.trim(u8, raw, " \t\r\n");
    const path = if (std.mem.startsWith(u8, remote, "git@github.com:"))
        remote["git@github.com:".len..]
    else if (std.mem.startsWith(u8, remote, "ssh://git@github.com/"))
        remote["ssh://git@github.com/".len..]
    else if (std.mem.startsWith(u8, remote, "https://github.com/"))
        remote["https://github.com/".len..]
    else
        return error.InvalidPackageProvenance;
    const slug = if (std.mem.endsWith(u8, path, ".git")) path[0 .. path.len - 4] else path;
    const slash = std.mem.indexOfScalar(u8, slug, '/') orelse return error.InvalidPackageProvenance;
    const owner = slug[0..slash];
    const name = slug[slash + 1 ..];
    if (owner.len < 1 or owner.len > 39 or name.len < 1 or name.len > 100 or
        std.mem.indexOfScalar(u8, name, '/') != null or std.mem.eql(u8, name, ".") or
        std.mem.eql(u8, name, "..") or std.mem.endsWith(u8, name, ".git")) return error.InvalidPackageProvenance;
    for (owner) |byte| if (!ownerCharacter(byte)) return error.InvalidPackageProvenance;
    for (name) |byte| if (!repoCharacter(byte)) return error.InvalidPackageProvenance;
    return std.fmt.allocPrint(allocator, "https://github.com/{s}/{s}.git", .{ owner, name });
}

fn git(allocator: Allocator, io: Io, root: []const u8, arguments: []const []const u8) ![]const u8 {
    var argv: std.ArrayList([]const u8) = .empty;
    try argv.appendSlice(allocator, &.{ "git", "-C", root });
    try argv.appendSlice(allocator, arguments);
    const result = std.process.run(allocator, io, .{
        .argv = argv.items,
        .stdout_limit = .limited(512),
        .stderr_limit = .limited(1024),
    }) catch return error.InvalidPackageProvenance;
    defer allocator.free(result.stderr);
    if (switch (result.term) { .exited => |code| code != 0, else => true }) {
        allocator.free(result.stdout);
        return error.InvalidPackageProvenance;
    }
    return result.stdout;
}

pub fn inspect(allocator: Allocator, io: Io, root: []const u8) !Descriptor.Provenance {
    const remote = try git(allocator, io, root, &.{ "remote", "get-url", "origin" });
    defer allocator.free(remote);
    const public_repository = try repository(allocator, remote);
    const head = try git(allocator, io, root, &.{ "rev-parse", "--verify", "HEAD" });
    defer allocator.free(head);
    const commit = std.mem.trim(u8, head, " \t\r\n");
    if (commit.len != 40) return error.InvalidPackageProvenance;
    for (commit) |byte| if (!std.ascii.isDigit(byte) and (byte < 'a' or byte > 'f')) return error.InvalidPackageProvenance;
    return .{ .repository = public_repository, .commit = try allocator.dupe(u8, commit) };
}

test "canonical GitHub origins and malformed remotes" {
    const allocator = std.testing.allocator;
    const canonical = try repository(allocator, "git@github.com:Matanek/Silex-Registry.git\n");
    defer allocator.free(canonical);
    try std.testing.expectEqualStrings("https://github.com/Matanek/Silex-Registry.git",
        canonical);
    try std.testing.expectError(error.InvalidPackageProvenance, repository(allocator, "https://example.org/Matanek/Silex-Registry.git"));
    try std.testing.expectError(error.InvalidPackageProvenance, repository(allocator, "https://github.com/Matanek/a/b.git"));
}
