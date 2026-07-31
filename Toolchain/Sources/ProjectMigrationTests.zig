const std = @import("std");
const Project = @import("Project.zig");

test "compose chained public reexports without changing declaration identity" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Geometry");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Geometry
        \\func main() {
        \\    let vector:Geometry.Vector = Geometry.Vector(20, 22)
        \\    print(Geometry.sum(vector) + Geometry.bump() + Geometry.bump(true))
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Geometry.sx",
        .data =
        \\public use Geometry.Middle.Vector as Vector
        \\public use Geometry.Middle.sum as sum
        \\public use Geometry.Middle.bump as bump
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Geometry/Middle.sx",
        .data =
        \\public use Geometry.Api.Vector as Vector
        \\public use Geometry.Api.sum as sum
        \\public use Geometry.Api.bump as bump
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Geometry/Api.sx",
        .data =
        \\public struct Vector {
        \\    let x:int
        \\    let y:int
        \\    init(x:int, y:int) { self.x = x; self.y = y }
        \\}
        \\public func sum(value:Vector) int { return value.x + value.y }
        \\public func bump(value:int = 0) int { return value }
        \\public func bump(value:bool) int {
        \\    if value { return 100 }
        \\    return 0
        \\}
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("142\n", result.stdout);

    var facade_structure = false;
    var facade_overloads: usize = 0;
    for (compilation.interfaces) |interface| {
        if (!std.mem.eql(u8, interface.name, "Geometry")) continue;
        for (interface.structures) |structure| {
            if (!std.mem.eql(u8, structure.export_name, "Vector")) continue;
            facade_structure = std.mem.eql(u8, structure.id.module, "Geometry.Api") and
                std.mem.eql(u8, structure.id.name, "Vector");
        }
        for (interface.functions) |function| {
            if (std.mem.eql(u8, function.export_name, "bump")) {
                try std.testing.expectEqualStrings("Geometry.Api", function.id.module);
                facade_overloads += 1;
            }
        }
    }
    try std.testing.expect(facade_structure);
    try std.testing.expectEqual(@as(usize, 2), facade_overloads);
}

test "compose public reexports through a package facade" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Geometry/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"Geometry\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Geometry/Package.json",
        .data = "{\"name\":\"Geometry\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Geometry.Facade\nfunc main() { let value:Facade.Integer = Facade.answer(); print(value) }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Geometry/Module/Facade.sx",
        .data = "public use Geometry.Api.answer as answer\npublic use int as Integer",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Geometry/Module/Api.sx",
        .data = "public func answer() int { return 42 }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "prefer a facade reexport over a homonymous principal type static call" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Facade
        \\func main() {
        \\    let settings = Facade.Settings()
        \\        ..title = "Silex"
        \\    print(settings.title)
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Facade.sx",
        .data =
        \\public use Api.Settings as Settings
        \\public struct Facade {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data =
        \\public struct Settings {
        \\    var title:str = "Default"
        \\}
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("Silex\n", result.stdout);
}

test "diagnose invalid public reexports and cycles" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "use Facade\nfunc main() {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Facade.sx", .data = "public use Api.hidden as hidden" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Api.sx", .data = "func hidden() {}" });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "public use cannot expose inaccessible declaration 'hidden'",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Facade.sx", .data = "public use Api as Api" });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("public use can only reexport a declaration", compiler.diagnostic.?.message);

    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Facade.sx", .data = "public use Api.value as value" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Api.sx", .data = "public use Facade.value as value" });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expect(std.mem.startsWith(u8, compiler.diagnostic.?.message, "public use cycle reaches"));
}

test "normalize transparent aliases in types signatures and construction" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use int as Integer
        \\use Integer as Count
        \\use Point as P
        \\public use Count as PublicCount
        \\public struct Point { let x:Count; let y:Integer }
        \\func sum(value:P) PublicCount { return value.x + value.y }
        \\func main() {
        \\    let point:P = P(x:20, y:22)
        \\    let converted:Integer = 42 as Count
        \\    print(sum(point) + converted)
        \\}
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("84\n", result.stdout);
    try std.testing.expectEqual(@as(usize, 1), compilation.interfaces[0].type_aliases.len);
    try std.testing.expectEqualStrings("PublicCount", compilation.interfaces[0].type_aliases[0].name);
    try std.testing.expectEqual(@import("Types.zig").Type.int, compilation.interfaces[0].type_aliases[0].target);
}

