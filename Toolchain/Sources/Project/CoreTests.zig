const std = @import("std");
const Compiler = @import("../Project.zig").Compiler;
const Types = @import("../Types.zig");

fn writeBoundaryArchive(directory: std.Io.Dir) !void {
    var archive = [_]u8{' '} ** (8 + 60 + 20);
    @memcpy(archive[0..8], "!<arch>\n");
    @memcpy(archive[8..24], "probe.o/        ");
    @memcpy(archive[8 + 48 .. 8 + 58], "20        ");
    @memcpy(archive[8 + 58 .. 8 + 60], "`\n");
    std.mem.writeInt(u32, archive[68..72], std.macho.MH_MAGIC_64, .little);
    std.mem.writeInt(u32, archive[72..76], @bitCast(std.macho.CPU_TYPE_ARM64), .little);
    try directory.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Boundary/macos-arm64/libBridge.a",
        .data = &archive,
    });
}

test "qualify local types used to read static storage" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\struct Test {
        \\    static let count:int = 100
        \\}
        \\class ClassTest {
        \\    static let count:int = 200
        \\}
        \\struct GenericTest<T> {
        \\    static let count:int = 300
        \\}
        \\func main() { print(Test.count, " ", ClassTest.count, " ", GenericTest<int>.count) }
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("100 200 300\n", result.stdout);
}

test "compile only the explicit local module closure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations
        \\func answer() int { return Operations.add(right:22, left:20) }
        \\func main() { answer() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Operations.sx",
        .data = "package func add(left:int, right:int) int { return left + right }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Unused.sx",
        .data = "this source is deliberately invalid",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const Interpreter = @import("../Interpreter.zig");
    const answer = try Interpreter.invoke(allocator, compilation.ir, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqualStrings("Main.answer", compilation.ir.functions[0].name);
    try std.testing.expectEqualStrings("Math.Operations.add", compilation.ir.functions[2].name);
}

test "keep main local to the explicit source file" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Library
        \\func answer() int { return Library.answer() }
        \\func main() { answer() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library.sx",
        .data =
        \\public func answer() int { return 42 }
        \\func main() { missing_function() }
        ,
    });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const input = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const answer = try @import("../Interpreter.zig").invoke(allocator, compilation.ir, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    for (compilation.ir.functions) |function| {
        try std.testing.expect(!std.mem.eql(u8, function.name, "Library.main"));
    }
    for (compilation.interfaces) |interface| for (interface.functions) |function| {
        try std.testing.expect(!std.mem.eql(u8, function.export_name, "main"));
    };

    const library_input = try std.fs.path.join(allocator, &.{ root, "Library.sx" });
    var direct = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, direct.compile(library_input));
    try std.testing.expectEqualStrings("unknown function 'Library.missing_function'", direct.diagnostic.?.message);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library.sx",
        .data =
        \\public func answer() int { return 42 }
        \\public func main() {}
        ,
    });
    var invalid_public = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, invalid_public.compile(input));
    try std.testing.expectEqualStrings("'main' cannot be public", invalid_public.diagnostic.?.message);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library.sx",
        .data = "public func answer() int { return 42 }\nfunc main() {",
    });
    var invalid_syntax = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, invalid_syntax.compile(input));
}

test "report missing modules and duplicate aliases" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Missing
        \\func main() {}
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("unknown module or declaration 'Missing'", compiler.diagnostic.?.message);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "One.sx",
        .data = "func value() int { return 1 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Two.sx",
        .data = "func value() int { return 2 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use One as Same\nuse Two as Same\nfunc main() {}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("use alias 'Same' is already declared", compiler.diagnostic.?.message);
}

test "resolve explicit module aliases direct declarations and grouping namespaces" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations as Ops
        \\use Math.Operations.add as plus
        \\use Math as Group
        \\func byModule() int { return Ops.add(20, 22) }
        \\func byDeclaration() int { return plus(21, 21) }
        \\func byNamespace() int { return Group.Operations.add(40, 2) }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Operations.sx",
        .data = "package func add(left:int, right:int) int { return left + right }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const Interpreter = @import("../Interpreter.zig");
    for (0..3) |function| {
        const answer = try Interpreter.invoke(allocator, compilation.ir, function, &.{});
        try std.testing.expectEqual(@as(i64, 42), answer.integer);
    }
}

test "reject alias collisions and dependency cycles across logical parents" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Group");
    try temporary.dir.createDirPath(std.testing.io, "Other");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Group.A\nfunc main() { A.run() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Group/A.sx",
        .data = "use Other.B\nfunc run() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Other/B.sx",
        .data = "use Group.A\nfunc run() {}",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "module dependency cycle crosses logical parents",
        compiler.diagnostic.?.message,
    );
}

test "allow dependency cycles under one logical parent" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Group");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Group.A\nfunc main() { A.run() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Group/A.sx",
        .data = "use Group.B\npackage func run() { B.touch() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Group/B.sx",
        .data = "use Group.A\npackage func touch() {}",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    _ = try @import("../Interpreter.zig").run(allocator, compilation.ir);
}

test "collect public overloads before analyzing calls across files" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations
        \\func answer() int { return Operations.value(20) + Operations.value(true) }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Operations.sx",
        .data =
        \\public func value(input:int) int { return input }
        \\public func value(input:bool) int { return 22 }
        \\func hidden() int { return 0 }
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const answer = try @import("../Interpreter.zig").invoke(allocator, compilation.ir, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqual(@as(usize, 2), compilation.interfaces.len);
    try std.testing.expectEqual(@as(usize, 2), compilation.interfaces[1].functions.len);
    try std.testing.expect(compilation.interfaces[1].functions[0].id.eql(.{
        .owner = .project,
        .module = "Math.Operations",
        .name = "value",
        .parameter_types = &.{.int},
    }));
}

