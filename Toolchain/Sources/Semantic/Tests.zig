const std = @import("std");
const Ir = @import("../Ir.zig");
const Parser = @import("../Parser.zig").Parser;
const Types = @import("../Types.zig");
const Analyzer = @import("Analyzer.zig").Analyzer;

fn expectSemanticError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator, source);
    var analyzer = Analyzer.init(allocator);
    try std.testing.expectError(error.InvalidSource, analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(message, analyzer.diagnostic.?.message);
}

test "lower empty main to an explicit void return" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator, "func main() {}");
    var analyzer = Analyzer.init(allocator);
    const text = try Ir.writeText(allocator, try analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(
        \\func @main() -> void {
        \\entry:
        \\    return
        \\}
        \\
    , text);
}

test "lower conditional paths to explicit deterministic blocks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\func choose(flag:bool) int {
        \\    if flag { return 1 }
        \\    else { return 2 }
        \\}
        \\func main() {}
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(@as(usize, 3), program.functions[0].blocks.len);
    try std.testing.expectEqual(@as(Ir.BlockId, 1), program.functions[0].blocks[0].terminator.branch.then_block);
    try std.testing.expectEqual(@as(Ir.BlockId, 2), program.functions[0].blocks[0].terminator.branch.else_block);
}

test "enforce boolean conditions lexical branches and path-complete returns" {
    try expectSemanticError(
        "func choose() int { if true { return 1 } } func main() {}",
        "function 'choose' must return 'int' on every path",
    );
    try expectSemanticError(
        "func main() { if 1 { print(1) } }",
        "if condition expects 'bool'",
    );
    try expectSemanticError(
        "func main() { if true { let scoped = 1 } print(scoped) }",
        "unknown variable 'scoped'",
    );
    try expectSemanticError(
        "func main() { let value = 1; if true { let value = 2 } }",
        "variable 'value' is already declared in this scope",
    );
}

test "lower mutable locals to typed abstract storage" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\func main() {
        \\    var value:int = 1
        \\    value = 2
        \\    print(value)
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqualSlices(Types.Type, &.{.int}, program.functions[0].local_types);
    const text = try Ir.writeText(allocator, program);
    try std.testing.expectEqualStrings(
        \\func @main() -> void {
        \\entry:
        \\    %0:int = const 1
        \\    store $0:int, %0
        \\    %1:int = const 2
        \\    store $0:int, %1
        \\    %2:int = load $0:int
        \\    print %2
        \\    return
        \\}
        \\
    , text);
}

test "lower nominal structure aggregates and chained field reads" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\struct Position {
        \\    let layer:int = 3
        \\    var x:int
        \\}
        \\struct Entity { var position:Position }
        \\func main() {
        \\    let entity = Entity(position:Position(x:4,))
        \\    print(entity.position.layer)
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(@as(usize, 2), program.structures.len);
    try std.testing.expectEqualStrings("Position", program.structures[0].name);
    const instructions = program.functions[0].blocks[0].instructions;
    try std.testing.expect(instructions[2] == .structure_init);
    try std.testing.expect(instructions[3] == .structure_init);
    try std.testing.expect(instructions[4] == .field_load);
    try std.testing.expect(instructions[5] == .field_load);
    const text = try Ir.writeText(allocator, program);
    try std.testing.expect(std.mem.indexOf(u8, text, "struct.init @Position(.layer=%0, .x=%1)") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "field %4, .layer") != null);
}

test "enforce private structure fields and methods while keeping defaults public" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\struct Vault {
        \\    private let secret:int = 40
        \\    private func offset() int { return 2 }
        \\    func reveal() int { return self.secret + self.offset() }
        \\}
        \\func main() { print(Vault().reveal()) }
    );
    var analyzer = Analyzer.init(allocator);
    const result = try @import("../Interpreter.zig").runCapture(allocator, try analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings("42\n", result.stdout);

    try expectSemanticError(
        "struct Vault { private let secret:int = 1 } func main() { print(Vault().secret) }",
        "field 'secret' is private and unavailable here",
    );
    try expectSemanticError(
        "struct Vault { private func secret() int { return 1 } } func main() { print(Vault().secret()) }",
        "method 'secret' is private and unavailable here",
    );
}

