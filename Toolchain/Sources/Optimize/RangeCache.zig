//! Cache only the decisions of the function-local interval solver. The key
//! contains exactly its numeric CFG, with no consumer-specific symbol indices.
const std = @import("std");
const Ir = @import("../Ir.zig");
const Binary = @import("../CacheBinary.zig");
const Store = @import("../Llvm/Store.zig").Store;
const Allocator = std.mem.Allocator;

pub const Counters = struct {
    hits: std.atomic.Value(usize) = .init(0),
    misses: std.atomic.Value(usize) = .init(0),
    mutex: std.Io.Mutex = .init,
    pending: std.ArrayList(Store.Fragment) = .empty,
};
pub const Context = struct { store: Store, counters: *Counters };
const Change = struct {
    block: usize,
    instruction: usize,
    kind: enum { binary, conversion, comparison },
    checked: bool = false,
    non_negative: bool = false,
    value: bool = false,
};

pub fn key(allocator: Allocator, function: Ir.Function) !?[32]u8 {
    // Avoid retaining or serializing thousands of trivial functions. These
    // large CFGs account for the measured compilation bottleneck.
    if (function.blocks.len < 16 or function.value_types.len < 64) return null;
    var projected = function;
    projected.name = "";
    projected.source_position = null;
    projected.return_type = .void;
    projected.local_types = &.{};
    projected.parameter_types = try types(allocator, function.parameter_types);
    projected.capture_types = try types(allocator, function.capture_types);
    projected.value_types = try types(allocator, function.value_types);
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, blocks) |block, *output| {
        const instructions = try allocator.alloc(Ir.Instruction, block.instructions.len);
        for (block.instructions, instructions) |instruction, *mapped| {
            mapped.* = switch (instruction) {
                .constant_int, .copy, .deep_copy, .unary, .binary => instruction,
                .convert => |conversion| .{ .convert = .{
                    .result = conversion.result,
                    .operand = conversion.operand,
                    .source = numericType(conversion.source),
                    .target = numericType(conversion.target),
                    .checked = conversion.checked,
                    .position = .{ .offset = 0, .line = 0, .column = 0 },
                } },
                inline else => |payload| unknown: {
                    if (@typeInfo(@TypeOf(payload)) == .@"struct" and @hasField(@TypeOf(payload), "result")) {
                        const result: ?Ir.ValueId = payload.result;
                        if (result) |value| break :unknown .{ .storage_init = .{ .result = value } };
                    }
                    break :unknown .mutex_lock;
                },
            };
        }
        output.* = .{ .instructions = instructions, .terminator = block.terminator };
    }
    projected.blocks = blocks;
    const bytes = try Binary.encode(allocator, projected);
    return Store.key("integer-range-decisions-v1", &.{bytes});
}

fn numericType(value: Ir.Type) Ir.Type {
    return if (value.isInteger()) value else .address;
}
fn types(allocator: Allocator, values: []const Ir.Type) ![]Ir.Type {
    const result = try allocator.alloc(Ir.Type, values.len);
    for (values, result) |value, *out| out.* = numericType(value);
    return result;
}

pub fn load(allocator: Allocator, context: Context, digest: [32]u8, function: Ir.Function) ?Ir.Function {
    const payload = context.store.load(digest) orelse return null;
    const changes = Binary.decode([]Change, allocator, payload) catch return null;
    const blocks = allocator.dupe(Ir.Block, function.blocks) catch return null;
    for (blocks) |*block| block.instructions = allocator.dupe(Ir.Instruction, block.instructions) catch return null;
    for (changes) |change| {
        if (change.block >= blocks.len or change.instruction >= blocks[change.block].instructions.len) return null;
        const instruction = &@constCast(blocks[change.block].instructions)[change.instruction];
        switch (change.kind) {
            .binary => {
                if (instruction.* != .binary) return null;
                instruction.binary.checked = change.checked;
                instruction.binary.left_non_negative = change.non_negative;
            },
            .comparison => {
                if (instruction.* != .binary) return null;
                const result = instruction.binary.result;
                instruction.* = .{ .constant_bool = .{ .result = result, .value = change.value } };
            },
            .conversion => {
                if (instruction.* != .convert) return null;
                instruction.convert.checked = change.checked;
            },
        }
    }
    var result = function;
    result.blocks = blocks;
    _ = context.counters.hits.fetchAdd(1, .monotonic);
    return result;
}

pub fn store(allocator: Allocator, context: Context, digest: [32]u8, original: Ir.Function, optimized: Ir.Function) void {
    var changes: std.ArrayList(Change) = .empty;
    for (original.blocks, optimized.blocks, 0..) |before, after, block_index| {
        for (before.instructions, after.instructions, 0..) |old, new, index| {
            const change: Change = switch (new) {
                .binary => |binary| if (old == .binary and
                    (old.binary.checked != binary.checked or old.binary.left_non_negative != binary.left_non_negative))
                    .{ .block = block_index, .instruction = index, .kind = .binary, .checked = binary.checked, .non_negative = binary.left_non_negative }
                else
                    continue,
                .convert => |conversion| if (old == .convert and old.convert.checked != conversion.checked)
                    .{ .block = block_index, .instruction = index, .kind = .conversion, .checked = conversion.checked }
                else
                    continue,
                .constant_bool => |boolean| if (old == .binary)
                    .{ .block = block_index, .instruction = index, .kind = .comparison, .value = boolean.value }
                else
                    continue,
                else => continue,
            };
            changes.append(allocator, change) catch return;
        }
    }
    const payload = Binary.encode(allocator, changes.items) catch return;
    context.counters.mutex.lockUncancelable(context.store.io);
    defer context.counters.mutex.unlock(context.store.io);
    context.counters.pending.append(allocator, .{ .digest = digest, .bytes = payload }) catch {};
}

pub fn flush(context: Context) void {
    context.counters.mutex.lockUncancelable(context.store.io);
    defer context.counters.mutex.unlock(context.store.io);
    context.store.publishMany(context.counters.pending.items) catch {};
    context.counters.pending.clearRetainingCapacity();
}
