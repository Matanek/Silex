const std = @import("std");
const build_options = @import("build_options");
const Artifacts = @import("Artifacts.zig");
const Boundary = @import("Boundary.zig");
const Cli = @import("Cli.zig");
const CliProgress = @import("CliProgress.zig");
const CompilationCache = @import("CompilationCache.zig");
const Lower = @import("Arm64/Lower.zig");
const Arm64Encoder = @import("Arm64/Encoder.zig");
const Arm64Object = @import("Arm64/Object.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const Lsp = @import("Lsp/Server.zig");
const MachO = @import("MacOS/MachO.zig");
const MachOObject = @import("MacOS/Object.zig");
const MacOSLink = @import("MacOS/Link.zig");
const Elf = @import("Linux/Elf.zig");
const X64Encoder = @import("X64/Encoder.zig");
const X64Object = @import("X64/Object.zig");
const PE = @import("Windows/PE.zig");
const WindowsImports = @import("Windows/Imports.zig");
const NativeLink = @import("NativeLink.zig");
const ReleaseOptimizer = @import("Optimize/Release.zig");
const Project = @import("Project.zig");
const ProjectPaths = @import("Project/Paths.zig");
const Packages = @import("Packages.zig");
const PackageRegistry = @import("PackageRegistry.zig");
const PackagePublish = @import("PackagePublish.zig");
const GitHubPublish = @import("GitHubPublish.zig");
const PackageStore = @import("PackageStore.zig");
const NativeTestRunner = @import("NativeTestRunner.zig");
const TestDiscovery = @import("TestDiscovery.zig");
const TargetModule = @import("Target.zig");
const ToolchainSetup = @import("ToolchainSetup.zig");
const EmbeddedFiles = @import("EmbeddedFiles.zig");
const ShaderAssets = @import("ShaderAssets.zig");
const SelfUpdate = @import("SelfUpdate.zig");

const Io = std.Io;

const usage =
    \\Usage: silex run <source.sx> [-d|--debug|-r|--release] [-n|--nocache] [--emit-ir]
    \\       silex interpret <source.sx> [-n|--nocache] [--emit-ir]
    \\       silex test <source.sx|directory> [-n|--nocache] [--emit-ir]
    \\       silex compile <source.sx> [--target <target>] [-d|--debug|-r|--release] [-n|--nocache] -o|--output <executable>
    \\       silex install <package|package-directory> [--target <target>]
    \\       silex release <package-directory>
    \\       silex publish <package-directory>
    \\       silex link <package-directory> [--workspace <directory>] [--target <target>]
    \\       silex unlink <package-name> [--workspace <directory>]
    \\       silex packages
    \\       silex packages resolve [source.sx|project-directory]
    \\       silex setup
    \\       silex update
    \\       silex targets
    \\       silex version
    \\       silex lsp
    \\
    \\Builds and runs native Silex programs, manages package releases, executes
    \\portable IR through the reference interpreter, or serves editor requests.
    \\
;

test {
    _ = Artifacts;
    _ = MachOObject;
    _ = Arm64Object;
    _ = MacOSLink;
    _ = X64Object;
    _ = NativeLink;
    _ = ToolchainSetup;
    _ = EmbeddedFiles;
    _ = ShaderAssets;
    _ = CliProgress;
    _ = PackageStore;
    _ = PackageRegistry;
    _ = PackagePublish;
    _ = GitHubPublish;
    _ = SelfUpdate;
}

pub fn main(init: std.process.Init) u8 {
    return runCli(init) catch |err| {
        std.debug.print("silex: error: {t}\n", .{err});
        return 1;
    };
}

fn runCli(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len == 1 or (args.len == 2 and isHelp(args[1]))) {
        try Io.File.stdout().writeStreamingAll(init.io, usage);
        return 0;
    }
    if (args.len == 2 and isVersion(args[1])) return printVersion(init.io);
    if (std.mem.eql(u8, args[1], "run")) return runSource(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "interpret")) return interpretSource(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "test")) return testSource(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "compile")) return compileNative(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "install")) return installPackage(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "release")) return releasePackage(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "publish")) return publishPackage(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "link")) return linkPackage(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "unlink")) return unlinkPackage(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "packages")) return listPackages(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "setup")) return setupToolchain(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "update")) return updateSilex(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "targets")) return listTargets(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "version")) {
        if (args.len != 2) {
            std.debug.print("silex: 'version' does not accept arguments\n", .{});
            return 1;
        }
        return printVersion(init.io);
    }
    if (std.mem.eql(u8, args[1], "lsp")) return runLanguageServer(init, args[2..]);
    std.debug.print("silex: unknown command '{s}'\n\n{s}", .{ args[1], usage });
    return 1;
}

fn updateSilex(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    if (args.len != 0) {
        std.debug.print("silex: 'update' does not accept arguments\n", .{});
        return 1;
    }
    var updater = SelfUpdate.Updater.init(allocator, init.gpa, init.io);
    const result = updater.update(init.environ_map) catch |err| switch (err) {
        error.InvalidUpdate => {
            std.debug.print("silex: cannot update: {s}\n", .{updater.diagnostic orelse "invalid update"});
            return 1;
        },
        else => return err,
    };
    if (result == .scheduled) {
        std.debug.print("silex: update scheduled; installation will finish after this process exits\n", .{});
    }
    return 0;
}

fn releasePackage(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const options = switch (Cli.parsePackage(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("release", diagnostic);
            return 1;
        },
    };
    var publisher = PackagePublish.Publisher.init(allocator, init.gpa, init.io);
    const result = publisher.release(options.package) catch |err| switch (err) {
        error.InvalidPublication, error.InvalidPackageGraph => {
            std.debug.print("silex: cannot release package: {s}\n", .{publisher.diagnostic orelse "invalid release"});
            return 1;
        },
        else => return err,
    };
    std.debug.print(
        "silex: {s} {s}@{d}.{d}.{d} at {s}\n",
        .{ if (result.created) "released" else "already released", result.name, result.version.major, result.version.minor, result.version.patch, result.url },
    );
    return 0;
}

fn publishPackage(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const options = switch (Cli.parsePackage(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("publish", diagnostic);
            return 1;
        },
    };
    const explicit_registry = init.environ_map.get("SILEX_REGISTRY_SOURCE");
    const registry_root = explicit_registry orelse (try globalRegistryRoot(allocator, init.environ_map) orelse {
        std.debug.print("silex: cannot publish package: cannot locate the user home directory\n", .{});
        return 1;
    });
    var publisher = PackagePublish.Publisher.init(allocator, init.gpa, init.io);
    const result = if (explicit_registry != null)
        publisher.prepare(options.package, registry_root)
    else
        publisher.prepareManaged(options.package, registry_root);
    const prepared = result catch |err| switch (err) {
        error.InvalidPublication, error.InvalidPackageGraph => {
            std.debug.print("silex: cannot publish package: {s}\n", .{publisher.diagnostic orelse "invalid publication"});
            return 1;
        },
        else => return err,
    };
    if (explicit_registry != null) {
        std.debug.print(
            "silex: prepared {s}@{d}.{d}.{d} for registry review in {s}\n",
            .{ prepared.name, prepared.version.major, prepared.version.minor, prepared.version.patch, prepared.manifest_path },
        );
        return 0;
    }
    const authorization_path = try globalGitHubAuthorizationPath(allocator, init.environ_map) orelse {
        std.debug.print("silex: cannot publish package: cannot locate the user home directory\n", .{});
        return 1;
    };
    var github = GitHubPublish.Publisher.init(allocator, init.gpa, init.io);
    const submitted = github.submit(registry_root, authorization_path, prepared, init.environ_map) catch |err| switch (err) {
        error.InvalidPublication => {
            std.debug.print("silex: cannot publish package: {s}\n", .{github.diagnostic orelse "GitHub publication failed"});
            return 1;
        },
        else => return err,
    };
    std.debug.print(
        "silex: published {s}@{d}.{d}.{d} for registry review at {s}\n",
        .{ prepared.name, prepared.version.major, prepared.version.minor, prepared.version.patch, submitted.pull_request_url },
    );
    return 0;
}

fn setupToolchain(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    if (args.len != 0) {
        std.debug.print("silex: 'setup' does not accept arguments\n", .{});
        return 1;
    }
    const host = TargetModule.Target.host() orelse {
        std.debug.print("silex: Shadercross is unavailable for this host\n", .{});
        return 1;
    };
    const root = try globalToolchainRoot(allocator, init.environ_map) orelse {
        std.debug.print("silex: cannot locate the user home directory for toolchain setup\n", .{});
        return 1;
    };
    var installer = Artifacts.Installer.init(allocator, init.gpa, init.io);
    for ([_]Artifacts.ToolSpec{ ToolchainSetup.shadercross(host), ToolchainSetup.linker(host) }) |tool| {
        const summary = installer.installTool(root, tool) catch |err| switch (err) {
            error.InvalidManifest => {
                std.debug.print(
                    "silex: cannot install {s}: {s}\n",
                    .{ tool.name, installer.diagnostic orelse "invalid toolchain artifact" },
                );
                return 1;
            },
            else => return err,
        };
        if (summary.installed == 0) {
            std.debug.print("silex: {s} is already installed for {s}\n", .{ tool.name, host.name() });
        } else {
            std.debug.print("silex: installed {s} for {s}\n", .{ tool.name, host.name() });
        }
    }
    return 0;
}