test "compose public parameter defaults in their declaring module" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations
        \\func answer() int { return Operations.value() + Operations.Box().plus() }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Operations.sx",
        .data =
        \\func seed() int { return 20 }
        \\public func value(input:int = seed()) int { return input }
        \\public struct Box {
        \\    var value:int
        \\    init(value:int = seed()) { self.value = value }
        \\    func plus(amount:int = 2) int { return self.value + amount }
        \\}
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const answer = try @import("../Interpreter.zig").invoke(allocator, compilation.ir, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqual(@as(usize, 0), compilation.interfaces[1].functions[0].required_parameters);
    try std.testing.expectEqualStrings("input", compilation.interfaces[1].functions[0].parameter_names[0]);
    try std.testing.expectEqual(@as(usize, 0), compilation.interfaces[1].structures[0].constructors[0].required_parameters);
    try std.testing.expectEqualStrings("value", compilation.interfaces[1].structures[0].constructors[0].parameter_names[0]);
    try std.testing.expectEqual(@as(usize, 0), compilation.interfaces[1].structures[0].methods[0].required_parameters);
    try std.testing.expectEqualStrings("amount", compilation.interfaces[1].structures[0].methods[0].parameter_names[0]);
}

test "defer generic callback defaults until an omitted argument needs them" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Library");
    try temporary.dir.createDirPath(std.testing.io, "Support");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Library.Box
        \\struct Key { let value:int }
        \\func read_key(value:@Key) int { return value.value }
        \\func answer() int {
        \\    let custom = Box.Holder<Key>(Key(value:35), read_key)
        \\    let defaulted = Box.Holder<int>(7)
        \\    return custom.read() + defaulted.read()
        \\}
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Box.sx",
        .data =
        \\use Support.Callbacks
        \\public struct Holder<T> {
        \\    let value:T
        \\    let callback:func(@T) int
        \\    init(value:T, callback:func(@T) int = Callbacks.read_int) {
        \\        self.value = value
        \\        self.callback = callback
        \\    }
        \\    func read() int { return self.callback(self.value) }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Support/Callbacks.sx",
        .data = "public func read_int(value:@int) int { return value }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    var answer_id: ?usize = null;
    for (compilation.ir.functions, 0..) |function, id| {
        if (std.mem.eql(u8, function.name, "Main.answer")) answer_id = id;
    }
    const answer = try @import("../Interpreter.zig").invoke(
        allocator,
        compilation.ir,
        answer_id orelse return error.TestUnexpectedResult,
        &.{},
    );
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
}

test "do not propagate private module access through a dependency" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Layer");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Layer.A\nfunc main() { B.hidden() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Layer/A.sx",
        .data = "use Layer.B\nfunc touch() { B.hidden() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Layer/B.sx",
        .data = "func hidden() {}",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("function 'Layer.B.hidden' is module-visible and unavailable outside its module", compiler.diagnostic.?.message);
}

test "compose simple modules with an adjacent local package" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Foo");
    try temporary.dir.createDirPath(std.testing.io, "MonPackage/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Foo.Bar
        \\use MonPackage.Class1
        \\func answer() int { return Bar.value() + Class1.value(right:2, left:20) }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Foo/Bar.sx",
        .data = "package func value() int { return 20 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "MonPackage/Package.json",
        .data = "{\"name\":\"MonPackage\",\"version\":\"1.4.1\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "MonPackage/Module/Class1.sx",
        .data = "public func value(left:int, right:int) int { return left + right }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const answer = try @import("../Interpreter.zig").invoke(allocator, compilation.ir, 1, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqual(@as(usize, 2), compilation.packages.packages.len);
    try std.testing.expectEqualStrings("MonPackage.Class1", compilation.interfaces[2].name);
}

test "compile a loose principal module with an installed package" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Sandbox/MonModule");
    try temporary.dir.createDirPath(std.testing.io, "Global/STD@0.16.2/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Sandbox/MonModule/@Module.sx",
        .data =
        \\use STD.Value
        \\func answer() int { return Value.answer() }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/STD@0.16.2/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"0.16.2\",\"requires\":{\"silex\":\">=0.38.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/STD@0.16.2/Module/Value.sx",
        .data = "public func answer() int { return 42 }",
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const input = try std.fs.path.join(allocator, &.{ base, "Sandbox", "MonModule", "@Module.sx" });
    const global = try std.fs.path.join(allocator, &.{ base, "Global" });
    var compiler = Compiler.initWithPackages(allocator, std.testing.io, global);
    const compilation = try compiler.compile(input);

    var answer_id: ?usize = null;
    for (compilation.ir.functions, 0..) |function, id| {
        if (std.mem.eql(u8, function.name, "MonModule.answer")) answer_id = id;
    }
    const answer = try @import("../Interpreter.zig").invoke(
        allocator,
        compilation.ir,
        answer_id orelse return error.TestUnexpectedResult,
        &.{},
    );
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqualStrings("MonModule", compilation.interfaces[0].name);
    try std.testing.expectEqualStrings("STD", compilation.packages.packages[1].name.?);
}

