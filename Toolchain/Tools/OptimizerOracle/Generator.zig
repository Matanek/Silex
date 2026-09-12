const std = @import("std");

pub const CorpusEntry = struct {
    name: []const u8,
    timing: bool,
    project: bool = false,
    llvm_float_width_minimum: u3 = 0,
    silex_arm64_pair_function: ?[]const u8 = null,
};

pub const StructuralContract = union(enum) {
    none,
    reduces_blocks: []const u8,
    removes_collection_bounds: []const u8,
    scalarizes_dense_loop: []const u8,
    scalarizes_aggregate: []const u8,
    elides_reference_memory: struct {
        overwritten: []const u8,
        observed: []const u8,
    },
    coalesces_view_memory: []const u8,
    forwards_owning_collection: []const u8,
    forwards_known_views: []const u8,
    reuses_dominated_fields: []const u8,
    reuses_scalar_expressions: struct {
        repeated: []const u8,
        stored: []const u8,
        reloaded: []const u8,
    },
    simplifies_ssa_values: []const u8,
    promotes_critical_edge: []const u8,
    coalesces_forwarded_phi: []const u8,
    promotes_distinct_phis: []const u8,
    folds_integer_conversions: []const u8,
    proves_integer_ranges: struct {
        bounded_add: []const u8,
        bounded_subtract: []const u8,
        bounded_conversion: []const u8,
        bounded_shift: []const u8,
        bounded_loop: []const u8,
        unproven_add: []const u8,
    },
    specializes_effectful_calls: []const u8,
    specializes_branching_reference_calls: []const u8,
    preserves_branching_reference_calls: []const u8,
    slp_width: struct {
        function: []const u8,
        minimum: u3,
        arm64_pair: bool = false,
        x64_pair: bool = false,
    },
    arm64_loop_cursor: struct {
        function: []const u8,
        pointer_terminated: bool = true,
    },
    arm64_reference_cursors: struct {
        function: []const u8,
        unchecked: u16,
        checked: u16,
    },
    arm64_aggregate_parameter_residence: struct {
        function: []const u8,
        minimum: u16,
    },
    native_loop_residence: struct {
        function: []const u8,
        arm64_minimum: u16,
        x64_minimum: u16,
    },
    x64_regional_budget: struct {
        function: []const u8,
        minimum_resident: u16,
        stack_slots: u16,
        frame_bytes: u32,
        direct_calls: u16,
        indirect_calls: u16,
        aggregate_width: u16,
        loop_stack_loads: u16 = 0,
        loop_stack_stores: u16 = 0,
    },
};

pub const RegressionEntry = struct {
    name: []const u8,
    concern: []const u8,
    contract: StructuralContract = .none,
};

pub const corpus = [_]CorpusEntry{
    .{ .name = "Regressions/DominatedReferenceReads.sx", .timing = false },
    .{ .name = "Regressions/LateScalarClosure.sx", .timing = false },
    .{ .name = "Regressions/ValueModules/Main.sx", .timing = false, .project = true },
    .{ .name = "Regressions/AggregatePreparation.sx", .timing = false },
    .{ .name = "Regressions/ScalarExpressionReuse.sx", .timing = false },
    .{ .name = "Regressions/KnownViewElements.sx", .timing = false },
    .{ .name = "DampedIntegration.sx", .timing = false },
    .{ .name = "PreparationMasses.sx", .timing = false },
    .{ .name = "AggregateViewAliasing.sx", .timing = false },
    .{ .name = "IntegerArithmetic.sx", .timing = true },
    .{ .name = "BranchingLoop.sx", .timing = true },
    .{ .name = "FloatArithmetic.sx", .timing = true },
    .{ .name = "IntegerControlFlow.sx", .timing = false },
    .{ .name = "IntegerWidths.sx", .timing = false },
    .{ .name = "UnsignedBitwise.sx", .timing = false },
    .{ .name = "AggregateScalarization.sx", .timing = false },
    .{ .name = "ReferenceAliasing.sx", .timing = false },
    .{ .name = "ReferenceDeadStores.sx", .timing = false },
    .{ .name = "ReadonlyViewMemory.sx", .timing = false },
    .{ .name = "MutableViewMemory.sx", .timing = false },
    .{ .name = "NestedAggregateWidths.sx", .timing = false },
    .{ .name = "OwningCollectionCopy.sx", .timing = false },
    .{ .name = "Regressions/LoopExitFloatLaneXY.sx", .timing = false, .llvm_float_width_minimum = 2, .silex_arm64_pair_function = "finish" },
    .{ .name = "Regressions/FloatLaneXYZ.sx", .timing = false },
    .{ .name = "Regressions/LoopExitFloatLaneXYZW.sx", .timing = false, .llvm_float_width_minimum = 4, .silex_arm64_pair_function = "finish" },
    .{ .name = "Regressions/PureMathReferenceInlining.sx", .timing = false, .project = true },
    .{ .name = "Regressions/HotReferenceLeafClosure.sx", .timing = false, .project = true },
};

