const std = @import("std");

/// Target families with distinct legal SIMD realizations. This deliberately
/// stops at the baseline shared by every supported CPU in the family.
pub const Target = enum { arm64, x64 };

/// Static cost components for one scalar or vector realization. Values are
/// counts, not target-independent cycles; `score` applies the family weights.
pub const Profile = struct {
    arithmetic: u32 = 0,
    branches: u32 = 0,
    loads: u32 = 0,
    stores: u32 = 0,
    shuffles: u32 = 0,
    extractions: u32 = 0,
    spills: u32 = 0,
    calls: u32 = 0,
    code_bytes: u32 = 0,
};

pub const Comparison = struct {
    scalar: Profile,
    vector: Profile,
    scalar_setup: Profile = .{},
    vector_setup: Profile = .{},
    repetitions: u32 = 1,
};

pub const Decision = struct {
    scalar_score: u64,
    vector_score: u64,

    pub fn profitable(self: Decision) bool {
        return self.vector_score < self.scalar_score;
    }
};

const Weights = struct {
    arithmetic: u8,
    branch: u8,
    load: u8,
    store: u8,
    shuffle: u8,
    extraction: u8,
    spill: u8,
    call: u8,
    code_quantum: u8,
};

fn weights(target: Target) Weights {
    return switch (target) {
        .arm64 => .{ .arithmetic = 2, .branch = 2, .load = 3, .store = 2, .shuffle = 1, .extraction = 2, .spill = 6, .call = 12, .code_quantum = 4 },
        .x64 => .{ .arithmetic = 2, .branch = 2, .load = 3, .store = 2, .shuffle = 2, .extraction = 3, .spill = 7, .call = 12, .code_quantum = 4 },
    };
}

fn score(target: Target, profile: Profile) u64 {
    const weight = weights(target);
    return @as(u64, profile.arithmetic) * weight.arithmetic +
        @as(u64, profile.branches) * weight.branch +
        @as(u64, profile.loads) * weight.load +
        @as(u64, profile.stores) * weight.store +
        @as(u64, profile.shuffles) * weight.shuffle +
        @as(u64, profile.extractions) * weight.extraction +
        @as(u64, profile.spills) * weight.spill +
        @as(u64, profile.calls) * weight.call +
        @divTrunc(@as(u64, profile.code_bytes) + weight.code_quantum - 1, weight.code_quantum);
}

pub fn compare(target: Target, candidate: Comparison) Decision {
    const repetitions = @max(candidate.repetitions, 1);
    return .{
        .scalar_score = score(target, candidate.scalar_setup) + score(target, candidate.scalar) * repetitions,
        .vector_score = score(target, candidate.vector_setup) + score(target, candidate.vector) * repetitions,
    };
}

/// Admission model for a portable float32 pair. `priority` grows by eight for
/// each isomorphic arithmetic layer, so it is an explicit estimate of useful
/// work rather than a source-name or slot-number heuristic. Machine legality,
/// liveness and exact extraction needs are checked again after allocation.
pub fn admitsFloat32Pair(target: Target, priority: u16, recurrence: bool, in_loop: bool) bool {
    if (priority < 8 or (recurrence and !in_loop)) return false;
    const arithmetic_layers: u32 = @max(@as(u32, priority / 8), 1);
    const repetitions: u32 = if (in_loop) 8 else 1;
    const decision = compare(target, .{
        .scalar = .{ .arithmetic = arithmetic_layers * 2 },
        .vector = .{ .arithmetic = arithmetic_layers },
        // Baseline SSE needs one explicit packing shuffle when a single pair
        // cannot reuse an already packed predecessor. Loop reuse amortizes it.
        .vector_setup = .{ .shuffles = @intFromBool(target == .x64 and arithmetic_layers == 1) },
        .repetitions = repetitions,
    });
    return decision.profitable();
}

/// Low-priority groups describe layout and operand affinity, not an emitted
/// vector operation. Retaining them lets a profitable arithmetic descendant
/// obtain packed operands without treating the affinity itself as a win.
pub fn admitsFloat32Group(target: Target, priority: u16, recurrence: bool, in_loop: bool) bool {
    if (priority == 0) return false;
    if (priority < 8) return !recurrence;
    return admitsFloat32Pair(target, priority, recurrence, in_loop);
}

test "vector cost accepts amortized arithmetic and rejects extraction cliffs" {
    try std.testing.expect(admitsFloat32Pair(.arm64, 8, false, false));
    try std.testing.expect(!admitsFloat32Pair(.x64, 8, false, false));
    try std.testing.expect(admitsFloat32Pair(.x64, 16, false, false));
    try std.testing.expect(admitsFloat32Pair(.x64, 8, true, true));
    try std.testing.expect(!admitsFloat32Pair(.arm64, 32, true, false));
    try std.testing.expect(admitsFloat32Group(.arm64, 1, false, false));
    try std.testing.expect(!admitsFloat32Group(.x64, 1, true, true));

    const extraction_cliff = compare(.arm64, .{
        .scalar = .{ .arithmetic = 8, .loads = 2, .stores = 2, .code_bytes = 24 },
        .vector = .{ .arithmetic = 4, .loads = 2, .stores = 2, .extractions = 6, .code_bytes = 40 },
    });
    try std.testing.expect(!extraction_cliff.profitable());
}

test "vector cost accounts for spills calls branches and code size by target" {
    const clean = Comparison{
        .scalar = .{ .arithmetic = 16, .branches = 2, .loads = 4, .stores = 2, .code_bytes = 64 },
        .vector = .{ .arithmetic = 8, .branches = 2, .loads = 2, .stores = 1, .shuffles = 1, .code_bytes = 52 },
    };
    try std.testing.expect(compare(.arm64, clean).profitable());
    try std.testing.expect(compare(.x64, clean).profitable());

    var pressured = clean;
    pressured.vector.spills = 3;
    pressured.vector.calls = 1;
    pressured.vector.code_bytes = 96;
    try std.testing.expect(!compare(.arm64, pressured).profitable());
    try std.testing.expect(!compare(.x64, pressured).profitable());
}
