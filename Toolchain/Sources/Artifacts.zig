const std = @import("std");
const TargetModule = @import("Target.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Summary = struct {
    installed: usize = 0,
    available: usize = 0,
};

const Artifact = struct {
    name: []const u8,
    path: []const u8,
    url: []const u8,
    sha256: [32]u8,
};

pub const Installer = struct {
    allocator: Allocator,
    download_allocator: Allocator,
    io: Io,
    diagnostic: ?[]const u8 = null,

    pub fn init(allocator: Allocator, download_allocator: Allocator, io: Io) Installer {
        return .{
            .allocator = allocator,
            .download_allocator = download_allocator,
            .io = io,
        };
    }

    pub fn install(
        self: *Installer,
        package_root: []const u8,
        target: TargetModule.Target,
    ) !Summary {
        const manifest_path = try std.fs.path.join(self.allocator, &.{ package_root, "Package.json" });
        const source = Io.Dir.cwd().readFileAlloc(self.io, manifest_path, self.allocator, .limited(1024 * 1024)) catch |err| {
            return self.failFmt("cannot read package manifest '{s}': {t}", .{ manifest_path, err });
        };
        const artifacts = self.parse(source, target) catch |err| switch (err) {
            error.InvalidManifest => return error.InvalidManifest,
            else => |other| return other,
        };

        var summary: Summary = .{};
        for (artifacts) |artifact| {
            const destination = try std.fs.path.join(self.allocator, &.{ package_root, artifact.path });
            if (try matchesHash(self.io, destination, artifact.sha256)) {
                summary.available += 1;
                continue;
            }
            try self.download(artifact, destination);
            summary.installed += 1;
        }
        return summary;
    }

    fn parse(self: *Installer, source: []const u8, target: TargetModule.Target) ![]const Artifact {
        const parsed = std.json.parseFromSliceLeaky(std.json.Value, self.allocator, source, .{
            .allocate = .alloc_always,
        }) catch return self.fail("invalid package manifest");
        const root = switch (parsed) {
            .object => |object| object,
            else => return self.fail("package manifest must be a JSON object"),
        };
        const artifact_targets = switch (root.get("artifacts") orelse
            return self.fail("package does not declare installable artifacts")) {
            .object => |object| object,
            else => return self.fail("'artifacts' must be an object indexed by target"),
        };
        const target_value = artifact_targets.get(target.name()) orelse
            return self.failFmt("package does not declare artifacts for target '{s}'", .{target.name()});
        const target_artifacts = switch (target_value) {
            .object => |object| object,
            else => return self.failFmt("artifacts for target '{s}' must be an object", .{target.name()}),
        };
        if (target_artifacts.count() == 0) {
            return self.failFmt("package declares no artifacts for target '{s}'", .{target.name()});
        }

        var result: std.ArrayList(Artifact) = .empty;
        var iterator = target_artifacts.iterator();
        while (iterator.next()) |entry| {
            const object = switch (entry.value_ptr.*) {
                .object => |object| object,
                else => return self.failFmt("artifact '{s}' must be an object", .{entry.key_ptr.*}),
            };
            const path = try self.requiredString(object, entry.key_ptr.*, "path");
            const url = try self.requiredString(object, entry.key_ptr.*, "url");
            const checksum = try self.requiredString(object, entry.key_ptr.*, "sha256");
            if (!safeRelativePath(path)) {
                return self.failFmt("artifact '{s}' has an unsafe destination path", .{entry.key_ptr.*});
            }
            if (!std.mem.startsWith(u8, url, "https://")) {
                return self.failFmt("artifact '{s}' must use an HTTPS URL", .{entry.key_ptr.*});
            }
            if (checksum.len != 64) {
                return self.failFmt("artifact '{s}' has an invalid SHA-256 checksum", .{entry.key_ptr.*});
            }
            var digest: [32]u8 = undefined;
            _ = std.fmt.hexToBytes(&digest, checksum) catch
                return self.failFmt("artifact '{s}' has an invalid SHA-256 checksum", .{entry.key_ptr.*});
            try result.append(self.allocator, .{
                .name = entry.key_ptr.*,
                .path = path,
                .url = url,
                .sha256 = digest,
            });
        }
        std.mem.sort(Artifact, result.items, {}, artifactLessThan);
        return result.toOwnedSlice(self.allocator);
    }

    fn requiredString(
        self: *Installer,
        object: std.json.ObjectMap,
        artifact_name: []const u8,
        field: []const u8,
    ) ![]const u8 {
        const value = object.get(field) orelse
            return self.failFmt("artifact '{s}' is missing '{s}'", .{ artifact_name, field });
        return switch (value) {
            .string => |text| if (text.len == 0)
                self.failFmt("artifact '{s}' has an empty '{s}'", .{ artifact_name, field })
            else
                text,
            else => self.failFmt("artifact '{s}' field '{s}' must be a string", .{ artifact_name, field }),
        };
    }

    fn download(self: *Installer, artifact: Artifact, destination: []const u8) !void {
        const parent = std.fs.path.dirname(destination) orelse
            return self.failFmt("artifact '{s}' has no destination directory", .{artifact.name});
        Io.Dir.cwd().createDirPath(self.io, parent) catch |err| {
            return self.failFmt("cannot create artifact directory '{s}': {t}", .{ parent, err });
        };

        const temporary = try std.fmt.allocPrint(self.allocator, "{s}.silex-download", .{destination});
        Io.Dir.cwd().deleteFile(self.io, temporary) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return self.failFmt("cannot prepare artifact download '{s}': {t}", .{ artifact.name, err }),
        };
        var keep_temporary = true;
        defer if (keep_temporary) Io.Dir.cwd().deleteFile(self.io, temporary) catch {};

        const file = Io.Dir.cwd().createFile(self.io, temporary, .{ .read = true, .exclusive = true }) catch |err| {
            return self.failFmt("cannot create artifact download '{s}': {t}", .{ artifact.name, err });
        };
        var file_is_open = true;
        defer if (file_is_open) file.close(self.io);

        var buffer: [64 * 1024]u8 = undefined;
        var file_writer = file.writer(self.io, &buffer);
        var client: std.http.Client = .{ .allocator = self.download_allocator, .io = self.io };
        defer client.deinit();
        const response = client.fetch(.{
            .location = .{ .url = artifact.url },
            .response_writer = &file_writer.interface,
            .headers = .{ .user_agent = .{ .override = "Silex artifact installer" } },
        }) catch |err| {
            return self.failFmt("cannot download artifact '{s}': {t}", .{ artifact.name, err });
        };
        file_writer.interface.flush() catch |err| {
            return self.failFmt("cannot write artifact '{s}': {t}", .{ artifact.name, err });
        };
        if (response.status.class() != .success) {
            return self.failFmt("cannot download artifact '{s}': HTTP {d}", .{ artifact.name, @intFromEnum(response.status) });
        }
        if (!try fileMatchesHash(self.io, file, artifact.sha256)) {
            return self.failFmt("downloaded artifact '{s}' does not match its SHA-256 checksum", .{artifact.name});
        }
        file.close(self.io);
        file_is_open = false;
        Io.Dir.cwd().rename(temporary, Io.Dir.cwd(), destination, self.io) catch |err| {
            return self.failFmt("cannot install artifact '{s}': {t}", .{ artifact.name, err });
        };
        keep_temporary = false;
    }

    fn fail(self: *Installer, message: []const u8) error{InvalidManifest} {
        self.diagnostic = message;
        return error.InvalidManifest;
    }

    fn failFmt(self: *Installer, comptime format: []const u8, arguments: anytype) error{ OutOfMemory, InvalidManifest } {
        self.diagnostic = try std.fmt.allocPrint(self.allocator, format, arguments);
        return error.InvalidManifest;
    }
};

