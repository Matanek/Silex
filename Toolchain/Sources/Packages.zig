const std = @import("std");
const build_options = @import("build_options");
const macho = std.macho;
const Modules = @import("Modules.zig");
const TargetModule = @import("Target.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,

    pub fn parse(text: []const u8) error{InvalidVersion}!Version {
        var parts: [3]u32 = undefined;
        var iterator = std.mem.splitScalar(u8, text, '.');
        for (&parts) |*part| {
            const component = iterator.next() orelse return error.InvalidVersion;
            if (component.len == 0) return error.InvalidVersion;
            for (component) |character| if (!std.ascii.isDigit(character)) return error.InvalidVersion;
            part.* = std.fmt.parseInt(u32, component, 10) catch return error.InvalidVersion;
        }
        if (iterator.next() != null) return error.InvalidVersion;
        return .{ .major = parts[0], .minor = parts[1], .patch = parts[2] };
    }

    pub fn order(left: Version, right: Version) std.math.Order {
        if (left.major != right.major) return std.math.order(left.major, right.major);
        if (left.minor != right.minor) return std.math.order(left.minor, right.minor);
        return std.math.order(left.patch, right.patch);
    }

    pub fn eql(left: Version, right: Version) bool {
        return left.order(right) == .eq;
    }
};

pub const Constraint = struct {
    kind: enum { exact, caret },
    version: Version,

    pub fn parse(text: []const u8) error{InvalidConstraint}!Constraint {
        if (text.len < 2 or (text[0] != '=' and text[0] != '^')) return error.InvalidConstraint;
        return .{
            .kind = if (text[0] == '=') .exact else .caret,
            .version = Version.parse(text[1..]) catch return error.InvalidConstraint,
        };
    }

    pub fn accepts(self: Constraint, candidate: Version) bool {
        if (self.kind == .exact) return self.version.eql(candidate);
        if (candidate.order(self.version) == .lt) return false;
        return candidate.major == self.version.major;
    }
};

pub const SilexRequirement = struct {
    text: []const u8,
    minimum: Version,
    maximum_exclusive: ?Version,

    pub fn parse(text: []const u8) error{InvalidRequirement}!SilexRequirement {
        var clauses = std.mem.tokenizeScalar(u8, text, ' ');
        const minimum_clause = clauses.next() orelse return error.InvalidRequirement;
        if (!std.mem.startsWith(u8, minimum_clause, ">=") or minimum_clause.len == 2) {
            return error.InvalidRequirement;
        }
        const minimum = Version.parse(minimum_clause[2..]) catch return error.InvalidRequirement;
        const maximum_exclusive = if (clauses.next()) |maximum_clause| maximum: {
            if (!std.mem.startsWith(u8, maximum_clause, "<") or maximum_clause.len == 1) {
                return error.InvalidRequirement;
            }
            const maximum = Version.parse(maximum_clause[1..]) catch return error.InvalidRequirement;
            if (maximum.order(minimum) != .gt) return error.InvalidRequirement;
            break :maximum maximum;
        } else null;
        if (clauses.next() != null) return error.InvalidRequirement;
        return .{ .text = text, .minimum = minimum, .maximum_exclusive = maximum_exclusive };
    }

    pub fn accepts(self: SilexRequirement, version: Version) bool {
        if (version.order(self.minimum) == .lt) return false;
        if (self.maximum_exclusive) |maximum| return version.order(maximum) == .lt;
        return true;
    }
};

fn currentToolchainVersion() Version {
    return Version.parse(build_options.version) catch @panic("invalid Silex toolchain version");
}

fn constraintSymbol(constraint: Constraint) u8 {
    return if (constraint.kind == .exact) '=' else '^';
}

fn newest(current: ?Version, candidate: Version) Version {
    return if (current == null or candidate.order(current.?) == .gt) candidate else current.?;
}

pub const Dependency = struct {
    name: []const u8,
    package: usize,
    constraint: Constraint,
};

pub const Package = struct {
    name: ?[]const u8,
    version: ?Version,
    extensions: []const []const u8 = &.{},
    root: []const u8,
    module_roots: []const ModuleRoot,
    inactive_modules: []const []const u8,
    dependencies: []const Dependency,
    boundary_providers: []const BoundaryProvider = &.{},
};

pub const BoundaryProvider = struct {
    name: []const u8,
    archive: []const u8,
    artifact_sha256: []const u8 = "",
    frameworks: []const []const u8,
    libraries: []const []const u8,
};

pub const ModuleRoot = struct {
    path: []const u8,
    origin: Modules.Origin,
};

pub const Graph = struct {
    packages: []const Package,
    explicit: bool,

    pub fn directDependencyForModule(self: Graph, owner: usize, module_name: []const u8) ?Dependency {
        var result: ?Dependency = null;
        for (self.packages[owner].dependencies) |dependency| {
            if (!belongsTo(module_name, dependency.name)) continue;
            if (result == null or dependency.name.len > result.?.name.len) result = dependency;
        }
        return result;
    }

    pub fn canAccess(self: Graph, owner: usize, provider: usize, module_name: []const u8) bool {
        if (owner == provider) return true;
        const direct = self.directDependencyForModule(owner, module_name) orelse return false;
        return direct.package == provider;
    }

    pub fn label(self: Graph, package: usize) []const u8 {
        return self.packages[package].name orelse "application";
    }

    pub fn unavailableForTarget(self: Graph, owner: usize, module_name: []const u8) bool {
        for (self.packages, 0..) |package, provider| {
            if (provider != owner and !self.canAccess(owner, provider, module_name)) continue;
            for (package.inactive_modules) |inactive| {
                if (package.name) |prefix| {
                    if (module_name.len == prefix.len + 1 + inactive.len and
                        std.mem.startsWith(u8, module_name, prefix) and
                        module_name[prefix.len] == '.' and
                        std.mem.eql(u8, module_name[prefix.len + 1 ..], inactive)) return true;
                } else if (std.mem.eql(u8, inactive, module_name)) return true;
            }
        }
        return false;
    }

    pub fn boundaryProvider(self: Graph, owner: usize, library: []const u8) ?BoundaryProvider {
        if (owner >= self.packages.len) return null;
        const separator = std.mem.indexOfScalar(u8, library, '.') orelse return null;
        const name = library[separator + 1 ..];
        for (self.packages[owner].boundary_providers) |provider| {
            if (std.mem.eql(u8, provider.name, name)) return provider;
        }
        return null;
    }
};

pub const ManifestInfo = struct {
    name: []const u8,
    version: Version,
    silex_requirement: SilexRequirement,
    extensions: []const []const u8,
    dependencies: []const ManifestDependency,
};

pub const ManifestDependency = struct {
    name: []const u8,
    constraint: Constraint,
};

pub const Result = struct {
    graph: Graph,
    diagnostic: ?[]const u8 = null,
};

const RawManifest = struct {
    name: ?[]const u8 = null,
    version: ?[]const u8 = null,
    extensions: ?std.json.Value = null,
    requires: ?std.json.Value = null,
    dependencies: ?std.json.Value = null,
    boundary: ?std.json.Value = null,
    artifacts: ?std.json.Value = null,
};

const ParsedManifest = struct {
    name: ?[]const u8,
    version: ?Version,
    extensions: []const []const u8,
    silex_requirement: ?SilexRequirement,
    dependencies: []const ManifestDependency,
    boundary_providers: []const BoundaryProvider,
};

const State = enum { visiting, done };

const Builder = struct {
    package: Package,
    dependencies: std.ArrayList(Dependency) = .empty,
    state: State,
};