test "select named package module roots for the macOS platform" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Bridge/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Platform/MacOS/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Platform/Linux/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Platform/Windows/Module");
    try temporary.dir.createDirPath(std.testing.io, "Portable/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data = "{\"name\":\"Bridge\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Public.sx",
        .data = "use Bridge.Implementation\npublic func value() int { return Implementation.value() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/MacOS/Module/Implementation.sx",
        .data = "public func value() int { return 40 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/Linux/Module/LinuxOnly.sx",
        .data = "this deliberately invalid Linux source must stay inactive",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/Windows/Module/Implementation.sx",
        .data = "this deliberately invalid Windows source must stay inactive",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Portable/Package.json",
        .data = "{\"name\":\"Portable\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Portable/Module/Api.sx",
        .data = "public func value() int { return 2 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Bridge.Public\nuse Portable.Api\nfunc answer() int { return Public.value() + Api.value() }\nfunc main() {}",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    var answer_id: ?usize = null;
    for (compilation.ir.functions, 0..) |function, id| {
        if (std.mem.eql(u8, function.name, "Main.answer")) answer_id = id;
    }
    const answer = try @import("../Interpreter.zig").invoke(
        allocator,
        compilation.ir,
        answer_id orelse return error.TestUnexpectedResult,
        &.{},
    );
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expect(compiler.index.find("Bridge.Implementation") != null);
    try std.testing.expect(compiler.index.find("Bridge.Platform.macos_arm64.Implementation") == null);
    try std.testing.expect(compiler.index.find("Bridge.LinuxOnly") == null);

    var second = Compiler.init(allocator, std.testing.io);
    const repeated = try second.compile(input);
    try std.testing.expectEqual(compilation.files.len, repeated.files.len);
    for (compilation.files, repeated.files) |left, right| try std.testing.expectEqualStrings(left, right);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Bridge.LinuxOnly\nfunc main() {}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "module 'Bridge.LinuxOnly' is not available for macos-arm64",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Bridge.Public\nfunc main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Implementation.sx",
        .data = "public func value() int { return 1 }",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "function 'Bridge.Implementation.value' with these parameter types is already declared",
        compiler.diagnostic.?.message,
    );
}

test "reserve a custom boundary provider to its declaring package" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Bridge/Boundary/macos-arm64");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Module");
    try temporary.dir.createDirPath(std.testing.io, "Thief/Module");
    try writeBoundaryArchive(temporary.dir);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data =
        \\{"name":"Bridge","version":"1.0.0","boundary":{"macos-arm64":{"providers":{"Native":{"archive":"Boundary/macos-arm64/libBridge.a"}}}}}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Api.sx",
        .data =
        \\use Interop.C
        \\use Interop.Boundary
        \\let native_answer = C.function<func() int32>(library:Boundary.Native, name:"boundary_answer")
        \\public func answer() int32 { return native_answer() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Thief/Package.json",
        .data = "{\"name\":\"Thief\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Thief/Module/Api.sx",
        .data =
        \\use Interop.C
        \\use Interop.Boundary
        \\let stolen = C.function<func() int32>(library:Boundary.Native, name:"boundary_answer")
        \\public func answer() int32 { return stolen() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Bridge.Api\nfunc main() { Api.answer() }",
    });

    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const input = try std.fs.path.join(allocator, &.{ base, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try std.testing.expectEqual(@as(usize, 1), compilation.boundaries.len);
    try std.testing.expectEqualStrings("Boundary.Native", compilation.boundaries[0].provider);
    try std.testing.expectEqual(@as(usize, 1), compilation.boundaries[0].owner);
    try std.testing.expect(compilation.boundaries[0].package_private);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Api.sx",
        .data =
        \\use Interop.C
        \\use Interop.MacOS
        \\let native_answer = C.function<func() int32>(library:MacOS.Native, name:"boundary_answer")
        \\public func answer() int32 { return native_answer() }
        ,
    });
    var system_prefixed = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, system_prefixed.compile(input));
    try std.testing.expectEqualStrings(
        "package boundary provider 'Native' must use library:Boundary.Native",
        system_prefixed.diagnostic.?.message,
    );
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Api.sx",
        .data =
        \\use Interop.C
        \\use Interop.Boundary
        \\let native_answer = C.function<func() int32>(library:Boundary.Native, name:"boundary_answer")
        \\public func answer() int32 { return native_answer() }
        ,
    });

    var unavailable = Compiler.init(allocator, std.testing.io);
    unavailable.target = .linux_x64;
    try std.testing.expectError(error.InvalidSource, unavailable.compile(input));
    try std.testing.expectEqualStrings(
        "boundary provider 'Native' is not declared by package 'Bridge' for this target",
        unavailable.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Thief.Api\nfunc main() { Api.answer() }",
    });
    var rejected = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, rejected.compile(input));
    try std.testing.expectEqualStrings(
        "boundary provider 'Native' is not declared by package 'Thief' for this target",
        rejected.diagnostic.?.message,
    );
}

