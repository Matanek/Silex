const std = @import("std");
const builtin = @import("builtin");
const Project = @import("Project.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const Lower = @import("Arm64/Lower.zig");
const Runner = @import("Arm64/Runner.zig");

const resources_source =
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
;

test "scoped typed resources shadow and fall back without mutating their parent" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application
        \\struct Shared { var value:int }
        \\struct Local { let value:int }
        \\func main() {
        \\    var application = Application()
        \\    var parent = application.resources()
        \\    parent.insert(Shared(value:1))
        \\    var child = parent.scope()
        \\    assert(child.has<Shared>())
        \\    if true { var inherited:&Shared = child.get_mut<Shared>(); inherited.value = 2 }
        \\    child.insert(Shared(value:3))
        \\    child.insert(Local(value:4))
        \\    if true { let local_state:@Shared = child.get<Shared>(); print(local_state.value) }
        \\    let removed = child.remove<Shared>()
        \\    assert(removed != null)
        \\    assert(child.try_get<Shared>() != null)
        \\    child.clear()
        \\    assert(!child.has<Local>())
        \\    if true { let inherited:@Shared = child.get<Shared>(); print(inherited.value) }
        \\}
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("3\n2\n", result.stdout);
    _ = try Lower.lower(allocator, compilation.ir);
}

test "ARM64 release preserves pointer-backed ECS component stores" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module/ECS");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/ECS/ComponentStore.sx",
        .data =
        \\intrinsic class ComponentPools {
        \\    func insert<T>(value:T)
        \\    func has<T>() bool
        \\    func get<T>() @T
        \\    func get_mut<T>() &T
        \\    func try_get<T>() @T?
        \\    func try_get_mut<T>() &T?
        \\    func remove<T>() T?
        \\    func clear()
        \\}
        \\public struct ComponentStore {
        \\    private var resources:ComponentPools
        \\    private var kinds:int[]
        \\    init() { self.resources = ComponentPools(); self.kinds = [] }
        \\    func insert<T>(value:T) { self.resources.insert(value); self.kinds.append(1) }
        \\    func get<T>() @self:T { return self.resources.get<T>() }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.ECS.ComponentStore.ComponentStore
        \\struct Bucket { let id:int; var values:int[] }
        \\func sample() int {
        \\    var store = ComponentStore()
        \\    store.insert(Bucket(id:40, values:[2]))
        \\    let bucket = store.get<Bucket>()
        \\    return bucket.id + bucket.values[0]
        \\}
        \\func main() {}
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const function = for (compilation.ir.functions, 0..) |candidate, index| {
        if (std.mem.eql(u8, candidate.name, "GFX.Smokes.Main.sample")) break @as(Ir.FunctionId, @intCast(index));
    } else return error.TestUnexpectedResult;
    const machine = try Lower.lowerWithMode(allocator, compilation.ir, .release);
    const result = try Runner.invoke(allocator, machine, function, &.{});
    try std.testing.expectEqual(@as(@TypeOf(result.status), .success), result.status);
    try std.testing.expectEqual(@as(i64, 42), result.value);
}

test "invalidated resource aliases refuse every operation and lower to native code" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const operations = [_][]const u8{
        "escaped.insert(7)",
        "assert(escaped.has<int>())",
        "let value:@int = escaped.get<int>()",
        "var value:&int = escaped.get_mut<int>()",
        "let value = escaped.try_get<int>()",
        "var value:&int? = escaped.try_get_mut<int>()",
        "let value = escaped.remove<int>()",
        "escaped.clear()",
        "var nested = escaped.scope()",
    };
    for (operations) |operation| {
        var temporary = std.testing.tmpDir(.{});
        defer temporary.cleanup();
        try prepare(&temporary);
        const source = try std.fmt.allocPrint(allocator,
            \\use GFX.Application
            \\func main() {{
            \\    var application = Application()
            \\    var parent = application.resources()
            \\    parent.insert(42)
            \\    var child = parent.scope()
            \\    var escaped = child
            \\    child.insert("local")
            \\    Application.invalidate_resources(child)
            \\    {s}
            \\}}
        , .{operation});
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GFX/Smokes/Main.sx", .data = source });

        var compiler = Project.Compiler.init(allocator, std.testing.io);
        const compilation = try compiler.compile(try inputPath(allocator, temporary));
        const interpreted = try Interpreter.runCapture(allocator, compilation.ir);
        try std.testing.expect(interpreted.exit_code != 0);
        try std.testing.expect(std.mem.indexOf(u8, interpreted.stderr, "Resources store has been invalidated") != null);

        _ = try Lower.lower(allocator, compilation.ir);
    }
}

