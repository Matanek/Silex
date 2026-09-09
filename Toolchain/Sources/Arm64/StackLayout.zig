const std = @import("std");
const Ir = @import("../Ir.zig");
const Machine = @import("Machine.zig");
const TypeLayout = @import("TypeLayout.zig");

const Allocator = std.mem.Allocator;

pub const Layout = struct {
    values: []const Machine.Span,
    locals: []const Machine.Span,
    parameters: []const Machine.Span,
    capture_parameters: []const Machine.Span,
    environments: []const ?Machine.Span,
    return_width: u12,
    return_aggregate: bool,
    hidden_return_slot: ?Machine.Slot,
    slot_count: Machine.Slot,
    reuses_slots: bool,
};

const ResidenceClass = enum { integer, float, aggregate };

const Interference = struct {
    words: []u64,

    fn deinit(self: Interference, allocator: Allocator) void {
        allocator.free(self.words);
    }

    fn insert(self: Interference, left: Ir.ValueId, right: Ir.ValueId) void {
        if (left == right) return;
        const larger = @max(left, right);
        const smaller = @min(left, right);
        const bit = larger * (larger - 1) / 2 + smaller;
        self.words[bit / 64] |= @as(u64, 1) << @intCast(bit % 64);
    }

    fn contains(self: Interference, left: Ir.ValueId, right: Ir.ValueId) bool {
        if (left == right) return true;
        const larger = @max(left, right);
        const smaller = @min(left, right);
        const bit = larger * (larger - 1) / 2 + smaller;
        return self.words[bit / 64] & (@as(u64, 1) << @intCast(bit % 64)) != 0;
    }
};

const ValueSet = struct {
    bits: []bool,
    excluded: ?[]const bool = null,
    valid: *bool,

    fn add(self: ValueSet, value: Ir.ValueId) void {
        if (value >= self.bits.len) {
            self.valid.* = false;
            return;
        }
        if (self.excluded) |excluded| if (excluded[value]) return;
        self.bits[value] = true;
    }
};

