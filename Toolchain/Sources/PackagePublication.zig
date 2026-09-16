const std = @import("std");
const Archive = @import("PackageArchive.zig");
const Descriptor = @import("PackageDescriptor.zig");
const Inventory = @import("PackageInventory.zig");
const Packages = @import("Packages.zig");
const Project = @import("Project.zig");
const Resources = @import("PackageResources.zig");
const Snapshot = @import("PackageSnapshot.zig");
const TargetModule = @import("Target.zig");

const Io = std.Io;

pub const Prepared = struct {
    name: []const u8,
    version: Packages.Version,
    files: []const Archive.File,
    source: []const u8,
    descriptor: Descriptor.Result,
};

pub const Manager = struct {
    allocator: std.mem.Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    diagnostic: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator, io: Io, global_packages_root: ?[]const u8) Manager {
        return .{ .allocator = allocator, .io = io, .global_packages_root = global_packages_root };
    }

    /// Prepare exactly one immutable source publication. Network transfer and
    /// credentials are deliberately outside this operation, so `--dry-run`
    /// exercises the same manifest, compiler, snapshot and descriptor path.
    pub fn prepare(self: *Manager, package_root: []const u8) !Prepared {
        self.diagnostic = null;
        const host = TargetModule.Target.host() orelse TargetModule.Target.macos_arm64;
        var resolver = Packages.Resolver.initForTarget(self.allocator, self.io, self.global_packages_root, host);
        const manifest = resolver.inspectPackage(package_root) catch |err| switch (err) {
            error.InvalidPackageGraph => return self.fail(resolver.diagnostic orelse "invalid package manifest"),
            else => |other| return other,
        };
        const sources = Inventory.collectSources(self.allocator, self.io, package_root, manifest.sources) catch {
            return self.fail("package source inventory is unsafe or cannot be read");
        };
        var uses: std.ArrayList(@import("EmbeddedFiles.zig").Use) = .empty;
        for (sources) |relative| {
            const source_path = try std.fs.path.join(self.allocator, &.{ package_root, relative });
            var compiler = Project.Compiler.initWithPackages(self.allocator, self.io, self.global_packages_root);
            compiler.target = targetForSource(relative, host) catch return self.fail("package source uses an unsupported Platform or Target variant");
            const compilation = compiler.compileTests(source_path) catch |err| switch (err) {
                error.InvalidSource, error.InvalidPackageGraph => return self.fail(compiler.diagnosticMessage() orelse "package source does not compile"),
                else => |other| return other,
            };
            try uses.appendSlice(self.allocator, compilation.embedded_file_uses);
        }
        const resources = Resources.select(self.allocator, package_root, uses.items) catch |err| switch (err) {
            error.ResourceOutsidePackage => return self.fail("a package source embeds a file outside the package"),
            else => |other| return other,
        };

        var selected: std.ArrayList([]const u8) = .empty;
        try appendUnique(self.allocator, &selected, "Package.json");
        for (sources) |path| try appendUnique(self.allocator, &selected, path);
        for (resources) |path| try appendUnique(self.allocator, &selected, path);
        for ([_][]const u8{ "README.md", "README", "LICENSE", "LICENSE.md", "NOTICE" }) |name| {
            if (try optionalRegularFile(self.allocator, self.io, package_root, name)) try appendUnique(self.allocator, &selected, name);
        }
        const files = Snapshot.captureSelected(self.allocator, self.io, package_root, selected.items) catch |err| switch (err) {
            error.MissingFile => return self.fail("a selected package file disappeared during preparation"),
            error.FileChanged => return self.fail("a selected package file changed during preparation"),
            error.UnsafeEntry => return self.fail("a selected package entry is a link or is not a regular file"),
            else => |other| return other,
        };
        const source = try Archive.encode(self.allocator, files);
        const descriptor = try Descriptor.render(self.allocator, files, source, &.{});
        return .{ .name = manifest.name, .version = manifest.version, .files = files, .source = source, .descriptor = descriptor };
    }

    fn fail(self: *Manager, message: []const u8) error{InvalidPackagePublication} {
        self.diagnostic = message;
        return error.InvalidPackagePublication;
    }
};

fn targetForSource(relative: []const u8, fallback: TargetModule.Target) !TargetModule.Target {
    if (componentAfter(relative, "Target/")) |name| return TargetModule.Target.parse(name);
    if (componentAfter(relative, "Platform/")) |name| {
        for (TargetModule.Target.recognized) |target| if (std.mem.eql(u8, target.platform.directoryName(), name)) return target;
        return error.UnknownTarget;
    }
    return fallback;
}

fn appendUnique(allocator: std.mem.Allocator, paths: *std.ArrayList([]const u8), path: []const u8) !void {
    for (paths.items) |existing| if (std.mem.eql(u8, existing, path)) return;
    try paths.append(allocator, path);
}

fn componentAfter(path: []const u8, prefix: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, path, prefix)) return null;
    const rest = path[prefix.len..];
    const end = std.mem.indexOfScalar(u8, rest, '/') orelse return null;
    return rest[0..end];
}

fn optionalRegularFile(allocator: std.mem.Allocator, io: Io, root: []const u8, name: []const u8) !bool {
    const path = try std.fs.path.join(allocator, &.{ root, name });
    defer allocator.free(path);
    const stat = Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return error.UnsafeEntry,
    };
    if (stat.kind != .file or stat.nlink != 1) return error.UnsafeEntry;
    return true;
}

test "prepare a modified local package without Git or cache files" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "LocalDemo/Module");
    try temporary.dir.createDirPath(std.testing.io, "LocalDemo/.silex/cache");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/Package.json", .data = "{\"name\":\"LocalDemo\",\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.44.0\"}}\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/Module/Content.sx", .data =
        \\public func answer() int { return 42 }
        \\func main() {
        \\    let file = "Message.txt"
        \\    print(embed_text(file))
        \\}
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/Module/Message.txt", .data = "modified before publication\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/README.md", .data = "Local package\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/.silex/cache/secret", .data = "excluded" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "LocalDemo" });
    var manager = Manager.init(allocator, std.testing.io, null);
    const prepared = try manager.prepare(root);
    try std.testing.expectEqualStrings("LocalDemo", prepared.name);
    try std.testing.expectEqual(@as(usize, 4), prepared.files.len);
    try std.testing.expect(std.mem.indexOf(u8, prepared.descriptor.json, ".silex") == null);
    const resource = for (prepared.files) |file| {
        if (std.mem.eql(u8, file.path, "Module/Message.txt")) break file;
    } else return error.TestExpectedEqual;
    try std.testing.expectEqualStrings("modified before publication\n", resource.bytes);
}
