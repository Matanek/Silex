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

test "mutable references write through locals fields indexes and forwarding" {
    const output = try run(
        \\struct Inner { var value:int }
        \\struct Box { var inner:Inner; func bump() { self.inner.value += 1 } }
        \\func increment(value:&int) { value += 1 }
        \\func forward(value:&int) { increment(value) }
        \\func mutate_box(box:&Box) { box.bump() }
        \\func grow(values:&int[]) { values.append(40) }
        \\func main() {
        \\    var count = 1
        \\    var box = Box(inner:Inner(value:10))
        \\    var values = [20, 30]
        \\    increment(count)
        \\    increment(box.inner.value)
        \\    forward(values[1])
        \\    mutate_box(box)
        \\    grow(values)
        \\    print(count, box.inner.value, values[1], values[2])
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("2123140\n", output);
}

test "two mutable references may alias and preserve body order" {
    const output = try run(
        \\func sequence(first:&int, second:&int) {
        \\    first += 1
        \\    second *= 3
        \\}
        \\func main() { var value = 4; sequence(value, value); print(value) }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("15\n", output);
}

test "mutating class methods write reconstructed state through a mutable reference" {
    const output = try run(
        \\class Counter {
        \\    private var value:int
        \\    init() { self.value = 0 }
        \\    func increment() { self.value += 1 }
        \\    func add(amount:int) int { self.value += amount; return self.value }
        \\}
        \\class Bucket {
        \\    private var values:int[]
        \\    init() { self.values = [] }
        \\    func append(value:int) { self.values.append(value) }
        \\    func append_twice(value:int) { self.append(value); self.append(value) }
        \\    func count() int { return self.values.count() }
        \\}
        \\func update(counter:&Counter) { counter.increment() }
        \\func add(counter:&Counter, amount:int) int { return counter.add(amount) }
        \\func main() {
        \\    var counter = Counter()
        \\    update(counter)
        \\    print(add(counter, 2))
        \\    var bucket = Bucket()
        \\    bucket.append_twice(7)
        \\    print(bucket.count())
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("3\n2\n", output);
}

test "mutable references copy value returns and reject immutable places and escaping capabilities" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const result = try Interpreter.runCapture(allocator, (try frontend.compile(
        "func copied(value:&int) int { value += 1; return value } func main() { var value = 1; print(copied(value)); print(value) }",
    )).ir);
    try std.testing.expectEqualStrings("2\n2\n", result.stdout);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func change(value:&int) { value += 1 }
        \\func main() { let fixed = 1; change(fixed) }
    ));
    try std.testing.expectEqualStrings("mutable reference requires a var root", frontend.diagnostic.?.message);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        "class State { var value:int } func leak(value:&State) State { return value } func main() {}",
    ));
    try std.testing.expectEqualStrings("mutable-reference parameter 'value' cannot be returned", frontend.diagnostic.?.message);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func conflict(read:@int, edit:&int) {}
        \\func main() { var value = 1; conflict(value, value) }
    ));
    try std.testing.expect(std.mem.containsAtLeast(u8, frontend.diagnostic.?.message, 1, "both '@' and '&'"));
}

test "reference mode does not distinguish overloads" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func update(value:int) {}
        \\func update(value:&int) {}
        \\func main() {}
    ));
    try std.testing.expectEqualStrings("function 'update' with these parameter types is already declared", frontend.diagnostic.?.message);
}