pub const Resolver = struct {
    allocator: Allocator,
    io: Io,
    global_root: ?[]const u8,
    target: TargetModule.Target,
    toolchain_version: Version = currentToolchainVersion(),
    local_root: []const u8 = "",
    shared_root: []const u8 = "",
    builders: std.ArrayList(Builder) = .empty,
    diagnostic: ?[]const u8 = null,

    pub fn init(allocator: Allocator, io: Io, global_root: ?[]const u8) Resolver {
        return initForTarget(allocator, io, global_root, TargetModule.Target.host() orelse .macos_arm64);
    }

    pub fn initForTarget(allocator: Allocator, io: Io, global_root: ?[]const u8, target: TargetModule.Target) Resolver {
        return .{ .allocator = allocator, .io = io, .global_root = global_root, .target = target };
    }

    pub fn resolve(self: *Resolver, project_root: []const u8) !Graph {
        self.diagnostic = null;
        try self.rejectLegacy(project_root);
        const manifest_path = try std.fs.path.join(self.allocator, &.{ project_root, "Package.json" });
        const root_manifest = try self.loadOptional(manifest_path);
        if (root_manifest) |manifest| {
            try self.validateToolchain(manifest);
            try self.validateRootIdentity(manifest, project_root);
        }
        self.local_root = if (root_manifest != null and root_manifest.?.name != null)
            std.fs.path.dirname(project_root) orelse project_root
        else
            project_root;
        self.shared_root = try self.findSharedRoot(project_root);
        const named_root = root_manifest != null and root_manifest.?.name != null;
        const roots = try self.moduleRoots(project_root, named_root);
        try self.builders.append(self.allocator, .{
            .package = .{
                .name = if (root_manifest) |manifest| manifest.name else null,
                .version = if (root_manifest) |manifest| manifest.version else null,
                .extensions = if (root_manifest) |manifest| manifest.extensions else &.{},
                .root = project_root,
                .module_roots = roots.active,
                .inactive_modules = roots.inactive,
                .dependencies = &.{},
                .boundary_providers = if (root_manifest) |manifest| manifest.boundary_providers else &.{},
            },
            .state = .visiting,
        });

        if (root_manifest) |manifest| {
            try self.resolveDependencies(0, manifest.dependencies);
        } else {
            try self.resolveAdjacent();
            try self.resolveImplicitLinks();
            try self.resolveImplicitGlobals();
        }
        self.builders.items[0].state = .done;
        try self.validateNamespaceExtensions();

        const packages = try self.allocator.alloc(Package, self.builders.items.len);
        for (self.builders.items, 0..) |*builder, index| {
            builder.package.dependencies = try builder.dependencies.toOwnedSlice(self.allocator);
            packages[index] = builder.package;
        }
        return .{ .packages = packages, .explicit = root_manifest != null };
    }

    pub fn inspectPackage(self: *Resolver, package_root: []const u8) !ManifestInfo {
        self.diagnostic = null;
        try self.rejectLegacy(package_root);
        const path = try std.fs.path.join(self.allocator, &.{ package_root, "Package.json" });
        const raw = try self.readManifest(path);
        const manifest = try self.parseManifestCore(raw);
        const name = manifest.name orelse return self.fail("an installable package requires name and version");
        const version = manifest.version orelse return self.fail("an installable package requires name and version");
        const requirement = manifest.silex_requirement orelse return self.fail(try std.fmt.allocPrint(
            self.allocator,
            "package '{s}@{d}.{d}.{d}' does not declare requires.silex",
            .{ name, version.major, version.minor, version.patch },
        ));
        try self.validateToolchain(manifest);
        return .{
            .name = name,
            .version = version,
            .silex_requirement = requirement,
            .extensions = manifest.extensions,
            .dependencies = manifest.dependencies,
        };
    }

    fn findSharedRoot(self: *Resolver, project_root: []const u8) ![]const u8 {
        const parent = std.fs.path.dirname(project_root) orelse ".";
        var directory = parent;
        while (true) {
            const candidate = try std.fs.path.join(self.allocator, &.{ directory, "Packages" });
            if (try exists(self.io, candidate)) return candidate;

            if (std.mem.eql(u8, directory, ".")) break;
            const next = std.fs.path.dirname(directory) orelse ".";
            if (std.mem.eql(u8, next, directory)) break;
            directory = next;
        }
        return std.fs.path.join(self.allocator, &.{ parent, "Packages" });
    }

    fn resolveAdjacent(self: *Resolver) !void {
        try self.resolveAdjacentFrom(self.local_root);
        try self.resolveAdjacentFrom(self.shared_root);
    }

    fn resolveAdjacentFrom(self: *Resolver, root_path: []const u8) !void {
        var directory = Io.Dir.cwd().openDir(self.io, root_path, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => return,
            else => return err,
        };
        defer directory.close(self.io);
        var names: std.ArrayList([]const u8) = .empty;
        var iterator = directory.iterateAssumeFirstIteration();
        while (try iterator.next(self.io)) |entry| {
            if (entry.kind != .directory) continue;
            const manifest_path = try std.fs.path.join(self.allocator, &.{ root_path, entry.name, "Package.json" });
            if (!try exists(self.io, manifest_path)) continue;
            try names.append(self.allocator, try self.allocator.dupe(u8, entry.name));
        }
        std.mem.sort([]const u8, names.items, {}, stringLessThan);
        for (names.items) |name| {
            const root = try std.fs.path.join(self.allocator, &.{ root_path, name });
            const manifest = try self.loadRequired(root);
            const identity = manifest.name orelse return self.fail("a sibling package requires name and version");
            const version = manifest.version orelse return self.fail("a sibling package requires name and version");
            if (!std.mem.eql(u8, identity, name)) return self.fail("local package folder and manifest name differ");
            const index = try self.resolveSelected(root, manifest, identity, version);
            var direct = false;
            for (self.builders.items[0].dependencies.items) |dependency| {
                if (std.mem.eql(u8, dependency.name, identity)) {
                    direct = true;
                    break;
                }
            }
            if (direct) continue;
            try self.builders.items[0].dependencies.append(self.allocator, .{
                .name = identity,
                .package = index,
                .constraint = .{ .kind = .exact, .version = version },
            });
        }
    }

    fn resolveImplicitGlobals(self: *Resolver) !void {
        const global_root = self.global_root orelse return;
        var directory = Io.Dir.cwd().openDir(self.io, global_root, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => return,
            else => |other| return other,
        };
        defer directory.close(self.io);

        var names: std.ArrayList([]const u8) = .empty;
        var iterator = directory.iterateAssumeFirstIteration();
        while (try iterator.next(self.io)) |entry| {
            if (entry.kind != .directory) continue;
            const separator = std.mem.lastIndexOfScalar(u8, entry.name, '@') orelse continue;
            const name = entry.name[0..separator];
            if (!Modules.validName(name) or separator + 1 == entry.name.len) continue;
            _ = Version.parse(entry.name[separator + 1 ..]) catch continue;
            try names.append(self.allocator, try self.allocator.dupe(u8, name));
        }
        std.mem.sort([]const u8, names.items, {}, stringLessThan);

        var previous: ?[]const u8 = null;
        for (names.items) |name| {
            if (previous) |seen| if (std.mem.eql(u8, seen, name)) continue;
            previous = name;
            if (self.rootDependsOn(name)) continue;

            const index = if (self.find(name)) |existing|
                existing
            else if (try self.bestImplicitGlobal(name)) |selected|
                try self.resolveSelected(selected.root, selected.manifest, name, selected.version)
            else
                continue;
            try self.appendImplicitRootDependency(name, index);
        }
    }

    fn resolveImplicitLinks(self: *Resolver) !void {
        const global_root = self.global_root orelse return;
        const silex_root = std.fs.path.dirname(global_root) orelse return;
        const links_root = try std.fs.path.join(self.allocator, &.{ silex_root, "links" });
        var directory = Io.Dir.cwd().openDir(self.io, links_root, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => return,
            else => |other| return other,
        };
        defer directory.close(self.io);

        var names: std.ArrayList([]const u8) = .empty;
        var iterator = directory.iterateAssumeFirstIteration();
        while (try iterator.next(self.io)) |entry| {
            if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".json")) continue;
            const name = entry.name[0 .. entry.name.len - ".json".len];
            if (!Modules.validName(name)) continue;
            try names.append(self.allocator, try self.allocator.dupe(u8, name));
        }
        std.mem.sort([]const u8, names.items, {}, stringLessThan);
        for (names.items) |name| {
            if (self.rootDependsOn(name)) continue;
            const index = if (self.find(name)) |existing|
                existing
            else if (try self.linkedNamed(name)) |selected|
                try self.resolveSelected(selected.root, selected.manifest, name, selected.version)
            else
                continue;
            try self.appendImplicitRootDependency(name, index);
        }
    }

    fn rootDependsOn(self: *Resolver, name: []const u8) bool {
        for (self.builders.items[0].dependencies.items) |dependency| {
            if (std.mem.eql(u8, dependency.name, name)) return true;
        }
        return false;
    }

    fn appendImplicitRootDependency(self: *Resolver, name: []const u8, package: usize) !void {
        const version = self.builders.items[package].package.version.?;
        try self.builders.items[0].dependencies.append(self.allocator, .{
            .name = name,
            .package = package,
            .constraint = .{ .kind = .exact, .version = version },
        });
    }

    fn resolveDependencies(self: *Resolver, owner: usize, dependencies: []const ManifestDependency) anyerror!void {
        for (dependencies) |request| {
            const package = try self.resolveRequest(owner, request);
            try self.builders.items[owner].dependencies.append(self.allocator, .{
                .name = request.name,
                .package = package,
                .constraint = request.constraint,
            });
        }
    }

    fn resolveRequest(self: *Resolver, owner: usize, request: ManifestDependency) anyerror!usize {
        if (self.find(request.name)) |existing| {
            const builder = &self.builders.items[existing];
            if (!request.constraint.accepts(builder.package.version.?)) {
                return self.fail(try self.selectedVersionDiagnostic(owner, request, builder.package.version.?));
            }
            if (builder.state == .visiting) return self.fail("package dependency cycle");
            return existing;
        }

        var available: ?Version = null;
        const local_root = try std.fs.path.join(self.allocator, &.{ self.local_root, request.name });
        try self.rejectLegacy(local_root);
        const local_manifest_path = try std.fs.path.join(self.allocator, &.{ local_root, "Package.json" });
        if (try exists(self.io, local_manifest_path)) {
            const manifest = try self.loadRequired(local_root);
            const version = try self.validateSelected(manifest, request.name, local_root, false);
            if (request.constraint.accepts(version)) return self.resolveSelected(local_root, manifest, request.name, version);
            available = newest(available, version);
        }

        const shared_root = try std.fs.path.join(self.allocator, &.{ self.shared_root, request.name });
        try self.rejectLegacy(shared_root);
        const shared_manifest_path = try std.fs.path.join(self.allocator, &.{ shared_root, "Package.json" });
        if (try exists(self.io, shared_manifest_path)) {
            const manifest = try self.loadRequired(shared_root);
            const version = try self.validateSelected(manifest, request.name, shared_root, false);
            if (request.constraint.accepts(version)) return self.resolveSelected(shared_root, manifest, request.name, version);
            available = newest(available, version);
        }

        if (try self.linked(owner, request)) |selected| {
            return self.resolveSelected(selected.root, selected.manifest, request.name, selected.version);
        }

        if (try self.bestGlobal(request, &available)) |selected| {
            return self.resolveSelected(selected.root, selected.manifest, request.name, selected.version);
        }
        return self.fail(try self.unresolvedDependencyDiagnostic(owner, request, available));
    }

    const Selected = struct {
        root: []const u8,
        manifest: ParsedManifest,
        version: Version,
    };

    const Link = struct {
        path: []const u8,
    };

    fn linked(self: *Resolver, owner: usize, request: ManifestDependency) !?Selected {
        const selected = try self.linkedNamed(request.name) orelse return null;
        if (!request.constraint.accepts(selected.version)) {
            return self.fail(try self.unresolvedDependencyDiagnostic(owner, request, selected.version));
        }
        return selected;
    }

    fn linkedNamed(self: *Resolver, name: []const u8) !?Selected {
        const global_root = self.global_root orelse return null;
        const silex_root = std.fs.path.dirname(global_root) orelse return null;
        const file_name = try std.fmt.allocPrint(self.allocator, "{s}.json", .{name});
        const link_path = try std.fs.path.join(self.allocator, &.{ silex_root, "links", file_name });
        const source = Io.Dir.cwd().readFileAlloc(self.io, link_path, self.allocator, .limited(64 * 1024)) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => return null,
            else => return self.fail(try std.fmt.allocPrint(
                self.allocator,
                "linked package '{s}' cannot be read; run 'silex unlink {s}'",
                .{ name, name },
            )),
        };
        const link = std.json.parseFromSliceLeaky(Link, self.allocator, source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = false,
        }) catch return self.fail(try std.fmt.allocPrint(
            self.allocator,
            "linked package '{s}' has an invalid link; run 'silex unlink {s}'",
            .{ name, name },
        ));
        const manifest = self.loadRequired(link.path) catch |err| switch (err) {
            error.InvalidPackageGraph => return self.fail(try std.fmt.allocPrint(
                self.allocator,
                "linked package '{s}' is unavailable at '{s}'; run 'silex unlink {s}'",
                .{ name, link.path, name },
            )),
            else => |other| return other,
        };
        const version = try self.validateSelected(manifest, name, link.path, true);
        try self.validateToolchain(manifest);
        return .{ .root = link.path, .manifest = manifest, .version = version };
    }

    fn bestGlobal(self: *Resolver, request: ManifestDependency, available: *?Version) !?Selected {
        const global_root = self.global_root orelse return null;
        var directory = Io.Dir.cwd().openDir(self.io, global_root, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => return null,
            else => |other| return other,
        };
        defer directory.close(self.io);
        const prefix = try std.fmt.allocPrint(self.allocator, "{s}@", .{request.name});
        var best: ?Selected = null;
        var toolchain_incompatible: ?Selected = null;
        var iterator = directory.iterateAssumeFirstIteration();
        while (try iterator.next(self.io)) |entry| {
            if (entry.kind != .directory or !std.mem.startsWith(u8, entry.name, prefix)) continue;
            const suffix = entry.name[prefix.len..];
            const folder_version = Version.parse(suffix) catch return self.fail("global package folder has an invalid version");
            const root = try std.fs.path.join(self.allocator, &.{ global_root, entry.name });
            var manifest = try self.loadRequired(root);
            const version = try self.validateSelected(manifest, request.name, root, true);
            manifest = try self.trustGlobalExtensions(root, manifest, request.name, version);
            if (!folder_version.eql(version)) return self.fail("global package folder and manifest version differ");
            available.* = newest(available.*, version);
            if (!request.constraint.accepts(version)) continue;
            if (!manifest.silex_requirement.?.accepts(self.toolchain_version)) {
                if (toolchain_incompatible == null or version.order(toolchain_incompatible.?.version) == .gt) {
                    toolchain_incompatible = .{ .root = root, .manifest = manifest, .version = version };
                }
                continue;
            }
            if (best == null or version.order(best.?.version) == .gt) {
                best = .{ .root = root, .manifest = manifest, .version = version };
            }
        }
        if (best == null) {
            if (toolchain_incompatible) |selected| try self.validateToolchain(selected.manifest);
        }
        return best;
    }

    fn bestImplicitGlobal(self: *Resolver, name: []const u8) !?Selected {
        const global_root = self.global_root orelse return null;
        var directory = Io.Dir.cwd().openDir(self.io, global_root, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => return null,
            else => |other| return other,
        };
        defer directory.close(self.io);
        const prefix = try std.fmt.allocPrint(self.allocator, "{s}@", .{name});
        var best: ?Selected = null;
        var iterator = directory.iterateAssumeFirstIteration();
        while (try iterator.next(self.io)) |entry| {
            if (entry.kind != .directory or !std.mem.startsWith(u8, entry.name, prefix)) continue;
            const folder_version = Version.parse(entry.name[prefix.len..]) catch continue;
            const root = try std.fs.path.join(self.allocator, &.{ global_root, entry.name });
            var manifest = try self.loadRequired(root);
            const version = try self.validateSelected(manifest, name, root, true);
            manifest = try self.trustGlobalExtensions(root, manifest, name, version);
            if (!folder_version.eql(version)) return self.fail("global package folder and manifest version differ");
            if (!manifest.silex_requirement.?.accepts(self.toolchain_version)) continue;
            if (best == null or version.order(best.?.version) == .gt) {
                best = .{ .root = root, .manifest = manifest, .version = version };
            }
        }
        return best;
    }

    fn trustGlobalExtensions(
        self: *Resolver,
        root: []const u8,
        manifest: ParsedManifest,
        name: []const u8,
        version: Version,
    ) !ParsedManifest {
        var trusted = manifest;
        trusted.extensions = &.{};
        const receipt_path = try std.fs.path.join(self.allocator, &.{ root, ".silex", "registry.json" });
        const source = Io.Dir.cwd().readFileAlloc(self.io, receipt_path, self.allocator, .limited(1024 * 1024)) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => return trusted,
            else => return self.fail("installed package registry proof cannot be read"),
        };
        const Receipt = struct {
            schema: u8,
            name: []const u8,
            version: []const u8,
            repository: ?[]const u8,
            archive_sha256: []const u8,
            manifest_sha256: []const u8,
            extensions: []const []const u8,
        };
        const receipt = std.json.parseFromSliceLeaky(Receipt, self.allocator, source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = false,
        }) catch return self.fail("installed package has an invalid registry proof; remove it and reinstall");
        const version_text = try std.fmt.allocPrint(
            self.allocator,
            "{d}.{d}.{d}",
            .{ version.major, version.minor, version.patch },
        );
        const manifest_path = try std.fs.path.join(self.allocator, &.{ root, "Package.json" });
        const manifest_sha256 = try fileSha256(self.allocator, self.io, manifest_path);
        if (receipt.schema != 1 or
            !std.mem.eql(u8, receipt.name, name) or
            !std.mem.eql(u8, receipt.version, version_text) or
            !validSha256(receipt.archive_sha256) or
            !std.mem.eql(u8, receipt.manifest_sha256, manifest_sha256) or
            !equalStrings(receipt.extensions, manifest.extensions))
        {
            return self.fail("installed package does not match its registry proof; remove it and reinstall");
        }
        _ = receipt.repository;
        trusted.extensions = receipt.extensions;
        return trusted;
    }

    fn selectedVersionDiagnostic(self: *Resolver, owner: usize, request: ManifestDependency, selected: Version) ![]const u8 {
        return std.fmt.allocPrint(
            self.allocator,
            "package '{s}' requires '{s}' {c}{d}.{d}.{d}, but version {d}.{d}.{d} is already selected",
            .{
                try self.ownerLabel(owner),
                request.name,
                constraintSymbol(request.constraint),
                request.constraint.version.major,
                request.constraint.version.minor,
                request.constraint.version.patch,
                selected.major,
                selected.minor,
                selected.patch,
            },
        );
    }

    fn unresolvedDependencyDiagnostic(
        self: *Resolver,
        owner: usize,
        request: ManifestDependency,
        available: ?Version,
    ) ![]const u8 {
        const owner_label = try self.ownerLabel(owner);
        if (available) |version| return std.fmt.allocPrint(
            self.allocator,
            "package '{s}' requires '{s}' {c}{d}.{d}.{d}, but available version {d}.{d}.{d} is incompatible",
            .{
                owner_label,
                request.name,
                constraintSymbol(request.constraint),
                request.constraint.version.major,
                request.constraint.version.minor,
                request.constraint.version.patch,
                version.major,
                version.minor,
                version.patch,
            },
        );
        return std.fmt.allocPrint(
            self.allocator,
            "package '{s}' requires '{s}' {c}{d}.{d}.{d}, but no package named '{s}' is available",
            .{
                owner_label,
                request.name,
                constraintSymbol(request.constraint),
                request.constraint.version.major,
                request.constraint.version.minor,
                request.constraint.version.patch,
                request.name,
            },
        );
    }

    fn ownerLabel(self: *Resolver, owner: usize) ![]const u8 {
        const package = self.builders.items[owner].package;
        const name = package.name orelse return "application";
        const version = package.version orelse return name;
        return std.fmt.allocPrint(self.allocator, "{s}@{d}.{d}.{d}", .{ name, version.major, version.minor, version.patch });
    }

    fn resolveSelected(
        self: *Resolver,
        root: []const u8,
        manifest: ParsedManifest,
        name: []const u8,
        version: Version,
    ) anyerror!usize {
        if (self.find(name)) |existing| return existing;
        try self.validateToolchain(manifest);
        const roots = try self.moduleRoots(root, true);
        const index = self.builders.items.len;
        try self.builders.append(self.allocator, .{
            .package = .{
                .name = name,
                .version = version,
                .extensions = manifest.extensions,
                .root = root,
                .module_roots = roots.active,
                .inactive_modules = roots.inactive,
                .dependencies = &.{},
                .boundary_providers = manifest.boundary_providers,
            },
            .state = .visiting,
        });
        try self.resolveDependencies(index, manifest.dependencies);
        self.builders.items[index].state = .done;
        return index;
    }

    const ModuleRoots = struct {
        active: []const ModuleRoot,
        inactive: []const []const u8,
    };

    fn moduleRoots(self: *Resolver, root: []const u8, named: bool) !ModuleRoots {
        if (!named) return .{
            .active = try self.allocator.dupe(ModuleRoot, &.{.{ .path = root, .origin = .portable }}),
            .inactive = &.{},
        };

        var active: std.ArrayList(ModuleRoot) = .empty;
        try active.append(self.allocator, .{
            .path = try std.fs.path.join(self.allocator, &.{ root, "Module" }),
            .origin = .portable,
        });
        const platform = try std.fs.path.join(self.allocator, &.{ root, "Platform", self.target.platform.directoryName(), "Module" });
        if (try exists(self.io, platform)) try active.append(self.allocator, .{ .path = platform, .origin = .platform });
        const selected = try std.fs.path.join(self.allocator, &.{ root, "Target", self.target.name(), "Module" });
        if (try exists(self.io, selected)) try active.append(self.allocator, .{ .path = selected, .origin = .target });
        return .{
            .active = try active.toOwnedSlice(self.allocator),
            .inactive = try self.inactiveModuleNames(root),
        };
    }

    fn inactiveModuleNames(self: *Resolver, root: []const u8) ![]const []const u8 {
        var names: std.ArrayList([]const u8) = .empty;
        try self.appendInactiveRootModules(root, "Platform", self.target.platform.directoryName(), &names);
        try self.appendInactiveRootModules(root, "Target", self.target.name(), &names);
        std.mem.sort([]const u8, names.items, {}, stringLessThan);
        var unique: std.ArrayList([]const u8) = .empty;
        for (names.items) |name| {
            if (unique.items.len == 0 or !std.mem.eql(u8, unique.items[unique.items.len - 1], name)) {
                try unique.append(self.allocator, name);
            }
        }
        return unique.toOwnedSlice(self.allocator);
    }

    fn appendInactiveRootModules(
        self: *Resolver,
        root: []const u8,
        category: []const u8,
        selected: []const u8,
        names: *std.ArrayList([]const u8),
    ) !void {
        const category_path = try std.fs.path.join(self.allocator, &.{ root, category });
        var directory = Io.Dir.cwd().openDir(self.io, category_path, .{ .iterate = true }) catch return;
        defer directory.close(self.io);
        var entries = directory.iterateAssumeFirstIteration();
        while (entries.next(self.io) catch null) |entry| {
            if (entry.kind != .directory or std.mem.eql(u8, entry.name, selected)) continue;
            const module_root = try std.fs.path.join(self.allocator, &.{ category_path, entry.name, "Module" });
            const discovered = Modules.discoverOwned(self.allocator, self.io, module_root, null, 0) catch continue;
            for (discovered.providers) |provider| try names.append(self.allocator, provider.name);
        }
    }

    fn validateSelected(
        self: *Resolver,
        manifest: ParsedManifest,
        expected_name: []const u8,
        root: []const u8,
        global: bool,
    ) !Version {
        _ = root;
        const name = manifest.name orelse return self.fail("a package dependency requires name and version");
        const version = manifest.version orelse return self.fail("a package dependency requires name and version");
        if (!std.mem.eql(u8, name, expected_name)) return self.fail("package folder and manifest name differ");
        if (global and manifest.silex_requirement == null) {
            return self.fail(try std.fmt.allocPrint(
                self.allocator,
                "installed package '{s}@{d}.{d}.{d}' does not declare requires.silex",
                .{ name, version.major, version.minor, version.patch },
            ));
        }
        return version;
    }

    fn validateToolchain(self: *Resolver, manifest: ParsedManifest) !void {
        const requirement = manifest.silex_requirement orelse return;
        if (requirement.accepts(self.toolchain_version)) return;
        const label = if (manifest.name) |name|
            if (manifest.version) |package_version|
                try std.fmt.allocPrint(
                    self.allocator,
                    "{s}@{d}.{d}.{d}",
                    .{ name, package_version.major, package_version.minor, package_version.patch },
                )
            else
                name
        else
            "application";
        return self.fail(try std.fmt.allocPrint(
            self.allocator,
            "package '{s}' requires Silex {s}, but this toolchain is Silex {d}.{d}.{d}",
            .{
                label,
                requirement.text,
                self.toolchain_version.major,
                self.toolchain_version.minor,
                self.toolchain_version.patch,
            },
        ));
    }

    fn validateNamespaceExtensions(self: *Resolver) !void {
        for (self.builders.items) |builder| {
            const child = builder.package.name orelse continue;
            const separator = std.mem.lastIndexOfScalar(u8, child, '.') orelse continue;
            const parent_name = child[0..separator];
            const parent_index = self.find(parent_name) orelse return self.fail(try std.fmt.allocPrint(
                self.allocator,
                "package '{s}' requires parent package '{s}' to authorize its namespace",
                .{ child, parent_name },
            ));
            const parent = self.builders.items[parent_index].package;
            if (allowsExtension(parent.extensions, child)) continue;
            return self.fail(try std.fmt.allocPrint(
                self.allocator,
                "package '{s}' does not authorize package '{s}' as a namespace extension",
                .{ parent_name, child },
            ));
        }
    }

    fn validateRootIdentity(self: *Resolver, manifest: ParsedManifest, root: []const u8) !void {
        if ((manifest.name == null) != (manifest.version == null)) {
            return self.fail("a manifest must declare name and version together");
        }
        if (manifest.name) |name| {
            if (!Modules.validName(name)) return self.fail("invalid package identity");
            if (!std.mem.eql(u8, std.fs.path.basename(root), name)) {
                return self.fail("local package folder and manifest name differ");
            }
        }
    }

    fn loadOptional(self: *Resolver, path: []const u8) !?ParsedManifest {
        if (!try exists(self.io, path)) return null;
        return try self.parseManifest(path);
    }

    fn loadRequired(self: *Resolver, root: []const u8) !ParsedManifest {
        try self.rejectLegacy(root);
        const path = try std.fs.path.join(self.allocator, &.{ root, "Package.json" });
        return self.parseManifest(path);
    }

    fn rejectLegacy(self: *Resolver, root: []const u8) !void {
        const legacy_at = try std.fs.path.join(self.allocator, &.{ root, "@Module.json" });
        const legacy_plain = try std.fs.path.join(self.allocator, &.{ root, "Module.json" });
        if (try exists(self.io, legacy_at) or try exists(self.io, legacy_plain)) {
            return self.fail("legacy package manifests are not supported; use Package.json");
        }
    }

    fn parseManifest(self: *Resolver, path: []const u8) !ParsedManifest {
        const raw = try self.readManifest(path);
        var manifest = try self.parseManifestCore(raw);
        manifest.boundary_providers = try self.parseBoundary(
            raw.boundary,
            raw.artifacts,
            raw.name,
            std.fs.path.dirname(path) orelse ".",
        );
        return manifest;
    }

    fn readManifest(self: *Resolver, path: []const u8) !RawManifest {
        const source = Io.Dir.cwd().readFileAlloc(self.io, path, self.allocator, .limited(1024 * 1024)) catch {
            return self.fail("package manifest cannot be read");
        };
        return std.json.parseFromSliceLeaky(RawManifest, self.allocator, source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = false,
        }) catch return self.fail("invalid package manifest or unsupported field");
    }

    fn parseManifestCore(self: *Resolver, raw: RawManifest) !ParsedManifest {
        if ((raw.name == null) != (raw.version == null)) {
            return self.fail("a manifest must declare name and version together");
        }
        const version = if (raw.version) |text|
            Version.parse(text) catch return self.fail("invalid package version")
        else
            null;
        if (raw.name) |name| if (!Modules.validName(name)) return self.fail("invalid package identity");

        var extensions: std.ArrayList([]const u8) = .empty;
        if (raw.extensions) |value| {
            const package_name = raw.name orelse return self.fail("an application manifest cannot declare extensions");
            const array = switch (value) {
                .array => |array| array,
                else => return self.fail("extensions must be an array of direct child package names"),
            };
            for (array.items) |item| {
                const extension = switch (item) {
                    .string => |text| text,
                    else => return self.fail("an extension grant must be a package name string"),
                };
                if (!validExtensionGrant(package_name, extension)) {
                    return self.fail("an extension grant must name one direct child package or use Parent.*");
                }
                try extensions.append(self.allocator, extension);
            }
            std.mem.sort([]const u8, extensions.items, {}, stringLessThan);
            if (extensions.items.len > 1) {
                for (extensions.items[1..], extensions.items[0 .. extensions.items.len - 1]) |current, previous| {
                    if (std.mem.eql(u8, current, previous)) return self.fail("extension grants must be unique");
                }
            }
        }

        var silex_requirement: ?SilexRequirement = null;
        if (raw.requires) |value| {
            const object = switch (value) {
                .object => |object| object,
                else => return self.fail("requires must be an object containing silex"),
            };
            if (object.count() != 1 or object.get("silex") == null) {
                return self.fail("requires accepts only a silex version range");
            }
            const text = switch (object.get("silex").?) {
                .string => |text| text,
                else => return self.fail("requires.silex must be a version range string"),
            };
            silex_requirement = SilexRequirement.parse(text) catch
                return self.fail("invalid requires.silex version range; expected '>=MAJOR.MINOR.PATCH' with optional '<MAJOR.MINOR.PATCH'");
        }

        var dependencies: std.ArrayList(ManifestDependency) = .empty;
        if (raw.dependencies) |value| {
            const object = switch (value) {
                .object => |object| object,
                else => return self.fail("dependencies must be an object of version constraints"),
            };
            var iterator = object.iterator();
            while (iterator.next()) |entry| {
                const name = entry.key_ptr.*;
                if (!Modules.validName(name)) return self.fail("invalid dependency identity");
                const text = switch (entry.value_ptr.*) {
                    .string => |text| text,
                    else => return self.fail("a dependency value must be a version constraint string"),
                };
                try dependencies.append(self.allocator, .{
                    .name = name,
                    .constraint = Constraint.parse(text) catch return self.fail("invalid dependency version constraint"),
                });
            }
            std.mem.sort(ManifestDependency, dependencies.items, {}, dependencyLessThan);
        }
        return .{
            .name = raw.name,
            .version = version,
            .extensions = try extensions.toOwnedSlice(self.allocator),
            .silex_requirement = silex_requirement,
            .dependencies = try dependencies.toOwnedSlice(self.allocator),
            .boundary_providers = &.{},
        };
    }

    fn parseBoundary(
        self: *Resolver,
        value: ?std.json.Value,
        artifacts: ?std.json.Value,
        package_name: ?[]const u8,
        root: []const u8,
    ) ![]const BoundaryProvider {
        const boundary_value = value orelse return &.{};
        if (package_name == null) return self.fail("an application manifest cannot declare a native boundary");
        const targets = switch (boundary_value) {
            .object => |object| object,
            else => return self.fail("boundary must be an object keyed by target"),
        };
        const selected = targets.get(self.target.name()) orelse return &.{};
        const target_object = switch (selected) {
            .object => |object| object,
            else => return self.fail("a boundary target must be an object"),
        };
        if (target_object.count() != 1 or target_object.get("providers") == null) {
            return self.fail("a boundary target accepts only providers");
        }
        const providers_object = switch (target_object.get("providers").?) {
            .object => |object| object,
            else => return self.fail("boundary providers must be an object"),
        };
        var providers: std.ArrayList(BoundaryProvider) = .empty;
        var iterator = providers_object.iterator();
        while (iterator.next()) |entry| {
            const provider_name = entry.key_ptr.*;
            if (!Modules.validName(provider_name) or std.mem.indexOfScalar(u8, provider_name, '.') != null) {
                return self.fail("invalid boundary provider name");
            }
            const provider = switch (entry.value_ptr.*) {
                .object => |object| object,
                else => return self.fail("a boundary provider must be an object"),
            };
            if (provider.count() == 0 or provider.count() > 3 or provider.get("archive") == null) {
                return self.fail("a boundary provider requires archive and optionally frameworks or libraries");
            }
            var field_iterator = provider.iterator();
            while (field_iterator.next()) |field| {
                if (!std.mem.eql(u8, field.key_ptr.*, "archive") and
                    !std.mem.eql(u8, field.key_ptr.*, "frameworks") and
                    !std.mem.eql(u8, field.key_ptr.*, "libraries"))
                {
                    return self.fail("unsupported boundary provider field");
                }
            }
            const relative_archive = switch (provider.get("archive").?) {
                .string => |archive| archive,
                else => return self.fail("boundary archive must be a relative path string"),
            };
            if (!validRelativePath(relative_archive)) return self.fail("boundary archive must stay inside its package");
            const archive = try std.fs.path.join(self.allocator, &.{ root, relative_archive });
            if (!try exists(self.io, archive)) {
                return self.fail("boundary archive is missing; run 'silex install <package-directory>'");
            }
            if (!validArchive(self.io, archive, self.target)) return self.fail("boundary archive does not match its target");
            var frameworks: std.ArrayList([]const u8) = .empty;
            if (provider.get("frameworks")) |framework_value| {
                const array = switch (framework_value) {
                    .array => |array| array,
                    else => return self.fail("boundary frameworks must be an array of names"),
                };
                for (array.items) |item| {
                    const framework = switch (item) {
                        .string => |name| name,
                        else => return self.fail("boundary frameworks must contain names"),
                    };
                    if (!Modules.validName(framework) or std.mem.indexOfScalar(u8, framework, '.') != null) {
                        return self.fail("invalid boundary framework name");
                    }
                    for (frameworks.items) |existing| if (std.mem.eql(u8, existing, framework)) {
                        return self.fail("duplicate boundary framework");
                    };
                    try frameworks.append(self.allocator, framework);
                }
                std.mem.sort([]const u8, frameworks.items, {}, stringLessThan);
            }
            if (frameworks.items.len != 0 and self.target.platform != .macos) {
                return self.fail("boundary frameworks are available only on macOS");
            }
            var libraries: std.ArrayList([]const u8) = .empty;
            if (provider.get("libraries")) |library_value| {
                const array = switch (library_value) {
                    .array => |array| array,
                    else => return self.fail("boundary libraries must be an array of names"),
                };
                for (array.items) |item| {
                    const library = switch (item) {
                        .string => |name| name,
                        else => return self.fail("boundary libraries must contain names"),
                    };
                    if (!validLibraryName(library)) return self.fail("invalid boundary library name");
                    for (libraries.items) |existing| if (std.mem.eql(u8, existing, library)) {
                        return self.fail("duplicate boundary library");
                    };
                    try libraries.append(self.allocator, library);
                }
                std.mem.sort([]const u8, libraries.items, {}, stringLessThan);
            }
            try providers.append(self.allocator, .{
                .name = provider_name,
                .archive = archive,
                .artifact_sha256 = artifactSha256(artifacts, self.target.name(), relative_archive) orelse "",
                .frameworks = try frameworks.toOwnedSlice(self.allocator),
                .libraries = try libraries.toOwnedSlice(self.allocator),
            });
        }
        std.mem.sort(BoundaryProvider, providers.items, {}, boundaryProviderLessThan);
        return providers.toOwnedSlice(self.allocator);
    }

    fn find(self: Resolver, name: []const u8) ?usize {
        for (self.builders.items, 0..) |builder, index| {
            if (builder.package.name) |candidate| if (std.mem.eql(u8, candidate, name)) return index;
        }
        return null;
    }

    fn fail(self: *Resolver, message: []const u8) error{InvalidPackageGraph} {
        self.diagnostic = message;
        return error.InvalidPackageGraph;
    }
};

