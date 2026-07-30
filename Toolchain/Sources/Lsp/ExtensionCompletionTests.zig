const std = @import("std");
const Completion = @import("Completion.zig");
const Types = @import("Types.zig");
const Workspace = @import("Workspace.zig");

test "complete imported types and their current extension context" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Vec3.sx",
        .data =
        \\public struct Vec3 {
        \\    var x:float
        \\    var y:float
        \\    var z:float
        \\}
        ,
    });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    const member_source =
        \\use Math
        \\extend Math.Vec3 {
        \\    func to_str() str { return "vec" }
        \\}
        \\func main() {
        \\    var v = Math.Vec3()
        \\    print(v.t)
        \\}
    ;
    const member_cursor = std.mem.indexOf(u8, member_source, "v.t").? + "v.t".len;
    const member_items = (try Workspace.itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        member_source,
        member_cursor,
    )).?;
    try std.testing.expectEqual(@as(usize, 1), member_items.len);
    try std.testing.expectEqualStrings("to_str", member_items[0].label);
    try std.testing.expectEqualStrings("to_str()", member_items[0].insertText.?);

    const target_source =
        \\use Math
        \\extend Math. {
        \\    func to_str() str { return "vec" }
        \\}
    ;
    const target_cursor = std.mem.indexOf(u8, target_source, "Math.").? + "Math.".len;
    const target_items = (try Workspace.itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        target_source,
        target_cursor,
    )).?;
    try std.testing.expect(hasLabel(target_items, "Vec3"));

    const self_source =
        \\use Math
        \\extend Math.Vec3 {
        \\    func to_str() str { return "$(self.)" }
        \\}
    ;
    const self_cursor = std.mem.indexOf(u8, self_source, "self.").? + "self.".len;
    const self_items = (try Workspace.itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        self_source,
        self_cursor,
    )).?;
    try std.testing.expect(hasLabel(self_items, "x"));
    try std.testing.expect(hasLabel(self_items, "y"));
    try std.testing.expect(hasLabel(self_items, "z"));
    try std.testing.expect(hasLabel(self_items, "to_str"));

    const expression_source =
        \\use Math
        \\extend Math.Vec3 {
        \\    func to_str() str { return "$(se)" }
        \\}
    ;
    const expression_cursor = std.mem.indexOf(u8, expression_source, "se)").? + "se".len;
    const expression_items = try Completion.itemsAt(
        allocator,
        expression_source,
        expression_cursor,
        .invoked,
    );
    try std.testing.expect(hasLabel(expression_items, "self"));
    try std.testing.expect(!hasLabel(expression_items, "false"));
}

test "complete an imported nominal relation before its body exists" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"0.1.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Bootstrap.sx",
        .data = "public protocol Plugin {}",
    });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    const sources = [_][]const u8{
        \\use GFX.Bootstrap
        \\
        \\struct FooPlugin : Bootstrap.Pl
        \\
        \\func main() {}
        ,
        \\use GFX.Bootstrap
        \\
        \\struct FooPlugin : Bootstrap.Pl {}
        \\
        \\func main() {}
        ,
    };
    for (sources) |source| {
        const cursor = std.mem.indexOf(u8, source, "Bootstrap.Pl").? + "Bootstrap.Pl".len;
        const items = (try Workspace.itemsAt(
            allocator,
            std.testing.io,
            null,
            root_uri,
            uri,
            &.{},
            source,
            cursor,
        )).?;
        const plugin = itemWithLabel(items, "Plugin").?;
        try std.testing.expectEqualStrings("Plugin", plugin.insertText.?);
    }
}

test "complete imported enum variants according to their payload" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public enum State { ready; value(int) }",
    });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const source =
        \\use Api
        \\func main() { let state = Api.State. }
    ;
    const cursor = std.mem.indexOf(u8, source, "Api.State.").? + "Api.State.".len;
    const items = (try Workspace.itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        source,
        cursor,
    )).?;
    const ready = itemWithLabel(items, "ready").?;
    const value = itemWithLabel(items, "value").?;
    try std.testing.expectEqualStrings("ready", ready.insertText.?);
    try std.testing.expect(ready.insertTextFormat == null);
    try std.testing.expectEqualStrings("value($0)", value.insertText.?);
    try std.testing.expectEqual(@as(?u8, 2), value.insertTextFormat);
}

