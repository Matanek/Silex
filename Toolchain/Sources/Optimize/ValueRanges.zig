const std = @import("std");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const Workers = @import("../Workers.zig");
const RangeCache = @import("RangeCache.zig");

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
    return optimizeWithWorkers(allocator, program, 1);
}

pub fn optimizeWithWorkers(allocator: Allocator, program: Ir.Program, requested: u16) !Ir.Program {
    return optimizeWithCache(allocator, program, requested, null);
}

pub fn optimizeWithCache(allocator: Allocator, program: Ir.Program, requested: u16, cache: ?RangeCache.Context) !Ir.Program {
    defer if (cache) |context| RangeCache.flush(context);
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    const count = Workers.selectedCount(program.functions.len, requested);
    if (count == 1) {
        for (program.functions, 0..) |function, index|
            functions[index] = try optimizeCachedFunction(allocator, function, cache);
    } else {
        var next = std.atomic.Value(usize).init(0);
        var workers: [Workers.max_count]Worker = undefined;
        for (workers[0..count]) |*worker| worker.* = .{
            .allocator = allocator,
            .source = program.functions,
            .destination = functions,
            .next = &next,
            .cache = cache,
        };
        Workers.run(Worker, workers[0..count], Worker.run);
        for (workers[0..count]) |worker| if (worker.failure) |err| return err;
    }
    var result = program;
    result.functions = functions;
    return result;
}

const Worker = struct {
    allocator: Allocator,
    source: []const Ir.Function,
    destination: []Ir.Function,
    next: *std.atomic.Value(usize),
    failure: ?anyerror = null,
    cache: ?RangeCache.Context,

    fn run(self: *Worker) void {
        while (true) {
            // Function costs vary sharply; claim the next function instead of
            // leaving one worker with all the large loop bodies.
            const index = self.next.fetchAdd(1, .monotonic);
            if (index >= self.source.len) return;
            self.destination[index] = optimizeCachedFunction(self.allocator, self.source[index], self.cache) catch |err| {
                self.failure = err;
                return;
            };
        }
    }
};

fn optimizeCachedFunction(allocator: Allocator, function: Ir.Function, cache: ?RangeCache.Context) !Ir.Function {
    const digest = if (cache != null) try RangeCache.key(allocator, function) else null;
    if (digest) |key| {
        if (RangeCache.load(allocator, cache.?, key, function)) |cached| return cached;
        _ = cache.?.counters.misses.fetchAdd(1, .monotonic);
    }
    const optimized = try optimizeFunction(allocator, function);
    if (digest) |key| RangeCache.store(allocator, cache.?, key, function, optimized);
    return optimized;
}

fn optimizeFunction(allocator: Allocator, function: Ir.Function) !Ir.Function {
    return solveFunction(allocator, function, true, null);
}