fn artifactSha256(artifacts: ?std.json.Value, target_name: []const u8, relative_path: []const u8) ?[]const u8 {
    const targets = switch (artifacts orelse return null) {
        .object => |object| object,
        else => return null,
    };
    const entries = switch (targets.get(target_name) orelse return null) {
        .object => |object| object,
        else => return null,
    };
    var iterator = entries.iterator();
    while (iterator.next()) |entry| {
        const artifact = switch (entry.value_ptr.*) {
            .object => |object| object,
            else => continue,
        };
        const path = switch (artifact.get("path") orelse continue) {
            .string => |text| text,
            else => continue,
        };
        if (!std.mem.eql(u8, path, relative_path)) continue;
        return switch (artifact.get("sha256") orelse return null) {
            .string => |text| if (text.len == 64) text else null,
            else => null,
        };
    }
    return null;
}

fn belongsTo(module_name: []const u8, package_name: []const u8) bool {
    return std.mem.eql(u8, module_name, package_name) or
        (module_name.len > package_name.len and std.mem.startsWith(u8, module_name, package_name) and
            module_name[package_name.len] == '.');
}

pub fn validExtensionGrant(package_name: []const u8, grant: []const u8) bool {
    if (grant.len <= package_name.len + 1 or !std.mem.startsWith(u8, grant, package_name) or
        grant[package_name.len] != '.') return false;
    const child = grant[package_name.len + 1 ..];
    return std.mem.eql(u8, child, "*") or
        (Modules.validName(child) and std.mem.indexOfScalar(u8, child, '.') == null);
}

