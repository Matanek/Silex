const std = @import("std");
const Ir = @import("../Ir.zig");
const CompilationCache = @import("../CompilationCache.zig");

const Allocator = std.mem.Allocator;

const Constant = union(enum) {
    unknown,
    integer: u64,
    boolean: bool,
};

const GlobalSummary = union(enum) {
    none,
    identity: usize,
    binary: BinarySummary,
    integer: u64,
    boolean: bool,
    string: []const u8,
    float32: u32,
    float64: u64,
};

const BinarySummary = struct {
    operator: Ir.BinaryOperator,
    left_parameter: usize,
    right_parameter: usize,
};

pub fn optimize(allocator: Allocator, program: Ir.Program) !Ir.Program {
    const summaries = try allocator.alloc(GlobalSummary, program.functions.len);
    for (program.functions, 0..) |function, index| summaries[index] = summarize(function);
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, index| {
        functions[index] = try optimizeFunction(allocator, function, summaries);
    }
    var result = program;
    result.functions = functions;
    const validated = try Ir.writeText(allocator, result);
    allocator.free(validated);
    return result;
}

pub fn optimizeCached(allocator: Allocator, io: std.Io, program: Ir.Program) !Ir.Program {
    const summaries = try allocator.alloc(GlobalSummary, program.functions.len);
    for (program.functions, 0..) |function, index| summaries[index] = summarize(function);
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, index| {
        var dependencies: std.ArrayList([]const u8) = .empty;
        const encoded = try std.json.Stringify.valueAlloc(allocator, function, .{});
        try dependencies.append(allocator, encoded);
        for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
            .call => |call| if (call.function < program.functions.len) {
                try dependencies.append(
                    allocator,
                    try std.json.Stringify.valueAlloc(allocator, program.functions[call.function], .{}),
                );
            },
            else => {},
        };
        const digest = CompilationCache.artifactKey("optimized-function", dependencies.items);
        if (CompilationCache.load(allocator, io, digest, "release-function")) |payload| {
            functions[index] = std.json.parseFromSliceLeaky(Ir.Function, allocator, payload, .{}) catch
                try optimizeFunction(allocator, function, summaries);
        } else {
            functions[index] = try optimizeFunction(allocator, function, summaries);
            const payload = try std.json.Stringify.valueAlloc(allocator, functions[index], .{});
            CompilationCache.store(allocator, io, digest, "release-function", payload);
        }
    }
    var result = program;
    result.functions = functions;
    const validated = try Ir.writeText(allocator, result);
    allocator.free(validated);
    return result;
}

fn optimizeFunction(allocator: Allocator, function: Ir.Function, summaries: []const GlobalSummary) !Ir.Function {
    // Alias and constant propagation is intentionally local to straight-line
    // functions until the optimizer models dominance and control-flow joins.
    if (function.blocks.len != 1) return function;

    const aliases = try allocator.alloc(Ir.ValueId, function.value_types.len);
    for (aliases, 0..) |*alias, index| alias.* = index;
    const constants = try allocator.alloc(Constant, function.value_types.len);
    @memset(constants, .unknown);

    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_index| {
        var local_values = try allocator.alloc(?Ir.ValueId, function.local_types.len);
        @memset(local_values, null);
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |original| {
            var instruction = try rewriteInstruction(allocator, original, aliases);
            if (instruction == .call) instruction = inlineConstantCall(instruction.call, summaries) orelse instruction;
            switch (instruction) {
                .copy => |copy| {
                    aliases[copy.result] = canonical(aliases, copy.operand);
                    continue;
                },
                .local_load => |load| if (local_values[load.local]) |stored| {
                    aliases[load.result] = canonical(aliases, stored);
                    continue;
                },
                .local_store => |store| local_values[store.local] = canonical(aliases, store.operand),
                .reference_store, .call, .indirect_call, .dynamic_call => @memset(local_values, null),
                else => {},
            }
            instruction = foldInstruction(function, instruction, constants);
            recordConstant(instruction, constants);
            try instructions.append(allocator, instruction);
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = rewriteTerminator(block.terminator, aliases, constants),
        };
    }

    var result = function;
    result.blocks = try removeUnreachableBlocks(allocator, blocks);
    result.blocks = try removeDeadConstants(allocator, result);
    return result;
}

