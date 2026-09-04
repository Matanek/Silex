const std = @import("std");
const Ir = @import("../Ir.zig");
const Bounds = @import("Bounds.zig");
const DenseBlocks = @import("DenseBlocks.zig");
const InlineControlFlow = @import("InlineControlFlow.zig");
const InlineValues = @import("InlineValues.zig");
const SsaPromotion = @import("SsaPromotion.zig");
const Workers = @import("../Workers.zig");
const UnusedLocals = @import("UnusedLocals.zig");
const AggregateStores = @import("AggregateStores.zig");
const AggregateLoads = @import("AggregateLoads.zig");

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
    return optimizeWithWorkers(allocator, program, 1);
}

pub fn optimizeWithWorkers(allocator: Allocator, program: Ir.Program, worker_count: u16) !Ir.Program {
    const prepared = try optimizeWithoutInliningWithWorkers(allocator, program, worker_count);
    // Simplify constructors before cloning them into branching callers:
    // otherwise each field assignment carries its whole aggregate along.
    const scalar_prepared = try replaceScalarAggregatesWithWorkers(allocator, prepared, worker_count);
    const intrinsic_prepared = try replaceScalarMathCalls(allocator, scalar_prepared);
    const inlined = try InlineValues.optimize(allocator, intrinsic_prepared);
    const control_flow_inlined = try InlineControlFlow.optimize(allocator, inlined);
    const scalarized = try replaceScalarAggregatesWithWorkers(allocator, control_flow_inlined, worker_count);
    return optimizeWithoutInliningWithWorkers(allocator, scalarized, worker_count);
}

fn replaceScalarMathCalls(allocator: Allocator, program: Ir.Program) !Ir.Program {
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, function_index| {
        const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
        for (function.blocks, 0..) |block, block_index| {
            const instructions = try allocator.alloc(Ir.Instruction, block.instructions.len);
            for (block.instructions, 0..) |instruction, instruction_index| {
                instructions[instruction_index] = scalarMathCall(program, function, instruction) orelse instruction;
            }
            blocks[block_index] = .{ .instructions = instructions, .terminator = block.terminator };
        }
        functions[function_index] = function;
        functions[function_index].blocks = blocks;
    }
    var result = program;
    result.functions = functions;
    return result;
}

fn scalarMathCall(program: Ir.Program, caller: Ir.Function, instruction: Ir.Instruction) ?Ir.Instruction {
    const call = switch (instruction) {
        .call => |value| value,
        else => return null,
    };
    const result = call.result orelse return null;
    if (call.function >= program.functions.len or call.arguments.len != 2 or result >= caller.value_types.len) return null;
    const callee = program.functions[call.function];
    if (callee.parameter_types.len != 2 or callee.return_type != caller.value_types[result]) return null;
    const value_type = caller.value_types[result];
    if (value_type != .float32 and value_type != .float64) return null;
    if (callee.parameter_types[0] != value_type or callee.parameter_types[1] != value_type) return null;
    const operator: Ir.BinaryOperator = if (std.mem.eql(u8, callee.name, "STD.Math.min"))
        .minimum
    else if (std.mem.eql(u8, callee.name, "STD.Math.max"))
        .maximum
    else
        return null;
    return .{ .binary = .{
        .result = result,
        .operator = operator,
        .left = call.arguments[0],
        .right = call.arguments[1],
        .checked = false,
    } };
}

pub fn optimizeWithoutInlining(allocator: Allocator, program: Ir.Program) !Ir.Program {
    return optimizeWithoutInliningWithWorkers(allocator, program, 1);
}

fn optimizeWithoutInliningWithWorkers(allocator: Allocator, program: Ir.Program, requested_worker_count: u16) !Ir.Program {
    const summaries = try allocator.alloc(GlobalSummary, program.functions.len);
    for (program.functions, 0..) |function, index| summaries[index] = summarize(function);
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    const worker_count = Workers.selectedCount(program.functions.len, requested_worker_count);
    if (worker_count == 1) {
        try optimizeFunctionRange(allocator, program, program.functions, functions, summaries, 0, program.functions.len);
    } else {
        var workers: [Workers.max_count]OptimizeWorker = undefined;
        const count: usize = worker_count;
        const chunk = std.math.divCeil(usize, program.functions.len, count) catch unreachable;
        for (workers[0..count], 0..) |*worker, index| worker.* = .{
            .allocator = allocator,
            .program = program,
            .source = program.functions,
            .destination = functions,
            .summaries = summaries,
            .start = index * chunk,
            .end = @min((index + 1) * chunk, program.functions.len),
        };
        Workers.run(OptimizeWorker, workers[0..count], OptimizeWorker.run);
        for (workers[0..count]) |worker| if (worker.failure) |err| return err;
    }
    var result = program;
    result.functions = functions;
    result = try SsaPromotion.optimize(allocator, result);
    const validated = try Ir.writeText(allocator, result);
    allocator.free(validated);
    return result;
}

