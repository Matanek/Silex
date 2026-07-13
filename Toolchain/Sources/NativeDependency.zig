const std = @import("std");
const TargetModule = @import("Target.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Dependency = struct {
    name: []const u8,
    manifest_path: []const u8,
    sources: []const []const u8,
    targets: []const []const u8,

    pub fn supports(self: Dependency, allocator: Allocator, target: TargetModule.Target) !bool {
        const target_name = try target.cacheName(allocator);
        for (self.targets) |supported_target| {
            if (std.mem.eql(u8, supported_target, target_name)) return true;
        }
        return false;
    }
};

const Manifest = struct {
    name: []const u8,
    sources: []const []const u8,
    targets: []const []const u8,
};

pub fn load(allocator: Allocator, io: Io, manifest_path: []const u8) !Dependency {
    const contents = try Io.Dir.cwd().readFileAlloc(io, manifest_path, allocator, .limited(1024 * 1024));
    const manifest = try std.json.parseFromSliceLeaky(Manifest, allocator, contents, .{
        .allocate = .alloc_always,
    });
    if (manifest.name.len == 0 or manifest.sources.len == 0 or manifest.targets.len == 0) {
        return error.IncompleteNativeDependency;
    }

    const manifest_dir = std.fs.path.dirname(manifest_path) orelse ".";
    const sources = try allocator.alloc([]const u8, manifest.sources.len);
    for (manifest.sources, 0..) |source, index| {
        sources[index] = try std.fs.path.join(allocator, &.{ manifest_dir, source });
    }

    return .{
        .name = manifest.name,
        .manifest_path = manifest_path,
        .sources = sources,
        .targets = manifest.targets,
    };
}

test "dependency declares supported targets" {
    const dependency: Dependency = .{
        .name = "example",
        .manifest_path = "example.json",
        .sources = &.{"example.cpp"},
        .targets = &.{"x86_64-linux-musl"},
    };
    const target = try TargetModule.Target.parse(std.testing.allocator, std.testing.io, "x86_64-linux-musl");
    defer std.testing.allocator.free(target.zig_triple.?);

    try std.testing.expect(try dependency.supports(std.testing.allocator, target));
    try std.testing.expect(!try dependency.supports(std.testing.allocator, TargetModule.Target.native()));
}
