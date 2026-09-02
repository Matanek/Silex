const std = @import("std");
const Ir = @import("../Ir.zig");

// Forward only immutable snapshots of pure value aggregates. Reset at every
// block boundary and retain stores: a later block may still observe the local.
// Addressed locals are never eligible, even if their address is taken later.
pub fn forwardLoads(
    allocator: std.mem.Allocator,
    function: Ir.Function,
    eligible: []const bool,
    definitions: []const usize,
) !Ir.Function {
    if (function.local_types.len == 0) return function;
    const allowed = try allocator.dupe(bool, eligible);
    defer allocator.free(allowed);
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .local_address => |value| allowed[value.local] = false,
        else => {},
    };
    const current = try allocator.alloc(?Ir.ValueId, eligible.len);
    defer allocator.free(current);
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, index| {
        @memset(current, null);
        const instructions = try allocator.dupe(Ir.Instruction, block.instructions);
        for (instructions) |*instruction| switch (instruction.*) {
            .local_store => |value| {
                current[value.local] = if (allowed[value.local] and definitions[value.operand] == 1) value.operand else null;
            },
            .local_load => |value| if (current[value.local]) |operand| {
                instruction.* = .{ .copy = .{ .result = value.result, .operand = operand } };
            },
            else => {},
        };
        blocks[index] = .{ .instructions = instructions, .terminator = block.terminator };
    }
    var result = function;
    result.blocks = blocks;
    return result;
}

// Alias propagation can remove every read of a local while leaving its
// stores behind. Those stores unnecessarily make temporary aggregates escape
// scalar replacement. Remove only unobserved local stores, not their operands
// or any explicit ownership operations.
pub fn removeStores(allocator: std.mem.Allocator, function: Ir.Function) !Ir.Function {
    if (function.local_types.len == 0) return function;
    const observed = try allocator.alloc(bool, function.local_types.len);
    defer allocator.free(observed);
    @memset(observed, false);
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .local_load => |value| observed[value.local] = true,
        .local_address => |value| observed[value.local] = true,
        else => {},
    };
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, index| {
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |instruction| {
            if (instruction == .local_store and !observed[instruction.local_store.local]) continue;
            try instructions.append(allocator, instruction);
        }
        blocks[index] = .{ .instructions = try instructions.toOwnedSlice(allocator), .terminator = block.terminator };
    }
    var result = function;
    result.blocks = blocks;
    return result;
}

test "retain stores observed by a load or a local address" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const instructions = [_]Ir.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 7 } },
        .{ .local_store = .{ .local = 0, .operand = 0 } },
        .{ .local_store = .{ .local = 1, .operand = 0 } },
        .{ .local_store = .{ .local = 2, .operand = 0 } },
        .{ .local_address = .{ .result = 1, .local = 0 } },
        .{ .local_load = .{ .result = 2, .local = 1 } },
    };
    const function: Ir.Function = .{
        .name = "observed_locals",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = &.{ .int, .address, .int },
        .local_types = &.{ .int, .int, .int },
        .blocks = &.{.{ .instructions = &instructions, .terminator = .return_void }},
    };
    const result = try removeStores(arena.allocator(), function);
    try std.testing.expectEqual(@as(usize, 5), result.blocks[0].instructions.len);
    try std.testing.expectEqual(@as(usize, 0), result.blocks[0].instructions[1].local_store.local);
    try std.testing.expectEqual(@as(usize, 1), result.blocks[0].instructions[2].local_store.local);
    try std.testing.expectEqual(@as(usize, 6), function.blocks[0].instructions.len);
}

test "forwarding respects block boundaries addresses reused values and eligibility" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const first = [_]Ir.Instruction{
        .{ .local_store = .{ .local = 0, .operand = 0 } },
        .{ .local_load = .{ .result = 2, .local = 0 } },
        .{ .local_store = .{ .local = 1, .operand = 0 } },
        .{ .local_load = .{ .result = 3, .local = 1 } },
        .{ .local_store = .{ .local = 2, .operand = 1 } },
        .{ .local_load = .{ .result = 4, .local = 2 } },
        .{ .local_store = .{ .local = 3, .operand = 0 } },
        .{ .local_load = .{ .result = 5, .local = 3 } },
    };
    const second = [_]Ir.Instruction{
        .{ .local_load = .{ .result = 6, .local = 0 } },
        .{ .local_address = .{ .result = 7, .local = 1 } },
    };
    const function: Ir.Function = .{
        .name = "local_boundaries",
        .parameter_types = &.{ .int, .int },
        .return_type = .void,
        .value_types = &.{ .int, .int, .int, .int, .int, .int, .int, .address },
        .local_types = &.{ .int, .int, .int, .int },
        .blocks = &.{
            .{ .instructions = &first, .terminator = .{ .jump = 1 } },
            .{ .instructions = &second, .terminator = .return_void },
        },
    };
    const forwarded = try forwardLoads(arena.allocator(), function, &.{ true, true, true, false }, &.{ 1, 2, 1, 1, 1, 1, 1, 1 });
    const result = try removeStores(arena.allocator(), forwarded);
    try std.testing.expectEqual(@as(usize, 8), result.blocks[0].instructions.len);
    try std.testing.expectEqual(@as(usize, 0), result.blocks[0].instructions[1].copy.operand);
    for ([_]usize{ 3, 5, 7 }) |index| try std.testing.expect(result.blocks[0].instructions[index] == .local_load);
    try std.testing.expect(result.blocks[1].instructions[0] == .local_load);
    try std.testing.expect(function.blocks[0].instructions[1] == .local_load);
}