fn optimizeFunctionRange(
    allocator: Allocator,
    program: Ir.Program,
    source: []const Ir.Function,
    destination: []Ir.Function,
    summaries: []const GlobalSummary,
    start: usize,
    end: usize,
) !void {
    for (start..end) |index| {
        const localized = try optimizeDenseBlocks(allocator, program, source[index]);
        const optimized = try optimizeFunction(allocator, localized, summaries);
        const simplified = try simplifyBooleanDiamonds(allocator, optimized);
        const bounded = try Bounds.optimize(allocator, simplified);
        var cleaned = try removeRedundantCollectionChecks(allocator, bounded);
        cleaned.blocks = try removeDeadConstants(allocator, cleaned);
        destination[index] = cleaned;
    }
}

const OptimizeWorker = struct {
    allocator: Allocator,
    program: Ir.Program,
    source: []const Ir.Function,
    destination: []Ir.Function,
    summaries: []const GlobalSummary,
    start: usize,
    end: usize,
    failure: ?anyerror = null,

    fn run(self: *OptimizeWorker) void {
        optimizeFunctionRange(self.allocator, self.program, self.source, self.destination, self.summaries, self.start, self.end) catch |err| {
            self.failure = err;
        };
    }
};

fn simplifyBooleanDiamonds(allocator: Allocator, function: Ir.Function) !Ir.Function {
    if (function.blocks.len < 4) return function;
    const blocks = try allocator.dupe(Ir.Block, function.blocks);
    const uses = try allocator.alloc(usize, function.value_types.len);
    @memset(uses, 0);
    for (blocks) |block| {
        for (block.instructions) |instruction| countUses(instruction, uses);
        countTerminatorUses(block.terminator, uses);
    }
    var changed = false;
    for (blocks, 0..) |block, block_index| {
        const outer = switch (block.terminator) {
            .branch => |value| value,
            else => continue,
        };
        if (outer.then_block >= blocks.len or outer.else_block >= blocks.len) continue;
        const evaluation = blocks[outer.then_block];
        const short_circuit = blocks[outer.else_block];
        if (short_circuit.instructions.len != 1) continue;
        const false_value = switch (short_circuit.instructions[0]) {
            .constant_bool => |value| value,
            else => continue,
        };
        if (false_value.value) continue;
        const join_id = switch (short_circuit.terminator) {
            .jump => |target| target,
            else => continue,
        };
        if (join_id >= blocks.len or evaluation.instructions.len == 0) continue;
        if (evaluation.terminator != .jump or evaluation.terminator.jump != join_id) continue;
        const join = blocks[join_id];
        if (join.instructions.len != 0) continue;
        const final_branch = switch (join.terminator) {
            .branch => |value| value,
            else => continue,
        };
        if (final_branch.condition != false_value.result) continue;
        const copy = switch (evaluation.instructions[evaluation.instructions.len - 1]) {
            .copy => |value| value,
            else => continue,
        };
        if (copy.result != false_value.result) continue;
        if (uses[false_value.result] != 1) continue;

        blocks[block_index].terminator = .{ .branch = .{
            .condition = outer.condition,
            .then_block = outer.then_block,
            .else_block = final_branch.else_block,
        } };
        blocks[outer.then_block] = .{
            .instructions = evaluation.instructions[0 .. evaluation.instructions.len - 1],
            .terminator = .{ .branch = .{
                .condition = copy.operand,
                .then_block = final_branch.then_block,
                .else_block = final_branch.else_block,
            } },
        };
        changed = true;
    }
    if (!changed) return function;
    var result = function;
    result.blocks = try removeUnreachableBlocks(allocator, blocks);
    result.blocks = try removeDeadConstants(allocator, result);
    return result;
}

pub fn optimizeCached(allocator: Allocator, io: std.Io, program: Ir.Program) !Ir.Program {
    _ = io;
    return optimize(allocator, program);
}

pub fn optimizeCachedWithWorkers(allocator: Allocator, io: std.Io, program: Ir.Program, worker_count: u16) !Ir.Program {
    _ = io;
    return optimizeWithWorkers(allocator, program, worker_count);
}

fn replaceScalarAggregates(allocator: Allocator, program: Ir.Program) !Ir.Program {
    return replaceScalarAggregatesWithWorkers(allocator, program, 1);
}

fn replaceScalarAggregatesWithWorkers(allocator: Allocator, program: Ir.Program, requested_worker_count: u16) !Ir.Program {
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    const worker_count = Workers.selectedCount(program.functions.len, requested_worker_count);
    if (worker_count == 1) {
        try replaceScalarAggregateRange(allocator, program, functions, 0, program.functions.len);
    } else {
        var workers: [Workers.max_count]ScalarWorker = undefined;
        const count: usize = worker_count;
        const chunk = std.math.divCeil(usize, program.functions.len, count) catch unreachable;
        for (workers[0..count], 0..) |*worker, index| worker.* = .{
            .allocator = allocator,
            .program = program,
            .destination = functions,
            .start = index * chunk,
            .end = @min((index + 1) * chunk, program.functions.len),
        };
        Workers.run(ScalarWorker, workers[0..count], ScalarWorker.run);
        for (workers[0..count]) |worker| if (worker.failure) |err| return err;
    }
    var result = program;
    result.functions = functions;
    return result;
}

fn replaceScalarAggregateRange(allocator: Allocator, program: Ir.Program, destination: []Ir.Function, start: usize, end: usize) !void {
    for (start..end) |index| destination[index] = try replaceFunctionScalarAggregates(allocator, program, program.functions[index]);
}

