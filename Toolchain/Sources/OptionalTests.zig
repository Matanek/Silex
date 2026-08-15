const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const Parser = @import("Parser.zig").Parser;

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

fn expectParseError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(), source);
    try std.testing.expectError(error.InvalidSource, parser.parse());
    try std.testing.expectEqualStrings(message, parser.diagnostic.?.message);
}

test "lower null and optional promotion to deterministic typed IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func lift(value:int) int? { return value }
        \\func none() int? { return null }
        \\func main() {}
    );
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        \\func @lift(%0:int) -> int? {
        \\entry:
        \\    %1:int? = optional.some %0
        \\    return %1
        \\}
        \\
        \\func @none() -> int? {
        \\entry:
        \\    %0:int? = optional.null
        \\    return %0
        \\}
        \\
        \\func @main() -> void {
        \\entry:
        \\    return
        \\}
        \\
    , text);
}

test "transport optional fundamentals and structures through language boundaries" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Box { let value:int? }
        \\func identity(value:int?) int? { return value }
        \\func absent() int? { return null }
        \\func present() int? { return 42 }
        \\func through_field() int? { return Box(value:9).value }
        \\func main() {
        \\    let absent:int?
        \\    let present:int? = 42
        \\    var current:int?
        \\    current = 9
        \\    identity(absent)
        \\    identity(present)
        \\    identity(Box(value:current).value)
        \\}
    );
    _ = try Interpreter.runCapture(allocator, compilation.ir);
    const absent = (try Interpreter.invoke(allocator, compilation.ir, 1, &.{})).optional;
    try std.testing.expect(absent.value == null);
    const present = (try Interpreter.invoke(allocator, compilation.ir, 2, &.{})).optional;
    try std.testing.expectEqual(@as(i64, 42), present.value.?.integer);
    const field = (try Interpreter.invoke(allocator, compilation.ir, 3, &.{})).optional;
    try std.testing.expectEqual(@as(i64, 9), field.value.?.integer);
}

test "use optional parameter context and preserve overload selection" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func accept(value:int?) int { return 1 }
        \\func choose(value:int?) int { return 2 }
        \\func choose(value:str?) int { return 3 }
        \\func main() {
        \\    let number:int? = 7
        \\    print(accept(null))
        \\    print(choose(number))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("1\n2\n", result.stdout);
}

test "reject invalid optional forms and context-free null" {
    try expectParseError("func invalid(value:void?) {} func main() {}", "'void?' is not a valid type");
    try expectCompileError("func main() { let value = null }", "'null' requires an expected optional type");
    try expectCompileError(
        "func main() { let value:int = null }",
        "'null' requires an expected optional type",
    );
    try expectCompileError(
        "func main() { let value:int? = 1; let required:int = value }",
        "variable 'required' expects 'int', found 'int?'",
    );
}

test "preserve every directly nested optional layer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func main() {
        \\    let pending:int?? = null
        \\    let missing:int? = null
        \\    let resolved_missing:int?? = missing
        \\    let found:int?? = 42
        \\    let deep:int??? = 7
        \\    if outer = pending { print("unexpected") } else { print("pending") }
        \\    if inner = resolved_missing { print(inner == null) }
        \\    if inner = found { if value = inner { print(value) } }
        \\    print(found!!)
        \\    print(deep!!!)
        \\    let values:int??[] = [pending, resolved_missing, found]
        \\    print(values.count())
        \\    print(pending == null)
        \\    print(resolved_missing == null)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("pending\ntrue\n42\n42\n7\n3\ntrue\nfalse\n", result.stdout);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.count(u8, text, "optional.some") >= 6);
}

test "compare all optional presence states with null on either side" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func main() {
        \\    let absent:int?
        \\    let same_absence:int? = null
        \\    let first:int? = 7
        \\    let same:int? = 7
        \\    let other:int? = 8
        \\    print(absent == same_absence)
        \\    print(first == same)
        \\    print(first == other)
        \\    print(absent == first)
        \\    print(absent == null)
        \\    print(null != first)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("true\ntrue\nfalse\nfalse\ntrue\ntrue\n", result.stdout);
}

test "refine direct local presence in positive and negative branches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Position { let x:int }
        \\func inspect(position:Position?) {
        \\    if position != null { print(position.x) }
        \\    if null == position { print("missing") }
        \\    else { print(position.x + 1) }
        \\}
        \\func main() {
        \\    inspect(Position(x:41))
        \\    inspect(null)
        \\}
    );
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "optional.unwrap") != null);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("41\n42\nmissing\n", result.stdout);
}