fn installPackage(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const options = switch (Cli.parseInstall(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("install", diagnostic);
            return 1;
        },
    };
    const target = options.target orelse TargetModule.Target.host() orelse {
        std.debug.print("silex: 'install' requires --target on an unrecognized host\n", .{});
        return 1;
    };
    const packages_root = try globalPackagesRoot(allocator, init.environ_map) orelse {
        std.debug.print("silex: cannot locate the user home directory for package installation\n", .{});
        return 1;
    };
    var store = PackageStore.Manager.init(allocator, init.gpa, init.io, packages_root);
    const result = try installPackageOperand(
        init,
        allocator,
        &store,
        packages_root,
        options.package_path,
        target,
    ) orelse return 1;
    std.debug.print("silex: {s} {s}@{d}.{d}.{d} in {s}\n", .{
        if (result.installed) "installed" else "already installed",
        result.package.name,
        result.package.version.major,
        result.package.version.minor,
        result.package.version.patch,
        result.destination,
    });
    return 0;
}

fn installPackageOperand(
    init: std.process.Init,
    allocator: std.mem.Allocator,
    store: *PackageStore.Manager,
    packages_root: []const u8,
    operand: []const u8,
    target: TargetModule.Target,
) !?PackageStore.InstallResult {
    const status = Io.Dir.cwd().statFile(init.io, operand, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => null,
        else => return err,
    };
    if (status) |found| {
        if (found.kind != .directory) {
            std.debug.print("silex: package source '{s}' is not a directory\n", .{operand});
            return null;
        }
        return store.install(operand, target) catch |err| switch (err) {
            error.InvalidPackageStore => {
                std.debug.print("silex: cannot install package: {s}\n", .{store.diagnostic orelse "invalid package"});
                return null;
            },
            else => return err,
        };
    }
    if (looksLikePath(operand)) {
        std.debug.print("silex: cannot locate package directory '{s}'\n", .{operand});
        return null;
    }

    const request = PackageRegistry.Request.parse(operand) catch {
        std.debug.print("silex: invalid package request '{s}'; expected Name or Name@MAJOR.MINOR.PATCH\n", .{operand});
        return null;
    };
    const silex_root = std.fs.path.dirname(packages_root) orelse {
        std.debug.print("silex: invalid user package store\n", .{});
        return null;
    };
    const cache_root = try std.fs.path.join(allocator, &.{ silex_root, "cache", "registry" });
    var registry = PackageRegistry.Client.init(allocator, init.gpa, init.io, cache_root);
    const location = init.environ_map.get("SILEX_REGISTRY") orelse PackageRegistry.default_location;
    const registry_index = registry.load(location) catch |err| switch (err) {
        error.InvalidRegistry => {
            std.debug.print("silex: cannot use package registry: {s}\n", .{registry.diagnostic orelse "invalid registry"});
            return null;
        },
        else => return err,
    };
    return registry.install(
        registry_index,
        request,
        Packages.Version.parse(build_options.version) catch unreachable,
        target,
        store,
    ) catch |err| switch (err) {
        error.InvalidRegistry => {
            std.debug.print("silex: cannot install package: {s}\n", .{registry.diagnostic orelse "cannot install registry package"});
            return null;
        },
        else => return err,
    };
}

fn looksLikePath(text: []const u8) bool {
    return std.fs.path.isAbsolute(text) or
        std.mem.startsWith(u8, text, ".") or
        std.mem.indexOfAny(u8, text, "/\\") != null;
}

fn linkPackage(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const options = switch (Cli.parseLink(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("link", diagnostic);
            return 1;
        },
    };
    const packages_root = try globalPackagesRoot(allocator, init.environ_map) orelse {
        std.debug.print("silex: cannot locate the user home directory for package links\n", .{});
        return 1;
    };
    const target = options.target orelse TargetModule.Target.host() orelse {
        std.debug.print("silex: 'link' requires --target on an unrecognized host\n", .{});
        return 1;
    };
    var store = PackageStore.Manager.init(allocator, init.gpa, init.io, packages_root);
    const result = (if (options.workspace) |workspace|
        store.linkWorkspace(options.package_path, workspace, target)
    else
        store.link(options.package_path, target)) catch |err| switch (err) {
        error.InvalidPackageStore => {
            std.debug.print("silex: cannot link package: {s}\n", .{store.diagnostic orelse "invalid package"});
            return 1;
        },
        else => return err,
    };
    std.debug.print("silex: linked {s}@{d}.{d}.{d} to {s}{s}\n", .{
        result.package.name,
        result.package.version.major,
        result.package.version.minor,
        result.package.version.patch,
        result.source,
        if (options.workspace != null) " for this workspace" else "",
    });
    return 0;
}

fn unlinkPackage(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const options = switch (Cli.parseUnlink(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("unlink", diagnostic);
            return 1;
        },
    };
    const packages_root = try globalPackagesRoot(allocator, init.environ_map) orelse {
        std.debug.print("silex: cannot locate the user home directory for package links\n", .{});
        return 1;
    };
    var store = PackageStore.Manager.init(allocator, init.gpa, init.io, packages_root);
    const removed = (if (options.workspace) |workspace|
        store.unlinkWorkspace(options.package, workspace)
    else
        store.unlink(options.package)) catch |err| switch (err) {
        error.InvalidPackageStore => {
            std.debug.print("silex: cannot unlink package: {s}\n", .{store.diagnostic orelse "invalid package name"});
            return 1;
        },
        else => return err,
    };
    if (!removed) {
        std.debug.print("silex: package '{s}' is not linked\n", .{options.package});
        return 1;
    }
    std.debug.print("silex: unlinked {s}\n", .{options.package});
    return 0;
}

fn listPackages(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const options = switch (Cli.parsePackages(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("packages", diagnostic);
            return 1;
        },
    };
    return switch (options.action) {
        .inventory => listAvailablePackages(init, allocator),
        .resolve => |project_path| listResolvedPackages(init, allocator, project_path),
    };
}

const AvailablePackage = struct {
    name: []const u8,
    version: []const u8,
    parsed_version: Packages.Version,
    origin: Packages.Origin,
    source: []const u8,
};

fn listAvailablePackages(init: std.process.Init, allocator: std.mem.Allocator) !u8 {
    const packages_root = try globalPackagesRoot(allocator, init.environ_map) orelse {
        try Io.File.stdout().writeStreamingAll(init.io, "No global packages available.\n");
        return 0;
    };
    var available: std.ArrayList(AvailablePackage) = .empty;
    try appendUserLinks(allocator, init.io, packages_root, &available);
    try appendInstalledPackages(allocator, init.io, packages_root, &available);
    std.mem.sort(AvailablePackage, available.items, {}, availablePackageLessThan);

    var output: std.ArrayList(u8) = .empty;
    for (available.items) |package| try output.appendSlice(
        allocator,
        try std.fmt.allocPrint(allocator, "{s} {s} {s} {s}\n", .{
            package.name,
            package.version,
            package.origin.label(),
            package.source,
        }),
    );
    if (output.items.len == 0) try output.appendSlice(allocator, "No global packages available.\n");
    try Io.File.stdout().writeStreamingAll(init.io, output.items);
    return 0;
}

fn appendUserLinks(
    allocator: std.mem.Allocator,
    io: Io,
    packages_root: []const u8,
    available: *std.ArrayList(AvailablePackage),
) !void {
    const silex_root = std.fs.path.dirname(packages_root) orelse return;
    const links_root = try std.fs.path.join(allocator, &.{ silex_root, "links" });
    var directory = Io.Dir.cwd().openDir(io, links_root, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return,
        else => |other| return other,
    };
    defer directory.close(io);
    const Link = struct { path: []const u8 };
    const Identity = struct { name: ?[]const u8 = null, version: ?[]const u8 = null };
    var iterator = directory.iterateAssumeFirstIteration();
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".json")) continue;
        const name = entry.name[0 .. entry.name.len - ".json".len];
        const link_path = try std.fs.path.join(allocator, &.{ links_root, entry.name });
        const link_source = Io.Dir.cwd().readFileAlloc(io, link_path, allocator, .limited(64 * 1024)) catch continue;
        const link = std.json.parseFromSliceLeaky(Link, allocator, link_source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = false,
        }) catch continue;
        const manifest_path = try std.fs.path.join(allocator, &.{ link.path, "Package.json" });
        const manifest_source = Io.Dir.cwd().readFileAlloc(io, manifest_path, allocator, .limited(1024 * 1024)) catch continue;
        const identity = std.json.parseFromSliceLeaky(Identity, allocator, manifest_source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = true,
        }) catch continue;
        const version = identity.version orelse continue;
        if (identity.name) |manifest_name| if (!std.mem.eql(u8, manifest_name, name)) continue;
        const parsed_version = Packages.Version.parse(version) catch continue;
        try available.append(allocator, .{
            .name = try allocator.dupe(u8, name),
            .version = version,
            .parsed_version = parsed_version,
            .origin = .user_link,
            .source = link.path,
        });
    }
}

