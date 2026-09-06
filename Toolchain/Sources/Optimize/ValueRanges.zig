const std = @import("std");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");

const Allocator = std.mem.Allocator;

const Interval = struct {
    minimum: i128,
    maximum: i128,
};

const Fact = union(enum) {
    absent,
    unknown,
    interval: Interval,
};

pub fn optimize(allocator: Allocator, program: Ir.Program) !Ir.Program {
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, index| {
        functions[index] = try optimizeFunction(allocator, function);
    }
    var result = program;
    result.functions = functions;
    return result;
}

fn optimizeFunction(allocator: Allocator, function: Ir.Function) !Ir.Function {
    if (function.blocks.len == 0 or function.value_types.len == 0) return function;
    const value_count = function.value_types.len;
    const block_count = function.blocks.len;
    const predecessors = try buildPredecessors(allocator, function.blocks);
    const comparisons = try comparisonDefinitions(allocator, function);
    const entry = try allocator.alloc(Fact, block_count * value_count);
    const exit = try allocator.alloc(Fact, block_count * value_count);
    @memset(entry, .absent);
    @memset(exit, .absent);
    const entry_reachable = try allocator.alloc(bool, block_count);
    const exit_reachable = try allocator.alloc(bool, block_count);
    @memset(entry_reachable, false);
    @memset(exit_reachable, false);
    const incoming = try allocator.alloc(Fact, value_count);
    const working = try allocator.alloc(Fact, value_count);

    var converged = false;
    const maximum_iterations = block_count * 4 + 8;
    for (0..maximum_iterations) |iteration| {
        var changed = false;
        for (0..block_count) |block_id| {
            const incoming_reachable = incomingFacts(
                function,
                block_id,
                predecessors,
                comparisons,
                exit,
                exit_reachable,
                incoming,
            );
            const reachable = block_id == 0 or incoming_reachable;
            if (!reachable) continue;
            if (!entry_reachable[block_id]) {
                entry_reachable[block_id] = true;
                changed = true;
            }
            // Widen only where a backward edge merges into a loop header.
            // Widening every block in the cyclic region would erase bounds
            // established by a dominating branch before its loop body.
            const widen = iteration >= block_count and hasBackwardPredecessor(predecessors[block_id].items, block_id);
            for (0..value_count) |value| {
                if (accumulate(
                    &entry[at(value_count, block_id, value)],
                    incoming[value],
                    function.value_types[value],
                    widen,
                )) changed = true;
            }

            @memcpy(working, entry[block_id * value_count ..][0..value_count]);
            for (function.blocks[block_id].instructions) |instruction| {
                transfer(function, working, instruction);
            }
            if (!exit_reachable[block_id]) {
                exit_reachable[block_id] = true;
                changed = true;
            }
            for (0..value_count) |value| {
                if (accumulate(
                    &exit[at(value_count, block_id, value)],
                    working[value],
                    function.value_types[value],
                    widen,
                )) changed = true;
            }
        }
        if (!changed) {
            converged = true;
            break;
        }
    }
    if (!converged) return function;

    const blocks = try allocator.alloc(Ir.Block, block_count);
    const facts = try allocator.alloc(Fact, value_count);
    for (function.blocks, 0..) |block, block_id| {
        @memcpy(facts, entry[block_id * value_count ..][0..value_count]);
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |original| {
            const rewritten = rewriteInstruction(function, facts, original);
            try instructions.append(allocator, rewritten);
            transfer(function, facts, rewritten);
        }
        blocks[block_id] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = block.terminator,
        };
    }
    var result = function;
    result.blocks = blocks;
    return result;
}

fn incomingFacts(
    function: Ir.Function,
    block_id: Ir.BlockId,
    predecessors: []const std.ArrayList(Ir.BlockId),
    comparisons: []const ?Ir.Instruction.Binary,
    exits: []const Fact,
    exit_reachable: []const bool,
    facts: []Fact,
) bool {
    const value_count = function.value_types.len;
    @memset(facts, .absent);
    var reachable = false;
    if (block_id == 0) {
        reachable = true;
        const initial_count = function.capture_types.len + function.parameter_types.len;
        for (0..initial_count) |value| if (function.value_types[value].isInteger()) {
            facts[value] = .{ .interval = typeInterval(function.value_types[value]) };
        };
    }
    for (predecessors[block_id].items) |predecessor| {
        if (!exit_reachable[predecessor] or !edgePossible(
            function,
            predecessor,
            block_id,
            comparisons,
            exits[predecessor * value_count ..][0..value_count],
        )) continue;
        reachable = true;
        for (0..value_count) |value| {
            var incoming = exits[at(value_count, predecessor, value)];
            incoming = refineForEdge(
                function,
                predecessor,
                block_id,
                value,
                comparisons,
                exits[predecessor * value_count ..][0..value_count],
                incoming,
            );
            facts[value] = joinFacts(facts[value], incoming);
        }
    }
    return reachable;
}