test "resource destruction helper is not source-accessible" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application
        \\func main() {
        \\    var application = Application()
        \\    var resources = application.resources()
        \\    resources.__silex_resource_clear()
        \\}
        ,
    });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(try inputPath(allocator, temporary)));
    try std.testing.expect(std.mem.indexOf(u8, compiler.diagnostic.?.message, "private") != null);
}

test "compatible non-Application hosts specialize typed systems with their own resources" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application
        \\use GFX.Application.Resources
        \\struct Counter { var value:int }
        \\class Scene {
        \\    private var store:Resources
        \\    init(parent:Resources) { self.store = parent.scope() }
        \\    func resources() Resources { return self.store }
        \\    func add_system(schedule:int, callback:func(Scene)) { callback(self) }
        \\    func add_system<System>(schedule:int, callback:System) { panic("unspecialized system") }
        \\    module func __silex_add_system(schedule:int, callback:func(Scene, int), after:bool, reads:str[], writes:str[], flags:uint) Scene { callback(self, 0); return self }
        \\    drop { self.store.clear() }
        \\}
        \\func increment(counter:&Counter) { counter.value++ }
        \\func main() {
        \\    var application = Application()
        \\    var scene = Scene(application.resources())
        \\    var resources = scene.resources()
        \\    resources.insert(Counter(value:41))
        \\    scene.add_system(0, increment)
        \\    print(resources.get<Counter>().value)
        \\}
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("42\n", result.stdout);
    _ = try Lower.lower(allocator, compilation.ir);
}

test "typed system hosts can delegate execution to an Application context" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application
        \\use GFX.Application.Resources
        \\struct Counter { var value:int }
        \\class Bundle {
        \\    private var context:Application
        \\    init(context:Application) { self.context = context }
        \\    func resources() Resources { return self.context.resources() }
        \\    func add_system<System>(schedule:int, callback:System) Bundle { panic("unspecialized system") }
        \\    module func __silex_system_host() Application { return self.context }
        \\    module func __silex_add_system(schedule:int, callback:func(Application, int), after:bool, reads:str[], writes:str[], flags:uint) Bundle {
        \\        self.context.__silex_add_system(schedule, callback, after, reads, writes, flags)
        \\        return self
        \\    }
        \\}
        \\func increment(counter:&Counter) { counter.value++ }
        \\func main() {
        \\    var application = Application()
        \\    var resources = application.resources()
        \\    resources.insert(Counter(value:41))
        \\    var bundle = Bundle(application)
        \\    bundle.add_system(0, increment)
        \\    print(resources.get<Counter>().value)
        \\}
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("42\n", result.stdout);
    _ = try Lower.lower(allocator, compilation.ir);
}

const application_declaration =
    \\public class Application {
    \\    private var store:Resources
    \\    init() { self.store = Resources() }
    \\    func resources() Resources { return self.store }
    \\    module func __silex_system_resources() @Resources { return self.store }
    \\    func add_system(schedule:int, callback:func(Application)) { callback(self) }
    \\    func add_system<System>(schedule:int, callback:System) { panic("unspecialized system") }
    \\    func add_after_system(schedule:int, callback:func(Application)) { callback(self) }
    \\    func add_after_system<System>(schedule:int, callback:System) { panic("unspecialized system") }
    \\    package func __silex_add_system(schedule:int, callback:func(Application, int), after:bool, reads:str[], writes:str[], flags:uint) { callback(self, 0) }
    \\    static func invalidate_resources(resources:Resources) { resources.invalidate() }
    \\    drop { self.store.clear() }
    \\}
;

const application_source = resources_source ++ application_declaration;