fn appendInstalledPackages(
    allocator: std.mem.Allocator,
    io: Io,
    packages_root: []const u8,
    available: *std.ArrayList(AvailablePackage),
) !void {
    var directory = Io.Dir.cwd().openDir(io, packages_root, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return,
        else => |other| return other,
    };
    defer directory.close(io);
    var iterator = directory.iterateAssumeFirstIteration();
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .directory) continue;
        const separator = std.mem.lastIndexOfScalar(u8, entry.name, '@') orelse continue;
        if (separator == 0 or separator + 1 == entry.name.len) continue;
        const name = entry.name[0..separator];
        const version = entry.name[separator + 1 ..];
        const parsed_version = Packages.Version.parse(version) catch continue;
        try available.append(allocator, .{
            .name = try allocator.dupe(u8, name),
            .version = try allocator.dupe(u8, version),
            .parsed_version = parsed_version,
            .origin = .installed,
            .source = try std.fs.path.join(allocator, &.{ packages_root, entry.name }),
        });
    }
}

fn availablePackageLessThan(_: void, left: AvailablePackage, right: AvailablePackage) bool {
    const name_order = std.mem.order(u8, left.name, right.name);
    if (name_order != .eq) return name_order == .lt;
    if (left.origin != right.origin) return left.origin == .user_link;
    return left.parsed_version.order(right.parsed_version) == .gt;
}

fn listResolvedPackages(
    init: std.process.Init,
    allocator: std.mem.Allocator,
    project_path: []const u8,
) !u8 {
    const canonical = Io.Dir.cwd().realPathFileAlloc(init.io, project_path, allocator) catch |err| {
        std.debug.print("silex: cannot locate project path '{s}': {t}\n", .{ project_path, err });
        return 1;
    };
    const input_stat = Io.Dir.cwd().statFile(init.io, canonical, .{}) catch |err| {
        std.debug.print("silex: cannot inspect project path '{s}': {t}\n", .{ project_path, err });
        return 1;
    };
    const input = if (input_stat.kind == .directory)
        try std.fs.path.join(allocator, &.{ canonical, "__packages__.sx" })
    else
        canonical;
    const project_root = try ProjectPaths.findRoot(allocator, init.io, input);
    var resolver = Packages.Resolver.initForTarget(
        allocator,
        init.io,
        try globalPackagesRoot(allocator, init.environ_map),
        TargetModule.Target.host() orelse .macos_arm64,
    );
    const graph = resolver.resolve(project_root) catch |err| switch (err) {
        error.InvalidPackageGraph => {
            std.debug.print("silex: cannot resolve packages: {s}\n", .{resolver.diagnostic orelse "invalid package graph"});
            return 1;
        },
        else => return err,
    };
    var output: std.ArrayList(u8) = .empty;
    for (graph.packages[1..]) |package| {
        const version = package.version.?;
        try output.appendSlice(
            allocator,
            try std.fmt.allocPrint(allocator, "{s} {d}.{d}.{d} {s} {s}\n", .{
                package.name.?,
                version.major,
                version.minor,
                version.patch,
                package.origin.label(),
                package.root,
            }),
        );
    }
    if (output.items.len == 0) try output.appendSlice(allocator, "No packages resolved.\n");
    try Io.File.stdout().writeStreamingAll(init.io, output.items);
    return 0;
}

fn testSource(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const options = switch (Cli.parseInterpret(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("test", diagnostic);
            return 1;
        },
    };
    if (options.cache) {
        CompilationCache.maintain(allocator, init.io);
        defer CompilationCache.maintainAfterMutation(allocator, init.io);
    }
    const target = TargetModule.Target.host() orelse {
        std.debug.print("silex: 'test' requires a recognized host target\n", .{});
        return 1;
    };
    const input_stat = Io.Dir.cwd().statFile(init.io, options.source_path, .{}) catch |err| {
        std.debug.print("silex: cannot inspect test path '{s}': {t}\n", .{ options.source_path, err });
        return 1;
    };
    const directory_input = input_stat.kind == .directory;
    const sources = TestDiscovery.sources(allocator, init.io, options.source_path, target) catch |err| switch (err) {
        error.InvalidTestPath => {
            std.debug.print("silex: test path must be a .sx source file or a directory\n", .{});
            return 1;
        },
        else => return err,
    };
    const packages_root = try globalPackagesRoot(allocator, init.environ_map);
    const linker_path = try nativeLinkerPath(allocator, init.io, init.environ_map, target);
    const native_target = target.eql(.macos_arm64) or target.eql(.linux_x64) or target.eql(.windows_x64);
    var passed: usize = 0;
    var failed: usize = 0;
    var source_errors: usize = 0;
    for (sources) |source_path| {
        var source_arena = std.heap.ArenaAllocator.init(init.gpa);
        defer source_arena.deinit();
        const source_allocator = source_arena.allocator();
        var compiler = Project.Compiler.initWithPackagesAndCache(source_allocator, init.io, packages_root, options.cache);
        compiler.target = target;
        try configureShaderCompiler(&compiler, source_allocator, init.environ_map);
        const compilation = compiler.compileTests(source_path) catch |err| switch (err) {
            error.InvalidSource => {
                printSourceDiagnostic(compiler, source_path);
                source_errors += 1;
                continue;
            },
            else => {
                std.debug.print("silex: cannot compile tests in '{s}': {t}\n", .{ source_path, err });
                source_errors += 1;
                continue;
            },
        };
        if (options.emit_ir) {
            try Io.File.stdout().writeStreamingAll(init.io, try Ir.writeText(source_allocator, compilation.ir));
        }
        const native_program = if (native_target)
            NativeTestRunner.lower(
                source_allocator,
                init.io,
                compilation.ir,
                compilation.boundaries,
                options.cache,
            ) catch |err| native: {
                std.debug.print("silex: native test backend cannot lower '{s}': {t}\n", .{ source_path, err });
                source_errors += 1;
                break :native null;
            }
        else
            null;
        if (native_target and native_program == null) continue;
        const boundary_providers = try requiredBoundaryProviders(
            source_allocator,
            compilation.boundaries,
            compilation.packages,
        );
        if (native_program == null) {
            var executable = true;
            for (compilation.boundaries) |boundary| {
                if (Interpreter.supportsBoundary(boundary)) continue;
                std.debug.print(
                    "silex: '{s}' cannot execute foreign function '{s}' from '{s}'\n",
                    .{ source_path, boundary.source_name, boundary.provider },
                );
                executable = false;
                break;
            }
            if (!executable) {
                source_errors += 1;
                continue;
            }
        }

        const display_path = if (directory_input) relativeTestPath(options.source_path, source_path) else source_path;
        for (compilation.tests) |case| {
            const case_name = case.name orelse try std.fmt.allocPrint(source_allocator, "test at line {d}", .{case.position.line});
            const label = if (directory_input)
                try std.fmt.allocPrint(source_allocator, "{s} :: {s}", .{ display_path, case_name })
            else
                case_name;
            const succeeded = if (native_program) |machine| succeeded: {
                const result = NativeTestRunner.execute(
                    source_allocator,
                    init.io,
                    target,
                    linker_path,
                    machine,
                    case.function,
                    source_path,
                    compilation.files,
                    boundary_providers,
                    options.cache,
                ) catch |err| {
                    failed += 1;
                    std.debug.print("silex: cannot execute native test '{s}': {t}\n", .{ label, err });
                    try Io.File.stdout().writeStreamingAll(init.io, try std.fmt.allocPrint(source_allocator, "FAILED - {s}\n", .{label}));
                    continue;
                };
                try Io.File.stdout().writeStreamingAll(init.io, result.stdout);
                try Io.File.stderr().writeStreamingAll(init.io, result.stderr);
                break :succeeded switch (result.term) {
                    .exited => |code| code == 0,
                    .signal => |signal| signaled: {
                        std.debug.print("silex: native test '{s}' terminated by signal {d}\n", .{ label, @intFromEnum(signal) });
                        break :signaled false;
                    },
                    .stopped => |signal| stopped: {
                        std.debug.print("silex: native test '{s}' stopped by signal {d}\n", .{ label, @intFromEnum(signal) });
                        break :stopped false;
                    },
                    .unknown => |status| unknown: {
                        std.debug.print("silex: native test '{s}' terminated with unknown status {d}\n", .{ label, status });
                        break :unknown false;
                    },
                };
            } else succeeded: {
                const result = Interpreter.runFunctionCaptureWithBoundaries(
                    source_allocator,
                    init.io,
                    compilation.ir,
                    case.function,
                    compilation.boundaries,
                ) catch |err| {
                    failed += 1;
                    std.debug.print("silex: test runtime error in '{s}': {t}\n", .{ label, err });
                    try Io.File.stdout().writeStreamingAll(init.io, try std.fmt.allocPrint(source_allocator, "FAILED - {s}\n", .{label}));
                    continue;
                };
                try Io.File.stdout().writeStreamingAll(init.io, result.stdout);
                try Io.File.stderr().writeStreamingAll(init.io, result.stderr);
                break :succeeded result.exit_code == 0;
            };
            const status = if (succeeded) status: {
                passed += 1;
                break :status "ok";
            } else status: {
                failed += 1;
                break :status "FAILED";
            };
            try Io.File.stdout().writeStreamingAll(init.io, try std.fmt.allocPrint(source_allocator, "{s} - {s}\n", .{ status, label }));
        }
    }
    const summary = if (directory_input)
        try std.fmt.allocPrint(allocator, "{d} passed; {d} failed in {d} files", .{ passed, failed, sources.len })
    else
        try std.fmt.allocPrint(allocator, "{d} passed; {d} failed", .{ passed, failed });
    const line = if (source_errors == 0)
        try std.fmt.allocPrint(allocator, "{s}\n", .{summary})
    else
        try std.fmt.allocPrint(allocator, "{s}; {d} source errors\n", .{ summary, source_errors });
    try Io.File.stdout().writeStreamingAll(init.io, line);
    return if (failed == 0 and source_errors == 0) 0 else 1;
}

