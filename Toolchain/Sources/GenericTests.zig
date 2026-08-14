const std = @import("std");
const Ast = @import("Ast.zig");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Parser = @import("Parser.zig").Parser;
const Project = @import("Project.zig");

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

const worker_job_prelude =
    \\protocol Job { func execute() }
    \\class Executor { public func submit<T:Job>(job:T) {} }
;

const parallel_job_prelude =
    \\protocol ParallelJob { func execute(start:int, end:int) }
    \\class Fence { public func complete() {} }
    \\class Executor { public func submit_parallel<T:ParallelJob>(count:int, job:T) Fence { return Fence() } }
;

test "parallel jobs accept fixed indexed writes and reject structural collection mutation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    _ = try frontend.compile(parallel_job_prelude ++
        \\class Values { public var items:int[] }
        \\struct Fill:ParallelJob {
        \\    var values:Values
        \\    func execute(start:int, end:int) { var index = start; while index < end { self.values.items[index] = index; index++ } }
        \\}
        \\func main() { var executor = Executor(); executor.submit_parallel(8, Fill(values:Values(items:[0, 0, 0, 0, 0, 0, 0, 0]))) }
    );
    try expectCompileError(
        parallel_job_prelude ++
            \\class Values { public var items:int[]; public func grow() { self.items.append(1) } }
            \\struct Grow:ParallelJob { var values:Values; func execute(start:int, end:int) { self.values.grow() } }
            \\func main() { var executor = Executor(); executor.submit_parallel(8, Grow(values:Values(items:[]))) }
        ,
        "job 'Grow' is not worker-safe: cannot mutate collection structure from a ParallelJob",
    );
}

test "worker-safe jobs preserve the submit surface and follow pure call graphs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    _ = try frontend.compile(worker_job_prelude ++
        \\func increment(value:int) int { return value + 1 }
        \\struct Safe:Job {
        \\    var value:int
        \\    func execute() { mutex { self.value = increment(self.value) } }
        \\}
        \\func main() { var executor = Executor(); executor.submit(Safe(value:0)) }
    );
}

test "worker-safe jobs may wait on fences but not consume job handles" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    _ = try frontend.compile(worker_job_prelude ++
        \\class Fence { public func complete() {} }
        \\struct Waits:Job { var fence:Fence; func execute() { self.fence.complete() } }
        \\func main() { var executor = Executor(); executor.submit(Waits(fence:Fence())) }
    );
    try expectCompileError(
        worker_job_prelude ++
            \\class JobHandle { public func complete() {} }
            \\struct Consumes:Job { var handle:JobHandle; func execute() { self.handle.complete() } }
            \\func main() { var executor = Executor(); executor.submit(Consumes(handle:JobHandle())) }
        ,
        "job 'Consumes' is not worker-safe: cannot call an Executor or JobHandle operation",
    );
}

test "worker-safe job analysis rejects main-thread static and executor effects" {
    try expectCompileError(
        worker_job_prelude ++
            \\struct MainThread:Job { func execute() { print("worker") } }
            \\func main() { var executor = Executor(); executor.submit(MainThread()) }
        ,
        "job 'MainThread' is not worker-safe: print requires the main thread",
    );
    try expectCompileError(
        worker_job_prelude ++
            \\struct Globals { public static var count:int = 0 }
            \\struct GlobalWrite:Job { func execute() { Globals.count++ } }
            \\func main() { var executor = Executor(); executor.submit(GlobalWrite()) }
        ,
        "job 'GlobalWrite' is not worker-safe: static mutation 'Globals.count' is unsynchronized",
    );
    try expectCompileError(
        worker_job_prelude ++
            \\struct CapturesExecutor:Job { let executor:Executor; func execute() {} }
            \\func main() { var executor = Executor(); executor.submit(CapturesExecutor(executor:executor)) }
        ,
        "job 'CapturesExecutor' cannot own or capture 'Executor'",
    );
    try expectCompileError(
        worker_job_prelude ++
            \\struct Reentrant:Job { func execute() { var nested = Executor(); nested.submit(Reentrant()) } }
            \\func main() { var executor = Executor(); executor.submit(Reentrant()) }
        ,
        "job 'Reentrant' is not worker-safe: cannot construct an Executor on a worker",
    );
}

