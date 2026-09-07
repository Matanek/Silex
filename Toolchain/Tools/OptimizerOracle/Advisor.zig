const std = @import("std");
const IrStats = @import("IrStats.zig");
const LlvmStats = @import("LlvmStats.zig");

pub const Kind = enum {
    stack_to_ssa,
    aggregate_scalarization,
    alias_forwarding,
    loop_induction_ssa,
    safety_check_elision,
    interprocedural_specialization,
    constant_propagation,
    control_flow_simplification,
    strength_reduction,
    range_analysis,
    conversion_elision,
    vectorization,

    pub fn label(self: Kind) []const u8 {
        return switch (self) {
            .stack_to_ssa => "promotion of local variables to SSA",
            .aggregate_scalarization => "scalar replacement of value aggregates",
            .alias_forwarding => "alias-aware reference-memory elimination",
            .loop_induction_ssa => "loop induction variables and PHI nodes",
            .safety_check_elision => "proven safety-check elimination",
            .interprocedural_specialization => "interprocedural specialization and inlining",
            .constant_propagation => "constant propagation and dead-code elimination",
            .control_flow_simplification => "control-flow graph simplification",
            .strength_reduction => "arithmetic strength reduction",
            .range_analysis => "range and signedness analysis",
            .conversion_elision => "redundant conversion elimination",
            .vectorization => "loop and lane vectorization",
        };
    }

    pub fn action(self: Kind) []const u8 {
        return switch (self) {
            .stack_to_ssa => "Promote non-escaping locals to SSA, then remove redundant loads and stores.",
            .aggregate_scalarization => "Decompose non-escaping value aggregates into scalar leaves while preserving snapshots and observable copies.",
            .alias_forwarding => "Remove dead reference reads and stores without forwarding values across writes that may alias.",
            .loop_induction_ssa => "Recognize induction variables and represent them with PHI nodes to expose loop invariants.",
            .safety_check_elision => "Use range and dominance proofs to remove only checks already implied by control flow.",
            .interprocedural_specialization => "Specialize small calls for known arguments before inlining and dead-code elimination.",
            .constant_propagation => "Propagate constants across calls and branches, then remove unreachable computations and blocks.",
            .control_flow_simplification => "Merge equivalent blocks and branches after propagation while preserving reused values.",
            .strength_reduction => "Canonicalize multiplication and division by powers of two into shifts when semantics permit.",
            .range_analysis => "Propagate ranges, signedness, and non-negativity to select simpler operations and prove checks.",
            .conversion_elision => "Compose consecutive conversions and remove those whose source range already fits the target.",
            .vectorization => "Extend SLP and dependence analysis to loops where LLVM materializes vector operations.",
        };
    }
};

pub const Finding = struct {
    kind: Kind,
    score: u8,
    evidence: []const u8,
};

pub const Analysis = struct {
    findings: []const Finding,
};

pub const Capabilities = struct {
    native_vectorization: bool = false,
};

pub const SummaryEntry = struct {
    kind: Kind,
    workloads: usize = 0,
    score_sum: usize = 0,
    maximum_score: u8 = 0,
};

const kind_count = @typeInfo(Kind).@"enum".fields.len;

pub const Summary = struct {
    entries: [kind_count]SummaryEntry = initialSummary(),

    pub fn add(self: *Summary, analysis: Analysis) void {
        var observed: [kind_count]bool = @splat(false);
        for (analysis.findings) |finding| {
            const index = @intFromEnum(finding.kind);
            self.entries[index].score_sum += finding.score;
            self.entries[index].maximum_score = @max(self.entries[index].maximum_score, finding.score);
            if (!observed[index]) {
                self.entries[index].workloads += 1;
                observed[index] = true;
            }
        }
    }

    pub fn ranked(self: Summary, allocator: std.mem.Allocator) ![]SummaryEntry {
        var result: std.ArrayList(SummaryEntry) = .empty;
        for (self.entries) |entry| if (entry.workloads != 0) try result.append(allocator, entry);
        std.mem.sort(SummaryEntry, result.items, {}, struct {
            fn lessThan(_: void, left: SummaryEntry, right: SummaryEntry) bool {
                if (left.score_sum != right.score_sum) return left.score_sum > right.score_sum;
                return left.maximum_score > right.maximum_score;
            }
        }.lessThan);
        return result.toOwnedSlice(allocator);
    }
};

