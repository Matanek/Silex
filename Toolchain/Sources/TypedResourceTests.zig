const std = @import("std");
const Project = @import("Project.zig");
const Interpreter = @import("Interpreter.zig");

const bootstrap_source =
    \\public class Resources {
    \\    private var __resource_order:int[]
    \\    public init() { self.__resource_order = [] }
    \\    public func insert<T>(value:T) { panic("unspecialized insert") }
    \\    public func has<T>() bool { panic("unspecialized has") }
    \\    public func get<T>() @T { panic("unspecialized get") }
    \\    public func get_mut<T>() &T { panic("unspecialized get_mut") }
    \\    public func try_get<T>() @T? { panic("unspecialized try_get") }
    \\    public func try_get_mut<T>() &T? { panic("unspecialized try_get_mut") }
    \\    public func remove<T>() T? { panic("unspecialized remove") }
    \\    public func clear() { panic("unspecialized clear") }
    \\    drop { self.clear() }
    \\}
    \\public class Application {
    \\    private var store:Resources
    \\    public init() { self.store = Resources() }
    \\    public func resources() Resources { return self.store }
    \\    public func add_system(schedule:int, callback:func(Application)) { callback(self) }
    \\    public func add_system<System>(schedule:int, callback:System) { panic("unspecialized system") }
    \\    public func add_after_system(schedule:int, callback:func(Application)) { callback(self) }
    \\    public func add_after_system<System>(schedule:int, callback:System) { panic("unspecialized system") }
    \\    internal func __silex_add_system(schedule:int, callback:func(Application, int), after:bool, reads:str[], writes:str[], flags:uint) { callback(self, 0) }
    \\    drop { self.store.clear() }
    \\}
;

fn prepare(temporary: anytype) !void {
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX/Smokes");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GFX/Module/Bootstrap.sx", .data = bootstrap_source });
}

fn inputPath(allocator: std.mem.Allocator, temporary: anytype) ![]const u8 {
    return std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "GFX", "Smokes", "Main.sx" });
}

test "typed application resources isolate canonical concrete types and destroy in reverse insertion order" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Model.sx",
        .data =
        \\public struct State { public var value:int }
        \\public struct Cache<T> { public let value:T }
        \\public struct First { public let value:int; public init(value:int) { self.value = value } drop { print("first ", self.value) } }
        \\public struct Second { public let value:int; public init(value:int) { self.value = value } drop { print("second ", self.value) } }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Facade.sx",
        .data = "public use GFX.Model.State as StateAlias",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Bootstrap
        \\use GFX.Model
        \\use GFX.Facade
        \\func main() {
        \\    var first_app = Bootstrap.Application()
        \\    var second_app = Bootstrap.Application()
        \\    var first = first_app.resources()
        \\    var second = second_app.resources()
        \\    first.insert(Model.State(value:40))
        \\    assert(first.has<Facade.StateAlias>())
        \\    assert(!second.has<Model.State>())
        \\    if true { var state:&Model.State = first.get_mut<Model.State>(); state.value += 2 }
        \\    if true { let state:@Model.State = first.get<Model.State>(); print(state.value) }
        \\    first.insert(Model.Cache<int>(value:1))
        \\    assert(!first.has<Model.Cache<str>>())
        \\    second.insert(Model.First(1))
        \\    second.insert(Model.Second(2))
        \\    second.insert(Model.First(3))
        \\    second.clear()
        \\    let removed = first.remove<Model.State>()
        \\    assert(removed != null)
        \\    assert(first.try_get<Model.State>() == null)
        \\}
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("42\nfirst 1\nfirst 3\nsecond 2\n", result.stdout);
}

test "typed resources report a missing required resource" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Bootstrap
        \\struct State { let value:int }
        \\func main() { var app = Bootstrap.Application(); var resources = app.resources(); let state:@State = resources.get<State>(); print(state.value) }
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "resource 'GFX.Smokes.Main.State' is not present") != null);
}