pub fn build(
    allocator: Allocator,
    program: Ir.Program,
    function: Ir.Function,
) Machine.Error!Layout {
    if (function.blocks.len == 0) return error.InvalidMachineProgram;
    const value_count = function.value_types.len;
    // Optimizations retain stable value IDs, including declarations whose
    // definitions and uses disappeared. They need no native storage. Keep
    // every ABI parameter even when its value is unused by the body.
    const present = try allocator.alloc(bool, value_count);
    defer allocator.free(present);
    @memset(present, false);
    var valid = true;
    const set: ValueSet = .{ .bits = present, .valid = &valid };
    for (0..function.parameter_types.len + function.capture_types.len) |parameter| set.add(parameter);
    for (function.blocks) |block| {
        for (block.instructions) |instruction| {
            addInstructionDefinitions(instruction, set);
            addInstructionUses(instruction, set);
        }
        addTerminatorUses(block.terminator, set);
    }
    if (!valid) return error.InvalidMachineProgram;
    const widths = try allocator.alloc(u12, value_count);
    const aggregates = try allocator.alloc(bool, value_count);
    const classes = try allocator.alloc(ResidenceClass, value_count);
    var naive_slots: usize = 0;
    for (function.value_types, 0..) |type_value, value| {
        widths[value] = if (present[value]) std.math.cast(u12, try TypeLayout.leafCount(program, type_value)) orelse
            return error.FrameTooLarge else 0;
        aggregates[value] = TypeLayout.isAggregate(program, type_value);
        classes[value] = residenceClass(type_value, aggregates[value]);
        naive_slots = std.math.add(usize, naive_slots, widths[value]) catch return error.FrameTooLarge;
    }
    for (function.local_types) |type_value| {
        naive_slots = std.math.add(usize, naive_slots, try TypeLayout.leafCount(program, type_value)) catch
            return error.FrameTooLarge;
    }
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .function_reference => |reference| {
            if (reference.result >= value_count) return error.InvalidMachineProgram;
            naive_slots = std.math.add(usize, naive_slots, reference.captures.len) catch
                return error.FrameTooLarge;
        },
        else => {},
    };
    const return_aggregate = TypeLayout.isAggregate(program, function.return_type);
    const return_width: u12 = if (function.return_type == .void)
        0
    else
        std.math.cast(u12, try TypeLayout.leafCount(program, function.return_type)) orelse
            return error.FrameTooLarge;
    naive_slots = std.math.add(usize, naive_slots, @intFromBool(return_aggregate)) catch
        return error.FrameTooLarge;
    const recycle = naive_slots > Machine.max_slots;
    const values = try allocator.alloc(Machine.Span, value_count);
    var next: usize = 0;
    if (!recycle) {
        for (0..value_count) |value| {
            values[value] = .{
                .start = try Machine.checkedSlot(next),
                .width = widths[value],
                .aggregate = aggregates[value],
            };
            next += widths[value];
        }
    } else {
        const pinned = try allocator.alloc(bool, value_count);
        @memset(pinned, false);
        markPinnedAliases(function, pinned) catch return error.InvalidMachineProgram;
        const interference = try buildInterference(allocator, function);
        defer interference.deinit(allocator);
        const relative_starts = try allocator.alloc(usize, value_count);
        @memset(relative_starts, 0);
        var class_sizes = [_]usize{ 0, 0, 0 };
        for (0..value_count) |value| {
            if (pinned[value]) continue;
            const class_index = @intFromEnum(classes[value]);
            const start = firstAvailable(
                value,
                widths,
                classes,
                pinned,
                relative_starts,
                interference,
            );
            relative_starts[value] = start;
            class_sizes[class_index] = @max(class_sizes[class_index], start + widths[value]);
        }
        const class_bases = [_]usize{
            0,
            class_sizes[0],
            class_sizes[0] + class_sizes[1],
        };
        next = class_sizes[0] + class_sizes[1] + class_sizes[2];
        for (0..value_count) |value| {
            const start = if (pinned[value]) pinned_start: {
                const result = next;
                next += widths[value];
                break :pinned_start result;
            } else class_bases[@intFromEnum(classes[value])] + relative_starts[value];
            values[value] = .{
                .start = try Machine.checkedSlot(start),
                .width = widths[value],
                .aggregate = aggregates[value],
            };
        }
    }

    const locals = try allocator.alloc(Machine.Span, function.local_types.len);
    for (function.local_types, 0..) |type_value, local| {
        locals[local] = try appendSpan(program, type_value, &next);
    }
    const environments = try allocator.alloc(?Machine.Span, value_count);
    @memset(environments, null);
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .function_reference => |reference| if (reference.captures.len != 0) {
            if (reference.result >= value_count) return error.InvalidMachineProgram;
            const width = std.math.cast(u12, reference.captures.len) orelse return error.FrameTooLarge;
            environments[reference.result] = .{
                .start = try Machine.checkedSlot(next),
                .width = width,
                .aggregate = true,
            };
            next += width;
            if (next > Machine.max_slots) return error.FrameTooLarge;
        },
        else => {},
    };
    const hidden_return_slot: ?Machine.Slot = if (return_aggregate) hidden: {
        const slot = try Machine.checkedSlot(next);
        next += 1;
        break :hidden slot;
    } else null;
    if (function.capture_types.len + function.parameter_types.len > values.len) {
        return error.InvalidMachineProgram;
    }
    const capture_parameters = try allocator.alloc(Machine.Span, function.capture_types.len);
    @memcpy(capture_parameters, values[0..function.capture_types.len]);
    const parameters = try allocator.alloc(Machine.Span, function.parameter_types.len);
    @memcpy(parameters, values[function.capture_types.len .. function.capture_types.len + function.parameter_types.len]);
    return .{
        .values = values,
        .locals = locals,
        .parameters = parameters,
        .capture_parameters = capture_parameters,
        .environments = environments,
        .return_width = return_width,
        .return_aggregate = return_aggregate,
        .hidden_return_slot = hidden_return_slot,
        .slot_count = try Machine.checkedSlot(next),
        .reuses_slots = recycle,
    };
}

