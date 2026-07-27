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

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "classes preserve shared identity through transport and containers" {
    const output = try run(
        \\class Player {
        \\    public var health:int = 100
        \\    public func damage(amount:int) { self.health -= amount }
        \\}
        \\struct Holder { public var player:Player }
        \\func touch(player:Player) Player { player.damage(1); return player }
        \\func health(player:Player?) int {
        \\    if var present = player { return present.health }
        \\    return 0
        \\}
        \\func main() {
        \\    var first = Player()
        \\    var second = first
        \\    second.damage(10)
        \\    var returned = touch(first)
        \\    var holder = Holder(player:first)
        \\    holder.player.damage(4)
        \\    var players:Player[] = [first]
        \\    players[0].damage(5)
        \\    var optional:Player? = first
        \\    var absent:Player?
        \\    print(first.health, " ", returned == second, " ", first != Player())
        \\    print(holder.player == players[0], " ", health(optional), " ", absent == null)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("80 true true\ntrue 80 true\n", output);
}

test "classes allow recursive optional links" {
    const output = try run(
        \\class Node { public var value:int; public var next:Node? = null }
        \\func value(node:Node?) int {
        \\    if var present = node { return present.value }
        \\    return 0
        \\}
        \\func main() {
        \\    var first = Node(value:1)
        \\    var second = Node(value:2, next:first)
        \\    print(value(second.next))
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("1\n", output);
}

test "class references require mutable initialized storage" {
    try expectCompileError(
        "class Player {} func main() { let player = Player() }",
        "a binding that can reach a class reference must use 'var'",
    );
    try expectCompileError(
        "class Player {} func main() { var player:Player }",
        "a class binding requires an initializer; use an optional to start at null",
    );
    try expectCompileError(
        "class Player {} struct Holder { let player:Player } func main() {}",
        "a field that can reach a class reference must use 'var'",
    );
    try expectCompileError(
        "class Player {} func main() { let players:Player[] = [Player()] }",
        "a binding that can reach a class reference must use 'var'",
    );
}
