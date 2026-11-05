const std = @import("std");
const Frontend = @import("Frontend.zig").Frontend;
const Interpreter = @import("Interpreter.zig");

test {
    _ = @import("Lsp/Completion.zig");
    _ = @import("Lsp/Tests/WorkspaceContracts.zig");
    _ = @import("TryTests.zig");
    _ = @import("ResultTests.zig");
    _ = @import("MapErrorTests.zig");
    _ = @import("MainResultTests.zig");
    _ = @import("MatchTests.zig");
    _ = @import("ScopeTests.zig");
    _ = @import("RecursiveResourceTests.zig");
    _ = @import("ForIterationTests.zig");
}

test "result call policy extracts directly and captures only the targeted call" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func argument() Result<int,str> { print("argument"); return Result<int,str>.success(40) }
        \\func read(value:int) Result<int,str> { print("read"); return Result<int,str>.success(value + 2) }
        \\func main() {
        \\    let captured = try read(argument())
        \\    match captured { success(value) => { assert(value == 42) }; failure(_) => { panic("unexpected") } }
        \\    assert(read(40) == 42)
        \\    let explicit = Result<int,str>.failure("stored")
        \\    match explicit { failure(error) => { assert(error == "stored") }; success(_) => { panic("unexpected") } }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("argument\nread\nread\n", result.stdout);
}

test "result call policy infers self mutation inside try alternatives" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func mark(value:&bool) Result<void,str> { value = true; return Result<void,str>.success() }
        \\func fail() Result<int,str> { return Result<int,str>.failure("expected") }
        \\struct Work {
        \\    var touched:bool = false
        \\    var failed:bool = false
        \\    func run() { try mark(self.touched) else error { self.failed = true; return } }
        \\    func recover() int { let value = try fail() else error { self.failed = true; return 42 }; return value }
        \\}
        \\func main() {
        \\    var work = Work()
        \\    work.run()
        \\    assert(work.touched && !work.failed)
        \\    assert(work.recover() == 42)
        \\    assert(work.failed)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "result call policy rejects getters mutating self in try alternatives" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func fail() Result<int,str> { return Result<int,str>.failure("expected") }
        \\struct Work {
        \\    var failed:bool = false
        \\    let value:int { get { let value = try fail() else error { self.failed = true; return 0 }; return value } }
        \\}
        \\func main() {}
    ));
    try std.testing.expectEqualStrings("a getter cannot mutate self; use an explicit method for observable mutation", frontend.diagnostic.?.message);
}

test "result call policy retains errors and terminates ordinary failures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func read() Result<int,str> { return Result<int,str>.failure("original") }
        \\func main() {
        \\    match try read() { failure(error) => { print(error) }; success(_) => { panic("unexpected") } }
        \\    print(read())
        \\    print("unreachable")
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("original\n", result.stdout);
    try std.testing.expectEqual(@as(u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "runtime error: original") != null);
}

