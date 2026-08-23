const Silex = @import("silex_optimizer_api");

pub const Counts = struct {
    functions: usize = 0,
    blocks: usize = 0,
    instructions: usize = 0,
    values: usize = 0,
    locals: usize = 0,
};

pub const Profile = struct {
    counts: Counts = .{},
    constants: usize = 0,
    copies: usize = 0,
    local_loads: usize = 0,
    local_stores: usize = 0,
    other_loads: usize = 0,
    other_stores: usize = 0,
    arithmetic: usize = 0,
    multiplies: usize = 0,
    divisions: usize = 0,
    remainders: usize = 0,
    shifts: usize = 0,
    comparisons: usize = 0,
    conversions: usize = 0,
    calls: usize = 0,
    aggregates: usize = 0,
    collections: usize = 0,
    strings: usize = 0,
    checked_operations: usize = 0,
    branches: usize = 0,
    jumps: usize = 0,
    returns: usize = 0,
    panics: usize = 0,
    prints: usize = 0,
    loop_back_edges: usize = 0,
};

pub fn count(program: Silex.Ir.Program) Counts {
    var result: Counts = .{ .functions = program.functions.len };
    for (program.functions) |function| {
        result.blocks += function.blocks.len;
        result.values += function.value_types.len;
        result.locals += function.local_types.len;
        for (function.blocks) |block| result.instructions += block.instructions.len;
    }
    return result;
}

pub fn profile(program: Silex.Ir.Program) Profile {
    var result: Profile = .{};
    result.counts.functions = program.functions.len;
    for (program.functions) |function| {
        result.counts.blocks += function.blocks.len;
        result.counts.values += function.value_types.len;
        result.counts.locals += function.local_types.len;
        for (function.blocks, 0..) |block, block_index| {
            result.counts.instructions += block.instructions.len;
            for (block.instructions) |instruction| profileInstruction(&result, instruction);
            switch (block.terminator) {
                .jump => |target| {
                    result.jumps += 1;
                    if (target <= block_index) result.loop_back_edges += 1;
                },
                .branch => |branch_value| {
                    result.branches += 1;
                    if (branch_value.then_block <= block_index or branch_value.else_block <= block_index)
                        result.loop_back_edges += 1;
                },
                .return_value, .return_void => result.returns += 1,
                .panic => result.panics += 1,
            }
        }
    }
    return result;
}

fn profileInstruction(result: *Profile, instruction: Silex.Ir.Instruction) void {
    switch (instruction) {
        .constant_int, .constant_bool, .constant_bytes, .constant_float32, .constant_float64, .optional_null => result.constants += 1,
        .copy, .deep_copy, .class_cast => result.copies += 1,
        .local_load => result.local_loads += 1,
        .local_store => result.local_stores += 1,
        .global_load, .field_load, .reference_load, .address_load => result.other_loads += 1,
        .collection_load => |load| {
            result.other_loads += 1;
            if (load.checked) result.checked_operations += 1;
        },
        .global_store, .field_store, .collection_replace, .reference_store, .address_store => result.other_stores += 1,
        .binary => |binary| {
            if (binary.checked) result.checked_operations += 1;
            switch (binary.operator) {
                .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => result.comparisons += 1,
                .multiply => {
                    result.arithmetic += 1;
                    result.multiplies += 1;
                },
                .divide => {
                    result.arithmetic += 1;
                    result.divisions += 1;
                },
                .remainder => {
                    result.arithmetic += 1;
                    result.remainders += 1;
                },
                .shift_left, .shift_right => {
                    result.arithmetic += 1;
                    result.shifts += 1;
                },
                else => result.arithmetic += 1,
            }
        },
        .unary => result.arithmetic += 1,
        .convert => |conversion| {
            result.conversions += 1;
            if (conversion.checked) result.checked_operations += 1;
        },
        .call, .indirect_call, .boundary_call, .dynamic_call => result.calls += 1,
        .structure_init, .protocol_init, .protocol_test, .protocol_extract, .enum_init, .enum_test, .enum_payload, .enum_raw => result.aggregates += 1,
        .list_init, .collection_reference, .collection_count, .list_edit, .collection_slice, .collection_view => result.collections += 1,
        .constant_str, .string_address, .string_byte_count, .string_byte_at, .string_from_bytes, .format_value, .string_concat, .string_count => result.strings += 1,
        .print => result.prints += 1,
        .assert => result.panics += 1,
        else => {},
    }
}

pub fn countFunction(program: Silex.Ir.Program, name: []const u8) ?Counts {
    for (program.functions) |function| {
        if (!@import("std").mem.eql(u8, function.name, name)) continue;
        var result: Counts = .{
            .functions = 1,
            .blocks = function.blocks.len,
            .values = function.value_types.len,
            .locals = function.local_types.len,
        };
        for (function.blocks) |block| result.instructions += block.instructions.len;
        return result;
    }
    return null;
}

test "IR counts aggregate all functions and blocks" {
    const program: Silex.Ir.Program = .{ .functions = &.{.{
        .name = "main",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = &.{.int},
        .local_types = &.{.int},
        .blocks = &.{.{
            .instructions = &.{.{ .constant_int = .{ .result = 0, .bits = 1 } }},
            .terminator = .return_void,
        }},
    }} };
    const result = count(program);
    try @import("std").testing.expectEqual(@as(usize, 1), result.functions);
    try @import("std").testing.expectEqual(@as(usize, 1), result.blocks);
    try @import("std").testing.expectEqual(@as(usize, 1), result.instructions);
    try @import("std").testing.expectEqual(@as(usize, 1), result.values);
    try @import("std").testing.expectEqual(@as(usize, 1), result.locals);
    const function = countFunction(program, "main").?;
    try @import("std").testing.expectEqual(@as(usize, 1), function.blocks);
    try @import("std").testing.expect(countFunction(program, "missing") == null);
}