test "removing a class resource transfers its last registry root" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Bootstrap
        \\class Token { drop { print("token dropped") } }
        \\func main() {
        \\    var application = Bootstrap.Application()
        \\    var resources = application.resources()
        \\    resources.insert(Token())
        \\    var removed = resources.remove<Token>()
        \\    assert(removed != null)
        \\    assert(!resources.has<Token>())
        \\}
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("token dropped\n", result.stdout);
}

test "typed resources cannot be invalidated while borrowed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Bootstrap
        \\struct State { let value:int }
        \\func main() {
        \\    var app = Bootstrap.Application()
        \\    var resources = app.resources()
        \\    resources.insert(State(value:1))
        \\    let state:@State = resources.get<State>()
        \\    resources.remove<State>()
        \\    print(state.value)
        \\}
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(try inputPath(allocator, temporary)));
    try std.testing.expect(std.mem.indexOf(u8, compiler.diagnostic.?.message, "alias 'state' is alive") != null);
}

test "systems inject read and mutable resources while preserving legacy callbacks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Bootstrap
        \\struct Time { let delta:int }
        \\struct World { var value:int }
        \\func update(time:@Time, world:&World) { world.value += time.delta }
        \\func observe(first:@Time, second:@Time) { print(first.delta + second.delta) }
        \\func empty() { print("empty") }
        \\func legacy(application:Bootstrap.Application) { print(application.resources().has<World>()) }
        \\func main() {
        \\    var application = Bootstrap.Application()
        \\    var resources = application.resources()
        \\    resources.insert(Time(delta:2))
        \\    resources.insert(World(value:40))
        \\    application.add_system(0, update)
        \\    application.add_system(0, observe)
        \\    application.add_after_system(schedule:0, callback:empty)
        \\    application.add_system(schedule:0, callback:legacy)
        \\    if true { let world:@World = resources.get<World>(); print(world.value) }
        \\}
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("4\nempty\ntrue\n42\n", result.stdout);
}

test "system callbacks keep their declaring module identity" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Feature.sx",
        .data =
        \\use GFX.Bootstrap
        \\public struct State { public var value:int }
        \\func update(state:&State) { state.value += 2 }
        \\public func install(application:Bootstrap.Application) { application.add_system(0, update) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Bootstrap
        \\use GFX.Feature
        \\func update() { print("entry callback") }
        \\func main() {
        \\    var application = Bootstrap.Application()
        \\    var resources = application.resources()
        \\    resources.insert(Feature.State(value:40))
        \\    Feature.install(application)
        \\    if true { let state:@Feature.State = resources.get<Feature.State>(); print(state.value) }
        \\}
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "injected systems name their missing resource" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Bootstrap
        \\struct Time { let delta:int }
        \\func update(time:@Time) { print(time.delta) }
        \\func main() { var application = Bootstrap.Application(); application.add_system(0, update) }
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "system 'update' requires resource 'GFX.Smokes.Main.Time'") != null);
}

test "injected systems reject invalid signatures and mutable conflicts" {
    const cases = [_]struct { system: []const u8, expected: []const u8 }{
        .{ .system = "func invalid(value:int) {}", .expected = "must use '@int' or '&int'" },
        .{ .system = "func invalid() int { return 1 }", .expected = "must return 'void'" },
        .{ .system = "func invalid(first:&State, second:@State) {}", .expected = "conflicting mutable access" },
        .{ .system = "func invalid(application:Bootstrap.Application, state:@State) {}", .expected = "Application must be the sole" },
    };
    for (cases) |case| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var temporary = std.testing.tmpDir(.{});
        defer temporary.cleanup();
        try prepare(&temporary);
        const source = try std.fmt.allocPrint(
            allocator,
            "use GFX.Bootstrap\nstruct State {{ var value:int }}\n{s}\nfunc main() {{ var application = Bootstrap.Application(); application.add_system(0, invalid) }}",
            .{case.system},
        );
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GFX/Smokes/Main.sx", .data = source });
        var compiler = Project.Compiler.init(allocator, std.testing.io);
        try std.testing.expectError(error.InvalidSource, compiler.compile(try inputPath(allocator, temporary)));
        try std.testing.expect(std.mem.indexOf(u8, compiler.diagnostic.?.message, case.expected) != null);
    }
}