fn edgePossible(
    function: Ir.Function,
    predecessor: Ir.BlockId,
    target: Ir.BlockId,
    comparisons: []const ?Ir.Instruction.Binary,
    facts: []const Fact,
) bool {
    const branch = switch (function.blocks[predecessor].terminator) {
        .branch => |value| value,
        else => return true,
    };
    if (branch.then_block == branch.else_block) return true;
    const comparison = comparisons[branch.condition] orelse return true;
    const proven = comparisonResult(comparison, facts) orelse return true;
    return if (target == branch.then_block) proven else !proven;
}

fn refineForEdge(
    function: Ir.Function,
    predecessor: Ir.BlockId,
    target: Ir.BlockId,
    value: Ir.ValueId,
    comparisons: []const ?Ir.Instruction.Binary,
    facts: []const Fact,
    original: Fact,
) Fact {
    const branch = switch (function.blocks[predecessor].terminator) {
        .branch => |item| item,
        else => return original,
    };
    if (branch.then_block == branch.else_block) return original;
    const comparison = comparisons[branch.condition] orelse return original;
    const truth = target == branch.then_block;
    if (value == comparison.left) {
        return refineComparison(original, facts[comparison.right], comparison.operator, truth);
    }
    if (value == comparison.right) {
        return refineComparison(original, facts[comparison.left], swappedComparison(comparison.operator), truth);
    }
    return original;
}

fn refineComparison(left: Fact, right: Fact, operator: Ir.BinaryOperator, truth: bool) Fact {
    if (left != .interval or right != .interval) return left;
    var result = left.interval;
    const other = right.interval;
    switch (operator) {
        .less => if (truth) {
            result.maximum = @min(result.maximum, other.maximum -| 1);
        } else {
            result.minimum = @max(result.minimum, other.minimum);
        },
        .less_equal => if (truth) {
            result.maximum = @min(result.maximum, other.maximum);
        } else {
            result.minimum = @max(result.minimum, other.minimum +| 1);
        },
        .greater => if (truth) {
            result.minimum = @max(result.minimum, other.minimum +| 1);
        } else {
            result.maximum = @min(result.maximum, other.maximum);
        },
        .greater_equal => if (truth) {
            result.minimum = @max(result.minimum, other.minimum);
        } else {
            result.maximum = @min(result.maximum, other.maximum -| 1);
        },
        .equal => if (truth) {
            result.minimum = @max(result.minimum, other.minimum);
            result.maximum = @min(result.maximum, other.maximum);
        },
        .not_equal => if (!truth) {
            result.minimum = @max(result.minimum, other.minimum);
            result.maximum = @min(result.maximum, other.maximum);
        },
        else => return left,
    }
    return if (result.minimum <= result.maximum) .{ .interval = result } else .absent;
}

fn rewriteInstruction(function: Ir.Function, facts: []const Fact, instruction: Ir.Instruction) Ir.Instruction {
    return switch (instruction) {
        .binary => |binary| rewrite: {
            if (isComparison(binary.operator)) {
                if (comparisonResult(binary, facts)) |value| {
                    break :rewrite .{ .constant_bool = .{ .result = binary.result, .value = value } };
                }
            }
            if (binary.checked and arithmeticFits(function, facts, binary)) {
                var unchecked = binary;
                unchecked.checked = false;
                break :rewrite .{ .binary = unchecked };
            }
            if (binary.checked and shiftCountFits(function, facts, binary)) {
                var unchecked = binary;
                unchecked.checked = false;
                break :rewrite .{ .binary = unchecked };
            }
            if (binary.checked and divisionFits(function, facts, binary)) {
                var unchecked = binary;
                unchecked.checked = false;
                break :rewrite .{ .binary = unchecked };
            }
            break :rewrite instruction;
        },
        .convert => |conversion| rewrite: {
            if (!conversion.checked or !conversion.target.isInteger()) break :rewrite instruction;
            const operand = facts[conversion.operand];
            if (operand != .interval or !contains(typeInterval(conversion.target), operand.interval))
                break :rewrite instruction;
            var unchecked = conversion;
            unchecked.checked = false;
            break :rewrite .{ .convert = unchecked };
        },
        else => instruction,
    };
}