test "enforce structure fields nominal identity defaults and representation cycles" {
    try expectSemanticError(
        "struct Position { var x:int } struct Velocity { var x:int } func main() { let value:Velocity = Position(x:1) }",
        "variable 'value' expects 'Velocity', found 'Position'",
    );
    try expectSemanticError(
        "struct Position { var x:int } func main() { let value = Position(depth:1) }",
        "structure 'Position' has no field named 'depth'",
    );
    try expectSemanticError(
        "struct Position { var x:int } func main() { let value = Position(x:1, x:2) }",
        "field 'x' is provided more than once",
    );
    try expectSemanticError(
        "struct Position { var x:int } func main() { let value = Position(1) }",
        "structure 'Position' uses named fields",
    );
    try expectSemanticError(
        "struct Node { var next:Node } func main() {}",
        "structure 'Node' has a recursive value representation",
    );
    try expectSemanticError(
        "struct Left { var right:Right } struct Right { var left:Left } func main() {}",
        "structure 'Left' has a recursive value representation",
    );
    try expectSemanticError(
        "struct Value { var number:int = observed() } func observed() int { return 1 } func main() {}",
        "field default must be a fundamental literal or structure aggregate",
    );
}

test "transport compare and overload nominal structure values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\struct Position { var x:int; var y:int }
        \\struct Velocity { var x:int; var y:int }
        \\func identity(value:Position) Position { return value }
        \\func kind(value:Position) int { return 1 }
        \\func kind(value:Velocity) int { return 2 }
        \\func main() {
        \\    var first = Position(x:20, y:22)
        \\    first = identity(first)
        \\    let second:Position = identity(first)
        \\    print(first == second, first != Position(), kind(first), kind(Velocity()))
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(Types.Type.structure(0), program.functions[0].parameter_types[0]);
    try std.testing.expectEqual(Types.Type.structure(0), program.functions[0].return_type);
    try expectSemanticError(
        "struct Position { var x:int } struct Velocity { var x:int } func read(value:Position) {} func main() { read(Velocity()) }",
        "argument 1 of 'read' expects 'Position', found 'Velocity'",
    );
}

test "lower mutable field paths by rebuilding value aggregates" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\struct Position { var x:int; var y:int }
        \\struct Entity { var position:Position; var name:str }
        \\func main() {
        \\    var entity = Entity(position:Position(x:1, y:2), name:"Ada")
        \\    entity.position.x += 2
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const instructions = (try analyzer.analyze(try parser.parse())).functions[0].blocks[0].instructions;
    var structure_initializations: usize = 0;
    var local_stores: usize = 0;
    for (instructions) |instruction| switch (instruction) {
        .structure_init => structure_initializations += 1,
        .local_store => local_stores += 1,
        else => {},
    };
    try std.testing.expectEqual(@as(usize, 4), structure_initializations);
    try std.testing.expectEqual(@as(usize, 2), local_stores);
}

test "enforce deep mutability along field assignment paths" {
    try expectSemanticError(
        "struct Item { var value:int } func main() { let item = Item(); item.value = 1 }",
        "cannot assign to immutable variable 'item'",
    );
    try expectSemanticError(
        "struct Item { let value:int } func main() { var item = Item(); item.value = 1 }",
        "cannot assign through immutable field 'value'",
    );
    try expectSemanticError(
        "struct Item { var value:int } struct Box { let item:Item } func main() { var box = Box(); box.item.value = 1 }",
        "cannot assign through immutable field 'item'",
    );
    try expectSemanticError(
        "struct Item { var value:int } func main() { var item = Item(); item.missing = 1 }",
        "structure 'Item' has no field named 'missing'",
    );
    try expectSemanticError(
        "struct Item { var label:str } func main() { var item = Item(); item.label++ }",
        "operator '++' requires a numeric field, found 'str'",
    );
}

test "lower overloaded constructors with complete branched self initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\struct Choice {
        \\    let value:int
        \\    let tag:int = 7
        \\    init(value:int, positive:bool) {
        \\        if positive { self.value = value } else { self.value = -value }
        \\    }
        \\    init(value:bool) {
        \\        if value { self.value = 1 } else { self.value = 0 }
        \\    }
        \\}
        \\func main() {
        \\    let first = Choice(5, true)
        \\    let second = Choice(false)
        \\    print(first.value + first.tag + second.value)
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(@as(usize, 3), program.functions.len);
    try std.testing.expectEqualStrings("Choice.init#0", program.functions[1].name);
    try std.testing.expectEqual(Types.Type.structure(0), program.functions[1].return_type);
}