// Keep the dense schedule as a test oracle. The incremental schedule visits
// blocks in the same order and keeps the same widening iterations.
fn solveFunction(allocator: Allocator, function: Ir.Function, comptime incremental: bool, evaluations: ?*usize) !Ir.Function {
    if (function.blocks.len == 0 or function.value_types.len == 0) return function;
    // The caller may retain its program arena for the entire compilation.
    // Analysis tables must release their pages after this function, independently
    // of the rewritten IR allocated below through the caller's allocator.
    var scratch = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer scratch.deinit();
    const temporary = scratch.allocator();
    const value_count = function.value_types.len;
    const active_values = try activeValues(temporary, function, incremental);
    const block_count = function.blocks.len;
    const predecessors = try buildPredecessors(temporary, function.blocks);
    const comparisons = try comparisonDefinitions(temporary, function);
    const entry = try temporary.alloc(Fact, block_count * value_count);
    const exit = try temporary.alloc(Fact, block_count * value_count);
    @memset(entry, .absent);
    @memset(exit, .absent);
    const entry_reachable = try temporary.alloc(bool, block_count);
    const exit_reachable = try temporary.alloc(bool, block_count);
    @memset(entry_reachable, false);
    @memset(exit_reachable, false);
    const incoming = try temporary.alloc(Fact, value_count);
    const working = try temporary.alloc(Fact, value_count);

    const pending = try temporary.alloc(bool, block_count);
    @memset(pending, false);
    pending[0] = true;
    var converged = false;
    const maximum_iterations = block_count * 4 + 8;
    for (0..maximum_iterations) |iteration| {
        var changed = false;
        for (0..block_count) |block_id| {
            if (incremental and !pending[block_id]) continue;
            pending[block_id] = false;
            if (evaluations) |count| count.* += 1;
            const incoming_reachable = incomingFacts(
                function,
                block_id,
                predecessors,
                comparisons,
                active_values,
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
            for (active_values) |value| {
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
            var exit_changed = false;
            if (!exit_reachable[block_id]) {
                exit_reachable[block_id] = true;
                exit_changed = true;
            }
            for (active_values) |value| {
                if (accumulate(
                    &exit[at(value_count, block_id, value)],
                    working[value],
                    function.value_types[value],
                    widen,
                )) exit_changed = true;
            }
            if (exit_changed) {
                changed = true;
                // Reconsider both branch edges: changed facts can make a
                // previously impossible edge reachable.
                switch (function.blocks[block_id].terminator) {
                    .jump => |target| pending[target] = true,
                    .branch => |branch| {
                        pending[branch.then_block] = true;
                        pending[branch.else_block] = true;
                    },
                    else => {},
                }
            }
        }
        if (!changed) {
            converged = true;
            break;
        }
    }
    if (!converged) return function;

    var blocks: ?[]Ir.Block = null;
    const facts = try temporary.alloc(Fact, value_count);
    for (function.blocks, 0..) |block, block_id| {
        @memcpy(facts, entry[block_id * value_count ..][0..value_count]);
        var instructions: ?[]Ir.Instruction = null;
        for (block.instructions, 0..) |original, instruction_id| {
            const rewritten = rewriteInstruction(function, facts, original);
            if (rewritten) |replacement| {
                if (blocks == null) blocks = try allocator.dupe(Ir.Block, function.blocks);
                if (instructions == null) instructions = try allocator.dupe(Ir.Instruction, block.instructions);
                instructions.?[instruction_id] = replacement;
            }
            transfer(function, facts, rewritten orelse original);
        }
        if (instructions) |changed| blocks.?[block_id].instructions = changed;
    }
    var result = function;
    result.blocks = blocks orelse return function;
    return result;
}

// Only integer parameters and integer results can acquire an interval.
// Descriptor slots left by earlier passes and non-integer values stay absent.
fn activeValues(allocator: Allocator, function: Ir.Function, comptime sparse: bool) ![]Ir.ValueId {
    const present = try allocator.alloc(bool, function.value_types.len);
    defer allocator.free(present);
    @memset(present, !sparse);
    if (sparse) {
        for (0..function.capture_types.len + function.parameter_types.len) |value|
            present[value] = function.value_types[value].isInteger();
        for (function.blocks) |block| for (block.instructions) |instruction| {
            if (instructionResult(instruction)) |value|
                present[value] = function.value_types[value].isInteger();
        };
    }
    var values: std.ArrayList(Ir.ValueId) = .empty;
    for (present, 0..) |included, value| if (included) {
        try values.append(allocator, value);
    };
    return values.toOwnedSlice(allocator);
}

fn incomingFacts(
    function: Ir.Function,
    block_id: Ir.BlockId,
    predecessors: []const std.ArrayList(Ir.BlockId),
    comparisons: []const ?Ir.Instruction.Binary,
    active_values: []const Ir.ValueId,
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
        for (active_values) |value| {
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

fn rewriteInstruction(function: Ir.Function, facts: []const Fact, instruction: Ir.Instruction) ?Ir.Instruction {
    return switch (instruction) {
        .binary => |binary| rewrite: {
            if (isComparison(binary.operator)) {
                if (comparisonResult(binary, facts)) |value| {
                    break :rewrite .{ .constant_bool = .{ .result = binary.result, .value = value } };
                }
            }
            var rewritten = binary;
            if (binary.checked and arithmeticFits(function, facts, binary)) {
                rewritten.checked = false;
            }
            if (binary.checked and shiftCountFits(function, facts, binary)) {
                rewritten.checked = false;
            }
            if (binary.checked and divisionFits(function, facts, binary)) {
                rewritten.checked = false;
            }
            if ((binary.operator == .divide or binary.operator == .remainder) and
                function.value_types[binary.left].isSignedInteger() and facts[binary.left] == .interval and
                facts[binary.left].interval.minimum >= 0)
            {
                rewritten.left_non_negative = true;
            }
            if (std.meta.eql(binary, rewritten)) break :rewrite null;
            break :rewrite .{ .binary = rewritten };
        },
        .convert => |conversion| rewrite: {
            if (!conversion.checked or !conversion.target.isInteger()) break :rewrite null;
            const operand = facts[conversion.operand];
            if (operand != .interval or !contains(typeInterval(conversion.target), operand.interval))
                break :rewrite null;
            var unchecked = conversion;
            unchecked.checked = false;
            break :rewrite .{ .convert = unchecked };
        },
        else => null,
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

test "constant signed division records only proven nonnegative dividends" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "nonnegative_dividend",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{ .int, .int, .int, .int, .int },
        .blocks = &.{.{
            .instructions = &.{
                .{ .constant_int = .{ .result = 0, .bits = 42 } },
                .{ .constant_int = .{ .result = 1, .bits = 7 } },
                .{ .binary = .{ .result = 2, .operator = .remainder, .left = 0, .right = 1 } },
                .{ .constant_int = .{ .result = 3, .bits = @bitCast(@as(i64, -42)) } },
                .{ .binary = .{ .result = 4, .operator = .remainder, .left = 3, .right = 1 } },
            },
            .terminator = .{ .return_value = 2 },
        }},
    }} };
    const optimized = try optimize(allocator, program);
    try std.testing.expect(optimized.functions[0].blocks[0].instructions[2].binary.left_non_negative);
    try std.testing.expect(!optimized.functions[0].blocks[0].instructions[4].binary.left_non_negative);
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

test "incremental range analysis matches dense widening without revisiting stable prefixes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const prefix = 24;
    const block_count = prefix + 4;
    for ([_]bool{ false, true }) |reverse| {
        for ([_]bool{ false, true }) |constant_bound| {
            const blocks = try allocator.alloc(Ir.Block, block_count);
            blocks[0] = .{ .instructions = &.{
                .{ .constant_int = .{ .result = 1, .bits = 0 } },
                .{ .copy = .{ .result = 5, .operand = 1 } },
            }, .terminator = .{ .jump = 1 } };
            if (constant_bound) {
                const instructions = try allocator.alloc(Ir.Instruction, blocks[0].instructions.len + 1);
                @memcpy(instructions[0..blocks[0].instructions.len], blocks[0].instructions);
                instructions[instructions.len - 1] = .{ .constant_int = .{ .result = 0, .bits = 10 } };
                blocks[0].instructions = instructions;
            }
            for (1..prefix) |index| blocks[index] = .{ .instructions = &.{}, .terminator = .{ .jump = index + 1 } };
            blocks[prefix] = .{ .instructions = &.{
                .{ .binary = .{ .result = 2, .operator = .less, .left = 5, .right = 0 } },
            }, .terminator = .{ .branch = .{ .condition = 2, .then_block = prefix + 1, .else_block = prefix + 2 } } };
            blocks[prefix + 1] = .{ .instructions = &.{
                .{ .constant_int = .{ .result = 3, .bits = 1 } },
                .{ .binary = .{ .result = 4, .operator = .add, .left = 5, .right = 3, .checked = true } },
                .{ .copy = .{ .result = 5, .operand = 4 } },
            }, .terminator = .{ .jump = prefix } };
            blocks[prefix + 2] = .{ .instructions = &.{}, .terminator = .{ .return_value = 5 } };
            // An unreachable predecessor must never supply facts to the loop.
            blocks[prefix + 3] = .{ .instructions = &.{
                .{ .constant_int = .{ .result = 5, .bits = 127 } },
            }, .terminator = .{ .jump = prefix } };
            if (reverse) {
                std.mem.reverse(Ir.Block, blocks[1..]);
                for (blocks) |*block| switch (block.terminator) {
                    .jump => |*target| target.* = block_count - target.*,
                    .branch => |*branch| {
                        branch.then_block = block_count - branch.then_block;
                        branch.else_block = block_count - branch.else_block;
                    },
                    else => {},
                };
            }
            const value_types = try allocator.alloc(Ir.Type, 256);
            @memcpy(value_types[0..6], &[_]Ir.Type{ .int, .int, .bool, .int, .int, .int });
            @memset(value_types[6..128], .float64);
            @memset(value_types[128..], .int);
            const function: Ir.Function = .{
                .name = "scheduled_loop",
                .parameter_types = &.{.int},
                .return_type = .int,
                .value_types = value_types,
                .blocks = blocks,
            };
            try std.testing.expectEqual(@as(usize, 5), (try activeValues(allocator, function, true)).len);
            var dense_evaluations: usize = 0;
            var incremental_evaluations: usize = 0;
            const dense = try solveFunction(allocator, function, false, &dense_evaluations);
            const incremental = try solveFunction(allocator, function, true, &incremental_evaluations);
            const expected = try Ir.writeText(allocator, .{ .functions = &.{dense} });
            const actual = try Ir.writeText(allocator, .{ .functions = &.{incremental} });
            try std.testing.expectEqualStrings(expected, actual);
            try std.testing.expect(incremental_evaluations < dense_evaluations / 2);
        }
    }
}

test "parallel range analysis preserves function order and loop decisions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const functions = try allocator.alloc(Ir.Function, Workers.minimum_items + 17);
    for (functions, 0..) |*function, index| {
        const instructions = try allocator.alloc(Ir.Instruction, 2);
        instructions[0] = .{ .constant_int = .{ .result = 1, .bits = index } };
        instructions[1] = .{ .copy = .{ .result = 5, .operand = 1 } };
        const blocks = try allocator.alloc(Ir.Block, 4);
        blocks[0] = .{ .instructions = instructions, .terminator = .{ .jump = 1 } };
        blocks[1] = .{ .instructions = &.{
            .{ .binary = .{ .result = 2, .operator = .less, .left = 5, .right = 0 } },
        }, .terminator = .{ .branch = .{ .condition = 2, .then_block = 2, .else_block = 3 } } };
        blocks[2] = .{ .instructions = &.{
            .{ .constant_int = .{ .result = 3, .bits = 1 } },
            .{ .binary = .{ .result = 4, .operator = .add, .left = 5, .right = 3, .checked = true } },
            .{ .copy = .{ .result = 5, .operand = 4 } },
        }, .terminator = .{ .jump = 1 } };
        blocks[3] = .{ .instructions = &.{}, .terminator = .{ .return_value = 5 } };
        function.* = .{
            .name = try std.fmt.allocPrint(allocator, "range_{d}", .{index}),
            .parameter_types = &.{.int},
            .return_type = .int,
            .value_types = &.{ .int, .int, .bool, .int, .int, .int },
            .blocks = blocks,
        };
    }
    const program: Ir.Program = .{ .functions = functions };
    const serial = try Ir.writeText(allocator, try optimize(allocator, program));
    for ([_]u16{ 2, Workers.max_count }) |count| {
        const parallel = try optimizeWithWorkers(allocator, program, count);
        try std.testing.expectEqualStrings(serial, try Ir.writeText(allocator, parallel));
    }
}

test "range decisions survive consumer symbol relocation and invalidate numeric changes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var counters: RangeCache.Counters = .{};
    const context: RangeCache.Context = .{ .store = .{
        .allocator = a,
        .io = std.testing.io,
        .root = try std.fs.path.join(a, &.{ ".zig-cache", "tmp", &temporary.sub_path }),
    }, .counters = &counters };
    const value_types = try a.alloc(Ir.Type, 64);
    @memset(value_types, .int);
    value_types[4] = .bool;
    value_types[5] = .structure(0);
    const blocks = try a.alloc(Ir.Block, 16);
    for (blocks, 0..) |*block, index| block.* = .{
        .instructions = &.{},
        .terminator = if (index + 1 < blocks.len) .{ .jump = index + 1 } else .{ .return_value = 3 },
    };
    blocks[0].instructions = &.{
        .{ .call = .{ .result = 0, .function = 17, .arguments = &.{} } },
        .{ .constant_int = .{ .result = 1, .bits = 2 } },
        .{ .constant_int = .{ .result = 2, .bits = 3 } },
        .{ .binary = .{ .result = 3, .operator = .add, .left = 1, .right = 2, .checked = true } },
        .{ .binary = .{ .result = 4, .operator = .less, .left = 1, .right = 2 } },
    };
    var function: Ir.Function = .{
        .name = "first",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = value_types,
        .blocks = blocks,
    };
    const first = try optimizeCachedFunction(a, function, context);
    RangeCache.flush(context);
    try std.testing.expect(!first.blocks[0].instructions[3].binary.checked);
    try std.testing.expect(first.blocks[0].instructions[4].constant_bool.value);
    const instructions = try a.dupe(Ir.Instruction, blocks[0].instructions);
    instructions[0].call.function = 92;
    blocks[0].instructions = instructions;
    value_types[5] = .structure(123);
    function.name = "second";
    const relocated = try optimizeCachedFunction(a, function, context);
    try std.testing.expectEqual(@as(usize, 1), counters.hits.load(.monotonic));
    try std.testing.expectEqual(@as(usize, 92), relocated.blocks[0].instructions[0].call.function);
    try std.testing.expectEqual(Ir.Type.structure(123), relocated.value_types[5]);
    const independent = try optimizeFunction(a, function);
    try std.testing.expectEqualDeep(independent, relocated);
    instructions[2].constant_int.bits = 1;
    const changed = try optimizeCachedFunction(a, function, context);
    try std.testing.expectEqual(@as(usize, 2), counters.misses.load(.monotonic));
    try std.testing.expect(!changed.blocks[0].instructions[4].constant_bool.value);
}