fn shiftCountFits(function: Ir.Function, facts: []const Fact, binary: Ir.Instruction.Binary) bool {
    if (binary.operator != .shift_left and binary.operator != .shift_right) return false;
    if (!function.value_types[binary.left].isInteger() or facts[binary.right] != .interval) return false;
    const count = facts[binary.right].interval;
    return count.minimum >= 0 and count.maximum < function.value_types[binary.left].bitWidth();
}

fn divisionFits(function: Ir.Function, facts: []const Fact, binary: Ir.Instruction.Binary) bool {
    if (binary.operator != .divide and binary.operator != .remainder) return false;
    const type_value = function.value_types[binary.left];
    if (!type_value.isInteger() or facts[binary.left] != .interval or facts[binary.right] != .interval)
        return false;
    const left = facts[binary.left].interval;
    const right = facts[binary.right].interval;
    if (right.minimum <= 0 and right.maximum >= 0) return false;
    if (!type_value.isSignedInteger()) return true;
    const includes_negative_one = right.minimum <= -1 and right.maximum >= -1;
    const includes_minimum = left.minimum <= Numeric.integerMin(type_value) and
        left.maximum >= Numeric.integerMin(type_value);
    return !includes_negative_one or !includes_minimum;
}

fn arithmeticFits(function: Ir.Function, facts: []const Fact, binary: Ir.Instruction.Binary) bool {
    if (binary.operator != .add and binary.operator != .subtract and binary.operator != .multiply) return false;
    const type_value = function.value_types[binary.result];
    if (!type_value.isInteger() or facts[binary.left] != .interval or facts[binary.right] != .interval)
        return false;
    const mathematical = arithmeticInterval(binary.operator, facts[binary.left].interval, facts[binary.right].interval) orelse
        return false;
    return contains(typeInterval(type_value), mathematical);
}

fn comparisonResult(binary: Ir.Instruction.Binary, facts: []const Fact) ?bool {
    if (!isComparison(binary.operator) or facts[binary.left] != .interval or facts[binary.right] != .interval)
        return null;
    const left = facts[binary.left].interval;
    const right = facts[binary.right].interval;
    return switch (binary.operator) {
        .less => if (left.maximum < right.minimum) true else if (left.minimum >= right.maximum) false else null,
        .less_equal => if (left.maximum <= right.minimum) true else if (left.minimum > right.maximum) false else null,
        .greater => if (left.minimum > right.maximum) true else if (left.maximum <= right.minimum) false else null,
        .greater_equal => if (left.minimum >= right.maximum) true else if (left.maximum < right.minimum) false else null,
        .equal => if (left.minimum == left.maximum and right.minimum == right.maximum and left.minimum == right.minimum)
            true
        else if (left.maximum < right.minimum or right.maximum < left.minimum)
            false
        else
            null,
        .not_equal => if (left.maximum < right.minimum or right.maximum < left.minimum)
            true
        else if (left.minimum == left.maximum and right.minimum == right.maximum and left.minimum == right.minimum)
            false
        else
            null,
        else => null,
    };
}

fn transfer(function: Ir.Function, facts: []Fact, instruction: Ir.Instruction) void {
    const result = instructionResult(instruction) orelse return;
    if (!function.value_types[result].isInteger()) return;
    facts[result] = switch (instruction) {
        .constant_int => |constant| .{ .interval = constantInterval(function.value_types[result], constant.bits) },
        .copy, .deep_copy => |copy| facts[copy.operand],
        .unary => |unary| unaryInterval(function.value_types[result], facts[unary.operand]),
        .binary => |binary| binaryResultInterval(function.value_types[result], facts, binary),
        .convert => |conversion| conversionInterval(conversion.target, facts[conversion.operand]),
        else => .{ .interval = typeInterval(function.value_types[result]) },
    };
}