pub fn analyze(
    allocator: std.mem.Allocator,
    silex: IrStats.Comparison,
    llvm: LlvmStats.Comparison,
) !Analysis {
    return analyzeWithCapabilities(allocator, silex, llvm, .{});
}

pub fn analyzeWithCapabilities(
    allocator: std.mem.Allocator,
    silex: IrStats.Comparison,
    llvm: LlvmStats.Comparison,
    capabilities: Capabilities,
) !Analysis {
    var findings: std.ArrayList(Finding) = .empty;
    const raw_silex = silex.raw;
    const optimized_silex = silex.optimized;
    const optimized_llvm = llvm.optimized;
    const llvm_memory_remaining = optimized_llvm.memoryOperations();
    const silex_local_remaining = optimized_silex.local_loads + optimized_silex.local_stores;
    const call_gap = optimized_silex.internal_calls > optimized_llvm.internal_calls;
    if (!call_gap and silex_local_remaining > llvm_memory_remaining) try append(
        allocator,
        &findings,
        .stack_to_ssa,
        score(88, silex_local_remaining - llvm_memory_remaining, 2),
        "LLVM retains {d} local-memory operation(s); Silex retains {d}.",
        .{ llvm_memory_remaining, silex_local_remaining },
    );

    if (!call_gap and optimized_silex.value_aggregate_operations > optimized_llvm.value_aggregate_operations) try append(
        allocator,
        &findings,
        .aggregate_scalarization,
        score(84, optimized_silex.value_aggregate_operations - optimized_llvm.value_aggregate_operations, 1),
        "LLVM retains {d} value-aggregate operation(s); Silex retains {d}.",
        .{ optimized_llvm.value_aggregate_operations, optimized_silex.value_aggregate_operations },
    );

    const silex_reference_memory = optimized_silex.reference_loads + optimized_silex.reference_stores;
    const llvm_reference_ceiling = optimized_llvm.loads + optimized_llvm.stores;
    if (silex_reference_memory > llvm_reference_ceiling) try append(
        allocator,
        &findings,
        .alias_forwarding,
        score(85, silex_reference_memory - llvm_reference_ceiling, 1),
        "LLVM retains at most {d} comparable reference-memory operation(s); Silex retains {d}.",
        .{ llvm_reference_ceiling, silex_reference_memory },
    );

    const llvm_safety_remaining = optimized_llvm.safetyGuards();
    const silex_safety_remaining = optimized_silex.safety_guards;
    if (silex_safety_remaining > llvm_safety_remaining) try append(
        allocator,
        &findings,
        .safety_check_elision,
        score(86, silex_safety_remaining - llvm_safety_remaining, 2),
        "LLVM retains {d} safety guard(s); Silex retains {d}.",
        .{ llvm_safety_remaining, silex_safety_remaining },
    );

    if (optimized_silex.internal_calls > optimized_llvm.internal_calls) try append(
        allocator,
        &findings,
        .interprocedural_specialization,
        score(76, optimized_silex.internal_calls - optimized_llvm.internal_calls, 1),
        "LLVM retains {d} internal call(s); Silex retains {d}.",
        .{ optimized_llvm.internal_calls, optimized_silex.internal_calls },
    );

    if (optimized_llvm.constant_prints > optimized_silex.constant_prints) {
        try append(
            allocator,
            &findings,
            .constant_propagation,
            score(80, optimized_llvm.constant_prints - optimized_silex.constant_prints, 1),
            "LLVM produces {d} constant print operation(s); Silex produces {d}.",
            .{ optimized_llvm.constant_prints, optimized_silex.constant_prints },
        );
    }

    if (optimized_silex.counts.blocks > optimized_llvm.blocks) {
        const excess = optimized_silex.counts.blocks - optimized_llvm.blocks;
        if (raw_silex.loop_back_edges != 0 and llvm.matched.phis_added != 0) {
            try append(
                allocator,
                &findings,
                .loop_induction_ssa,
                score(82, excess, 1),
                "LLVM rotates the loop and retains {d} block(s) with {d} added PHI node(s); Silex retains {d} block(s).",
                .{ optimized_llvm.blocks, llvm.matched.phis_added, optimized_silex.counts.blocks },
            );
        } else {
            try append(
                allocator,
                &findings,
                .control_flow_simplification,
                score(72, excess, 1),
                "LLVM retains {d} block(s); Silex retains {d}.",
                .{ optimized_llvm.blocks, optimized_silex.counts.blocks },
            );
        }
    }

    const multiplies_removed = llvm.matched.multiplies_removed;
    const shifts_added = llvm.matched.shifts_added;
    if (multiplies_removed != 0 and
        shifts_added != 0 and
        optimized_silex.multiplies != 0 and
        optimized_silex.shifts <= raw_silex.shifts)
        try append(
            allocator,
            &findings,
            .strength_reduction,
            72,
            "LLVM replaces at least {d} multiplication(s) with {d} additional shift(s); Silex retains {d} reachable multiplication(s) and adds no shifts.",
            .{ multiplies_removed, shifts_added, optimized_silex.multiplies },
        );

    if (optimized_silex.signed_remainders > optimized_llvm.signed_remainders and
        optimized_llvm.unsigned_remainders > optimized_silex.unsigned_remainders)
    {
        try append(
            allocator,
            &findings,
            .range_analysis,
            70,
            "LLVM retains {d} signed and {d} unsigned remainder operation(s); Silex retains {d} signed and {d} unsigned.",
            .{ optimized_llvm.signed_remainders, optimized_llvm.unsigned_remainders, optimized_silex.signed_remainders, optimized_silex.unsigned_remainders },
        );
    }

    if (optimized_silex.conversions > optimized_llvm.conversions) try append(
        allocator,
        &findings,
        .conversion_elision,
        score(68, optimized_silex.conversions - optimized_llvm.conversions, 1),
        "LLVM retains {d} conversion(s); Silex retains {d}.",
        .{ optimized_llvm.conversions, optimized_silex.conversions },
    );

    const vector_operations_added = llvm.matched.vector_operations_added;
    if (vector_operations_added != 0 and !capabilities.native_vectorization) try append(
        allocator,
        &findings,
        .vectorization,
        score(90, vector_operations_added, 1),
        "LLVM introduces {d} vector operation(s) absent from the initial IR.",
        .{vector_operations_added},
    );

    std.mem.sort(Finding, findings.items, {}, struct {
        fn lessThan(_: void, left: Finding, right: Finding) bool {
            return left.score > right.score;
        }
    }.lessThan);
    return .{ .findings = try findings.toOwnedSlice(allocator) };
}

