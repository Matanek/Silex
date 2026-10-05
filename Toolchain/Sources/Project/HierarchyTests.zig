const std = @import("std");
const Compiler = @import("../Project.zig").Compiler;
const Interpreter = @import("../Interpreter.zig");

test "hierarchical module cycles compose protocol signatures from either entry order" {
    for ([_][]const u8{ "use Group\nuse Group.Rules", "use Group.Rules\nuse Group" }) |imports| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var temporary = std.testing.tmpDir(.{});
        defer temporary.cleanup();
        try temporary.dir.createDirPath(std.testing.io, "Group");
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/@Value.sx", .data =
            \\use Group.Rules
            \\public struct Value { var amount:int }
            \\public func apply(operation:Rules.Operation, input:Value) Value {
            \\    var active = operation
            \\    return active.forward(input)
            \\}
        });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/Rules.sx", .data =
            \\use Group
            \\public protocol Operation { func forward(input:Group.Value) Group.Value }
        });
        const main = try std.fmt.allocPrint(allocator,
            \\{s}
            \\struct Double:Rules.Operation {{
            \\    func forward(input:Group.Value) Group.Value {{ return Group.Value(amount:input.amount * 2) }}
            \\}}
            \\func main() {{ print(Group.apply(Double(), Group.Value(amount:21)).amount) }}
        , .{imports});
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = main });
        const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
        var compiler = Compiler.init(allocator, std.testing.io);
        const compilation = try compiler.compile(input);
        const result = try Interpreter.runCapture(allocator, compilation.ir);
        try std.testing.expectEqualStrings("42\n", result.stdout);
    }
}

test "hierarchical module cycles allow a distant descendant" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Group/Nested");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "use Group\nfunc main() { print(Group.answer()) }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/@Value.sx", .data = "use Group.Nested.Rules\npublic func base() int { return 21 }\npublic func answer() int { return Rules.twice() }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/Nested/Rules.sx", .data = "use Group\npublic func twice() int { return Group.base() * 2 }" });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "hierarchical module cycles reject a textual prefix without ancestry" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Group");
    try temporary.dir.createDirPath(std.testing.io, "Grouped");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "use Group\nfunc main() { Group.answer() }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/@Value.sx", .data = "use Grouped.Rules\npublic func answer() {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Grouped/Rules.sx", .data = "use Group\npublic func answer() {}" });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("module dependency cycle crosses logical parents", compiler.diagnostic.?.message);
}

test "hierarchical module cycles cannot conceal an unrelated intermediate branch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Group");
    try temporary.dir.createDirPath(std.testing.io, "Other");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "use Group\nfunc main() { Group.answer() }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/@Value.sx", .data = "use Other.Middle\npublic func answer() {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Other/Middle.sx", .data = "use Group.Rules\npublic func answer() {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/Rules.sx", .data = "use Group\npublic func answer() {}" });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("module dependency cycle crosses logical parents", compiler.diagnostic.?.message);
}
