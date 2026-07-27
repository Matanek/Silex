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

test "generic constraints specialize requirements for every supported family" {
    const output = try run(
        \\protocol Describable { func describe() str }
        \\struct User : Describable { func describe() str { return "user" } }
        \\class Entity : Describable { public func describe() str { return "entity" } }
        \\class Child : Entity {}
        \\func describe<T : Describable>(value:T) str { return value.describe() }
        \\struct Wrapper<T : Describable> {
        \\    let value:T
        \\    func text() str { return self.value.describe() }
        \\}
        \\enum Choice<T : Describable> { some(T); none }
        \\class Box<T : Describable> {
        \\    public let value:T
        \\    public init(value:T) { self.value = value }
        \\    public func text() str { return self.value.describe() }
        \\}
        \\struct Helper { func text<T : Describable>(value:T) str { return value.describe() } }
        \\func choice_text(value:Choice<User>) str {
        \\    return match value { some(item) => item.describe(); none => "none" }
        \\}
        \\func main() {
        \\    let user = User()
        \\    var child = Child()
        \\    var box = Box<User>(user)
        \\    print(describe(user), " ", describe<Child>(child))
        \\    print(Wrapper<User>(value:user).text(), " ", box.text())
        \\    print(Helper().text(user), " ", choice_text(Choice<User>.some(user)))
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("user entity\nuser user\nuser user\n", output);
}

test "generic constraints reject absent conformance and non-protocol contracts" {
    try expectCompileError(
        "struct Marker {} func read<T : Marker>(value:T) {} func main() {}",
        "generic constraint on 'T' must name a protocol",
    );
    try expectCompileError(
        "protocol Named { func name() str } struct Rock {} func read<T : Named>(value:T) {} func main() { read(Rock()) }",
        "type 'Rock' does not conform to protocol 'Named' required by 'T'",
    );
    try expectCompileError(
        "protocol Named { func name() str } struct Rock {} struct Box<T : Named> { let value:T } func main() { let box = Box<Rock>(value:Rock()) }",
        "type 'Rock' does not conform to protocol 'Named' required by 'T'",
    );
}

test "compose a constrained generic through a protocol reexport" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Model
        \\use Render
        \\func main() { print(Render.label(Model.Item())) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public protocol Named { func name() str }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Facade.sx",
        .data = "public use Api.Named as Named",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Model.sx",
        .data = "use Facade.Named; public struct Item : Named { public func name() str { return \"item\" } }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Render.sx",
        .data = "use Facade.Named; public func label<T : Named>(value:T) str { return value.name() }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    var found_constraint = false;
    for (compilation.interfaces) |interface| {
        if (!std.mem.eql(u8, interface.name, "Render")) continue;
        for (interface.functions) |function| if (std.mem.eql(u8, function.export_name, "label")) {
            try std.testing.expectEqual(@as(usize, 1), function.type_parameter_constraints.len);
            try std.testing.expect(function.type_parameter_constraints[0] != null);
            found_constraint = true;
        };
    }
    try std.testing.expect(found_constraint);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("item\n", result.stdout);
}
