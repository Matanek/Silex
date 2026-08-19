const std = @import("std");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");
const Workspace = @import("../Workspace.zig");

test "server navigates local and imported function values" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Systems/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Systems/Package.json",
        .data = "{\"name\":\"Systems\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Systems/Module/Frame.sx",
        .data = "public func imported_system() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const imported_uri = try std.fmt.allocPrint(allocator, "file://{s}/Systems/Module/Frame.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);

    const local = (try Support.serverDefinition(&server, allocator, main_uri,
        \\func create_geometry() {}
        \\func rotate_entities() {}
        \\func add_system(system:func()) {}
        \\func main() {
        \\    add_system(create_geo<|>metry)
        \\    add_system(rotate_entities)
        \\}
    )).?;
    try std.testing.expectEqualStrings(main_uri, local.uri);
    try std.testing.expectEqual(@as(usize, 0), local.range.start.line);

    const second_local = (try Support.serverDefinition(&server, allocator, main_uri,
        \\func create_geometry() {}
        \\func rotate_entities() {}
        \\func add_system(system:func()) {}
        \\func main() {
        \\    add_system(create_geometry)
        \\    add_system(rotate_ent<|>ities)
        \\}
    )).?;
    try std.testing.expectEqualStrings(main_uri, second_local.uri);
    try std.testing.expectEqual(@as(usize, 1), second_local.range.start.line);

    const bound_method = (try Support.serverDefinition(&server, allocator, main_uri,
        \\struct Counter {
        \\    func read() int { return 42 }
        \\}
        \\func main() {
        \\    let counter = Counter()
        \\    let read:func() int = counter.re<|>ad
        \\}
    )).?;
    try std.testing.expectEqualStrings(main_uri, bound_method.uri);
    try std.testing.expectEqual(@as(usize, 1), bound_method.range.start.line);

    const imported = (try Support.serverDefinition(&server, allocator, main_uri,
        \\use Systems.Frame.imported_system as frame_system
        \\func add_system(system:func()) {}
        \\func main() { add_system(frame_<|>system) }
    )).?;
    try std.testing.expectEqualStrings(imported_uri, imported.uri);
    try std.testing.expectEqual(@as(usize, 0), imported.range.start.line);
}

test "server navigates imported package declarations to their exact sources" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Math/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Package.json",
        .data = "{\"name\":\"Math\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Module/Operations.sx",
        .data =
        \\public struct Vector {
        \\    func length() int { return 0 }
        \\}
        \\public func add(left:int, right:int) int { return left + right }
        ,
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const operations_uri = try std.fmt.allocPrint(allocator, "file://{s}/Math/Module/Operations.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    try Support.openDocument(&server, allocator, operations_uri, 2,
        \\// unsaved editor overlay
        \\public struct Vector {
        \\    func length() int { return 0 }
        \\}
        \\public func add(left:int, right:int) int { return left + right }
    );

    const vector = (try Support.serverDefinition(&server, allocator, main_uri,
        \\use Math.Operations
        \\func main() { let value = Operations.Vec<|>tor() }
    )).?;
    try std.testing.expectEqualStrings(operations_uri, vector.uri);
    try std.testing.expectEqual(@as(usize, 1), vector.range.start.line);
    try std.testing.expectEqual(@as(usize, 14), vector.range.start.character);
    try std.testing.expectEqual(@as(usize, 20), vector.range.end.character);

    const add = (try Support.serverDefinition(&server, allocator, main_uri,
        \\use Math.Operations
        \\func main() { print(Operations.ad<|>d(1, 2)) }
    )).?;
    try std.testing.expectEqualStrings(operations_uri, add.uri);
    try std.testing.expectEqual(@as(usize, 4), add.range.start.line);
    try std.testing.expectEqual(@as(usize, 12), add.range.start.character);
    try std.testing.expectEqual(@as(usize, 15), add.range.end.character);

    const method = (try Support.serverDefinition(&server, allocator, main_uri,
        \\use Math.Operations
        \\func main() {
        \\    let value = Operations.Vector()
        \\    print(value.len<|>gth())
        \\}
    )).?;
    try std.testing.expectEqualStrings(operations_uri, method.uri);
    try std.testing.expectEqual(@as(usize, 2), method.range.start.line);
    try std.testing.expectEqual(@as(usize, 9), method.range.start.character);
    try std.testing.expectEqual(@as(usize, 15), method.range.end.character);
}