fn summarize(function: Ir.Function) GlobalSummary {
    if (function.capture_types.len != 0) return .none;
    if (function.blocks.len != 1) return .none;
    const returned = switch (function.blocks[0].terminator) {
        .return_value => |value| value,
        else => return .none,
    };
    if (function.blocks[0].instructions.len == 0) {
        return if (returned < function.parameter_types.len) .{ .identity = returned } else .none;
    }
    if (function.blocks[0].instructions.len != 1) return .none;
    return switch (function.blocks[0].instructions[0]) {
        .constant_int => |value| if (value.result == returned) .{ .integer = value.bits } else .none,
        .constant_bool => |value| if (value.result == returned) .{ .boolean = value.value } else .none,
        .constant_str => |value| if (value.result == returned) .{ .string = value.value } else .none,
        .constant_float32 => |value| if (value.result == returned) .{ .float32 = value.bits } else .none,
        .constant_float64 => |value| if (value.result == returned) .{ .float64 = value.bits } else .none,
        .binary => |value| if (value.result == returned and
            value.left < function.parameter_types.len and
            value.right < function.parameter_types.len)
            .{ .binary = .{
                .operator = value.operator,
                .left_parameter = value.left,
                .right_parameter = value.right,
            } }
        else
            .none,
        else => .none,
    };
}

fn inlineConstantCall(call: Ir.Instruction.Call, summaries: []const GlobalSummary) ?Ir.Instruction {
    const result = call.result orelse return null;
    if (call.function >= summaries.len) return null;
    return switch (summaries[call.function]) {
        .none => null,
        .identity => |parameter| if (parameter < call.arguments.len)
            .{ .copy = .{ .result = result, .operand = call.arguments[parameter] } }
        else
            null,
        .binary => |summary| if (summary.left_parameter < call.arguments.len and
            summary.right_parameter < call.arguments.len)
            .{ .binary = .{
                .result = result,
                .operator = summary.operator,
                .left = call.arguments[summary.left_parameter],
                .right = call.arguments[summary.right_parameter],
            } }
        else
            null,
        .integer => |bits| .{ .constant_int = .{ .result = result, .bits = bits } },
        .boolean => |value| .{ .constant_bool = .{ .result = result, .value = value } },
        .string => |value| .{ .constant_str = .{ .result = result, .value = value } },
        .float32 => |bits| .{ .constant_float32 = .{ .result = result, .bits = bits } },
        .float64 => |bits| .{ .constant_float64 = .{ .result = result, .bits = bits } },
    };
}

fn canonical(aliases: []const Ir.ValueId, value: Ir.ValueId) Ir.ValueId {
    var current = value;
    while (aliases[current] != current) current = aliases[current];
    return current;
}

