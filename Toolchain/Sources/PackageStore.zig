const std = @import("std");
const Artifacts = @import("Artifacts.zig");
const Modules = @import("Modules.zig");
const Packages = @import("Packages.zig");
const TargetModule = @import("Target.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const InstallResult = struct {
    package: Packages.ManifestInfo,
    destination: []const u8,
    artifacts: Artifacts.Summary,
    installed: bool,
};

pub const LinkResult = struct {
    package: Packages.ManifestInfo,
    source: []const u8,
    artifacts: Artifacts.Summary,
};

pub const PublicationProof = struct {
    repository: []const u8,
    commit: []const u8,
    archive_sha256: []const u8,
    extensions: []const []const u8,
};

const Receipt = struct {
    schema: u8 = 2,
    name: []const u8,
    version: []const u8,
    repository: []const u8,
    commit: []const u8,
    archive_sha256: []const u8,
    manifest_sha256: []const u8,
    extensions: []const []const u8,
};

pub const Manager = struct {
    allocator: Allocator,
    download_allocator: Allocator,
    io: Io,
    packages_root: []const u8,
    diagnostic: ?[]const u8 = null,

    pub fn init(
        allocator: Allocator,
        download_allocator: Allocator,
        io: Io,
        packages_root: []const u8,
    ) Manager {
        return .{
            .allocator = allocator,
            .download_allocator = download_allocator,
            .io = io,
            .packages_root = packages_root,
        };
    }

    pub fn install(self: *Manager, source: []const u8, target: TargetModule.Target) !InstallResult {
        return self.installWithProof(source, target, null);
    }

    pub fn installPublished(
        self: *Manager,
        source: []const u8,
        target: TargetModule.Target,
        proof: PublicationProof,
    ) !InstallResult {
        return self.installWithProof(source, target, proof);
    }

    fn installWithProof(
        self: *Manager,
        source: []const u8,
        target: TargetModule.Target,
        proof: ?PublicationProof,
    ) !InstallResult {
        self.diagnostic = null;
        const package = try self.inspect(source);
        if (proof) |publication| if (!equalStrings(package.extensions, publication.extensions)) {
            return self.failFmt("package '{s}' extensions do not match its source proof", .{package.name});
        };
        const folder = try packageFolder(self.allocator, package);
        const destination = try std.fs.path.join(self.allocator, &.{ self.packages_root, folder });
        if (try exists(self.io, destination)) {
            const existing = try self.inspect(destination);
            if (!std.mem.eql(u8, existing.name, package.name) or !existing.version.eql(package.version)) {
                return self.failFmt("installed package folder '{s}' has inconsistent contents", .{folder});
            }
            if (proof) |publication| try self.verifyReceipt(destination, existing, publication);
            const artifacts = try self.prepareArtifacts(destination, target);
            return .{
                .package = existing,
                .destination = destination,
                .artifacts = artifacts,
                .installed = false,
            };
        }

        try Io.Dir.cwd().createDirPath(self.io, self.packages_root);
        const staging_folder = try std.fmt.allocPrint(self.allocator, ".{s}.installing", .{folder});
        const staging = try std.fs.path.join(self.allocator, &.{ self.packages_root, staging_folder });
        if (try exists(self.io, staging)) return self.failFmt(
            "an incomplete installation exists at '{s}'",
            .{staging},
        );

        try self.copyTree(source, staging);
        if (proof) |publication| try self.writeReceipt(staging, package, publication);
        var published = false;
        defer if (!published) Io.Dir.cwd().deleteTree(self.io, staging) catch {};

        const artifacts = try self.prepareArtifacts(staging, target);
        Io.Dir.cwd().rename(staging, Io.Dir.cwd(), destination, self.io) catch |err| {
            return self.failFmt("cannot publish package '{s}': {t}", .{ folder, err });
        };
        published = true;
        return .{
            .package = package,
            .destination = destination,
            .artifacts = artifacts,
            .installed = true,
        };
    }

    fn writeReceipt(self: *Manager, root: []const u8, package: Packages.ManifestInfo, proof: PublicationProof) !void {
        const metadata_root = try std.fs.path.join(self.allocator, &.{ root, ".silex" });
        try Io.Dir.cwd().createDirPath(self.io, metadata_root);
        const path = try std.fs.path.join(self.allocator, &.{ metadata_root, "source.json" });
        const manifest_path = try std.fs.path.join(self.allocator, &.{ root, "Package.json" });
        const manifest_sha256 = try fileSha256(self.allocator, self.io, manifest_path);
        const version = try std.fmt.allocPrint(
            self.allocator,
            "{d}.{d}.{d}",
            .{ package.version.major, package.version.minor, package.version.patch },
        );
        const source = try std.json.Stringify.valueAlloc(self.allocator, Receipt{
            .name = package.name,
            .version = version,
            .repository = proof.repository,
            .commit = proof.commit,
            .archive_sha256 = proof.archive_sha256,
            .manifest_sha256 = manifest_sha256,
            .extensions = proof.extensions,
        }, .{ .whitespace = .indent_2 });
        try Io.Dir.cwd().writeFile(self.io, .{ .sub_path = path, .data = source });
    }

    fn verifyReceipt(self: *Manager, root: []const u8, package: Packages.ManifestInfo, proof: PublicationProof) !void {
        const path = try std.fs.path.join(self.allocator, &.{ root, ".silex", "source.json" });
        const source = Io.Dir.cwd().readFileAlloc(self.io, path, self.allocator, .limited(1024 * 1024)) catch
            return self.failFmt("installed package '{s}' has no source proof; remove it and reinstall", .{package.name});
        const receipt = std.json.parseFromSliceLeaky(Receipt, self.allocator, source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = false,
        }) catch return self.failFmt("installed package '{s}' has an invalid source proof", .{package.name});
        const version = try std.fmt.allocPrint(
            self.allocator,
            "{d}.{d}.{d}",
            .{ package.version.major, package.version.minor, package.version.patch },
        );
        const manifest_path = try std.fs.path.join(self.allocator, &.{ root, "Package.json" });
        const manifest_sha256 = try fileSha256(self.allocator, self.io, manifest_path);
        if (receipt.schema != 2 or
            !std.mem.eql(u8, receipt.name, package.name) or
            !std.mem.eql(u8, receipt.version, version) or
            !std.mem.eql(u8, receipt.repository, proof.repository) or
            !std.mem.eql(u8, receipt.commit, proof.commit) or
            !std.mem.eql(u8, receipt.archive_sha256, proof.archive_sha256) or
            !std.mem.eql(u8, receipt.manifest_sha256, manifest_sha256) or
            !equalStrings(receipt.extensions, proof.extensions))
        {
            return self.failFmt("installed package '{s}' does not match its source proof; remove it and reinstall", .{package.name});
        }
    }

    pub fn link(self: *Manager, source: []const u8, target: TargetModule.Target) !LinkResult {
        return self.linkAt(source, target, try self.userLinksRoot());
    }

    pub fn linkWorkspace(
        self: *Manager,
        source: []const u8,
        workspace: []const u8,
        target: TargetModule.Target,
    ) !LinkResult {
        return self.linkAt(source, target, try self.workspaceLinksRoot(workspace));
    }

    fn linkAt(
        self: *Manager,
        source: []const u8,
        target: TargetModule.Target,
        links_root: []const u8,
    ) !LinkResult {
        self.diagnostic = null;
        const canonical = Io.Dir.cwd().realPathFileAlloc(self.io, source, self.allocator) catch {
            return self.failFmt("cannot locate package directory '{s}'", .{source});
        };
        const package = try self.inspect(canonical);
        var artifact_installer = Artifacts.Installer.init(self.allocator, self.download_allocator, self.io);
        const artifacts = artifact_installer.install(canonical, target) catch |err| switch (err) {
            error.InvalidManifest => return self.failFmt(
                "cannot prepare linked package artifacts: {s}",
                .{artifact_installer.diagnostic orelse "invalid artifact declaration"},
            ),
            else => |other| return other,
        };
        try Io.Dir.cwd().createDirPath(self.io, links_root);
        const link_name = try std.fmt.allocPrint(self.allocator, "{s}.json", .{package.name});
        const destination = try std.fs.path.join(self.allocator, &.{ links_root, link_name });
        const temporary_name = try std.fmt.allocPrint(self.allocator, ".{s}.linking", .{package.name});
        const temporary = try std.fs.path.join(self.allocator, &.{ links_root, temporary_name });
        const payload = try std.json.Stringify.valueAlloc(self.allocator, .{ .path = canonical }, .{});
        try Io.Dir.cwd().writeFile(self.io, .{ .sub_path = temporary, .data = payload });
        Io.Dir.cwd().rename(temporary, Io.Dir.cwd(), destination, self.io) catch |err| {
            Io.Dir.cwd().deleteFile(self.io, temporary) catch {};
            return err;
        };
        return .{ .package = package, .source = canonical, .artifacts = artifacts };
    }

    pub fn unlink(self: *Manager, name: []const u8) !bool {
        return self.unlinkAt(name, try self.userLinksRoot());
    }

    pub fn unlinkWorkspace(self: *Manager, name: []const u8, workspace: []const u8) !bool {
        return self.unlinkAt(name, try self.workspaceLinksRoot(workspace));
    }

    fn unlinkAt(self: *Manager, name: []const u8, links_root: []const u8) !bool {
        self.diagnostic = null;
        if (!Modules.validName(name)) return self.failFmt("invalid package name '{s}'", .{name});
        const link_name = try std.fmt.allocPrint(self.allocator, "{s}.json", .{name});
        const path = try std.fs.path.join(self.allocator, &.{ links_root, link_name });
        Io.Dir.cwd().deleteFile(self.io, path) catch |err| switch (err) {
            error.FileNotFound => return false,
            else => |other| return other,
        };
        return true;
    }

    fn prepareArtifacts(self: *Manager, root: []const u8, target: TargetModule.Target) !Artifacts.Summary {
        var installer = Artifacts.Installer.init(self.allocator, self.download_allocator, self.io);
        return installer.install(root, target) catch |err| switch (err) {
            error.InvalidManifest => return self.failFmt(
                "cannot prepare package artifacts: {s}",
                .{installer.diagnostic orelse "invalid artifact declaration"},
            ),
            else => |other| return other,
        };
    }

    pub fn inspect(self: *Manager, source: []const u8) !Packages.ManifestInfo {
        var resolver = Packages.Resolver.init(self.allocator, self.io, self.packages_root);
        return resolver.inspectPackage(source) catch |err| switch (err) {
            error.InvalidPackageGraph => return self.failFmt(
                "cannot use package: {s}",
                .{resolver.diagnostic orelse "invalid package manifest"},
            ),
            else => |other| return other,
        };
    }

    fn copyTree(self: *Manager, source: []const u8, destination: []const u8) !void {
        Io.Dir.cwd().createDirPath(self.io, destination) catch |err| return self.failFmt(
            "cannot create package directory '{s}': {t}",
            .{ destination, err },
        );
        var directory = Io.Dir.cwd().openDir(self.io, source, .{ .iterate = true }) catch {
            return self.failFmt("cannot read package directory '{s}'", .{source});
        };
        defer directory.close(self.io);
        var entries = directory.iterateAssumeFirstIteration();
        while (try entries.next(self.io)) |entry| {
            if (std.mem.eql(u8, entry.name, ".git") or std.mem.eql(u8, entry.name, ".silex")) continue;
            const source_path = try std.fs.path.join(self.allocator, &.{ source, entry.name });
            const destination_path = try std.fs.path.join(self.allocator, &.{ destination, entry.name });
            switch (entry.kind) {
                .directory => try self.copyTree(source_path, destination_path),
                .file => Io.Dir.cwd().copyFile(source_path, Io.Dir.cwd(), destination_path, self.io, .{}) catch |err| {
                    return self.failFmt("cannot copy package file '{s}': {t}", .{ source_path, err });
                },
                else => return self.failFmt(
                    "package entry '{s}' is not a regular file or directory",
                    .{source_path},
                ),
            }
        }
    }

    fn userLinksRoot(self: *Manager) ![]const u8 {
        const silex_root = std.fs.path.dirname(self.packages_root) orelse
            return self.failFmt("invalid package store path '{s}'", .{self.packages_root});
        return std.fs.path.join(self.allocator, &.{ silex_root, "links" });
    }

    fn workspaceLinksRoot(self: *Manager, workspace: []const u8) ![]const u8 {
        const canonical = Io.Dir.cwd().realPathFileAlloc(self.io, workspace, self.allocator) catch {
            return self.failFmt("cannot locate workspace directory '{s}'", .{workspace});
        };
        return std.fs.path.join(self.allocator, &.{ canonical, ".silex", "links" });
    }

    fn failFmt(self: *Manager, comptime format: []const u8, arguments: anytype) error{InvalidPackageStore} {
        self.diagnostic = std.fmt.allocPrint(self.allocator, format, arguments) catch "package store failure";
        return error.InvalidPackageStore;
    }
};