test "compose same-package module fragments across active roots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Bridge/Module");
    inline for (.{ "MacOS", "Linux", "Windows" }) |platform| {
        try temporary.dir.createDirPath(std.testing.io, "Bridge/Platform/" ++ platform ++ "/Module");
    }
    inline for (.{ "macos-arm64", "linux-x64", "windows-x64", "windows-arm64" }) |target| {
        try temporary.dir.createDirPath(std.testing.io, "Bridge/Target/" ++ target ++ "/Module");
    }
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data = "{\"name\":\"Bridge\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Combined.sx",
        .data = "public func value() int { return Platform.PlatformValue(value:Platform.value()).value + Target.value() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Platform/MacOS/Module/Combined.sx", .data = "struct PlatformValue { let value:int }\nfunc value() int { return 100 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Platform/Linux/Module/Combined.sx", .data = "struct PlatformValue { let value:int }\nfunc value() int { return 200 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Platform/Windows/Module/Combined.sx", .data = "struct PlatformValue { let value:int }\nfunc value() int { return 300 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Target/macos-arm64/Module/Combined.sx", .data = "func value() int { return 1 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Target/linux-x64/Module/Combined.sx", .data = "func value() int { return 2 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Target/windows-x64/Module/Combined.sx", .data = "func value() int { return 3 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Target/windows-arm64/Module/Combined.sx", .data = "func value() int { return 4 }" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Bridge.Combined\nfunc answer() int { return Combined.value() }\nfunc main() {}",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    const cases = [_]struct { target: @import("../Target.zig").Target, expected: i64 }{
        .{ .target = .macos_arm64, .expected = 101 },
        .{ .target = .linux_x64, .expected = 202 },
        .{ .target = .windows_x64, .expected = 303 },
        .{ .target = .windows_arm64, .expected = 304 },
    };
    for (cases) |case| {
        var compiler = Compiler.init(allocator, std.testing.io);
        compiler.cache_modules = true;
        compiler.target = case.target;
        const compilation = try compiler.compile(input);
        var answer_id: ?usize = null;
        for (compilation.ir.functions, 0..) |function, id| {
            if (std.mem.eql(u8, function.name, "Main.answer")) answer_id = id;
        }
        const answer = try @import("../Interpreter.zig").invoke(
            allocator,
            compilation.ir,
            answer_id orelse return error.TestUnexpectedResult,
            &.{},
        );
        try std.testing.expectEqual(case.expected, answer.integer);
        var fragment_count: usize = 0;
        for (compiler.index.providers) |provider| {
            if (std.mem.eql(u8, provider.name, "Bridge.Combined")) fragment_count += 1;
        }
        try std.testing.expectEqual(@as(usize, 3), fragment_count);
    }

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/MacOS/Module/Combined.sx",
        .data = "struct PlatformValue { let value:int }\nfunc value() int { return 110 }",
    });
    var changed_compiler = Compiler.init(allocator, std.testing.io);
    changed_compiler.cache_modules = true;
    changed_compiler.target = .macos_arm64;
    const changed = try changed_compiler.compile(input);
    var changed_answer_id: ?usize = null;
    for (changed.ir.functions, 0..) |function, id| {
        if (std.mem.eql(u8, function.name, "Main.answer")) changed_answer_id = id;
    }
    const changed_answer = try @import("../Interpreter.zig").invoke(
        allocator,
        changed.ir,
        changed_answer_id orelse return error.TestUnexpectedResult,
        &.{},
    );
    try std.testing.expectEqual(@as(i64, 111), changed_answer.integer);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/MacOS/Module/Combined.sx",
        .data = "struct PlatformValue { let value:int }\nlocal func value() int { return 100 }",
    });
    var internal_compiler = Compiler.init(allocator, std.testing.io);
    internal_compiler.target = .macos_arm64;
    try std.testing.expectError(error.InvalidSource, internal_compiler.compile(input));
    try std.testing.expectEqualStrings(
        "function 'Bridge.Combined.$Platform.value' is local to its source file",
        internal_compiler.diagnostic.?.message,
    );
    try std.testing.expect(std.mem.endsWith(
        u8,
        internal_compiler.diagnosticPath(input),
        "Bridge/Module/Combined.sx",
    ));
}

test "keep fragment imports local to their source file" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Bridge/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Platform/MacOS/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data = "{\"name\":\"Bridge\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Helper.sx",
        .data = "public func value() int { return 42 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Combined.sx",
        .data = "public func value() int { return Helper.value() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/MacOS/Module/Combined.sx",
        .data = "use Bridge.Helper\nfunc platform_value() int { return Helper.value() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Bridge.Combined\nfunc main() { print(Combined.value()) }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    compiler.target = .macos_arm64;
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("unknown function 'Helper.value'", compiler.diagnostic.?.message);
}

test "require explicit contextual qualifiers for specialized fragments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Bridge/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Platform/MacOS/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data = "{\"name\":\"Bridge\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/MacOS/Module/Combined.sx",
        .data = "func specialized() int { return 42 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Bridge.Combined\nfunc main() { print(Combined.value()) }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Combined.sx",
        .data = "public func value() int { return specialized() }",
    });
    var compiler = Compiler.init(allocator, std.testing.io);
    compiler.target = .macos_arm64;
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "function 'specialized' from the Platform fragment must be accessed as 'Platform.specialized'",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Combined.sx",
        .data = "public func value() int { return Platform.missing() }",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    compiler.target = .macos_arm64;
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "Platform fragment of 'Bridge.Combined' has no declaration 'missing'",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Combined.sx",
        .data = "public func value() int { return Target.missing() }",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    compiler.target = .macos_arm64;
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "module 'Bridge.Combined' has no Target fragment for macos-arm64",
        compiler.diagnostic.?.message,
    );
}