test "worker-safe job analysis rejects unknown dynamic callbacks and unsafe destruction" {
    try expectCompileError(
        worker_job_prelude ++
            \\struct Dynamic:Job { let callback:func(); func execute() { callback() } }
            \\func ready() {}
            \\func main() { var executor = Executor(); executor.submit(Dynamic(callback:ready)) }
        ,
        "job 'Dynamic' is not worker-safe: cannot use a callback or call target that cannot be proven worker-safe",
    );
    try expectCompileError(
        worker_job_prelude ++
            \\struct UnsafeDrop:Job { func execute() {} drop { print("drop") } }
            \\func main() { var executor = Executor(); executor.submit(UnsafeDrop()) }
        ,
        "job 'UnsafeDrop' is not worker-safe: print requires the main thread",
    );
}

test "parse generic function declarations and explicit calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func identity<T>(value:T) T { return value }
        \\func main() { identity<int>(42) }
    );
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 1), program.functions[0].type_parameters.len);
    try std.testing.expectEqual(@as(usize, 1), program.functions[1].statements[0].expression_statement.value.call.type_arguments.len);
}

test "parse borrowed tuple patterns as generic type arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\struct Query<Pattern> {}
        \\struct Position { var x:int }
        \\struct Velocity { let x:int }
        \\func visit(query:Query<(@Position, &Velocity)>) {}
    );
    const program = try parser.parse();
    const query_type = program.functions[0].parameters[0].type;
    const query = program.generic_types[query_type.genericInstantiationIndex().?];
    const pattern = program.structures[query.arguments[0].structureIndex().?];
    try std.testing.expectEqual(Ast.Parameter.Mode.read, pattern.fields[0].access_mode);
    try std.testing.expectEqual(Ast.Parameter.Mode.mutable, pattern.fields[1].access_mode);
}

test "borrowed tuple patterns accept class components without storing them" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    _ = try frontend.compile(
        \\class Actor { public func update() {} }
        \\struct Query<Pattern> {}
        \\func visit(query:Query<(@Actor, &Actor)>) {}
        \\func main() {}
    );
}

test "borrowed tuple patterns cannot escape generic arguments as runtime values" {
    try expectCompileError(
        "func visit(value:(@int, &int)) {} func main() {}",
        "borrowed access tuples are non-runtime generic patterns",
    );
    try expectCompileError(
        "struct Stored { let value:(@int, &int) } func main() {}",
        "borrowed access tuples cannot be stored in structure fields",
    );
}

test "specialize inferred and explicit generic functions once" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func identity<T>(value:T) T { return value }
        \\func choose<Key, Value>(key:Key, value:Value) Value { return value }
        \\func main() {
        \\    print(identity(42))
        \\    print(identity<int>(7))
        \\    print(identity("Silex"))
        \\    print(choose(1, "ready"))
        \\}
    );
    try std.testing.expectEqual(@as(usize, 4), compilation.ir.functions.len);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n7\nSilex\nready\n", result.stdout);
}

