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

test "callbacks pass as values and remain distinct from shadowed functions" {
    const output = try run(
        \\func predicate(value:@int) bool { return false }
        \\func positive(value:@int) bool { return value > 0 }
        \\struct Tester {
        \\    private var predicate:func(@int) bool
        \\    init(predicate:func(@int) bool) { self.predicate = predicate }
        \\    func test(value:@int) bool { return self.predicate(value) }
        \\}
        \\func apply(value:@int, callback:func(@int) bool) bool { return callback(value) }
        \\func main() {
        \\    let tester = Tester(positive)
        \\    print(tester.test(1), apply(-1, positive))
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("truefalse\n", output);
}

test "void callback types omit an explicit return type" {
    const output = try run(
        \\func consume(value:int) { print(value) }
        \\func apply(callback:func(int)) { callback(42) }
        \\func main() { apply(consume) }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("42\n", output);
}

test "static methods pass as callback values" {
    const output = try run(
        \\struct Systems {
        \\    static func tick() { print("tick") }
        \\}
        \\func invoke(callback:func()) { callback() }
        \\func main() { invoke(Systems.tick) }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("tick\n", output);
}

test "anonymous functions execute as callbacks" {
    const output = try run(
        \\func transform(value:int, callback:func(int) int) int { return callback(value) }
        \\func consume(value:int, callback:func(int)) { callback(value) }
        \\func main() {
        \\    print(transform(40, func(value:int) int { return value + 2 }))
        \\    consume(7, func(value:int) { print(value) })
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("42\n7\n", output);
}

test "anonymous functions capture immutable lexical values" {
    const output = try run(
        \\func apply(callback:func() int) int { return callback() }
        \\func main() {
        \\    let value = 42
        \\    print(apply(func() int { return value }))
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("42\n", output);
}

test "anonymous functions share mutations with captured var bindings" {
    const output = try run(
        \\func each_attr(callback:func(str, str)) { callback("id", "main") }
        \\func main() {
        \\    var result = "element"
        \\    each_attr(func(key:str, value:str) {
        \\        result = result + " $(key)=\"$(value)\""
        \\    })
        \\    print(result)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("element id=\"main\"\n", output);
}

test "methods share captured locals with synchronous callbacks" {
    const output = try run(
        \\struct Element {
        \\    let name:str
        \\    func each_attr(callback:func(str, str)) { callback("id", "main") }
        \\    func render() str {
        \\        var result = self.name
        \\        self.each_attr(func(key:str, value:str) {
        \\            result = result + " $(key)=\"$(value)\""
        \\        })
        \\        return result
        \\    }
        \\}
        \\func main() { print(Element(name:"element").render()) }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("element id=\"main\"\n", output);
}

test "capturing closures cannot outlive their lexical environment" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func invalid() func() int {
        \\    let value = 42
        \\    return func() int { return value }
        \\}
        \\func main() {}
    ));
    try std.testing.expectEqualStrings(
        "capturing function value cannot be returned from its lexical scope",
        frontend.diagnostic.?.message,
    );
}

test "copies of a closure share the same captured var" {
    const output = try run(
        \\func main() {
        \\    var count = 0
        \\    var first = func() { count += 1 }
        \\    var second = first
        \\    first()
        \\    second()
        \\    print(count)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("2\n", output);
}

test "nested anonymous callbacks capture transitive lexical context" {
    const output = try run(
        \\func apply(value:int, callback:func(int) int) int { return callback(value) }
        \\func main() {
        \\    let base = 30
        \\    print(apply(5, func(outer:int) int {
        \\        let offset = 2
        \\        return apply(outer, func(inner:int) int {
        \\            return base + outer + offset + inner
        \\        })
        \\    }))
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("42\n", output);
}

test "anonymous callbacks survive generic handle specialization" {
    const output = try run(
        \\protocol Task { func execute() }
        \\class Handle<T:Task> {
        \\    var task:T
        \\    public init(task:T) { self.task = task }
        \\    public func complete() T { return self.task }
        \\}
        \\func submit<T:Task>(task:T, callback:func(T)) Handle<T> {
        \\    callback(task)
        \\    return Handle<T>(task)
        \\}
        \\struct CheckTask:Task {
        \\    var name:str
        \\    func execute() {}
        \\}
        \\func main() {
        \\    var handle = submit(CheckTask(name:"callback-ran"), func(task:CheckTask) { print(task.name) })
        \\    handle.complete()
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("callback-ran\n", output);
}