test "server navigates package extensions call chains fields and cascades" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const files = [_]struct { path: []const u8, source: []const u8 }{
        .{ .path = "Kit/Package.json", .source = "{\"name\":\"Kit\",\"version\":\"1.0.0\"}" },
        .{ .path = "Kit/Module/Math/Vec3.sx", .source =
        \\public struct Vec3 {}
        \\extend Vec3 { static func zero() Vec3 { return Vec3() } }
        },
        .{ .path = "Kit/Module/Math/Quat.sx", .source =
        \\public struct Quat { func multiply(other:Quat) Quat { return self } }
        \\extend Quat {
        \\    static func identity() Quat { return Quat() }
        \\    static func angle_axis() Quat { return Quat() }
        \\}
        },
        .{ .path = "Kit/Module/Transform/Transform3D.sx", .source =
        \\use Kit.Math
        \\public struct Transform3D { var rotation:Math.Quat }
        },
        .{ .path = "Kit/Module/Geometry/Cube.sx", .source =
        \\use Kit.Geometry.Mesh as Mesh
        \\public struct Cube { static func make() Mesh { return Mesh() } }
        },
        .{ .path = "Kit/Module/Geometry/Mesh.sx", .source =
        \\use Kit.Math
        \\public struct Mesh { func translated(offset:Math.Vec3) Mesh { return self } }
        },
        .{ .path = "Kit/Module/ECS/EntityRecipe.sx", .source =
        \\public class EntityRecipe { func with<T>(component:T) EntityRecipe { return self } }
        },
        .{ .path = "Kit/Module/ECS/Query.sx", .source = "public class Query<T> {}" },
    };
    for (files) |file| {
        const directory = std.fs.path.dirname(file.path).?;
        try temporary.dir.createDirPath(std.testing.io, directory);
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = file.path, .data = file.source });
    }
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);

    const static_source =
        \\use Kit.Math
        \\func main() {
        \\    print(Math.Vec3.ze<|>ro())
        \\    print(Math.Quat.identity())
        \\    print(Math.Quat.angle_axis())
        \\}
    ;
    const zero = (try Support.serverDefinition(&server, allocator, main_uri, static_source)) orelse return error.MissingZeroDefinition;
    try std.testing.expect(std.mem.endsWith(u8, zero.uri, "/Kit/Module/Math/Vec3.sx"));
    const identity = (try Support.serverDefinition(&server, allocator, main_uri,
        \\use Kit.Math
        \\func main() { print(Math.Quat.ident<|>ity()) }
    )) orelse return error.MissingIdentityDefinition;
    try std.testing.expect(std.mem.endsWith(u8, identity.uri, "/Kit/Module/Math/Quat.sx"));
    const angle_axis = (try Support.serverDefinition(&server, allocator, main_uri,
        \\use Kit.Math
        \\func main() { print(Math.Quat.angle_<|>axis()) }
    )) orelse return error.MissingAngleAxisDefinition;
    try std.testing.expect(std.mem.endsWith(u8, angle_axis.uri, "/Kit/Module/Math/Quat.sx"));

    const translated = (try Support.serverDefinition(&server, allocator, main_uri,
        \\use Kit.Geometry
        \\use Kit.Math
        \\func main() { print(Geometry.Cube.make().trans<|>lated(Math.Vec3())) }
    )) orelse return error.MissingTranslatedDefinition;
    try std.testing.expect(std.mem.endsWith(u8, translated.uri, "/Kit/Module/Geometry/Mesh.sx"));

    const field_chain_source =
        \\use Kit.ECS
        \\struct Rotator {}
        \\func rotate(rotators:ECS.Query<(@Rotator, &Kit.Transform.Transform3D)>) {
        \\    for (rotator, transform) in rotators {
        \\        print(transform.rotation.mul<|>tiply(transform.rotation))
        \\    }
        \\}
    ;
    const multiply = (try Support.serverDefinition(&server, allocator, main_uri, field_chain_source)) orelse return error.MissingMultiplyDefinition;
    try std.testing.expect(std.mem.endsWith(u8, multiply.uri, "/Kit/Module/Math/Quat.sx"));

    const rotation = (try Support.serverDefinition(&server, allocator, main_uri,
        \\use Kit.ECS
        \\struct Rotator {}
        \\func rotate(rotators:ECS.Query<(@Rotator, &Kit.Transform.Transform3D)>) {
        \\    for (rotator, transform) in rotators { print(transform.rot<|>ation) }
        \\}
    )) orelse return error.MissingRotationDefinition;
    try std.testing.expect(std.mem.endsWith(u8, rotation.uri, "/Kit/Module/Transform/Transform3D.sx"));

    const cascade = (try Support.serverDefinition(&server, allocator, main_uri,
        \\use Kit.ECS
        \\func main() {
        \\    var recipe = ECS.EntityRecipe()
        \\        ..wi<|>th(1)
        \\}
    )) orelse return error.MissingCascadeDefinition;
    try std.testing.expect(std.mem.endsWith(u8, cascade.uri, "/Kit/Module/ECS/EntityRecipe.sx"));
}