test "compose platform and exact target roots across the portability matrix" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Bridge/Module");
    inline for (.{ "MacOS", "Linux", "Windows" }) |platform| {
        try temporary.dir.createDirPath(std.testing.io, "Bridge/Platform/" ++ platform ++ "/Module");
    }
    inline for (.{ "macos-arm64", "linux-x64", "windows-x64", "windows-arm64" }) |target| {
        try temporary.dir.createDirPath(std.testing.io, "Bridge/Target/" ++ target ++ "/Module");
    }
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data = "{\"name\":\"Bridge\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Module/Public.sx",
        .data =
        \\use Bridge.PlatformValue
        \\use Bridge.TargetValue
        \\public func value() int { return PlatformValue.value() + TargetValue.value() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Platform/MacOS/Module/PlatformValue.sx", .data = "public func value() int { return 100 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Platform/Linux/Module/PlatformValue.sx", .data = "public func value() int { return 200 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Platform/Windows/Module/PlatformValue.sx", .data = "public func value() int { return 300 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Target/macos-arm64/Module/TargetValue.sx", .data = "public func value() int { return 1 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Target/linux-x64/Module/TargetValue.sx", .data = "public func value() int { return 2 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Target/windows-x64/Module/TargetValue.sx", .data = "public func value() int { return 3 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Target/windows-arm64/Module/TargetValue.sx", .data = "public func value() int { return 4 }" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Bridge.Public\nfunc answer() int { return Public.value() }\nfunc main() {}",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    const cases = [_]struct { target: @import("../Target.zig").Target, expected: i64 }{
        .{ .target = .macos_arm64, .expected = 101 },
        .{ .target = .linux_x64, .expected = 202 },
        .{ .target = .windows_x64, .expected = 303 },
        .{ .target = .windows_arm64, .expected = 304 },
    };
    for (cases) |case| {
        var compiler = Compiler.init(allocator, std.testing.io);
        compiler.target = case.target;
        const compilation = try compiler.compile(input);
        var answer_id: ?usize = null;
        for (compilation.ir.functions, 0..) |function, id| {
            if (std.mem.eql(u8, function.name, "Main.answer")) answer_id = id;
        }
        const answer = try @import("../Interpreter.zig").invoke(
            allocator,
            compilation.ir,
            answer_id orelse return error.TestUnexpectedResult,
            &.{},
        );
        try std.testing.expectEqual(case.expected, answer.integer);
    }

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Platform/MacOS/Module/TargetValue.sx",
        .data = "public func value() int { return 0 }",
    });
    var collision = Compiler.init(allocator, std.testing.io);
    collision.target = .macos_arm64;
    try std.testing.expectError(error.InvalidSource, collision.compile(input));
    try std.testing.expectEqualStrings(
        "function 'Bridge.TargetValue.value' with these parameter types is already declared",
        collision.diagnostic.?.message,
    );
}

test "compile an explicit package test entry outside public module roots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Toolkit/Module");
    try temporary.dir.createDirPath(std.testing.io, "Toolkit/Tests");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Toolkit/Package.json",
        .data = "{\"name\":\"Toolkit\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Toolkit/Module/Value.sx",
        .data = "public func answer() int { return 42 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Toolkit/Tests/Main.sx",
        .data = "use Toolkit.Value\nfunc main() { print(Value.answer()) }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Toolkit/Tests/Unloaded.sx",
        .data = "this test must remain undiscovered",
    });

    const input = try std.fs.path.join(
        allocator,
        &.{ ".zig-cache", "tmp", &temporary.sub_path, "Toolkit", "Tests", "Main.sx" },
    );
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
    try std.testing.expect(compiler.index.find("Toolkit.Tests.Main") != null);
    try std.testing.expect(compiler.index.find("Toolkit.Tests.Unloaded") == null);
}

test "compile an explicit package suite entry after composing a merged extension" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GFX/Module/Application");
    try temporary.dir.createDirPath(std.testing.io, "GFX.Application/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX.Scene2D/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX.Scene2D/Tests");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data =
        \\{"name":"GFX","version":"1.0.0","extensions":{"GFX.Application":{"merge":true,"suite":true},"GFX.Scene2D":{"suite":true}}}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Application/@Module.sx",
        .data =
        \\public protocol Plugin {
        \\    func id() str
        \\    func build(application:&Application)
        \\}
        \\public class Application {
        \\    func add_plugin<P:Plugin>(plugin:P) {
        \\        assert(plugin.id() == "time")
        \\        var candidate = plugin
        \\        var host = self
        \\        candidate.build(host)
        \\    }
        \\    func mark_ready() {}
        \\}
        \\public func core_value() int { return 20 }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Application/Time.sx",
        .data =
        \\use GFX.Application
        \\use GFX.Application.Plugin as PluginProtocol
        \\public struct Time:PluginProtocol {
        \\    func id() str { return "time" }
        \\    func build(application:&Application) { application.mark_ready() }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Application/Package.json",
        .data = "{\"name\":\"GFX.Application\",\"version\":\"1.0.0\",\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Application/Module/@Scene.sx",
        .data = "public func scene_value() int { return 22 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Scene2D/Package.json",
        .data = "{\"name\":\"GFX.Scene2D\",\"version\":\"1.0.0\",\"dependencies\":{\"GFX\":\"=1.0.0\",\"GFX.Application\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Scene2D/Module/Domain.sx",
        .data = "public func value() int { return 1 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Scene2D/Tests/Domain.sx",
        .data =
        \\use GFX.Application
        \\use GFX.Application.Time as TimePlugin
        \\test "consume merged application" {
        \\    var host = Application()
        \\    host.add_plugin(TimePlugin())
        \\    assert(Application.core_value() + Application.scene_value() == 42)
        \\}
        ,
    });

    const input = try std.fs.path.join(
        allocator,
        &.{ ".zig-cache", "tmp", &temporary.sub_path, "GFX.Scene2D", "Tests", "Domain.sx" },
    );
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compileTests(input);
    try std.testing.expectEqual(@as(usize, 1), compilation.tests.len);
    try std.testing.expect(compiler.index.find("GFX.Scene2D.Tests.Domain") != null);
    const result = try @import("../Interpreter.zig").runFunctionCaptureWithBoundaries(
        allocator,
        null,
        compilation.ir,
        compilation.tests[0].function,
        compilation.boundaries,
    );
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    _ = try @import("../Arm64/Lower.zig").lower(allocator, compilation.ir);
}