fn rewriteInstruction(allocator: Allocator, instruction: Ir.Instruction, aliases: []const Ir.ValueId) !Ir.Instruction {
    return switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_str,
        .constant_bytes,
        .constant_float32,
        .constant_float64,
        .optional_null,
        .global_load,
        .local_address,
        .mutex_lock,
        .mutex_unlock,
        => instruction,
        .function_reference => |value| .{ .function_reference = .{
            .result = value.result,
            .function = value.function,
            .captures = try rewriteValues(allocator, value.captures, aliases),
        } },
        .string_address => |value| .{ .string_address = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
        } },
        .string_byte_count => |value| .{ .string_byte_count = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
        } },
        .string_byte_at => |value| .{ .string_byte_at = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .index = canonical(aliases, value.index),
        } },
        .string_from_bytes => |value| .{ .string_from_bytes = .{
            .result = value.result,
            .bytes = canonical(aliases, value.bytes),
        } },
        .optional_some => |value| .{ .optional_some = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .optional_unwrap => |value| .{ .optional_unwrap = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .copy => |value| .{ .copy = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .deep_copy => |value| .{ .deep_copy = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .class_cast => |value| .{ .class_cast = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .class_retain => |value| .{ .class_retain = .{ .operand = canonical(aliases, value.operand), .ownership = value.ownership } },
        .class_drop => |value| .{ .class_drop = .{ .operand = canonical(aliases, value.operand), .ownership = value.ownership, .static_type = value.static_type, .plans = value.plans } },
        .list_retain => |value| .{ .list_retain = .{ .operand = canonical(aliases, value.operand), .ownership = value.ownership } },
        .string_retain => |value| .{ .string_retain = .{ .operand = canonical(aliases, value.operand), .ownership = value.ownership } },
        .string_drop => |value| .{ .string_drop = .{ .operand = canonical(aliases, value.operand), .ownership = value.ownership } },
        .list_drop => |value| .{ .list_drop = .{
            .operand = canonical(aliases, value.operand),
            .ownership = value.ownership,
            .deallocate = value.deallocate,
        } },
        .global_store => |value| .{ .global_store = .{ .global = value.global, .operand = canonical(aliases, value.operand) } },
        .structure_init => |value| .{ .structure_init = .{
            .result = value.result,
            .structure = value.structure,
            .fields = try rewriteValues(allocator, value.fields, aliases),
        } },
        .protocol_init => |value| .{ .protocol_init = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .structure = value.structure,
        } },
        .protocol_test => |value| .{ .protocol_test = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .structure = value.structure,
        } },
        .protocol_extract => |value| .{ .protocol_extract = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .structure = value.structure,
        } },
        .list_init => |value| .{ .list_init = .{
            .result = value.result,
            .values = try rewriteValues(allocator, value.values, aliases),
        } },
        .enum_init => |value| .{ .enum_init = .{
            .result = value.result,
            .enumeration = value.enumeration,
            .variant = value.variant,
            .values = try rewriteValues(allocator, value.values, aliases),
        } },
        .enum_test => |value| .{ .enum_test = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .enumeration = value.enumeration,
            .variant = value.variant,
        } },
        .enum_payload => |value| .{ .enum_payload = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .enumeration = value.enumeration,
            .variant = value.variant,
            .index = value.index,
        } },
        .enum_raw => |value| .{ .enum_raw = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .enumeration = value.enumeration,
        } },
        .field_load => |value| .{ .field_load = .{
            .result = value.result,
            .base = canonical(aliases, value.base),
            .field = value.field,
        } },
        .field_store => |value| .{ .field_store = .{
            .result = value.result,
            .base = canonical(aliases, value.base),
            .field = value.field,
            .replacement = canonical(aliases, value.replacement),
        } },
        .collection_load => |value| .{ .collection_load = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
            .index = canonical(aliases, value.index),
            .position = value.position,
        } },
        .collection_reference => |value| .{ .collection_reference = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
            .reference = rewriteOptional(value.reference, aliases),
            .index = canonical(aliases, value.index),
            .position = value.position,
        } },
        .collection_replace => |value| .{ .collection_replace = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
            .index = canonical(aliases, value.index),
            .replacement = canonical(aliases, value.replacement),
            .ownership = value.ownership,
            .position = value.position,
        } },
        .collection_count => |value| .{ .collection_count = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
        } },
        .list_edit => |value| .{ .list_edit = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
            .ownership = value.ownership,
            .kind = value.kind,
            .index = rewriteOptional(value.index, aliases),
            .argument = rewriteOptional(value.argument, aliases),
            .argument_transferred = value.argument_transferred,
            .removed = value.removed,
            .position = value.position,
        } },
        .collection_slice => |value| .{ .collection_slice = try rewriteSlice(value, aliases) },
        .collection_view => |value| .{ .collection_view = try rewriteSlice(value, aliases) },
        .local_load => |value| .{ .local_load = value },
        .local_store => |value| .{ .local_store = .{ .local = value.local, .operand = canonical(aliases, value.operand) } },
        .reference_load => |value| .{ .reference_load = .{ .result = value.result, .reference = canonical(aliases, value.reference) } },
        .address_load => |value| .{ .address_load = .{
            .result = value.result,
            .address = canonical(aliases, value.address),
            .byte_offset = canonical(aliases, value.byte_offset),
            .type = value.type,
        } },
        .address_store => |value| .{ .address_store = .{
            .address = canonical(aliases, value.address),
            .byte_offset = canonical(aliases, value.byte_offset),
            .operand = canonical(aliases, value.operand),
            .type = value.type,
        } },
        .reference_store => |value| .{ .reference_store = .{
            .reference = canonical(aliases, value.reference),
            .operand = canonical(aliases, value.operand),
        } },
        .reference_field => |value| .{ .reference_field = .{
            .result = value.result,
            .reference = canonical(aliases, value.reference),
            .structure = value.structure,
            .field = value.field,
        } },
        .reference_optional => |value| .{ .reference_optional = .{
            .result = value.result,
            .reference = canonical(aliases, value.reference),
        } },
        .convert => |value| .{ .convert = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .source = value.source,
            .target = value.target,
            .position = value.position,
            .checked = value.checked,
        } },
        .format_value => |value| .{ .format_value = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .string_concat => |value| .{ .string_concat = .{
            .result = value.result,
            .left = canonical(aliases, value.left),
            .right = canonical(aliases, value.right),
        } },
        .string_count => |value| .{ .string_count = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .unary => |value| .{ .unary = .{
            .result = value.result,
            .operator = value.operator,
            .operand = canonical(aliases, value.operand),
        } },
        .binary => |value| .{ .binary = .{
            .result = value.result,
            .operator = value.operator,
            .left = canonical(aliases, value.left),
            .right = canonical(aliases, value.right),
        } },
        .call => |value| .{ .call = .{
            .result = value.result,
            .function = value.function,
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
        } },
        .indirect_call => |value| .{ .indirect_call = .{
            .result = value.result,
            .callee = canonical(aliases, value.callee),
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
        } },
        .boundary_call => |value| .{ .boundary_call = .{
            .result = value.result,
            .function = value.function,
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
        } },
        .dynamic_call => |value| .{ .dynamic_call = .{
            .result = value.result,
            .function = value.function,
            .receiver = canonical(aliases, value.receiver),
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
            .implementations = value.implementations,
        } },
        .print => |value| .{ .print = .{ .value = canonical(aliases, value.value), .newline = value.newline } },
        .assert => |value| .{ .assert = .{
            .condition = canonical(aliases, value.condition),
            .message = canonical(aliases, value.message),
            .position = value.position,
        } },
    };
}