const ScalarWorker = struct {
    allocator: Allocator,
    program: Ir.Program,
    destination: []Ir.Function,
    start: usize,
    end: usize,
    failure: ?anyerror = null,

    fn run(self: *ScalarWorker) void {
        replaceScalarAggregateRange(self.allocator, self.program, self.destination, self.start, self.end) catch |err| {
            self.failure = err;
        };
    }
};

fn replaceFunctionScalarAggregates(allocator: Allocator, program: Ir.Program, input: Ir.Function) !Ir.Function {
    const input_function = try AggregateStores.optimize(allocator, program, input);
    const definitions = try allocator.alloc(usize, input_function.value_types.len);
    @memset(definitions, 0);
    for (0..input_function.capture_types.len + input_function.parameter_types.len) |parameter| definitions[parameter] = 1;
    for (input_function.blocks) |block| for (block.instructions) |instruction| countDefinitions(instruction, definitions);
    const eligible = try allocator.alloc(bool, input_function.local_types.len);
    defer allocator.free(eligible);
    for (input_function.local_types, 0..) |local_type, local| eligible[local] = if (local_type.structureIndex()) |structure|
        scalarStructure(program, structure, 0)
    else
        false;
    const forwarded = try UnusedLocals.forwardLoads(allocator, input_function, eligible, definitions);
    const pruned = try UnusedLocals.removeOverwrittenStores(allocator, forwarded, eligible);
    const function = try UnusedLocals.removeStores(allocator, pruned);
    const roots = try allocator.alloc(?Ir.ValueId, function.value_types.len);
    @memset(roots, null);
    const fields = try allocator.alloc(?[]const Ir.ValueId, function.value_types.len);
    @memset(fields, null);
    // Lowered joins can define the same value on several predecessor edges.
    // Only immutable, single-definition values may become global aliases.
    for (function.blocks) |block| {
        for (block.instructions) |instruction| switch (instruction) {
            .structure_init => |value| if (definitions[value.result] == 1 and scalarStructure(program, value.structure, 0)) {
                roots[value.result] = value.result;
                fields[value.result] = value.fields;
            },
            else => {},
        };
    }
    var changed = true;
    while (changed) {
        changed = false;
        for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
            .copy => |value| if (definitions[value.result] == 1 and roots[value.result] == null and roots[value.operand] != null and
                function.value_types[value.result] == function.value_types[value.operand])
            {
                roots[value.result] = roots[value.operand];
                changed = true;
            },
            else => {},
        };
    }

    const uses = try allocator.alloc(usize, function.value_types.len);
    @memset(uses, 0);
    for (function.blocks) |block| {
        for (block.instructions) |instruction| countUses(instruction, uses);
        countTerminatorUses(block.terminator, uses);
    }
    const allowed = try allocator.alloc(usize, function.value_types.len);
    @memset(allowed, 0);
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .copy => |value| if (roots[value.operand] != null and roots[value.result] == roots[value.operand]) {
            allowed[value.operand] += 1;
        },
        .field_load => |value| if (roots[value.base] != null and definitions[value.result] == 1) {
            allowed[value.base] += 1;
        },
        else => {},
    };
    const escaped = try allocator.alloc(bool, function.value_types.len);
    @memset(escaped, false);
    for (roots, 0..) |root, value| if (root) |resolved| {
        if (uses[value] != allowed[value]) escaped[resolved] = true;
    };
    for (fields, 0..) |aggregate, root| if (aggregate) |values| {
        for (values) |value| if (definitions[value] != 1) {
            escaped[root] = true;
        };
    };

    const aliases = try allocator.alloc(Ir.ValueId, function.value_types.len);
    for (aliases, 0..) |*alias, value| alias.* = value;
    // Compute all projections before rewriting any block: block order need
    // not be dominance order, and a projection can feed a later aggregate.
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .copy => |value| if (roots[value.operand]) |root| {
            if (!escaped[root] and roots[value.result] == root) aliases[value.result] = value.operand;
        },
        .field_load => |value| if (roots[value.base]) |root| {
            if (!escaped[root] and definitions[value.result] == 1) {
                const aggregate_fields = fields[root] orelse return error.InvalidProgram;
                if (value.field >= aggregate_fields.len) return error.InvalidProgram;
                aliases[value.result] = aggregate_fields[value.field];
            }
        },
        else => {},
    };

    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    const constants = try allocator.alloc(Constant, function.value_types.len);
    @memset(constants, .unknown);
    for (function.blocks, 0..) |block, block_index| {
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |original| {
            switch (original) {
                .copy => |value| if (aliases[value.result] != value.result) {
                    continue;
                },
                .field_load => |value| if (aliases[value.result] != value.result) {
                    continue;
                },
                else => {},
            }
            const instruction = try rewriteInstruction(allocator, original, aliases);
            switch (instruction) {
                .structure_init => |value| if (roots[value.result]) |root| {
                    if (!escaped[root]) continue;
                },
                else => {},
            }
            try instructions.append(allocator, instruction);
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = rewriteTerminator(block.terminator, aliases, constants),
        };
    }
    var result = function;
    result.blocks = blocks;
    @memset(uses, 0);
    for (blocks) |block| {
        for (block.instructions) |instruction| countUses(instruction, uses);
        countTerminatorUses(block.terminator, uses);
    }
    return AggregateLoads.optimize(allocator, program, result, definitions, uses);
}