test "result call policy handles void and explicit propagation without extracting captures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func save(allowed:bool) Result<void,str> {
        \\    if allowed { return Result<void,str>.success() }
        \\    return Result<void,str>.failure("unsaved")
        \\}
        \\func forward() Result<void,str> { return try save(false) }
        \\func explicit() Result<void,str> {
        \\    try save(false) else error { return Result<void,str>.failure(error) }
        \\    return Result<void,str>.success()
        \\}
        \\func main() {
        \\    save(true)
        \\    match try forward() { failure(error) => { assert(error == "unsaved") }; success => { panic("unexpected") } }
        \\    match try explicit() { failure(error) => { assert(error == "unsaved") }; success => { panic("unexpected") } }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "result call policy specializes generic arguments using the effective call value" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func read() Result<int,str> { return Result<int,str>.success(42) }
        \\func identity<T>(value:T) T { return value }
        \\func main() {
        \\    assert(identity(read()) == 42)
        \\    let raw = try identity(try read())
        \\    match raw { success(value) => { assert(value == 42) }; failure(_) => { panic("unexpected") } }
        \\    let callback:func() Result<int,str> = read
        \\    assert(callback() == 42)
        \\    match try callback() { success(value) => { assert(value == 42) }; failure(_) => { panic("unexpected") } }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "result call policy preserves payload lifetimes and formats structured errors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\class Token {
        \\    static var drops:int = 0
        \\    let id:int
        \\    init(id:int) { self.id = id }
        \\    drop { Token.drops++ }
        \\}
        \\enum Kind { invalid(str); denied }
        \\struct Failure { let kind:Kind; let line:int; let subject:str? }
        \\func create(allowed:bool) Result<Token,Token> {
        \\    if allowed { return Result<Token,Token>.success(Token(42)) }
        \\    return Result<Token,Token>.failure(Token(13))
        \\}
        \\func invalid() Result<int,Failure> {
        \\    return Result<int,Failure>.failure(Failure(kind:Kind.invalid("note"),line:7,subject:"bad"))
        \\}
        \\func main() {
        \\    { var value = create(true); assert(value.id == 42 && Token.drops == 0) }
        \\    assert(Token.drops == 1)
        \\    {
        \\        var captured = try create(false)
        \\        match captured { failure(error) => { assert(error.id == 13) }; success(_) => { panic("unexpected") } }
        \\    }
        \\    assert(Token.drops == 2)
        \\    print(invalid())
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "kind: invalid(note), line: 7, subject: bad") != null);
}

test "result call policy handles methods protocol dispatch and safe receivers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\protocol Reader { func read() Result<int,str> }
        \\struct Source:Reader {
        \\    func read() Result<int,str> { return Result<int,str>.success(42) }
        \\}
        \\func main() {
        \\    var reader:Reader = Source()
        \\    assert(reader.read() == 42)
        \\    match try reader.read() { success(value) => { assert(value == 42) }; failure(_) => { panic("unexpected") } }
        \\    var source:Source? = Source()
        \\    assert(source?.read() == 42)
        \\    if let captured = try source?.read() {
        \\        match captured { success(value) => { assert(value == 42) }; failure(_) => { panic("unexpected") } }
        \\    }
        \\    source = null
        \\    assert(source?.read() == null)
        \\    assert((try source?.read()) == null)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "result call policy qualifies defaults static inherited generics optional and nested data" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.init(allocator);
    const source = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "../Tests/Functions/ResultCalls.sx", allocator, .limited(1024 * 1024));
    const compilation = frontend.compile(source) catch |err| {
        if (frontend.diagnostic) |diagnostic| std.debug.print("Result fixture line {d}: {s}\n", .{ diagnostic.position.line, diagnostic.message });
        return err;
    };
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "result call policy rejects implicit Result contexts and unused captures" {
    const cases = [_]struct { source: []const u8, message: []const u8 }{
        .{ .source = "func read() Result<int,str> { return Result<int,str>.success(42) } func main() { let raw:Result<int,str> = read() }", .message = "variable 'raw' expects 'Result<int,str>', found 'int'" },
        .{ .source = "func read() int { return 42 } func main() { let raw = try read() }", .message = "'try' expects 'Result<T,E>', found 'int'" },
        .{ .source = "func read() Result<int,str> { return Result<int,str>.success(42) } func main() { try read() }", .message = "the Result captured by 'try' must be used" },
        .{ .source = "func save() Result<void,str> { return Result<void,str>.success() } func main() { try save() }", .message = "the Result captured by 'try' must be used" },
        .{ .source = "func read() Result<int,str>? { return null } func main() { let raw = try read() }", .message = "'try' expects 'Result<T,E>', found 'Result<int,str>?'" },
        .{ .source = "class Token { let id:int } func view(value:@Result<Token,str>) @Result<Token,str> { return value } func consume(value:Token) {} func main() { var stored = Result<Token,str>.success(Token(id:42)); consume(view(stored)) }", .message = "read-reference parameter 'stored' cannot be passed by value" },
    };
    for (cases) |case| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var frontend = Frontend.init(arena.allocator());
        try std.testing.expectError(error.InvalidSource, frontend.compile(case.source));
        try std.testing.expectEqualStrings(case.message, frontend.diagnostic.?.message);
    }
}
