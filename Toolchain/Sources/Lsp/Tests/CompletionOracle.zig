const std = @import("std");
const FrontendModule = @import("../../Frontend.zig");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");

fn publicInstanceMembers(
    allocator: std.mem.Allocator,
    source: []const u8,
    type_name: []const u8,
) ![]const []const u8 {
    var frontend = FrontendModule.Frontend.init(allocator);
    const program = (try frontend.compile(source)).ast;
    var labels: std.ArrayList([]const u8) = .empty;
    for (program.structures) |structure| {
        if (!std.mem.eql(u8, structure.name, type_name)) continue;
        for (structure.fields) |field| {
            if (field.is_static or !field.is_public or field.is_private or field.is_protected or field.is_local) continue;
            try labels.append(allocator, field.name);
        }
        for (structure.methods) |method| {
            if (method.is_static or !method.is_public or method.is_private or method.is_protected or method.is_local) continue;
            try labels.append(allocator, method.name);
        }
        std.mem.sort([]const u8, labels.items, {}, struct {
            fn lessThan(_: void, left: []const u8, right: []const u8) bool {
                return std.mem.lessThan(u8, left, right);
            }
        }.lessThan);
        return labels.toOwnedSlice(allocator);
    }
    return error.MissingOracleType;
}

test "complete source syntax provides an oracle independent from LSP recovery" {
    const canonical =
        \\public class Widget {
        \\    public var opacity:float = 0.0
        \\    public func clear() {}
        \\    public func paint() {}
        \\    private func secret() {}
        \\}
        \\func main() {
        \\    var widget = Widget()
        \\    widget.paint()
        \\}
    ;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Api/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"Api\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api/Package.json",
        .data = "{\"name\":\"Api\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Api/Module/Widget.sx", .data = canonical });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const expected = try publicInstanceMembers(allocator, canonical, "Widget");

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const actual = try Support.serverCompletionAfterTrigger(
        &server,
        allocator,
        main_uri,
        "use Api.Widget\nfunc main() { Widget().<|> }",
        ".",
    );
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected) |label| try Support.expectPresent(label, actual);
    try Support.expectAbsent("secret", actual);
    try Support.expectNoDuplicates(actual);
}

test "semantic oracle rejects a parsed but ill-typed canonical source" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectError(
        error.InvalidSource,
        publicInstanceMembers(
            arena.allocator(),
            "public class Widget { public func value() int { return false } } func main() {}",
            "Widget",
        ),
    );
}