fn append(
    allocator: std.mem.Allocator,
    findings: *std.ArrayList(Finding),
    kind: Kind,
    finding_score: u8,
    comptime format: []const u8,
    arguments: anytype,
) !void {
    try findings.append(allocator, .{
        .kind = kind,
        .score = finding_score,
        .evidence = try std.fmt.allocPrint(allocator, format, arguments),
    });
}

fn score(base: u8, evidence: usize, unit: usize) u8 {
    return @min(100, base + @as(u8, @intCast(@min(12, evidence / unit))));
}

fn initialSummary() [kind_count]SummaryEntry {
    var entries: [kind_count]SummaryEntry = undefined;
    for (&entries, 0..) |*entry, index| entry.* = .{ .kind = @enumFromInt(index) };
    return entries;
}

test "advisor guidance uses stable English labels" {
    const expected_labels = [_][]const u8{
        "promotion of local variables to SSA",
        "scalar replacement of value aggregates",
        "alias-aware reference-memory elimination",
        "loop induction variables and PHI nodes",
        "proven safety-check elimination",
        "interprocedural specialization and inlining",
        "constant propagation and dead-code elimination",
        "control-flow graph simplification",
        "arithmetic strength reduction",
        "range and signedness analysis",
        "redundant conversion elimination",
        "loop and lane vectorization",
    };

    for (expected_labels, 0..) |expected, index| {
        const kind: Kind = @enumFromInt(index);
        try std.testing.expectEqualStrings(expected, kind.label());
        for (kind.action()) |byte| try std.testing.expect(byte < 0x80);
    }
}