fn rewriteSlice(value: Ir.Instruction.CollectionSlice, aliases: []const Ir.ValueId) !Ir.Instruction.CollectionSlice {
    return .{
        .result = value.result,
        .collection = canonical(aliases, value.collection),
        .start = canonical(aliases, value.start),
        .end = canonical(aliases, value.end),
        .reference = rewriteOptional(value.reference, aliases),
    };
}

fn rewriteValues(allocator: Allocator, values: []const Ir.ValueId, aliases: []const Ir.ValueId) ![]const Ir.ValueId {
    const rewritten = try allocator.alloc(Ir.ValueId, values.len);
    for (values, 0..) |value, index| rewritten[index] = canonical(aliases, value);
    return rewritten;
}

fn rewriteOptional(value: ?Ir.ValueId, aliases: []const Ir.ValueId) ?Ir.ValueId {
    return if (value) |present| canonical(aliases, present) else null;
}

fn foldInstruction(function: Ir.Function, instruction: Ir.Instruction, constants: []const Constant) Ir.Instruction {
    return switch (instruction) {
        .unary => |value| foldUnary(function, value, constants) orelse instruction,
        .binary => |value| foldBinary(function, value, constants) orelse instruction,
        else => instruction,
    };
}

fn foldUnary(function: Ir.Function, value: Ir.Instruction.Unary, constants: []const Constant) ?Ir.Instruction {
    const bits = switch (constants[value.operand]) {
        .integer => |bits| bits,
        else => return null,
    };
    const type_value = function.value_types[value.result];
    if (!type_value.isSignedInteger()) return null;
    const operand = signedValue(bits, type_value.bitWidth());
    const result = -operand;
    if (!fitsSigned(result, type_value.bitWidth())) return null;
    return .{ .constant_int = .{ .result = value.result, .bits = integerBits(result, type_value.bitWidth()) } };
}

fn foldBinary(function: Ir.Function, value: Ir.Instruction.Binary, constants: []const Constant) ?Ir.Instruction {
    const left_bits = switch (constants[value.left]) {
        .integer => |bits| bits,
        else => return null,
    };
    const right_bits = switch (constants[value.right]) {
        .integer => |bits| bits,
        else => return null,
    };
    const operand_type = function.value_types[value.left];
    if (!operand_type.isInteger()) return null;
    if (isComparison(value.operator)) {
        const result = compareIntegers(value.operator, operand_type, left_bits, right_bits);
        return .{ .constant_bool = .{ .result = value.result, .value = result } };
    }
    const bits = foldInteger(value.operator, operand_type, left_bits, right_bits) orelse return null;
    return .{ .constant_int = .{ .result = value.result, .bits = bits } };
}