fn binaryResultInterval(type_value: Ir.Type, facts: []const Fact, binary: Ir.Instruction.Binary) Fact {
    if (facts[binary.left] != .interval or facts[binary.right] != .interval)
        return .{ .interval = typeInterval(type_value) };
    const left = facts[binary.left].interval;
    const right = facts[binary.right].interval;
    const mathematical = switch (binary.operator) {
        .add, .subtract, .multiply => arithmeticInterval(binary.operator, left, right),
        .remainder => remainderInterval(type_value, left, right),
        .minimum => Interval{ .minimum = @min(left.minimum, right.minimum), .maximum = @min(left.maximum, right.maximum) },
        .maximum => Interval{ .minimum = @max(left.minimum, right.minimum), .maximum = @max(left.maximum, right.maximum) },
        else => null,
    } orelse return .{ .interval = typeInterval(type_value) };
    return .{ .interval = intersectOrFull(mathematical, typeInterval(type_value)) };
}

fn remainderInterval(type_value: Ir.Type, dividend: Interval, divisor: Interval) ?Interval {
    if (!type_value.isInteger() or divisor.minimum != divisor.maximum or divisor.minimum == 0) return null;
    const magnitude = if (divisor.minimum < 0) -divisor.minimum else divisor.minimum;
    const maximum_remainder = magnitude - 1;
    if (!type_value.isSignedInteger()) return .{ .minimum = 0, .maximum = maximum_remainder };
    return .{
        .minimum = if (dividend.minimum < 0) -maximum_remainder else 0,
        .maximum = if (dividend.maximum > 0) maximum_remainder else 0,
    };
}

fn arithmeticInterval(operator: Ir.BinaryOperator, left: Interval, right: Interval) ?Interval {
    return switch (operator) {
        .add => .{
            .minimum = std.math.add(i128, left.minimum, right.minimum) catch return null,
            .maximum = std.math.add(i128, left.maximum, right.maximum) catch return null,
        },
        .subtract => .{
            .minimum = std.math.sub(i128, left.minimum, right.maximum) catch return null,
            .maximum = std.math.sub(i128, left.maximum, right.minimum) catch return null,
        },
        .multiply => multiplyInterval(left, right),
        else => null,
    };
}

fn multiplyInterval(left: Interval, right: Interval) ?Interval {
    const products = [_]i128{
        std.math.mul(i128, left.minimum, right.minimum) catch return null,
        std.math.mul(i128, left.minimum, right.maximum) catch return null,
        std.math.mul(i128, left.maximum, right.minimum) catch return null,
        std.math.mul(i128, left.maximum, right.maximum) catch return null,
    };
    var minimum = products[0];
    var maximum = products[0];
    for (products[1..]) |product| {
        minimum = @min(minimum, product);
        maximum = @max(maximum, product);
    }
    return .{ .minimum = minimum, .maximum = maximum };
}

fn unaryInterval(type_value: Ir.Type, operand: Fact) Fact {
    if (operand != .interval) return .{ .interval = typeInterval(type_value) };
    const minimum = std.math.negate(operand.interval.maximum) catch return .{ .interval = typeInterval(type_value) };
    const maximum = std.math.negate(operand.interval.minimum) catch return .{ .interval = typeInterval(type_value) };
    return .{ .interval = intersectOrFull(.{ .minimum = minimum, .maximum = maximum }, typeInterval(type_value)) };
}

fn conversionInterval(target: Ir.Type, operand: Fact) Fact {
    if (operand != .interval) return .{ .interval = typeInterval(target) };
    return .{ .interval = intersectOrFull(operand.interval, typeInterval(target)) };
}

fn accumulate(destination: *Fact, incoming: Fact, type_value: Ir.Type, widen: bool) bool {
    if (incoming == .absent) return false;
    var next = joinFacts(destination.*, incoming);
    if (widen and destination.* == .interval and next == .interval) {
        const full = typeInterval(type_value);
        if (next.interval.minimum < destination.interval.minimum) next.interval.minimum = full.minimum;
        if (next.interval.maximum > destination.interval.maximum) next.interval.maximum = full.maximum;
    }
    if (std.meta.eql(destination.*, next)) return false;
    destination.* = next;
    return true;
}

fn joinFacts(left: Fact, right: Fact) Fact {
    if (left == .absent) return right;
    if (right == .absent) return left;
    if (left == .unknown or right == .unknown) return .unknown;
    return .{ .interval = .{
        .minimum = @min(left.interval.minimum, right.interval.minimum),
        .maximum = @max(left.interval.maximum, right.interval.maximum),
    } };
}

fn contains(container: Interval, value: Interval) bool {
    return value.minimum >= container.minimum and value.maximum <= container.maximum;
}

