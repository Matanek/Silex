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

test "evaluate exhaustive associated enum matches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Connection { waiting; connected(str); measured(int, bool) }
        \\func observe(value:Connection) Connection { print("subject"); return value }
        \\func describe(value:Connection) str {
        \\    return match observe(value) {
        \\        waiting => "waiting"
        \\        connected(name) => name
        \\        measured(let count, var enabled) => "measured"
        \\    }
        \\}
        \\func emit(text:str) { print(text) }
        \\func main() {
        \\    let first = describe(Connection.waiting())
        \\    emit(first)
        \\    emit(describe(Connection.connected("server")))
        \\    emit(describe(Connection.measured(7, true)))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("subject\nwaiting\nsubject\nserver\nsubject\nmeasured\n", result.stdout);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "enum.test") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "enum.payload") != null);
}

test "ignore selected match payloads without declaring bindings" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Tracer { let label:str; drop { print("drop ", self.label) } }
        \\enum Token { identifier(str, int); traced(Tracer, int); end(int) }
        \\func classify(token:Token) str {
        \\    return match token {
        \\        identifier(_, _) => "name"
        \\        traced(value, _) => value.label
        \\        end(_) => "end"
        \\    }
        \\}
        \\func ignore_resource(token:Token) {
        \\    match token { traced(_, _) => { print("ignored") }; else => {} }
        \\}
        \\func name_resource(token:Token) {
        \\    match token { traced(value, _) => { print("named") }; else => {} }
        \\}
        \\func main() {
        \\    print(classify(Token.identifier("silex", 1)))
        \\    print(classify(Token.traced(Tracer(label:"kept"), 2)))
        \\    print(classify(Token.end(3)))
        \\    ignore_resource(Token.traced(Tracer(label:"ignored"), 4))
        \\    name_resource(Token.traced(Tracer(label:"named"), 5))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        "name\ndrop kept\ndrop kept\nkept\nend\nignored\ndrop ignored\ndrop ignored\nnamed\ndrop named\ndrop named\n",
        result.stdout,
    );
}

test "diagnose invalid ignored match payload forms" {
    try expectCompileError(
        "enum Choice { value(int); empty } func main() { let result = match Choice.value(1) { value(let _) => 1; empty => 0 } }",
        "ignored match payload cannot use 'let'",
    );
    try expectCompileError(
        "enum Choice { value(int); empty } func main() { let result = match Choice.value(1) { value(var _) => 1; empty => 0 } }",
        "ignored match payload cannot use 'var'",
    );
    try expectCompileError(
        "enum Choice { value(int); empty } func main() { let result = match Choice.value(1) { value(_) => _; empty => 0 } }",
        "unknown variable '_'",
    );
    try expectCompileError("func main() { let _ = 1 }", "'_' is reserved for ignored match payloads");
    try expectCompileError("func main() { var _:int }", "'_' is reserved for ignored match payloads");
}

test "evaluate ordered guarded match branches after binding payloads" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Token { integer(int, int); identifier(str, int); end }
        \\func source() Token { print("subject"); return Token.integer(0, 7) }
        \\func permits(label:str, accepted:bool) bool { print(label); return accepted }
        \\func classify(token:Token) str {
        \\    return match token {
        \\        integer(value, _) if permits("negative", value < 0) => "negative"
        \\        integer(value, _) if permits("zero", value == 0) => "zero"
        \\        integer(_, _) => "positive"
        \\        identifier(name, _) if name == "self" => "reserved"
        \\        identifier(_, _) => "name"
        \\        else => "other"
        \\    }
        \\}
        \\func announce(token:Token) {
        \\    match token {
        \\        integer(value, _) if value > 0 => { print("positive block") }
        \\        integer(_, _) => { print("other block") }
        \\        else => { print("non integer") }
        \\    }
        \\}
        \\func main() {
        \\    print(classify(source()))
        \\    print(classify(Token.integer(3, 8)))
        \\    print(classify(Token.identifier("self", 9)))
        \\    announce(Token.integer(1, 10))
        \\    announce(Token.integer(0, 11))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        "subject\nnegative\nzero\nzero\nnegative\nzero\npositive\nreserved\npositive block\nother block\n",
        result.stdout,
    );
}