test "reuse a generic nominal type already named by a collection" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\protocol Value { func read() int }
        \\struct Number:Value { let value:int; func read() int { return self.value } }
        \\struct Box<T:Value> { let value:T }
        \\class Maker {
        \\    public func make<T:Value>(value:T) Box<T> { return Box<T>(value:value) }
        \\}
        \\func main() {
        \\    var pending:Box<Number>[] = []
        \\    var maker = Maker()
        \\    pending.append(maker.make(Number(value:42)))
        \\    print(pending[0].value.read())
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "specialize a generic function with a generic nominal type argument" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Entry<Key, Value> { let key:Key; let value:Value }
        \\struct Cursor<T> { let values:T[]; func count() int { return self.values.count() } }
        \\func count_where<T>(values:Cursor<T>, predicate:func(@T) bool) int {
        \\    var count = 0
        \\    for value in values.values { if predicate(value) { count++ } }
        \\    return count
        \\}
        \\func passing(entry:@Entry<str, int>) bool { return entry.value >= 10 }
        \\func main() {
        \\    let entries:Entry<str, int>[] = [Entry<str, int>(key:"Ada", value:12)]
        \\    print(count_where<Entry<str, int>>(Cursor<Entry<str, int>>(values:entries), passing))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("1\n", result.stdout);
}

test "compose nested generic callback specialization through a module" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Api
        \\use Api.Entry
        \\use Api.Cursor
        \\func passing(entry:@Entry<str, int>) bool { return entry.value >= 10 }
        \\func main() {
        \\    let entries:Entry<str, int>[] = [Entry<str, int>(key:"Ada", value:12)]
        \\    let values = Cursor<Entry<str, int>>(values:entries)
        \\    print(Api.count_where<Entry<str, int>>(values, passing))
        \\    print(Api.count_where(values, passing))
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data =
        \\public struct Entry<Key, Value> { let key:Key; let value:Value }
        \\public struct Cursor<T> { let values:T[] }
        \\public func count_where<T>(values:Cursor<T>, predicate:func(@T) bool) int {
        \\    var count = 0
        \\    for value in values.values { if predicate(value) { count++ } }
        \\    return count
        \\}
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("1\n1\n", result.stdout);
}

test "prefer concrete overloads and specialize defaults and stable recursion" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func select(value:int) int { return 100 }
        \\func select<T>(value:T) T { return value }
        \\func with_default<T>(value:T, amount:int = 2) T { return value }
        \\func descend<T>(value:T, count:int) T {
        \\    if count == 0 { return value }
        \\    return descend(value, count - 1)
        \\}
        \\func main() {
        \\    print(select(1))
        \\    print(select("generic"))
        \\    print(with_default(9))
        \\    print(descend(8, 2))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("100\ngeneric\n9\n8\n", result.stdout);
}

test "prefer a concrete zero-argument overload while keeping explicit specialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func constant() float { return 1.0 }
        \\func constant<T>() T { return 2 as T }
        \\func main() { print(constant()); print(constant<int>()) }
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("1.0\n2\n", result.stdout);
}

test "diagnose generic function arity inference conflicts and divergent recursion" {
    try expectCompileError(
        "func create<T>() T { panic(\"no value\") } func main() { create() }",
        "generic function 'create' cannot infer all type arguments; use explicit '<...>'",
    );
    try expectCompileError(
        "func same<T>(left:T, right:T) T { return left } func main() { same(1, \"x\") }",
        "generic function 'same' cannot infer all type arguments; use explicit '<...>'",
    );
    try expectCompileError(
        "func choose<T, U>(value:T) T { return value } func main() { choose<int>(1) }",
        "generic function 'choose' has no overload accepting 1 type arguments",
    );
    try expectCompileError(
        "func plain(value:int) int { return value } func main() { plain<int>(1) }",
        "function 'plain' does not accept type arguments",
    );
    try expectCompileError(
        "func expand<T>(value:T) T { return expand<T?>(value) } func main() { expand(1) }",
        "generic function 'expand' recursively expands with different type arguments",
    );
}

test "reuse one generic function specialization through modules aliases and reexports" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Left
        \\use Right
        \\func main() { print(Left.answer()); print(Right.answer()) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public func identity<T>(value:T) T { return value }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Facade.sx",
        .data = "public use Api.identity as keep",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Left.sx",
        .data = "use Facade.keep as keep\npublic func answer() int { return keep(20) }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Right.sx",
        .data = "use Api\npublic func answer() int { return Api.identity<int>(22) }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try std.testing.expectEqual(@as(usize, 4), compilation.ir.functions.len);
    var found_reexport = false;
    for (compilation.interfaces) |interface| {
        if (!std.mem.eql(u8, interface.name, "Facade")) continue;
        for (interface.functions) |function| if (std.mem.eql(u8, function.export_name, "keep")) {
            try std.testing.expectEqual(@as(usize, 1), function.type_parameters.len);
            try std.testing.expectEqualStrings("T", function.type_parameters[0]);
            found_reexport = true;
        };
    }
    try std.testing.expect(found_reexport);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("20\n22\n", result.stdout);
}