test "complete extensions declared by an on-demand package child module" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "STD/Module/Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"0.1.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/Math.sx",
        .data = "public func pi() float { return 3.14 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/Math/Vec3.sx",
        .data =
        \\public struct Vec3 {
        \\    var x:float
        \\    var y:float
        \\    var z:float
        \\    init() {}
        \\    func length() float { return 0.0 }
        \\}
        \\extend Vec3 {
        \\    func to_str() str { return "vec" }
        \\    static func zero() Vec3 { return Vec3() }
        \\}
        ,
    });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const source =
        \\use STD.Math
        \\func main() {
        \\    var v = Math.Vec3()
        \\    print(v.to)
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "v.to").? + "v.to".len;
    const items = (try Workspace.itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        source,
        cursor,
    )).?;
    try std.testing.expect(hasLabel(items, "to_str"));
    try std.testing.expect(!hasLabel(items, "zero"));

    const constructor_source =
        \\use STD.Math
        \\func main() {
        \\    var v = Math.V
        \\}
    ;
    const constructor_cursor = std.mem.indexOf(u8, constructor_source, "Math.V").? + "Math.V".len;
    const constructors = (try Workspace.itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        constructor_source,
        constructor_cursor,
    )).?;
    const vec3 = itemWithLabel(constructors, "Vec3").?;
    try std.testing.expectEqualStrings("Vec3()", vec3.insertText.?);
    try std.testing.expect(vec3.insertTextFormat == null);
}

test "insert calls and place the cursor inside parameterized functions and methods" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Counter {
        \\    func reset() {}
        \\    func add(value:int) {}
        \\}
        \\func answer() int { return 42 }
        \\func consume(value:int) {}
        \\func main() {
        \\    var counter = Counter()
        \\    counter.
        \\}
    ;
    const member_cursor = std.mem.indexOf(u8, source, "counter.").? + "counter.".len;
    const members = try Completion.itemsAt(arena.allocator(), source, member_cursor, .trigger_character);
    try std.testing.expectEqualStrings("reset()", itemWithLabel(members, "reset").?.insertText.?);
    try std.testing.expect(itemWithLabel(members, "reset").?.insertTextFormat == null);
    try std.testing.expectEqualStrings("add($0)", itemWithLabel(members, "add").?.insertText.?);
    try std.testing.expectEqual(@as(?u8, 2), itemWithLabel(members, "add").?.insertTextFormat);

    const function_source =
        "func answer() int { return 42 }\n" ++
        "func consume(value:int) {}\n" ++
        "func main() {\n" ++
        "    \n" ++
        "    print(true)\n" ++
        "}";
    const function_cursor = std.mem.indexOf(u8, function_source, "    \n").? + "    ".len;
    const functions = try Completion.itemsAt(arena.allocator(), function_source, function_cursor, .invoked);
    try std.testing.expectEqualStrings("answer()", itemWithLabel(functions, "answer").?.insertText.?);
    try std.testing.expect(itemWithLabel(functions, "answer").?.insertTextFormat == null);
    try std.testing.expectEqualStrings("consume($0)", itemWithLabel(functions, "consume").?.insertText.?);
    try std.testing.expectEqual(@as(?u8, 2), itemWithLabel(functions, "consume").?.insertTextFormat);
}

test "reuse an existing call when completing an imported module function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "STD/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"0.1.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/Crypto.sx",
        .data =
        \\public func md5(value:str) str { return value }
        \\public func sha256(value:str) str { return value }
        ,
    });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    const empty_source =
        \\use STD.Crypto
        \\func main() {
        \\    print(Crypto.("value"))
        \\}
    ;
    const empty_cursor = std.mem.indexOf(u8, empty_source, "Crypto.").? + "Crypto.".len;
    const empty_items = (try Workspace.itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        empty_source,
        empty_cursor,
    )).?;
    const md5 = itemWithLabel(empty_items, "md5").?;
    try std.testing.expectEqualStrings("md5", md5.insertText.?);
    try std.testing.expect(md5.insertTextFormat == null);

    const partial_source =
        \\use STD.Crypto
        \\func main() {
        \\    print(Crypto.sh("value"))
        \\}
    ;
    const partial_cursor = std.mem.indexOf(u8, partial_source, "Crypto.sh").? + "Crypto.sh".len;
    const partial_items = (try Workspace.itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        partial_source,
        partial_cursor,
    )).?;
    const sha256 = itemWithLabel(partial_items, "sha256").?;
    try std.testing.expectEqualStrings("sha256", sha256.insertText.?);
    try std.testing.expect(sha256.insertTextFormat == null);

    const new_call_source =
        \\use STD.Crypto
        \\func main() {
        \\    print(Crypto.sh)
        \\}
    ;
    const new_call_cursor = std.mem.indexOf(u8, new_call_source, "Crypto.sh").? + "Crypto.sh".len;
    const new_call_items = (try Workspace.itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        new_call_source,
        new_call_cursor,
    )).?;
    const new_call = itemWithLabel(new_call_items, "sha256").?;
    try std.testing.expectEqualStrings("sha256($0)", new_call.insertText.?);
    try std.testing.expectEqual(@as(?u8, 2), new_call.insertTextFormat);
}

