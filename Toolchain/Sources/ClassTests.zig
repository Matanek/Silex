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

test "class parameter modes separate instance mutation observation and reference replacement" {
    const output = try run(
        \\class Counter {
        \\    public var value:int
        \\    public func increment() { self.value++ }
        \\}
        \\struct Holder { var counter:Counter }
        \\func inspect(counter:@Counter) int { return counter.value }
        \\func inspect_holder(holder:@Holder) int { return holder.counter.value }
        \\func modify(counter:Counter) { counter.value = 10; counter.increment() }
        \\func modify_holder(holder:Holder) { holder.counter.value = 12 }
        \\func replace(counter:&Counter) { counter = Counter(value:20) }
        \\func replace_optional(counter:&Counter?) { counter = Counter(value:30) }
        \\func main() {
        \\    var first = Counter(value:1)
        \\    var alias = first
        \\    modify(first)
        \\    var holder = Holder(counter:first)
        \\    modify_holder(holder)
        \\    replace(alias)
        \\    var optional:Counter? = null
        \\    replace_optional(optional)
        \\    if var present = optional {
        \\        print(inspect(first), " ", inspect_holder(holder), " ", alias.value, " ", present.value, " ", first == alias)
        \\    }
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("12 12 20 30 false\n", output);
}

test "read-reference class parameters reject direct transitive and dynamic mutation" {
    try expectCompileError(
        "class Counter { public var value:int } func change(counter:@Counter) { counter.value = 1 } func main() {}",
        "cannot mutate through read-reference parameter 'counter'",
    );
    try expectCompileError(
        "class Counter { public var value:int; public func increment() { self.value++ } } func change(counter:@Counter) { counter.increment() } func main() {}",
        "mutating method 'increment' cannot be called through a read reference",
    );
    try expectCompileError(
        "class Counter { public var value:int; public func increment() { self.value++ } } struct Holder { var counter:Counter } func change(holder:@Holder) { holder.counter.increment() } func main() {}",
        "mutating method 'increment' cannot be called through a read reference",
    );
    try expectCompileError(
        "class Counter { public var value:int } func conflict(read:@Counter, write:Counter) { write.value = 1 } func main() { var value = Counter(value:0); conflict(value, value) }",
        "cannot pass 'value' as both a read reference and a mutation-capable class value",
    );
    try expectCompileError(
        "class Base { public func inspect() {} } class Child : Base { public var value:int = 0; override public func inspect() { self.value++ } } func main() {}",
        "an override cannot introduce receiver mutation",
    );
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
        \\    public init(value:str) { self.token = value }
        \\    public init(value:int, suffix:str = "!") { self.token = "$(value)$(suffix)" }
        \\    public func text() str { return self.token }
        \\    local func mark() { self.uses++ }
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

test "class constructor parameters survive when retained by the new instance" {
    const output = try run(
        \\class Token {
        \\    public let label:str
        \\    drop { print("drop ", self.label) }
        \\}
        \\struct Lifetime { var token:Token? = null }
        \\class Owner {
        \\    private var lifetime:Lifetime = Lifetime()
        \\    public init(token:Token) { self.lifetime = Lifetime(token:token) }
        \\    public func label() str {
        \\        if var token = self.lifetime.token { return token.label }
        \\        return "missing"
        \\    }
        \\}
        \\func main() {
        \\    var token = Token(label:"alive")
        \\    var owner = Owner(token)
        \\    print(owner.label())
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("alive\ndrop alive\n", output);
}

test "constructed values transfer nested class roots through bindings returns and arguments" {
    const output = try run(
        \\class Token {
        \\    public let label:str
        \\    drop { print("drop ", self.label) }
        \\}
        \\struct Holder { var token:Token }
        \\class Sink { public func accept(holder:Holder) {} }
        \\func wrap(token:Token) Holder { return Holder(token:token) }
        \\func accept(holder:Holder) {}
        \\func main() {
        \\    var token = Token(label:"owned")
        \\    var sink = Sink()
        \\    sink.accept(Holder(token:token))
        \\    sink.accept(holder:Holder(token:token))
        \\    accept(Holder(token:token))
        \\    var holder = wrap(token)
        \\    print("alive ", holder.token.label)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("alive owned\ndrop owned\n", output);
}

test "conditional binding consumes a transferred optional class root" {
    const output = try run(
        \\class Token { drop { print("drop") } }
        \\func create() Token? { return Token() }
        \\func main() {
        \\    if var token = create() { print(token == token) }
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("true\ndrop\n", output);
}

test "class visibility closes construction and private state" {
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

test "nonmutating override bodies preserve a mutating receiver contract" {
    const output = try run(
        \\class Base {
        \\    protected var value:int = 0
        \\    public func hook() { self.value++ }
        \\    public func run() { self.hook(); self.value++ }
        \\    public func current() int { return self.value }
        \\}
        \\class Child : Base {
        \\    override public func hook() { print("child") }
        \\}
        \\func main() {
        \\    var value:Base = Child()
        \\    value.run()
        \\    print(value.current())
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("child\n1\n", output);
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

test "static let evaluates deterministic intrinsic expressions and functions" {
    const output = try run(
        \\struct Constants {
        \\    static let width:int = 960
        \\    static let margin:float = 8.0
        \\    static let half:float = Constants.extent(Constants.width, Constants.margin)
        \\    static let enabled:bool = Constants.width > 0 && Constants.half == 472.0
        \\    static func half_of(size:int) float { return size as float * 0.5 }
        \\    static func extent(size:int, margin:float) float {
        \\        let half:float = Constants.half_of(size)
        \\        return half - margin
        \\    }
        \\}
        \\func doubled(value:int) int { return value * 2 }
        \\func doubled(value:float) float { return value * 2.0 }
        \\struct More { static let count:int = doubled(value:21) }
        \\func main() {
        \\    print(Constants.half, " ", Constants.enabled, " ", More.count)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("472.0 true 42\n", output);
}

test "immutable intrinsic static members lower directly to constants" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Values {
        \\    static let integer:int = 42
        \\    static let ratio:float = 1.5
        \\    static let ready:bool = true
        \\    static var mutable:int = 3
        \\}
        \\func main() {
        \\    print(Values.integer, " ", Values.ratio, " ", Values.ready, " ", Values.mutable)
        \\}
    );
    var saw_integer = false;
    var saw_float = false;
    var saw_boolean = false;
    var global_loads: usize = 0;
    for (compilation.ir.functions[0].blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .constant_int => |value| if (value.bits == 42) { saw_integer = true; },
        .constant_float32 => |value| if (value.bits == @as(u32, @bitCast(@as(f32, 1.5)))) { saw_float = true; },
        .constant_bool => |value| if (value.value) { saw_boolean = true; },
        .global_load => global_loads += 1,
        else => {},
    };
    try std.testing.expect(saw_integer);
    try std.testing.expect(saw_float);
    try std.testing.expect(saw_boolean);
    try std.testing.expectEqual(@as(usize, 1), global_loads);
}

test "static initializers reject effects mutable dependencies and cycles" {
    try expectCompileError(
        "func seed() int { print(1); return 1 } struct Values { static let current:int = seed() } func main() {}",
        "static initializer calls a function that is not compile-time evaluable",
    );
    try expectCompileError(
        "struct Values { static var seed:int = 1; static let current:int = Values.seed } func main() {}",
        "static initializer cannot read mutable static field 'seed'",
    );
    try expectCompileError(
        "struct Values { static let first:int = Values.second; static let second:int = Values.first } func main() {}",
        "static initializer dependency forms a cycle",
    );
}

test "static members reject instance selection and immutable assignment" {
    try expectCompileError(
        "struct Values { static let current:int = 1 } func main() { Values.current = 2 }",
        "cannot assign to immutable static field",
    );
    try expectCompileError(
        "struct Values { static func current() int { return 1 } } func main() { let value = Values(); print(value.current()) }",
        "structure 'Values' has no method named 'current' accepting 0 arguments",
    );
}

test "static classes group state without creating instances" {
    const output = try run(
        \\static class Tasks {
        \\    public static var submitted:int = 0
        \\    private static func next() int { return Tasks.submitted + 1 }
        \\    public static func submit() { Tasks.submitted = Tasks.next() }
        \\    public static func identity<T>(value:T) T { return value }
        \\}
        \\func main() {
        \\    Tasks.submit()
        \\    Tasks.submit()
        \\    print(Tasks.submitted, " ", Tasks.identity("ready"))
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("2 ready\n", output);
}

test "static classes reject instance features" {
    try expectCompileError(
        "static class Tasks {} func main() { var tasks = Tasks() }",
        "static classes cannot be constructed",
    );
    try expectCompileError(
        "static class Tasks { var count:int } func main() {}",
        "static class fields must start with 'static let' or 'static var'",
    );
    try expectCompileError(
        "static class Tasks { func run() {} } func main() {}",
        "static class methods must start with 'static func'",
    );
    try expectCompileError(
        "static class Tasks { init() {} } func main() {}",
        "static classes cannot declare constructors",
    );
    try expectCompileError(
        "static class Tasks { drop {} } func main() {}",
        "static classes cannot declare drop",
    );
    try expectCompileError(
        "static class Tasks<T> {} func main() {}",
        "static classes cannot be generic",
    );
    try expectCompileError(
        "static class Tasks {} class Child : Tasks {} func main() {}",
        "a class can only inherit from another class",
    );
}

test "nested nominal types qualify without capturing an owner" {
    const output = try run(
        \\struct Api {
        \\    struct Entry { let value:int }
        \\    static class State {
        \\        public static var count:int = 0
        \\        public static func bump() { State.count++ }
        \\    }
        \\}
        \\class Container {
        \\    public class Item { public let label:str }
        \\}
        \\func main() {
        \\    let entry:Api.Entry = Api.Entry(value:7)
        \\    var item = Container.Item(label:"nested")
        \\    Api.State.bump()
        \\    print(entry.value, " ", item.label, " ", Api.State.count)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("7 nested 1\n", output);
}

test "nested families share private access without leaking private types" {
    const output = try run(
        \\class Vault {
        \\    private static var seed:int = 40
        \\    class Key {
        \\        private let value:int
        \\        func shifted() int { return self.value + Vault.seed }
        \\    }
        \\    public static func key() Key { return Key(value:2) }
        \\    public static func read(key:Key) int { return key.shifted() }
        \\}
        \\func main() { var key = Vault.key(); print(Vault.read(key)) }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("42\n", output);

    try expectCompileError(
        "class Vault { class Key {} } func main() { var key = Vault.Key() }",
        "type 'Vault.Key' is unavailable in this context",
    );
    try expectCompileError(
        "struct Api { static var Entry:int = 1; struct Entry {} } func main() {}",
        "a nested type and static member cannot share a name",
    );
}

test "protected nested classes require qualification and are not inherited" {
    const output = try run(
        \\class Base { protected class Token { public let value:int } }
        \\class Child : Base {
        \\    public static func token() Base.Token { return Base.Token(value:9) }
        \\}
        \\func main() { var token = Child.token(); print(token.value) }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("9\n", output);

    try expectCompileError(
        "class Base { public class Token {} } class Child : Base { public static func token() Token { return Token() } } func main() {}",
        "unknown function 'Token'",
    );
}

test "class drop waits for the last scoped alias and runs once" {
    const output = try run(
        \\class Tracer {
        \\    public let label:str
        \\    drop { print("drop ", self.label) }
        \\}
        \\func main() {
        \\    var first = Tracer(label:"one")
        \\    if true { var alias = first; print("alias ", alias.label) }
        \\    print("alive ", first.label)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("alias one\nalive one\ndrop one\n", output);
}

test "replacing the last class root drops the old instance immediately" {
    const output = try run(
        \\class Tracer { public let label:str; drop { print("drop ", self.label) } }
        \\func main() {
        \\    var value = Tracer(label:"old")
        \\    value = Tracer(label:"new")
        \\    print("current ", value.label)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("drop old\ncurrent new\ndrop new\n", output);
}

test "resetting a static optional root releases its class graph" {
    const output = try run(
        \\class Tracer { public let label:str; drop { print("drop ", self.label) } }
        \\static class Roots { public static var current:Tracer? = null }
        \\func main() {
        \\    Roots.current = Tracer(label:"shared")
        \\    print("held")
        \\    Roots.current = null
        \\    print("reset")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("held\ndrop shared\nreset\n", output);
}

test "class drop follows derived base and owned field order" {
    const output = try run(
        \\struct Resource { let name:str; drop { print("resource ", self.name) } }
        \\class Base { drop { print("base") } }
        \\class Owner : Base {
        \\    let resource:Resource
        \\    public init(name:str) : super() { self.resource = Resource(name:name) }
        \\    drop { print("owner") }
        \\}
        \\func main() { var owner = Owner("file") }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("owner\nbase\nresource file\n", output);
}

test "class drop follows the dynamic type after an upcast" {
    const output = try run(
        \\class Base { drop { print("base") } }
        \\class Child : Base { drop { print("child") } }
        \\func main() { var value:Base = Child() }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("child\nbase\n", output);
}

test "last released root finalizes its unreachable cycle once while the graph is readable" {
    const output = try run(
        \\class Node {
        \\    public let name:str
        \\    public var next:Node? = null
        \\    drop { print("drop ", self.name, " linked=", self.next != null) }
        \\}
        \\func main() {
        \\    var first = Node(name:"first")
        \\    var second = Node(name:"second")
        \\    first.next = second
        \\    second.next = first
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("drop first linked=true\ndrop second linked=true\n", output);
}

test "unreachable cycles crossing dynamic collections finalize every class once" {
    const output = try run(
        \\class Node {
        \\    public let name:str
        \\    public var links:Node[]
        \\    public init(name:str) { self.name = name; self.links = [] }
        \\    drop { print("drop ", self.name, " links=", self.links.count()) }
        \\}
        \\func main() {
        \\    var first = Node("first")
        \\    var second = Node("second")
        \\    first.links.append(second)
        \\    second.links.append(first)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("drop first links=1\ndrop second links=1\n", output);
}

test "unreachable cycles crossing protocol values finalize every class once" {
    const output = try run(
        \\protocol Link { func label() str }
        \\class Node : Link {
        \\    public let name:str
        \\    public var next:Link? = null
        \\    public func label() str { return self.name }
        \\    drop { print("drop ", self.name) }
        \\}
        \\func main() {
        \\    var first = Node(name:"first")
        \\    var second = Node(name:"second")
        \\    first.next = second
        \\    second.next = first
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("drop first\ndrop second\n", output);
}