test "server preserves prefix ranking in the response consumed by Zed" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const items = try Support.serverCompletion(&server, allocator, uri,
        \\func main() {
        \\    l<|>
        \\}
    );
    try Support.expectExactLabels(&.{ "let", "Result", "reflect" }, items);
    try Support.expectFirst("let", items);
    try Support.expectNoDuplicates(items);
}

test "server completes the value of a reexported cascade field from its declared type" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Animator/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module/Scene2D");
    try temporary.dir.createDirPath(std.testing.io, "STD/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"Animator\":\"=1.0.0\",\"GFX\":\"=1.0.0\",\"STD\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Animator/Package.json",
        .data = "{\"name\":\"Animator\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Animator/Module/@Module.sx",
        .data = "public struct Timeline { func advance(delta:float) Timeline { return self } }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"dependencies\":{\"STD\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/Math.sx",
        .data =
        \\public struct Vec2 {
        \\    var x:float
        \\    init(value:float = 0.0) { self.x = value }
        \\    func length() float { return x }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Scene2D/Overlay.sx",
        .data =
        \\use STD.Math
        \\public struct Overlay {
        \\    var position:Math.Vec2
        \\    init(size:int) { self.position = Math.Vec2(size as float) }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Components.sx",
        .data = "public use GFX.Scene2D.Overlay as Overlay2D",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const marked_source =
        \\use GFX.Components
        \\use STD.Math
        \\func make_position() Math.Vec2 { return Math.Vec2() }
        \\func main() {
        \\    var position:Math.Vec2 = Math.Vec2()
        \\    Components.Overlay2D(10)
        \\        ..position = <|>
        \\}
    ;
    const marked = try Support.removeMarker(allocator, marked_source);
    try Support.openDocument(&server, allocator, uri, 1, marked.text);
    const expected = try Workspace.assignmentExpectedTypeAtForTarget(
        allocator,
        std.testing.io,
        null,
        .macos_arm64,
        root_uri,
        uri,
        server.documents.items,
        marked.text,
        marked.cursor,
    );
    try std.testing.expectEqualStrings("Math.Vec2", expected orelse return error.MissingAssignmentExpectedType);
    const items = try Support.serverCompletionInOpenDocument(&server, allocator, uri, marked);
    try Support.expectPresent("position", items);
    try Support.expectPresent("make_position", items);
    try Support.expectPresent("Math", items);
    try Support.expectAbsent("Components", items);
    try Support.expectAbsent("Result", items);
    try Support.expectAbsent("if", items);
    try Support.expectNoDuplicates(items);

    const member_source =
        \\use Animator
        \\use STD.Math
        \\struct Motion { var position:Animator.Timeline }
        \\func main() {
        \\    var positions:Math.Vec2[] = [Math.Vec2()]
        \\    for position in positions {
        \\        position.<|>
        \\    }
        \\}
    ;
    const member_marked = try Support.removeMarker(allocator, member_source);
    try Support.changeDocument(&server, allocator, uri, 2, member_marked.text);
    const members = try Support.serverCompletionInOpenDocument(&server, allocator, uri, member_marked);
    try Support.expectPresent("x", members);
    try Support.expectPresent("length", members);
    try Support.expectFirst("x", members);
    try Support.expectAbsent("advance", members);
    try Support.expectNoDuplicates(members);
}

test "server ranks imported method parameter labels before scope symbols" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use WebView\nfunc main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "WebView.sx",
        .data =
        \\public static class Asset {
        \\    func javascript(source:str, path:str) str { return source }
        \\}
        ,
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const items = try Support.serverCompletion(&server, allocator, uri,
        \\use WebView
        \\func wrap(value:str) str { return value }
        \\func main() {
        \\    let asset = WebView.Asset.javascript(wrap("app.js"), <|>)
        \\}
    );
    try Support.expectFirst("path", items);
    try Support.expectItem(.{
        .label = "path",
        .kind = 6,
        .detail = "path:str",
        .insert_text = "path:",
        .insert_text_format = null,
    }, items);
    try Support.expectNoDuplicates(items);
}

test "server resolves a UTF-16 completion position after non-ASCII text" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const items = try Support.serverCompletion(&server, allocator, uri,
        \\func test(value:str = "😀") i<|>
    );
    try Support.expectFirst("int", items);
    try Support.expectPresent("int32", items);
    try Support.expectAbsent("if", items);
}