fn allowsExtension(grants: []const []const u8, child: []const u8) bool {
    for (grants) |grant| {
        if (std.mem.eql(u8, grant, child) or std.mem.endsWith(u8, grant, ".*")) return true;
    }
    return false;
}

fn equalStrings(left: []const []const u8, right: []const []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_value, right_value| if (!std.mem.eql(u8, left_value, right_value)) return false;
    return true;
}

fn validSha256(text: []const u8) bool {
    if (text.len != 64) return false;
    for (text) |character| if (!std.ascii.isDigit(character) and !(character >= 'a' and character <= 'f')) return false;
    return true;
}

fn fileSha256(allocator: Allocator, io: Io, path: []const u8) ![]const u8 {
    const source = Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch
        return error.InvalidPackageGraph;
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    return allocator.dupe(u8, &hex);
}

fn validRelativePath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return false;
    }
    return true;
}

fn validLibraryName(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |character| if (!std.ascii.isAlphanumeric(character) and character != '_' and character != '-' and character != '.') return false;
    return true;
}

fn validArchive(io: Io, path: []const u8, target: TargetModule.Target) bool {
    const file = Io.Dir.cwd().openFile(io, path, .{}) catch return false;
    defer file.close(io);
    const stat = file.stat(io) catch return false;
    var signature: [8]u8 = undefined;
    if ((file.readPositionalAll(io, &signature, 0) catch return false) != signature.len or
        !std.mem.eql(u8, &signature, "!<arch>\n")) return false;
    var found_object = false;
    var offset: u64 = signature.len;
    while (offset + 60 <= stat.size) {
        var header: [60]u8 = undefined;
        if ((file.readPositionalAll(io, &header, offset) catch return false) != header.len or
            !std.mem.eql(u8, header[58..60], "`\n")) return false;
        const member_size = std.fmt.parseInt(u64, std.mem.trim(u8, header[48..58], " "), 10) catch return false;
        const data_offset = offset + header.len;
        if (data_offset + member_size > stat.size) return false;
        const raw_name = std.mem.trimEnd(u8, header[0..16], " ");
        var object_offset = data_offset;
        if (std.mem.startsWith(u8, raw_name, "#1/")) {
            const name_size = std.fmt.parseInt(u64, raw_name[3..], 10) catch return false;
            if (name_size > member_size) return false;
            object_offset += name_size;
        }
        var object_header: [20]u8 = undefined;
        if (object_offset + object_header.len <= data_offset + member_size and
            (file.readPositionalAll(io, &object_header, object_offset) catch return false) == object_header.len)
        {
            const matches = if (target.eql(.macos_arm64))
                std.mem.readInt(u32, object_header[0..4], .little) == macho.MH_MAGIC_64 and
                    std.mem.readInt(u32, object_header[4..8], .little) == @as(u32, @bitCast(macho.CPU_TYPE_ARM64))
            else if (target.eql(.linux_x64))
                std.mem.eql(u8, object_header[0..4], "\x7fELF") and object_header[4] == 2 and object_header[5] == 1 and
                    std.mem.readInt(u16, object_header[16..18], .little) == 1 and
                    std.mem.readInt(u16, object_header[18..20], .little) == 62
            else if (target.eql(.windows_x64))
                std.mem.readInt(u16, object_header[0..2], .little) == 0x8664 and
                    std.mem.readInt(u16, object_header[2..4], .little) != 0
            else
                std.mem.readInt(u16, object_header[0..2], .little) == 0xaa64 and
                    std.mem.readInt(u16, object_header[2..4], .little) != 0;
            if (matches) found_object = true;
        }
        offset = data_offset + member_size + (member_size & 1);
    }
    return found_object;
}