test "diagnose invalid constructor initialization and calls" {
    try expectSemanticError(
        "struct Value { let number:int; init() {} } func main() {}",
        "field 'number' is not initialized on every constructor path",
    );
    try expectSemanticError(
        "struct Value { let number:int; init(flag:bool) { if flag { self.number = 1 } } } func main() {}",
        "field 'number' is not initialized on every constructor path",
    );
    try expectSemanticError(
        "struct Value { let number:int; init() { self.number = 1; self.number = 2 } } func main() {}",
        "immutable field 'number' is initialized more than once",
    );
    try expectSemanticError(
        "struct Value { let first:int; let second:int; init() { self.second = self.first; self.first = 1 } } func main() {}",
        "field 'first' is read before initialization",
    );
    try expectSemanticError(
        "struct Value { let number:int; init() { observe(self); self.number = 1 } } func observe(value:Value) {} func main() {}",
        "self cannot be used before all fields are initialized",
    );
    try expectSemanticError(
        "struct Value { let number:int; init(number:int) { self.number = number } } func main() { Value(true) }",
        "no constructor of 'Value' matches the argument types",
    );
}

test "infer transitive method mutability and lower private receiver results" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\struct Counter {
        \\    var value:int
        \\    func increment() { self.value++ }
        \\    func forward() { self.increment() }
        \\    func add(amount:int) int { self.value += amount; return self.value }
        \\    func current() int { return self.value }
        \\    func duplicate() Counter { return self }
        \\}
        \\func main() {
        \\    var counter = Counter(value:1)
        \\    counter.forward()
        \\    let updated = counter.add(2)
        \\    print(updated, counter.duplicate().current())
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(@as(usize, 6), program.functions.len);
    try std.testing.expectEqual(@as(usize, 2), program.structures.len);
    try std.testing.expectEqualStrings("Counter.add#result2", program.structures[1].name);
    try std.testing.expectEqual(Types.Type.structure(0), program.functions[1].return_type);
    try std.testing.expectEqual(Types.Type.structure(1), program.functions[3].return_type);
}

test "enforce receiver mutability and method overload contracts" {
    try expectSemanticError(
        "struct Counter { var value:int; func increment() { self.value++ } } func main() { let counter = Counter(); counter.increment() }",
        "mutating method 'increment' requires a var receiver",
    );
    try expectSemanticError(
        "struct Counter { var value:int; func increment() { self.value++ } } func main() { Counter().increment() }",
        "mutating method 'increment' requires a var receiver",
    );
    try expectSemanticError(
        "struct Counter { var value:int; func choose(value:int) {} func choose(value:bool) {} } func main() { let counter = Counter(); counter.choose(\"bad\") }",
        "no overload of method 'choose' matches the argument types",
    );
    try expectSemanticError(
        "struct Counter { var value:int; func current() int { return self.value } func current() bool { return true } } func main() {}",
        "method 'current' with these parameter types is already declared in 'Counter'",
    );
    try expectSemanticError(
        "struct Counter { var value:int; func first(flag:bool) { if flag { self.second(false) } } func second(flag:bool) { if flag { self.first(false) } else { self.value++ } } } func main() { let counter = Counter(); counter.first(true) }",
        "mutating method 'first' requires a var receiver",
    );
}

test "diagnose invalid assignments at the language boundary" {
    try expectSemanticError(
        "func main() { let value = 1; value = 2 }",
        "cannot assign to immutable variable 'value'",
    );
    try expectSemanticError(
        "func change(value:int) { value = 2 } func main() {}",
        "cannot assign to parameter 'value'",
    );
    try expectSemanticError(
        "func main() { missing = 2 }",
        "unknown variable 'missing'",
    );
    try expectSemanticError(
        "func main() { var value:bool = true; value = 1 }",
        "assignment to 'value' expects 'bool', found 'int'",
    );
}