fn residenceClass(type_value: Ir.Type, aggregate: bool) ResidenceClass {
    if (aggregate) return .aggregate;
    return if (type_value.isFloat()) .float else .integer;
}

fn firstAvailable(
    value: Ir.ValueId,
    widths: []const u12,
    classes: []const ResidenceClass,
    pinned: []const bool,
    starts: []const usize,
    interference: Interference,
) usize {
    var candidate: usize = 0;
    while (true) {
        var next = candidate;
        for (0..value) |other| {
            if (pinned[other] or classes[other] != classes[value] or
                !interference.contains(value, other)) continue;
            const other_end = starts[other] + widths[other];
            const candidate_end = candidate + widths[value];
            if (candidate < other_end and starts[other] < candidate_end) next = @max(next, other_end);
        }
        if (next == candidate) return candidate;
        candidate = next;
    }
}

fn appendSpan(program: Ir.Program, type_value: Ir.Type, next: *usize) Machine.Error!Machine.Span {
    if (type_value == .void) return error.UnsupportedType;
    const width = std.math.cast(u12, try TypeLayout.leafCount(program, type_value)) orelse
        return error.FrameTooLarge;
    const result: Machine.Span = .{
        .start = try Machine.checkedSlot(next.*),
        .width = width,
        .aggregate = TypeLayout.isAggregate(program, type_value),
    };
    next.* += width;
    if (next.* > Machine.max_slots) return error.FrameTooLarge;
    return result;
}

fn markPinnedAliases(function: Ir.Function, pinned: []bool) error{InvalidMachineProgram}!void {
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .collection_reference => |value| {
            try pin(pinned, value.collection);
            if (value.reference) |reference| try pin(pinned, reference);
        },
        .collection_slice, .collection_view => |value| {
            try pin(pinned, value.collection);
            if (value.reference) |reference| try pin(pinned, reference);
        },
        .reference_field => |value| try pin(pinned, value.reference),
        .reference_optional => |value| try pin(pinned, value.reference),
        else => {},
    };
}

fn pin(pinned: []bool, value: Ir.ValueId) error{InvalidMachineProgram}!void {
    if (value >= pinned.len) return error.InvalidMachineProgram;
    pinned[value] = true;
}

