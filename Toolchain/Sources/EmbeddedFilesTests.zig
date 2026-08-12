const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const NativeTestRunner = @import("NativeTestRunner.zig");
const Project = @import("Project.zig");

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "embed UTF-8 text and track its source as a cache dependency" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Web");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Web/index.html",
        .data = "<main>embedded</main>",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\func main() {
        \\    let page = embed_text("Web/index.html")
        \\    print(page)
        \\}
        ,
    });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const input = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const asset_path = try std.fs.path.join(allocator, &.{ root, "Web", "index.html" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("<main>embedded</main>\n", result.stdout);

    var tracked = false;
    for (compilation.files) |path| tracked = tracked or std.mem.eql(u8, path, asset_path);
    try std.testing.expect(tracked);
}

test "require the embedded text path at compile time" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Web");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Web/index.html", .data = "embedded" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\func main() {
        \\    var path = "Web/index.html"
        \\    let page = embed_text(path)
        \\}
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("embedded file path must be a string known at compile time", compiler.diagnostic.?.message);
}

test "embed arbitrary bytes compactly and track the source as a cache dependency" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    const expected = [_]u8{ 0x00, 0x89, 0xff, 0x0a, 0x42 };
    var larger: [300]u8 = undefined;
    for (&larger, 0..) |*byte, index| byte.* = @intCast(index % 251);
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "asset.bin", .data = &expected });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "larger.bin", .data = &larger });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "empty.bin", .data = "" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\func main() {
        \\    var bytes = embed_bytes("asset.bin")
        \\    let larger = embed_bytes("larger.bin")
        \\    let other = embed_bytes("asset.bin")
        \\    let empty = embed_bytes("empty.bin")
        \\    assert(empty.is_empty())
        \\    bytes[0] = 7 as uint8
        \\    print(bytes.count(), " ", bytes[0], " ", bytes[1], " ", bytes[2], " ", bytes[3], " ", bytes[4], " ", other[0])
        \\    print(larger.count(), " ", larger[0], " ", larger[250], " ", larger[251], " ", larger[299])
        \\}
        ,
    });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const input = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const asset_path = try std.fs.path.join(allocator, &.{ root, "asset.bin" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const interpreted = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        "5 7 137 255 10 66 0\n300 0 250 0 48\n",
        interpreted.stdout,
    );

    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "const.bytes 0x0089ff0a42") != null);
    var tracked = false;
    for (compilation.files) |path| tracked = tracked or std.mem.eql(u8, path, asset_path);
    try std.testing.expect(tracked);

    const builtin = @import("builtin");
    if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
        const machine = try NativeTestRunner.lower(allocator, std.testing.io, compilation.ir, compilation.boundaries, false);
        const main = for (compilation.ir.functions, 0..) |function, index| {
            if (std.mem.eql(u8, function.name, "main")) break index;
        } else return error.InvalidProgram;
        const native = try NativeTestRunner.execute(
            allocator,
            std.testing.io,
            .macos_arm64,
            "zig",
            machine,
            main,
            input,
            compilation.files,
            &.{},
            false,
        );
        try std.testing.expectEqual(@as(u8, 0), exitCode(native.term));
        try std.testing.expectEqualStrings(interpreted.stdout, native.stdout);
    }
}

test "reserve the embed_text intrinsic name" {
    try expectCompileError(
        "func embed_text(file:str) str { return file } func main() {}",
        "'embed_text' is a reserved intrinsic function name",
    );
    try expectCompileError(
        "func main() { let embed_text = 1 }",
        "'embed_text' is a reserved intrinsic function name",
    );
    try expectCompileError(
        "use Library as embed_text\nfunc main() {}",
        "'embed_text' is a reserved intrinsic function name",
    );
}

test "reserve the embed_bytes intrinsic name" {
    try expectCompileError(
        "func embed_bytes(file:str) uint8[] { return [] } func main() {}",
        "'embed_bytes' is a reserved intrinsic function name",
    );
    try expectCompileError(
        "func main() { let embed_bytes = 1 }",
        "'embed_bytes' is a reserved intrinsic function name",
    );
    try expectCompileError(
        "use Library as embed_bytes\nfunc main() {}",
        "'embed_bytes' is a reserved intrinsic function name",
    );
}

fn exitCode(term: std.process.Child.Term) u8 {
    return switch (term) {
        .exited => |code| code,
        else => 255,
    };
}