test "injected systems forward positional named and default process modes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application.Resources
        \\struct Counter { var value:int }
        \\class Host {
        \\    private var store:Resources = Resources()
        \\    func resources() Resources { return self.store }
        \\    func add_system<System>(schedule:int, callback:System, process_mode:int = 0) Host { panic("unspecialized") }
        \\    func add_after_system<System>(schedule:int, callback:System, process_mode:int = 0) Host { panic("unspecialized") }
        \\    module func __silex_add_system(schedule:int, callback:func(Host, int), after:bool, reads:str[], writes:str[], flags:uint, process_mode:int = 0) Host {
        \\        print(process_mode)
        \\        callback(self, 0)
        \\        return self
        \\    }
        \\}
        \\func increment(counter:&Counter) { counter.value++ }
        \\func main() {
        \\    var host = Host()
        \\    host.resources().insert(Counter(value:40))
        \\    host.add_system(0, increment)
        \\    host.add_system(0, increment, 7)
        \\    host.add_after_system(process_mode:4, callback:increment, schedule:0)
        \\    print(host.resources().get<Counter>().value)
        \\}
        ,
    });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("0\n7\n4\n43\n", result.stdout);
    _ = try Lower.lower(allocator, compilation.ir);
}

test "injected systems borrow the application resource store when the host exposes the compiler hook" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application
        \\struct State { var value:int }
        \\func update(state:&State) { state.value++ }
        \\func main() {
        \\    var application = Application()
        \\    application.resources().insert(State(value:41))
        \\    application.add_system(0, update)
        \\}
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "__silex_system_resources") != null);
    const adapter_start = std.mem.indexOf(u8, text, "__silex_system_adapter_") orelse
        return error.TestUnexpectedResult;
    const adapter_tail = text[adapter_start..];
    const adapter_end = std.mem.indexOf(u8, adapter_tail, "\n}\n") orelse
        return error.TestUnexpectedResult;
    const adapter = adapter_tail[0 .. adapter_end + 3];
    try std.testing.expectEqual(@as(usize, 0), std.mem.count(u8, adapter, "Resources.drop"));
    _ = try Lower.lower(allocator, compilation.ir);
}

fn prepare(temporary: anytype) !void {
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX/Smokes");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GFX/Module/Application.sx", .data = application_source });
}

fn inputPath(allocator: std.mem.Allocator, temporary: anytype) ![]const u8 {
    return std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "GFX", "Smokes", "Main.sx" });
}

test "package consumers execute Resources self-return in test compilation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.createDirPath(std.testing.io, "Tests");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\"Tests\",\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Tests/Scope.sx",
        .data =
        \\use GFX.Application.Resources
        \\test "scope resources" {
        \\    var parent = Resources()
        \\    var child = parent.scope()
        \\    assert(!child.has<int>())
        \\}
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Tests", "Scope.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compileTests(input);
    const result = try Interpreter.runFunctionCaptureWithBoundaries(
        allocator,
        null,
        compilation.ir,
        compilation.tests[0].function,
        compilation.boundaries,
    );
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    _ = try Lower.lower(allocator, compilation.ir);
}

test "typed resources require the exact compiler-provided intrinsic contract" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Application.sx",
        .data =
        \\public intrinsic class Resources {
        \\    func insert<T>(value:T) { panic("placeholder") }
        \\    module func retain_class<T>(value:T)
        \\    func has<T>() bool
        \\    func get<T>() @T
        \\    func get_mut<T>() &T
        \\    func try_get<T>() @T?
        \\    func try_get_mut<T>() &T?
        \\    func remove<T>() T?
        \\    func clear()
        \\}
        ++ application_declaration,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data = "use GFX.Application\nfunc main() { let application = Application() }",
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(try inputPath(allocator, temporary)));
    try std.testing.expectEqualStrings(
        "intrinsic class 'GFX.Application.Resources' does not match the compiler-provided contract",
        compiler.diagnostic.?.message,
    );
}

