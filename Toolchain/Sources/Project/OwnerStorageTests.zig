const std = @import("std");
const Compiler = @import("../Project.zig").Compiler;
const Interpreter = @import("../Interpreter.zig");

test "composed module owner storage is accessible across atoms with ordinary member visibility" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Group");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/@Owner.sx", .data = "public class Owner { module var value:int = 21; init() {} drop {} }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/@Read.sx", .data = "public func twice(owner:Owner) int { owner.value *= 2; return owner.value }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "use Group\nfunc main() { var owner=Group.Owner(); print(Group.twice(owner)) }" });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "composed module owner storage preserves private fields and unrelated module boundary" {
    for ([_]bool{ true, false }) |private_field| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var temporary = std.testing.tmpDir(.{});
        defer temporary.cleanup();
        try temporary.dir.createDirPath(std.testing.io, "Group");
        try temporary.dir.createDirPath(std.testing.io, "Other");
        const owner = if (private_field) "public class Owner { private var value:int = 21; init() {} drop {} }" else "public class Owner { public var value:int = 21; init() {} drop {} }";
        const read_path = if (private_field) "Group/@Read.sx" else "Other/Read.sx";
        const read = if (private_field) "public func read(owner:Owner) int { return owner.value }" else "use Group\npublic func read(owner:Group.Owner) int { return owner.value }";
        const main = if (private_field) "use Group\nfunc main() { var owner=Group.Owner(); print(Group.read(owner)) }" else "use Group\nuse Other.Read\nfunc main() { var owner=Group.Owner(); print(Read.read(owner)) }";
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Group/@Owner.sx", .data = owner });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = read_path, .data = read });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = main });
        const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
        var compiler = Compiler.init(allocator, std.testing.io);
        try std.testing.expectError(error.InvalidSource, compiler.compile(input));
        if (private_field) {
            try std.testing.expect(std.mem.indexOf(u8, compiler.diagnostic.?.message, "private") != null);
        } else {
            try std.testing.expectEqualStrings("owner structure storage is private to its declaring file and direct module users", compiler.diagnostic.?.message);
        }
    }
}
