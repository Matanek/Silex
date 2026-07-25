const std = @import("std");
const builtin = @import("builtin");
const Encoder = @import("Encoder.zig");
const Lower = @import("Lower.zig");
const Machine = @import("Machine.zig");

const Allocator = std.mem.Allocator;

pub const Error = Encoder.Error || std.posix.MMapError || std.process.ProtectMemoryError || error{
    InvalidNativeStatus,
    UnsupportedHost,
};

pub const Result = struct {
    value: i64,
    status: Machine.Status,
};

const RawResult = extern struct {
    value: i64,
    status: u64,
};

const NativeFunction = *const fn (
    i64,
    i64,
    i64,
    i64,
    i64,
    i64,
    i64,
    i64,
) callconv(.c) RawResult;

extern "c" fn sys_icache_invalidate(start: *anyopaque, length: usize) void;

pub fn invoke(
    allocator: Allocator,
    program: Machine.Program,
    function: Machine.FunctionId,
    arguments: []const i64,
) Error!Result {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.UnsupportedHost;
    if (function >= program.functions.len or arguments.len != program.functions[function].parameter_count) {
        return error.InvalidMachineProgram;
    }
    const image = try Encoder.encode(allocator, program, .{ .test_function = function });
    defer image.deinit(allocator);
    const entry_offset = image.entry_offset orelse return error.InvalidMachineProgram;
    const mapped_size = std.mem.alignForward(usize, image.code.len, std.heap.page_size_min);
    const memory = try std.posix.mmap(
        null,
        mapped_size,
        .{ .READ = true, .WRITE = true },
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
        -1,
        0,
    );
    defer std.posix.munmap(memory);
    @memcpy(memory[0..image.code.len], image.code);
    try std.process.protectMemory(memory, .{ .read = true, .execute = true });
    sys_icache_invalidate(memory.ptr, image.code.len);

    const entry_address = @intFromPtr(memory.ptr) + entry_offset;
    const native: NativeFunction = @ptrFromInt(entry_address);
    var padded_arguments = [_]i64{0} ** Machine.max_register_arguments;
    @memcpy(padded_arguments[0..arguments.len], arguments);
    const raw = native(
        padded_arguments[0],
        padded_arguments[1],
        padded_arguments[2],
        padded_arguments[3],
        padded_arguments[4],
        padded_arguments[5],
        padded_arguments[6],
        padded_arguments[7],
    );
    const status: Machine.Status = switch (raw.status) {
        0 => .success,
        1 => .integer_overflow,
        2 => .division_by_zero,
        else => return error.InvalidNativeStatus,
    };
    return .{ .value = raw.value, .status = status };
}

fn compile(allocator: Allocator, source: []const u8) !Machine.Program {
    var frontend = @import("../Frontend.zig").Frontend.init(allocator);
    return Lower.lower(allocator, (try frontend.compile(source)).ir);
}

test "execute answer directly on the ARM64 host" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(allocator,
        \\func answer() int { return 40 + 2 }
        \\func main() {}
    );
    const result = try invoke(allocator, program, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), result.value);
    try std.testing.expectEqual(Machine.Status.success, result.status);
}
