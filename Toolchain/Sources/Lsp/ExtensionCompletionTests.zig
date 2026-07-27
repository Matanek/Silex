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

fn hasLabel(items: []const Types.CompletionItem, label: []const u8) bool {
    for (items) |item| if (std.mem.eql(u8, item.label, label)) return true;
    return false;
}

fn itemWithLabel(items: []const Types.CompletionItem, label: []const u8) ?Types.CompletionItem {
    for (items) |item| if (std.mem.eql(u8, item.label, label)) return item;
    return null;
}