test "invalidate mutable proofs and keep compound or member proofs local" {
    try expectCompileError(
        "func main() { var value:int? = 1; if value != null { value = null; print(value + 1) } }",
        "operator '+' does not accept 'int?' and 'int'",
    );
    try expectCompileError(
        "func main() { let value:int? = 1; if !(value == null) { print(value + 1) } }",
        "operator '+' does not accept 'int?' and 'int'",
    );
    try expectCompileError(
        "func main() { let value:int? = 1; if value != null && true { print(value + 1) } }",
        "operator '+' does not accept 'int?' and 'int'",
    );
    try expectCompileError(
        "struct Box { let value:int? } func main() { let box = Box(value:1); if box.value != null { print(box.value + 1) } }",
        "operator '+' does not accept 'int?' and 'int'",
    );
}

test "bind optional values across conditional forms with deterministic effects" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func observed(value:int?) int? { print("source"); return value }
        \\func main() {
        \\    if item = observed(1) { print(item) }
        \\    if missing = observed(null) { print(100) }
        \\    if true {} elif skipped = observed(2) { print(skipped) }
        \\    if false {} elif reached = observed(3) { print(reached) }
        \\    if false {} else if (let alternative = observed(4)) { print(alternative) }
        \\    if var mutable = observed(5) { mutable += 1; print(mutable) }
        \\    var next:int? = 6
        \\    while item = observed(next) { print(item); next = null; continue }
        \\    next = 7
        \\    while (var item = observed(next)) { item += 1; print(item); break }
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const result = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    try std.testing.expectEqualStrings(
        "source\n1\nsource\nsource\n3\nsource\n4\nsource\n6\nsource\n6\nsource\nsource\n8\n",
        result.stdout,
    );
}

test "enforce conditional binding type mutability scope and collisions" {
    try expectCompileError(
        "func main() { if value = 1 { print(value) } }",
        "conditional binding 'value' expects an optional source, found 'int'",
    );
    try expectCompileError(
        "func main() { if let value:int = null {} }",
        "expected '=' after conditional binding name",
    );
    try expectCompileError(
        "func main() { let item = 1; if item = null {} }",
        "variable 'item' is already declared in this scope",
    );
    try expectCompileError(
        "func main() { let source:int? = 1; if item = source { item = 2 } }",
        "cannot assign to immutable variable 'item'",
    );
    try expectCompileError(
        "func main() { let source:int? = 1; if item = source {} print(item) }",
        "unknown variable 'item'",
    );
}

test "flatten safe field chains and require every nullable step" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Position { let x:int }
        \\struct Profile { let position:Position? }
        \\func main() {
        \\    let profile:Profile? = Profile(position:Position(x:42))
        \\    let missing:Profile?
        \\    if x = profile?.position?.x { print(x) }
        \\    if x = missing?.position?.x { print(x) }
        \\}
    );
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.count(u8, text, "optional.unwrap") >= 4);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
    try expectCompileError(
        "struct Position { let x:int } struct Profile { let position:Position? } func main() { let profile:Profile?; print(profile?.position.x) }",
        "type 'Position?' has no fields",
    );
}

test "skip safe method effects flatten results and mutate optional var places" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Position {
        \\    var x:int
        \\    func shifted(delta:int) int { return self.x + delta }
        \\    func maybe() int? { return self.x }
        \\    func show(label:str) { print(label); print(self.x) }
        \\    func translate(delta:int) { self.x += delta }
        \\}
        \\func argument() int { print("argument"); return 2 }
        \\func observed(value:Position?) Position? { print("receiver"); return value }
        \\func main() {
        \\    var position:Position? = Position(x:40)
        \\    let absent:Position?
        \\    if result = position?.shifted(argument()) { print(result) }
        \\    absent?.shifted(argument())
        \\    observed(absent)?.shifted(argument())
        \\    if flat = position?.maybe() { print(flat) }
        \\    position?.show("show")
        \\    position?.translate(2)
        \\    if updated = position { print(updated.x) }
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(source);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("argument\n42\nreceiver\n40\nshow\n40\n42\n", result.stdout);
}

test "diagnose invalid safe receivers and immutable mutating places" {
    try expectCompileError(
        "struct Position { let x:int } func main() { let value = Position(x:1); print(value?.x) }",
        "safe access '?.' requires an optional receiver, found 'Position'",
    );
    try expectCompileError(
        "struct Position { var x:int; func translate() { self.x += 1 } } func main() { let value:Position? = Position(x:1); value?.translate() }",
        "mutating method 'translate' requires a var receiver",
    );
}

test "short circuit safe assignments and mutate stored optional paths" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Position { var x:int }
        \\struct Profile { var position:Position?; var accepted:int; var values:int[] }
        \\func index() int { print("index"); return 0 }
        \\func replacement() int { print("right"); return 9 }
        \\func main() {
        \\    var present:Profile? = Profile(position:Position(x:1), accepted:2, values:[3])
        \\    var absent:Profile?
        \\    present?.position?.x = 10
        \\    present?.accepted += 1
        \\    present?.values[index()] = replacement()
        \\    absent?.position?.x = replacement()
        \\    absent?.values[index()] = replacement()
        \\    if profile = present {
        \\        if position = profile.position { print(position.x) }
        \\        print(profile.accepted, " ", profile.values[0])
        \\    }
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const result = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    try std.testing.expectEqualStrings("index\nright\n10\n3 9\n", result.stdout);
}