test "specialize generic structure fields initializers constructors and methods" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Pair<T> {
        \\    let first:T
        \\    let second:T
        \\}
        \\struct Box<T> {
        \\    var value:T
        \\    init(value:T) { self.value = value }
        \\    func replace(value:T) { self.value = value }
        \\}
        \\func main() {
        \\    let named = Pair<int>(first:1, second:2)
        \\    var built = Box<str>("left")
        \\    built.replace("right")
        \\    print(named.first + named.second)
        \\    print(built.value)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("3\nright\n", result.stdout);
}

test "keep nested generic structure identities distinct and reusable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Box<T> { let value:T }
        \\func main() {
        \\    let first = Box<int>(value:1)
        \\    let same = Box<int>(value:1)
        \\    let text = Box<str>(value:"one")
        \\    let nested = Box<Box<int>>(value:first)
        \\    print(first == same)
        \\    print(text.value)
        \\    print(nested.value.value)
        \\}
    );
    try std.testing.expectEqual(@as(usize, 3), compilation.ir.structures.len);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("true\none\n1\n", result.stdout);
}

test "infer function type arguments through a generic structure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Box<T> { let value:T }
        \\func unbox<T>(box:Box<T>) T { return box.value }
        \\func main() {
        \\    print(unbox(Box<int>(value:42)))
        \\    print(unbox(Box<str>(value:"ready")))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\nready\n", result.stdout);
}

test "compose generic structures through aliases and reexports" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Facade
        \\use Api.Pair as LocalPair
        \\use Api.Pair<int> as IntPair
        \\func main() {
        \\    let left:Facade.Pair<int> = Facade.Pair<int>(first:20, second:22)
        \\    let right:IntPair = LocalPair<int>(first:left.first, second:left.second)
        \\    print(right.first + right.second)
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public struct Pair<T> { public let first:T; public let second:T }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Facade.sx",
        .data = "public use Api.Pair as Pair",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try std.testing.expectEqual(@as(usize, 1), compilation.ir.structures.len);
    var found_reexport = false;
    for (compilation.interfaces) |interface| {
        if (!std.mem.eql(u8, interface.name, "Facade")) continue;
        for (interface.structures) |structure| if (std.mem.eql(u8, structure.export_name, "Pair")) {
            try std.testing.expectEqual(@as(usize, 1), structure.type_parameters.len);
            found_reexport = true;
        };
    }
    try std.testing.expect(found_reexport);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "diagnose invalid generic structure uses and recursive expansion" {
    try expectCompileError(
        "struct Box<T> { let value:T } func main() { let value:Box }",
        "generic struct 'Box' requires 1 type argument",
    );
    try expectCompileError(
        "struct Pair<T, U> { let left:T; let right:U } func main() { Pair<int>(left:1, right:2) }",
        "generic struct 'Pair' expects 2 type arguments, found 1",
    );
    try expectCompileError(
        "struct Box { let value:int } func main() { Box<int>(value:1) }",
        "struct 'Box' does not accept type arguments",
    );
    try expectCompileError(
        "struct Box<T> { let value:T } func main() { Box(value:1) }",
        "generic struct 'Box' requires 1 type argument",
    );
    try expectCompileError(
        "struct Box<T> { let value:T } func main() { Box<void>() }",
        "'void' is not a generic type argument",
    );
    try expectCompileError(
        "struct Node<T> { let next:Node<T> } func main() { let value:Node<int> }",
        "structure 'Node<int>' has a recursive value representation",
    );
    try expectCompileError(
        "struct Expand<T> { let value:Expand<Expand<T>> } func main() { let value:Expand<int> }",
        "generic struct 'Expand' recursively expands with different type arguments",
    );
}

test "specialize generic associated enums and match concrete payloads" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Box<T> { let value:T }
        \\enum Outcome<T, E> { success(Box<T>); failure(E) }
        \\func describe<T>(value:Outcome<T, str>) str {
        \\    return match value {
        \\        success(box) => "value $(box.value)"
        \\        failure(message) => message
        \\    }
        \\}
        \\func main() {
        \\    let success = Outcome<int, str>.success(Box<int>(value:42))
        \\    let failure = Outcome<int, str>.failure("failed")
        \\    let other = Outcome<str, int>.failure(7)
        \\    print(describe(success))
        \\    print(describe(failure))
        \\    match other { success(box) => { print(box.value) }; failure(code) => { print(code) } }
        \\}
    );
    try std.testing.expectEqual(@as(usize, 2), compilation.ir.enums.len);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("value 42\nfailed\n7\n", result.stdout);
}