test "diagnose invalid guarded match coverage and types" {
    try expectCompileError(
        "enum Choice { value(int); empty } func main() { let result = match Choice.value(1) { value(number) if number => 1; value(_) => 2; empty => 0 } }",
        "match guard requires bool, found 'int'",
    );
    try expectCompileError(
        "enum Choice { value(int); empty } func main() { let result = match Choice.value(1) { value(number) if number > 0 => 1; empty => 0 } }",
        "match is missing unguarded branch for variant 'value'",
    );
    try expectCompileError(
        "enum Choice { value(int); empty } func main() { let result = match Choice.value(1) { value(_) => 1; value(number) if number > 0 => 2; empty => 0 } }",
        "guarded branch for variant 'value' is unreachable after its unguarded branch",
    );
    try expectCompileError(
        "enum Choice { value; empty } func main() { let result = match Choice.value { value => 1; else if true => 2 } }",
        "else match branch cannot have a guard",
    );
}

test "compile terminal match nested in a mutating method branch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Outcome { success(int); failure(str) }
        \\func outcome() Outcome { return Outcome.success(7) }
        \\class Parser {
        \\    var offset:int
        \\    init(offset:int) { self.offset = offset }
        \\    func run() Result<int, str> {
        \\        if self.offset == 0 {
        \\            match outcome() {
        \\                success(value) => { return Result<int, str>.success(value) }
        \\                failure(error) => { return Result<int, str>.failure(error) }
        \\            }
        \\        }
        \\        return Result<int, str>.success(0)
        \\    }
        \\}
        \\func main() {
        \\    var parser = Parser(0)
        \\    match parser.run() { success(value) => { assert(value == 7, "nested match") }; failure(error) => { panic(error) } }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "diagnose invalid exhaustive match patterns" {
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1 } }",
        "match is missing variant 'right'",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1; left => 2 } }",
        "variant 'left' is matched more than once",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1; unknown => 2 } }",
        "enum 'Choice' has no variant named 'unknown'",
    );
    try expectCompileError(
        "enum Choice { left(int); right } func main() { let value = match Choice.left(1) { left => 1; right => 2 } }",
        "variant 'left' exposes 1 associated values, pattern binds 0",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1 as int8; right => 2 } }",
        "match branch expects exact type 'int8', found 'int'",
    );
    try expectCompileError(
        "enum Choice { left; right } func optional() int? { return 1 } func main() { let value = match Choice.left() { left => optional(); right => 2 } }",
        "match branch expects exact type 'int?', found 'int'",
    );
    try expectCompileError(
        "func main() { let value = match 1 { left => 1 } }",
        "literal match requires literal branches",
    );
}

test "evaluate nested expression and imperative matches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Outer { value(int); empty }
        \\enum Inner { left; right }
        \\func main() {
        \\    let value = match Outer.value(7) {
        \\        value(number) => match Inner.right {
        \\            left => 0
        \\            right => number
        \\        }
        \\        empty => -1
        \\    }
        \\    print(value)
        \\    match Outer.value(3) {
        \\        value(number) => {
        \\            match Inner.left {
        \\                left => { print(number) }
        \\                right => { print(0) }
        \\            }
        \\        }
        \\        empty => { print(-1) }
        \\    }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("7\n3\n", result.stdout);
}

test "keep match bindings scoped to their branch" {
    try expectCompileError(
        "enum Choice { value(int); empty } func main() { let result = match Choice.value(1) { value(number) => number; empty => 0 }; print(number) }",
        "unknown variable 'number'",
    );
}