test "complete static members of a module principal type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "STD/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"0.1.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/UUID.sx",
        .data =
        \\public struct UUID {
        \\    public static func random() UUID { return UUID() }
        \\    public func to_str() str { return "uuid" }
        \\}
        \\public func is_supported() bool { return true }
        ,
    });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    const source =
        \\use STD.UUID
        \\func main() {
        \\    print(UUID.)
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "UUID.").? + "UUID.".len;
    const items = (try Workspace.itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        source,
        cursor,
    )).?;
    const random = itemWithLabel(items, "random").?;
    try std.testing.expectEqualStrings("random()", random.insertText.?);
    try std.testing.expect(hasLabel(items, "is_supported"));

    const alias_source =
        \\use STD.UUID as Identifier
        \\func main() {
        \\    print(Identifier.)
        \\}
    ;
    const alias_cursor = std.mem.indexOf(u8, alias_source, "Identifier.").? + "Identifier.".len;
    const alias_items = (try Workspace.itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        alias_source,
        alias_cursor,
    )).?;
    try std.testing.expect(hasLabel(alias_items, "random"));

    const result_source =
        \\use STD.UUID
        \\func main() {
        \\    print(UUID.random().)
        \\}
    ;
    const result_cursor = std.mem.indexOf(u8, result_source, "UUID.random().").? + "UUID.random().".len;
    const result_items = (try Workspace.itemsAt(
        allocator,
        std.testing.io,
        null,
        root_uri,
        uri,
        &.{},
        result_source,
        result_cursor,
    )).?;
    const to_str = itemWithLabel(result_items, "to_str").?;
    try std.testing.expectEqualStrings("to_str()", to_str.insertText.?);
}

test "complete members after a qualified local static call" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Token {
        \\    static func make() Token { return Token() }
        \\    func text() str { return "token" }
        \\}
        \\func main() {
        \\    print(Token.make().)
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "Token.make().").? + "Token.make().".len;
    const items = try Completion.itemsAt(arena.allocator(), source, cursor, .trigger_character);
    const member = itemWithLabel(items, "text").?;
    try std.testing.expectEqualStrings("text()", member.insertText.?);
}

test "insert calls for structure and class constructors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Value {}
        \\class Entity {
        \\    init(name:str) {}
        \\}
        \\func main() {
        \\    var value = Va
        \\    var entity = En
        \\}
    ;
    const value_cursor = std.mem.indexOf(u8, source, "Va\n").? + "Va".len;
    const values = try Completion.itemsAt(arena.allocator(), source, value_cursor, .invoked);
    try std.testing.expectEqualStrings("Value()", itemWithLabel(values, "Value").?.insertText.?);
    try std.testing.expect(itemWithLabel(values, "Value").?.insertTextFormat == null);

    const entity_cursor = std.mem.indexOf(u8, source, "En\n").? + "En".len;
    const entities = try Completion.itemsAt(arena.allocator(), source, entity_cursor, .invoked);
    try std.testing.expectEqualStrings("Entity($0)", itemWithLabel(entities, "Entity").?.insertText.?);
    try std.testing.expectEqual(@as(?u8, 2), itemWithLabel(entities, "Entity").?.insertTextFormat);
}

fn hasLabel(items: []const Types.CompletionItem, label: []const u8) bool {
    for (items) |item| if (std.mem.eql(u8, item.label, label)) return true;
    return false;
}

fn itemWithLabel(items: []const Types.CompletionItem, label: []const u8) ?Types.CompletionItem {
    for (items) |item| if (std.mem.eql(u8, item.label, label)) return item;
    return null;
}