fn boundaryProviderLessThan(_: void, left: BoundaryProvider, right: BoundaryProvider) bool {
    return std.mem.lessThan(u8, left.name, right.name);
}

fn exists(io: Io, path: []const u8) !bool {
    _ = Io.Dir.cwd().statFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return false,
        else => |other| return other,
    };
    return true;
}

fn stringLessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}

fn dependencyLessThan(_: void, left: ManifestDependency, right: ManifestDependency) bool {
    return std.mem.lessThan(u8, left.name, right.name);
}

fn writeTestArm64Archive(directory: Io.Dir, io: Io, path: []const u8) !void {
    var archive = [_]u8{' '} ** (8 + 60 + 20);
    @memcpy(archive[0..8], "!<arch>\n");
    @memcpy(archive[8..24], "probe.o/        ");
    @memcpy(archive[8 + 48 .. 8 + 58], "20        ");
    @memcpy(archive[8 + 58 .. 8 + 60], "`\n");
    std.mem.writeInt(u32, archive[68..72], macho.MH_MAGIC_64, .little);
    std.mem.writeInt(u32, archive[72..76], @bitCast(macho.CPU_TYPE_ARM64), .little);
    try directory.writeFile(io, .{ .sub_path = path, .data = &archive });
}

fn writeTestArchive(directory: Io.Dir, io: Io, path: []const u8, target: TargetModule.Target) !void {
    var archive = [_]u8{' '} ** (8 + 60 + 20);
    @memcpy(archive[0..8], "!<arch>\n");
    @memcpy(archive[8..24], "probe.o/        ");
    @memcpy(archive[8 + 48 .. 8 + 58], "20        ");
    @memcpy(archive[8 + 58 .. 8 + 60], "`\n");
    if (target.eql(.linux_x64)) {
        @memcpy(archive[68..72], "\x7fELF");
        archive[72] = 2;
        archive[73] = 1;
        std.mem.writeInt(u16, archive[84..86], 1, .little);
        std.mem.writeInt(u16, archive[86..88], 62, .little);
    } else {
        std.mem.writeInt(u16, archive[68..70], if (target.eql(.windows_x64)) 0x8664 else 0xaa64, .little);
        std.mem.writeInt(u16, archive[70..72], 1, .little);
    }
    try directory.writeFile(io, .{ .sub_path = path, .data = &archive });
}

