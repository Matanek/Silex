const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");

fn run(source: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const result = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    return std.testing.allocator.dupe(u8, result.stdout);
}

test "owner structures drop once after move and before replacement" {
    const output = try run(
        \\struct File {
        \\    let descriptor:int
        \\    drop { print("drop ", self.descriptor) }
        \\}
        \\func replace() {
        \\    var current = File(descriptor:1)
        \\    current = File(descriptor:2)
        \\    print("held")
        \\}
        \\func transfer() {
        \\    let source = File(descriptor:3)
        \\    let destination = move source
        \\    print("moved")
        \\}
        \\func main() { replace(); transfer() }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("drop 1\nheld\ndrop 2\nmoved\ndrop 3\n", output);
}

test "owner temporaries transfer through calls and named values require move" {
    const output = try run(
        \\struct File { let descriptor:int; drop { print(self.descriptor) } }
        \\func consume(file:File) { print("consume") }
        \\func forward(file:File) File { return move file }
        \\func main() {
        \\    consume(File(descriptor:4))
        \\    let source = File(descriptor:5)
        \\    let result = forward(move source)
        \\    print("done")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("consume\n4\ndone\n5\n", output);
}

test "owner structures reject copies comparison and mutable references" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\struct File { let descriptor:int; drop {} }
        \\func main() { let first = File(descriptor:1); let second = first }
    ));
    try std.testing.expect(std.mem.containsAtLeast(u8, frontend.diagnostic.?.message, 1, "requires 'move'"));

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\struct File { let descriptor:int; drop {} }
        \\func main() { let first = File(descriptor:1); let second = File(descriptor:1); print(first == second) }
    ));
    try std.testing.expectEqualStrings("owner structures cannot be compared", frontend.diagnostic.?.message);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\struct File { let descriptor:int; drop {} }
        \\func edit(file:&File) {}
        \\func main() {}
    ));
    try std.testing.expect(std.mem.containsAtLeast(u8, frontend.diagnostic.?.message, 1, "cannot be passed through '&T'"));
}

test "owner structures remain inspectable through read references" {
    const output = try run(
        \\struct File { let descriptor:int; drop { print("closed") } }
        \\func inspect(file:@File) { print(file.descriptor) }
        \\func main() { let file = File(descriptor:9); inspect(file) }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("9\nclosed\n", output);
}

test "drop rejects return and try" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\struct File { let descriptor:int; drop { return } }
        \\func main() {}
    ));
    try std.testing.expectEqualStrings("drop cannot contain 'return' or 'try'", frontend.diagnostic.?.message);
}
