const std = @import("std");
const Ast = @import("../Ast.zig");
const Parser = @import("../Parser.zig").Parser;
const Specializer = @import("Specializer.zig").Specializer;

test "specialize protocol constrained generic functions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\protocol Named { func name() str }
        \\struct User : Named { func name() str { return "Ada" } }
        \\func label<T : Named>(value:T) str { return value.name() }
        \\func main() { print(label<User>(User())) }
    );
    var specializer = Specializer.init(allocator, try parser.parse());
    const program = try specializer.specialize();
    var found = false;
    for (program.functions) |function| {
        if (std.mem.startsWith(u8, function.name, "label<")) found = true;
    }
    try std.testing.expect(found);
}

test "specialize generic types in protocol requirements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\protocol Reader { func read(buffer:&uint8[..]) Result<int,str> }
    );
    var specializer = Specializer.init(allocator, try parser.parse());
    const program = try specializer.specialize();
    try std.testing.expectEqual(@as(usize, 1), program.protocols.len);
    try std.testing.expect(program.protocols[0].requirements[0].return_type == .structure);
    try std.testing.expect(std.mem.startsWith(
        u8,
        program.protocols[0].requirements[0].return_type.structure,
        "Result<int, str>",
    ));
}

test "reject a type argument without declared protocol conformance" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\protocol Named { func name() str }
        \\struct User { func name() str { return "Ada" } }
        \\func label<T : Named>(value:T) str { return value.name() }
        \\func main() { print(label<User>(User())) }
    );
    var specializer = Specializer.init(allocator, try parser.parse());
    try std.testing.expectError(error.InvalidSource, specializer.specialize());
    try std.testing.expectEqualStrings(
        "type argument 'User' does not conform to protocol 'Named' required by 'T'",
        specializer.diagnostic.?.message,
    );
}

test "accept inherited protocol conformance for a type argument" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\protocol Named { func name() str }
        \\class Entity : Named { public func name() str { return "entity" } }
        \\class Player : Entity {}
        \\func label<T : Named>(value:T) str { return value.name() }
        \\func main() { var player = Player(); print(label<Player>(player)) }
    );
    var specializer = Specializer.init(allocator, try parser.parse());
    _ = try specializer.specialize();
}

test "specialize a constrained generic enum" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\protocol Named { func name() str }
        \\struct User : Named { func name() str { return "Ada" } }
        \\enum Event<T : Named> { value(T) }
        \\func main() { let event = Event<User>.value(User()) }
    );
    var specializer = Specializer.init(allocator, try parser.parse());
    const program = try specializer.specialize();
    try std.testing.expectEqual(@as(usize, 1), program.enums.len);
}

test "specialize generic extension methods and reuse identical calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\struct Catalog {}
        \\extend Catalog {
        \\    func identity<T>(value:T) T { return value }
        \\    func select<Key, Value>(key:Key, value:Value?) Value? { return value }
        \\    func transform<T>(values:T[], callback:func(T) T) T? {
        \\        let first:T = values[0]
        \\        return callback(first)
        \\    }
        \\    func repeat<T>(value:T, count:int) T {
        \\        if count == 0 { return value }
        \\        return self.repeat<T>(value, count - 1)
        \\    }
        \\}
        \\func main() {
        \\    var catalog = Catalog()
        \\    print(catalog.identity<int>(1))
        \\    print(catalog.identity<int>(2))
        \\    print(catalog.identity<str>("ok"))
        \\    let selected = catalog.select<int, str>(1, "value")
        \\    let transformed = catalog.transform<int>([1], func(value:int) int { return value })
        \\    print(catalog.repeat<int>(3, 1))
        \\}
    );
    var specializer = Specializer.init(allocator, try parser.parse());
    const program = try specializer.specialize();
    try std.testing.expectEqual(@as(usize, 5), program.structures[0].methods.len);
    try std.testing.expectEqualStrings("identity<int>", program.structures[0].methods[0].name);
    try std.testing.expectEqualStrings("identity<str>", program.structures[0].methods[1].name);
    try std.testing.expectEqualStrings("select<int, str>", program.structures[0].methods[2].name);
    try std.testing.expectEqualStrings("transform<int>", program.structures[0].methods[3].name);
    try std.testing.expectEqualStrings("repeat<int>", program.structures[0].methods[4].name);
}