fn relativeTestPath(root: []const u8, path: []const u8) []const u8 {
    if (std.mem.eql(u8, root, ".")) return path;
    var prefix_len = root.len;
    while (prefix_len != 0 and (root[prefix_len - 1] == '/' or root[prefix_len - 1] == '\\')) prefix_len -= 1;
    if (path.len > prefix_len and std.mem.startsWith(u8, path, root[0..prefix_len]) and
        (path[prefix_len] == '/' or path[prefix_len] == '\\'))
    {
        return path[prefix_len + 1 ..];
    }
    return path;
}

fn listTargets(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    if (args.len != 0) {
        std.debug.print("silex: 'targets' does not accept arguments\n", .{});
        return 1;
    }
    const host = TargetModule.Target.host();
    for (TargetModule.Target.supported) |target| {
        const line = if (host) |selected|
            if (selected.eql(target))
                try std.fmt.allocPrint(allocator, "{s} (host)\n", .{target.name()})
            else
                try std.fmt.allocPrint(allocator, "{s}\n", .{target.name()})
        else
            try std.fmt.allocPrint(allocator, "{s}\n", .{target.name()});
        try Io.File.stdout().writeStreamingAll(init.io, line);
    }
    return 0;
}

fn runLanguageServer(init: std.process.Init, args: []const []const u8) !u8 {
    if (args.len != 0) {
        std.debug.print("silex: 'lsp' does not accept arguments\n", .{});
        return 1;
    }
    var server = Lsp.Server.initWithPackages(
        init.gpa,
        init.io,
        try globalPackagesRoot(init.arena.allocator(), init.environ_map),
    );
    defer server.deinit();
    try server.run();
    return 0;
}

fn runSource(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const options = switch (Cli.parseRun(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("run", diagnostic);
            return 1;
        },
    };
    const target = TargetModule.Target.host() orelse {
        std.debug.print("silex: 'run' requires a recognized host target\n", .{});
        return 1;
    };
    if (options.cache) CompilationCache.maintain(allocator, init.io);
    const output_path = try runArtifactPath(allocator, options, target);
    const status = try compileNativeOptions(init, allocator, .{
        .source_path = options.source_path,
        .output_path = output_path,
        .mode = options.mode,
        .cache = options.cache,
        .target = target,
    }, options.emit_ir);
    if (status != 0) return status;
    var progress = CliProgress.Build.init(init.io);
    progress.source(.run, options.source_path);
    progress.finish();
    return executeNative(init, allocator, output_path, options.source_path);
}

fn interpretSource(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const options = switch (Cli.parseInterpret(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("interpret", diagnostic);
            return 1;
        },
    };

    const target = TargetModule.Target.host() orelse {
        std.debug.print("silex: 'interpret' requires a recognized host target\n", .{});
        return 1;
    };
    if (options.cache) {
        CompilationCache.maintain(allocator, init.io);
        defer CompilationCache.maintainAfterMutation(allocator, init.io);
    }
    var boundaries: []const Boundary.Function = &.{};
    const cached_ir = if (options.cache) CompilationCache.loadIr(allocator, init.io, options.source_path, target.name()) else null;
    const portable_ir = if (cached_ir) |cached| if (containsBoundaryCall(cached)) null else cached else null;
    const program = portable_ir orelse program: {
        var compiler = Project.Compiler.initWithPackagesAndCache(
            allocator,
            init.io,
            try globalPackagesRoot(allocator, init.environ_map),
            options.cache,
        );
        compiler.target = target;
        try configureShaderCompiler(&compiler, allocator, init.environ_map);
        const compilation = compiler.compile(options.source_path) catch |err| switch (err) {
            error.InvalidSource => {
                printSourceDiagnostic(compiler, options.source_path);
                return 1;
            },
            else => return err,
        };
        boundaries = compilation.boundaries;
        // Portable IR deliberately omits provider metadata. Recompile programs
        // with boundaries until the cache owns that complete contract.
        if (options.cache and boundaries.len == 0) CompilationCache.storeIr(
            allocator,
            init.io,
            options.source_path,
            target.name(),
            compilation.cache_files,
            compilation.ir,
        );
        break :program compilation.ir;
    };

    if (options.emit_ir) {
        const text = try Ir.writeText(allocator, program);
        try Io.File.stdout().writeStreamingAll(init.io, text);
    }
    for (boundaries) |boundary| {
        if (Interpreter.supportsBoundary(boundary)) continue;
        std.debug.print(
            "silex: 'interpret' cannot execute foreign function '{s}' from '{s}'; use 'silex run' for this platform boundary\n",
            .{ boundary.source_name, boundary.provider },
        );
        return 1;
    }
    const result = Interpreter.runCaptureWithBoundaries(allocator, init.io, program, boundaries) catch |err| {
        std.debug.print("silex: runtime error: {t}\n", .{err});
        return 1;
    };
    try Io.File.stdout().writeStreamingAll(init.io, result.stdout);
    try Io.File.stderr().writeStreamingAll(init.io, result.stderr);
    return result.exit_code;
}

fn containsBoundaryCall(program: Ir.Program) bool {
    for (program.functions) |function| {
        for (function.blocks) |block| {
            for (block.instructions) |instruction| switch (instruction) {
                .boundary_call => return true,
                else => {},
            };
        }
    }
    return false;
}

fn compileNative(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const options = switch (Cli.parseCompile(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("compile", diagnostic);
            return 1;
        },
    };
    if (options.cache) CompilationCache.maintain(allocator, init.io);
    return compileNativeOptions(init, allocator, options, false);
}