test "diagnose immutable and non optional safe assignment paths" {
    try expectCompileError(
        "struct Position { var x:int } func main() { let position:Position? = Position(x:1); position?.x = 2 }",
        "safe assignment requires a var root",
    );
    try expectCompileError(
        "struct Position { var x:int } func main() { var position = Position(x:1); position?.x = 2 }",
        "safe assignment '?.' requires an optional receiver, found 'Position'",
    );
    try expectCompileError(
        "struct Position { var x:int } struct Profile { let position:Position? } func main() { var profile:Profile? = Profile(position:Position(x:1)); profile?.position?.x = 2 }",
        "cannot assign through immutable field 'position'",
    );
}

test "safe assignments mutate shared classes and clean replaced values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Resource { let name:str; drop { print("drop ", self.name) } }
        \\struct Holder { var resource:Resource }
        \\class Counter { public var value:int }
        \\func main() {
        \\    var holder:Holder? = Holder(resource:Resource(name:"old"))
        \\    holder?.resource = Resource(name:"new")
        \\    var counter:Counter? = Counter(value:1)
        \\    var alias = counter
        \\    counter?.value += 1
        \\    if shared = alias { print(shared.value) }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, result.stdout, "drop old") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.stdout, "2\n") != null);
}

test "force one present optional layer with postfix bang" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Box { let value:int }
        \\enum Choice { value(int); empty }
        \\class Entity { public let value:int }
        \\func observed() int? { print("source"); return 40 }
        \\func main() {
        \\    let number:int? = 2
        \\    let box:Box? = Box(value:3)
        \\    let choice:Choice? = Choice.value(4)
        \\    var entity:Entity? = Entity(value:5)
        \\    print(observed()! + number!)
        \\    print(box!.value)
        \\    match choice! { value(item) => { print(item) }; empty => {} }
        \\    print(entity!.value)
        \\    print(!false)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("source\n42\n3\n4\n5\ntrue\n", result.stdout);
    try expectCompileError("func main() { let value = 1! }", "postfix '!' expects an optional value, found 'int'");
}

test "forced optional failure matches panic diagnostics in the interpreter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    var compilation = try frontend.compile(
        \\func main() {
        \\    let value:int?
        \\    print(value!)
        \\}
    );
    compilation.ir.files = &.{"Main.sx"};
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 1), result.exit_code);
    try std.testing.expectEqualStrings("Main.sx:3:16: runtime error: forced optional extraction failed\n", result.stderr);
}

test "coalesce optionals lazily with right associative fallback" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func source(label:str, value:int?) int? { print(label); return value }
        \\func fallback(label:str, value:int) int { print(label); return value }
        \\func main() {
        \\    print(source("present", 1) ?? fallback("skipped", 9))
        \\    print(source("absent", null) ?? fallback("used", 2))
        \\    print(source("first", null) ?? source("second", 3) ?? fallback("last", 4))
        \\    let missing:int?
        \\    let alternative:int? = 5
        \\    let retained:int? = missing ?? alternative
        \\    if value = retained { print(value) }
        \\    let narrow:int8? = null
        \\    print(narrow ?? 6)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("present\n1\nabsent\nused\n2\nfirst\nsecond\n3\n5\n6\n", result.stdout);
}

test "diagnose invalid optional coalescing operands" {
    try expectCompileError("func main() { print(1 ?? 2) }", "left operand of '??' must be optional, found 'int'");
    try expectCompileError(
        "func main() { let value:int? = 1; print(value ?? \"text\") }",
        "right operand of '??' expects 'int' or 'int?', found 'str'",
    );
}

test "coalescing composite values cleans only the selected owned result" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Resource { let name:str; drop { print("drop ", self.name) } }
        \\func fallback() Resource { print("compute"); return Resource(name:"fallback") }
        \\func main() {
        \\    { let present:Resource? = Resource(name:"present"); let selected = present ?? fallback(); print(selected.name) }
        \\    { let absent:Resource?; let selected = absent ?? fallback(); print(selected.name) }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, result.stdout, "present") != null);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, result.stdout, "compute\n"));
    try std.testing.expect(std.mem.indexOf(u8, result.stdout, "drop present") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.stdout, "drop fallback") != null);
}

test "nested optional safe access removes only one layer" {
    try expectCompileError(
        "struct Box { let value:int } func main() { let nested:Box?? = Box(value:1); print(nested?.value) }",
        "type 'Box?' has no fields",
    );
}
