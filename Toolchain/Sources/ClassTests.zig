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

test "derived classes construct their base and preserve identity through upcasts" {
    const output = try run(
        \\class Entity {
        \\    protected var position:int
        \\    public init(position:int) { self.position = position }
        \\    public func current() int { return self.position }
        \\}
        \\class Player : Entity {
        \\    let name:str
        \\    public init(name:str, position:int) : super(position) { self.name = name }
        \\    public func shift() { self.position += 1 }
        \\    public func label() str { return self.name }
        \\}
        \\func entity(player:Player) Entity { return player }
        \\func position(value:Entity) int { return value.current() }
        \\func main() {
        \\    var player = Player("Ada", 4)
        \\    var base:Entity = player
        \\    player.shift()
        \\    var optional:Entity? = player
        \\    var values:Entity[] = [player]
        \\    print(player.label(), " ", position(player), " ", base.current())
        \\    print(base == entity(player), " ", optional != null, " ", values[0] == base)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("Ada 5 5\ntrue true true\n", output);
}

test "class inheritance rejects invalid bases, cycles, and inherited field collisions" {
    try expectCompileError(
        "struct Value {} class Child : Value {} func main() {}",
        "a class can only inherit from another class",
    );
    try expectCompileError(
        "class First : Second {} class Second : First {} func main() {}",
        "class inheritance forms a cycle",
    );
    try expectCompileError(
        "class Base { protected var value:int = 1 } class Child : Base { var value:int = 2 } func main() {}",
        "field 'value' is already inherited from a base class",
    );
    try expectCompileError(
        "class Base { private var value:int = 1 } class Child : Base { func read() int { return self.value } } func main() {}",
        "field 'value' is private and unavailable here",
    );
}

test "overrides dispatch on the dynamic class and super stays direct" {
    const output = try run(
        \\class Entity {
        \\    public func label() str { return "entity" }
        \\    public func code(value:int) str { return "base $(value)" }
        \\    public func code(value:str) str { return "text $(value)" }
        \\}
        \\class Player : Entity {
        \\    override public func label() str { return "$(super.label()) player" }
        \\    override public func code(value:int) str { return "player $(value)" }
        \\}
        \\class Captain : Player {
        \\    override public func label() str { return "captain" }
        \\}
        \\func label(value:Entity) str { return value.label() }
        \\func code(value:Entity) str { return value.code(7) }
        \\func text(value:Player) str { return value.code("ok") }
        \\func main() {
        \\    var entity = Entity()
        \\    var player = Player()
        \\    var captain = Captain()
        \\    print(label(entity), " | ", label(player), " | ", label(captain))
        \\    print(code(player), " | ", code(captain))
        \\    print(text(player))
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("entity | entity player | captain\nplayer 7 | player 7\ntext ok\n", output);
}

test "override declarations preserve inherited signatures and visibility" {
    try expectCompileError(
        "class Base { public func value() int { return 1 } } class Child : Base { public func value() int { return 2 } } func main() {}",
        "an overriding method must declare 'override'",
    );
    try expectCompileError(
        "class Base {} class Child : Base { override public func value() int { return 2 } } func main() {}",
        "override does not match an inherited method signature",
    );
    try expectCompileError(
        "class Base { public func value() int { return 1 } } class Child : Base { override protected func value() int { return 2 } } func main() {}",
        "an override cannot reduce public visibility",
    );
    try expectCompileError(
        "class Base { public func value() int { return 1 } } class Child : Base { override public func value() str { return \"x\" } } func main() {}",
        "override does not match an inherited method signature",
    );
}

test "mutating overrides and constructor calls bind at the required phase" {
    const output = try run(
        \\class Base {
        \\    protected var value:int = 0
        \\    public init() { self.trace() }
        \\    public func trace() { print("base init") }
        \\    public func bump() { self.value++ }
        \\    public func current() int { return self.value }
        \\}
        \\class Child : Base {
        \\    public init() : super() { self.trace() }
        \\    override public func trace() { print("child init") }
        \\    override public func bump() { super.bump(); super.bump() }
        \\}
        \\func bump(value:Base) { value.bump() }
        \\func main() {
        \\    var child = Child()
        \\    var base:Base = child
        \\    bump(base)
        \\    print(base.current())
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("base init\nchild init\n2\n", output);
}

test "static members use type-qualified shared storage" {
    const output = try run(
        \\struct Counter {
        \\    static var total:int = 2
        \\    static let step:int = 3
        \\    static func value() int { return Counter.total }
        \\    func value() int { return 99 }
        \\    static func add(value:int) int {
        \\        Counter.total += value
        \\        return Counter.total
        \\    }
        \\}
        \\class Token {
        \\    public var value:int
        \\    private static func seed() int { return 7 }
        \\    public static func create() Token { return Token(value:Token.seed()) }
        \\}
        \\func main() {
        \\    print(Counter.value(), " ", Counter.add(Counter.step), " ", Counter().value())
        \\    var token = Token.create()
        \\    print(token.value)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("2 5 99\n7\n", output);
}

test "static members reject instance selection and dynamic initializers" {
    try expectCompileError(
        "func seed() int { return 1 } struct Values { static var current:int = seed() } func main() {}",
        "static initializer must be a deterministic intrinsic value",
    );
    try expectCompileError(
        "struct Values { static let current:int = 1 } func main() { Values.current = 2 }",
        "cannot assign to immutable static field",
    );
    try expectCompileError(
        "struct Values { static func current() int { return 1 } } func main() { let value = Values(); print(value.current()) }",
        "structure 'Values' has no method named 'current' accepting 0 arguments",
    );
}