test "qualified packages share namespaces without sharing ownership" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    const package_names = [_][]const u8{ "Silex", "Silex.Audio", "Silex.Bootstrap", "Silex.Rendering" };
    for (package_names) |name| {
        const module_path = try std.fs.path.join(allocator, &.{ name, "Module" });
        try temporary.dir.createDirPath(std.testing.io, module_path);
        const manifest_path = try std.fs.path.join(allocator, &.{ name, "Package.json" });
        const manifest = if (std.mem.eql(u8, name, "Silex"))
            "{\"name\":\"Silex\",\"version\":\"1.0.0\",\"extensions\":{\"Silex.*\":{}}}"
        else
            try std.fmt.allocPrint(
                allocator,
                "{{\"name\":\"{s}\",\"version\":\"1.0.0\"}}",
                .{name},
            );
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = manifest_path, .data = manifest });
    }
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Silex.Core
        \\use Silex.Audio.Mixer
        \\use Silex.Bootstrap.Start
        \\use Silex.Rendering.Texture
        \\func answer() int { return Core.value() + Mixer.value() + Start.value() + Texture.value() }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Silex/Module/Core.sx", .data = "public func value() int { return 9 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Silex.Audio/Module/Mixer.sx", .data = "public func value() int { return 10 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Silex.Bootstrap/Module/Start.sx", .data = "public func value() int { return 11 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Silex.Rendering/Module/Texture.sx", .data = "public func value() int { return 12 }" });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const answer = try @import("../Interpreter.zig").invoke(allocator, compilation.ir, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqual(@as(usize, 5), compilation.packages.packages.len);

    try temporary.dir.createDirPath(std.testing.io, "Silex/Module/Rendering");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Silex/Module/Rendering/Texture.sx",
        .data = "public func duplicate() {}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("multiple source files provide the same module", compiler.diagnostic.?.message);
}

test "packages authorize direct namespace extensions hierarchically" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX.UI/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"GFX\":\"=1.0.0\",\"GFX.UI\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.UI/Package.json",
        .data = "{\"name\":\"GFX.UI\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Core.sx",
        .data = "public func value() int { return 20 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.UI/Module/Button.sx",
        .data = "public func value() int { return 22 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use GFX.Core\nuse GFX.UI.Button\nfunc main() { print(Core.value() + Button.value()) }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "package 'GFX' does not authorize package 'GFX.UI' as a namespace extension",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.UI\":{}}}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    var compilation = try compiler.compile(input);
    var result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);

    try temporary.dir.createDirPath(std.testing.io, "GFX.UI.Controls/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"GFX\":\"=1.0.0\",\"GFX.UI\":\"=1.0.0\",\"GFX.UI.Controls\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.*\":{}}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.UI.Controls/Package.json",
        .data = "{\"name\":\"GFX.UI.Controls\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.UI.Controls/Module/Panel.sx",
        .data = "public func value() int { return 1 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use GFX.Core\nuse GFX.UI.Button\nuse GFX.UI.Controls.Panel\nfunc main() { print(Core.value() + Button.value() + Panel.value()) }",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "package 'GFX.UI' does not authorize package 'GFX.UI.Controls' as a namespace extension",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.UI/Package.json",
        .data = "{\"name\":\"GFX.UI\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.UI.*\":{}}}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    compilation = try compiler.compile(input);
    result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("43\n", result.stdout);
}

test "parent packages own exact extension modules and may merge them additively" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX.Physics/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"GFX\":\"=1.0.0\",\"GFX.Physics\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Physics\":{}}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Physics.sx",
        .data = "public func core_value() int { return 20 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Physics/Package.json",
        .data = "{\"name\":\"GFX.Physics\",\"version\":\"1.0.0\",\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Physics/Module/@Module.sx",
        .data = "public func extension_value() int { return 22 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use GFX.Physics\nfunc main() { print(Physics.core_value() + Physics.extension_value()) }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "parent package 'GFX' owns module 'GFX.Physics'; extension package 'GFX.Physics' cannot provide the same module unless its exact extension permission enables merge",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Physics\":{\"merge\":true}}}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    const compilation = compiler.compile(input) catch |err| {
        std.debug.print("merged extension compilation failed: {s}\n", .{compiler.diagnostic.?.message});
        return err;
    };
    const result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
    const provider = compiler.index.find("GFX.Physics").?;
    try std.testing.expectEqualStrings("GFX", compiler.packages.label(provider.owner));

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Physics/Module/@Module.sx",
        .data = "public func core_value() int { return 22 }",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "public declaration 'core_value' from extension package 'GFX.Physics' collides with package 'GFX' in merged module 'GFX.Physics'",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Physics.sx",
        .data = "public func core_value() int { return GFX.Physics.extension_hidden() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Physics/Module/@Module.sx",
        .data = "func extension_hidden() int { return 42 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use GFX.Physics\nfunc main() { print(Physics.core_value()) }",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "function 'GFX.Physics.extension_hidden' is module-visible and unavailable outside its module",
        compiler.diagnostic.?.message,
    );
}