test "reject intrinsic classes without a compiler implementation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Demo/Module");
    try temporary.dir.createDirPath(std.testing.io, "Demo/Smokes");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Demo/Package.json",
        .data = "{\"name\":\"Demo\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Demo/Module/Magic.sx",
        .data = "public intrinsic class Magic { func run() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Demo/Smokes/Main.sx",
        .data = "use Demo.Magic\nfunc main() { let magic = Magic() }",
    });
    const path = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Demo", "Smokes", "Main.sx" });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(path));
    try std.testing.expectEqualStrings(
        "intrinsic class 'Demo.Magic' has no compiler implementation",
        compiler.diagnostic.?.message,
    );
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
        \\public struct State { var value:int }
        \\public struct Cache<T> { let value:T }
        \\public struct First { let value:int; init(value:int) { self.value = value } drop { print("first ", self.value) } }
        \\public struct Second { let value:int; init(value:int) { self.value = value } drop { print("second ", self.value) } }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Facade.sx",
        .data = "public use GFX.Model.State as StateAlias",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application
        \\use GFX.Model
        \\use GFX.Facade
        \\func main() {
        \\    var first_app = Application()
        \\    var second_app = Application()
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
        \\use GFX.Application
        \\struct State { let value:int }
        \\func main() { var app = Application(); var resources = app.resources(); let state:@State = resources.get<State>(); print(state.value) }
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
        \\use GFX.Application
        \\class Token { drop { print("token dropped") } }
        \\func main() {
        \\    var application = Application()
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
        \\use GFX.Application
        \\struct State { let value:int }
        \\func main() {
        \\    var app = Application()
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
        \\use GFX.Application
        \\struct Time { let delta:int }
        \\struct World { var value:int }
        \\func update(time:@Time, world:&World) { world.value += time.delta }
        \\func observe(first:@Time, second:@Time) { print(first.delta + second.delta) }
        \\func empty() { print("empty") }
        \\func legacy(application:Application) { print(application.resources().has<World>()) }
        \\func main() {
        \\    var application = Application()
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

test "class instance methods register as stateful system callbacks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application
        \\struct Counter { var value:int }
        \\class Game {
        \\    var updates:int
        \\    init() { self.updates = 0 }
        \\    func build(application:Application) {
        \\        application.add_system(0, Game.update)
        \\    }
        \\    func update(counter:&Counter) {
        \\        self.updates++
        \\        counter.value += 2
        \\    }
        \\    func update_count() int { return self.updates }
        \\}
        \\func main() {
        \\    var application = Application()
        \\    var game = Game()
        \\    var resources = application.resources()
        \\    resources.insert(game)
        \\    resources.insert(Counter(value:40))
        \\    game.build(application)
        \\    let counter:@Counter = resources.get<Counter>()
        \\    print(game.update_count(), ":", counter.value)
        \\}
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("1:42\n", result.stdout);
    _ = try Lower.lower(allocator, compilation.ir);
}

test "instance system methods require class identity" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application
        \\struct Game {
        \\    func update() {}
        \\}
        \\func main() {
        \\    var application = Application()
        \\    application.add_system(0, Game.update)
        \\}
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(try inputPath(allocator, temporary)));
    try std.testing.expectEqualStrings(
        "instance system methods require a class receiver",
        compiler.diagnostic.?.message,
    );
}

test "structure methods register system callbacks declared later in their module" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Application.sx",
        .data = resources_source ++
            \\public class Application {
            \\    private var store:Resources
            \\    init() { self.store = Resources() }
            \\    func resources() Resources { return self.store }
            \\    func add_system(schedule:int, callback:func(Application)) { callback(self) }
            \\    func add_system<System>(schedule:int, callback:System) { panic("unspecialized system") }
            \\    func add_after_system(schedule:int, callback:func(Application)) { callback(self) }
            \\    func add_after_system<System>(schedule:int, callback:System) { panic("unspecialized system") }
            \\    package func __silex_add_system(schedule:int, callback:func(Application, int), after:bool, reads:str[], writes:str[], flags:uint) { callback(self, 0) }
            \\    func run() { self.add_after_system(0, flush) }
            \\    drop { self.store.clear() }
            \\}
            \\func flush() { print("flushed") }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application
        \\func main() { var application = Application(); application.run() }
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("flushed\n", result.stdout);
}