pub const regressions = [_]RegressionEntry{
    .{ .name = "Regressions/ScalarClassLeaves.sx", .concern = "scalar class mutator leaves preserve shared identity, signed and floating updates, boolean fields, and resource replacement barriers" },
    .{ .name = "Regressions/IntegerMemoryRegions.sx", .concern = "integer loop regions and direct signed/unsigned operands preserve aliases, narrow normalization, cold exits and empty iterations" },
    .{ .name = "Regressions/BranchComparisons.sx", .concern = "single-use and shared comparisons preserve signed and unsigned widths, unordered floats, infinities and signed zero" },
    .{ .name = "Regressions/BranchSnapshots.sx", .concern = "arm-local scalar snapshots preserve alias writes, joined values, negative indices, NaN and signed zero" },
    .{ .name = "Regressions/PrivateCollectionLengths.sx", .concern = "private literal lengths cross branches and unrelated calls while mutation, copies, view escapes and terminal lifetimes stay exact" },
    .{ .name = "Regressions/ScalarFloatOperands.sx", .concern = "direct scalar SSE operands preserve subtraction/division order, widths, signed zero and unordered comparisons" },
    .{ .name = "Regressions/FloatMemoryResidence.sx", .concern = "mixed integer and FP recurrences across aggregate inputs and returns, stack copies and fixed/view loads, widths, NaN and signed zero" },
    .{ .name = "Regressions/LoopExitResidence.sx", .concern = "loop-carried scalar state survives interleaved class exits and direct mutator calls" },
    // Native-only: the strict LLVM oracle does not lower float-to-integer conversions.
    .{ .name = "Regressions/ScalarFloatResidence.sx", .concern = "scalar FP pressure, loop recurrence, call barriers, addressed aliases, exact conversion, NaN and signed zero" },
    .{ .name = "Regressions/DominatedReferenceReads.sx", .concern = "dominated borrowed fields preserve branches, mutable aliases, signed zero, NaN and mixed scalar widths" },
    .{
        .name = "Regressions/LateScalarClosure.sx",
        .concern = "helpers exposed as scalar leaves after collection cleanup preserve loop results and checked initialization",
        .contract = .none,
    },
    .{
        .name = "Regressions/ValueModules/Main.sx",
        .concern = "module and generic boundaries preserve dominated values, partial paths, mutable aliases and strict floating observations",
        .contract = .none,
    },
    .{
        .name = "Regressions/AggregatePreparation.sx",
        .concern = "complete preparation observes all 26 fields across dynamic/fixed bodies, warm starts and detached results",
        .contract = .{ .reuses_dominated_fields = "prepare" },
    },
    .{
        .name = "Regressions/ScalarExpressionReuse.sx",
        .concern = "identical scalar snapshots share calculations across stores while changed memory and floating edge values retain their observations",
        .contract = .{ .reuses_scalar_expressions = .{ .repeated = "repeated", .stored = "storeBetween", .reloaded = "reloadBetween" } },
    },
    .{
        .name = "Regressions/KnownViewElements.sx",
        .concern = "known scalar elements propagate through clamped nested views; aliases and branches retain observations",
        .contract = .{ .forwards_known_views = "constantViews" },
    },
    .{
        .name = "IntegerArithmetic.sx",
        .concern = "a hot scalar loop retains target registers across a terminal output barrier",
        .contract = .{ .native_loop_residence = .{
            .function = "main",
            .arm64_minimum = 10,
            .x64_minimum = 10,
        } },
    },
    .{
        .name = "AggregateScalarization.sx",
        .concern = "value aggregate copies, field updates and returns reduce to scalar leaves",
        .contract = .{ .scalarizes_aggregate = "update" },
    },
    .{
        .name = "ReferenceDeadStores.sx",
        .concern = "exact reference stores are eliminated while a possibly aliasing observation remains",
        .contract = .{ .elides_reference_memory = .{
            .overwritten = "overwrite",
            .observed = "observed",
        } },
    },
    .{
        .name = "MutableViewMemory.sx",
        .concern = "exact mutable-view stores and loads coalesce without removing the surviving bounds guard",
        .contract = .{ .coalesces_view_memory = "rewrite" },
    },
    .{
        .name = "OwningCollectionCopy.sx",
        .concern = "known owning-list values forward while copy-on-write mutation remains explicit",
        .contract = .{ .forwards_owning_collection = "main" },
    },
    .{
        .name = "Regressions/AggregateFieldStores.sx",
        .concern = "scalar field reads and writes preserve snapshots, alias mutations across calls and loops, and owning collection copies",
    },
    .{
        .name = "Regressions/CheckedMemoryLanes.sx",
        .concern = "checked aggregate loads, independent arithmetic lanes, branches and borrowed writes",
    },
    .{
        .name = "Regressions/AggregateControlFlow.sx",
        .concern = "immutable aggregate projections across branches and loops preserve snapshots and joined returns",
    },
    .{
        .name = "Regressions/FloatSsaDiamond.sx",
        .concern = "float32 and float64 local values preserve both incoming edges of an SSA diamond",
    },
    .{
        .name = "Regressions/FloatSsaLoop.sx",
        .concern = "float32 and float64 local recurrences preserve entry and back-edge values",
    },
    .{
        .name = "Regressions/BooleanSharedChain.sx",
        .concern = "shared boolean-chain blocks and reused branch values",
        .contract = .{ .reduces_blocks = "hot_chain" },
    },
    .{
        .name = "Regressions/SsaValueFacts.sx",
        .concern = "unanimous SSA joins propagate exact constants while divergent joins retain their control",
        .contract = .{ .simplifies_ssa_values = "unanimous" },
    },
    .{
        .name = "Regressions/SsaCriticalEdge.sx",
        .concern = "float32 and float64 locals cross a critical edge without memory traffic or a synthetic block",
        .contract = .{ .promotes_critical_edge = "choose64" },
    },
    .{
        .name = "Regressions/SsaForwardedPhiLoop.sx",
        .concern = "a loop-carried float value crosses an inner forwarding join without falling back to local storage",
        .contract = .{ .coalesces_forwarded_phi = "accumulate" },
    },
    .{
        .name = "Regressions/SsaDistinctPhiLoop.sx",
        .concern = "a float recurrence keeps distinct loop and branch joins without falling back to local storage",
        .contract = .{ .promotes_distinct_phis = "accumulate" },
    },
    .{
        .name = "Regressions/IntegerConversionConstants.sx",
        .concern = "unanimous integer facts cross representable conversions and expose dependent constant arithmetic",
        .contract = .{ .folds_integer_conversions = "joined" },
    },
    .{
        .name = "Regressions/IntegerShiftConstants.sx",
        .concern = "unanimous integer and count facts fold valid shifts while invalid counts preserve their failure",
        .contract = .{ .simplifies_ssa_values = "shifted" },
    },
    .{
        .name = "Regressions/IntegerRangeChecks.sx",
        .concern = "dominating and loop-carried bounds remove only proven overflow and conversion checks",
        .contract = .{ .proves_integer_ranges = .{
            .bounded_add = "increment",
            .bounded_subtract = "decrement",
            .bounded_conversion = "widen_unsigned",
            .bounded_shift = "shift_bounded",
            .bounded_loop = "accumulate",
            .unproven_add = "risky",
        } },
    },
    .{
        .name = "Regressions/ConstantDivision.sx",
        .concern = "signed and unsigned constant division, including powers of two, preserves all Silex integer widths on native backends",
    },
    .{
        .name = "Regressions/X64RegionalBarriers.sx",
        .concern = "a hot X64 scalar loop retains volatile registers while aggregate construction and a direct call remain stack barriers",
        .contract = .{ .x64_regional_budget = .{
            .function = "integrate",
            .minimum_resident = 8,
            .stack_slots = 2,
            .frame_bytes = 32,
            .direct_calls = 1,
            .indirect_calls = 0,
            .aggregate_width = 2,
        } },
    },
    .{
        .name = "Regressions/X64IndirectAggregate.sx",
        .concern = "a hot X64 scalar loop retains registers before a wide aggregate and indirect call barrier",
        .contract = .{ .x64_regional_budget = .{
            .function = "integrate",
            .minimum_resident = 8,
            .stack_slots = 6,
            .frame_bytes = 64,
            .direct_calls = 0,
            .indirect_calls = 1,
            .aggregate_width = 4,
        } },
    },
    .{
        .name = "Regressions/ArrayStorageAccess.sx",
        .concern = "fixed, dynamic, nested, and aggregate collection storage",
    },
    .{
        .name = "Regressions/BoundedCollectionLoop.sx",
        .concern = "proven zero-origin collection traversal without weakening other bounds checks",
        .contract = .{ .removes_collection_bounds = "sum" },
    },
    .{
        .name = "Regressions/SequentialBoundedLoops.sx",
        .concern = "zero-origin recovery after a sequential loop resets its reused induction variable",
        .contract = .{ .removes_collection_bounds = "sum_sequential" },
    },
    .{
        .name = "Regressions/DenseScalarLoop.sx",
        .concern = "class count accessor inlining and redundant scalar loads inside a dense loop",
        .contract = .{ .scalarizes_dense_loop = "integrate" },
    },
    .{
        .name = "Regressions/LoopExitFloatLaneXY.sx",
        .concern = "XY loop recurrences become stable vectorizable snapshots after loop exit",
        .contract = .{ .slp_width = .{ .function = "finish", .minimum = 2, .arm64_pair = true } },
    },
    .{
        .name = "Regressions/FloatLaneXYZ.sx",
        .concern = "portable XYZ lane grouping through loads and arithmetic",
        .contract = .{ .slp_width = .{ .function = "transform", .minimum = 3 } },
    },
    .{
        .name = "Regressions/LoopExitFloatLaneXYZW.sx",
        .concern = "XYZW loop recurrences become two stable vectorizable pairs after loop exit",
        .contract = .{ .slp_width = .{ .function = "finish", .minimum = 4, .arm64_pair = true } },
    },
    .{
        .name = "Regressions/TextOutputIntegrity.sx",
        .concern = "complete text output through branches and collection iteration",
    },
    .{
        .name = "Regressions/BoidsKernel.sx",
        .concern = "boids-like arrays, shared boolean chains, and native XY/Z realization",
        .contract = .{ .slp_width = .{ .function = "steer", .minimum = 3, .arm64_pair = true, .x64_pair = true } },
    },
    .{
        .name = "Regressions/Boids2DSteering.sx",
        .concern = "aggregate vector parameters keep pointer-terminated collection cursors disjoint from cached float literals",
    },
    .{
        .name = "Regressions/ReversedFloatRecurrence.sx",
        .concern = "reversed float recurrence copies preserve lane order and exact unaligned compact-field loads",
    },
    .{
        .name = "Regressions/CollectionCursor.sx",
        .concern = "a generic unit-stride float collection loop retains a post-indexed pointer-terminated cursor",
        .contract = .{ .arm64_loop_cursor = .{ .function = "accumulate" } },
    },
    .{
        .name = "Regressions/ReferenceCursorReuse.sx",
        .concern = "ascending mutable view references preserve checked bounds and reuse stable element addresses across field writes",
    },
    .{
        .name = "Regressions/MultipleReferenceCursors.sx",
        .concern = "independent mutable views carry every checked ascending element address in one loop",
        .contract = .{ .arm64_reference_cursors = .{
            .function = "shift",
            .unchecked = 0,
            .checked = 2,
        } },
    },
    .{
        .name = "Regressions/AggregateParameterResidence.sx",
        .concern = "read-only aggregate parameters keep scalar leaves in ARM64 registers unless storage is required",
        .contract = .{ .arm64_aggregate_parameter_residence = .{
            .function = "evaluate",
            .minimum = 12,
        } },
    },
    .{
        .name = "Regressions/LoopForms.sx",
        .concern = "signed and unsigned inductions, nested control, break, continue, dynamic bounds, strided access and contiguous recurrence",
    },
    .{
        .name = "Regressions/CallEffectsInlining.sx",
        .concern = "small reference and checked-view callees inline into the final caller without losing their memory effects",
        .contract = .{ .specializes_effectful_calls = "main" },
    },
    .{
        .name = "Regressions/BranchingReferenceInlining.sx",
        .concern = "branching reference callees inline at hot loop sites while preserving their writes",
        .contract = .{ .specializes_branching_reference_calls = "main" },
    },
    .{
        .name = "Regressions/PureMathReferenceInlining.sx",
        .concern = "proven pure scalar-math effects remain exact while a native call barrier stays outside a branching reference caller",
        .contract = .{ .preserves_branching_reference_calls = "main" },
    },
    .{
        .name = "Regressions/HotReferenceLeafClosure.sx",
        .concern = "a pressure-heavy hot set of reference leaf callees stays out of line until expanded caller residences are proven profitable",
        .contract = .{ .preserves_branching_reference_calls = "integrate" },
    },
    .{
        .name = "Regressions/DynamicFieldClearAppend.sx",
        .concern = "a loop-local class call bound stays defined before clearing and rebuilding a dynamic field",
    },
};