test "parse exact and caret stable versions" {
    try std.testing.expect((try Constraint.parse("=1.4.1")).accepts(try Version.parse("1.4.1")));
    try std.testing.expect(!(try Constraint.parse("=1.4.1")).accepts(try Version.parse("1.4.2")));
    try std.testing.expect((try Constraint.parse("^1.4.0")).accepts(try Version.parse("1.9.0")));
    try std.testing.expect(!(try Constraint.parse("^1.4.0")).accepts(try Version.parse("2.0.0")));
    try std.testing.expect((try Constraint.parse("^0.2.1")).accepts(try Version.parse("0.2.9")));
    try std.testing.expect((try Constraint.parse("^0.2.1")).accepts(try Version.parse("0.3.0")));
    try std.testing.expect(!(try Constraint.parse("^0.2.1")).accepts(try Version.parse("1.0.0")));
    try std.testing.expectError(error.InvalidVersion, Version.parse("1.2.3-beta"));
}

test "diagnose invalid package extension grants" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "GFX" });

    const cases = [_]struct { source: []const u8, diagnostic: []const u8 }{
        .{
            .source = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{}}",
            .diagnostic = "extensions must be an array of direct child package names",
        },
        .{
            .source = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":[false]}",
            .diagnostic = "an extension grant must be a package name string",
        },
        .{
            .source = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":[\"GFX.UI.Controls\"]}",
            .diagnostic = "an extension grant must name one direct child package or use Parent.*",
        },
        .{
            .source = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":[\"GFX.UI\",\"GFX.UI\"]}",
            .diagnostic = "extension grants must be unique",
        },
        .{
            .source = "{\"extensions\":[]}",
            .diagnostic = "an application manifest cannot declare extensions",
        },
    };
    for (cases) |case| {
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GFX/Package.json", .data = case.source });
        var resolver = Resolver.init(allocator, std.testing.io, null);
        try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(root));
        try std.testing.expectEqualStrings(case.diagnostic, resolver.diagnostic.?);
    }
}