fn foldInteger(operator: Ir.BinaryOperator, type_value: Ir.Type, left_bits: u64, right_bits: u64) ?u64 {
    const width = type_value.bitWidth();
    if (type_value.isSignedInteger()) {
        const left = signedValue(left_bits, width);
        const right = signedValue(right_bits, width);
        const result = switch (operator) {
            .add => left + right,
            .subtract => left - right,
            .multiply => left * right,
            .divide => if (right == 0 or (left == signedMinimum(width) and right == -1)) return null else @divTrunc(left, right),
            .remainder => if (right == 0 or (left == signedMinimum(width) and right == -1)) return null else @rem(left, right),
            .bit_and => return masked(left_bits & right_bits, width),
            .bit_xor => return masked(left_bits ^ right_bits, width),
            else => return null,
        };
        if (!fitsSigned(result, width)) return null;
        return integerBits(result, width);
    }

    const left: u128 = masked(left_bits, width);
    const right: u128 = masked(right_bits, width);
    const result = switch (operator) {
        .add => left + right,
        .subtract => if (left < right) return null else left - right,
        .multiply => left * right,
        .divide => if (right == 0) return null else left / right,
        .remainder => if (right == 0) return null else left % right,
        .bit_and => left & right,
        .bit_xor => left ^ right,
        else => return null,
    };
    if (result > unsignedMaximum(width)) return null;
    return @intCast(result);
}

fn compareIntegers(operator: Ir.BinaryOperator, type_value: Ir.Type, left_bits: u64, right_bits: u64) bool {
    if (type_value.isSignedInteger()) {
        const left = signedValue(left_bits, type_value.bitWidth());
        const right = signedValue(right_bits, type_value.bitWidth());
        return compare(operator, left, right);
    }
    const left: u128 = masked(left_bits, type_value.bitWidth());
    const right: u128 = masked(right_bits, type_value.bitWidth());
    return compare(operator, left, right);
}

fn compare(operator: Ir.BinaryOperator, left: anytype, right: @TypeOf(left)) bool {
    return switch (operator) {
        .less => left < right,
        .less_equal => left <= right,
        .greater => left > right,
        .greater_equal => left >= right,
        .equal => left == right,
        .not_equal => left != right,
        else => unreachable,
    };
}

fn isComparison(operator: Ir.BinaryOperator) bool {
    return switch (operator) {
        .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => true,
        else => false,
    };
}

fn recordConstant(instruction: Ir.Instruction, constants: []Constant) void {
    switch (instruction) {
        .constant_int => |value| constants[value.result] = .{ .integer = value.bits },
        .constant_bool => |value| constants[value.result] = .{ .boolean = value.value },
        else => {},
    }
}

fn rewriteTerminator(terminator: Ir.Terminator, aliases: []const Ir.ValueId, constants: []const Constant) Ir.Terminator {
    return switch (terminator) {
        .jump, .return_void => terminator,
        .return_value => |value| .{ .return_value = canonical(aliases, value) },
        .panic => |value| .{ .panic = .{
            .message = canonical(aliases, value.message),
            .position = value.position,
        } },
        .branch => |branch| branch_result: {
            const condition = canonical(aliases, branch.condition);
            if (constants[condition] == .boolean) {
                break :branch_result .{ .jump = if (constants[condition].boolean) branch.then_block else branch.else_block };
            }
            break :branch_result .{ .branch = .{
                .condition = condition,
                .then_block = branch.then_block,
                .else_block = branch.else_block,
            } };
        },
    };
}

fn removeUnreachableBlocks(allocator: Allocator, blocks: []const Ir.Block) ![]const Ir.Block {
    if (blocks.len == 0) return blocks;
    const reachable = try allocator.alloc(bool, blocks.len);
    @memset(reachable, false);
    var pending: std.ArrayList(Ir.BlockId) = .empty;
    try pending.append(allocator, 0);
    while (pending.pop()) |block_id| {
        if (reachable[block_id]) continue;
        reachable[block_id] = true;
        switch (blocks[block_id].terminator) {
            .jump => |target| try pending.append(allocator, target),
            .branch => |branch| {
                try pending.append(allocator, branch.then_block);
                try pending.append(allocator, branch.else_block);
            },
            else => {},
        }
    }

    const remap = try allocator.alloc(Ir.BlockId, blocks.len);
    var count: usize = 0;
    for (reachable, 0..) |present, old| if (present) {
        remap[old] = count;
        count += 1;
    };
    const result = try allocator.alloc(Ir.Block, count);
    var next: usize = 0;
    for (blocks, 0..) |block, old| {
        if (!reachable[old]) continue;
        result[next] = .{
            .instructions = block.instructions,
            .terminator = remapTerminator(block.terminator, remap),
        };
        next += 1;
    }
    return result;
}