test "specialize generic methods declared in structures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\struct Catalog {
        \\    let name:str
        \\    func entry<T>(value:T) T {
        \\        print(self.name)
        \\        return value
        \\    }
        \\}
        \\func main() {
        \\    var catalog = Catalog(name:"primary")
        \\    print(catalog.entry<int>(1))
        \\    print(catalog.entry<int>(2))
        \\    print(catalog.entry<str>("ok"))
        \\}
    );
    var specializer = Specializer.init(allocator, try parser.parse());
    const program = try specializer.specialize();
    try std.testing.expectEqual(@as(usize, 2), program.structures[0].methods.len);
    try std.testing.expectEqualStrings("entry<int>", program.structures[0].methods[0].name);
    try std.testing.expectEqualStrings("entry<str>", program.structures[0].methods[1].name);
    try std.testing.expect(program.structures[0].methods[0].extension_visible_files == null);
}

test "specialize generic methods declared in classes and class extensions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\protocol Named { func name() str }
        \\struct User : Named { func name() str { return "Ada" } }
        \\class Catalog {
        \\    public func identity<T>(value:T) T { return value }
        \\}
        \\extend Catalog {
        \\    public func label<T:Named>(value:T) str { return value.name() }
        \\}
        \\func main() {
        \\    var catalog = Catalog()
        \\    print(catalog.identity(1))
        \\    print(catalog.identity<str>("class"))
        \\    print(catalog.label(User()))
        \\    print(catalog.label<User>(User()))
        \\}
    );
    var parsed = try parser.parse();
    const structures = try allocator.dupe(Ast.Structure, parsed.structures);
    var merged_methods: std.ArrayList(Ast.Function) = .empty;
    try merged_methods.appendSlice(allocator, structures[1].methods);
    try merged_methods.appendSlice(allocator, parsed.extensions[0].methods);
    structures[1].methods = try merged_methods.toOwnedSlice(allocator);
    parsed.structures = structures;
    var specializer = Specializer.init(allocator, parsed);
    const program = try specializer.specialize();
    try std.testing.expect(program.structures[1].is_class);
    try std.testing.expectEqual(@as(usize, 3), program.structures[1].methods.len);
    try std.testing.expectEqualStrings("identity<int>", program.structures[1].methods[0].name);
    try std.testing.expectEqualStrings("identity<str>", program.structures[1].methods[1].name);
    try std.testing.expectEqualStrings("label<User>", program.structures[1].methods[2].name);
    try std.testing.expect(program.structures[1].methods[2].is_public);
}

test "specialize inherited generic class methods from a descendant" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\class Base {
        \\    public func identity<T>(value:T) T { return value }
        \\}
        \\class Child : Base {}
        \\func main() {
        \\    var child = Child()
        \\    print(child.identity(1))
        \\    print(child.identity<str>("inherited"))
        \\}
    );
    var specializer = Specializer.init(allocator, try parser.parse());
    const program = try specializer.specialize();
    try std.testing.expectEqual(@as(usize, 2), program.structures[0].methods.len);
    try std.testing.expectEqualStrings("identity<int>", program.structures[0].methods[0].name);
    try std.testing.expectEqualStrings("identity<str>", program.structures[0].methods[1].name);
    try std.testing.expectEqual(@as(usize, 0), program.structures[1].methods.len);
}

test "infer generic function and method arguments from static argument types" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\struct Catalog {
        \\    func identity<T>(value:T) T { return value }
        \\}
        \\extend Catalog { func first<T>(values:T[]) T { return values[0] } }
        \\func identity<T>(value:T) T { return value }
        \\func transformed<T>(value:T, callback:func(T) T) T { return callback(value) }
        \\func main() {
        \\    var local = 1
        \\    print(identity(local))
        \\    print(identity<int>(2))
        \\    print(transformed(3, func(value:int) int { return value }))
        \\    var catalog = Catalog()
        \\    print(catalog.identity("method"))
        \\    var values = [5, 6]
        \\    print(catalog.first(values))
        \\}
    );
    var specializer = Specializer.init(allocator, try parser.parse());
    const program = try specializer.specialize();
    var inferred_function = false;
    var explicit_function = false;
    for (program.functions) |function| {
        if (std.mem.eql(u8, function.name, "identity<int>")) {
            if (inferred_function) explicit_function = true else inferred_function = true;
        }
    }
    try std.testing.expect(inferred_function);
    try std.testing.expect(!explicit_function);
    try std.testing.expectEqual(@as(usize, 2), program.structures[0].methods.len);
    try std.testing.expectEqualStrings("identity<str>", program.structures[0].methods[0].name);
    try std.testing.expectEqualStrings("first<int>", program.structures[0].methods[1].name);
}

