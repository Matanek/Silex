const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const builtin = @import("builtin");
const Lower = @import("Arm64/Lower.zig");
const MachO = @import("MacOS/MachO.zig");
const Arm64Encoder = @import("Arm64/Encoder.zig");
const X64Encoder = @import("X64/Encoder.zig");

fn compile(allocator: std.mem.Allocator, source: []const u8) !Ir.Program {
    var frontend = Frontend.Frontend.init(allocator);
    return (try frontend.compile(source)).ir;
}

test "mutex is recursive across helper calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(allocator,
        \\func nested() { mutex { print("nested") } }
        \\func main() { mutex { nested() } }
    );
    const result = try Interpreter.runCapture(allocator, program);
    try std.testing.expectEqualStrings("nested\n", result.stdout);
}

test "mutex unlocks before returning from its body" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(allocator,
        \\func guarded() int { mutex { return 42 } }
        \\func main() { print(guarded()) }
    );
    const guarded = program.functions[0];
    try std.testing.expectEqual(Ir.Instruction.mutex_lock, guarded.blocks[0].instructions[0]);
    try std.testing.expectEqual(Ir.Instruction.mutex_unlock, guarded.blocks[0].instructions[2]);
    const result = try Interpreter.runCapture(allocator, program);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "break releases only mutexes entered inside the loop" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(allocator,
        \\func main() {
        \\    mutex {
        \\        while true {
        \\            mutex { break }
        \\        }
        \\        print("released")
        \\    }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, program);
    try std.testing.expectEqualStrings("released\n", result.stdout);
}

test "mutex protects a mutating method body" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(allocator,
        \\struct Counter {
        \\    var value:int
        \\    func increment() { mutex { self.value++ } }
        \\}
        \\func main() {
        \\    var counter = Counter(value:41)
        \\    counter.increment()
        \\    print(counter.value)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, program);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "macOS executable enters nested mutex blocks" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(allocator,
        \\func nested() { mutex {} }
        \\func main() { mutex { nested() } }
    );
    const machine = try Lower.lower(allocator, program);
    const executable = try MachO.emit(allocator, machine);
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const file = try temporary.dir.createFile(std.testing.io, "mutex-app", .{ .permissions = .executable_file });
    defer file.close(std.testing.io);
    try file.writeStreamingAll(std.testing.io, executable);
    try file.setPermissions(std.testing.io, .executable_file);
    const path = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "mutex-app" });
    var child = try std.process.spawn(std.testing.io, .{
        .argv = &.{path},
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .inherit,
    });
    defer child.kill(std.testing.io);
    const termination = try child.wait(std.testing.io);
    try std.testing.expectEqual(@as(u8, 0), switch (termination) {
        .exited => |code| code,
        else => 255,
    });
}

test "every native target encoder accepts mutex" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(allocator,
        \\func nested() { mutex {} }
        \\func main() { mutex { nested() } }
    );
    const machine = try Lower.lower(allocator, program);
    var linux = try X64Encoder.encodeLinux(allocator, machine);
    defer linux.deinit(allocator);
    var windows_x64 = try X64Encoder.encodeWindows(allocator, machine);
    defer windows_x64.deinit(allocator);
    var windows_arm64 = try Arm64Encoder.encodeWindows(allocator, machine, .{ .executable_main = 1 });
    defer windows_arm64.deinit(allocator);
    var windows_arm64_test = try Arm64Encoder.encodeWindows(allocator, machine, .{ .test_function = 0 });
    defer windows_arm64_test.deinit(allocator);
    try std.testing.expect(linux.code.len != 0);
    try std.testing.expect(windows_x64.windows_import_sites.len >= 3);
    try std.testing.expect(windows_arm64.external_call_sites.len >= 3);
    var initializes_test_mutex = false;
    for (windows_arm64_test.external_call_sites) |site| {
        if (site.windows_symbol == .initialize_critical_section) initializes_test_mutex = true;
    }
    try std.testing.expect(initializes_test_mutex);
}