fn remapTerminator(terminator: Ir.Terminator, remap: []const Ir.BlockId) Ir.Terminator {
    return switch (terminator) {
        .jump => |target| .{ .jump = remap[target] },
        .branch => |branch| .{ .branch = .{
            .condition = branch.condition,
            .then_block = remap[branch.then_block],
            .else_block = remap[branch.else_block],
        } },
        else => terminator,
    };
}

fn removeDeadConstants(allocator: Allocator, function: Ir.Function) ![]const Ir.Block {
    var current = function.blocks;
    while (true) {
        const uses = try allocator.alloc(usize, function.value_types.len);
        @memset(uses, 0);
        for (current) |block| {
            for (block.instructions) |instruction| countUses(instruction, uses);
            countTerminatorUses(block.terminator, uses);
        }
        var changed = false;
        const next = try allocator.alloc(Ir.Block, current.len);
        for (current, 0..) |block, block_index| {
            var instructions: std.ArrayList(Ir.Instruction) = .empty;
            for (block.instructions) |instruction| {
                if (removableResult(instruction)) |result| if (uses[result] == 0) {
                    changed = true;
                    continue;
                };
                try instructions.append(allocator, instruction);
            }
            next[block_index] = .{
                .instructions = try instructions.toOwnedSlice(allocator),
                .terminator = block.terminator,
            };
        }
        current = next;
        if (!changed) return current;
    }
}

fn removableResult(instruction: Ir.Instruction) ?Ir.ValueId {
    return switch (instruction) {
        .constant_int => |value| value.result,
        .constant_bool => |value| value.result,
        .constant_str => |value| value.result,
        .constant_float32 => |value| value.result,
        .constant_float64 => |value| value.result,
        .optional_null => |value| value.result,
        .optional_some => |value| value.result,
        .optional_unwrap => |value| value.result,
        .protocol_test => |value| value.result,
        .protocol_extract => |value| value.result,
        .enum_test => |value| value.result,
        .enum_payload => |value| value.result,
        .enum_raw => |value| value.result,
        .field_load => |value| value.result,
        .collection_count => |value| value.result,
        .local_load => |value| value.result,
        .reference_field => |value| value.result,
        .reference_optional => |value| value.result,
        .collection_reference => |value| value.result,
        .string_count => |value| value.result,
        .string_byte_at => |value| value.result,
        .string_from_bytes => |value| value.result,
        .binary => |value| if (isRemovableBinary(value.operator)) value.result else null,
        else => null,
    };
}

fn isRemovableBinary(operator: Ir.BinaryOperator) bool {
    return isComparison(operator) or operator == .bit_and or operator == .bit_xor;
}

