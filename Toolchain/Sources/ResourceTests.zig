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

test "drop structures run once after move and before replacement" {
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

test "drop structure temporaries transfer explicitly with move" {
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

test "drop structures copy compare and use ordinary borrows" {
    const output = try run(
        \\struct Item { var value:int; drop { print("drop ", self.value) } }
        \\func duplicate(value:Item) Item { return value }
        \\func inspect(value:@Item) int { return value.value }
        \\func edit(value:&Item) { value.value += 1 }
        \\func main() {
        \\    var first = Item(value:1)
        \\    var second = first
        \\    second = second
        \\    edit(second)
        \\    let returned = duplicate(first)
        \\    print(inspect(first), " ", second.value, " ", first == returned)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings(
        "drop 1\ndrop 1\n1 2 true\ndrop 1\ndrop 2\ndrop 1\n",
        output,
    );
}

test "drop structures remain inspectable through read references" {
    const output = try run(
        \\struct File { let descriptor:int; drop { print("closed") } }
        \\func inspect(file:@File) { print(file.descriptor) }
        \\func main() { let file = File(descriptor:9); inspect(file) }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("9\nclosed\n", output);
}

test "owned temporaries borrowed by calls are released after every call form" {
    const output = try run(
        \\class Counter { var drops:int }
        \\class Token {
        \\    var counter:Counter
        \\    init(counter:Counter) { self.counter = counter }
        \\    drop { self.counter.drops++ }
        \\}
        \\struct Parcel { var tokens:Token[] }
        \\func make(counter:Counter) Parcel { return Parcel(tokens:[Token(counter)]) }
        \\func inspect(parcel:@Parcel) int { return parcel.tokens.count() }
        \\struct Inspector { func inspect(parcel:@Parcel) int { return parcel.tokens.count() } }
        \\struct Measurement {
        \\    let count:int
        \\    init(parcel:@Parcel) { self.count = parcel.tokens.count() }
        \\}
        \\func invoke(callback:func(@Parcel) int, counter:Counter) int {
        \\    return callback(make(counter))
        \\}
        \\func main() {
        \\    var counter = Counter(drops:0)
        \\    let positional = inspect(make(counter))
        \\    print(positional, " ", counter.drops)
        \\    let named = inspect(parcel:make(counter))
        \\    print(named, " ", counter.drops)
        \\    let method = Inspector().inspect(make(counter))
        \\    print(method, " ", counter.drops)
        \\    let measurement = Measurement(make(counter))
        \\    print(measurement.count, " ", counter.drops)
        \\    let callback = invoke(inspect, counter)
        \\    print(callback, " ", counter.drops)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("1 1\n1 2\n1 3\n1 4\n1 5\n", output);
}

test "copies with drop preserve shared class fields" {
    const output = try run(
        \\class State {
        \\    var value:int
        \\    drop { print("state ", self.value) }
        \\}
        \\struct Box {
        \\    var state:State
        \\    drop { print("box ", self.state.value) }
        \\}
        \\func main() {
        \\    var state = State(value:1)
        \\    var first = Box(state:state)
        \\    var second = first
        \\    second.state.value = 7
        \\    print(first.state == second.state, " ", first.state.value)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("true 7\nbox 7\nbox 7\nstate 7\n", output);
}

test "drop copies lower to deterministic portable IR" {
    const source =
        \\struct Item { let value:int; drop { print(self.value) } }
        \\func main() { let first = Item(value:1); let second = first }
    ;
    var first_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer first_arena.deinit();
    var second_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer second_arena.deinit();
    var first = Frontend.Frontend.init(first_arena.allocator());
    var second = Frontend.Frontend.init(second_arena.allocator());
    const first_text = try Ir.writeText(first_arena.allocator(), (try first.compile(source)).ir);
    const second_text = try Ir.writeText(second_arena.allocator(), (try second.compile(source)).ir);
    try std.testing.expectEqualStrings(first_text, second_text);
    try std.testing.expect(std.mem.indexOf(u8, first_text, "Item.$drop") != null);
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
