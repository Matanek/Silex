const std = @import("std");
const Support = @import("Support.zig");
const Project = @import("../../Project.zig");
const Server = @import("../Server.zig").Server;

fn item(items: anytype, name: []const u8) ?@import("../Types.zig").CompletionItem {
    for (items) |candidate| if (std.mem.eql(u8, candidate.label, name)) return candidate;
    return null;
}

fn compile(allocator: std.mem.Allocator, source: []const u8) !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = source });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    _ = compiler.compile(input) catch |err| {
        if (compiler.diagnostic) |diagnostic| std.debug.print("{s}\n", .{diagnostic.message});
        return err;
    };
}

const header =
    \\use Interop.C
    \\struct Point { let x:float64; let y:float64 }
    \\func worker(value:float64) float64 { return value+value }
    \\func worker_text(value:str) str { return value }
    \\
;

test "C callback completion inserts bare static references and immutable aliases" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const setup = header ++ "func main() { let alias=worker; var changing=worker; let captured=2.0; let closed:func(float64) float64=func(value:float64) float64 { return value+captured }; let pointer=C.function_address(";
    try compile(allocator, setup ++ "worker) }");
    for ([_][]const u8{ "<|>", "wo<|>", "al<|>" }) |partial| {
        const source = try std.fmt.allocPrint(allocator, "{s}{s}) }}", .{ setup, partial });
        const items = try Support.complete(allocator, source);
        const name = if (std.mem.startsWith(u8, partial, "al")) "alias" else "worker";
        const candidate = item(items, name) orelse return error.TestExpectedEqual;
        try std.testing.expectEqualStrings(name, candidate.insertText orelse candidate.label);
        try std.testing.expect(item(items, "worker_text") == null);
        try std.testing.expect(item(items, "changing") == null);
        try std.testing.expect(item(items, "closed") == null);
        try Support.expectNoDuplicates(items);
        try Support.expectEqualItems(items, try Support.complete(allocator, source));
    }
}

test "C callback completion contextualizes C.call address and flat record arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const setup = header ++ "func main() { let entry:uint=0; let entry_text:str=\"\"; let point=Point(x:1.0,y:2.0); let point_text=\"\"; let result=";
    try compile(allocator, setup ++ "C.call<func(Point) float64>(entry,point) }");
    for ([_]struct { partial: []const u8, wanted: []const u8, forbidden: []const u8, strict: bool = true }{
        .{ .partial = "C.call<func(Point) float64>(en<|>,point)", .wanted = "entry", .forbidden = "entry_text", .strict = false },
        .{ .partial = "C.call<func(Point) float64>(entry,po<|>)", .wanted = "point", .forbidden = "point_text", .strict = false },
        .{ .partial = "C.call<func(Point) float64>(<|>,point)", .wanted = "entry", .forbidden = "entry_text" },
        .{ .partial = "C.call<func(Point) float64>(entry,<|>)", .wanted = "point", .forbidden = "point_text" },
    }) |case| {
        const source = try std.fmt.allocPrint(allocator, "{s}{s} }}", .{ setup, case.partial });
        const items = try Support.complete(allocator, source);
        try std.testing.expect(item(items, case.wanted) != null);
        if (case.strict) {
            try std.testing.expect(item(items, case.forbidden) == null);
        } else {
            var wanted_index: usize = items.len;
            var other_index: usize = items.len;
            for (items, 0..) |candidate, index| {
                if (std.mem.eql(u8, candidate.label, case.wanted)) wanted_index = index;
                if (std.mem.eql(u8, candidate.label, case.forbidden)) other_index = index;
            }
            try std.testing.expect(wanted_index < other_index);
        }
        try Support.expectNoDuplicates(items);
    }
    const typed = try Support.complete(allocator, header ++ "func main() { let result=C.call<func(Po<|>) float64>(0 as uint,Point(x:1.0,y:2.0)) }");
    try std.testing.expect(item(typed, "Point") != null);
    try std.testing.expect(item(typed, "worker") == null);
}