test "parse and apply Silex toolchain requirements before package sources" {
    const bounded = try SilexRequirement.parse(">=0.38.0 <0.41.0");
    try std.testing.expect(bounded.accepts(try Version.parse("0.38.0")));
    try std.testing.expect(bounded.accepts(try Version.parse("0.40.9")));
    try std.testing.expect(!bounded.accepts(try Version.parse("0.37.9")));
    try std.testing.expect(!bounded.accepts(try Version.parse("0.41.0")));
    try std.testing.expect((try SilexRequirement.parse(">=0.38.0")).accepts(try Version.parse("1.0.0")));
    try std.testing.expectError(error.InvalidRequirement, SilexRequirement.parse("^0.38.0"));
    try std.testing.expectError(error.InvalidRequirement, SilexRequirement.parse(">=0.41.0 <0.38.0"));

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Modern/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Modern/Package.json",
        .data =
        \\{"name":"Modern","version":"1.2.0","requires":{"silex":">=0.39.0 <0.42.0"}}
        ,
    });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Modern" });
    var resolver = Resolver.init(allocator, std.testing.io, null);
    resolver.toolchain_version = try Version.parse("0.38.0");
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(root));
    try std.testing.expectEqualStrings(
        "package 'Modern@1.2.0' requires Silex >=0.39.0 <0.42.0, but this toolchain is Silex 0.38.0",
        resolver.diagnostic.?,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Modern/Package.json",
        .data =
        \\{"name":"Modern","version":"1.2.0","requires":{"silex":">=0.38.0 <0.39.0"}}
        ,
    });
    resolver = Resolver.init(allocator, std.testing.io, null);
    resolver.toolchain_version = try Version.parse("0.38.0");
    const graph = try resolver.resolve(root);
    try std.testing.expectEqualStrings("Modern", graph.packages[0].name.?);

    try temporary.dir.createDirPath(std.testing.io, "App");
    try temporary.dir.createDirPath(std.testing.io, "Global/Legacy@1.0.0/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "App/Package.json",
        .data = "{\"dependencies\":{\"Legacy\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/Legacy@1.0.0/Package.json",
        .data = "{\"name\":\"Legacy\",\"version\":\"1.0.0\"}",
    });
    const app = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "App" });
    const global = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Global" });
    resolver = Resolver.init(allocator, std.testing.io, global);
    resolver.toolchain_version = try Version.parse("0.38.0");
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(app));
    try std.testing.expectEqualStrings(
        "installed package 'Legacy@1.0.0' does not declare requires.silex",
        resolver.diagnostic.?,
    );
}

test "resolve a target-private ARM64 archive and reject escaping paths" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Boundary/macos-arm64");
    try writeTestArm64Archive(temporary.dir, std.testing.io, "Bridge/Boundary/macos-arm64/libBridge.a");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data =
        \\{"name":"Bridge","version":"1.0.0","artifacts":{"macos-arm64":{"Bridge":{"path":"Boundary/macos-arm64/libBridge.a","url":"https://example.com/libBridge.a","sha256":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}}},"boundary":{"macos-arm64":{"providers":{"Native":{"archive":"Boundary/macos-arm64/libBridge.a","frameworks":["Metal","Cocoa"]}}}}}
        ,
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Bridge" });
    var resolver = Resolver.initForTarget(allocator, std.testing.io, null, .macos_arm64);
    const graph = try resolver.resolve(base);
    try std.testing.expectEqual(@as(usize, 1), graph.packages[0].boundary_providers.len);
    const provider = graph.packages[0].boundary_providers[0];
    try std.testing.expectEqualStrings("Native", provider.name);
    try std.testing.expect(std.mem.endsWith(u8, provider.archive, "Boundary/macos-arm64/libBridge.a"));
    try std.testing.expectEqualStrings("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", provider.artifact_sha256);
    try std.testing.expectEqualStrings("Cocoa", provider.frameworks[0]);
    try std.testing.expectEqualStrings("Metal", provider.frameworks[1]);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data =
        \\{"name":"Bridge","version":"1.0.0","boundary":{"macos-arm64":{"providers":{"Native":{"archive":"../libBridge.a"}}}}}
        ,
    });
    resolver = Resolver.initForTarget(allocator, std.testing.io, null, .macos_arm64);
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(base));
    try std.testing.expectEqualStrings("boundary archive must stay inside its package", resolver.diagnostic.?);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data =
        \\{"name":"Bridge","version":"1.0.0","boundary":{"macos-arm64":{"providers":{"Native":{"archive":"Boundary/macos-arm64/missing.a"}}}}}
        ,
    });
    resolver = Resolver.initForTarget(allocator, std.testing.io, null, .macos_arm64);
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(base));
    try std.testing.expectEqualStrings(
        "boundary archive is missing; run 'silex install <package-directory>'",
        resolver.diagnostic.?,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Boundary/macos-arm64/invalid.a",
        .data = "not an archive",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data =
        \\{"name":"Bridge","version":"1.0.0","boundary":{"macos-arm64":{"providers":{"Native":{"archive":"Boundary/macos-arm64/invalid.a"}}}}}
        ,
    });
    resolver = Resolver.initForTarget(allocator, std.testing.io, null, .macos_arm64);
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(base));
    try std.testing.expectEqualStrings("boundary archive does not match its target", resolver.diagnostic.?);
}

test "resolve ELF and COFF boundary archives with system libraries" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Boundary/linux-x64");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Boundary/windows-x64");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Boundary/windows-arm64");
    try writeTestArchive(temporary.dir, std.testing.io, "Bridge/Boundary/linux-x64/libBridge.a", .linux_x64);
    try writeTestArchive(temporary.dir, std.testing.io, "Bridge/Boundary/windows-x64/Bridge.lib", .windows_x64);
    try writeTestArchive(temporary.dir, std.testing.io, "Bridge/Boundary/windows-arm64/Bridge.lib", .windows_arm64);
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Bridge" });

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data =
        \\{"name":"Bridge","version":"1.0.0","boundary":{"linux-x64":{"providers":{"Native":{"archive":"Boundary/linux-x64/libBridge.a","libraries":["pthread","dl","m"]}}}}}
        ,
    });
    var resolver = Resolver.initForTarget(allocator, std.testing.io, null, .linux_x64);
    var graph = try resolver.resolve(base);
    try std.testing.expectEqualStrings("dl", graph.packages[0].boundary_providers[0].libraries[0]);
    try std.testing.expectEqualStrings("m", graph.packages[0].boundary_providers[0].libraries[1]);
    try std.testing.expectEqualStrings("pthread", graph.packages[0].boundary_providers[0].libraries[2]);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data =
        \\{"name":"Bridge","version":"1.0.0","boundary":{"windows-x64":{"providers":{"Native":{"archive":"Boundary/windows-x64/Bridge.lib","libraries":["user32"]}}}}}
        ,
    });
    resolver = Resolver.initForTarget(allocator, std.testing.io, null, .windows_x64);
    graph = try resolver.resolve(base);
    try std.testing.expectEqualStrings("user32", graph.packages[0].boundary_providers[0].libraries[0]);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data =
        \\{"name":"Bridge","version":"1.0.0","boundary":{"windows-arm64":{"providers":{"Native":{"archive":"Boundary/windows-arm64/Bridge.lib"}}}}}
        ,
    });
    resolver = Resolver.initForTarget(allocator, std.testing.io, null, .windows_arm64);
    graph = try resolver.resolve(base);
    try std.testing.expectEqual(@as(usize, 1), graph.packages[0].boundary_providers.len);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data =
        \\{"name":"Bridge","version":"1.0.0","boundary":{"windows-x64":{"providers":{"Native":{"archive":"Boundary/windows-arm64/Bridge.lib"}}}}}
        ,
    });
    resolver = Resolver.initForTarget(allocator, std.testing.io, null, .windows_x64);
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(base));
    try std.testing.expectEqualStrings("boundary archive does not match its target", resolver.diagnostic.?);
}