fn countUses(instruction: Ir.Instruction, uses: []usize) void {
    switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_str,
        .constant_bytes,
        .constant_float32,
        .constant_float64,
        .optional_null,
        .global_load,
        .local_load,
        .local_address,
        => {},
        .function_reference => |value| useValues(uses, value.captures),
        .optional_some => |value| useValue(uses, value.operand),
        .optional_unwrap => |value| useValue(uses, value.operand),
        .copy => |value| useValue(uses, value.operand),
        .deep_copy => |value| useValue(uses, value.operand),
        .class_cast => |value| useValue(uses, value.operand),
        .class_retain => |value| useValue(uses, value.operand),
        .class_drop => |value| useValue(uses, value.operand),
        .list_retain, .list_drop, .string_retain, .string_drop => |value| useValue(uses, value.operand),
        .global_store => |value| useValue(uses, value.operand),
        .structure_init => |value| useValues(uses, value.fields),
        .protocol_init => |value| useValue(uses, value.operand),
        .protocol_test => |value| useValue(uses, value.operand),
        .protocol_extract => |value| useValue(uses, value.operand),
        .list_init => |value| useValues(uses, value.values),
        .enum_init => |value| useValues(uses, value.values),
        .enum_test => |value| useValue(uses, value.operand),
        .enum_payload => |value| useValue(uses, value.operand),
        .enum_raw => |value| useValue(uses, value.operand),
        .field_load => |value| useValue(uses, value.base),
        .field_store => |value| {
            useValue(uses, value.base);
            useValue(uses, value.replacement);
        },
        .collection_load => |value| {
            useValue(uses, value.collection);
            useValue(uses, value.index);
        },
        .collection_reference => |value| {
            useValue(uses, value.collection);
            useOptional(uses, value.reference);
            useValue(uses, value.index);
        },
        .collection_replace => |value| {
            useValue(uses, value.collection);
            useValue(uses, value.index);
            useValue(uses, value.replacement);
        },
        .collection_count => |value| useValue(uses, value.collection),
        .list_edit => |value| {
            useValue(uses, value.collection);
            useOptional(uses, value.index);
            useOptional(uses, value.argument);
        },
        .collection_slice, .collection_view => |value| {
            useValue(uses, value.collection);
            useValue(uses, value.start);
            useValue(uses, value.end);
            useOptional(uses, value.reference);
        },
        .string_address, .string_byte_count => |value| useValue(uses, value.operand),
        .string_byte_at => |value| {
            useValue(uses, value.operand);
            useValue(uses, value.index);
        },
        .string_from_bytes => |value| useValue(uses, value.bytes),
        .local_store => |value| useValue(uses, value.operand),
        .reference_load => |value| useValue(uses, value.reference),
        .address_load => |value| {
            useValue(uses, value.address);
            useValue(uses, value.byte_offset);
        },
        .address_store => |value| {
            useValue(uses, value.address);
            useValue(uses, value.byte_offset);
            useValue(uses, value.operand);
        },
        .reference_store => |value| {
            useValue(uses, value.reference);
            useValue(uses, value.operand);
        },
        .reference_field => |value| useValue(uses, value.reference),
        .reference_optional => |value| useValue(uses, value.reference),
        .convert => |value| useValue(uses, value.operand),
        .format_value => |value| useValue(uses, value.operand),
        .string_concat => |value| {
            useValue(uses, value.left);
            useValue(uses, value.right);
        },
        .string_count => |value| useValue(uses, value.operand),
        .unary => |value| useValue(uses, value.operand),
        .binary => |value| {
            useValue(uses, value.left);
            useValue(uses, value.right);
        },
        .call => |value| useValues(uses, value.arguments),
        .indirect_call => |value| {
            useValue(uses, value.callee);
            useValues(uses, value.arguments);
        },
        .boundary_call => |value| useValues(uses, value.arguments),
        .dynamic_call => |value| {
            useValue(uses, value.receiver);
            useValues(uses, value.arguments);
        },
        .print => |value| useValue(uses, value.value),
        .assert => |value| {
            useValue(uses, value.condition);
            useValue(uses, value.message);
        },
        .mutex_lock, .mutex_unlock => {},
    }
}

fn countTerminatorUses(terminator: Ir.Terminator, uses: []usize) void {
    switch (terminator) {
        .return_value => |value| useValue(uses, value),
        .branch => |value| useValue(uses, value.condition),
        .panic => |value| useValue(uses, value.message),
        else => {},
    }
}

fn useValue(uses: []usize, value: Ir.ValueId) void {
    uses[value] += 1;
}

fn useValues(uses: []usize, values: []const Ir.ValueId) void {
    for (values) |value| useValue(uses, value);
}

fn useOptional(uses: []usize, value: ?Ir.ValueId) void {
    if (value) |present| useValue(uses, present);
}

fn signedValue(bits: u64, width: u7) i128 {
    const value: i128 = @intCast(masked(bits, width));
    const sign: i128 = @as(i128, 1) << @intCast(width - 1);
    return if (value & sign != 0) value - (@as(i128, 1) << @intCast(width)) else value;
}

fn signedMinimum(width: u7) i128 {
    return -(@as(i128, 1) << @intCast(width - 1));
}

