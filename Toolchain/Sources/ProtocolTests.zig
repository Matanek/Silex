const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Project = @import("Project.zig");
const Ir = @import("Ir.zig");

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

test "dynamic protocol values copy structures and preserve class identity" {
    const output = try run(
        \\protocol Counter { func advance() int }
        \\struct Step : Counter {
        \\    var value:int
        \\    func advance() int { self.value += 1; return self.value }
        \\}
        \\class Shared : Counter {
        \\    public var value:int = 10
        \\    public func advance() int { self.value += 1; return self.value }
        \\}
        \\func main() {
        \\    let source = Step(value:1)
        \\    var erased:Counter = source
        \\    print(erased.advance(), " ", source.value)
        \\    var shared = Shared()
        \\    erased = shared
        \\    print(erased.advance(), " ", shared.value)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("2 1\n11 11\n", output);
}

test "transport dynamic protocol values through language containers" {
    const output = try run(
        \\protocol Readable { func read() int }
        \\struct Number : Readable { let value:int; func read() int { return self.value } }
        \\struct Holder { var value:Readable }
        \\func relay(value:Readable) Readable { return value }
        \\func main() {
        \\    var direct:Readable = Number(value:4)
        \\    var holder = Holder(value:direct)
        \\    var optional:Readable? = Number(value:5)
        \\    let values:Readable[] = [Number(value:6), Number(value:7)]
        \\    var returned = relay(holder.value)
        \\    if var present = optional { print(returned.read(), " ", present.read()) }
        \\    var selected:Readable = values[1]
        \\    print(selected.read())
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("4 5\n7\n", output);
}

test "dynamic protocol values expose only requirements and require mutable copyable storage" {
    try expectCompileError(
        "protocol Readable { func read() int } struct Number : Readable { func read() int { return 1 } func hidden() {} } func main() { var value:Readable = Number(); value.hidden() }",
        "structure 'Readable' has no method named 'hidden' accepting 0 arguments",
    );
    try expectCompileError(
        "protocol Readable { func read() int } struct Number : Readable { func read() int { return 1 } } func main() { let value:Readable = Number(); value.read() }",
        "a binding that can reach a class reference must use 'var'",
    );
    try expectCompileError(
        "protocol Readable { func read() int } struct Owner : Readable { drop {} func read() int { return 1 } } func main() { var value:Readable = Owner() }",
        "a noncopyable structure cannot be erased into a dynamic protocol value",
    );
    try expectCompileError(
        "protocol Readable { func read() int } struct Number : Readable { func read() int { return 1 } } func inspect(value:@Readable) {} func main() {}",
        "dynamic protocol values cannot use '@' or '&'",
    );
}

test "dynamic protocol values retain one shared class identity until final drop" {
    const output = try run(
        \\protocol Live { func touch() }
        \\class Resource : Live {
        \\    public func touch() { print("alive") }
        \\    drop { print("drop") }
        \\}
        \\func main() {
        \\    var resource = Resource()
        \\    var erased:Live = resource
        \\    erased.touch()
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("alive\ndrop\n", output);
}

test "protocol erasure has deterministic explicit portable IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        "protocol Readable { func read() int } struct Number : Readable { func read() int { return 4 } } func main() { var value:Readable = Number(); print(value.read()) }",
    );
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "protocol.init @Readable") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "protocol.test") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "protocol.extract") != null);
}

test "compose dynamic protocol values across module boundaries" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data =
        \\use Api
        \\use Model
        \\func main() { var value:Api.Readable = Model.Number(value:9); print(value.read()) }
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Api.sx", .data =
        "public protocol Readable { func read() int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Model.sx", .data =
        "use Api; public struct Number : Api.Readable { public let value:int; public func read() int { return self.value } }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("9\n", result.stdout);
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
        "a dynamic protocol value requires an initializer",
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
