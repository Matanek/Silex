const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "propagate Result successes failures and void with one operand evaluation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func read(allowed:bool) Result<int, str> {
        \\    print("read")
        \\    if allowed { return Result<int, str>.success(40) }
        \\    return Result<int, str>.failure("denied")
        \\}
        \\func propagated(allowed:bool) Result<int, str> {
        \\    print("before")
        \\    let value = try read(allowed) + 2
        \\    print("after")
        \\    return Result<int, str>.success(value)
        \\}
        \\func save(allowed:bool) Result<void, str> {
        \\    print("save")
        \\    if allowed { return Result<void, str>.success() }
        \\    return Result<void, str>.failure("not saved")
        \\}
        \\func save_all(allowed:bool) Result<void, str> {
        \\    try save(allowed)
        \\    print("after save")
        \\    return Result<void, str>.success()
        \\}
        \\func main() {
        \\    match propagated(true) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match propagated(false) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match save_all(true) { success => { print("saved") }; failure(error) => { print(error) } }
        \\    match save_all(false) { success => { print("saved") }; failure(error) => { print(error) } }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        "before\nread\nafter\n42\nbefore\nread\ndenied\nsave\nafter save\nsaved\nsave\nnot saved\n",
        result.stdout,
    );
}

test "lower try as deterministic ordinary enum control flow" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func read() Result<int, str> { return Result<int, str>.success(42) }
        \\func propagate() Result<bool, str> {
        \\    let value = try read()
        \\    return Result<bool, str>.success(value == 42)
        \\}
        \\func main() { match propagate() { success(value) => { print(value) }; failure(error) => { print(error) } } }
    );
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "enum.test") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "enum.payload") != null);
    try std.testing.expect(std.mem.count(u8, text, "return") >= 3);
}

test "lower try else as deterministic ordinary enum control flow" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func read() Result<int,int> { return Result<int,int>.failure(7) }
        \\func load() Result<int,str> {
        \\    let value = try read() else error { return Result<int,str>.failure("error $(error)") }
        \\    return Result<int,str>.success(value)
        \\}
        \\func main() {}
    ;
    var first_frontend = Frontend.Frontend.init(allocator);
    var second_frontend = Frontend.Frontend.init(allocator);
    const first = try Ir.writeText(allocator, (try first_frontend.compile(source)).ir);
    const second = try Ir.writeText(allocator, (try second_frontend.compile(source)).ir);
    try std.testing.expectEqualStrings(first, second);
    try std.testing.expect(std.mem.indexOf(u8, first, "enum.test") != null);
    try std.testing.expect(std.mem.indexOf(u8, first, "enum.payload") != null);
}

test "handle Result failures locally and replace errors with contextual messages" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum ReadError { denied(int) }
        \\func read(allowed:bool) Result<int,ReadError> {
        \\    print("read")
        \\    if allowed { return Result<int,ReadError>.success(40) }
        \\    return Result<int,ReadError>.failure(ReadError.denied(7))
        \\}
        \\func message() str { print("message"); return "context" }
        \\func inspected(allowed:bool) Result<int,str> {
        \\    let value = try read(allowed) else error {
        \\        match error { denied(code) => { print(code) } }
        \\        return Result<int,str>.failure("inspected")
        \\    }
        \\    return Result<int,str>.success(value + 2)
        \\}
        \\func ignored(allowed:bool) Result<int,str> {
        \\    let value = try read(allowed) else {
        \\        print("ignored")
        \\        return Result<int,str>.failure("ignored")
        \\    }
        \\    return Result<int,str>.success(value)
        \\}
        \\func contextual(allowed:bool) Result<int,str> {
        \\    let value = try read(allowed) else error message()
        \\    return Result<int,str>.success(value)
        \\}
        \\func main() {
        \\    match inspected(true) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match inspected(false) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match ignored(false) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match contextual(true) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match contextual(false) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        "read\n42\nread\n7\ninspected\nread\nignored\nignored\nread\n40\nread\nmessage\ncontext\n",
        result.stdout,
    );
}

test "handle void Result locally and allow loop exits" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func save(allowed:bool) Result<void,int> {
        \\    print("save")
        \\    if allowed { return Result<void,int>.success() }
        \\    return Result<void,int>.failure(7)
        \\}
        \\func save_all(allowed:bool) Result<void,str> {
        \\    try save(allowed) else error "save failed"
        \\    print("saved")
        \\    return Result<void,str>.success()
        \\}
        \\func stop_on_failure() {
        \\    while true {
        \\        try save(false) else { break }
        \\    }
        \\    print("stopped")
        \\}
        \\func continue_on_failure() {
        \\    var count = 0
        \\    while count < 2 {
        \\        count += 1
        \\        try save(count == 2) else { continue }
        \\        print("continued")
        \\    }
        \\}
        \\func main() {
        \\    match save_all(true) { success => { print("ok") }; failure(error) => { print(error) } }
        \\    match save_all(false) { success => { print("ok") }; failure(error) => { print(error) } }
        \\    stop_on_failure()
        \\    continue_on_failure()
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        "save\nsaved\nok\nsave\nsave failed\nsave\nstopped\nsave\nsave\ncontinued\n",
        result.stdout,
    );
}