test "evaluate ordered integer string and boolean literal matches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func observed_code() int { print("code"); return 404 }
        \\func status(code:int) str {
        \\    return match code { 200 => "ok"; 404 => "missing"; else => "other" }
        \\}
        \\func narrow(value:int8) str {
        \\    return match value { -1 => "negative"; 127 => "maximum"; else => "middle" }
        \\}
        \\func command(value:str) int {
        \\    return match value { "start" => 1; "stop" => 2; else => 0 }
        \\}
        \\func truth(value:bool) int { return match value { true => 1; false => 0 } }
        \\func permits() bool { print("guard"); return false }
        \\func guarded(value:int) str {
        \\    return match value { 7 if permits() => "guarded"; 7 => "fallback"; else => "other" }
        \\}
        \\func main() {
        \\    print(status(observed_code()))
        \\    print(narrow(-1 as int8))
        \\    print(narrow(127 as int8))
        \\    print(command("stop"))
        \\    print(truth(false))
        \\    print(guarded(7))
        \\    match "run" { "run" => { print("imperative") }; else => { print("other") } }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        "code\nmissing\nnegative\nmaximum\n2\n0\nguard\nfallback\nimperative\n",
        result.stdout,
    );
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, " = eq ") != null);
}

test "diagnose incomplete incompatible and unreachable literal matches" {
    try expectCompileError(
        "func main() { let value = match 1 { 1 => true } }",
        "match on 'int' requires an else branch",
    );
    try expectCompileError(
        "func main() { let value = match true { true => 1 } }",
        "match is missing literal 'false'",
    );
    try expectCompileError(
        "func main() { let value = match true { true => 1; false => 0; else => -1 } }",
        "else match branch is unreachable because every boolean value is already covered",
    );
    try expectCompileError(
        "func main() { let value = match 1 { 1 => true; 0x1 => false; else => false } }",
        "literal is matched more than once",
    );
    try expectCompileError(
        "func main() { let value = match 1 { 1 => true; 1 if true => false; else => false } }",
        "guarded branch for literal is unreachable after its unguarded branch",
    );
    try expectCompileError(
        "func main() { let value = match 1 { \"1\" => true; else => false } }",
        "match branch expects a literal of type 'int', found 'str'",
    );
    try expectCompileError(
        "func main() { let value = match 1.0 { 1 => true; else => false } }",
        "literal match requires a bool, integer, or str subject, found 'float'",
    );
    try expectCompileError(
        "enum Choice { one; other } func main() { let value = match Choice.one { 1 => true; else => false } }",
        "enum match requires enum variant branches",
    );
    try expectCompileError(
        "func main() { let value = match 1 { one => true; else => false } }",
        "literal match requires literal branches",
    );
    try expectCompileError(
        "func narrow() int8 { return 0 } func main() { let value = match narrow() { 128 => true; else => false } }",
        "integer literal is outside the range of 'int8'",
    );
}

test "route unmatched variants through a terminal else branch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Direction { north; south; east; west }
        \\func vertical(value:Direction) bool {
        \\    return match value { north => true; south => true; else => false }
        \\}
        \\func main() {
        \\    print(vertical(Direction.north()))
        \\    print(vertical(Direction.east()))
        \\    print(match Direction.west() { else => "fallback" })
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("true\nfalse\nfallback\n", result.stdout);
}

test "diagnose invalid else match branches" {
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1; right => 2; else => 3 } }",
        "else match branch is unreachable because every variant is already covered",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { else => 1; left => 2 } }",
        "else match branch must be last",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1; else(name) => 2 } }",
        "else match branch cannot bind associated values",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1 as int8; else => 2 } }",
        "match branch expects exact type 'int8', found 'int'",
    );
}

test "execute imperative match blocks with branch-local mutable copies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum State { waiting; connected(str); closed(str) }
        \\func show(value:State) {
        \\    match value {
        \\        waiting => { print("waiting") }
        \\        connected(var name) => { name = "changed"; print(name) }
        \\        closed(reason) => { print(reason) }
        \\    }
        \\    match value { waiting => { print("kept") }; else => { print("kept other") } }
        \\}
        \\func classify(value:State) int {
        \\    match value { waiting => { return 1 }; connected(name) => { return 2 }; else => { return 3 } }
        \\}
        \\func main() {
        \\    show(State.waiting())
        \\    show(State.connected("server"))
        \\    print(classify(State.closed("done")))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("waiting\nkept\nchanged\nkept other\n3\n", result.stdout);
}

