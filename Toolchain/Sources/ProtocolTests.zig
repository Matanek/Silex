const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Project = @import("Project.zig");
const Ir = @import("Ir.zig");

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

test "validate nominal protocol conformances independently of use" {
    const output = try run(
        \\protocol Named { func name(prefix:@str) str }
        \\protocol Resettable { func reset(value:&int) }
        \\struct Item : Named, Resettable {
        \\    func name(prefix:@str) str { return "item" }
        \\    func reset(value:&int) {}
        \\}
        \\struct Unlisted { func name(prefix:@str) str { return "structural only" } }
        \\func main() { print("valid") }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("valid\n", output);
}

test "classes conform with or without a base and inherit conformances" {
    const output = try run(
        \\protocol Drawable { func draw() str }
        \\protocol Named { func name() str }
        \\protocol AlsoNamed { func name() str }
        \\class Entity : Named {
        \\    func name() str { return "entity" }
        \\}
        \\class Player : Entity, Drawable, AlsoNamed {
        \\    func draw() str { return "player" }
        \\}
        \\class Icon : Drawable {
        \\    func draw() str { return "icon" }
        \\}
        \\func main() { var player = Player(); var icon = Icon(); print(player.name(), " ", icon.draw()) }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("entity icon\n", output);
}

test "dynamic protocol values copy structures and preserve class identity" {
    const output = try run(
        \\protocol Counter { func advance() int }
        \\struct Step : Counter {
        \\    var value:int
        \\    func advance() int { self.value += 1; return self.value }
        \\}
        \\class Shared : Counter {
        \\    var value:int = 10
        \\    func advance() int { self.value += 1; return self.value }
        \\}
        \\func main() {
        \\    let source = Step(value:1)
        \\    var erased:Counter = source
        \\    print(erased.advance(), " ", source.value)
        \\    var shared = Shared()
        \\    erased = shared
        \\    print(erased.advance(), " ", shared.value)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("2 1\n11 11\n", output);
}

test "transport dynamic protocol values through language containers" {
    const output = try run(
        \\protocol Readable { func read() int }
        \\struct Number : Readable { let value:int; func read() int { return self.value } }
        \\struct Holder { var value:Readable }
        \\func relay(value:Readable) Readable { return value }
        \\func main() {
        \\    var direct:Readable = Number(value:4)
        \\    var holder = Holder(value:direct)
        \\    var optional:Readable? = Number(value:5)
        \\    let values:Readable[] = [Number(value:6), Number(value:7)]
        \\    var returned = relay(holder.value)
        \\    if var present = optional { print(returned.read(), " ", present.read()) }
        \\    var selected:Readable = values[1]
        \\    print(selected.read())
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("4 5\n7\n", output);
}

test "call a void protocol requirement while its dynamic collection is empty" {
    const output = try run(
        \\protocol Job { func execute() }
        \\func execute_all(jobs:Job[]) {
        \\    var pending = jobs
        \\    for var job in pending { job.execute() }
        \\}
        \\func main() { execute_all([]); print("empty") }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("empty\n", output);
}

test "dynamic protocol values expose only requirements and require mutable storage" {
    try expectCompileError(
        "protocol Readable { func read() int } struct Number : Readable { func read() int { return 1 } func hidden() {} } func main() { var value:Readable = Number(); value.hidden() }",
        "structure 'Readable' has no method named 'hidden' accepting 0 arguments",
    );
    try expectCompileError(
        "protocol Readable { func read() int } struct Number : Readable { func read() int { return 1 } } func main() { let value:Readable = Number(); value.read() }",
        "a binding that can reach a class reference must use 'var'",
    );
    try expectCompileError(
        "protocol Readable { func read() int } struct Number : Readable { func read() int { return 1 } } func inspect(value:@Readable) {} func main() {}",
        "dynamic protocol values cannot use '@' or '&'",
    );
}

test "dynamic protocol values copy structures with drop" {
    const output = try run(
        \\protocol Readable { func read() int }
        \\struct Item : Readable {
        \\    let value:int
        \\    func read() int { return self.value }
        \\    drop { print("drop ", self.value) }
        \\}
        \\func main() {
        \\    var first:Readable = Item(value:3)
        \\    var second = first
        \\    print(first.read(), " ", second.read())
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("3 3\ndrop 3\ndrop 3\n", output);
}

test "dynamic protocol values retain one shared class identity until final drop" {
    const output = try run(
        \\protocol Live { func touch() }
        \\class Resource : Live {
        \\    func touch() { print("alive") }
        \\    drop { print("drop") }
        \\}
        \\func main() {
        \\    var resource = Resource()
        \\    var erased:Live = resource
        \\    erased.touch()
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("alive\ndrop\n", output);
}

test "protocol erasure has deterministic explicit portable IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        "protocol Readable { func read() int } struct Number : Readable { func read() int { return 4 } } func main() { var value:Readable = Number(); print(value.read()) }",
    );
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "protocol.init @Readable") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "protocol.test") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "protocol.extract") != null);
}

test "compose dynamic protocol values across module boundaries" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data =
        \\use Api
        \\use Model
        \\func main() { var value:Api.Readable = Model.Number(value:9); print(value.read()) }
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public protocol Readable { func read() int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Model.sx",
        .data = "use Api; public struct Number : Api.Readable { let value:int; func read() int { return self.value } }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("9\n", result.stdout);
}

test "public protocol contract does not republish a package implementation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Library/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"Library\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Package.json",
        .data = "{\"name\":\"Library\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Module/Api.sx",
        .data =
        \\public protocol Named { func name() str }
        \\package class Concrete : Named { func name() str { return "package" } }
        \\public func make() Named { return Concrete() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Library.Api\nfunc main() { var value:Api.Named = Api.make(); print(value.name()) }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("package\n", result.stdout);
}

test "generic protocol calls use the contract without republishing a consumer implementation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Library/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"Library\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Package.json",
        .data = "{\"name\":\"Library\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Module/Jobs.sx",
        .data =
        \\public protocol Job { func execute() }
        \\public func run<T:Job>(job:T) { job.execute() }
        \\public class Runner { init() {} func run<T:Job>(job:T) { job.execute() } }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Library.Jobs
        \\class Task : Jobs.Job { func execute() { print("done") } }
        \\func main() { Jobs.run(Task()); Jobs.Runner().run(Task()) }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("done\ndone\n", result.stdout);
}

test "diagnose missing and mismatched protocol requirements" {
    try expectCompileError(
        "protocol Drawable { func draw() } struct Sprite : Drawable {} func main() {}",
        "type 'Sprite' does not implement protocol requirement 'Drawable.draw'",
    );
    try expectCompileError(
        "protocol Named { func name(value:@int) str } struct Item : Named { func name(value:&int) str { return \"x\" } } func main() {}",
        "type 'Item' does not implement protocol requirement 'Named.name'",
    );
}

test "reject unsupported protocol declaration forms and dynamic values" {
    try expectCompileError(
        "protocol Value<T> {} func main() {}",
        "generic protocols are not supported",
    );
    try expectCompileError(
        "protocol Child : Parent {} func main() {}",
        "protocol inheritance is not supported",
    );
    try expectCompileError(
        "protocol Factory { func make<T>() } func main() {}",
        "generic protocol methods are not supported",
    );
    try expectCompileError(
        "protocol Drawable { func draw(amount:int=1) {} } func main() {}",
        "protocol requirements cannot declare parameter defaults",
    );
    try expectCompileError(
        "protocol Drawable { func draw() } func main() { let value:Drawable }",
        "a dynamic protocol value requires an initializer",
    );
}

test "compose protocol aliases reexports and dependent conformances" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Types
        \\func main() { let sprite = Types.Sprite(); print(sprite.draw()) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public protocol Drawable { func draw() str }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Facade.sx",
        .data = "public use Api.Drawable as Shape",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Types.sx",
        .data =
        \\use Facade.Shape as Drawable
        \\public struct Sprite : Drawable { func draw() str { return "sprite" } }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("sprite\n", result.stdout);
}

test "generic constraints specialize requirements for every supported family" {
    const output = try run(
        \\protocol Describable { func describe() str }
        \\struct User : Describable { func describe() str { return "user" } }
        \\class Entity : Describable { func describe() str { return "entity" } }
        \\class Child : Entity {}
        \\func describe<T : Describable>(value:T) str { return value.describe() }
        \\struct Wrapper<T : Describable> {
        \\    let value:T
        \\    func text() str { return self.value.describe() }
        \\}
        \\enum Choice<T : Describable> { some(T); none }
        \\class Box<T : Describable> {
        \\    let value:T
        \\    init(value:T) { self.value = value }
        \\    func text() str { return self.value.describe() }
        \\}
        \\struct Helper { func text<T : Describable>(value:T) str { return value.describe() } }
        \\func choice_text(value:Choice<User>) str {
        \\    return match value { some(item) => item.describe(); none => "none" }
        \\}
        \\func main() {
        \\    let user = User()
        \\    var child = Child()
        \\    var box = Box<User>(user)
        \\    print(describe(user), " ", describe<Child>(child))
        \\    print(Wrapper<User>(value:user).text(), " ", box.text())
        \\    print(Helper().text(user), " ", choice_text(Choice<User>.some(user)))
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("user entity\nuser user\nuser user\n", output);
}

test "generic constraints reject absent conformance and non-protocol contracts" {
    try expectCompileError(
        "struct Marker {} func read<T : Marker>(value:T) {} func main() {}",
        "generic constraint on 'T' must name a protocol",
    );
    try expectCompileError(
        "protocol Named { func name() str } struct Rock {} func read<T : Named>(value:T) {} func main() { read(Rock()) }",
        "type 'Rock' does not conform to protocol 'Named' required by 'T'",
    );
    try expectCompileError(
        "protocol Named { func name() str } struct Rock {} struct Box<T : Named> { let value:T } func main() { let box = Box<Rock>(value:Rock()) }",
        "type 'Rock' does not conform to protocol 'Named' required by 'T'",
    );
}

test "compose a constrained generic through a protocol reexport" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Model
        \\use Render
        \\func main() { print(Render.label(Model.Item())) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public protocol Named { func name() str }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Facade.sx",
        .data = "public use Api.Named as Named",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Model.sx",
        .data = "use Facade.Named; public struct Item : Named { func name() str { return \"item\" } }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Render.sx",
        .data = "use Facade.Named; public func label<T : Named>(value:T) str { return value.name() }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    var found_constraint = false;
    for (compilation.interfaces) |interface| {
        if (!std.mem.eql(u8, interface.name, "Render")) continue;
        for (interface.functions) |function| if (std.mem.eql(u8, function.export_name, "label")) {
            try std.testing.expectEqual(@as(usize, 1), function.type_parameter_constraints.len);
            try std.testing.expect(function.type_parameter_constraints[0] != null);
            found_constraint = true;
        };
    }
    try std.testing.expect(found_constraint);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("item\n", result.stdout);
}

test "protocol erasure transfers temporary resources through collection mutation" {
    const output = try run(
        \\class Item { drop { print("item dropped") } }
        \\protocol Value { func consume() }
        \\struct Box:Value {
        \\    private var value:Item?
        \\    init(value:Item) { self.value = value }
        \\    func consume() {
        \\        var value = self.value
        \\        self.value = null
        \\        if var present = value { print("consumed") }
        \\    }
        \\}
        \\class Bag {
        \\    private var values:Value[]
        \\    init() { self.values = [] }
        \\    func add(value:Item) { self.values.append(Box(value)) }
        \\    func take() Value[] {
        \\        var values = self.values
        \\        self.values = []
        \\        return values
        \\    }
        \\}
        \\func main() {
        \\    var bag = Bag()
        \\    bag.add(Item())
        \\    var values = bag.take()
        \\    for var value in values { value.consume() }
        \\    print("done")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("consumed\nitem dropped\ndone\n", output);
}

test "recursive protocol values retain and release finite nested payloads" {
    const output = try run(
        \\protocol Tree { func count() int }
        \\class Token {
        \\    static var destroyed:int = 0
        \\    drop { Token.destroyed++ }
        \\}
        \\struct Leaf:Tree {
        \\    var token:Token
        \\    let label:str
        \\    func count() int { return 1 }
        \\}
        \\struct Branch:Tree {
        \\    var children:Tree[]
        \\    func count() int {
        \\        var total = 0
        \\        for child in self.children { var value = child; total += value.count() }
        \\        return total
        \\    }
        \\}
        \\enum Choice { absent; present(Tree) }
        \\class Wrapped:Tree {
        \\    var choice:Choice
        \\    func count() int {
        \\        match self.choice {
        \\            absent => { return 0 }
        \\            present(child) => { var value = child; return value.count() }
        \\        }
        \\    }
        \\}
        \\class Optional:Tree {
        \\    var child:Tree?
        \\    func count() int {
        \\        if var child = self.child { return child.count() }
        \\        return 0
        \\    }
        \\}
        \\func relay(tree:Tree) Tree { return tree }
        \\func main() {
        \\    {
        \\        var tree:Tree = Branch(children:[
        \\            Leaf(token:Token(), label:"a"),
        \\            Optional(child:Wrapped(choice:Choice.present(Branch(children:[Leaf(token:Token(), label:"b")])))),
        \\            Optional(child:null), Wrapped(choice:Choice.absent)
        \\        ])
        \\        var copied = relay(tree)
        \\        assert(tree.count() == 2 && copied.count() == 2)
        \\        assert(Token.destroyed == 0)
        \\    }
        \\    assert(Token.destroyed == 2)
        \\    print("recursive ownership ok")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("recursive ownership ok\n", output);
}

test "mutually recursive protocol resource helpers preserve payload dispatch" {
    const output = try run(
        \\protocol First { func read() int }
        \\protocol Second { func read() int }
        \\struct Number:First { let value:int; func read() int { return self.value } }
        \\struct Forward:Second { var children:First[]; func read() int { var child = self.children[0]; return child.read() } }
        \\struct Back:First { var children:Second[]; func read() int { var child = self.children[0]; return child.read() } }
        \\func main() {
        \\    var value:First = Back(children:[Forward(children:[Number(value:42)])])
        \\    var copied = value
        \\    print(value.read(), " ", copied.read())
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("42 42\n", output);
}

test "reject unbounded inline recursive protocol payloads before native lowering" {
    try expectCompileError(
        "protocol Item { func count() int } struct Wrapped:Item { var child:Item?; func count() int { return 0 } } func main() {}",
        "recursive protocol values must cross a class or dynamic-array field",
    );
}

test "protocol getters read constructor parameters and borrowed collection elements without writeback" {
    const output = try run(
        \\protocol Named { name:str { get } }
        \\struct Item:Named { let name:str }
        \\class Computed:Named { let name:str { get { return "computed" } } }
        \\class Wrapper {
        \\    let name:str
        \\    init(source:Named) { self.name = source.name }
        \\}
        \\func main() {
        \\    var source:Named = Item(name:"item")
        \\    var wrapper = Wrapper(source)
        \\    print(wrapper.name)
        \\    var values:Named[] = [source, Computed()]
        \\    for value in values { print(value.name) }
        \\    print(Wrapper(Computed()).name)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("item\nitem\ncomputed\ncomputed\n", output);
}

test "mutable iteration updates collection fields rather than a copied snapshot" {
    const output = try run(
        \\struct Owner {
        \\    var values:int[]
        \\    func update() {
        \\        for index, var value in self.values.indexed() {
        \\            value += index + 1
        \\            if index == 0 { continue }
        \\            if index == 1 { break }
        \\        }
        \\    }
        \\}
        \\func main() {
        \\    var owner = Owner(values:[1, 2, 3])
        \\    let snapshot = owner.values
        \\    owner.update(); owner.update()
        \\    print(owner.values[0], " ", owner.values[1], " ", owner.values[2])
        \\    print(snapshot[0], " ", snapshot[1], " ", snapshot[2])
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("3 6 3\n1 2 3\n", output);
    try expectCompileError(
        "struct Owner { let values:int[]; func update() { for var value in self.values { value++ } } } func main() {}",
        "field 'values' is immutable and cannot be borrowed as '&'",
    );
}

test "protocol class receivers preserve reentrant replacement in mixed conformances" {
    const output = try run(
        \\protocol Action { func invoke(callback:func()) int; func read() int }
        \\class Item:Action { var amount:int; func invoke(callback:func()) int { callback(); return self.amount } func read() int { return self.amount } }
        \\struct Value:Action { var amount:int; func invoke(callback:func()) int { self.amount++; callback(); return self.amount } func read() int { return self.amount } }
        \\class Holder {
        \\    var item:Action; var next:Action
        \\    func replace() { self.item = self.next }
        \\    func call() int { return self.item.invoke(self.replace) }
        \\    func read() int { return self.item.read() }
        \\}
        \\func main() {
        \\    var first = Item(amount:17); var next = Item(amount:29)
        \\    var holder = Holder(item:first, next:next)
        \\    assert(holder.call() == 17 && holder.read() == 29)
        \\    var value = Holder(item:Value(amount:5), next:Value(amount:20))
        \\    assert(value.call() == 6 && value.read() == 6)
        \\    print("mixed receivers ok")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("mixed receivers ok\n", output);
}

test "protocol class receivers omit unchanged field stores in typed IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const program = (try frontend.compile(
        \\protocol Readable { func read() int }
        \\class Item:Readable { func read() int { return 7 } }
        \\class Holder { var item:Readable; func read() int { return self.item.read() } }
        \\func main() { var holder = Holder(item:Item()); assert(holder.read() == 7) }
    )).ir;
    var found = false;
    for (program.functions) |function| {
        if (!std.mem.startsWith(u8, function.name, "Holder.read#")) continue;
        found = true;
        for (function.blocks) |block| for (block.instructions) |instruction| {
            try std.testing.expect(instruction != .field_store);
        };
    }
    try std.testing.expect(found);
}

test "protocol class receivers do not drop value conformers during an internal hold" {
    const output = try run(
        \\protocol Readable { func read() int }
        \\class Item:Readable { func read() int { return 9 } }
        \\struct Value:Readable {
        \\    static var drops:int = 0
        \\    var amount:int
        \\    func read() int { return self.amount }
        \\    drop { Value.drops++ }
        \\}
        \\func main() {
        \\    var value:Readable = Value(amount:7)
        \\    let before = Value.drops
        \\    assert(value.read() == 7 && value.read() == 7)
        \\    assert(Value.drops == before)
        \\    var item:Readable = Item(); assert(item.read() == 9)
        \\    print("value drops ok")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("value drops ok\n", output);
}

test "protocol class receivers preserve optional replacement through safe dispatch" {
    const output = try run(
        \\protocol Action { func invoke(callback:func()) int }
        \\class Item:Action { func invoke(callback:func()) int { callback(); return 17 } }
        \\class Holder {
        \\    var item:Action?
        \\    func clear() { self.item = null }
        \\    func call() int? { return self.item?.invoke(self.clear) }
        \\}
        \\func main() {
        \\    var holder = Holder(item:Item())
        \\    assert(holder.call() == 17 && holder.item == null)
        \\    assert(holder.call() == null)
        \\    print("optional receivers ok")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("optional receivers ok\n", output);
}

test "generic protocol calls honor hidden conformers without exposing other members" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Library/Module");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package.json", .data = "{\"sources\":\".\",\"dependencies\":{\"Library\":\"=1.0.0\"}}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Library/Package.json", .data = "{\"name\":\"Library\",\"version\":\"1.0.0\"}" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Module/Jobs.sx",
        .data =
        \\public protocol Job { func execute(amount:int) int }
        \\public func run<T:Job>(job:T) int { return job.execute(2) }
        \\public func named<T:Job>(job:T) int { return job.execute(amount:5) }
        \\public class Runner { init() {} func run<T:Job>(job:T) int { return job.execute(4) } }
        \\public struct Holder<T:Job> { var job:T; func run() int { return self.job.execute(3) } }
        \\public func helper<T:Job>(job:T) int { return job.secret() }
        \\public func overload<T:Job>(job:T) int { return job.execute("secret") }
        \\public func field<T:Job>(job:T) int { return job.value }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    const body =
        \\    var value:int = 40
        \\    func execute(amount:int) int { return self.value + amount }
        \\    func execute(amount:str) int { return 99 }
        \\    func secret() int { return self.value }
    ;
    for ([_][]const u8{ "class", "package class", "local class", "package struct", "local struct" }) |kind| {
        const source = try std.fmt.allocPrint(allocator, "use Library.Jobs\n{s} Task:Jobs.Job {{\n{s}\n}}\n" ++
            "func main() {{ print(Jobs.run(Task())); print(Jobs.named(Task())); print(Jobs.Runner().run(Task())); var holder = Jobs.Holder<Task>(job:Task()); print(holder.run()) }}", .{ kind, body });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = source });
        var compiler = Project.Compiler.init(allocator, std.testing.io);
        const compilation = compiler.compile(input) catch |err| {
            std.debug.print("kind={s}: {s}\n", .{ kind, if (compiler.diagnostic) |diagnostic| diagnostic.message else "no diagnostic" });
            return err;
        };
        const result = try Interpreter.runCapture(allocator, compilation.ir);
        try std.testing.expectEqualStrings("42\n45\n44\n43\n", result.stdout);
    }
    for ([_][]const u8{ "helper", "overload", "field" }) |operation| {
        const source = try std.fmt.allocPrint(allocator, "use Library.Jobs\npackage struct Task:Jobs.Job {{\n{s}\n}}\nfunc main() {{ print(Jobs.{s}(Task())) }}", .{ body, operation });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = source });
        var compiler = Project.Compiler.init(allocator, std.testing.io);
        try std.testing.expectError(error.InvalidSource, compiler.compile(input));
        try std.testing.expect(compiler.diagnostic != null);
    }
}