fn packageFolder(allocator: Allocator, package: Packages.ManifestInfo) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}@{d}.{d}.{d}", .{
        package.name,
        package.version.major,
        package.version.minor,
        package.version.patch,
    });
}

fn exists(io: Io, path: []const u8) !bool {
    _ = Io.Dir.cwd().statFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return false,
        else => |other| return other,
    };
    return true;
}

fn fileSha256(allocator: Allocator, io: Io, path: []const u8) ![]const u8 {
    const source = try Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024));
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    return allocator.dupe(u8, &hex);
}

fn optionalStringEqual(left: ?[]const u8, right: ?[]const u8) bool {
    if (left == null or right == null) return left == null and right == null;
    return std.mem.eql(u8, left.?, right.?);
}

fn equalStrings(left: []const []const u8, right: []const []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_value, right_value| if (!std.mem.eql(u8, left_value, right_value)) return false;
    return true;
}

test "install copies an immutable package without repository state" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Checkout/Module");
    try temporary.dir.createDirPath(std.testing.io, "Checkout/.git/objects");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Checkout/Package.json",
        .data =
        \\{"name":"STD","version":"1.2.0","requires":{"silex":">=0.38.0 <0.39.0"}}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Checkout/Module/Text.sx", .data = "public module Text {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Checkout/.git/HEAD", .data = "ref: refs/heads/main" });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const source = try std.fs.path.join(allocator, &.{ base, "Checkout" });
    const packages_root = try std.fs.path.join(allocator, &.{ base, "Home", ".silex", "packages" });
    var manager = Manager.init(allocator, std.testing.allocator, std.testing.io, packages_root);
    const result = try manager.install(source, .macos_arm64);
    try std.testing.expectEqualStrings("STD", result.package.name);
    try std.testing.expect(try exists(std.testing.io, try std.fs.path.join(allocator, &.{ result.destination, "Module", "Text.sx" })));
    try std.testing.expect(!try exists(std.testing.io, try std.fs.path.join(allocator, &.{ result.destination, ".git" })));
    const repeated = try manager.install(source, .macos_arm64);
    try std.testing.expect(!repeated.installed);
}