test "clean try else error payloads on local and short exits" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Failure { let id:int; drop { print("drop ", self.id) } }
        \\func read(id:int) Result<int,Failure> {
        \\    if id == 0 { return Result<int,Failure>.success(40) }
        \\    return Result<int,Failure>.failure(Failure(id:id))
        \\}
        \\func ignored() Result<int,str> {
        \\    let value = try read(1) else { return Result<int,str>.failure("ignored") }
        \\    return Result<int,str>.success(value)
        \\}
        \\func inspected() Result<int,str> {
        \\    let value = try read(2) else error {
        \\        print("seen ", error.id)
        \\        return Result<int,str>.failure("inspected")
        \\    }
        \\    return Result<int,str>.success(value)
        \\}
        \\func message() str { print("message"); return "context" }
        \\func contextual() Result<int,str> {
        \\    let value = try read(3) else error message()
        \\    return Result<int,str>.success(value)
        \\}
        \\func main() { ignored(); inspected(); contextual() }
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        "drop 1\nseen 2\ndrop 2\nmessage\ndrop 3\n",
        result.stdout,
    );
}

test "diagnose invalid try else branches bindings messages and contexts" {
    try expectCompileError(
        "func read() Result<int,int> { return Result<int,int>.failure(1) } func value() int { return try read() else {} } func main() {}",
        "'try else' branch must exit the current flow on every path",
    );
    try expectCompileError(
        "func read() Result<int,int> { return Result<int,int>.failure(1) } func value() int { let error = 2; return try read() else error { return error } } func main() {}",
        "variable 'error' is already declared in this scope",
    );
    try expectCompileError(
        "func read() Result<int,int> { return Result<int,int>.failure(1) } func value() Result<int,str> { return try read() else error 42 } func main() {}",
        "'try else error' message expects 'str', found 'int'",
    );
    try expectCompileError(
        "func read() Result<int,int> { return Result<int,int>.failure(1) } func value() int { return try read() else error \"bad\" } func main() {}",
        "'try else error' requires an enclosing function returning 'Result<U,str>'",
    );
    try expectCompileError(
        "func read() Result<int,int> { return Result<int,int>.failure(1) } func value() Result<int,str> { return try read() else error { return 1 } } func main() {}",
        "return expects 'Result<int,str>', found 'int'",
    );
    try expectCompileError(
        "func read() Result<int,int> { return Result<int,int>.failure(1) } struct Box { let value:int; init() { self.value = try read() else { return } } } func main() {}",
        "'try else' is not allowed in this context",
    );
    try expectCompileError(
        "func read() Result<int,int> { return Result<int,int>.failure(1) } func value() int { let item = try read() else error { return 0 }; return error } func main() {}",
        "unknown variable 'error'",
    );
}

test "diagnose invalid try operands contexts and error types" {
    try expectCompileError(
        "func compute() Result<int, str> { return try 1 } func main() {}",
        "'try' expects 'Result<T,E>', found 'int'",
    );
    try expectCompileError(
        "func read() Result<int, str> { return Result<int, str>.success(1) } func compute() int { return try read() } func main() {}",
        "'try' requires an enclosing function returning 'Result<U,E>'",
    );
    try expectCompileError(
        "struct ReadError {} struct SaveError {} func read() Result<int, ReadError> { return Result<int, ReadError>.success(1) } func save() Result<int, SaveError> { return Result<int, SaveError>.success(try read()) } func main() {}",
        "'try' error type 'ReadError' does not match enclosing error type 'SaveError'",
    );
    try expectCompileError(
        "func read() Result<void, str> { return Result<void, str>.success() } func value() Result<int, str> { let item = try read(); return Result<int, str>.success(item) } func main() {}",
        "'try' of 'Result<void,E>' does not produce a value",
    );
    try expectCompileError(
        "func read() Result<int, str> { return Result<int, str>.success(1) } func value() Result<void, str> { try read(); return Result<void, str>.success() } func main() {}",
        "the success value produced by 'try' must be used",
    );
    try expectCompileError(
        "func read() Result<int, str> { return Result<int, str>.success(1) } struct Box { let value:int; init() { self.value = try read() } } func main() {}",
        "'try' requires an enclosing function returning 'Result<U,E>'",
    );
}