test "lower while to a condition backedge and an explicit exit" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\func main() {
        \\    var value = 0
        \\    while value < 2 { value = value + 1 }
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const function = (try analyzer.analyze(try parser.parse())).functions[0];
    try std.testing.expectEqual(@as(usize, 4), function.blocks.len);
    try std.testing.expectEqual(@as(Ir.BlockId, 1), function.blocks[0].terminator.jump);
    try std.testing.expectEqual(@as(Ir.BlockId, 2), function.blocks[1].terminator.branch.then_block);
    try std.testing.expectEqual(@as(Ir.BlockId, 3), function.blocks[1].terminator.branch.else_block);
    try std.testing.expectEqual(@as(Ir.BlockId, 1), function.blocks[2].terminator.jump);
    try std.testing.expect(function.blocks[1].instructions[0] == .local_load);
}

test "enforce loop conditions controls and lexical bodies" {
    try expectSemanticError(
        "func main() { while 1 { break } }",
        "while condition expects 'bool'",
    );
    try expectSemanticError(
        "func main() { break }",
        "'break' is only valid inside a loop",
    );
    try expectSemanticError(
        "func main() { continue }",
        "'continue' is only valid inside a loop",
    );
    try expectSemanticError(
        "func main() { while false { let scoped = 1 } print(scoped) }",
        "unknown variable 'scoped'",
    );
}

test "lower arithmetic assignments through the existing checked operators" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\func main() {
        \\    var value:int8 = 1
        \\    value += 2
        \\    value++
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const instructions = (try analyzer.analyze(try parser.parse())).functions[0].blocks[0].instructions;
    try std.testing.expect(instructions[2] == .local_load);
    try std.testing.expectEqual(Ir.BinaryOperator.add, instructions[4].binary.operator);
    try std.testing.expect(instructions[5] == .local_store);
    try std.testing.expect(instructions[6] == .local_load);
    try std.testing.expectEqual(Ir.BinaryOperator.add, instructions[8].binary.operator);
    try std.testing.expect(instructions[9] == .local_store);
}

test "diagnose invalid arithmetic assignments with their source operator" {
    try expectSemanticError(
        "func main() { let value = 1; value += 2 }",
        "cannot apply '+=' to immutable variable 'value'",
    );
    try expectSemanticError(
        "func main() { var value = \"text\"; value++ }",
        "operator '++' requires a numeric variable, found 'str'",
    );
    try expectSemanticError(
        "func main() { var value:bool; value += true }",
        "operator '+=' requires a numeric variable, found 'bool'",
    );
    try expectSemanticError(
        "func main() { var value:int8 = 1; let wider:int16 = 2; value += wider }",
        "operator '+=' does not accept 'int8' and 'int16'",
    );
}

test "resolve forward calls overloads locals and intrinsic values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\func main() {
        \\    answer()
        \\    choose(true)
        \\}
        \\func choose(value:int) int { return value }
        \\func choose(value:bool) bool { return value }
        \\func answer() int {
        \\    let left:int = 40
        \\    let right:int = 2
        \\    let ready:bool
        \\    return left + right
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(@as(usize, 4), program.functions.len);
    try std.testing.expectEqual(Types.Type.bool, program.functions[0].value_types[1]);
    try std.testing.expectEqual(@as(Ir.FunctionId, 3), program.functions[0].blocks[0].instructions[0].call.function);
    try std.testing.expectEqual(@as(u64, 2), program.functions[3].blocks[0].instructions[1].constant_int.bits);
    try std.testing.expect(!program.functions[3].blocks[0].instructions[2].constant_bool.value);
}

test "lower fundamental calculation to deterministic IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\func add(left:int, right:int) int {
        \\    let result = left + right
        \\    return result
        \\}
        \\func answer() int { return add(40, 2) }
        \\func main() { answer() }
    );
    var analyzer = Analyzer.init(allocator);
    const text = try Ir.writeText(allocator, try analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(
        \\func @add(%0:int, %1:int) -> int {
        \\entry:
        \\    %2:int = add %0, %1
        \\    return %2
        \\}
        \\
        \\func @answer() -> int {
        \\entry:
        \\    %0:int = const 40
        \\    %1:int = const 2
        \\    %2:int = call @add(%0, %1)
        \\    return %2
        \\}
        \\
        \\func @main() -> void {
        \\entry:
        \\    %0:int = call @answer()
        \\    return
        \\}
        \\
    , text);
}

test "accept the minimum signed integer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(
        allocator,
        "func minimum() int { return -9223372036854775808 } func main() {}",
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(@as(u64, @bitCast(@as(i64, std.math.minInt(i64)))), program.functions[0].blocks[0].instructions[0].constant_int.bits);
}