fn compileNativeOptions(
    init: std.process.Init,
    allocator: std.mem.Allocator,
    options: Cli.CompileOptions,
    emit_ir: bool,
) !u8 {
    const target = options.target orelse TargetModule.Target.host() orelse {
        std.debug.print("silex: 'compile' requires --target on this host\n", .{});
        return 1;
    };
    var progress = CliProgress.Build.init(init.io);
    progress.source(.analyze, options.source_path);
    const executable_kind = if (target.eql(.macos_arm64)) "macho" else if (target.eql(.linux_x64)) "elf" else "pe";
    const native_variant = try std.fmt.allocPrint(allocator, "{s}:{s}:{s}", .{ target.name(), @tagName(options.mode), options.source_path });
    if (options.cache) if (CompilationCache.loadNativeState(allocator, init.io, options.source_path, target.name())) |state| {
        const digest = CompilationCache.nativeKey(
            allocator,
            init.io,
            state.files,
            state.providers,
            "compile",
            native_variant,
        ) catch null;
        if (digest) |key| if (CompilationCache.executableExists(allocator, init.io, key, executable_kind)) {
            progress.target(target.name(), @tagName(options.mode));
            progress.stage(.cache);
            progress.source(.write, options.output_path);
            CompilationCache.materializeExecutable(allocator, init.io, key, executable_kind, options.output_path) catch |err| {
                std.debug.print("silex: unable to materialize cached executable: {t}\n", .{err});
                return 1;
            };
            progress.source(.ready, options.output_path);
            progress.finish();
            return 0;
        };
    };
    var boundaries: []const Boundary.Function = &.{};
    var boundary_providers: []const Packages.BoundaryProvider = &.{};
    var dependency_files: []const []const u8 = &.{};
    const program = program: {
        var compiler = Project.Compiler.initWithPackagesAndCache(
            allocator,
            init.io,
            try globalPackagesRoot(allocator, init.environ_map),
            options.cache,
        );
        compiler.target = target;
        try configureShaderCompiler(&compiler, allocator, init.environ_map);
        const compilation = compiler.compile(options.source_path) catch |err| switch (err) {
            error.InvalidSource => {
                printSourceDiagnostic(compiler, options.source_path);
                return 1;
            },
            else => return err,
        };
        boundaries = compilation.boundaries;
        boundary_providers = try requiredBoundaryProviders(allocator, boundaries, compilation.packages);
        dependency_files = compilation.cache_files;
        if (options.cache and boundaries.len == 0) {
            CompilationCache.storeIr(allocator, init.io, options.source_path, target.name(), compilation.cache_files, compilation.ir);
        }
        if (options.cache) CompilationCache.storeNativeState(
            allocator,
            init.io,
            options.source_path,
            target.name(),
            compilation.cache_files,
            boundary_providers,
        );
        break :program compilation.ir;
    };

    // A cache miss may write frontend, machine and executable entries. Keep
    // cleanup off the cache-hit path and enforce the disk budget once after
    // the mutating compilation has completed.
    if (options.cache) {
        defer CompilationCache.maintainAfterMutation(allocator, init.io);
    }

    if (emit_ir) {
        const text = try Ir.writeText(allocator, program);
        try Io.File.stdout().writeStreamingAll(init.io, text);
    }

    if (!target.hasNativeEmitter()) {
        std.debug.print("silex: target '{s}' is recognized but its native backend is not implemented yet\n", .{target.name()});
        return 1;
    }
    const linker_path = try nativeLinkerPath(allocator, init.io, init.environ_map, target);

    progress.target(target.name(), @tagName(options.mode));

    const cache_key = if (options.cache)
        CompilationCache.nativeKey(allocator, init.io, dependency_files, boundary_providers, "compile", native_variant) catch null
    else
        null;
    if (cache_key) |digest| if (CompilationCache.executableExists(allocator, init.io, digest, executable_kind)) {
        progress.stage(.cache);
        progress.source(.write, options.output_path);
        CompilationCache.materializeExecutable(allocator, init.io, digest, executable_kind, options.output_path) catch |err| {
            std.debug.print("silex: unable to materialize cached executable: {t}\n", .{err});
            return 1;
        };
        progress.source(.ready, options.output_path);
        progress.finish();
        return 0;
    };

    // Cached outputs are hard links to their canonical artifact. Detach the
    // requested path before a linker or emitter overwrites it so an older
    // content-addressed entry can never be mutated in place.
    Io.Dir.cwd().deleteFile(init.io, options.output_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => {
            std.debug.print("silex: unable to replace '{s}': {t}\n", .{ options.output_path, err });
            return 1;
        },
    };

    const native_ir = switch (options.mode) {
        .debug => program,
        .release => (if (options.cache)
            ReleaseOptimizer.optimizeCached(allocator, init.io, program)
        else
            ReleaseOptimizer.optimize(allocator, program)) catch |err| {
            std.debug.print("silex: optimizer rejected the portable IR: {t}\n", .{err});
            return 1;
        },
    };
    const lower_mode = lowerModeForTarget(options.mode, target);
    const machine = (if (options.cache)
        Lower.lowerCachedWithBoundaries(allocator, init.io, native_ir, boundaries, lower_mode)
    else
        Lower.lowerWithModeAndBoundaries(allocator, native_ir, boundaries, lower_mode)) catch |err| {
        std.debug.print("silex: native backend cannot lower this program: {t}\n", .{err});
        return 1;
    };
    progress.stage(.emit);
    if (target.eql(.macos_arm64) and
        (boundary_providers.len != 0 or MacOSLink.requiresSystemLink(machine.external_functions)))
    {
        const object = MachOObject.emit(allocator, machine) catch |err| {
            std.debug.print("silex: cannot emit relocatable native object: {t}\n", .{err});
            return 1;
        };
        const object_path = try linkedObjectPath(allocator, options, boundary_providers);
        defer Io.Dir.cwd().deleteFile(init.io, object_path) catch {};
        if (std.fs.path.dirname(object_path)) |directory| try Io.Dir.cwd().createDirPath(init.io, directory);
        {
            const file = try Io.Dir.cwd().createFile(init.io, object_path, .{});
            defer file.close(init.io);
            try file.writeStreamingAll(init.io, object);
        }
        if (std.fs.path.dirname(options.output_path)) |directory| try Io.Dir.cwd().createDirPath(init.io, directory);
        progress.stage(.link);
        MacOSLink.executable(
            allocator,
            init.io,
            linker_path,
            object_path,
            options.output_path,
            boundary_providers,
            machine.external_functions,
        ) catch |err| {
            std.debug.print("silex: cannot link native package artifacts: {t}\n", .{err});
            return 1;
        };
        if (cache_key) |digest| storeLinkedExecutable(allocator, init.io, digest, executable_kind, options.output_path);
        progress.source(.ready, options.output_path);
        progress.finish();
        return 0;
    }
    if ((target.eql(.linux_x64) or target.eql(.windows_x64)) and boundary_providers.len != 0) {
        var image = (if (target.eql(.linux_x64))
            X64Encoder.encodeLinuxObject(allocator, machine)
        else
            X64Encoder.encodeWindowsObject(allocator, machine)) catch |err| {
            std.debug.print("silex: {s} encoder cannot emit a linked object: {t}\n", .{ target.name(), err });
            return 1;
        };
        defer image.deinit(allocator);
        const object = (if (target.eql(.linux_x64))
            X64Object.emitElf(allocator, machine, image)
        else
            X64Object.emitCoff(allocator, machine, image)) catch |err| {
            std.debug.print("silex: cannot emit a {s} relocatable object: {t}\n", .{ target.name(), err });
            return 1;
        };
        const object_path = try linkedObjectPath(allocator, options, boundary_providers);
        defer Io.Dir.cwd().deleteFile(init.io, object_path) catch {};
        if (std.fs.path.dirname(object_path)) |directory| try Io.Dir.cwd().createDirPath(init.io, directory);
        {
            const file = try Io.Dir.cwd().createFile(init.io, object_path, .{});
            defer file.close(init.io);
            try file.writeStreamingAll(init.io, object);
        }
        if (std.fs.path.dirname(options.output_path)) |directory| try Io.Dir.cwd().createDirPath(init.io, directory);
        progress.stage(.link);
        NativeLink.executable(allocator, init.io, linker_path, target, object_path, options.output_path, boundary_providers) catch |err| {
            std.debug.print("silex: cannot link native package artifacts for {s}: {t}\n", .{ target.name(), err });
            return 1;
        };
        if (cache_key) |digest| storeLinkedExecutable(allocator, init.io, digest, executable_kind, options.output_path);
        progress.source(.ready, options.output_path);
        progress.finish();
        return 0;
    }
    if (target.eql(.windows_arm64) and boundary_providers.len != 0) {
        const object = Arm64Object.emitWindows(allocator, machine) catch |err| {
            std.debug.print("silex: cannot emit a Windows ARM64 relocatable object: {t}\n", .{err});
            return 1;
        };
        const object_path = try linkedObjectPath(allocator, options, boundary_providers);
        defer Io.Dir.cwd().deleteFile(init.io, object_path) catch {};
        if (std.fs.path.dirname(object_path)) |directory| try Io.Dir.cwd().createDirPath(init.io, directory);
        {
            const file = try Io.Dir.cwd().createFile(init.io, object_path, .{});
            defer file.close(init.io);
            try file.writeStreamingAll(init.io, object);
        }
        if (std.fs.path.dirname(options.output_path)) |directory| try Io.Dir.cwd().createDirPath(init.io, directory);
        progress.stage(.link);
        NativeLink.executable(allocator, init.io, linker_path, target, object_path, options.output_path, boundary_providers) catch |err| {
            std.debug.print("silex: cannot link native package artifacts for windows-arm64: {t}\n", .{err});
            return 1;
        };
        if (cache_key) |digest| storeLinkedExecutable(allocator, init.io, digest, executable_kind, options.output_path);
        progress.source(.ready, options.output_path);
        progress.finish();
        return 0;
    }
    const executable = executable: {
        if (target.eql(.macos_arm64)) break :executable MachO.emit(allocator, machine) catch |err| {
            std.debug.print("silex: cannot emit native executable: {t}\n", .{err});
            return 1;
        };
        if (target.eql(.linux_x64)) {
            var image = X64Encoder.encodeLinux(allocator, machine) catch |err| {
                std.debug.print("silex: Linux X64 encoder cannot emit this program yet: {t}\n", .{err});
                return 1;
            };
            defer image.deinit(allocator);
            break :executable Elf.emit(allocator, image.code, image.entry_offset) catch |err| {
                std.debug.print("silex: cannot emit Linux ELF executable: {t}\n", .{err});
                return 1;
            };
        }
        if (target.eql(.windows_x64)) {
            var image = X64Encoder.encodeWindows(allocator, machine) catch |err| {
                std.debug.print("silex: Windows X64 encoder cannot emit this program yet: {t}\n", .{err});
                return 1;
            };
            defer image.deinit(allocator);
            break :executable PE.emitX64(
                allocator,
                .x64,
                image.code,
                image.entry_offset,
                image.windows_import_sites,
            ) catch |err| {
                std.debug.print("silex: cannot emit Windows PE32+ executable: {t}\n", .{err});
                return 1;
            };
        }
        if (target.eql(.windows_arm64)) {
            const main_id = findMachineMain(machine) orelse {
                std.debug.print("silex: Windows ARM64 executable has no valid main function\n", .{});
                return 1;
            };
            var image = Arm64Encoder.encodeWindows(allocator, machine, .{ .executable_main = main_id }) catch |err| {
                std.debug.print("silex: Windows ARM64 encoder cannot emit this program yet: {t}\n", .{err});
                return 1;
            };
            defer image.deinit(allocator);
            const sites = try allocator.alloc(WindowsImports.Arm64Site, image.external_call_sites.len);
            defer allocator.free(sites);
            for (image.external_call_sites, 0..) |site, index| {
                const symbol = site.windows_symbol orelse symbol: {
                    if (site.function >= machine.external_functions.len) return error.InvalidProgram;
                    const external = machine.external_functions[site.function];
                    if (std.mem.eql(u8, external.provider, "Windows.bcrypt_primitives") and
                        std.mem.eql(u8, external.source_name, "ProcessPrng"))
                    {
                        break :symbol WindowsImports.Symbol.process_prng;
                    }
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and
                        std.mem.eql(u8, external.source_name, "QueryPerformanceCounter"))
                    {
                        break :symbol WindowsImports.Symbol.query_performance_counter;
                    }
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and
                        std.mem.eql(u8, external.source_name, "QueryPerformanceFrequency"))
                    {
                        break :symbol WindowsImports.Symbol.query_performance_frequency;
                    }
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and
                        std.mem.eql(u8, external.source_name, "GetSystemTimeAsFileTime"))
                    {
                        break :symbol WindowsImports.Symbol.get_system_time_as_file_time;
                    }
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_write")) break :symbol .crt_write;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_read")) break :symbol .crt_read;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_isatty")) break :symbol .crt_isatty;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_wopen")) break :symbol .crt_wopen;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_close")) break :symbol .crt_close;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_commit")) break :symbol .crt_commit;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_lseeki64")) break :symbol .crt_lseeki64;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_chsize_s")) break :symbol .crt_chsize_s;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "__p___argc")) break :symbol .crt_p_argc;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "__p___wargv")) break :symbol .crt_p_wargv;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetStdHandle")) break :symbol .get_std_handle;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetConsoleScreenBufferInfo")) break :symbol .get_console_screen_buffer_info;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetConsoleMode")) break :symbol .get_console_mode;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetConsoleMode")) break :symbol .set_console_mode;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetConsoleCP")) break :symbol .get_console_cp;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetConsoleCP")) break :symbol .set_console_cp;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "WaitForSingleObject")) break :symbol .wait_for_single_object;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetCurrentDirectoryW")) break :symbol .get_current_directory_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetCurrentDirectoryW")) break :symbol .set_current_directory_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetModuleFileNameW")) break :symbol .get_module_file_name_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetCurrentProcessId")) break :symbol .get_current_process_id;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetEnvironmentVariableW")) break :symbol .get_environment_variable_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetEnvironmentVariableW")) break :symbol .set_environment_variable_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetEnvironmentStringsW")) break :symbol .get_environment_strings_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "FreeEnvironmentStringsW")) break :symbol .free_environment_strings_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetFileAttributesExW")) break :symbol .get_file_attributes_ex_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "FindFirstFileW")) break :symbol .find_first_file_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "FindNextFileW")) break :symbol .find_next_file_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "FindClose")) break :symbol .find_close;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CreateDirectoryW")) break :symbol .create_directory_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "DeleteFileW")) break :symbol .delete_file_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "RemoveDirectoryW")) break :symbol .remove_directory_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "MoveFileExW")) break :symbol .move_file_ex_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CopyFileW")) break :symbol .copy_file_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetFileAttributesW")) break :symbol .set_file_attributes_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetFullPathNameW")) break :symbol .get_full_path_name_w;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "GetAddrInfoW")) break :symbol .get_addr_info_w;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "FreeAddrInfoW")) break :symbol .free_addr_info_w;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "WSAStartup")) break :symbol .wsa_startup;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "WSACleanup")) break :symbol .wsa_cleanup;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "socket")) break :symbol .wsa_socket;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "connect")) break :symbol .wsa_connect;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "bind")) break :symbol .wsa_bind;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "listen")) break :symbol .wsa_listen;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "accept")) break :symbol .wsa_accept;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "recv")) break :symbol .wsa_recv;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "send")) break :symbol .wsa_send;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "shutdown")) break :symbol .wsa_shutdown;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "closesocket")) break :symbol .wsa_close_socket;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "getsockname")) break :symbol .wsa_getsockname;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "getpeername")) break :symbol .wsa_getpeername;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "setsockopt")) break :symbol .wsa_setsockopt;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "sendto")) break :symbol .wsa_sendto;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "recvfrom")) break :symbol .wsa_recvfrom;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CreatePipe")) break :symbol .create_pipe;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetHandleInformation")) break :symbol .set_handle_information;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CreateProcessW")) break :symbol .create_process_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "ReadFile")) break :symbol .read_file;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "WriteFile")) break :symbol .write_file;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "PeekNamedPipe")) break :symbol .peek_named_pipe;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CloseHandle")) break :symbol .close_handle;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "TerminateProcess")) break :symbol .terminate_process;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetExitCodeProcess")) break :symbol .get_exit_code_process;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetLastError")) break :symbol .get_last_error;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CreateThread")) break :symbol .create_thread;
                    return error.InvalidProgram;
                };
                sites[index] = .{ .instruction_offset = site.instruction_offset, .symbol = symbol };
            }
            break :executable PE.emitArm64(allocator, image.code, image.entry_offset.?, sites) catch |err| {
                std.debug.print("silex: cannot emit Windows ARM64 PE32+ executable: {t}\n", .{err});
                return 1;
            };
        }
        unreachable;
    };

    progress.source(.write, options.output_path);
    const status = writeExecutable(init, options.output_path, executable);
    if (status == 0) {
        if (cache_key) |digest| CompilationCache.storeExecutableFile(
            allocator,
            init.io,
            digest,
            executable_kind,
            options.output_path,
        );
        progress.source(.ready, options.output_path);
        progress.finish();
    }
    return status;
}