test "compose public fundamental aliases and diagnose cycles and signature collisions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Facade.Integer as Number
        \\func identity(value:Number) Number { return value }
        \\func main() { print(identity(42)) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Facade.sx",
        .data = "public use int as Integer",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Second as First\nuse First as Second\nfunc main() {}",
    });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expect(std.mem.startsWith(u8, compiler.diagnostic.?.message, "type alias cycle reaches"));

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use int as Integer
        \\func same(value:Integer) {}
        \\func same(value:int) {}
        \\func main() {}
        ,
    });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "function 'Main.same' with these parameter types is already declared",
        compiler.diagnostic.?.message,
    );
}

test "use local declarations and members inside their source file" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\local func offset() int { return 2 }
        \\local struct Handle {
        \\    local var value:int
        \\    local init(value:int) { self.value = value }
        \\    local func read() int { return self.value }
        \\}
        \\func main() {
        \\    var handle = Handle(40)
        \\    handle.value += 2
        \\    print(handle.read() + offset())
        \\}
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("44\n", result.stdout);
    try std.testing.expectEqual(@as(usize, 0), compilation.interfaces[0].structures.len);
    try std.testing.expectEqual(@as(usize, 0), compilation.interfaces[0].functions.len);
}

test "reject local functions and structures from sibling files and packages" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api.hidden as hidden\nfunc main() { hidden() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "local func hidden() {}\nlocal struct Handle {}",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("function 'Api.hidden' is local to its source file", compiler.diagnostic.?.message);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api.Handle as Handle\nfunc main() { let value:Handle }",
    });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("structure 'Handle' is local to its source file", compiler.diagnostic.?.message);

    try temporary.dir.createDirPath(std.testing.io, "Library/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"Library\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Package.json",
        .data = "{\"name\":\"Library\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Module/Api.sx",
        .data = "local func hidden() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Library.Api.hidden as hidden\nfunc main() { hidden() }",
    });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("function 'Library.Api.hidden' is local to its source file", compiler.diagnostic.?.message);
}

test "share internal declarations across one package without exporting them" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Library/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"Library\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Package.json",
        .data = "{\"name\":\"Library\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Module/Internals.sx",
        .data =
        \\internal struct Token {
        \\    internal var value:int
        \\    internal init(value:int) { self.value = value }
        \\    internal func read() int { return self.value }
        \\}
        \\internal func offset() int { return 2 }
        \\public struct Box {
        \\    internal var hidden:int
        \\    public var value:int
        \\    internal func secret() int { return self.hidden }
        \\}
        \\public func make() Box { return Box(hidden:20, value:22) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Module/Bridge.sx",
        .data =
        \\use Library.Internals
        \\public func answer() int {
        \\    let token = Internals.Token(40)
        \\    let box = Internals.make()
        \\    return token.read() + Internals.offset() + box.secret() - box.hidden
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Library.Bridge\nfunc main() { print(Bridge.answer()) }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Library.Internals.offset as offset\nfunc main() { print(offset()) }",
    });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "function 'Library.Internals.offset' is internal to its package",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Library.Internals\nfunc main() { let box = Internals.make(); print(box.secret()) }",
    });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("method 'secret' is internal to its package", compiler.diagnostic.?.message);
}

test "keep local return values opaque and reject public input leaks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api\nfunc main() { let handle = Api.make(); print(42) }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data =
        \\local struct Handle { var code:int }
        \\public func make() Handle { return Handle(code:42) }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
    for (compilation.interfaces) |interface| {
        if (!std.mem.eql(u8, interface.name, "Api")) continue;
        try std.testing.expectEqual(@as(usize, 0), interface.structures.len);
        try std.testing.expectEqual(@as(usize, 1), interface.functions.len);
    }

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data =
        \\local struct Handle { var code:int }
        \\public func consume(value:Handle) {}
        ,
    });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "public function 'consume' exposes local structure 'Handle'",
        compiler.diagnostic.?.message,
    );
}

test "enforce local fields methods and constructors from other files" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data =
        \\public struct Box {
        \\    local var secret:int
        \\    var value:int
        \\    local init(secret:int, value:int) { self.secret = secret; self.value = value }
        \\    local func hidden() int { return self.secret }
        \\}
        \\public func make() Box { return Box(20, 22) }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api\nfunc main() { let box = Api.make(); print(box.secret) }",
    });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("field 'secret' is local to its source file", compiler.diagnostic.?.message);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api\nfunc main() { let box = Api.make(); print(box.hidden()) }",
    });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("method 'hidden' is local to its source file", compiler.diagnostic.?.message);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api\nfunc main() { let box = Api.Box(20, 22); print(box.value) }",
    });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expect(std.mem.startsWith(u8, compiler.diagnostic.?.message, "constructor of 'Api.Box' is local"));
}
