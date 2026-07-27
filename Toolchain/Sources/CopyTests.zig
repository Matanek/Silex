const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");

fn run(source: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const result = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    return std.testing.allocator.dupe(u8, result.stdout);
}

test "copy detaches classes while ordinary copies preserve identity" {
    const output = try run(
        \\class State { public var value:int }
        \\struct Foo { var value:int; var instance:State }
        \\func main() {
        \\    var original = Foo(value:10, instance:State(value:5))
        \\    var shared = original
        \\    var detached = copy original
        \\    shared.instance.value = 6
        \\    detached.instance.value = 9
        \\    print(original.instance == shared.instance, " ", original.instance != detached.instance)
        \\    print(original.instance.value, " ", detached.instance.value, " ", original.value)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("true true\n6 9 10\n", output);
}

test "copy keeps scalar values and gives cloned resources independent lifetimes" {
    const output = try run(
        \\class State {
        \\    public let value:int
        \\    drop { print("state ", self.value) }
        \\}
        \\struct Holder {
        \\    let value:int
        \\    var state:State
        \\    drop { print("holder ", self.value) }
        \\}
        \\func main() {
        \\    let scalar = 7
        \\    let scalar_copy = copy scalar
        \\    var source = Holder(value:scalar_copy, state:State(value:1))
        \\    var detached = copy source
        \\    print(source.state != detached.state)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("true\nholder 7\nstate 1\nholder 7\nstate 1\n", output);
}

test "copy preserves graph aliases cycles dynamic classes and private fields" {
    const output = try run(
        \\class Node {
        \\    private let secret:int
        \\    public var next:Node? = null
        \\    public init(secret:int) { self.secret = secret }
        \\    public func value() int { return self.secret }
        \\}
        \\class Special : Node {
        \\    public init(secret:int) : super(secret) {}
        \\    override public func value() int { return super.value() + 100 }
        \\}
        \\struct Graph { var first:Node; var again:Node }
        \\func cyclic(node:Node) bool {
        \\    if var next = node.next {
        \\        if var back = next.next { return back == node }
        \\    }
        \\    return false
        \\}
        \\func main() {
        \\    var first:Node = Special(7)
        \\    var second = Node(8)
        \\    first.next = second
        \\    second.next = first
        \\    var source = Graph(first:first, again:first)
        \\    var clone = copy source
        \\    print(clone.first == clone.again, " ", clone.first != first, " ", cyclic(clone.first), " ", clone.first.value())
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("true true true 107\n", output);
}

test "copy traverses containers protocols and borrowed operands" {
    const output = try run(
        \\class State { public var value:int }
        \\protocol Boxed { func current() int; func change(value:int) }
        \\struct Holder : Boxed {
        \\    var state:State
        \\    func current() int { return self.state.value }
        \\    func change(value:int) { self.state.value = value }
        \\}
        \\enum Choice { none; some(State) }
        \\func from_read(value:@State) State { return copy value }
        \\func from_mutable(value:&State) State { return copy value }
        \\func main() {
        \\    var state = State(value:5)
        \\    var values:State[] = [state, state]
        \\    var detached = copy values
        \\    var optional:State? = state
        \\    var optional_copy = copy optional
        \\    var choice = Choice.some(state)
        \\    var choice_copy = copy choice
        \\    var erased:Boxed = Holder(state:state)
        \\    var erased_copy = copy erased
        \\    erased_copy.change(9)
        \\    var read_copy = from_read(state)
        \\    var mutable_copy = from_mutable(state)
        \\    print(detached[0] == detached[1], " ", detached[0] != state, " ", erased.current(), " ", erased_copy.current())
        \\    if var present = optional_copy { print(present != state) }
        \\    match choice_copy { some(value) => { print(value != state) }; none => { print(false) } }
        \\    print(read_copy != state, " ", mutable_copy != state)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("true true 5 9\ntrue\ntrue\ntrue true\n", output);
}

test "copy leaves the source available and remains distinct from move" {
    const output = try run(
        \\class State { public var value:int }
        \\func main() {
        \\    var source = State(value:4)
        \\    var clone = copy source
        \\    print(source.value, " ", clone != source)
        \\    var transferred = move source
        \\    print(transferred.value, " ", clone != transferred)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("4 true\n4 true\n", output);
}

test "copy rejects borrowed view results and emits deterministic IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile("func main() { var values = [1, 2]; let clone = copy @values[0:2] }"));
    try std.testing.expectEqualStrings("'copy' cannot produce an owned borrowed-view type", frontend.diagnostic.?.message);

    const source = "class State { public var value:int } func main() { var value = State(value:1); var clone = copy value }";
    var first = Frontend.Frontend.init(arena.allocator());
    var second = Frontend.Frontend.init(arena.allocator());
    const first_text = try Ir.writeText(arena.allocator(), (try first.compile(source)).ir);
    const second_text = try Ir.writeText(arena.allocator(), (try second.compile(source)).ir);
    try std.testing.expectEqualStrings(first_text, second_text);
    try std.testing.expect(std.mem.indexOf(u8, first_text, "deep_copy") != null);
}
