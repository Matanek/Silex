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

test "extend structures and classes with instance static default and mutating methods" {
    const output = try run(
        \\struct Counter { var value:int }
        \\extend Counter {
        \\    func add(amount:int = 1) int { self.value += amount; return self.value }
        \\    static func zero() Counter { return Counter(value:0) }
        \\}
        \\class Box { public var value:int = 4 }
        \\extend Box { public func double() int { self.value *= 2; return self.value } }
        \\func main() {
        \\    var counter = Counter.zero()
        \\    print(counter.add(), " ", counter.add(2))
        \\    var box = Box()
        \\    print(box.double(), " ", box.value)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("1 3\n8 8\n", output);
}

test "class extension lookup uses the exact declared receiver type" {
    const output = try run(
        \\class Entity {}
        \\class Player : Entity {}
        \\extend Entity { public func label() str { return "entity" } }
        \\extend Player { public func label() str { return "player" } }
        \\func main() {
        \\    var player = Player()
        \\    var entity:Entity = player
        \\    print(player.label(), " ", entity.label())
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("player entity\n", output);
}

test "do not inherit extension methods from a class base" {
    try expectCompileError(
        "class Entity {} class Player : Entity {} extend Entity { public func label() str { return \"entity\" } } func main() { var player = Player(); player.label() }",
        "structure 'Player' has no method named 'label' accepting 0 arguments",
    );
}

test "diagnose extension targets declarations collisions and access" {
    try expectCompileError(
        "struct Value { func read() int { return 1 } } extend Value { func read() int { return 2 } } func main() {}",
        "extension method 'read' conflicts with a method declared by type 'Value'",
    );
    try expectCompileError(
        "enum Choice { one } extend Choice { func read() {} } func main() {}",
        "an extension cannot target an enum, scalar, or collection",
    );
    try expectCompileError(
        "protocol Named { func name() str } extend Named { func other() {} } func main() {}",
        "a protocol cannot be extended",
    );
    try expectCompileError(
        "static class Tools {} extend Tools { static func make() {} } func main() {}",
        "a static class cannot be extended",
    );
    try expectCompileError(
        "struct Box<T> { let value:T } extend Box<int> { func read() int { return 1 } } func main() {}",
        "generic extension targets and specializations are not supported",
    );
    try expectCompileError(
        "class Vault { private let value:int = 4 } extend Vault { public func reveal() int { return self.value } } func main() {}",
        "field 'value' is private and unavailable here",
    );
}

test "activate public extensions through direct and transitive use closure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data =
        \\use Core
        \\use Bridge
        \\func main() { var value = Core.Value(value:7); print(value.label()) }
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Core.sx", .data =
        "public struct Value { public let value:int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Extensions.sx", .data =
        "use Core; extend Core.Value { public func label() int { return self.value } }",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge.sx", .data = "use Extensions" });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("7\n", result.stdout);
}

test "leave extensions inactive without a dependency" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data =
        "use Core; func main() { let value = Core.Value(); value.extra() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Core.sx", .data = "public struct Value {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Unused.sx", .data =
        "use Core; extend Core.Value { public func extra() {} }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("structure 'Core.Value' has no method named 'extra' accepting 0 arguments", compiler.diagnostic.?.message);
}

test "diagnose two extension providers visible in the same use closure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data =
        "use Core; use First; use Second; func main() { let value = Core.Value(); value.read() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Core.sx", .data = "public struct Value {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "First.sx", .data =
        "use Core; extend Core.Value { public func read() int { return 1 } }",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Second.sx", .data =
        "use Core; extend Core.Value { public func read() int { return 2 } }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expect(std.mem.indexOf(u8, compiler.diagnostic.?.message, "extension method 'read'") != null);
    try std.testing.expect(std.mem.indexOf(u8, compiler.diagnostic.?.message, "First") != null);
    try std.testing.expect(std.mem.indexOf(u8, compiler.diagnostic.?.message, "Second") != null);
}
