const std = @import("std");
const Compiler = @import("../Project.zig").Compiler;
const Interpreter = @import("../Interpreter.zig");

test "private nominal atoms resolve package imports independently of physical order" {
    for ([_][]const u8{ "@A.sx", "@Z.sx" }) |atom| {
        for ([_][]const u8{
            "use Package.Secret\nuse Package.Mode\npublic func answer() int { var value:Secret=Secret(); let mode:Mode=Mode.ready; if mode==Mode.ready {return value.value()} return 0 }",
            "public func answer() int { var value:Package.Secret=Package.Secret(); let mode:Package.Mode=Package.Mode.ready; if mode==Package.Mode.ready {return value.value()} return 0 }",
        }) |consumer| {
            var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
            defer arena.deinit();
            const allocator = arena.allocator();
            var temporary = std.testing.tmpDir(.{});
            defer temporary.cleanup();
            try temporary.dir.createDirPath(std.testing.io, "PrivateAtoms/Module");
            try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "PrivateAtoms/Package.json", .data = "{\"name\":\"PrivateAtoms\",\"version\":\"1.0.0\"}" });
            try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "PrivateAtoms/Module/@M.sx", .data = "public func anchor() int {return 0}" });
            const atom_path = try std.fs.path.join(allocator, &.{ "PrivateAtoms/Module", atom });
            try temporary.dir.writeFile(std.testing.io, .{ .sub_path = atom_path, .data =
                \\package class Secret {init() {} func value() int {return 42}}
                \\package enum Mode {ready}
            });
            try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "PrivateAtoms/Module/Child.sx", .data = consumer });
            try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "PrivateAtoms/Module/Main.sx", .data = "use Package.Child\nfunc main() {print(Child.answer())}" });
            const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "PrivateAtoms", "Module", "Main.sx" });
            var compiler = Compiler.init(allocator, std.testing.io);
            const compilation = try compiler.compile(input);
            const result = try Interpreter.runCapture(allocator, compilation.ir);
            try std.testing.expectEqualStrings("42\n", result.stdout);
        }
    }
}

test "private nominal atoms keep package and file visibility after resolution" {
    for ([_][]const u8{ "Secret", "Mode" }) |name| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var temporary = std.testing.tmpDir(.{});
        defer temporary.cleanup();
        try temporary.dir.createDirPath(std.testing.io, "Api/Module");
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package.json", .data = "{\"sources\":\".\",\"dependencies\":{\"Api\":\"=1.0.0\"}}" });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Api/Package.json", .data = "{\"name\":\"Api\",\"version\":\"1.0.0\"}" });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Api/Module/@First.sx", .data = "public func anchor() {}" });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Api/Module/@Second.sx", .data = "package struct Secret {}\npackage enum Mode {ready}" });
        const main = try std.fmt.allocPrint(allocator, "use Api.{s}\nfunc consume(value:{s}) {{}}\nfunc main() {{}}", .{ name, name });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = main });
        const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
        var compiler = Compiler.init(allocator, std.testing.io);
        try std.testing.expectError(error.InvalidSource, compiler.compile(input));
        try std.testing.expect(std.mem.indexOf(u8, compiler.diagnostic.?.message, "package-visible and unavailable outside package 'Api'") != null);
    }
    for ([_][]const u8{ "Secret", "Mode" }) |name| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var temporary = std.testing.tmpDir(.{});
        defer temporary.cleanup();
        try temporary.dir.createDirPath(std.testing.io, "PrivateAtoms/Module");
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "PrivateAtoms/Package.json", .data = "{\"name\":\"PrivateAtoms\",\"version\":\"1.0.0\"}" });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "PrivateAtoms/Module/@First.sx", .data = "public func anchor() {}" });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "PrivateAtoms/Module/@Second.sx", .data = "local struct Secret {}\nlocal enum Mode {ready}" });
        const main = try std.fmt.allocPrint(allocator, "use Package.{s}\nfunc consume(value:{s}) {{}}\nfunc main() {{}}", .{ name, name });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "PrivateAtoms/Module/Main.sx", .data = main });
        const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "PrivateAtoms/Module/Main.sx" });
        var compiler = Compiler.init(allocator, std.testing.io);
        try std.testing.expectError(error.InvalidSource, compiler.compile(input));
        try std.testing.expect(std.mem.indexOf(u8, compiler.diagnostic.?.message, "local to its source file") != null);
    }
}

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
