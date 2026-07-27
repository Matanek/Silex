const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Project = @import("Project.zig");

fn run(source: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const result = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    return std.testing.allocator.dupe(u8, result.stdout);
}

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "validate nominal protocol conformances independently of use" {
    const output = try run(
        \\protocol Named { func name(prefix:@str) str }
        \\protocol Resettable { func reset(value:&int) }
        \\struct Item : Named, Resettable {
        \\    func name(prefix:@str) str { return "item" }
        \\    func reset(value:&int) {}
        \\}
        \\struct Unlisted { func name(prefix:@str) str { return "structural only" } }
        \\func main() { print("valid") }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("valid\n", output);
}

test "classes conform with or without a base and inherit conformances" {
    const output = try run(
        \\protocol Drawable { func draw() str }
        \\protocol Named { func name() str }
        \\protocol AlsoNamed { func name() str }
        \\class Entity : Named {
        \\    public func name() str { return "entity" }
        \\}
        \\class Player : Entity, Drawable, AlsoNamed {
        \\    public func draw() str { return "player" }
        \\}
        \\class Icon : Drawable {
        \\    public func draw() str { return "icon" }
        \\}
        \\func main() { var player = Player(); var icon = Icon(); print(player.name(), " ", icon.draw()) }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("entity icon\n", output);
}

test "diagnose missing private and mismatched protocol requirements" {
    try expectCompileError(
        "protocol Drawable { func draw() } struct Sprite : Drawable {} func main() {}",
        "type 'Sprite' does not implement protocol requirement 'Drawable.draw'",
    );
    try expectCompileError(
        "protocol Drawable { func draw() } class Sprite : Drawable { func draw() {} } func main() {}",
        "method 'draw' satisfying protocol 'Drawable' must be public",
    );
    try expectCompileError(
        "protocol Named { func name(value:@int) str } struct Item : Named { func name(value:&int) str { return \"x\" } } func main() {}",
        "type 'Item' does not implement protocol requirement 'Named.name'",
    );
}

test "reject unsupported protocol declaration forms and dynamic values" {
    try expectCompileError(
        "protocol Value<T> {} func main() {}",
        "generic protocols are not supported",
    );
    try expectCompileError(
        "protocol Child : Parent {} func main() {}",
        "protocol inheritance is not supported",
    );
    try expectCompileError(
        "protocol Factory { func make<T>() } func main() {}",
        "generic protocol methods are not supported",
    );
    try expectCompileError(
        "protocol Drawable { func draw() {} } func main() {}",
        "protocol requirements cannot declare a body",
    );
    try expectCompileError(
        "protocol Drawable { func draw() } func main() { let value:Drawable }",
        "dynamic protocol values are not supported yet",
    );
}

test "compose protocol aliases reexports and dependent conformances" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Types
        \\func main() { let sprite = Types.Sprite(); print(sprite.draw()) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public protocol Drawable { func draw() str }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Facade.sx",
        .data = "public use Api.Drawable as Shape",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Types.sx",
        .data =
        \\use Facade.Shape as Drawable
        \\public struct Sprite : Drawable { public func draw() str { return "sprite" } }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("sprite\n", result.stdout);
}