test "generic inference diagnoses missing conflicting and constrained arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var missing_parser = Parser.init(allocator,
        \\func create<T>() int { return 1 }
        \\func main() { print(create()) }
    );
    var missing = Specializer.init(allocator, try missing_parser.parse());
    try std.testing.expectError(error.InvalidSource, missing.specialize());
    try std.testing.expectEqualStrings(
        "generic function 'create' cannot infer all type arguments; use explicit '<...>'",
        missing.diagnostic.?.message,
    );

    var conflict_parser = Parser.init(allocator,
        \\func same<T>(first:T, second:T) T { return first }
        \\func main() { print(same(1, "two")) }
    );
    var conflict = Specializer.init(allocator, try conflict_parser.parse());
    try std.testing.expectError(error.InvalidSource, conflict.specialize());
    try std.testing.expectEqualStrings(
        "generic function 'same' cannot infer all type arguments; use explicit '<...>'",
        conflict.diagnostic.?.message,
    );

    var constraint_parser = Parser.init(allocator,
        \\protocol Named { func name() str }
        \\struct Value {}
        \\func label<T:Named>(value:T) str { return value.name() }
        \\func main() { print(label(Value())) }
    );
    var constraint = Specializer.init(allocator, try constraint_parser.parse());
    try std.testing.expectError(error.InvalidSource, constraint.specialize());
    try std.testing.expectEqualStrings(
        "type argument 'Value' does not conform to protocol 'Named' required by 'T'",
        constraint.diagnostic.?.message,
    );
}

test "generic inference gives compatible concrete overloads priority" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\func select(value:int) int { return value }
        \\func select<T>(value:T) T { return value }
        \\func main() {
        \\    print(select(1))
        \\    print(select("generic"))
        \\}
    );
    var specializer = Specializer.init(allocator, try parser.parse());
    const program = try specializer.specialize();
    var generic_count: usize = 0;
    for (program.functions) |function| {
        if (std.mem.eql(u8, function.name, "select<str>")) generic_count += 1;
        try std.testing.expect(!std.mem.eql(u8, function.name, "select<int>"));
    }
    try std.testing.expectEqual(@as(usize, 1), generic_count);
}

test "diagnose generic extension method arguments and constraints" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var missing_parser = Parser.init(allocator,
        \\struct Box {}
        \\extend Box { func create<T>() int { return 1 } }
        \\func main() { var box = Box(); print(box.create()) }
    );
    var missing = Specializer.init(allocator, try missing_parser.parse());
    try std.testing.expectError(error.InvalidSource, missing.specialize());
    try std.testing.expectEqualStrings(
        "generic method 'create' cannot infer all type arguments; use explicit '<...>'",
        missing.diagnostic.?.message,
    );

    var arity_parser = Parser.init(allocator,
        \\struct Box {}
        \\extend Box { func identity<T>(value:T) T { return value } }
        \\func main() { var box = Box(); print(box.identity<int, str>(1)) }
    );
    var arity = Specializer.init(allocator, try arity_parser.parse());
    try std.testing.expectError(error.InvalidSource, arity.specialize());
    try std.testing.expectEqualStrings("generic method 'identity' expects 1 type argument, found 2", arity.diagnostic.?.message);

    var constraint_parser = Parser.init(allocator,
        \\protocol Named { func name() str }
        \\struct Box {}
        \\struct Value {}
        \\extend Box { func label<T:Named>(value:T) str { return value.name() } }
        \\func main() { var box = Box(); print(box.label<Value>(Value())) }
    );
    var constraint = Specializer.init(allocator, try constraint_parser.parse());
    try std.testing.expectError(error.InvalidSource, constraint.specialize());
    try std.testing.expectEqualStrings(
        "type argument 'Value' does not conform to protocol 'Named' required by 'T'",
        constraint.diagnostic.?.message,
    );

    var concrete_parser = Parser.init(allocator,
        \\struct Box { func identity(value:int) int { return value } }
        \\extend Box { func identity<T>(value:T) T { return value } }
        \\func main() { var box = Box(); print(box.identity(1)) }
    );
    var concrete = Specializer.init(allocator, try concrete_parser.parse());
    const concrete_program = try concrete.specialize();
    try std.testing.expectEqual(@as(usize, 1), concrete_program.structures[0].methods.len);

    var expansion_parser = Parser.init(allocator,
        \\struct Box {}
        \\extend Box {
        \\    func expand<T>(value:T) { self.expand<T[]>([value]) }
        \\}
        \\func main() { var box = Box(); box.expand<int>(1) }
    );
    var expansion = Specializer.init(allocator, try expansion_parser.parse());
    try std.testing.expectError(error.InvalidSource, expansion.specialize());
    try std.testing.expectEqualStrings(
        "generic method 'expand' recursively expands with different type arguments",
        expansion.diagnostic.?.message,
    );
}