fn safeRelativePath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolutePosix(path) or std.fs.path.isAbsoluteWindows(path)) return false;
    if (std.mem.indexOfScalar(u8, path, '\\') != null or std.mem.indexOfScalar(u8, path, 0) != null) return false;
    var iterator = std.mem.splitScalar(u8, path, '/');
    while (iterator.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return false;
    }
    return true;
}

fn matchesHash(io: Io, path: []const u8, expected: [32]u8) !bool {
    const file = Io.Dir.cwd().openFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return false,
        else => return err,
    };
    defer file.close(io);
    return fileMatchesHash(io, file, expected);
}

fn fileMatchesHash(io: Io, file: Io.File, expected: [32]u8) !bool {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    var offset: u64 = 0;
    var buffer: [64 * 1024]u8 = undefined;
    while (true) {
        const amount = try file.readPositionalAll(io, &buffer, offset);
        if (amount == 0) break;
        hasher.update(buffer[0..amount]);
        offset += amount;
    }
    var actual: [32]u8 = undefined;
    hasher.final(&actual);
    return std.mem.eql(u8, &actual, &expected);
}

fn artifactLessThan(_: void, left: Artifact, right: Artifact) bool {
    return std.mem.lessThan(u8, left.name, right.name);
}

test "artifact manifest expresses one verified target-specific destination" {
    const source =
        \\{
        \\  "artifacts": {
        \\    "linux-x64": {
        \\      "SDL3": {
        \\        "path": "Boundary/linux-x64/libSDL3.a",
        \\        "url": "https://example.invalid/SDL3.a",
        \\        "sha256": "307863a80e696052ba4944d62533598889a08068badeec7e2729f096f4f2eada"
        \\      }
        \\    }
        \\  }
        \\}
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var installer = Installer.init(arena.allocator(), std.testing.allocator, std.testing.io);
    const artifacts = try installer.parse(source, .linux_x64);
    try std.testing.expectEqual(@as(usize, 1), artifacts.len);
    try std.testing.expectEqualStrings("SDL3", artifacts[0].name);
    try std.testing.expectEqualStrings("Boundary/linux-x64/libSDL3.a", artifacts[0].path);
}

test "artifact destinations cannot escape their package" {
    try std.testing.expect(safeRelativePath("Boundary/macos-arm64/libSDL3.a"));
    try std.testing.expect(!safeRelativePath("../libSDL3.a"));
    try std.testing.expect(!safeRelativePath("Boundary/../libSDL3.a"));
    try std.testing.expect(!safeRelativePath("/tmp/libSDL3.a"));
    try std.testing.expect(!safeRelativePath("C:\\libSDL3.lib"));
}