fn intersectOrFull(left: Interval, right: Interval) Interval {
    const minimum = @max(left.minimum, right.minimum);
    const maximum = @min(left.maximum, right.maximum);
    return if (minimum <= maximum) .{ .minimum = minimum, .maximum = maximum } else right;
}

fn typeInterval(type_value: Ir.Type) Interval {
    return if (type_value.isSignedInteger()) .{
        .minimum = Numeric.integerMin(type_value),
        .maximum = Numeric.integerMax(type_value),
    } else .{
        .minimum = 0,
        .maximum = Numeric.integerMax(type_value),
    };
}

fn constantInterval(type_value: Ir.Type, bits: u64) Interval {
    const value: i128 = if (type_value.isSignedInteger())
        @as(i64, @bitCast(Numeric.signExtend(bits, type_value.bitWidth())))
    else
        bits;
    return .{ .minimum = value, .maximum = value };
}

fn comparisonDefinitions(allocator: Allocator, function: Ir.Function) ![]?Ir.Instruction.Binary {
    const result = try allocator.alloc(?Ir.Instruction.Binary, function.value_types.len);
    const counts = try allocator.alloc(usize, function.value_types.len);
    @memset(result, null);
    @memset(counts, 0);
    for (function.blocks) |block| for (block.instructions) |instruction| {
        const value = instructionResult(instruction) orelse continue;
        counts[value] += 1;
        if (instruction == .binary and isComparison(instruction.binary.operator)) result[value] = instruction.binary;
    };
    for (result, 0..) |*comparison, value| if (counts[value] != 1) {
        comparison.* = null;
    };
    return result;
}

fn buildPredecessors(allocator: Allocator, blocks: []const Ir.Block) ![]std.ArrayList(Ir.BlockId) {
    const result = try allocator.alloc(std.ArrayList(Ir.BlockId), blocks.len);
    for (result) |*list| list.* = .empty;
    for (blocks, 0..) |block, predecessor| switch (block.terminator) {
        .jump => |target| try result[target].append(allocator, predecessor),
        .branch => |branch| {
            try result[branch.then_block].append(allocator, predecessor);
            if (branch.else_block != branch.then_block) try result[branch.else_block].append(allocator, predecessor);
        },
        else => {},
    };
    return result;
}

fn hasBackwardPredecessor(predecessors: []const Ir.BlockId, block: Ir.BlockId) bool {
    for (predecessors) |predecessor| if (predecessor >= block) return true;
    return false;
}

fn swappedComparison(operator: Ir.BinaryOperator) Ir.BinaryOperator {
    return switch (operator) {
        .less => .greater,
        .less_equal => .greater_equal,
        .greater => .less,
        .greater_equal => .less_equal,
        else => operator,
    };
}

fn isComparison(operator: Ir.BinaryOperator) bool {
    return switch (operator) {
        .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => true,
        else => false,
    };
}

fn instructionResult(instruction: Ir.Instruction) ?Ir.ValueId {
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
        => null,
        .list_edit => |value| value.result,
        .call => |value| value.result,
        .indirect_call => |value| value.result,
        .boundary_call => |value| value.result,
        .boundary_indirect_call => |value| value.result,
        .dynamic_call => |value| value.result,
        inline else => |value| value.result,
    };
}

fn at(value_count: usize, block: usize, value: usize) usize {
    return block * value_count + value;
}

test "dominant integer bounds remove only proven overflow checks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const blocks = [_]Ir.Block{
        .{ .instructions = &.{
            .{ .constant_int = .{ .result = 1, .bits = 100 } },
            .{ .binary = .{ .result = 2, .operator = .less, .left = 0, .right = 1 } },
        }, .terminator = .{ .branch = .{ .condition = 2, .then_block = 1, .else_block = 2 } } },
        .{ .instructions = &.{
            .{ .constant_int = .{ .result = 3, .bits = 1 } },
            .{ .binary = .{ .result = 4, .operator = .add, .left = 0, .right = 3, .checked = true } },
        }, .terminator = .{ .return_value = 4 } },
        .{ .instructions = &.{
            .{ .constant_int = .{ .result = 5, .bits = 1 } },
            .{ .binary = .{ .result = 6, .operator = .add, .left = 0, .right = 5, .checked = true } },
        }, .terminator = .{ .return_value = 0 } },
    };
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "bounded",
        .parameter_types = &.{.int8},
        .return_type = .int8,
        .value_types = &.{ .int8, .int8, .bool, .int8, .int8, .int8, .int8 },
        .blocks = &blocks,
    }} };
    const optimized = try optimize(allocator, program);
    try std.testing.expect(!optimized.functions[0].blocks[1].instructions[1].binary.checked);
    try std.testing.expect(optimized.functions[0].blocks[2].instructions[1].binary.checked);
}