test "construct an empty generic enum variant without parentheses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Choice<T> { empty; value(T) }
        \\func main() {
        \\    let choice = Choice<int>.empty
        \\    print(match choice { empty => "empty"; value(number) => "$(number)" })
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("empty\n", result.stdout);
}

test "compose generic enums through modules aliases and reexports" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Api
        \\use Facade
        \\use Api.Outcome as LocalOutcome
        \\func main() {
        \\    let first:Facade.Outcome<int, str> = Facade.Outcome<int, str>.success(42)
        \\    let second = LocalOutcome<int, str>.failure("failed")
        \\    match first { success(value) => { print(value) }; failure(message) => { print(message) } }
        \\    match second { success(value) => { print(value) }; failure(message) => { print(message) } }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public enum Outcome<T, E> { success(T); failure(E) }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Facade.sx",
        .data = "public use Api.Outcome as Outcome",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try std.testing.expectEqual(@as(usize, 1), compilation.ir.enums.len);
    var found_reexport = false;
    for (compilation.interfaces) |interface| {
        if (!std.mem.eql(u8, interface.name, "Facade")) continue;
        for (interface.enums) |enumeration| if (std.mem.eql(u8, enumeration.export_name, "Outcome")) {
            try std.testing.expectEqual(@as(usize, 2), enumeration.type_parameters.len);
            found_reexport = true;
        };
    }
    try std.testing.expect(found_reexport);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\nfailed\n", result.stdout);
}

test "diagnose invalid generic enum uses" {
    try expectCompileError(
        "enum Outcome<T, E> { success(T); failure(E) } func main() { let value:Outcome }",
        "generic enum 'Outcome' requires 2 type arguments",
    );
    try expectCompileError(
        "enum Outcome<T> { success(T) } func main() { Outcome.success(1) }",
        "generic enum 'Outcome' requires 1 type argument",
    );
    try expectCompileError(
        "enum Outcome<T, E> { success(T); failure(E) } func main() { Outcome<int>.success(1) }",
        "generic enum 'Outcome' expects 2 type arguments, found 1",
    );
    try expectCompileError(
        "enum State { ready } func main() { State<int>.ready() }",
        "enum 'State' does not accept type arguments",
    );
    try expectCompileError(
        "enum Outcome<T> { success(T) } func main() { Outcome<void>.success() }",
        "'void' is not a generic type argument",
    );
    try expectCompileError(
        "enum Code<T>: int { ready = 1 } func main() {}",
        "raw enums cannot be generic",
    );
}