fn buildInterference(allocator: Allocator, function: Ir.Function) Machine.Error!Interference {
    const value_count = function.value_types.len;
    const cell_count = std.math.mul(usize, function.blocks.len, value_count) catch
        return error.InvalidMachineProgram;
    const used = try allocator.alloc(bool, cell_count);
    defer allocator.free(used);
    const defined = try allocator.alloc(bool, cell_count);
    defer allocator.free(defined);
    const live_in = try allocator.alloc(bool, cell_count);
    defer allocator.free(live_in);
    const live_out = try allocator.alloc(bool, cell_count);
    defer allocator.free(live_out);
    @memset(used, false);
    @memset(defined, false);
    @memset(live_in, false);
    @memset(live_out, false);
    var valid = true;
    for (function.blocks, 0..) |block, block_id| {
        const start = block_id * value_count;
        const block_used = used[start .. start + value_count];
        const block_defined = defined[start .. start + value_count];
        for (block.instructions) |instruction| {
            addInstructionUses(instruction, .{ .bits = block_used, .excluded = block_defined, .valid = &valid });
            addInstructionDefinitions(instruction, .{ .bits = block_defined, .valid = &valid });
        }
        addTerminatorUses(block.terminator, .{ .bits = block_used, .excluded = block_defined, .valid = &valid });
    }
    if (!valid) return error.InvalidMachineProgram;

    var changed = true;
    while (changed) {
        changed = false;
        var reverse = function.blocks.len;
        while (reverse != 0) {
            reverse -= 1;
            const start = reverse * value_count;
            for (0..value_count) |value| {
                const out = try successorLive(function.blocks, live_in, value_count, reverse, value);
                const input = used[start + value] or (out and !defined[start + value]);
                if (live_out[start + value] != out or live_in[start + value] != input) {
                    live_out[start + value] = out;
                    live_in[start + value] = input;
                    changed = true;
                }
            }
        }
    }

    const pair_count = std.math.mul(usize, value_count, value_count -| 1) catch
        return error.InvalidMachineProgram;
    const bit_count = pair_count / 2;
    const word_count = bit_count / 64 + @intFromBool(bit_count % 64 != 0);
    const words = try allocator.alloc(u64, word_count);
    @memset(words, 0);
    const result: Interference = .{ .words = words };
    const live = try allocator.alloc(bool, value_count);
    defer allocator.free(live);
    for (function.blocks, 0..) |block, block_id| {
        const start = block_id * value_count;
        @memcpy(live, live_out[start .. start + value_count]);
        addTerminatorUses(block.terminator, .{ .bits = live, .valid = &valid });
        addClique(result, live);
        var reverse = block.instructions.len;
        while (reverse != 0) {
            reverse -= 1;
            const instruction = block.instructions[reverse];
            addInstructionUses(instruction, .{ .bits = live, .valid = &valid });
            var definitions: [2]Ir.ValueId = undefined;
            const definition_count = instructionDefinitions(instruction, &definitions);
            for (definitions[0..definition_count]) |definition| {
                if (definition >= value_count) {
                    valid = false;
                    continue;
                }
                for (live, 0..) |is_live, other| if (is_live) result.insert(definition, other);
            }
            if (definition_count == 2) result.insert(definitions[0], definitions[1]);
            for (definitions[0..definition_count]) |definition| if (definition < value_count) {
                live[definition] = false;
            };
        }
        addClique(result, live);
    }
    if (!valid) {
        result.deinit(allocator);
        return error.InvalidMachineProgram;
    }
    return result;
}

fn successorLive(
    blocks: []const Ir.Block,
    live_in: []const bool,
    value_count: usize,
    block_id: Ir.BlockId,
    value: Ir.ValueId,
) Machine.Error!bool {
    return switch (blocks[block_id].terminator) {
        .jump => |target| if (target < blocks.len)
            live_in[target * value_count + value]
        else
            error.InvalidMachineProgram,
        .branch => |branch| if (branch.then_block < blocks.len and branch.else_block < blocks.len)
            live_in[branch.then_block * value_count + value] or
                live_in[branch.else_block * value_count + value]
        else
            error.InvalidMachineProgram,
        .return_value, .return_void, .panic => false,
    };
}

fn addClique(interference: Interference, live: []const bool) void {
    for (live, 0..) |left_live, left| {
        if (!left_live) continue;
        for (live[0..left], 0..) |right_live, right| if (right_live) {
            interference.insert(left, right);
        };
    }
}

fn instructionDefinitions(instruction: Ir.Instruction, output: *[2]Ir.ValueId) usize {
    return switch (instruction) {
        .class_retain,
        .class_drop,
        .list_retain,
        .list_drop,
        .string_retain,
        .string_drop,
        .global_store,
        .local_store,
        .address_store,
        .reference_store,
        .print,
        .assert,
        .mutex_lock,
        .mutex_unlock,
        => 0,
        .list_edit => |edit| result: {
            output[0] = edit.result;
            if (edit.removed) |removed| {
                output[1] = removed;
                break :result 2;
            }
            break :result 1;
        },
        .call => |call| optionalDefinition(call.result, output),
        .indirect_call => |call| optionalDefinition(call.result, output),
        .boundary_call => |call| optionalDefinition(call.result, output),
        .boundary_indirect_call => |call| optionalDefinition(call.result, output),
        .dynamic_call => |call| optionalDefinition(call.result, output),
        inline else => |value| result: {
            output[0] = value.result;
            break :result 1;
        },
    };
}

fn optionalDefinition(value: ?Ir.ValueId, output: *[2]Ir.ValueId) usize {
    output[0] = value orelse return 0;
    return 1;
}

