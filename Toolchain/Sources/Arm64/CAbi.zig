const std = @import("std");
const Machine = @import("Machine.zig");

pub const Architecture = enum { arm64, x64 };
pub const Location = union(enum) { general: u4, floating: u4, stack: u16 };
pub const Argument = struct { locations: []const Location, indirect: bool = false };
pub const Plan = struct {
    arguments: []const Argument,
    stack_size: u16,
    pub fn deinit(self: Plan, allocator: std.mem.Allocator) void {
        for (self.arguments) |argument| allocator.free(argument.locations);
        allocator.free(self.arguments);
    }
};
pub fn floating(kind: Machine.AbiValue) bool {
    return kind == .float32 or kind == .float64;
}
pub fn fields(signature: Machine.ExternalFunction.Signature, index: usize) []const Machine.AbiValue {
    if (signature.arguments[index] != .record) return &.{};
    return signature.record_fields[index];
}
pub fn width(signature: Machine.ExternalFunction.Signature, index: usize) usize {
    return @max(fields(signature, index).len, 1);
}
pub fn scalarSize(kind: Machine.AbiValue) usize {
    return switch (kind) {
        .uint8 => 1,
        .uint16 => 2,
        .int32, .uint32, .float32 => 4,
        else => 8,
    };
}

// All record leaves in this slice are naturally aligned 64-bit scalars. This
// layout is deliberately independent of Silex's private aggregate convention.
pub fn plan(allocator: std.mem.Allocator, architecture: Architecture, platform: anytype, signature: Machine.ExternalFunction.Signature) Machine.Error!Plan {
    const arguments = try allocator.alloc(Argument, signature.arguments.len);
    var initialized: usize = 0;
    errdefer {
        for (arguments[0..initialized]) |argument| allocator.free(argument.locations);
        allocator.free(arguments);
    }
    var general: usize = 0;
    var floats: usize = 0;
    var stack: usize = if (architecture == .x64 and platform == .windows) 32 else 0;
    for (signature.arguments, 0..) |kind, index| {
        const record = kind == .record;
        if (record and (signature.record_fields.len != signature.arguments.len or signature.record_fields[index].len == 0)) return error.InvalidMachineProgram;
        const leaves = fields(signature, index);
        const hfa = record and leaves.len <= 4 and for (leaves) |leaf| {
            if (leaf != .float64) break false;
        } else true;
        const indirect = record and (if (architecture == .arm64) leaves.len > 2 and !hfa else platform == .windows and leaves.len > 1);
        const count = if (indirect) 1 else @max(leaves.len, 1);
        const locations = try allocator.alloc(Location, count);
        arguments[index] = .{ .locations = locations, .indirect = indirect };
        initialized += 1;
        if (architecture == .x64 and platform == .windows) {
            if (index >= 4 and 32 + (index - 3) * 8 > 4080) return error.FrameTooLarge;
            locations[0] = if (index < 4) (if (!record and floating(kind)) .{ .floating = @intCast(index) } else .{ .general = @intCast(index) }) else .{ .stack = @intCast(32 + (index - 4) * 8) };
            stack = @max(stack, 32 + (index + 1 -| 4) * 8);
            continue;
        }
        if (record and !indirect) {
            if (architecture == .arm64) {
                if (hfa and floats + count <= 8) {
                    for (locations, 0..) |*location, leaf| location.* = .{ .floating = @intCast(floats + leaf) };
                    floats += count;
                    continue;
                }
                if (!hfa and general + count <= 8) {
                    for (locations, 0..) |*location, leaf| location.* = .{ .general = @intCast(general + leaf) };
                    general += count;
                    continue;
                }
                if (hfa) floats = 8 else general = 8;
            } else if (count <= 2) {
                var needed_general: usize = 0;
                var needed_float: usize = 0;
                for (leaves) |leaf| {
                    if (floating(leaf)) needed_float += 1 else needed_general += 1;
                }
                if (general + needed_general <= 6 and floats + needed_float <= 8) {
                    for (locations, leaves) |*location, leaf| {
                        if (floating(leaf)) {
                            location.* = .{ .floating = @intCast(floats) };
                            floats += 1;
                        } else {
                            location.* = .{ .general = @intCast(general) };
                            general += 1;
                        }
                    }
                    continue;
                }
            }
            stack = std.mem.alignForward(usize, stack, 8);
            if (stack + count * 8 > 4080) return error.FrameTooLarge;
            for (locations, 0..) |*location, leaf| location.* = .{ .stack = @intCast(stack + leaf * 8) };
            stack += count * 8;
            continue;
        }
        const fp = !indirect and floating(kind);
        const limit: usize = if (fp or architecture == .arm64) 8 else 6;
        const lane = if (fp) floats else general;
        if (lane < limit) {
            locations[0] = if (fp) .{ .floating = @intCast(lane) } else .{ .general = @intCast(lane) };
            if (fp) floats += 1 else general += 1;
        } else {
            const size = if (architecture == .arm64 and platform == .darwin and !indirect) scalarSize(kind) else 8;
            stack = std.mem.alignForward(usize, stack, size);
            if (stack + size > 4080) return error.FrameTooLarge;
            locations[0] = .{ .stack = @intCast(stack) };
            stack += size;
        }
        if (stack > 4096) return error.FrameTooLarge;
    }
    return .{ .arguments = arguments, .stack_size = @intCast(std.mem.alignForward(usize, stack, 16)) };
}

pub fn internalFlattened(signature: Machine.ExternalFunction.Signature, architecture: Architecture) bool {
    if (architecture != .arm64) return false;
    var count: usize = 0;
    var small = false;
    for (signature.arguments, 0..) |_, index| {
        const leaves = fields(signature, index);
        if (leaves.len > 0 and leaves.len <= 2) {
            count += leaves.len;
            small = true;
        } else count += 1;
    }
    return small and count <= 8;
}
pub fn internalCount(signature: Machine.ExternalFunction.Signature, architecture: Architecture) usize {
    if (!internalFlattened(signature, architecture)) return signature.arguments.len;
    var count: usize = 0;
    for (signature.arguments, 0..) |_, index| {
        const leaves = fields(signature, index);
        count += if (leaves.len > 0 and leaves.len <= 2) leaves.len else 1;
    }
    return count;
}
pub fn homeSize(signature: Machine.ExternalFunction.Signature) usize {
    var count: usize = 0;
    for (signature.arguments, 0..) |_, index| count += width(signature, index);
    return count * 8;
}
