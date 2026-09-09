const std = @import("std");
const Project = @import("../../Project.zig");

pub const Id = enum {
    std_math,
    widget_alias,
    current_module,
    atom_math,
    canvas_principal_reexport,
    catalog_field_chain,
    development_dependency,
    friend_package,
    submodule,
    merged_extension,
    platform_fragment,
};

const File = struct {
    path: []const u8,
    source: []const u8,
};

const Definition = struct {
    entry_path: []const u8 = "Main.sx",
    files: []const File,
};

pub fn validate(identifier: Id, canonical_source: []const u8) !void {
    inline for (std.meta.fields(Id)) |field| {
        const known: Id = @enumFromInt(field.value);
        if (identifier == known) return validateDefinition(comptime definition(known), canonical_source);
    }
    unreachable;
}

pub fn install(identifier: Id, temporary: *std.testing.TmpDir) ![]const u8 {
    return switch (identifier) {
        inline else => |known| installDefinition(comptime definition(known), temporary),
    };
}

fn installDefinition(comptime fixture: Definition, temporary: *std.testing.TmpDir) ![]const u8 {
    for (fixture.files) |file| try writeFile(temporary, file.path, file.source);
    return fixture.entry_path;
}

fn validateDefinition(fixture: Definition, canonical_source: []const u8) !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    for (fixture.files) |file| try writeFile(&temporary, file.path, file.source);
    try writeFile(&temporary, fixture.entry_path, canonical_source);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const input = try std.fs.path.join(arena.allocator(), &.{
        ".zig-cache",
        "tmp",
        &temporary.sub_path,
        fixture.entry_path,
    });
    var compiler = Project.Compiler.init(arena.allocator(), std.testing.io);
    _ = compiler.compile(input) catch |err| {
        std.debug.print(
            "workspace completion fixture is not semantically valid: {s}\n",
            .{if (compiler.diagnostic) |diagnostic| diagnostic.message else @errorName(err)},
        );
        return err;
    };
}

fn writeFile(temporary: *std.testing.TmpDir, path: []const u8, source: []const u8) !void {
    if (std.fs.path.dirname(path)) |parent| try temporary.dir.createDirPath(std.testing.io, parent);
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = path, .data = source });
}