test "specialize inferred explicit overloaded mutating and recursive generic methods" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Catalog {
        \\    var count:int
        \\    func identity<T>(value:T) T { return value }
        \\    func select(value:int) int { return 100 }
        \\    func select<T>(value:T) T { return value }
        \\    func store<T>(value:T, amount:int = 1) T {
        \\        self.count += amount
        \\        return value
        \\    }
        \\    func descend<T>(value:T, count:int) T {
        \\        if count == 0 { return value }
        \\        return self.descend(value, count - 1)
        \\    }
        \\}
        \\func main() {
        \\    var catalog = Catalog()
        \\    print(catalog.identity(42))
        \\    print(catalog.identity<str>("Silex"))
        \\    print(catalog.select(1))
        \\    print(catalog.select("generic"))
        \\    print(catalog.store(7))
        \\    print(catalog.count)
        \\    print(catalog.descend(8, 2))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\nSilex\n100\ngeneric\n7\n1\n8\n", result.stdout);
}

test "specialize overloaded generic methods with named arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Scheduler {
        \\    func submit<T>(value:T) int { return 1 }
        \\    func submit<T>(value:T, after:int) int { return 2 }
        \\    func submit<T>(value:T, after:@int[]) int { return 3 }
        \\}
        \\func main() {
        \\    var scheduler = Scheduler()
        \\    print(scheduler.submit("one", after:7))
        \\    print(scheduler.submit("many", after:[1, 2]))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("2\n3\n", result.stdout);
}

test "specialize nested types with owner arguments before child arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Box<T> {
        \\    struct Entry<U> { let owner:T; let value:U }
        \\}
        \\struct Catalog { struct Item<T> { let value:T } }
        \\func main() {
        \\    let entry:Box<int>.Entry<str> = Box<int>.Entry<str>(owner:42, value:"nested")
        \\    let item = Catalog.Item<int>(value:7)
        \\    print(entry.owner, " ", entry.value, " ", item.value)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42 nested 7\n", result.stdout);
}

test "compose public generic methods through modules" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Api
        \\func main() {
        \\    let catalog = Api.Catalog()
        \\    print(catalog.identity(20))
        \\    print(catalog.identity<int>(22))
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public struct Catalog { public func identity<T>(value:T) T { return value } }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    var found_method = false;
    for (compilation.interfaces) |interface| {
        if (!std.mem.eql(u8, interface.name, "Api")) continue;
        for (interface.structures) |structure| if (std.mem.eql(u8, structure.export_name, "Catalog")) {
            try std.testing.expectEqual(@as(usize, 1), structure.methods.len);
            try std.testing.expectEqual(@as(usize, 1), structure.methods[0].type_parameters.len);
            try std.testing.expectEqualStrings("T", structure.methods[0].type_parameters[0]);
            found_method = true;
        };
    }
    try std.testing.expect(found_method);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("20\n22\n", result.stdout);
}

test "specialize an explicit generic method with a named function callback" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Mapper { func apply<T>(value:T, callback:func(T) T) T { return callback(value) } }
        \\func increment(value:int) int { return value + 1 }
        \\func main() { print(Mapper().apply<int>(41, increment)) }
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "diagnose invalid generic method declarations and calls" {
    try expectCompileError(
        "struct Factory { func create<T>() int { return 1 } } func main() { Factory().create() }",
        "generic method 'create' cannot infer all type arguments; use explicit '<...>'",
    );
    try expectCompileError(
        "struct Catalog { func choose<T, U>(value:T) T { return value } } func main() { Catalog().choose<int>(1) }",
        "generic method 'choose' has no overload accepting 1 type arguments",
    );
    try expectCompileError(
        "struct Catalog { func plain(value:int) int { return value } } func main() { Catalog().plain<int>(1) }",
        "method 'plain' does not accept type arguments",
    );
    try expectCompileError(
        "struct Catalog { func expand<T>(value:T) T { return self.expand<T?>(value) } } func main() { Catalog().expand(1) }",
        "generic method 'expand' recursively expands with different type arguments",
    );
    try expectCompileError(
        "struct Factory { func create<T>() int { return 1 } } func main() { Factory().create<void>() }",
        "'void' is not a generic type argument",
    );
    try expectCompileError(
        "struct Catalog { func pick<T>(left:T, right:int) T { return left } func pick<T>(left:int, right:T) T { return right } } func main() { Catalog().pick(1, 2) }",
        "generic call to method 'pick' is ambiguous",
    );
    try expectCompileError(
        "struct Box<T> { func identity<U>(value:U) U { return value } } func main() {}",
        "generic methods in generic structures are not supported",
    );
    try expectCompileError(
        "struct Box { init<T>() {} } func main() {}",
        "constructors cannot declare type parameters",
    );
}