const IntegerKind = struct {
    name: []const u8,
    signed: bool,
};

const integer_kinds = [_]IntegerKind{
    .{ .name = "int8", .signed = true },
    .{ .name = "int16", .signed = true },
    .{ .name = "int32", .signed = true },
    .{ .name = "int", .signed = true },
    .{ .name = "uint8", .signed = false },
    .{ .name = "uint16", .signed = false },
    .{ .name = "uint32", .signed = false },
    .{ .name = "uint", .signed = false },
};

const Generator = struct {
    state: u64,

    fn next(self: *Generator) u64 {
        self.state = self.state *% 6364136223846793005 +% 1442695040888963407;
        return self.state;
    }

    fn choose(self: *Generator, values: []const []const u8) []const u8 {
        return values[@intCast(self.next() % values.len)];
    }

    fn smallInteger(self: *Generator) i64 {
        return @as(i64, @intCast(self.next() % 17)) - 8;
    }

    fn smallPositiveInteger(self: *Generator) u64 {
        return self.next() % 9;
    }
};

pub fn source(allocator: std.mem.Allocator, seed: u64) ![]u8 {
    var generator: Generator = .{ .state = seed };
    const kind = integer_kinds[@intCast(seed % integer_kinds.len)];
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.print(
        \\func calculate(a:{s}, b:{s}, c:{s}) {s} {{
        \\    var value = a
        \\
    , .{ kind.name, kind.name, kind.name, kind.name });
    const signed_operators = [_][]const u8{ "+", "-" };
    const unsigned_operators = [_][]const u8{ "+", "^", "&" };
    const operators: []const []const u8 = if (kind.signed) &signed_operators else &unsigned_operators;
    const operands = [_][]const u8{ "a", "b", "c" };
    for (0..12) |_| {
        const operator = generator.choose(operators);
        if ((generator.next() & 1) == 0) {
            const operand = generator.choose(&operands);
            try output.writer.print(
                "    value = value {s} {s}\n",
                .{ operator, operand },
            );
        } else {
            try output.writer.print(
                "    value = value {s} ({d} as {s})\n",
                .{ operator, generator.smallPositiveInteger(), kind.name },
            );
        }
    }
    const first = if (kind.signed) generator.smallInteger() else @as(i64, @intCast(generator.smallPositiveInteger()));
    const second = if (kind.signed) generator.smallInteger() else @as(i64, @intCast(generator.smallPositiveInteger()));
    const third = if (kind.signed) generator.smallInteger() else @as(i64, @intCast(generator.smallPositiveInteger()));
    try output.writer.print(
        \\    return value
        \\}}
        \\func main() {{
        \\    print(calculate({d}, {d}, {d}))
        \\}}
        \\
    , .{ first, second, third });
    return output.toOwnedSlice();
}

test "generated sources are deterministic and seed-sensitive" {
    const first = try source(std.testing.allocator, 42);
    defer std.testing.allocator.free(first);
    const repeated = try source(std.testing.allocator, 42);
    defer std.testing.allocator.free(repeated);
    const different = try source(std.testing.allocator, 43);
    defer std.testing.allocator.free(different);
    try std.testing.expectEqualStrings(first, repeated);
    try std.testing.expect(!std.mem.eql(u8, first, different));
}

test "successive seeds cover every integer width and signedness" {
    for (integer_kinds, 0..) |kind, seed| {
        const generated = try source(std.testing.allocator, seed);
        defer std.testing.allocator.free(generated);
        const signature = try std.fmt.allocPrint(std.testing.allocator, "a:{s}", .{kind.name});
        defer std.testing.allocator.free(signature);
        try std.testing.expect(std.mem.containsAtLeast(u8, generated, 1, signature));
    }
}