fn fitsSigned(value: i128, width: u7) bool {
    const minimum = signedMinimum(width);
    const maximum = (@as(i128, 1) << @intCast(width - 1)) - 1;
    return value >= minimum and value <= maximum;
}

fn unsignedMaximum(width: u7) u128 {
    return (@as(u128, 1) << @intCast(width)) - 1;
}

fn masked(bits: u64, width: u7) u64 {
    return if (width == 64) bits else bits & ((@as(u64, 1) << @intCast(width)) - 1);
}

fn integerBits(value: i128, width: u7) u64 {
    return masked(@bitCast(@as(i64, @intCast(value))), width);
}

test "release folds constants and propagates copies in straight-line code" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const value_types = [_]Ir.Type{ .int, .int, .int, .int };
    const instructions = [_]Ir.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 20 } },
        .{ .copy = .{ .result = 1, .operand = 0 } },
        .{ .constant_int = .{ .result = 2, .bits = 22 } },
        .{ .binary = .{ .result = 3, .operator = .add, .left = 1, .right = 2 } },
    };
    const blocks = [_]Ir.Block{.{ .instructions = &instructions, .terminator = .{ .return_value = 3 } }};
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "answer",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &value_types,
        .blocks = &blocks,
    }} };
    const optimized = try optimize(allocator, program);
    try std.testing.expectEqual(@as(usize, 1), optimized.functions[0].blocks.len);
    const text = try Ir.writeText(allocator, optimized);
    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "const 42"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "copy"));
}

test "release preserves effects and observable execution" {
    const Frontend = @import("../Frontend.zig");
    const Interpreter = @import("../Interpreter.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Resource {
        \\    let value:int
        \\    drop { print("drop ", self.value) }
        \\}
        \\func calculate(limit:int) int {
        \\    var total = 0
        \\    var index = 0
        \\    while index < limit {
        \\        total += index
        \\        index += 1
        \\    }
        \\    return total
        \\}
        \\func main() {
        \\    let resource = Resource(value:3)
        \\    let answer = calculate(10)
        \\    assert(answer == 45, "wrong answer")
        \\    print(answer)
        \\}
    );
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const optimized = try optimize(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqual(reference.exit_code, release.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, release.stdout);
    try std.testing.expectEqualStrings(reference.stderr, release.stderr);
}

test "release preserves floating branches and loops" {
    const Frontend = @import("../Frontend.zig");
    const Interpreter = @import("../Interpreter.zig");
    const Lower = @import("../Arm64/Lower.zig");
    const Runner = @import("../Arm64/Runner.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func root(value:float) float {
        \\    if value < 0.0 { return invalid(value) }
        \\    if value == 0.0 || value + value == value { return value }
        \\    var estimate = 1.0
        \\    if value > 1.0 { estimate = value }
        \\    var previous = 0.0
        \\    var iteration = 0
        \\    while iteration < 128 {
        \\        let next = (estimate + value / estimate) * 0.5
        \\        if next == estimate || next == previous { return next }
        \\        previous = estimate
        \\        estimate = next
        \\        iteration += 1
        \\    }
        \\    return estimate
        \\}
        \\func invalid(value:float) float {
        \\    let zero = value - value
        \\    return zero / zero
        \\}
        \\func main() { assert(root(0.0) == 0.0, "root zero") }
    );
    const optimized = try optimize(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqual(@as(u8, 0), release.exit_code);
    try std.testing.expectEqualStrings("", release.stderr);
    const machine = try Lower.lowerWithMode(allocator, optimized, .release);
    const native = try Runner.invoke(allocator, machine, 0, &.{0});
    try std.testing.expectEqual(@as(i64, 0), native.value);
}

test "release removes calls to proven constant functions" {
    const Frontend = @import("../Frontend.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func answer() int { return 42 }
        \\func main() { print(answer()) }
    );
    const optimized = try optimize(allocator, compilation.ir);
    const text = try Ir.writeText(allocator, optimized);
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "call @answer"));
    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "const 42"));
}

test "release inlines proven identity and scalar binary functions" {
    const Frontend = @import("../Frontend.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func identity(value:int) int { return value }
        \\func add(left:int, right:int) int { return left + right }
        \\func main() { print(add(identity(20), 22)) }
    );
    const optimized = try optimize(allocator, compilation.ir);
    const text = try Ir.writeText(allocator, optimized);
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "call @identity"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "call @add"));
}