test "published package extensions require an intact source proof" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX.UI/Module");
    try temporary.dir.createDirPath(std.testing.io, "App");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.38.0 <0.39.0\"},\"extensions\":[\"GFX.UI\"]}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.UI/Package.json",
        .data = "{\"name\":\"GFX.UI\",\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.38.0 <0.39.0\"},\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "App/Package.json",
        .data = "{\"dependencies\":{\"GFX\":\"=1.0.0\",\"GFX.UI\":\"=1.0.0\"}}",
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const packages_root = try std.fs.path.join(allocator, &.{ base, "Home", ".silex", "packages" });
    const gfx = try std.fs.path.join(allocator, &.{ base, "GFX" });
    const ui = try std.fs.path.join(allocator, &.{ base, "GFX.UI" });
    const app = try std.fs.path.join(allocator, &.{ base, "App" });
    const digest = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    var manager = Manager.init(allocator, std.testing.allocator, std.testing.io, packages_root);
    const gfx_result = try manager.installPublished(gfx, .macos_arm64, .{
        .repository = "Matanek/Silex-Lib-GFX",
        .commit = "0123456789abcdef0123456789abcdef01234567",
        .archive_sha256 = digest,
        .extensions = &.{"GFX.UI"},
    });
    _ = try manager.installPublished(ui, .macos_arm64, .{
        .repository = "Matanek/Silex-Lib-GFX-UI",
        .commit = "1123456789abcdef0123456789abcdef01234567",
        .archive_sha256 = digest,
        .extensions = &.{},
    });
    var resolver = Packages.Resolver.init(allocator, std.testing.io, packages_root);
    const graph = try resolver.resolve(app);
    try std.testing.expectEqual(@as(usize, 3), graph.packages.len);

    try Io.Dir.cwd().writeFile(std.testing.io, .{
        .sub_path = try std.fs.path.join(allocator, &.{ gfx_result.destination, "Package.json" }),
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.38.0 <0.39.0\"},\"extensions\":[\"GFX.Evil\"]}",
    });
    resolver = Packages.Resolver.init(allocator, std.testing.io, packages_root);
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(app));
    try std.testing.expectEqualStrings(
        "installed package does not match its source proof; remove it and reinstall",
        resolver.diagnostic.?,
    );
    try std.testing.expectError(error.InvalidPackageStore, manager.installPublished(gfx, .macos_arm64, .{
        .repository = "Matanek/Silex-Lib-GFX",
        .commit = "0123456789abcdef0123456789abcdef01234567",
        .archive_sha256 = digest,
        .extensions = &.{"GFX.UI"},
    }));
}