test "advisor reports conservative reference-memory residues" {
    var optimized_silex: IrStats.Profile = .{};
    optimized_silex.reference_loads = 5;
    optimized_silex.reference_stores = 1;
    var optimized_llvm: LlvmStats.Profile = .{};
    optimized_llvm.loads = 4;
    optimized_llvm.stores = 1;
    const analysis = try analyze(std.testing.allocator, .{
        .raw = .{},
        .optimized = optimized_silex,
        .matched = .{},
    }, .{
        .raw = .{},
        .optimized = optimized_llvm,
        .matched = .{},
    });
    defer {
        for (analysis.findings) |finding| std.testing.allocator.free(finding.evidence);
        std.testing.allocator.free(analysis.findings);
    }
    try std.testing.expectEqual(@as(usize, 1), analysis.findings.len);
    try std.testing.expectEqual(Kind.alias_forwarding, analysis.findings[0].kind);
}

test "advisor does not attribute missing inlining to local or aggregate optimization" {
    var optimized_silex: IrStats.Profile = .{};
    optimized_silex.local_loads = 5;
    optimized_silex.value_aggregate_operations = 4;
    optimized_silex.internal_calls = 2;
    const analysis = try analyze(std.testing.allocator, .{
        .raw = .{},
        .optimized = optimized_silex,
        .matched = .{},
    }, .{
        .raw = .{},
        .optimized = .{},
        .matched = .{},
    });
    defer {
        for (analysis.findings) |finding| std.testing.allocator.free(finding.evidence);
        std.testing.allocator.free(analysis.findings);
    }
    try std.testing.expectEqual(@as(usize, 1), analysis.findings.len);
    try std.testing.expectEqual(Kind.interprocedural_specialization, analysis.findings[0].kind);
}

test "advisor reports only excess value aggregate residues" {
    var optimized_silex: IrStats.Profile = .{};
    optimized_silex.value_aggregate_operations = 4;
    var optimized_llvm: LlvmStats.Profile = .{};
    optimized_llvm.value_aggregate_operations = 2;
    const analysis = try analyze(std.testing.allocator, .{
        .raw = .{},
        .optimized = optimized_silex,
        .matched = .{},
    }, .{
        .raw = .{},
        .optimized = optimized_llvm,
        .matched = .{},
    });
    defer {
        for (analysis.findings) |finding| std.testing.allocator.free(finding.evidence);
        std.testing.allocator.free(analysis.findings);
    }
    try std.testing.expectEqual(@as(usize, 1), analysis.findings.len);
    try std.testing.expectEqual(Kind.aggregate_scalarization, analysis.findings[0].kind);
    try std.testing.expectEqualStrings(
        "LLVM retains 2 value-aggregate operation(s); Silex retains 4.",
        analysis.findings[0].evidence,
    );
}

test "advisor ranks optimized SSA and safety residues" {
    var raw_silex: IrStats.Profile = .{};
    raw_silex.local_loads = 4;
    raw_silex.local_stores = 3;
    raw_silex.safety_guards = 4;
    raw_silex.loop_back_edges = 1;
    const optimized_silex = raw_silex;
    var raw_llvm: LlvmStats.Profile = .{};
    raw_llvm.allocas = 2;
    raw_llvm.loads = 4;
    raw_llvm.stores = 3;
    raw_llvm.overflow_intrinsics = 4;
    raw_llvm.trap_branches = 4;
    var optimized_llvm: LlvmStats.Profile = .{};
    optimized_llvm.phis = 2;
    const analysis = try analyze(std.testing.allocator, .{
        .raw = raw_silex,
        .optimized = optimized_silex,
        .matched = .{},
    }, .{
        .raw = raw_llvm,
        .optimized = optimized_llvm,
        .matched = .{
            .memory_removed = 9,
            .phis_added = 2,
            .safety_removed = 8,
        },
    });
    defer {
        for (analysis.findings) |finding| std.testing.allocator.free(finding.evidence);
        std.testing.allocator.free(analysis.findings);
    }
    try std.testing.expectEqual(@as(usize, 2), analysis.findings.len);
    try std.testing.expectEqual(Kind.stack_to_ssa, analysis.findings[0].kind);
    try std.testing.expectEqualStrings(
        "LLVM retains 0 local-memory operation(s); Silex retains 7.",
        analysis.findings[0].evidence,
    );
}