test "generic classes specialize storage methods identity and lifetime" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\class Box<T> {
        \\    public let value:T
        \\    public init(value:T) { self.value = value }
        \\    public func get() T { return self.value }
        \\    drop { print("drop") }
        \\}
        \\func main() {
        \\    var integer = Box<int>(42)
        \\    var alias = integer
        \\    var text = Box<str>("Silex")
        \\    print(integer.get(), " ", text.get(), " ", integer == alias)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42 Silex true\ndrop\ndrop\n", result.stdout);
}

test "generic classes specialize generic bases overrides and static storage" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\class Base<T> {
        \\    public let value:T
        \\    public static var count:int = 0
        \\    public static func set_count(value:int) { Base<T>.count = value }
        \\    public init(value:T) { self.value = value }
        \\    public func get() T { return self.value }
        \\}
        \\class Child<T> : Base<T> {
        \\    public init(value:T) : super(value) {}
        \\    override public func get() T { return self.value }
        \\}
        \\func read(value:Base<int>) int { return value.get() }
        \\func main() {
        \\    Base<int>.set_count(3)
        \\    Base<str>.set_count(8)
        \\    var value:Base<int> = Child<int>(42)
        \\    print(read(value), " ", Base<int>.count, " ", Base<str>.count)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42 3 8\n", result.stdout);
}

test "compose generic classes through aliases and reexports" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Facade
        \\use Api.Box as LocalBox
        \\use Api.Box<int> as IntBox
        \\func main() {
        \\    var left:Facade.Box<int> = Facade.Box<int>(20)
        \\    var right:IntBox = LocalBox<int>(left.value + 22)
        \\    print(right.value)
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data =
        \\public class Box<T> {
        \\    public let value:T
        \\    public init(value:T) { self.value = value }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Facade.sx",
        .data = "public use Api.Box as Box",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try std.testing.expectEqual(@as(usize, 1), compilation.ir.structures.len);
    try std.testing.expect(compilation.ir.structures[0].is_class);
    var found_reexport = false;
    for (compilation.interfaces) |interface| {
        if (!std.mem.eql(u8, interface.name, "Facade")) continue;
        for (interface.structures) |structure| if (std.mem.eql(u8, structure.export_name, "Box")) {
            try std.testing.expectEqual(@as(usize, 1), structure.type_parameters.len);
            found_reexport = true;
        };
    }
    try std.testing.expect(found_reexport);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "compose static calls on generic structures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\struct Value<T> {
        \\    static func answer() int { return 42 }
        \\}
        \\func main() { print(Value<int>.answer()) }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "prefer an exact generic collection overload over a borrowed view" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func kind<T>(values:@T[]) int { return 1 }
        \\func kind<T>(values:@T[..]) int { return 2 }
        \\func main() { var values = [42]; print(kind(values)) }
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("1\n", result.stdout);
}

test "diagnose incomplete and invalid generic class arguments" {
    try expectCompileError(
        "class Box<T> {} func main() { var value = Box() }",
        "generic class 'Box' requires 1 type argument",
    );
    try expectCompileError(
        "class Box<T> {} func main() { var value = Box<int, str>() }",
        "generic class 'Box' expects 1 type argument, found 2",
    );
    try expectCompileError(
        "class Plain {} func main() { var value = Plain<int>() }",
        "class 'Plain' does not accept type arguments",
    );
    try expectCompileError(
        "class Box<T> { func identity<U>(value:U) U { return value } } func main() {}",
        "generic methods in generic structures are not supported",
    );
}