fn storeLinkedExecutable(
    allocator: std.mem.Allocator,
    io: Io,
    digest: [std.crypto.hash.Blake3.digest_length]u8,
    executable_kind: []const u8,
    output_path: []const u8,
) void {
    CompilationCache.storeExecutableFile(allocator, io, digest, executable_kind, output_path);
}

fn requiredBoundaryProviders(
    allocator: std.mem.Allocator,
    boundaries: []const Boundary.Function,
    graph: ?Packages.Graph,
) ![]const Packages.BoundaryProvider {
    const packages = graph orelse return &.{};
    var providers: std.ArrayList(Packages.BoundaryProvider) = .empty;
    var selections: std.ArrayList(BoundaryProviderKey) = .empty;
    defer selections.deinit(allocator);
    for (boundaries) |boundary| {
        const provider = packages.boundaryProvider(boundary.owner, boundary.provider) orelse continue;
        try appendBoundaryProvider(allocator, packages, boundary.owner, provider, &selections, &providers);
    }
    return providers.toOwnedSlice(allocator);
}

const BoundaryProviderKey = struct {
    owner: usize,
    name: []const u8,
};

fn appendBoundaryProvider(
    allocator: std.mem.Allocator,
    graph: Packages.Graph,
    owner: usize,
    provider: Packages.BoundaryProvider,
    selections: *std.ArrayList(BoundaryProviderKey),
    providers: *std.ArrayList(Packages.BoundaryProvider),
) !void {
    for (selections.items) |selection| {
        if (selection.owner == owner and std.mem.eql(u8, selection.name, provider.name)) return;
    }
    try selections.append(allocator, .{ .owner = owner, .name = provider.name });
    try providers.append(allocator, provider);
    for (provider.requires) |requirement| {
        const required = graph.requiredBoundaryProvider(owner, requirement) orelse continue;
        try appendBoundaryProvider(allocator, graph, required.owner, required.provider, selections, providers);
    }
}

