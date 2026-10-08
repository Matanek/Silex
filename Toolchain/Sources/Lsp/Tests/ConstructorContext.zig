const std = @import("std");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");

test "overloaded initializer list arguments preserve runtime variable completion" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const header = "struct Grid {init(values:float[],shape:int[]) {} init(values:int32[],shape:int[]) {}}\nfunc main() {var values:float[]=[1.0];let rows=1;let columns=2;let flag=true;var shape:int[]=[1,2];";
    for ([_][]const u8{ "Grid(values,[<|>])}", "Grid(values:values,shape:[<|>])}" }) |suffix| {
        const source = try std.fmt.allocPrint(allocator, "{s}{s}", .{ header, suffix });
        const items = try Support.serverCompletion(&server, allocator, main_uri, source);
        try Support.expectPresent("rows", items);
        try Support.expectPresent("columns", items);
        try Support.expectAbsent("values", items);
        try Support.expectAbsent("shape", items);
        try Support.expectAbsent("flag", items);
        try Support.expectItem(.{ .label = "rows", .kind = 6, .detail = "rows:int", .insert_text = "rows" }, items);
        try Support.expectNoDuplicates(items);
        const repeated = try Support.serverCompletion(&server, allocator, main_uri, source);
        try Support.expectEqualItems(items, repeated);
    }
}

test "named overloaded function and static method list arguments preserve shared element context" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const header = "func make(choice:int, shape:int[]) {} func make(choice:str, shape:int[]) {}\npublic static struct Factory { func make(choice:int, shape:int[]) {} func make(choice:str, shape:int[]) {} }\nfunc main() {let rows=1;let columns=2;let flag=true;var shape:int[]=[1,2];";
    for ([_][]const u8{ "make(choice:1,shape:[<|>])}", "Factory.make(choice:1,shape:[<|>])}" }) |suffix| {
        const source = try std.fmt.allocPrint(allocator, "{s}{s}", .{ header, suffix });
        const items = try Support.serverCompletion(&server, allocator, main_uri, source);
        try Support.expectPresent("rows", items);
        try Support.expectPresent("columns", items);
        try Support.expectAbsent("shape", items);
        try Support.expectAbsent("flag", items);
        try Support.expectItem(.{ .label = "rows", .kind = 6, .detail = "rows:int", .insert_text = "rows" }, items);
        try Support.expectNoDuplicates(items);
        const repeated = try Support.serverCompletion(&server, allocator, main_uri, source);
        try Support.expectEqualItems(items, repeated);
    }
}