fn addInstructionDefinitions(instruction: Ir.Instruction, set: ValueSet) void {
    var definitions: [2]Ir.ValueId = undefined;
    const count = instructionDefinitions(instruction, &definitions);
    for (definitions[0..count]) |definition| set.add(definition);
}

fn addInstructionUses(instruction: Ir.Instruction, set: ValueSet) void {
    switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_str,
        .constant_bytes,
        .constant_float32,
        .constant_float64,
        .optional_null,
        .global_load,
        .storage_init,
        .local_load,
        .local_address,
        => {},
        .function_reference => |value| addValues(set, value.captures),
        .optional_some => |value| set.add(value.operand),
        .optional_unwrap => |value| set.add(value.operand),
        .copy, .deep_copy, .class_cast => |value| set.add(value.operand),
        .class_retain => |value| set.add(value.operand),
        .class_drop => |value| set.add(value.operand),
        .list_retain, .list_drop, .string_retain, .string_drop => |value| set.add(value.operand),
        .global_store => |value| set.add(value.operand),
        .structure_init => |value| addValues(set, value.fields),
        .protocol_init => |value| set.add(value.operand),
        .protocol_test => |value| set.add(value.operand),
        .protocol_extract => |value| set.add(value.operand),
        .list_init => |value| addValues(set, value.values),
        .enum_init => |value| addValues(set, value.values),
        .enum_test => |value| set.add(value.operand),
        .enum_payload => |value| set.add(value.operand),
        .enum_raw => |value| set.add(value.operand),
        .field_load => |value| set.add(value.base),
        .field_store => |value| {
            set.add(value.base);
            set.add(value.replacement);
        },
        .collection_load => |value| {
            set.add(value.collection);
            set.add(value.index);
        },
        .collection_reference => |value| {
            set.add(value.collection);
            addOptional(set, value.reference);
            set.add(value.index);
        },
        .collection_replace => |value| {
            set.add(value.collection);
            set.add(value.index);
            set.add(value.replacement);
        },
        .collection_count => |value| set.add(value.collection),
        .list_edit => |value| {
            set.add(value.collection);
            addOptional(set, value.index);
            addOptional(set, value.argument);
        },
        .collection_slice, .collection_view => |value| {
            set.add(value.collection);
            set.add(value.start);
            set.add(value.end);
            addOptional(set, value.reference);
        },
        .string_address, .string_byte_count => |value| set.add(value.operand),
        .string_byte_at => |value| {
            set.add(value.operand);
            set.add(value.index);
        },
        .string_from_bytes => |value| set.add(value.bytes),
        .local_store => |value| set.add(value.operand),
        .reference_load => |value| set.add(value.reference),
        .address_load => |value| {
            set.add(value.address);
            set.add(value.byte_offset);
        },
        .address_store => |value| {
            set.add(value.address);
            set.add(value.byte_offset);
            set.add(value.operand);
        },
        .reference_store => |value| {
            set.add(value.reference);
            set.add(value.operand);
        },
        .reference_field => |value| set.add(value.reference),
        .reference_optional => |value| set.add(value.reference),
        .convert => |value| set.add(value.operand),
        .format_value => |value| set.add(value.operand),
        .string_concat => |value| {
            set.add(value.left);
            set.add(value.right);
        },
        .string_count => |value| set.add(value.operand),
        .unary => |value| set.add(value.operand),
        .binary => |value| {
            set.add(value.left);
            set.add(value.right);
        },
        .call => |value| addValues(set, value.arguments),
        .indirect_call => |value| {
            set.add(value.callee);
            addValues(set, value.arguments);
        },
        .boundary_call => |value| addValues(set, value.arguments),
        .boundary_indirect_call => |value| {
            set.add(value.callee);
            addValues(set, value.arguments);
        },
        .dynamic_call => |value| {
            set.add(value.receiver);
            addValues(set, value.arguments);
        },
        .print => |value| set.add(value.value),
        .assert => |value| {
            set.add(value.condition);
            set.add(value.message);
        },
        .mutex_lock, .mutex_unlock => {},
    }
}