test "public package lists preserve collection behavior in consumers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Parent/Module");
    try temporary.dir.createDirPath(std.testing.io, "Tests");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\"Tests\",\"dependencies\":{\"Parent\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Parent/Package.json",
        .data = "{\"name\":\"Parent\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Parent/Module/@Module.sx",
        .data =
        \\public use Parent.Item.Item
        \\public use Parent.Store.Store
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Parent/Module/Item.sx",
        .data = "public struct Item { let value:int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Parent/Module/Store.sx",
        .data =
        \\use Parent.Item.Item
        \\public class Store {
        \\    func items() Item[] { return [Item(value:2), Item(value:3)] }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Tests/PublicList.sx",
        .data =
        \\use Parent
        \\func total() int {
        \\    var store = Parent.Store()
        \\    assert(store.items().count() == 2)
        \\    let values = store.items()
        \\    assert(values.count() == 2)
        \\    assert(values[0].value == 2)
        \\    var result = 0
        \\    for value in values { result += value.value }
        \\    return result
        \\}
        \\func main() { print(total()) }
        \\test "consume public list" { assert(total() == 5) }
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Tests", "PublicList.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("5\n", result.stdout);
    _ = try @import("../Arm64/Lower.zig").lower(allocator, compilation.ir);

    compiler = Compiler.init(allocator, std.testing.io);
    const suite = try compiler.compileTests(input);
    const test_result = try @import("../Interpreter.zig").runFunctionCaptureWithBoundaries(
        allocator,
        null,
        suite.ir,
        suite.tests[0].function,
        suite.boundaries,
    );
    try std.testing.expectEqual(@as(u8, 0), test_result.exit_code);
    _ = try @import("../Arm64/Lower.zig").lower(allocator, suite.ir);
}

test "merged extension atoms ignore synthetic internal types but preserve public collisions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX.Application/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"GFX.Application\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Application\":{\"merge\":true}}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Application.sx",
        .data =
        \\public enum Schedule { update }
        \\public intrinsic class Resources {
        \\    func scope() Resources
        \\    func insert<T>(value:T)
        \\    module func retain_class<T>(value:T)
        \\    func has<T>() bool
        \\    func get<T>() @T
        \\    func get_mut<T>() &T
        \\    func try_get<T>() @T?
        \\    func try_get_mut<T>() &T?
        \\    func remove<T>() T?
        \\    func clear()
        \\    module func invalidate()
        \\}
        \\class RegisteredSystem {
        \\    let reads:str[]
        \\    let writes:str[]
        \\    init(reads:str[], writes:str[]) { self.reads = reads; self.writes = writes }
        \\}
        \\public class Application {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Application/Package.json",
        .data = "{\"name\":\"GFX.Application\",\"version\":\"1.0.0\",\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Application/Module/@Scene.sx",
        .data =
        \\class SceneSystem {
        \\    let reads:str[]
        \\    let writes:str[]
        \\    init(reads:str[], writes:str[]) { self.reads = reads; self.writes = writes }
        \\}
        \\public class Scene {
        \\    var resources:Resources
        \\    init(resources:Resources) { resources.invalidate(); self.resources = resources }
        \\    func add_system(schedule:Schedule) { var system = SceneSystem([], []) }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use GFX.Application
        \\func main() {}
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    _ = try compiler.compile(input);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use GFX.Application.Resources
        \\func main() { var resources = Resources(); resources.invalidate() }
        ,
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "method 'invalidate' is module-visible and unavailable outside its module",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use GFX.Application
        \\func main() {}
        ,
    });

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Application/Module/@Scene.sx",
        .data =
        \\public intrinsic class Resources {}
        \\public class Scene {}
        ,
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "public declaration 'Resources' from extension package 'GFX.Application' collides with package 'GFX' in merged module 'GFX.Application'",
        compiler.diagnostic.?.message,
    );
}

test "enforce public package interfaces and direct dependency visibility" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "A/Module");
    try temporary.dir.createDirPath(std.testing.io, "B/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"A\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "A/Package.json",
        .data = "{\"name\":\"A\",\"version\":\"1.0.0\",\"dependencies\":{\"B\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "A/Module/Api.sx",
        .data = "func hidden() {}\npublic func exposed() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "B/Package.json",
        .data = "{\"name\":\"B\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "B/Module/Private.sx",
        .data = "public func value() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use A.Api\nfunc main() { Api.hidden() }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "function 'A.Api.hidden' is module-visible and unavailable outside its module",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() { A.Api.hidden() }",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "function 'A.Api.hidden' is module-visible and unavailable outside its module",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use B.Private\nfunc main() {}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("unknown module or declaration 'B.Private'", compiler.diagnostic.?.message);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() { B.Private.value() }",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("unknown function 'B.Private.value'", compiler.diagnostic.?.message);
}

test "let exact and wildcard friend packages use package declarations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX.Physics/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"GFX\":\"=1.0.0\",\"GFX.Physics\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Physics\":{}}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Core.sx",
        .data =
        \\package struct InternalValue {
        \\    let amount:int
        \\    func add(value:int) int { return self.amount + value }
        \\}
        \\package enum Increment { two }
        \\package func internal_value() int { return 42 }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Physics/Package.json",
        .data = "{\"name\":\"GFX.Physics\",\"version\":\"1.0.0\",\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Physics/Module/Plugin.sx",
        .data =
        \\use GFX.Core
        \\public func function_value() int { return Core.internal_value() }
        \\public func structure_value() int {
        \\    let increment = Core.Increment.two
        \\    let value = Core.InternalValue(amount:40)
        \\    return value.add(2)
        \\}
        \\public func value() int { return function_value() + structure_value() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use GFX.Physics.Plugin\nfunc main() { print(Plugin.value()) }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "enum 'Increment' is package-visible and unavailable outside package 'GFX'",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Physics\":{\"friend\":true}}}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    var compilation = try compiler.compile(input);
    var result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("84\n", result.stdout);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.*\":{\"friend\":true}}}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    compilation = try compiler.compile(input);
    result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("84\n", result.stdout);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.*\":{\"friend\":true},\"GFX.Physics\":{}}}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "enum 'Increment' is package-visible and unavailable outside package 'GFX'",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use GFX.Core\nfunc main() { print(Core.internal_value()) }",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "function 'GFX.Core.internal_value' is package-visible and unavailable outside its package",
        compiler.diagnostic.?.message,
    );
}