test "select required boundary providers after their owner" {
    const dependency_provider: Packages.BoundaryProvider = .{
        .name = "SDL3",
        .frameworks = &.{"Metal"},
        .libraries = &.{},
    };
    const root_provider: Packages.BoundaryProvider = .{
        .name = "SDL3_mixer",
        .frameworks = &.{},
        .libraries = &.{},
        .requires = &.{.{ .package = "GFX", .provider = "SDL3" }},
    };
    const dependencies = [_]Packages.Dependency{.{
        .name = "GFX",
        .package = 1,
        .constraint = .{ .kind = .caret, .version = .{ .major = 1, .minor = 0, .patch = 0 } },
    }};
    const packages = [_]Packages.Package{
        .{
            .name = "GFX.Audio",
            .version = .{ .major = 1, .minor = 0, .patch = 0 },
            .origin = .project,
            .root = "GFX.Audio",
            .module_roots = &.{},
            .inactive_modules = &.{},
            .dependencies = &dependencies,
            .boundary_providers = &.{root_provider},
        },
        .{
            .name = "GFX",
            .version = .{ .major = 1, .minor = 0, .patch = 0 },
            .origin = .workspace_link,
            .root = "GFX",
            .module_roots = &.{},
            .inactive_modules = &.{},
            .dependencies = &.{},
            .boundary_providers = &.{dependency_provider},
        },
    };
    const boundaries = [_]Boundary.Function{.{
        .name = "initialize",
        .provider = "Boundary.SDL3_mixer",
        .source_name = "MIX_Init",
        .parameters = &.{},
        .return_type = .int32,
        .owner = 0,
    }};
    const selected = try requiredBoundaryProviders(std.testing.allocator, &boundaries, .{
        .packages = &packages,
        .explicit = true,
    });
    defer std.testing.allocator.free(selected);
    try std.testing.expectEqual(@as(usize, 2), selected.len);
    try std.testing.expectEqualStrings("SDL3_mixer", selected[0].name);
    try std.testing.expectEqualStrings("SDL3", selected[1].name);
}

fn linkedObjectPath(
    allocator: std.mem.Allocator,
    options: Cli.CompileOptions,
    providers: []const Packages.BoundaryProvider,
) ![]const u8 {
    var dependencies: std.ArrayList([]const u8) = .empty;
    try dependencies.appendSlice(allocator, &.{ options.source_path, options.output_path, @tagName(options.mode) });
    for (providers) |provider| if (provider.archive) |archive| try dependencies.append(allocator, archive);
    const digest = CompilationCache.artifactKey("linked-object", dependencies.items);
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(allocator, ".silex/link/{s}.o", .{hex[0..16]});
}

fn findMachineMain(program: @import("Arm64/Machine.zig").Program) ?usize {
    for (program.functions, 0..) |function, index| {
        if (std.mem.eql(u8, function.name, "main") and function.parameter_count == 0) return index;
    }
    return null;
}

fn printSourceDiagnostic(compiler: Project.Compiler, source_path: []const u8) void {
    const diagnostic = compiler.diagnostic orelse {
        std.debug.print("{s}: error: compilation failed without a source diagnostic\n", .{source_path});
        return;
    };
    std.debug.print("{s}:{d}:{d}: error: {s}\n", .{
        compiler.diagnosticPath(source_path),
        diagnostic.position.line,
        diagnostic.position.column,
        diagnostic.message,
    });
}

fn writeExecutable(init: std.process.Init, output_path: []const u8, executable: []const u8) u8 {
    if (std.fs.path.dirname(output_path)) |directory| Io.Dir.cwd().createDirPath(init.io, directory) catch |err| {
        std.debug.print("silex: unable to create directory '{s}': {t}\n", .{ directory, err });
        return 1;
    };
    const file = Io.Dir.cwd().createFile(init.io, output_path, .{
        .permissions = .executable_file,
    }) catch |err| {
        std.debug.print("silex: unable to create '{s}': {t}\n", .{ output_path, err });
        return 1;
    };
    defer file.close(init.io);
    file.writeStreamingAll(init.io, executable) catch |err| {
        std.debug.print("silex: unable to write '{s}': {t}\n", .{ output_path, err });
        return 1;
    };
    file.setPermissions(init.io, .executable_file) catch |err| {
        std.debug.print("silex: unable to make '{s}' executable: {t}\n", .{ output_path, err });
        return 1;
    };
    return 0;
}

fn runArtifactPath(allocator: std.mem.Allocator, options: Cli.RunOptions, target: TargetModule.Target) ![]const u8 {
    const digest = CompilationCache.artifactKey("run-executable", &.{ options.source_path, target.name(), @tagName(options.mode) });
    const hex = std.fmt.bytesToHex(digest, .lower);
    const extension = if (target.eql(.windows_x64) or target.eql(.windows_arm64)) ".exe" else "";
    return std.fmt.allocPrint(
        allocator,
        ".silex/run/{s}-{s}-{s}-{s}{s}",
        .{ std.fs.path.stem(options.source_path), target.name(), @tagName(options.mode), hex[0..16], extension },
    );
}

fn executeNative(
    init: std.process.Init,
    allocator: std.mem.Allocator,
    executable_path: []const u8,
    source_path: []const u8,
) !u8 {
    const current_directory = try std.process.currentPathAlloc(init.io, allocator);
    const absolute_executable = try std.fs.path.resolve(allocator, &.{ current_directory, executable_path });
    const source_directory = std.fs.path.dirname(source_path) orelse ".";
    const absolute_source_directory = try std.fs.path.resolve(allocator, &.{ current_directory, source_directory });
    var child = std.process.spawn(init.io, .{
        .argv = &.{absolute_executable},
        .cwd = .{ .path = absolute_source_directory },
        .stdin = .inherit,
        .stdout = .inherit,
        .stderr = .inherit,
    }) catch |err| {
        std.debug.print("silex: unable to run '{s}': {t}\n", .{ executable_path, err });
        return 1;
    };
    defer child.kill(init.io);
    return switch (try child.wait(init.io)) {
        .exited => |code| code,
        .signal => |signal| terminated: {
            std.debug.print("silex: program terminated by signal {d}\n", .{@intFromEnum(signal)});
            break :terminated 1;
        },
        .stopped => |signal| stopped: {
            std.debug.print("silex: program stopped by signal {d}\n", .{@intFromEnum(signal)});
            break :stopped 1;
        },
        .unknown => |status| unknown: {
            std.debug.print("silex: program terminated with unknown status {d}\n", .{status});
            break :unknown 1;
        },
    };
}

fn printCliDiagnostic(command: []const u8, diagnostic: Cli.Diagnostic) void {
    switch (diagnostic.kind) {
        .missing_source => if (std.mem.eql(u8, command, "test"))
            std.debug.print("silex: 'test' expects one source file or directory\n", .{})
        else
            std.debug.print("silex: '{s}' expects one source file\n", .{command}),
        .multiple_sources => if (std.mem.eql(u8, command, "test"))
            std.debug.print("silex: 'test' accepts only one source file or directory, found '{s}'\n", .{diagnostic.argument.?})
        else
            std.debug.print("silex: '{s}' accepts only one source file, found '{s}'\n", .{ command, diagnostic.argument.? }),
        .missing_package => std.debug.print("silex: '{s}' expects one package directory or name\n", .{command}),
        .multiple_packages => std.debug.print(
            "silex: '{s}' accepts only one package directory or name, found '{s}'\n",
            .{ command, diagnostic.argument.? },
        ),
        .missing_output => if (diagnostic.argument) |argument|
            std.debug.print("silex: option '{s}' expects an output path\n", .{argument})
        else
            std.debug.print("silex: 'compile' expects -o or --output followed by an executable path\n", .{}),
        .duplicate_output => std.debug.print("silex: output is specified more than once by '{s}'\n", .{diagnostic.argument.?}),
        .missing_target => std.debug.print("silex: option '--target' expects a target name\n", .{}),
        .duplicate_target => std.debug.print("silex: target is specified more than once\n", .{}),
        .unknown_target => std.debug.print("silex: unknown target '{s}'; expected macos-arm64, linux-x64, windows-x64 or windows-arm64\n", .{diagnostic.argument.?}),
        .missing_workspace => std.debug.print("silex: option '--workspace' expects a directory\n", .{}),
        .duplicate_workspace => std.debug.print("silex: workspace is specified more than once\n", .{}),
        .unknown_action => std.debug.print("silex: unknown '{s}' action '{s}'; expected 'resolve' or no action\n", .{ command, diagnostic.argument.? }),
        .conflicting_modes => std.debug.print("silex: Debug and Release modes are mutually exclusive near '{s}'\n", .{diagnostic.argument.?}),
        .option_unavailable => std.debug.print("silex: option '{s}' is unavailable for '{s}'\n", .{ diagnostic.argument.?, command }),
        .unknown_option => std.debug.print("silex: unknown option '{s}'\n", .{diagnostic.argument.?}),
    }
}