test "link exposes live package sources and unlink removes the override" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "App");
    try temporary.dir.createDirPath(std.testing.io, "Checkout/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "App/Package.json",
        .data =
        \\{"dependencies":{"STD":"^1.0.0"}}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Checkout/Package.json",
        .data =
        \\{"name":"STD","version":"1.2.0","requires":{"silex":">=0.38.0 <0.39.0"}}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Checkout/Module/Live.sx", .data = "public module Live {}" });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const app = try std.fs.path.join(allocator, &.{ base, "App" });
    const source = try std.fs.path.join(allocator, &.{ base, "Checkout" });
    const packages_root = try std.fs.path.join(allocator, &.{ base, "Home", ".silex", "packages" });
    var manager = Manager.init(allocator, std.testing.allocator, std.testing.io, packages_root);
    _ = try manager.install(source, .macos_arm64);
    const linked = try manager.link(source, .macos_arm64);
    var resolver = Packages.Resolver.init(allocator, std.testing.io, packages_root);
    const graph = try resolver.resolve(app);
    try std.testing.expectEqualStrings(linked.source, graph.packages[1].root);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Checkout/Package.json",
        .data =
        \\{"name":"STD","version":"2.0.0","requires":{"silex":">=0.38.0 <0.39.0"}}
        ,
    });
    resolver = Packages.Resolver.init(allocator, std.testing.io, packages_root);
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(app));
    try std.testing.expect(std.mem.indexOf(u8, resolver.diagnostic.?, "available version 2.0.0 is incompatible") != null);
    try std.testing.expect(try manager.unlink("STD"));
    resolver = Packages.Resolver.init(allocator, std.testing.io, packages_root);
    const installed_graph = try resolver.resolve(app);
    try std.testing.expectEqualStrings("STD", installed_graph.packages[1].name.?);
    try std.testing.expect(installed_graph.packages[1].version.?.eql(try Packages.Version.parse("1.2.0")));
    try std.testing.expect(!(try manager.unlink("STD")));

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Checkout/Package.json",
        .data =
        \\{"name":"STD","version":"1.2.0","requires":{"silex":">=0.38.0 <0.39.0"}}
        ,
    });
    _ = try manager.linkWorkspace(source, base, .macos_arm64);
    resolver = Packages.Resolver.init(allocator, std.testing.io, packages_root);
    const workspace_graph = try resolver.resolve(app);
    try std.testing.expectEqual(Packages.Origin.workspace_link, workspace_graph.packages[1].origin);
    try std.testing.expect(try manager.unlinkWorkspace("STD", base));
    try std.testing.expect(!(try manager.unlinkWorkspace("STD", base)));
}