fn addTerminatorUses(terminator: Ir.Terminator, set: ValueSet) void {
    switch (terminator) {
        .return_value => |value| set.add(value),
        .branch => |branch| set.add(branch.condition),
        .panic => |value| set.add(value.message),
        .jump, .return_void => {},
    }
}

fn addValues(set: ValueSet, values: []const Ir.ValueId) void {
    for (values) |value| set.add(value);
}

fn addOptional(set: ValueSet, value: ?Ir.ValueId) void {
    if (value) |present| set.add(present);
}

test "reuse stack homes beyond the former virtual slot ceiling" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const value_count = Machine.max_slots + 1024;
    const types = try allocator.alloc(Ir.Type, value_count);
    @memset(types, .int);
    const instructions = try allocator.alloc(Ir.Instruction, value_count);
    instructions[0] = .{ .constant_int = .{ .result = 0, .bits = 1 } };
    for (instructions[1..], 1..) |*instruction, value| {
        instruction.* = .{ .unary = .{ .result = value, .operator = .negate, .operand = value - 1 } };
    }
    const blocks = [_]Ir.Block{.{
        .instructions = instructions,
        .terminator = .{ .return_value = value_count - 1 },
    }};
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "large_sequential_frame",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = types,
        .blocks = &blocks,
    }} };
    const layout = try build(allocator, program, program.functions[0]);
    try std.testing.expectEqual(@as(Machine.Slot, 2), layout.slot_count);
    try std.testing.expectEqual(layout.values[0].start, layout.values[2].start);
    try std.testing.expect(layout.values[0].start != layout.values[1].start);
}

test "prune unused declarations while keeping branch values in distinct homes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const types = try allocator.alloc(Ir.Type, Machine.max_slots + 1);
    @memset(types, .int);
    types[2] = .bool;
    const blocks = [_]Ir.Block{
        .{ .instructions = &.{
            .{ .constant_int = .{ .result = 0, .bits = 10 } },
            .{ .constant_int = .{ .result = 1, .bits = 20 } },
            .{ .constant_bool = .{ .result = 2, .value = true } },
        }, .terminator = .{ .branch = .{ .condition = 2, .then_block = 1, .else_block = 2 } } },
        .{ .instructions = &.{.{ .binary = .{ .result = 3, .operator = .add, .left = 0, .right = 1 } }}, .terminator = .{ .return_value = 3 } },
        .{ .instructions = &.{.{ .binary = .{ .result = 4, .operator = .subtract, .left = 0, .right = 1 } }}, .terminator = .{ .return_value = 4 } },
    };
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "branch_values",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = types,
        .blocks = &blocks,
    }} };
    const layout = try build(allocator, program, program.functions[0]);
    try std.testing.expect(layout.values[0].start != layout.values[1].start);
    try std.testing.expectEqual(@as(Machine.Slot, 5), layout.slot_count);
    try std.testing.expect(!layout.reuses_slots);
}

test "prune unused declarations without dropping ABI parameters" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const types = try allocator.alloc(Ir.Type, 256);
    @memset(types, .int);
    const function: Ir.Function = .{
        .name = "sparse_value_ids",
        .parameter_types = &.{.int},
        .capture_types = &.{.int},
        .return_type = .int,
        .value_types = types,
        .blocks = &.{.{
            .instructions = &.{.{ .constant_int = .{ .result = 255, .bits = 42 } }},
            .terminator = .{ .return_value = 255 },
        }},
    };
    const layout = try build(allocator, .{ .functions = &.{function} }, function);
    try std.testing.expectEqual(@as(Machine.Slot, 3), layout.slot_count);
    try std.testing.expectEqual(@as(u12, 1), layout.parameters[0].width);
    try std.testing.expectEqual(@as(u12, 1), layout.capture_parameters[0].width);
    try std.testing.expect(layout.parameters[0].start != layout.capture_parameters[0].start);
    try std.testing.expectEqual(@as(u12, 0), layout.values[2].width);
}
