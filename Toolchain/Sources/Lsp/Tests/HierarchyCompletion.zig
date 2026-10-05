const std = @import("std");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");

test "hierarchical module cycles preserve protocol completion and definition" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Group");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/@Value.sx", .data = "use Group.Rules\npublic struct Value {var amount:int}\npublic func apply(operation:Rules.Operation, input:Value) Value {var active=operation;return active.forward(input)}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/Rules.sx", .data = "use Group\npublic protocol Operation {func forward(input:Group.Value) Group.Value}\nlocal struct Hidden {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const rule_uri = try std.fmt.allocPrint(allocator, "file://{s}/Group/Rules.sx", .{root});
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    for ([_][]const u8{ "use Group.Rules.<|>", "use Group.Rules.Op<|>", "use Group.Rules\nfunc inspect(operation:Rules.<|>) {}" }) |source| {
        const items = try Support.serverCompletion(&server, allocator, main_uri, source);
        try Support.expectPresent("Operation", items);
        try Support.expectAbsent("Hidden", items);
        try Support.expectNoDuplicates(items);
        const repeated = try Support.serverCompletion(&server, allocator, main_uri, source);
        try Support.expectEqualItems(items, repeated);
    }
    const target = (try Support.serverDefinition(&server, allocator, main_uri, "use Group.Rules\nfunc inspect(operation:Rules.Oper<|>ation) {}")) orelse return error.MissingDefinition;
    try std.testing.expectEqualStrings(rule_uri, target.uri);
    try std.testing.expectEqual(@as(usize, 1), target.range.start.line);
}

test "composed module owner storage completion preserves member scope" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Group");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/@Owner.sx", .data = "public class Owner { module var value:int=21; private var hidden:int=0; init() {} drop {} }\nclass LocalOwner {var local_value:int=7; drop {}}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/@Read.sx", .data = "func inspect(owner:Owner) {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const read_uri = try std.fmt.allocPrint(allocator, "file://{s}/Group/@Read.sx", .{root});
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const internal = try Support.serverCompletionAfterTrigger(&server, allocator, read_uri, "func inspect(owner:Owner) {owner.<|>}", ".");
    try Support.expectPresent("value", internal);
    try Support.expectAbsent("hidden", internal);
    try Support.expectNoDuplicates(internal);
    const local_type = try Support.serverCompletionAfterTrigger(&server, allocator, read_uri, "func inspect(owner:LocalOwner) {owner.<|>}", ".");
    try Support.expectPresent("local_value", local_type);
    const prefix = try Support.serverCompletion(&server, allocator, read_uri, "func inspect(owner:Owner) {owner.va<|>}");
    try Support.expectExactLabels(&.{"value"}, prefix);
    try Support.expectNoDuplicates(prefix);
    const external = try Support.serverCompletionAfterTrigger(&server, allocator, main_uri, "use Group\nfunc inspect(owner:Group.Owner) {owner.<|>}", ".");
    try Support.expectAbsent("value", external);
    try Support.expectAbsent("hidden", external);
}