test "compose child-owned reexports into authorized umbrella catalogs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX.Physics/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"GFX\":\"=1.0.0\",\"GFX.Physics\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Physics\":{}},\"catalogs\":[\"GFX.Plugins\"]}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Plugins.sx",
        .data = "public struct Core { let value:int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Physics/Package.json",
        .data = "{\"name\":\"GFX.Physics\",\"version\":\"1.0.0\",\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Physics/Module/@Module.sx",
        .data =
        \\contribute GFX.Plugins {
        \\    public use GFX.Physics.Plugin as Physics
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Physics/Module/Plugin.sx",
        .data = "public struct Plugin { let value:int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use GFX.Plugins\nfunc main() { print(Plugins.Physics(value:42).value) }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Physics\":{}}}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "package 'GFX.Physics' cannot contribute to 'GFX.Plugins'; its parent must declare that existing module in catalogs",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Physics\":{}},\"catalogs\":[\"GFX.Plugins\"]}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Plugins.sx",
        .data = "public struct Physics {}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "umbrella contribution 'Physics' collides with an existing declaration or child namespace",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Plugins.sx",
        .data = "public struct Core { let value:int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Physics/Module/@Module.sx",
        .data =
        \\contribute GFX.Plugins {
        \\    public use GFX.Plugins.Core as Physics
        \\}
        ,
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "an umbrella contribution can only reexport a declaration owned by package 'GFX.Physics'",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Foreign.sx",
        .data = "public struct Foreign {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Physics/Module/@Module.sx",
        .data =
        \\public use GFX.Foreign.Foreign as Relayed
        \\contribute GFX.Plugins {
        \\    public use GFX.Physics.Relayed as Physics
        \\}
        ,
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "an umbrella contribution can only reexport a declaration owned by package 'GFX.Physics'",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Physics/Module/@Module.sx",
        .data = "",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Physics/Module/Contribution.sx",
        .data =
        \\contribute GFX.Plugins {
        \\    public use GFX.Physics.Plugin as Physics
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use GFX.Physics.Contribution\nfunc main() {}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "umbrella contributions must be declared in a named package's portable principal module",
        compiler.diagnostic.?.message,
    );
}

test "compose a merged child-owned declaration into an authorized umbrella catalog" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX.Application/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"GFX\":\"=1.0.0\",\"GFX.Application\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Application\":{\"merge\":true}},\"catalogs\":[\"GFX.Plugins\"]}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Application.sx",
        .data = "public struct Application {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Plugins.sx",
        .data = "public struct Core {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Application/Package.json",
        .data = "{\"name\":\"GFX.Application\",\"version\":\"1.0.0\",\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Application/Module/@SceneManager.sx",
        .data =
        \\public struct SceneManager { let value:int }
        \\contribute GFX.Plugins {
        \\    public use GFX.Application.SceneManager as SceneManager
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use GFX.Plugins\nfunc main() { print(Plugins.SceneManager(value:42).value) }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "compose and execute structures inside their declaring module" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\struct Point { var x:int; var y:int = 2 }
        \\func main() { let point = Point(x:40); print(point.x + point.y) }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "compose public nested types while their owner caps visibility" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data =
        \\public struct Catalog { struct Entry { let value:int } }
        \\struct Hidden { struct Leaked {} }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Api
        \\func main() { let entry = Api.Catalog.Entry(value:42); print(entry.value) }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
    var leaked = false;
    for (compilation.interfaces) |interface| for (interface.structures) |structure| {
        if (std.mem.eql(u8, structure.export_name, "Hidden.Leaked")) leaked = true;
    };
    try std.testing.expect(!leaked);
}

test "compose public associated enums across modules" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data =
        \\public enum Message { empty; text(str) }
        \\public func accept(value:Message) int { return 42 }
        \\public func describe(value:Message) str {
        \\    return match value { empty => "empty"; text(content) => content }
        \\}
        \\public func show(value:Message) {
        \\    match value { empty => { print("empty") }; text(content) => { print(content) } }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Api.Message
        \\use Api.accept
        \\use Api.describe
        \\use Api.show
        \\func main() { let value = Message.text("hello"); print(accept(value)); print(describe(value)); show(Message.text("api")) }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\nhello\napi\n", result.stdout);
    var found_interface = false;
    for (compilation.interfaces) |interface| {
        if (!std.mem.eql(u8, interface.name, "Api")) continue;
        found_interface = true;
        try std.testing.expectEqual(@as(usize, 1), interface.enums.len);
    }
    try std.testing.expect(found_interface);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "local enum Message { empty }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api.Message\nfunc main() { Message.empty() }",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("enum 'Message' is local to its source file", compiler.diagnostic.?.message);
}

test "compose public raw enums across modules" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Codes.sx",
        .data =
        \\public enum Code:int { ok = 200; missing = 404 }
        \\public func raw(value:Code) int { return value.raw_value }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Codes.Code\nuse Codes.raw\nfunc main() { print(raw(Code.missing())) }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("404\n", result.stdout);
    for (compilation.interfaces) |interface| {
        if (!std.mem.eql(u8, interface.name, "Codes")) continue;
        try std.testing.expectEqual(Types.Type.int, interface.enums[0].raw_type.?);
    }
}