test "preserve enclosing break and continue through imperative match" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Action { stop; retry }
        \\func run(action:Action) {
        \\    var active = true
        \\    while active {
        \\        active = false
        \\        match action { stop => { break }; retry => { continue } }
        \\        print("unreachable")
        \\    }
        \\    print("done")
        \\}
        \\func main() { run(Action.stop()); run(Action.retry()) }
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("done\ndone\n", result.stdout);
}

test "diagnose mixed and misplaced match branch forms" {
    try expectCompileError(
        "enum Choice { left; right } func main() { match Choice.left() { left => { print(1) }; right => 2 } }",
        "match statement expression branch must be a call, cascade, propagated result, or nested match",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => { print(1) }; right => { print(2) } } }",
        "value-producing match block must end with 'yield value'",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { match Choice.left() { left => 1; right => 2 } }",
        "match statement expression branch must be a call, cascade, propagated result, or nested match",
    );
    try expectCompileError(
        "enum Choice { value(int); empty } func main() { match Choice.value(1) { value(number) => { print(number) }; empty => {} }; print(number) }",
        "unknown variable 'number'",
    );
}

test "evaluate ordered condition matches and short statement branches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func category(score:int) str {
        \\    return match {
        \\        score >= 16 => "excellent"
        \\        score >= 10 => "admitted"
        \\        else => "insufficient"
        \\    }
        \\}
        \\func accept() { print("accepted") }
        \\func reject() { print("rejected") }
        \\class Probe {
        \\    var checks:int
        \\    init() { self.checks = 0 }
        \\    func check(result:bool) bool { self.checks++; return result }
        \\}
        \\func announce(condition:bool) {
        \\    match condition { true => accept(); else => reject() }
        \\}
        \\func main() {
        \\    print(category(18))
        \\    print(category(12))
        \\    print(category(4))
        \\    announce(true)
        \\    announce(false)
        \\    var probe = Probe()
        \\    let selected = match {
        \\        probe.check(true) => 1
        \\        probe.check(true) => 2
        \\        else => 0
        \\    }
        \\    assert(selected == 1)
        \\    assert(probe.checks == 1)
        \\    let value = 41
        \\    let available = match {
        \\        true => value + 1
        \\        move value == 0 => 0
        \\        else => -1
        \\    }
        \\    assert(available == 42)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("excellent\nadmitted\ninsufficient\naccepted\nrejected\n", result.stdout);
}

test "yield values from recursive match branch blocks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func predicted(condition:bool, x:float) float {
        \\    return match condition {
        \\        true => {
        \\            var result = 0.0
        \\            result += x * 10.0
        \\            result /= 2.0
        \\            yield match result > 5.0 {
        \\                true => {
        \\                    let bonus = 0.5
        \\                    yield result + bonus
        \\                }
        \\                else => result
        \\            }
        \\        }
        \\        else => 0.0
        \\    }
        \\}
        \\func main() {
        \\    assert(predicted(true, 2.0) == 10.5, "recursive yield")
        \\    assert(predicted(true, 1.0) == 5.0, "expression sibling")
        \\    assert(predicted(false, 2.0) == 0.0, "outer fallback")
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "diagnose invalid condition matches and yield placement" {
    try expectCompileError(
        "func main() { let value = match { true => 1 } }",
        "condition match requires an else branch",
    );
    try expectCompileError(
        "func main() { let value = match { 1 => true; else => false } }",
        "condition match branch requires bool, found 'int'",
    );
    try expectCompileError(
        "func main() { yield 1 }",
        "yield is only valid as the final statement of a value-producing match block",
    );
    try expectCompileError(
        "func main() { let value = match true { true => { let result = 1 }; else => 0 } }",
        "value-producing match block must end with 'yield value'",
    );
    try expectCompileError(
        "func main() { let value = match true { true => { yield 1; print(1) }; else => 0 } }",
        "value-producing match block must end with 'yield value'",
    );
    try expectCompileError(
        "func main() { let value = match true { true => { yield 1 as int8 }; else => 0 } }",
        "match branch expects exact type 'int8', found 'int'",
    );
}