test "type contexts expose modules as paths without leaking module values" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Math/Shapes");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Vector.sx",
        .data =
        \\public struct Vector {}
        \\public enum Axis { x; y }
        \\public func make_vector() Vector { return Vector() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Shapes/Circle.sx",
        .data = "public struct Circle {}",
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);

    const return_context_items = try Support.serverCompletion(&server, allocator, uri,
        \\struct LocalType {}
        \\func make_value() LocalType { return LocalType() }
        \\func test() <|>
    );
    try Support.expectPresent("LocalType", return_context_items);
    try Support.expectPresent("Math", return_context_items);
    try Support.expectPresent("Result", return_context_items);
    try Support.expectPresent("int", return_context_items);
    try Support.expectAbsent("make_value", return_context_items);
    try Support.expectAbsent("true", return_context_items);
    try Support.expectAbsent("if", return_context_items);
    try Support.expectNoDuplicates(return_context_items);

    const root_items = try Support.serverCompletion(&server, allocator, uri, "func test() M<|>");
    try Support.expectExactLabels(&.{"Math"}, root_items);
    try Support.expectAbsent("make_vector", root_items);

    const qualified_items = try Support.serverCompletion(
        &server,
        allocator,
        uri,
        "func test() Result<Math.<|>>",
    );
    try Support.expectExactLabels(&.{ "Shapes", "Vector" }, qualified_items);
    try Support.expectAbsent("make_vector", qualified_items);
    try Support.expectAbsent("x", qualified_items);
    try Support.expectAbsent("if", qualified_items);
    try Support.expectNoDuplicates(qualified_items);

    const provider_items = try Support.serverCompletion(
        &server,
        allocator,
        uri,
        "func test() Result<Math.Vector.<|>>",
    );
    try Support.expectPresent("Axis", provider_items);
    try Support.expectAbsent("make_vector", provider_items);
    try Support.expectNoDuplicates(provider_items);
}

test "field parameter and generic annotations expose module paths to types" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Domain");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Domain/Message.sx",
        .data = "public struct Message {}",
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);

    const sources = [_][]const u8{
        \\struct Error {
        \\    let message:<|>
        \\}
        ,
        \\func report(message:<|>) {}
        ,
        \\func draw<T:<|>>() {}
        ,
    };
    for (sources) |source| {
        const items = try Support.serverCompletion(&server, allocator, uri, source);
        try Support.expectPresent("Domain", items);
        try Support.expectPresent("Result", items);
        try Support.expectPresent("str", items);
        try Support.expectAbsent("Message", items);
        try Support.expectAbsent("if", items);
        try Support.expectNoDuplicates(items);
    }

    const qualified_sources = [_][]const u8{
        \\struct Error {
        \\    let message:Domain.<|>
        \\}
        ,
        \\func report(message:Domain.<|>) {}
        ,
        \\func draw<T:Domain.<|>>() {}
        ,
    };
    for (qualified_sources) |source| {
        const items = try Support.serverCompletion(&server, allocator, uri, source);
        try Support.expectExactLabels(&.{"Message"}, items);
    }
}

test "workspace completion uses the unsaved contents of imported documents" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api\nfunc main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public struct DiskType {}",
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const api_uri = try std.fmt.allocPrint(allocator, "file://{s}/Api.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    try Support.openDocument(&server, allocator, api_uri, 1, "public struct PreviousBufferType {}");
    try Support.changeDocument(&server, allocator, api_uri, 2, "public struct BufferType {}");

    const marked = try Support.removeMarker(allocator,
        \\use Api
        \\func test() Result<Api.<|>, str>
    );
    try Support.openDocument(&server, allocator, main_uri, 1, marked.text);
    const items = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{"BufferType"}, items);
    try Support.expectAbsent("DiskType", items);
    try Support.expectAbsent("PreviousBufferType", items);
    try Support.expectNoDuplicates(items);
}
