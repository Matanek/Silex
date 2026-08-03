const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
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
    try std.testing.expectEqualStrings("embedded text file path must be a string known at compile time", compiler.diagnostic.?.message);
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