test "loop exit bound proves induction increment" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const blocks = [_]Ir.Block{
        .{ .instructions = &.{
            .{ .constant_int = .{ .result = 1, .bits = 0 } },
            .{ .copy = .{ .result = 5, .operand = 1 } },
        }, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{
            .{ .binary = .{ .result = 2, .operator = .less, .left = 5, .right = 0 } },
        }, .terminator = .{ .branch = .{ .condition = 2, .then_block = 2, .else_block = 3 } } },
        .{ .instructions = &.{
            .{ .constant_int = .{ .result = 3, .bits = 1 } },
            .{ .binary = .{ .result = 4, .operator = .add, .left = 5, .right = 3, .checked = true } },
            .{ .copy = .{ .result = 5, .operand = 4 } },
        }, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{}, .terminator = .{ .return_value = 5 } },
    };
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "bounded_loop",
        .parameter_types = &.{.int},
        .return_type = .int,
        .value_types = &.{ .int, .int, .bool, .int, .int, .int },
        .blocks = &blocks,
    }} };
    const optimized = try optimize(allocator, program);
    try std.testing.expect(!optimized.functions[0].blocks[2].instructions[1].binary.checked);
}

test "constant remainder bounds prove dependent arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "bounded_remainder",
        .parameter_types = &.{.int},
        .return_type = .int,
        .value_types = &.{ .int, .int, .int, .int, .int },
        .blocks = &.{.{
            .instructions = &.{
                .{ .constant_int = .{ .result = 1, .bits = 97 } },
                .{ .binary = .{ .result = 2, .operator = .remainder, .left = 0, .right = 1 } },
                .{ .constant_int = .{ .result = 3, .bits = 1 } },
                .{ .binary = .{ .result = 4, .operator = .add, .left = 2, .right = 3, .checked = true } },
            },
            .terminator = .{ .return_value = 4 },
        }},
    }} };
    const optimized = try optimize(allocator, program);
    try std.testing.expect(!optimized.functions[0].blocks[0].instructions[1].binary.checked);
    try std.testing.expect(!optimized.functions[0].blocks[0].instructions[3].binary.checked);
}

test "constant shift counts remove only proven width checks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "bounded_shift",
        .parameter_types = &.{ .uint32, .int8 },
        .return_type = .uint32,
        .value_types = &.{ .uint32, .int8, .uint8, .uint32, .uint32 },
        .blocks = &.{.{
            .instructions = &.{
                .{ .constant_int = .{ .result = 2, .bits = 5 } },
                .{ .binary = .{ .result = 3, .operator = .shift_left, .left = 0, .right = 2 } },
                .{ .binary = .{ .result = 4, .operator = .shift_right, .left = 0, .right = 1 } },
            },
            .terminator = .{ .return_value = 3 },
        }},
    }} };
    const optimized = try optimize(allocator, program);
    try std.testing.expect(!optimized.functions[0].blocks[0].instructions[1].binary.checked);
    try std.testing.expect(optimized.functions[0].blocks[0].instructions[2].binary.checked);
}

test "constant divisors remove only proven division checks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "bounded_division",
        .parameter_types = &.{.int},
        .return_type = .int,
        .value_types = &.{ .int, .int, .int, .int, .int, .int },
        .blocks = &.{.{
            .instructions = &.{
                .{ .constant_int = .{ .result = 1, .bits = 3 } },
                .{ .binary = .{ .result = 2, .operator = .divide, .left = 0, .right = 1 } },
                .{ .constant_int = .{ .result = 3, .bits = @bitCast(@as(i64, -1)) } },
                .{ .binary = .{ .result = 4, .operator = .remainder, .left = 0, .right = 3 } },
                .{ .binary = .{ .result = 5, .operator = .divide, .left = 0, .right = 0 } },
            },
            .terminator = .{ .return_value = 2 },
        }},
    }} };
    const optimized = try optimize(allocator, program);
    try std.testing.expect(!optimized.functions[0].blocks[0].instructions[1].binary.checked);
    try std.testing.expect(optimized.functions[0].blocks[0].instructions[3].binary.checked);
    try std.testing.expect(optimized.functions[0].blocks[0].instructions[4].binary.checked);
}