test "query iteration caches pools and preserves mutable component ownership" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module/ECS");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/ECS/@Module.sx",
        .data =
        \\public use GFX.ECS.Entity.Entity
        \\public use GFX.ECS.World.World
        \\public use GFX.ECS.Query.Query
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/ECS/Entity.sx",
        .data = "public struct Entity { let index:int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/ECS/ComponentPool.sx",
        .data =
        \\use GFX.ECS.Entity.Entity
        \\public struct ComponentPool<T> {
        \\    private var sparse:int[]
        \\    private var values:T[]
        \\    init(value:T) { self.sparse = [2, 1]; self.values = [value, value] }
        \\    func get_known(entity:Entity) @self:T { return @self.values[self.sparse[entity.index] - 1] }
        \\    func get_mut(entity:Entity) &self:T { return &self.values[self.sparse[entity.index] - 1] }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/ECS/ComponentStore.sx",
        .data =
        \\use GFX.ECS.Entity.Entity
        \\use GFX.ECS.ComponentPool.ComponentPool
        \\intrinsic class ComponentPools {
        \\    func insert<T>(value:T)
        \\    func has<T>() bool
        \\    func get<T>() @T
        \\    func get_mut<T>() &T
        \\    func try_get<T>() @T?
        \\    func try_get_mut<T>() &T?
        \\    func remove<T>() T?
        \\    func clear()
        \\}
        \\public struct ComponentStore {
        \\    private var resources:ComponentPools
        \\    init() { self.resources = ComponentPools() }
        \\    func seed<T>(value:T) { self.resources.insert(ComponentPool<T>(value)) }
        \\    func has<T>() bool { return self.resources.has<ComponentPool<T>>() }
        \\    func query_pool<T>() @self:ComponentPool<T> { return self.resources.get<ComponentPool<T>>() }
        \\    func get_mut<T>(entity:Entity) &self:T {
        \\        var pool:&ComponentPool<T> = self.resources.get_mut<ComponentPool<T>>()
        \\        return pool.get_mut(entity)
        \\    }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/ECS/World.sx",
        .data =
        \\use GFX.ECS.Entity.Entity
        \\use GFX.ECS.ComponentPool.ComponentPool
        \\use GFX.ECS.ComponentStore.ComponentStore
        \\public class World {
        \\    private var components:ComponentStore
        \\    init() { self.components = ComponentStore() }
        \\    func seed<T>(value:T) { self.components.seed(value) }
        \\    func read<T>(index:int) @self:T { return self.components.query_pool<T>().get_known(Entity(index:index)) }
        \\    module func query_get_mut<T>(entity:Entity) &self:T { return self.components.get_mut<T>(entity) }
        \\    package func query_count(required:int[]) int { return 0 }
        \\    package func query_archetype_count() int { return 1 }
        \\    package func query_entity_count(archetype:int) int { return 2 }
        \\    package func query_entity(archetype:int, row:int) Entity { return Entity(index:row) }
        \\    package func query_range_start(base:int, count:int, range_start:int) int { return 0 }
        \\    package func query_range_end(base:int, count:int, range_end:int) int { return count }
        \\    module func query_component_id<T>() int { return 0 }
        \\    package func query_archetype_has<T>(archetype:int) bool { return self.components.has<T>() }
        \\    module func query_pool<T>() @self:ComponentPool<T> { return self.components.query_pool<T>() }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/ECS/Query.sx",
        .data =
        \\use GFX.ECS.World.World
        \\public class Query<Pattern> {
        \\    package var world:World
        \\    package let range_start:int
        \\    package let range_end:int
        \\    package init(world:World) { self.world = world; self.range_start = 0; self.range_end = -1 }
        \\    package init(world:World, range_start:int, range_end:int) { self.world = world; self.range_start = range_start; self.range_end = range_end }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application
        \\use GFX.Application.Resources
        \\use GFX.ECS
        \\class Scene {
        \\    private var store:Resources
        \\    init(parent:Resources) { self.store = parent.scope() }
        \\    func resources() Resources { return self.store }
        \\    func add_system<System>(schedule:int, callback:System) Scene { panic("unspecialized system") }
        \\    module func __silex_add_system(schedule:int, callback:func(Scene, int), after:bool, reads:str[], writes:str[], flags:uint) Scene { callback(self, 0); return self }
        \\    module func __silex_run_query(count:int, system_order:int, commands_address:uint, callback:func(Scene, int, int, int, uint)) { callback(self, system_order, 0, count, commands_address) }
        \\    drop { self.store.clear() }
        \\}
        \\struct Position { var x:int; var items:int[] }
        \\func inspect(query:ECS.Query<(ECS.Entity, ECS.Entity)>) {
        \\    for (first, second) in query {
        \\        if first.index == second.index { return }
        \\    }
        \\}
        \\func inspect_components(query:ECS.Query<(ECS.Entity, @Position)>) {
        \\    for (entity, position) in query {
        \\        if entity.index == position.x { return }
        \\    }
        \\}
        \\func parallel_inspect(query:ECS.Query<(ECS.Entity, ECS.Entity)>) {
        \\    for (first, second) in query {}
        \\}
        \\func mutate_components(query:ECS.Query<(ECS.Entity, &Position)>) {
        \\    var visited = 0
        \\    for (entity, position) in query {
        \\        position.x += entity.index + 1
        \\        position.items[0] += entity.index + 1
        \\        visited++
        \\    }
        \\    assert(visited == 2)
        \\}
        \\func sample() int {
        \\    var application = Application()
        \\    var world = ECS.World()
        \\    let before = Position(x:40, items:[9])
        \\    world.seed(before)
        \\    application.resources().insert(world)
        \\    application.add_system(0, mutate_components)
        \\    assert(before.x == 40 && before.items[0] == 9)
        \\    assert(world.read<Position>(0).x == 41)
        \\    assert(world.read<Position>(0).items[0] == 10)
        \\    assert(world.read<Position>(1).items[0] == 11)
        \\    return world.read<Position>(1).x
        \\}
        \\func main() {
        \\    print(sample())
        \\    var application = Application()
        \\    application.resources().insert(ECS.World())
        \\    application.add_system(0, inspect)
        \\    application.add_system(0, inspect_components)
        \\    var scene = Scene(application.resources())
        \\    scene.resources().insert(ECS.World())
        \\    scene.add_system(0, parallel_inspect)
        \\}
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(try inputPath(allocator, temporary));
    const text = try Ir.writeText(allocator, compilation.ir);
    const start = std.mem.indexOf(u8, text, "func @GFX.Smokes.Main.inspect(") orelse return error.TestUnexpectedResult;
    const tail = text[start..];
    const finish = std.mem.indexOf(u8, tail, "\n}\n") orelse return error.TestUnexpectedResult;
    const function_text = tail[0 .. finish + 3];
    try std.testing.expectEqual(@as(usize, 0), std.mem.count(u8, function_text, "list.init"));
    try std.testing.expectEqual(@as(usize, 0), std.mem.count(u8, function_text, "list.drop"));
    const component_start = std.mem.indexOf(u8, text, "func @GFX.Smokes.Main.inspect_components(") orelse return error.TestUnexpectedResult;
    const component_tail = text[component_start..];
    const component_finish = std.mem.indexOf(u8, component_tail, "\n}\n") orelse return error.TestUnexpectedResult;
    const component_text = component_tail[0 .. component_finish + 3];
    try std.testing.expectEqual(@as(usize, 0), std.mem.count(u8, component_text, ".get_known#"));
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, component_text, "collection.load"));
    const mutable_start = std.mem.indexOf(u8, text, "func @GFX.Smokes.Main.mutate_components(") orelse return error.TestUnexpectedResult;
    const mutable_tail = text[mutable_start..];
    const mutable_finish = std.mem.indexOf(u8, mutable_tail, "\n}\n") orelse return error.TestUnexpectedResult;
    const mutable_text = mutable_tail[0 .. mutable_finish + 3];
    try std.testing.expectEqual(@as(usize, 0), std.mem.count(u8, mutable_text, "query_get_mut<"));
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, mutable_text, "ComponentPools.get_mut<"));
    const mutable_function = for (compilation.ir.functions) |candidate| {
        if (std.mem.eql(u8, candidate.name, "GFX.Smokes.Main.mutate_components")) break candidate;
    } else return error.TestUnexpectedResult;
    var pool_block: ?usize = null;
    var entity_block: ?usize = null;
    for (mutable_function.blocks, 0..) |block, block_index| {
        for (block.instructions) |instruction| switch (instruction) {
            .call => |call| {
                const name = compilation.ir.functions[call.function].name;
                if (std.mem.indexOf(u8, name, "ComponentPools.get_mut<") != null) pool_block = block_index;
                if (std.mem.indexOf(u8, name, "World.query_entity#") != null) entity_block = block_index;
            },
            .collection_load => |load| try std.testing.expect(load.checked),
            .collection_reference => |reference| {
                try std.testing.expect(reference.checked);
                try std.testing.expect(reference.reference != null);
            },
            else => {},
        };
    }
    try std.testing.expect(pool_block != null and entity_block != null);
    try std.testing.expect(pool_block.? != entity_block.?);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("42\n", result.stdout);
    _ = try Lower.lower(allocator, compilation.ir);
    if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
        const function = for (compilation.ir.functions, 0..) |candidate, index| {
            if (std.mem.eql(u8, candidate.name, "GFX.Smokes.Main.sample")) break @as(Ir.FunctionId, @intCast(index));
        } else return error.TestUnexpectedResult;
        const machine = try Lower.lowerWithMode(allocator, compilation.ir, .release);
        const native = try Runner.invoke(allocator, machine, function, &.{});
        try std.testing.expectEqual(@as(@TypeOf(native.status), .success), native.status);
        try std.testing.expectEqual(@as(i64, 42), native.value);
    }
}