fn isHelp(argument: []const u8) bool {
    return std.mem.eql(u8, argument, "--help") or std.mem.eql(u8, argument, "-h");
}

fn isVersion(argument: []const u8) bool {
    return std.mem.eql(u8, argument, "--version") or std.mem.eql(u8, argument, "-V");
}

fn printVersion(io: Io) !u8 {
    var buffer: [64]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "silex {s}\n", .{build_options.version}) catch unreachable;
    try Io.File.stdout().writeStreamingAll(io, text);
    return 0;
}

fn globalPackagesRoot(
    allocator: std.mem.Allocator,
    environment: *const std.process.Environ.Map,
) !?[]const u8 {
    const home = environment.get("HOME") orelse environment.get("USERPROFILE") orelse return null;
    return try std.fs.path.join(allocator, &.{ home, ".silex", "packages" });
}

fn globalToolchainRoot(
    allocator: std.mem.Allocator,
    environment: *const std.process.Environ.Map,
) !?[]const u8 {
    const home = environment.get("HOME") orelse environment.get("USERPROFILE") orelse return null;
    return try std.fs.path.join(allocator, &.{ home, ".silex", "toolchain" });
}

fn globalRegistryRoot(
    allocator: std.mem.Allocator,
    environment: *const std.process.Environ.Map,
) !?[]const u8 {
    const home = environment.get("HOME") orelse environment.get("USERPROFILE") orelse return null;
    return try std.fs.path.join(allocator, &.{ home, ".silex", "registry" });
}

fn globalGitHubAuthorizationPath(
    allocator: std.mem.Allocator,
    environment: *const std.process.Environ.Map,
) !?[]const u8 {
    const home = environment.get("HOME") orelse environment.get("USERPROFILE") orelse return null;
    return try std.fs.path.join(allocator, &.{ home, ".silex", "auth", "github.json" });
}

fn nativeLinkerPath(
    allocator: std.mem.Allocator,
    io: Io,
    environment: *const std.process.Environ.Map,
    target: TargetModule.Target,
) ![]const u8 {
    const root = try globalToolchainRoot(allocator, environment) orelse return "zig";
    const host = TargetModule.Target.host() orelse target;
    const managed = try ToolchainSetup.linkerExecutablePath(allocator, root, host);
    const file = Io.Dir.cwd().openFile(io, managed, .{}) catch return "zig";
    file.close(io);
    return managed;
}

fn configureShaderCompiler(
    compiler: *Project.Compiler,
    allocator: std.mem.Allocator,
    environment: *const std.process.Environ.Map,
) !void {
    const root = try globalToolchainRoot(allocator, environment) orelse return;
    const host = TargetModule.Target.host() orelse return;
    compiler.shadercross_path = try ToolchainSetup.executablePath(allocator, root, host);
}

fn lowerModeForTarget(mode: Cli.Mode, target: TargetModule.Target) Lower.Mode {
    if (mode == .release and target.eql(.macos_arm64)) return .release;
    // X64 keeps the optimized portable IR but uses stack slots until its
    // native register allocator can consume release machine functions.
    return .debug;
}

test "select release register allocation only for its supported target" {
    try std.testing.expectEqual(Lower.Mode.release, lowerModeForTarget(.release, .macos_arm64));
    try std.testing.expectEqual(Lower.Mode.debug, lowerModeForTarget(.release, .linux_x64));
    try std.testing.expectEqual(Lower.Mode.debug, lowerModeForTarget(.release, .windows_x64));
    try std.testing.expectEqual(Lower.Mode.debug, lowerModeForTarget(.debug, .macos_arm64));
}

test "run owns a stable mode-specific artifact below .silex" {
    const debug = try runArtifactPath(std.testing.allocator, .{
        .source_path = "Sources/Main.sx",
        .emit_ir = false,
        .mode = .debug,
        .cache = true,
    }, .macos_arm64);
    defer std.testing.allocator.free(debug);
    const release = try runArtifactPath(std.testing.allocator, .{
        .source_path = "Sources/Main.sx",
        .emit_ir = false,
        .mode = .release,
        .cache = true,
    }, .macos_arm64);
    defer std.testing.allocator.free(release);
    try std.testing.expect(std.mem.startsWith(u8, debug, ".silex/run/Main-macos-arm64-debug-"));
    try std.testing.expect(std.mem.startsWith(u8, release, ".silex/run/Main-macos-arm64-release-"));
    try std.testing.expect(!std.mem.eql(u8, debug, release));
}

test {
    _ = @import("Target.zig");
    _ = @import("Cli.zig");
    _ = @import("Arm64/Differential.zig");
    _ = @import("Arm64/Encoder.zig");
    _ = @import("Arm64/Instructions.zig");
    _ = @import("Arm64/Lower.zig");
    _ = @import("Arm64/Machine.zig");
    _ = @import("Arm64/Runner.zig");
    _ = @import("BorrowedReturnTests.zig");
    _ = @import("CallbackTests.zig");
    _ = @import("CascadeTests.zig");
    _ = @import("MacOS/CodeSignature.zig");
    _ = @import("MacOS/MachO.zig");
    _ = @import("Linux/Elf.zig");
    _ = @import("X64/Encoder.zig");
    _ = @import("Windows/PE.zig");
    _ = @import("Optimize/Release.zig");
    _ = @import("Optimize/Slp.zig");
    _ = @import("Arm64/RegisterAllocation.zig");
    _ = @import("CompilationCache.zig");
    _ = @import("Composition.zig");
    _ = @import("CopyTests.zig");
    _ = @import("SnapshotTests.zig");
    _ = @import("EnumTests.zig");
    _ = @import("FixedArrayTests.zig");
    _ = @import("TupleTests.zig");
    _ = @import("DynamicListTests.zig");
    _ = @import("EmbeddedFilesTests.zig");
    _ = @import("CollectionMutationTests.zig");
    _ = @import("CollectionSliceTests.zig");
    _ = @import("ForIterationTests.zig");
    _ = @import("GenericTests.zig");
    _ = @import("MatchTests.zig");
    _ = @import("ScopeTests.zig");
    _ = @import("MapErrorTests.zig");
    _ = @import("MainResultTests.zig");
    _ = @import("MoveTests.zig");
    _ = @import("NamedArgumentTests.zig");
    _ = @import("MutexTests.zig");
    _ = @import("MutableReferenceTests.zig");
    _ = @import("DropCollectionTests.zig");
    _ = @import("NativeComposition.zig");
    _ = @import("NativeEffects.zig");
    _ = @import("Modules.zig");
    _ = @import("Numeric.zig");
    _ = @import("OptionalTests.zig");
    _ = @import("ResultTests.zig");
    _ = @import("TryTests.zig");
    _ = @import("TypedResourceTests.zig");
    _ = @import("TestBlockTests.zig");
    _ = @import("TestDiscovery.zig");
    _ = @import("NativeTestRunner.zig");
    _ = @import("ViewTests.zig");
    _ = @import("ClassTests.zig");
    _ = @import("ProtocolTests.zig");
    _ = @import("ExtensionTests.zig");
    _ = @import("Packages.zig");
    _ = @import("Packages/ImplicitTests.zig");
    _ = @import("ReadReferenceTests.zig");
    _ = @import("RecursiveResourceTests.zig");
    _ = @import("ResourceTests.zig");
    _ = @import("Lexer.zig");
    _ = @import("LspTests.zig");
    _ = @import("MacOS/ExternalCallTests.zig");
    _ = @import("Parser.zig");
    _ = @import("Project.zig");
    _ = @import("Project/CoreTests.zig");
    _ = @import("ProjectMigrationTests.zig");
    _ = @import("ProjectStructureTests.zig");
    _ = @import("Semantic/Analyzer.zig");
    _ = @import("Semantic/Tests.zig");
    _ = @import("Ir.zig");
    _ = @import("Interpreter.zig");
    _ = @import("Interface.zig");
    _ = @import("InteropTests.zig");
    _ = @import("Frontend.zig");
}
