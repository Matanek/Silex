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

test "instance methods bind their receiver as callback values" {
    const output = try run(
        \\struct Counter {
        \\    var value:int
        \\    func read(offset:int) int { return self.value + offset }
        \\    func increment() { self.value += 1 }
        \\}
        \\func main() {
        \\    var counter = Counter(value:40)
        \\    { let read:func(int) int = counter.read; print(read(2)) }
        \\    { let increment:func() = counter.increment; increment(); increment() }
        \\    print(counter.value)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("42\n42\n", output);
}

test "bound methods match equivalent anonymous forwarding functions" {
    const output = try run(
        \\struct Counter { let value:int; func read(offset:int) int { return self.value + offset } }
        \\func apply(callback:func(int) int) int { return callback(2) }
        \\func main() {
        \\    let counter = Counter(value:40)
        \\    let bound:func(int) int = counter.read
        \\    let forwarded:func(int) int = func(offset:int) int { return counter.read(offset) }
        \\    print(apply(bound), " ", apply(forwarded))
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("42 42\n", output);
}

test "bound methods cannot escape directly or through composite values" {
    const message = "capturing function value cannot be returned from its lexical scope";
    try expectCompileError(
        \\struct Counter { let value:int; func read() int { return self.value } }
        \\func invalid() func() int { let counter = Counter(value:42); return counter.read }
        \\func main() {}
    , message);
    try expectCompileError(
        \\struct Counter { let value:int; func read() int { return self.value } }
        \\struct Holder { let callback:func() int }
        \\func invalid() Holder { let counter = Counter(value:42); return Holder(callback:counter.read) }
        \\func main() {}
    , message);
    try expectCompileError(
        \\struct Counter { let value:int; func read() int { return self.value } }
        \\enum Holder { callback(func() int); empty }
        \\func invalid() Holder { let counter = Counter(value:42); return Holder.callback(counter.read) }
        \\func main() {}
    , message);
    try expectCompileError(
        \\struct Counter { func tick() {} }
        \\func invalid() func()? {
        \\    let counter = Counter()
        \\    let callback:func() = counter.tick
        \\    return callback
        \\}
        \\func main() {}
    , message);
}

test "bound mutating methods require a stable mutable receiver place" {
    try expectCompileError(
        \\struct Counter { var value:int; func increment() { self.value++ } }
        \\func main() { let increment:func() = Counter(value:0).increment }
    , "a bound mutating method requires a stable mutable receiver place");
    try expectCompileError(
        \\struct Counter { var value:int; func increment() { self.value++ } }
        \\func main() {
        \\    var counter = Counter(value:0)
        \\    let increment:func() = counter.increment
        \\    counter.value = 2
        \\}
    , "cannot mutate or move 'counter' while bound method 'increment' is alive");
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

test "bound method overloads require a unique expected callback type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\struct Converter {
        \\    func convert(value:int) int { return value }
        \\    func convert(value:str) str { return value }
        \\}
        \\func main() {
        \\    let converter = Converter()
        \\    let convert = converter.convert
        \\}
    ));
    try std.testing.expectEqualStrings(
        "method reference 'convert' is ambiguous",
        frontend.diagnostic.?.message,
    );
}

test "stored callback fields and methods with the same name are ambiguous" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func fallback(value:int) {}
        \\struct Action {
        \\    let run:func(int);
        \\    func run(value:int) {}
        \\}
        \\func main() {
        \\    let action = Action(run:fallback)
        \\    let run:func(int) = action.run
        \\}
    ));
    try std.testing.expectEqualStrings(
        "member reference 'run' is ambiguous between a stored field and a method",
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
        \\    init(task:T) { self.task = task }
        \\    func complete() T { return self.task }
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