test "C callback completion keeps imported functions bare through the server" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Helpers.sx", .data = "public func worker(value:float64) float64 { return value+value }\n" });
    const marked = "use Interop.C\nuse Helpers.worker\nfunc main() { let address=C.function_address(wo<|>) }\n";
    const canonical = "use Interop.C\nuse Helpers.worker\nfunc main() { let address=C.function_address(worker) }\n";
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = canonical });
    const root = try temporary.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    const path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    _ = try compiler.compile(path);
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{path});
    var server = Server.init(allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const items = try Support.serverCompletion(&server, allocator, uri, marked);
    const worker = item(items, "worker") orelse return error.TestExpectedEqual;
    try std.testing.expectEqualStrings("worker", worker.insertText orelse worker.label);
    try Support.expectNoDuplicates(items);
}

test "C callback completion keeps generic and capture-free local references discoverable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const generic = "use Interop.C\nfunc worker<T>(value:T) T { return value }\nfunc worker_text<T>(value:str) str { return value }\n";
    try compile(allocator, generic ++ "func main() { let pointer=C.function_address<float64>(worker) }");
    const items = try Support.complete(allocator, generic ++ "func main() { let pointer=C.function_address<float64>(wo<|>) }");
    const worker = item(items, "worker") orelse return error.TestExpectedEqual;
    try std.testing.expectEqualStrings("worker", worker.insertText orelse worker.label);
    try std.testing.expect(item(items, "worker_text") == null);
    try Support.expectNoDuplicates(items);
    const setup = "use Interop.C\nfunc main() { let callback:func(float64) float64=func(value:float64) float64 { return value+value }; let pointer=C.function_address(";
    try compile(allocator, setup ++ "callback) }");
    const local_items = try Support.complete(allocator, setup ++ "ca<|>) }");
    const callback = item(local_items, "callback") orelse return error.TestExpectedEqual;
    try std.testing.expectEqualStrings("callback", callback.insertText orelse callback.label);
    try Support.expectNoDuplicates(local_items);
}

test "C callback completion keeps static members bare and excludes bound methods" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const setup = "use Interop.C\nstruct Workers { static func worker(value:float64) float64 { return value } static func text(value:str) str { return value } func bound(value:float64) float64 { return value } }\nfunc main() { let pointer=C.function_address(Workers.";
    try compile(allocator, setup ++ "worker) }");
    for ([_][]const u8{ "<|>", "wo<|>" }) |partial| {
        const source = try std.fmt.allocPrint(allocator, "{s}{s}) }}", .{ setup, partial });
        const items = try Support.complete(allocator, source);
        const worker = item(items, "worker") orelse return error.TestExpectedEqual;
        try std.testing.expectEqualStrings("worker", worker.insertText orelse worker.label);
        try std.testing.expect(item(items, "text") == null);
        try std.testing.expect(item(items, "bound") == null);
        try Support.expectNoDuplicates(items);
    }
}

test "C callback completion resolves the local reference before a namespaced homonym" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Helpers.sx", .data = "public func worker(value:uint) uint { return value }\n" });
    const marked = "use Interop.C\nuse Helpers\nfunc worker(value:float64) float64 { return value+value }\nfunc main() { let pointer=C.function_address(wo<|>) }";
    const canonical = "use Interop.C\nuse Helpers\nfunc worker(value:float64) float64 { return value+value }\nfunc main() { let pointer=C.function_address(worker) }";
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = canonical });
    const root = try temporary.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    const path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(path);
    const ir = try @import("../../Ir.zig").writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, ir, "c_function @Main.worker") != null);
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{path});
    var server = Server.init(allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const items = try Support.serverCompletion(&server, allocator, uri, marked);
    const worker = item(items, "worker") orelse return error.TestExpectedEqual;
    try std.testing.expectEqualStrings("worker", worker.insertText orelse worker.label);
    try Support.expectNoDuplicates(items);
}