fn definition(comptime identifier: Id) Definition {
    return switch (identifier) {
        .std_math => .{ .files = &.{
            .{ .path = "Package.json", .source = rootManifest("STD") },
            .{ .path = "STD/Package.json", .source = packageManifest("STD") },
            .{ .path = "STD/Module/Math.sx", .source = vec2Source() },
        } },
        .widget_alias => .{ .files = &.{
            .{ .path = "Package.json", .source = rootManifest("Api") },
            .{ .path = "Api/Package.json", .source = packageManifest("Api") },
            .{ .path = "Api/Module/Widget.sx", .source =
            \\public class Widget {
            \\    func paint() {}
            \\}
            },
        } },
        .current_module => .{ .files = &.{
            .{ .path = "Package.json", .source = "{\"sources\":\".\"}" },
            .{ .path = "Tools.sx", .source = "public func build() {}" },
        } },
        .atom_math => .{ .files = &.{
            .{ .path = "Package.json", .source = rootManifest("Api") },
            .{ .path = "Api/Package.json", .source = packageManifest("Api") },
            .{ .path = "Api/Module/Math/@Vec2.sx", .source = vec2Source() },
        } },
        .canvas_principal_reexport => .{ .files = &.{
            .{ .path = "Package.json", .source = rootManifest("GFX.Canvas") },
            .{
                .path = "GFX/Package.json",
                .source = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Canvas\":{\"suite\":true}}}",
            },
            .{ .path = "GFX/Module/@Module.sx", .source = "" },
            .{
                .path = "GFX.Canvas/Package.json",
                .source = "{\"name\":\"GFX.Canvas\",\"version\":\"1.0.0\",\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
            },
            .{ .path = "GFX.Canvas/Module/@Module.sx", .source = "public use GFX.Canvas.Canvas.Canvas" },
            .{ .path = "GFX.Canvas/Module/Canvas.sx", .source =
            \\public class Canvas {
            \\    func paint(callback:func()) Canvas { callback(); return self }
            \\    func clear() Canvas { return self }
            \\}
            },
        } },
        .catalog_field_chain => .{ .files = &.{
            .{
                .path = "Package.json",
                .source = "{\"sources\":\".\",\"dependencies\":{\"STD\":\"=1.0.0\",\"GFX\":\"=1.0.0\",\"GFX.Scene2D\":\"=1.0.0\"}}",
            },
            .{ .path = "STD/Package.json", .source = packageManifest("STD") },
            .{ .path = "STD/Module/Math/@Vec2.sx", .source = vec2Source() },
            .{
                .path = "GFX/Package.json",
                .source = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Scene2D\":{}},\"catalogs\":[\"GFX.Components\"]}",
            },
            .{ .path = "GFX/Module/Components.sx", .source = "public struct CoreComponent {}" },
            .{
                .path = "GFX.Scene2D/Package.json",
                .source = "{\"name\":\"GFX.Scene2D\",\"version\":\"1.0.0\",\"dependencies\":{\"GFX\":\"=1.0.0\",\"STD\":\"=1.0.0\"}}",
            },
            .{ .path = "GFX.Scene2D/Module/@Module.sx", .source =
            \\use STD.Math
            \\public struct Transform2D { var position:Math.Vec2 }
            \\contribute GFX.Components {
            \\    public use GFX.Scene2D.Transform2D
            \\}
            },
        } },
        .development_dependency => .{ .files = &.{
            .{
                .path = "Package.json",
                .source = "{\"sources\":\".\",\"devDependencies\":{\"TestKit\":\"=1.0.0\"}}",
            },
            .{ .path = "TestKit/Package.json", .source = packageManifest("TestKit") },
            .{
                .path = "TestKit/Module/Assertions.sx",
                .source = "public func equal(left:int, right:int) { assert(left == right) }",
            },
        } },
        .friend_package => .{
            .entry_path = "GFX.Physics/Module/Probe.sx",
            .files = &.{
                .{
                    .path = "GFX/Package.json",
                    .source = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Physics\":{\"friend\":true}}}",
                },
                .{
                    .path = "GFX/Module/Core.sx",
                    .source = "package func package_visible() int { return 42 }\nlocal func private_visible() int { return 0 }",
                },
                .{
                    .path = "GFX.Physics/Package.json",
                    .source = "{\"name\":\"GFX.Physics\",\"version\":\"1.0.0\",\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
                },
            },
        },
        .submodule => .{ .files = &.{
            .{ .path = "Package.json", .source = rootManifest("Api") },
            .{ .path = "Api/Package.json", .source = packageManifest("Api") },
            .{
                .path = "Api/Module/Rendering/Canvas.sx",
                .source = "public class Canvas { func paint() {}\nprivate func hidden() {} }",
            },
        } },
        .merged_extension => .{ .files = &.{
            .{
                .path = "Package.json",
                .source = "{\"sources\":\".\",\"dependencies\":{\"GFX\":\"=1.0.0\",\"GFX.Physics\":\"=1.0.0\"}}",
            },
            .{
                .path = "GFX/Package.json",
                .source = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Physics\":{\"merge\":true}}}",
            },
            .{ .path = "GFX/Module/Physics.sx", .source = "public func core_value() int { return 1 }" },
            .{
                .path = "GFX.Physics/Package.json",
                .source = "{\"name\":\"GFX.Physics\",\"version\":\"1.0.0\",\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
            },
            .{
                .path = "GFX.Physics/Module/@Module.sx",
                .source = "public class Adapter { func choose() int { return 42 }\nprivate func private_helper() {} }",
            },
        } },
        .platform_fragment => .{ .files = &.{
            .{ .path = "Package.json", .source = rootManifest("Bridge") },
            .{ .path = "Bridge/Package.json", .source = packageManifest("Bridge") },
            .{ .path = "Bridge/Module/@Module.sx", .source = "" },
            .{ .path = "Bridge/Platform/MacOS/Module/Window.sx", .source =
            \\public class Window {
            \\    static func current() Window { return Window() }
            \\    func show() {}
            \\}
            },
            .{ .path = "Bridge/Platform/Linux/Module/Window.sx", .source = "inactive invalid Linux source" },
        } },
    };
}

fn rootManifest(comptime dependency: []const u8) []const u8 {
    return "{\"sources\":\".\",\"dependencies\":{\"" ++ dependency ++ "\":\"=1.0.0\"}}";
}

fn packageManifest(comptime name: []const u8) []const u8 {
    return "{\"name\":\"" ++ name ++ "\",\"version\":\"1.0.0\"}";
}

fn vec2Source() []const u8 {
    return
    \\public struct Vec2 {
    \\    var x:float = 0.0
    \\    var y:float = 0.0
    \\    func length() float { return self.x + self.y }
    \\    func normalized() Vec2 { return self }
    \\}
    ;
}