test "ECS queries cannot escape their injected system function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try prepare(&temporary);
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module/ECS");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/ECS/@Module.sx",
        .data =
        \\public use GFX.ECS.Entity.Entity
        \\public use GFX.ECS.World.World
        \\public use GFX.ECS.Query.Query
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/ECS/Entity.sx",
        .data = "public struct Entity { let value:int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/ECS/World.sx",
        .data =
        \\use GFX.ECS.Entity.Entity
        \\public class World {
        \\    package func query_archetype_count() int { return 0 }
        \\    package func query_entity_count(archetype:int) int { return 0 }
        \\    package func query_entity(archetype:int, row:int) Entity { return Entity(value:0) }
        \\    package func query_range_start(base:int, count:int, range_start:int) int { return 0 }
        \\    package func query_range_end(base:int, count:int, range_end:int) int { return 0 }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/ECS/Query.sx",
        .data =
        \\use GFX.ECS.World.World
        \\public class Query<Pattern> {
        \\    package var world:World
        \\    package let range_start:int
        \\    package let range_end:int
        \\    package init(world:World) { self.world = world; self.range_start = 0; self.range_end = -1 }
        \\    package init(world:World, range_start:int, range_end:int) { self.world = world; self.range_start = range_start; self.range_end = range_end }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application
        \\use GFX.ECS
        \\func consume(query:ECS.Query<(ECS.Entity, ECS.Entity)>) {}
        \\func simulate(query:ECS.Query<(ECS.Entity, ECS.Entity)>) { consume(query) }
        \\func main() { var application = Application(); application.add_system(0, simulate) }
        ,
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(try inputPath(allocator, temporary)));
    try std.testing.expectEqualStrings(
        "ECS.Query is a system-owned capability and cannot be passed to another function; iterate it directly in the system function",
        compiler.diagnostic.?.message,
    );
    try std.testing.expectEqual(@as(usize, 4), compiler.diagnostic.?.position.line);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application
        \\use GFX.ECS
        \\func observe(query:@ECS.Query<(ECS.Entity, ECS.Entity)>) {}
        \\func simulate(query:ECS.Query<(ECS.Entity, ECS.Entity)>) { observe(query) }
        \\func main() { var application = Application(); application.add_system(0, simulate) }
        ,
    });
    var borrowed_compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, borrowed_compiler.compile(try inputPath(allocator, temporary)));
    try std.testing.expectEqualStrings(
        "ECS.Query is a system-owned capability and cannot be passed to another function; iterate it directly in the system function",
        borrowed_compiler.diagnostic.?.message,
    );
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
        \\use GFX.Application
        \\public struct State { var value:int }
        \\func update(state:&State) { state.value += 2 }
        \\public func install(application:Application) { application.add_system(0, update) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Smokes/Main.sx",
        .data =
        \\use GFX.Application
        \\use GFX.Feature
        \\func update() { print("entry callback") }
        \\func main() {
        \\    var application = Application()
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
        \\use GFX.Application
        \\struct Time { let delta:int }
        \\func update(time:@Time) { print(time.delta) }
        \\func main() { var application = Application(); application.add_system(0, update) }
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
        .{ .system = "func invalid(application:Application, state:@State) {}", .expected = "system host must be the sole" },
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
            "use GFX.Application\nstruct State {{ var value:int }}\n{s}\nfunc main() {{ var application = Application(); application.add_system(0, invalid) }}",
            .{case.system},
        );
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GFX/Smokes/Main.sx", .data = source });
        var compiler = Project.Compiler.init(allocator, std.testing.io);
        try std.testing.expectError(error.InvalidSource, compiler.compile(try inputPath(allocator, temporary)));
        try std.testing.expect(std.mem.indexOf(u8, compiler.diagnostic.?.message, case.expected) != null);
    }
}
