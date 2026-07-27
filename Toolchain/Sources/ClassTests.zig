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

test "class constructors establish private invariants and overloads" {
    const output = try run(
        \\class Session {
        \\    let token:str
        \\    private var uses:int = 0
        \\    public init(token:str) { self.token = token }
        \\    public init(code:int, suffix:str = "!") { self.token = "$(code)$(suffix)" }
        \\    public func text() str { return self.token }
        \\    internal func mark() { self.uses++ }
        \\}
        \\class Settings { var hidden:int = 1; public var visible:int }
        \\func main() {
        \\    var first = Session("abc")
        \\    var second = Session(7)
        \\    first.mark()
        \\    var settings = Settings(visible:2)
        \\    print(first.text(), " ", second.text(), " ", settings.visible)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("abc 7! 2\n", output);
}

test "class visibility closes construction and private state" {
    try expectCompileError(
        "class Session { let token:str; public init(token:str) { self.token = token } } func main() { var value = Session(token:\"x\") }",
        "structure 'Session' has constructors and does not accept named fields",
    );
    try expectCompileError(
        "class Vault { init() {} } func main() { var value = Vault() }",
        "constructor of 'Vault' is unavailable here",
    );
    try expectCompileError(
        "class Vault { private var secret:int = 1 } func main() { var value = Vault(); print(value.secret) }",
        "field 'secret' is private and unavailable here",
    );
    try expectCompileError(
        "class Base { protected var value:int = 1 } func main() { var base = Base(); print(base.value) }",
        "field 'value' is protected and unavailable here",
    );
    try expectCompileError(
        "class Settings { private var hidden:int = 1; public var visible:int } func main() { var value = Settings(hidden:2, visible:3) }",
        "field 'hidden' is private and unavailable here",
    );
    try expectCompileError(
        "class Settings { private var hidden:int; public var visible:int } func main() { var value = Settings(visible:3) }",
        "private field 'hidden' requires a default or a constructor",
    );
}