fn scalarStructure(program: Ir.Program, structure_index: usize, depth: usize) bool {
    if (depth > 8 or structure_index >= program.structures.len) return false;
    const structure = program.structures[structure_index];
    if (structure.is_class or structure.is_static or structure.collection != null) return false;
    for (structure.fields) |field| {
        if (field.type.isNumeric() or field.type == .bool) continue;
        const child = field.type.structureIndex() orelse return false;
        if (!scalarStructure(program, child, depth + 1)) return false;
    }
    return true;
}

fn optimizeFunction(allocator: Allocator, function: Ir.Function, summaries: []const GlobalSummary) !Ir.Function {
    // Global alias and constant propagation stays restricted to a single
    // block until the optimizer models dominance and control-flow joins.
    if (function.blocks.len != 1) return function;

    const aliases = try allocator.alloc(Ir.ValueId, function.value_types.len);
    for (aliases, 0..) |*alias, index| alias.* = index;
    const constants = try allocator.alloc(Constant, function.value_types.len);
    @memset(constants, .unknown);

    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_index| {
        const local_values = try allocator.alloc(?Ir.ValueId, function.local_types.len);
        @memset(local_values, null);
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |original| {
            var instruction = try rewriteInstruction(allocator, original, aliases);
            if (instruction == .call) instruction = inlineConstantCall(instruction.call, summaries) orelse instruction;
            switch (instruction) {
                .copy => |copy| {
                    if (function.value_types[copy.result] == function.value_types[copy.operand]) {
                        aliases[copy.result] = canonical(aliases, copy.operand);
                        continue;
                    }
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

fn optimizeDenseBlocks(allocator: Allocator, program: Ir.Program, function: Ir.Function) !Ir.Function {
    if (!DenseBlocks.isEligible(function)) return function;
    const locals_cannot_alias = !hasLocalAddress(function);
    const references_stable_across_blocks = referencesStableAcrossBlocks(function);
    const definitions = try allocator.alloc(usize, function.value_types.len);
    @memset(definitions, 0);
    for (function.blocks) |block| for (block.instructions) |instruction| countDefinitions(instruction, definitions);
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    const constants = try allocator.alloc(Constant, function.value_types.len);
    @memset(constants, .unknown);
    var entry_references: std.ArrayList(Ir.Instruction.CollectionReference) = .empty;
    const stable_local_origins = try stableLocalOrigins(
        allocator,
        program,
        function,
        definitions,
        references_stable_across_blocks and locals_cannot_alias,
    );
    for (function.blocks, 0..) |block, block_index| {
        const aliases = try allocator.alloc(Ir.ValueId, function.value_types.len);
        for (aliases, 0..) |*alias, value| alias.* = value;
        const local_values = try allocator.alloc(?Ir.ValueId, function.local_types.len);
        @memset(local_values, null);
        var field_loads: std.ArrayList(Ir.Instruction.FieldLoad) = .empty;
        var collection_loads: std.ArrayList(Ir.Instruction.CollectionLoad) = .empty;
        var collection_references: std.ArrayList(Ir.Instruction.CollectionReference) = .empty;
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |original| {
            var instruction = try rewriteInstruction(allocator, original, aliases);
            switch (instruction) {
                .copy => |copy| {
                    if (definitions[copy.result] == 1 and
                        function.value_types[copy.result] == function.value_types[copy.operand])
                    {
                        aliases[copy.result] = canonical(aliases, copy.operand);
                        continue;
                    }
                },
                .local_load => |load| {
                    const local_type = function.local_types[load.local];
                    if (local_type.isNumeric() or local_type == .bool or isViewType(program, local_type)) {
                        if (local_values[load.local]) |previous| {
                            aliases[load.result] = canonical(aliases, previous);
                            continue;
                        }
                        local_values[load.local] = load.result;
                    }
                },
                .local_store => |store| {
                    const local_type = function.local_types[store.local];
                    local_values[store.local] = if (local_type.isNumeric() or local_type == .bool or isViewType(program, local_type))
                        canonical(aliases, store.operand)
                    else
                        null;
                },
                .field_load => |load| {
                    if (matchingFieldLoad(field_loads.items, load)) |previous| {
                        aliases[load.result] = canonical(aliases, previous);
                        continue;
                    }
                    try field_loads.append(allocator, load);
                },
                .collection_load => |load| {
                    const result_type = function.value_types[load.result];
                    if (result_type.isNumeric() or result_type == .bool) {
                        if (matchingCollectionLoad(collection_loads.items, load)) |previous| {
                            aliases[load.result] = canonical(aliases, previous);
                            continue;
                        }
                        try collection_loads.append(allocator, load);
                    }
                },
                .collection_reference => |reference| {
                    if (block_index != 0 and matchingDominatingCollectionReference(
                        program,
                        function,
                        definitions,
                        stable_local_origins,
                        entry_references.items,
                        reference,
                    )) {
                        instruction.collection_reference.checked = false;
                    }
                    if (matchingCollectionReference(collection_references.items, reference)) |previous| {
                        aliases[reference.result] = canonical(aliases, previous);
                        continue;
                    }
                    try collection_references.append(allocator, reference);
                },
                .global_store,
                .field_store,
                .collection_replace,
                .list_edit,
                .reference_store,
                .address_store,
                .call,
                .indirect_call,
                .boundary_call,
                .dynamic_call,
                .mutex_lock,
                .mutex_unlock,
                => {
                    if (instruction == .reference_store and locals_cannot_alias) {
                        retainStableFieldLoads(&field_loads, program, function);
                    } else field_loads.clearRetainingCapacity();
                    collection_loads.clearRetainingCapacity();
                    if (instruction != .reference_store) collection_references.clearRetainingCapacity();
                    switch (instruction) {
                        .reference_store,
                        .address_store,
                        .call,
                        .indirect_call,
                        .boundary_call,
                        .dynamic_call,
                        .mutex_lock,
                        .mutex_unlock,
                        => if (instruction != .reference_store or !locals_cannot_alias) @memset(local_values, null),
                        else => {},
                    }
                },
                else => {},
            }
            try instructions.append(allocator, instruction);
        }
        if (block_index == 0 and references_stable_across_blocks) {
            for (collection_references.items) |reference| {
                if (reference.checked and reference.reference == null and isViewType(program, function.value_types[reference.collection])) {
                    try entry_references.append(allocator, reference);
                }
            }
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = rewriteTerminator(block.terminator, aliases, constants),
        };
    }
    var result = function;
    result.blocks = blocks;
    return removeRedundantCollectionChecks(allocator, result);
}

fn referencesStableAcrossBlocks(function: Ir.Function) bool {
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .global_store,
        .field_store,
        .collection_replace,
        .list_edit,
        .address_store,
        .call,
        .indirect_call,
        .boundary_call,
        .boundary_indirect_call,
        .dynamic_call,
        .mutex_lock,
        .mutex_unlock,
        => return false,
        else => {},
    };
    return true;
}

fn stableLocalOrigins(
    allocator: Allocator,
    program: Ir.Program,
    function: Ir.Function,
    definitions: []const usize,
    enabled: bool,
) ![]?Ir.ValueId {
    const origins = try allocator.alloc(?Ir.ValueId, function.local_types.len);
    @memset(origins, null);
    if (!enabled) return origins;
    for (function.local_types, 0..) |local_type, local| {
        if (!isStableReferenceSourceType(program, local_type)) continue;
        var seed: ?Ir.ValueId = null;
        var valid = true;
        for (function.blocks, 0..) |block, block_index| for (block.instructions) |instruction| switch (instruction) {
            .local_store => |store| if (store.local == local) {
                const origin = copyOriginAcrossBlocks(function, definitions, store.operand);
                if (localLoadProducing(function, definitions, origin)) |load| {
                    if (load.local == local) continue;
                }
                if (block_index != 0 or (seed != null and seed.? != origin)) {
                    valid = false;
                    break;
                }
                seed = origin;
            },
            else => {},
        };
        if (valid) origins[local] = seed;
    }
    return origins;
}

fn isStableReferenceSourceType(program: Ir.Program, value_type: Ir.Type) bool {
    if (value_type.isNumeric() or value_type == .bool or isViewType(program, value_type)) return true;
    const structure = value_type.structureIndex() orelse return false;
    return structure < program.structures.len and !program.structures[structure].is_class and
        program.structures[structure].collection == null;
}

fn matchingDominatingCollectionReference(
    program: Ir.Program,
    function: Ir.Function,
    definitions: []const usize,
    stable_local_origins: []const ?Ir.ValueId,
    references: []const Ir.Instruction.CollectionReference,
    candidate: Ir.Instruction.CollectionReference,
) bool {
    if (candidate.reference != null) return false;
    const collection = stableValueOrigin(program, function, definitions, stable_local_origins, candidate.collection);
    const index = stableValueOrigin(program, function, definitions, stable_local_origins, candidate.index);
    for (references) |reference| {
        if (reference.reference == null and reference.ownership == candidate.ownership and
            stableValueOrigin(program, function, definitions, stable_local_origins, reference.collection) == collection and
            stableValueOrigin(program, function, definitions, stable_local_origins, reference.index) == index) return true;
    }
    return false;
}

fn stableValueOrigin(
    program: Ir.Program,
    function: Ir.Function,
    definitions: []const usize,
    stable_local_origins: []const ?Ir.ValueId,
    value: Ir.ValueId,
) Ir.ValueId {
    var current = copyOriginAcrossBlocks(function, definitions, value);
    var remaining = function.value_types.len;
    while (remaining != 0) : (remaining -= 1) {
        if (localLoadProducing(function, definitions, current)) |load| {
            current = stable_local_origins[load.local] orelse return current;
            current = copyOriginAcrossBlocks(function, definitions, current);
            continue;
        }
        const field = fieldLoadProducingAcrossBlocks(function, definitions, current) orelse return current;
        const structure_index = function.value_types[field.base].structureIndex() orelse return current;
        if (structure_index >= program.structures.len or program.structures[structure_index].is_class) return current;
        const base = stableValueOrigin(program, function, definitions, stable_local_origins, field.base);
        return stableFieldOrigin(function, definitions, base, field.field, current);
    }
    return current;
}

fn stableFieldOrigin(function: Ir.Function, definitions: []const usize, base: Ir.ValueId, field: usize, fallback: Ir.ValueId) Ir.ValueId {
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .field_load => |load| if (load.field == field and
            copyOriginAcrossBlocks(function, definitions, load.base) == base) return load.result,
        else => {},
    };
    return fallback;
}

fn copyOriginAcrossBlocks(function: Ir.Function, definitions: []const usize, value: Ir.ValueId) Ir.ValueId {
    var current = value;
    var remaining = definitions.len;
    while (remaining != 0) : (remaining -= 1) {
        if (definitions[current] != 1) return current;
        const instruction = instructionProducing(function, current) orelse return current;
        if (instruction != .copy) return current;
        current = instruction.copy.operand;
    }
    return value;
}

fn localLoadProducing(function: Ir.Function, definitions: []const usize, value: Ir.ValueId) ?Ir.Instruction.LocalLoad {
    if (definitions[value] != 1) return null;
    const instruction = instructionProducing(function, value) orelse return null;
    return switch (instruction) {
        .local_load => |load| load,
        else => null,
    };
}

fn fieldLoadProducingAcrossBlocks(function: Ir.Function, definitions: []const usize, value: Ir.ValueId) ?Ir.Instruction.FieldLoad {
    if (definitions[value] != 1) return null;
    const instruction = instructionProducing(function, value) orelse return null;
    return switch (instruction) {
        .field_load => |load| load,
        else => null,
    };
}

fn instructionProducing(function: Ir.Function, value: Ir.ValueId) ?Ir.Instruction {
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .copy => |copy| if (copy.result == value) return instruction,
        .local_load => |load| if (load.result == value) return instruction,
        .field_load => |load| if (load.result == value) return instruction,
        else => {},
    };
    return null;
}

fn removeRedundantCollectionChecks(allocator: Allocator, function: Ir.Function) !Ir.Function {
    const uses = try allocator.alloc(usize, function.value_types.len);
    @memset(uses, 0);
    for (function.blocks) |block| {
        for (block.instructions) |instruction| countUses(instruction, uses);
        countTerminatorUses(block.terminator, uses);
    }
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    var changed = false;
    for (function.blocks, 0..) |block, block_index| {
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions, 0..) |instruction, instruction_index| {
            if (instruction == .collection_load) {
                const load = instruction.collection_load;
                if (load.checked and uses[load.result] == 0 and
                    collectionCheckProven(function, block.instructions, instruction_index, load))
                {
                    changed = true;
                    continue;
                }
            }
            try instructions.append(allocator, instruction);
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = block.terminator,
        };
    }
    if (!changed) return function;
    var result = function;
    result.blocks = blocks;
    return result;
}

fn collectionCheckProven(
    function: Ir.Function,
    instructions: []const Ir.Instruction,
    load_index: usize,
    load: Ir.Instruction.CollectionLoad,
) bool {
    for (instructions, 0..) |instruction, reference_index| {
        const reference = switch (instruction) {
            .collection_reference => |value| value,
            else => continue,
        };
        const exact_values = reference.collection == load.collection and reference.index == load.index;
        if (!exact_values and (!sameStableLocalValue(function, reference.collection, load.collection) or
            !sameStableLocalValue(function, reference.index, load.index))) continue;
        if (!referenceFeedsMutation(instructions, reference.result, 0)) continue;
        const start = @min(load_index, reference_index);
        const end = @max(load_index, reference_index);
        if (!collectionAddressStable(instructions[start + 1 .. end])) continue;
        if (reference_index < load_index and
            (exact_values or collectionCheckOrderStable(instructions[start + 1 .. end]))) return true;
        if (std.meta.eql(reference.position, load.position) and
            collectionCheckOrderStable(instructions[start + 1 .. end])) return true;
    }
    return false;
}

fn sameStableLocalValue(function: Ir.Function, left: Ir.ValueId, right: Ir.ValueId) bool {
    if (left == right) return true;
    const left_definition = instructionProducing(function, left) orelse return false;
    const right_definition = instructionProducing(function, right) orelse return false;
    return left_definition == .local_load and right_definition == .local_load and
        left_definition.local_load.local == right_definition.local_load.local;
}

fn referenceFeedsMutation(instructions: []const Ir.Instruction, reference: Ir.ValueId, depth: usize) bool {
    if (depth >= instructions.len) return false;
    for (instructions) |instruction| switch (instruction) {
        .reference_store => |store| if (store.reference == reference) return true,
        .reference_field => |field| if (field.reference == reference and
            referenceFeedsMutation(instructions, field.result, depth + 1)) return true,
        .reference_optional => |optional| if (optional.reference == reference and
            referenceFeedsMutation(instructions, optional.result, depth + 1)) return true,
        .copy => |copy| if (copy.operand == reference and
            referenceFeedsMutation(instructions, copy.result, depth + 1)) return true,
        .call => |call| for (call.arguments) |argument| {
            if (argument == reference) return true;
        },
        else => {},
    };
    return false;
}

fn collectionCheckOrderStable(instructions: []const Ir.Instruction) bool {
    for (instructions) |instruction| switch (instruction) {
        .local_store,
        .global_store,
        .field_store,
        .collection_replace,
        .list_edit,
        .reference_store,
        .address_store,
        .call,
        .indirect_call,
        .boundary_call,
        .boundary_indirect_call,
        .dynamic_call,
        .mutex_lock,
        .mutex_unlock,
        => return false,
        else => {},
    };
    return true;
}

fn collectionAddressStable(instructions: []const Ir.Instruction) bool {
    for (instructions) |instruction| switch (instruction) {
        .global_store,
        .field_store,
        .collection_replace,
        .list_edit,
        .address_store,
        .call,
        .indirect_call,
        .boundary_call,
        .boundary_indirect_call,
        .dynamic_call,
        .mutex_lock,
        .mutex_unlock,
        => return false,
        else => {},
    };
    return true;
}

fn retainStableFieldLoads(
    loads: *std.ArrayList(Ir.Instruction.FieldLoad),
    program: Ir.Program,
    function: Ir.Function,
) void {
    var retained: usize = 0;
    for (loads.items) |load| {
        const structure = function.value_types[load.base].structureIndex() orelse continue;
        if (structure >= program.structures.len or program.structures[structure].is_class) continue;
        loads.items[retained] = load;
        retained += 1;
    }
    loads.shrinkRetainingCapacity(retained);
}

fn hasLocalAddress(function: Ir.Function) bool {
    for (function.blocks) |block| for (block.instructions) |instruction| {
        if (instruction == .local_address) return true;
    };
    return false;
}

fn isViewType(program: Ir.Program, value_type: Ir.Type) bool {
    const structure = value_type.structureIndex() orelse return false;
    if (structure >= program.structures.len) return false;
    const collection = program.structures[structure].collection orelse return false;
    return collection.view;
}

fn countDefinitions(instruction: Ir.Instruction, definitions: []usize) void {
    switch (instruction) {
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
        => {},
        .list_edit => |edit| {
            definitions[edit.result] += 1;
            if (edit.removed) |removed| definitions[removed] += 1;
        },
        .call => |call| if (call.result) |result| {
            definitions[result] += 1;
        },
        .indirect_call => |call| if (call.result) |result| {
            definitions[result] += 1;
        },
        .boundary_call => |call| if (call.result) |result| {
            definitions[result] += 1;
        },
        .boundary_indirect_call => |call| if (call.result) |result| {
            definitions[result] += 1;
        },
        .dynamic_call => |call| if (call.result) |result| {
            definitions[result] += 1;
        },
        inline else => |value| definitions[value.result] += 1,
    }
}

fn matchingFieldLoad(loads: []const Ir.Instruction.FieldLoad, candidate: Ir.Instruction.FieldLoad) ?Ir.ValueId {
    for (loads) |load| {
        if (load.base == candidate.base and load.field == candidate.field) return load.result;
    }
    return null;
}

fn matchingCollectionLoad(
    loads: []const Ir.Instruction.CollectionLoad,
    candidate: Ir.Instruction.CollectionLoad,
) ?Ir.ValueId {
    for (loads) |load| {
        if (load.collection == candidate.collection and load.index == candidate.index and
            load.checked == candidate.checked) return load.result;
    }
    return null;
}

fn matchingCollectionReference(
    references: []const Ir.Instruction.CollectionReference,
    candidate: Ir.Instruction.CollectionReference,
) ?Ir.ValueId {
    for (references) |reference| {
        if (reference.collection == candidate.collection and reference.index == candidate.index and
            reference.reference == candidate.reference and reference.ownership == candidate.ownership)
            return reference.result;
    }
    return null;
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
        .storage_init,
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
        .class_drop => |value| .{ .class_drop = .{
            .operand = canonical(aliases, value.operand),
            .ownership = value.ownership,
            .skip_cycle = value.skip_cycle,
            .static_type = value.static_type,
            .plans = value.plans,
        } },
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
            .checked = value.checked,
            .position = value.position,
        } },
        .collection_reference => |value| .{ .collection_reference = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
            .reference = rewriteOptional(value.reference, aliases),
            .index = canonical(aliases, value.index),
            .checked = value.checked,
            .ownership = value.ownership,
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
            .checked = value.checked,
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
        .boundary_indirect_call => |value| .{ .boundary_indirect_call = .{
            .result = value.result,
            .callee = canonical(aliases, value.callee),
            .signature = value.signature,
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
        .storage_init => |value| value.result,
        .optional_null => |value| value.result,
        .optional_some => |value| value.result,
        .optional_unwrap => |value| value.result,
        .protocol_test => |value| value.result,
        .protocol_extract => |value| value.result,
        .enum_test => |value| value.result,
        .enum_payload => |value| value.result,
        .enum_raw => |value| value.result,
        .field_load => |value| value.result,
        .collection_load => |value| if (!value.checked) value.result else null,
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
        .storage_init,
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
        .boundary_indirect_call => |value| {
            useValue(uses, value.callee);
            useValues(uses, value.arguments);
        },
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

test "release replaces only exact scalar STD Math minimum and maximum calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const arguments = [_]Ir.ValueId{ 0, 1 };
    const caller_instructions = [_]Ir.Instruction{
        .{ .call = .{ .result = 2, .function = 0, .arguments = &arguments } },
        .{ .call = .{ .result = 3, .function = 1, .arguments = &arguments } },
        .{ .call = .{ .result = 4, .function = 2, .arguments = &arguments } },
    };
    const functions = [_]Ir.Function{
        .{
            .name = "STD.Math.min",
            .parameter_types = &.{ .float32, .float32 },
            .return_type = .float32,
            .value_types = &.{ .float32, .float32 },
            .blocks = &.{},
        },
        .{
            .name = "STD.Math.max",
            .parameter_types = &.{ .float32, .float32 },
            .return_type = .float32,
            .value_types = &.{ .float32, .float32 },
            .blocks = &.{},
        },
        .{
            .name = "Application.max",
            .parameter_types = &.{ .float32, .float32 },
            .return_type = .float32,
            .value_types = &.{ .float32, .float32 },
            .blocks = &.{},
        },
        .{
            .name = "caller",
            .parameter_types = &.{ .float32, .float32 },
            .return_type = .float32,
            .value_types = &.{ .float32, .float32, .float32, .float32, .float32 },
            .blocks = &.{.{ .instructions = &caller_instructions, .terminator = .{ .return_value = 2 } }},
        },
    };
    const optimized = try replaceScalarMathCalls(allocator, .{ .functions = &functions });
    const instructions = optimized.functions[3].blocks[0].instructions;
    try std.testing.expectEqual(Ir.BinaryOperator.minimum, instructions[0].binary.operator);
    try std.testing.expectEqual(Ir.BinaryOperator.maximum, instructions[1].binary.operator);
    try std.testing.expect(instructions[2] == .call);
}

test "boolean diamond simplification preserves a merged result used after the branch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const value_types = [_]Ir.Type{ .bool, .bool, .bool };
    const evaluated = [_]Ir.Instruction{
        .{ .copy = .{ .result = 2, .operand = 1 } },
    };
    const short_circuit = [_]Ir.Instruction{
        .{ .constant_bool = .{ .result = 2, .value = false } },
    };
    const blocks = [_]Ir.Block{
        .{ .instructions = &.{}, .terminator = .{ .branch = .{
            .condition = 0,
            .then_block = 1,
            .else_block = 2,
        } } },
        .{ .instructions = &evaluated, .terminator = .{ .jump = 3 } },
        .{ .instructions = &short_circuit, .terminator = .{ .jump = 3 } },
        .{ .instructions = &.{}, .terminator = .{ .branch = .{
            .condition = 2,
            .then_block = 4,
            .else_block = 5,
        } } },
        .{ .instructions = &.{}, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{}, .terminator = .{ .return_value = 2 } },
    };
    const function: Ir.Function = .{
        .name = "shared",
        .parameter_types = &.{ .bool, .bool },
        .return_type = .bool,
        .value_types = &value_types,
        .blocks = &blocks,
    };

    const optimized = try simplifyBooleanDiamonds(allocator, function);

    try std.testing.expectEqual(@as(usize, blocks.len), optimized.blocks.len);
    try std.testing.expectEqual(@as(Ir.BlockId, 2), optimized.blocks[0].terminator.branch.else_block);
}

test "boolean diamond simplification accepts shared control-only blocks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const value_types = [_]Ir.Type{ .bool, .bool, .bool };
    const evaluated = [_]Ir.Instruction{
        .{ .copy = .{ .result = 2, .operand = 1 } },
    };
    const short_circuit = [_]Ir.Instruction{
        .{ .constant_bool = .{ .result = 2, .value = false } },
    };
    const blocks = [_]Ir.Block{
        .{ .instructions = &.{}, .terminator = .{ .branch = .{
            .condition = 0,
            .then_block = 1,
            .else_block = 2,
        } } },
        .{ .instructions = &evaluated, .terminator = .{ .jump = 3 } },
        .{ .instructions = &short_circuit, .terminator = .{ .jump = 3 } },
        .{ .instructions = &.{}, .terminator = .{ .branch = .{
            .condition = 2,
            .then_block = 4,
            .else_block = 5,
        } } },
        .{ .instructions = &.{}, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{}, .terminator = .return_void },
    };
    const function: Ir.Function = .{
        .name = "shared_control",
        .parameter_types = &.{ .bool, .bool },
        .return_type = .void,
        .value_types = &value_types,
        .blocks = &blocks,
    };

    const optimized = try simplifyBooleanDiamonds(allocator, function);

    try std.testing.expectEqual(@as(usize, 4), optimized.blocks.len);
}

test "release preserves representation-changing copies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const runtime_type = Ir.Type.structure(0);
    const structures = [_]Ir.Structure{.{
        .name = "Runtime",
        .fields = &.{},
        .is_class = true,
    }};
    const value_types = [_]Ir.Type{ .uint, runtime_type };
    const instructions = [_]Ir.Instruction{
        .{ .copy = .{ .result = 1, .operand = 0 } },
        .{ .class_retain = .{ .operand = 1, .ownership = .root } },
    };
    const blocks = [_]Ir.Block{.{ .instructions = &instructions, .terminator = .return_void }};
    const program: Ir.Program = .{
        .structures = &structures,
        .functions = &.{.{
            .name = "from_address",
            .parameter_types = &.{.uint},
            .return_type = .void,
            .value_types = &value_types,
            .blocks = &blocks,
        }},
    };

    const optimized = try optimize(allocator, program);
    const text = try Ir.writeText(allocator, optimized);
    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "copy %0"));
    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "class.retain %1"));
}

test {
    _ = @import("ReleaseTests.zig");
    _ = @import("AggregateStoresTests.zig");
    _ = @import("UnusedLocals.zig");
}