test "range analysis retains only rewritten IR between passes" {
    const block_count = 64;
    var blocks: [block_count]Ir.Block = undefined;
    blocks[0] = .{ .instructions = &.{
        .{ .constant_int = .{ .result = 0, .bits = 40 } },
        .{ .constant_int = .{ .result = 1, .bits = 2 } },
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1, .checked = true } },
    }, .terminator = .{ .jump = 1 } };
    for (1..block_count - 1) |index| blocks[index] = .{
        .instructions = &.{},
        .terminator = .{ .jump = index + 1 },
    };
    blocks[block_count - 1] = .{
        .instructions = &.{.{ .print = .{ .value = 2, .newline = true } }},
        .terminator = .return_void,
    };
    const value_types = [_]Ir.Type{.int} ** 64;
    const function: Ir.Function = .{
        .name = "main",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = &value_types,
        .blocks = &blocks,
    };
    const functions = [_]Ir.Function{function} ** 32;
    // The retained IR fits here, but the 32 pairs of analysis matrices do not.
    // The output budget must not grow with completed functions' scratch data.
    var storage: [1024 * 1024]u8 = undefined;
    var retained = std.heap.FixedBufferAllocator.init(&storage);
    const optimized = try optimize(retained.allocator(), .{ .functions = &functions });
    try std.testing.expect(blocks[0].instructions[2].binary.checked);
    // An idempotent replay needs only its function table, not another copy of
    // the unchanged IR from the previous analysis.
    var replay_storage: [@sizeOf(Ir.Function) * functions.len]u8 align(@alignOf(Ir.Function)) = undefined;
    var replay_allocator = std.heap.FixedBufferAllocator.init(&replay_storage);
    const replay = try optimize(replay_allocator.allocator(), optimized);
    for (replay.functions) |result| {
        try std.testing.expect(!result.blocks[0].instructions[2].binary.checked);
        var execution = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer execution.deinit();
        const observed = try @import("../Interpreter.zig").runCapture(execution.allocator(), .{ .functions = &.{result} });
        try std.testing.expectEqualStrings("42\n", observed.stdout);
    }
}
