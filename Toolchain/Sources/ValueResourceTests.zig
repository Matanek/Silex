const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");

fn run(source: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const result = try Interpreter.runCapture(arena.allocator(), (try frontend.compile(source)).ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    return std.testing.allocator.dupe(u8, result.stdout);
}

test "recursive dynamic-array values copy and destroy finite trees" {
    const output = try run(
        \\class Token { static var destroyed:int = 0; drop { Token.destroyed++ } }
        \\struct Item { var token:Token?; let label:str; var children:Item[] }
        \\func relay(item:Item) Item { return item }
        \\func main() {
        \\    {
        \\        var item = Item(token:Token(), label:"root", children:[Item(token:Token(), label:"leaf", children:[])])
        \\        var copied = relay(item)
        \\        assert(copied.children[0].label == "leaf")
        \\        assert(Token.destroyed == 0)
        \\    }
        \\    assert(Token.destroyed == 2)
        \\    print("recursive values ok")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("recursive values ok\n", output);
}

test "mutually recursive arrays preserve copies and empty leaves" {
    const output = try run(
        \\struct Left { let label:str; var children:Right[] }
        \\struct Right { var children:Left[] }
        \\func main() {
        \\    var tree = Left(label:"root", children:[Right(children:[Left(label:"leaf", children:[])])])
        \\    var copied = tree
        \\    assert(copied.children[0].children[0].label == "leaf")
        \\    print("mutual values ok")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("mutual values ok\n", output);
}