test "advisor attributes rotated loop blocks to induction analysis" {
    var raw_silex: IrStats.Profile = .{};
    raw_silex.loop_back_edges = 1;
    var optimized_silex: IrStats.Profile = .{};
    optimized_silex.counts.blocks = 8;
    var optimized_llvm: LlvmStats.Profile = .{};
    optimized_llvm.blocks = 6;
    const analysis = try analyze(std.testing.allocator, .{
        .raw = raw_silex,
        .optimized = optimized_silex,
        .matched = .{},
    }, .{
        .raw = .{},
        .optimized = optimized_llvm,
        .matched = .{ .phis_added = 4 },
    });
    defer {
        for (analysis.findings) |finding| std.testing.allocator.free(finding.evidence);
        std.testing.allocator.free(analysis.findings);
    }
    try std.testing.expectEqual(@as(usize, 1), analysis.findings.len);
    try std.testing.expectEqual(Kind.loop_induction_ssa, analysis.findings[0].kind);
}

test "advisor compares optimized residues instead of incompatible raw deltas" {
    var raw_silex: IrStats.Profile = .{};
    raw_silex.local_loads = 5;
    raw_silex.local_stores = 4;
    var raw_llvm: LlvmStats.Profile = .{};
    raw_llvm.allocas = 2;
    raw_llvm.loads = 5;
    raw_llvm.stores = 4;
    const analysis = try analyze(std.testing.allocator, .{
        .raw = raw_silex,
        .optimized = .{},
        .matched = .{ .local_memory_removed = 9 },
    }, .{
        .raw = raw_llvm,
        .optimized = .{},
        .matched = .{ .memory_removed = 11 },
    });
    defer std.testing.allocator.free(analysis.findings);
    try std.testing.expectEqual(@as(usize, 0), analysis.findings.len);
}

test "advisor ignores strength reduction in an unreachable LLVM helper" {
    var raw_silex: IrStats.Profile = .{};
    raw_silex.multiplies = 1;
    const analysis = try analyze(std.testing.allocator, .{
        .raw = raw_silex,
        .optimized = .{},
        .matched = .{},
    }, .{
        .raw = .{},
        .optimized = .{},
        .matched = .{
            .multiplies_removed = 1,
            .shifts_added = 1,
        },
    });
    defer std.testing.allocator.free(analysis.findings);
    try std.testing.expectEqual(@as(usize, 0), analysis.findings.len);
}

test "advisor reports strength reduction when a reachable multiply remains" {
    var raw_silex: IrStats.Profile = .{};
    raw_silex.multiplies = 2;
    var optimized_silex: IrStats.Profile = .{};
    optimized_silex.multiplies = 1;
    const analysis = try analyze(std.testing.allocator, .{
        .raw = raw_silex,
        .optimized = optimized_silex,
        .matched = .{},
    }, .{
        .raw = .{},
        .optimized = .{},
        .matched = .{
            .multiplies_removed = 1,
            .shifts_added = 1,
        },
    });
    defer {
        for (analysis.findings) |finding| std.testing.allocator.free(finding.evidence);
        std.testing.allocator.free(analysis.findings);
    }
    try std.testing.expectEqual(@as(usize, 1), analysis.findings.len);
    try std.testing.expectEqual(Kind.strength_reduction, analysis.findings[0].kind);
    try std.testing.expectEqualStrings(
        "LLVM replaces at least 1 multiplication(s) with 1 additional shift(s); Silex retains 1 reachable multiplication(s) and adds no shifts.",
        analysis.findings[0].evidence,
    );
}

test "advisor does not report an LLVM vector gap already realized by the native backend" {
    const comparison: LlvmStats.Comparison = .{
        .raw = .{},
        .optimized = .{},
        .matched = .{ .vector_operations_added = 8 },
    };
    const missing = try analyze(std.testing.allocator, .{ .raw = .{}, .optimized = .{}, .matched = .{} }, comparison);
    defer {
        for (missing.findings) |finding| std.testing.allocator.free(finding.evidence);
        std.testing.allocator.free(missing.findings);
    }
    try std.testing.expectEqual(Kind.vectorization, missing.findings[0].kind);

    const realized = try analyzeWithCapabilities(
        std.testing.allocator,
        .{ .raw = .{}, .optimized = .{}, .matched = .{} },
        comparison,
        .{ .native_vectorization = true },
    );
    defer std.testing.allocator.free(realized.findings);
    try std.testing.expectEqual(@as(usize, 0), realized.findings.len);
}