test "prefer compatible sibling and otherwise select newest global version" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "App/Math/Module");
    try temporary.dir.createDirPath(std.testing.io, "Global/Math@1.5.0/Module");
    try temporary.dir.createDirPath(std.testing.io, "Global/Math@1.9.0/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "App/Package.json",
        .data = "{\"dependencies\":{\"Math\":\"^1.4.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "App/Math/Package.json",
        .data = "{\"name\":\"Math\",\"version\":\"1.4.1\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/Math@1.5.0/Package.json",
        .data = "{\"name\":\"Math\",\"version\":\"1.5.0\",\"requires\":{\"silex\":\">=0.38.0 <0.39.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/Math@1.9.0/Package.json",
        .data = "{\"name\":\"Math\",\"version\":\"1.9.0\",\"requires\":{\"silex\":\">=0.39.0 <0.40.0\"}}",
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const app = try std.fs.path.join(allocator, &.{ base, "App" });
    const global = try std.fs.path.join(allocator, &.{ base, "Global" });
    var resolver = Resolver.init(allocator, std.testing.io, global);
    var graph = try resolver.resolve(app);
    try std.testing.expectEqualStrings("Math", graph.packages[1].name.?);
    try std.testing.expect(graph.packages[1].version.?.eql(try Version.parse("1.4.1")));

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "App/Package.json",
        .data = "{\"dependencies\":{\"Math\":\"^1.5.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "App/Math/Package.json",
        .data = "{\"name\":\"Math\",\"version\":\"1.4.1\"}",
    });
    resolver = Resolver.init(allocator, std.testing.io, global);
    graph = try resolver.resolve(app);
    try std.testing.expect(graph.packages[1].version.?.eql(try Version.parse("1.5.0")));
}

test "discover packages beside the source directory parent" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Sandbox");
    try temporary.dir.createDirPath(std.testing.io, "Packages/GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "Packages/STD/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Packages/GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"0.11.0\",\"dependencies\":{\"STD\":\"^0.7.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Packages/STD/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"0.8.0\"}",
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const sandbox = try std.fs.path.join(allocator, &.{ base, "Sandbox" });
    var resolver = Resolver.init(allocator, std.testing.io, null);
    const graph = try resolver.resolve(sandbox);
    try std.testing.expectEqual(@as(usize, 3), graph.packages.len);
    try std.testing.expectEqualStrings("GFX", graph.packages[1].name.?);
    try std.testing.expect(std.mem.endsWith(u8, graph.packages[1].root, "Packages/GFX"));
    try std.testing.expectEqualStrings("STD", graph.packages[2].name.?);
    try std.testing.expectEqual(@as(usize, 2), graph.packages[0].dependencies.len);
}

test "discover shared packages above a nested application" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Sandbox/Lighting");
    try temporary.dir.createDirPath(std.testing.io, "Packages/GFX/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Packages/GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}",
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const application = try std.fs.path.join(allocator, &.{ base, "Sandbox", "Lighting" });
    var resolver = Resolver.init(allocator, std.testing.io, null);
    const graph = try resolver.resolve(application);
    try std.testing.expectEqual(@as(usize, 2), graph.packages.len);
    try std.testing.expectEqualStrings("GFX", graph.packages[1].name.?);
    try std.testing.expect(std.mem.endsWith(u8, graph.packages[1].root, "Packages/GFX"));
}

test "reject path fields conflicts and package cycles" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"Math\":{\"path\":\"../Math\"}}}",
    });
    var resolver = Resolver.init(allocator, std.testing.io, null);
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(base));

    try temporary.dir.createDirPath(std.testing.io, "A/Module");
    try temporary.dir.createDirPath(std.testing.io, "B/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"A\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "A/Package.json",
        .data = "{\"name\":\"A\",\"version\":\"1.0.0\",\"dependencies\":{\"B\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "B/Package.json",
        .data = "{\"name\":\"B\",\"version\":\"1.0.0\",\"dependencies\":{\"A\":\"=1.0.0\"}}",
    });
    resolver = Resolver.init(allocator, std.testing.io, null);
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(base));
    try std.testing.expectEqualStrings("package dependency cycle", resolver.diagnostic.?);
}

test "resolve qualified identities literally from an injected global root" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "App");
    try temporary.dir.createDirPath(std.testing.io, "Global/Silex.Bootstrap@0.1.7/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "App/Package.json",
        .data = "{\"dependencies\":{\"Silex.Bootstrap\":\"^0.1.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/Silex.Bootstrap@0.1.7/Package.json",
        .data = "{\"name\":\"Silex.Bootstrap\",\"version\":\"0.1.7\",\"requires\":{\"silex\":\">=0.38.0 <0.39.0\"}}",
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const app = try std.fs.path.join(allocator, &.{ base, "App" });
    const global = try std.fs.path.join(allocator, &.{ base, "Global" });
    var resolver = Resolver.init(allocator, std.testing.io, global);
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(app));
    try std.testing.expectEqualStrings(
        "package 'Silex.Bootstrap' requires parent package 'Silex' to authorize its namespace",
        resolver.diagnostic.?,
    );

    try temporary.dir.createDirPath(std.testing.io, "Global/Silex@0.1.0/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "App/Package.json",
        .data = "{\"dependencies\":{\"Silex\":\"^0.1.0\",\"Silex.Bootstrap\":\"^0.1.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/Silex@0.1.0/Package.json",
        .data = "{\"name\":\"Silex\",\"version\":\"0.1.0\",\"requires\":{\"silex\":\">=0.38.0 <0.39.0\"},\"extensions\":[\"Silex.Bootstrap\"]}",
    });
    try temporary.dir.createDirPath(std.testing.io, "Global/Silex@0.1.0/.silex");
    const silex_manifest = try std.fs.path.join(allocator, &.{ global, "Silex@0.1.0", "Package.json" });
    const manifest_sha256 = try fileSha256(allocator, std.testing.io, silex_manifest);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/Silex@0.1.0/.silex/registry.json",
        .data = try std.fmt.allocPrint(
            allocator,
            "{{\"schema\":1,\"name\":\"Silex\",\"version\":\"0.1.0\",\"repository\":\"Matanek/Silex\",\"archive_sha256\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"manifest_sha256\":\"{s}\",\"extensions\":[\"Silex.Bootstrap\"]}}",
            .{manifest_sha256},
        ),
    });
    resolver = Resolver.init(allocator, std.testing.io, global);
    const graph = try resolver.resolve(app);
    try std.testing.expectEqualStrings("Silex.Bootstrap", graph.packages[2].name.?);
    try std.testing.expect(std.mem.endsWith(u8, graph.packages[2].root, "Silex.Bootstrap@0.1.7"));
}

test "reject incompatible graph constraints missing packages and legacy manifests" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"Missing\":\"=1.0.0\"}}",
    });
    var resolver = Resolver.init(allocator, std.testing.io, null);
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(base));
    try std.testing.expectEqualStrings(
        "package 'application' requires 'Missing' =1.0.0, but no package named 'Missing' is available",
        resolver.diagnostic.?,
    );

    try temporary.dir.createDirPath(std.testing.io, "Missing/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Missing/Package.json",
        .data = "{\"name\":\"Missing\",\"version\":\"1.5.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"Missing\":\"=2.0.0\"}}",
    });
    resolver = Resolver.init(allocator, std.testing.io, null);
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(base));
    try std.testing.expectEqualStrings(
        "package 'application' requires 'Missing' =2.0.0, but available version 1.5.0 is incompatible",
        resolver.diagnostic.?,
    );

    try temporary.dir.createDirPath(std.testing.io, "A/Module");
    try temporary.dir.createDirPath(std.testing.io, "B/Module");
    try temporary.dir.createDirPath(std.testing.io, "Common/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"A\":\"=1.0.0\",\"B\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "A/Package.json",
        .data = "{\"name\":\"A\",\"version\":\"1.0.0\",\"dependencies\":{\"Common\":\"^1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "B/Package.json",
        .data = "{\"name\":\"B\",\"version\":\"1.0.0\",\"dependencies\":{\"Common\":\"=2.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Common/Package.json",
        .data = "{\"name\":\"Common\",\"version\":\"1.5.0\"}",
    });
    resolver = Resolver.init(allocator, std.testing.io, null);
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(base));
    try std.testing.expectEqualStrings(
        "package 'B@1.0.0' requires 'Common' =2.0.0, but version 1.5.0 is already selected",
        resolver.diagnostic.?,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "@Module.json",
        .data = "{}",
    });
    resolver = Resolver.init(allocator, std.testing.io, null);
    try std.testing.expectError(error.InvalidPackageGraph, resolver.resolve(base));
    try std.testing.expectEqualStrings(
        "legacy package manifests are not supported; use Package.json",
        resolver.diagnostic.?,
    );
}