test "lower strings comparisons and effects to deterministic IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\func main() {
        \\    let empty:str
        \\    print("A\0B")
        \\    assert(2 * 3 >= 6, "math")
        \\    panic(empty)
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const text = try Ir.writeText(allocator, try analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(
        \\func @main() -> void {
        \\entry:
        \\    %0:str = const ""
        \\    %1:str = const "A\0B"
        \\    print %1
        \\    %2:int = const 2
        \\    %3:int = const 3
        \\    %4:int = mul %2, %3
        \\    %5:int = const 6
        \\    %6:bool = ge %4, %5
        \\    %7:str = const "math"
        \\    assert %6, %7
        \\    panic %0
        \\}
        \\
    , text);
}

test "report declaration and resolution errors" {
    try expectSemanticError(
        "func value(input:int) int { return input } func value(other:int) bool { return true } func main() {}",
        "function 'value' with these parameter types is already declared",
    );
    try expectSemanticError(
        "func value(input:int, input:int) int { return input } func main() {}",
        "parameter 'input' is already declared",
    );
    try expectSemanticError(
        "func main() { let value = 1; let value = 2 }",
        "variable 'value' is already declared in this scope",
    );
    try expectSemanticError("func value() int { return missing } func main() {}", "unknown variable 'missing'");
    try expectSemanticError("func main() { missing() }", "unknown function 'missing'");
    try expectSemanticError(
        "func add(left:int, right:int) int { return left + right } func main() { add(1) }",
        "function 'add' expects 2 arguments, found 1",
    );
    try expectSemanticError(
        "func enabled(value:bool) bool { return value } func main() { enabled(1) }",
        "argument 1 of 'enabled' expects 'bool', found 'int'",
    );
    try expectSemanticError(
        "func choose(left:int, right:int) int { return left } func choose(left:bool, right:bool) bool { return left } func main() { choose(1, true) }",
        "no overload of function 'choose' matches the argument types",
    );
}

test "lower omitted parameter defaults after selecting an effective signature" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\func seed() int { return 40 }
        \\func add(left:int = seed(), right:int = 2) int { return left + right }
        \\func main() { print(add()); print(add(20)); print(add(20, 22)) }
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    const text = try Ir.writeText(allocator, program);
    try std.testing.expect(std.mem.indexOf(u8, text, "call @add(%0, %1)") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "call @add(%3, %4)") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "call @add(%6, %7)") != null);
}

test "reject collisions between effective signatures" {
    try expectSemanticError(
        "func value() {} func value(input:float = 0) {} func main() {}",
        "function 'value()' is already exposed by the declaration at 1:6",
    );
    try expectSemanticError(
        "struct Value { init(input:float) {} init(x:float, y:float = 0) {} } func main() {}",
        "constructor 'init(float)' is already exposed by the declaration at 1:16",
    );
    try expectSemanticError(
        "struct Vector { init() {} init(x:float = 0, y:float = 0, z:float = 0) {} } func main() {}",
        "constructor 'init()' is already exposed by the declaration at 1:17",
    );
    try expectSemanticError(
        "struct Value { func read() {} func read(input:int = 0) {} } func main() {}",
        "method 'read()' is already exposed in 'Value' by the declaration at 1:21",
    );
    try expectSemanticError(
        "func alias(value:int = 0) {} func alias(value:int64) {} func main() {}",
        "function 'alias(int)' is already exposed by the declaration at 1:6",
    );
}

test "reject an incompatible or context-dependent parameter default" {
    try expectSemanticError(
        "func invalid(value:int = false) {} func main() {}",
        "default for parameter 'value' expects 'int', found 'bool'",
    );
    try expectSemanticError(
        "func invalid(value:int = caller_local) {} func main() { let caller_local = 1; invalid() }",
        "unknown variable 'caller_local'",
    );
    try expectSemanticError(
        "func recursive(value:int = recursive()) int { return value } func main() {}",
        "default parameter expansion is recursive",
    );
}

test "associate named callable arguments in declaration order" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\func combine(first:int = 1, second:int = 2, third:int = 3) int { return first + second + third }
        \\struct Box {
        \\    var value:int
        \\    init(value:int, scale:int = 2) { self.value = value * scale }
        \\    func add(left:int, right:int = 1) int { return self.value + left + right }
        \\}
        \\func main() {
        \\    print(combine(third:30, first:10))
        \\    print(combine(10, third:30))
        \\    print(Box(scale:3, value:4).add(right:2, left:1))
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    const result = try @import("../Interpreter.zig").runCapture(allocator, program);
    try std.testing.expectEqualStrings("42\n42\n15\n", result.stdout);
    const text = try Ir.writeText(allocator, program);
    try std.testing.expect(std.mem.indexOf(u8, text, "call @combine(") != null);
}

test "diagnose invalid named callable arguments and overload labels" {
    try expectSemanticError(
        "func compute(value:int) {} func main() { compute(other:2) }",
        "unknown parameter label 'other'",
    );
    try expectSemanticError(
        "func compute(value:int) {} func main() { compute(1, value:2) }",
        "parameter 'value' is provided more than once",
    );
    try expectSemanticError(
        "func compute(value:int) {} func main() { compute(value:1, value:2) }",
        "parameter 'value' is provided more than once",
    );
    try expectSemanticError(
        "func compute(value:int, other:int) {} func main() { compute(value:1) }",
        "required parameter 'other' is missing",
    );
    try expectSemanticError(
        "func choose(value:int) {} func choose(enabled:bool) {} func main() {}",
        "overloads of function 'choose' must use the same parameter labels",
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(), "func compute(first:int, second:int) {} func main() { compute(first:1, 2) }");
    try std.testing.expectError(error.InvalidSource, parser.parse());
    try std.testing.expectEqualStrings("a positional argument cannot follow a named argument", parser.diagnostic.?.message);
}

test "allow distinct overload labels when accepted arities are disjoint" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\struct Vector {
        \\    init(value:int) {}
        \\    init(x:int, y:int, z:int) {}
        \\}
        \\func select(value:int) {}
        \\func select(x:int, y:int, z:int) {}
        \\func main() {
        \\    Vector(1)
        \\    Vector(z:3, y:2, x:1)
        \\    select(1)
        \\    select(1, 2, 3)
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    _ = try analyzer.analyze(try parser.parse());
}

test "report fundamental type and return errors" {
    try expectSemanticError(
        "func value() int { return true + 1 } func main() {}",
        "operator '+' does not accept 'bool' and 'int'",
    );
    try expectSemanticError(
        "func main() { let ready:bool = 1 }",
        "variable 'ready' expects 'bool', found 'int'",
    );
    try expectSemanticError(
        "func value() int { return 9223372036854775808 } func main() {}",
        "integer literal is outside the range of 'int'",
    );
    try expectSemanticError(
        "func value() int {} func main() {}",
        "function 'value' must return 'int' on every path",
    );
    try expectSemanticError(
        "func value() int { return } func main() {}",
        "expected return value of type 'int'",
    );
    try expectSemanticError(
        "func value() int { return false } func main() {}",
        "return expects 'int', found 'bool'",
    );
    try expectSemanticError("func main() { return 1 }", "a void function cannot return a value");
    try expectSemanticError("func main() { assert(1, \"message\") }", "assert condition expects 'bool'");
    try expectSemanticError("func main() { assert(true, 1) }", "assert message expects 'str'");
    try expectSemanticError("func main() { panic(false) }", "panic message expects 'str'");
    try expectSemanticError("func main() { print(\"a\" < \"b\") }", "operator '<' does not accept 'str' and 'str'");
    try expectSemanticError("func main() { print(\"a\" + 1) }", "operator '+' does not accept 'str' and 'int'");
    try expectSemanticError(
        "func main() { let value:int = 1; print(value.count()) }",
        "count() expects 'str'",
    );
}

test "numeric aliases domains widening and overload ambiguity" {
    try expectSemanticError(
        "func main() { let value:uint8 = 256 }",
        "integer literal is outside the range of 'uint8'",
    );
    try expectSemanticError(
        "func main() { let signed:int8 = 1; let unsigned:uint8 = 1; print(signed + unsigned) }",
        "operator '+' does not accept 'int8' and 'uint8'",
    );
    try expectSemanticError(
        "func choose(value:int16) int { return 1 } func choose(value:int32) int { return 2 } func main() { let value:int8 = 1; choose(value) }",
        "call to 'choose' is ambiguous",
    );
    try expectSemanticError(
        "func same(value:int) int { return value } func same(value:int64) int { return value } func main() {}",
        "function 'same' with these parameter types is already declared",
    );
}
