const std = @import("std");
const Silex = @import("silex_optimizer_api");

const Allocator = std.mem.Allocator;

pub const Manifest = struct {
    schema_version: u32,
    oracle: Oracle,
    baselines: []const Baseline,
    workspace_baseline: []const WorkspaceRepository,
    portable_ir: []const InventoryFamily,
    terminators: []const []const u8,
    types: []const []const u8,
    machine_ir: []const InventoryFamily,
    passes: []const Pass,
    coverage: []const Coverage,
    hot_functions: []const HotFunction,
    interactions: Interactions,
    metamorphic_axes: []const []const u8,
    qualification_corpus: []const QualificationCase,
    transposition: []const Transposition,
};

pub const Oracle = struct {
    executable: []const u8,
    version_line: []const u8,
    source_repository: []const u8,
    source_tag: []const u8,
    source_revision: []const u8,
    target_triple: []const u8,
    cpu: []const u8,
    features: []const u8,
    optimization: []const u8,
    floating_point: []const u8,
    linker: []const u8,
    libraries: []const []const u8,
};

pub const PlanSummary = struct {
    pairwise_cases: usize,
    risk_triplets: usize,
    sha256: [64]u8,
};

const Baseline = struct {
    id: []const u8,
    status: []const u8,
    repository: []const u8,
    revision: []const u8,
    source: []const u8,
    command: []const u8,
    metric: []const u8,
    value: []const u8,
};

const WorkspaceRepository = struct {
    repository: []const u8,
    revision: []const u8,
    role: []const u8,
};

const InventoryFamily = struct {
    family: []const u8,
    operations: []const []const u8,
};

const Pass = struct {
    id: []const u8,
    families: []const []const u8,
};

const Coverage = struct {
    id: []const u8,
    state: []const u8,
    owner_part: []const u8,
    semantic: bool,
    cost_model: bool,
    debug: bool,
    release: bool,
    llvm: bool,
    structure: bool,
    targets: []const []const u8,
    evidence: []const []const u8,
};

pub const HotFunction = struct {
    id: []const u8,
    repository: []const u8,
    revision: []const u8,
    source: []const u8,
    source_sha256: []const u8,
    function: []const u8,
    state: []const u8,
    owner_part: []const u8,
    evidence: []const u8,
    budgets: []const StructuralBudget,
};

pub const StructuralBudget = struct {
    metric: []const u8,
    direction: []const u8,
    limit: u64,
    observed: u64,
    unit: []const u8,
};

pub const HotMeasurement = struct {
    ir_field_loads: u64,
    ir_checked_operations: u64,
    machine_collection_loads: u64,
    machine_calls: u64,
    machine_branches: u64,
    machine_stack_slots: u64,
    machine_frame_bytes: u64,
    machine_simd_xy_pairs: u64,
};

const hot_metric_names = [_][]const u8{
    "ir_field_loads",
    "ir_checked_operations",
    "machine_collection_loads",
    "machine_calls",
    "machine_branches",
    "machine_stack_slots",
    "machine_frame_bytes",
    "machine_simd_xy_pairs",
};

const Interactions = struct {
    pairwise_seed: u64,
    triplet_seed: u64,
    axes: []const []const u8,
    risk_triplets: []const []const u8,
};

const QualificationCase = struct {
    id: []const u8,
    repository: []const u8,
    revision: []const u8,
    path: []const u8,
    sha256: []const u8,
    sealed: bool,
};

const Transposition = struct {
    family: []const u8,
    verdict: []const u8,
    owner_part: []const u8,
    source: []const u8,
    proof: []const u8,
};

pub fn load(allocator: Allocator, io: std.Io, corpus_directory: []const u8) !Manifest {
    const path = try std.fs.path.join(allocator, &.{ corpus_directory, "Coverage.json" });
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(4 * 1024 * 1024));
    return std.json.parseFromSliceLeaky(Manifest, allocator, bytes, .{});
}

pub fn audit(manifest: Manifest) !void {
    if (manifest.schema_version != 1) return error.UnsupportedRegistrySchema;
    try auditOracle(manifest.oracle);
    try auditBaselines(manifest.baselines);
    try auditWorkspaceBaseline(manifest.workspace_baseline);
    try auditInventory(Silex.Ir.Instruction, manifest.portable_ir);
    try auditNames(@typeInfo(Silex.Ir.Terminator).@"union".fields, manifest.terminators);
    try auditNames(@typeInfo(Silex.Ir.Type).@"enum".fields, manifest.types);
    try auditInventory(Silex.Arm64Machine.Instruction, manifest.machine_ir);
    try auditPasses(manifest.passes);
    try auditCoverage(manifest.coverage);
    try auditHotFunctions(manifest.hot_functions);
    try auditUniqueStrings(manifest.interactions.axes);
    try auditUniqueStrings(manifest.interactions.risk_triplets);
    try auditUniqueStrings(manifest.metamorphic_axes);
    if (manifest.interactions.axes.len < 2 or manifest.interactions.risk_triplets.len == 0 or
        manifest.metamorphic_axes.len == 0 or manifest.interactions.pairwise_seed == manifest.interactions.triplet_seed)
    {
        return error.IncompleteInteractionPlan;
    }
    try auditQualification(manifest.qualification_corpus);
    try auditTransposition(manifest.transposition);
}

pub fn validateOracleEnvironment(allocator: Allocator, io: std.Io, oracle: Oracle) !void {
    const version = try successfulCommand(allocator, io, &.{ oracle.executable, "--version" });
    const version_line = firstLine(version.stdout);
    if (!std.mem.eql(u8, version_line, oracle.version_line)) return error.OracleVersionMismatch;
    const target = try successfulCommand(allocator, io, &.{ oracle.executable, "-dumpmachine" });
    if (!std.mem.eql(u8, std.mem.trim(u8, target.stdout, " \t\r\n"), oracle.target_triple))
        return error.OracleTargetMismatch;
}

pub fn validateQualificationCorpus(
    allocator: Allocator,
    io: std.Io,
    manifest: Manifest,
    corpus_directory: []const u8,
) !void {
    const workspace_root = try std.fs.path.join(allocator, &.{ corpus_directory, "../../../.." });
    for (manifest.workspace_baseline) |entry| {
        const repository_root = try std.fs.path.join(allocator, &.{ workspace_root, entry.repository });
        try validateRevisionAncestor(allocator, io, repository_root, entry.revision);
    }
    for (manifest.qualification_corpus) |entry| {
        const repository_root = try std.fs.path.join(allocator, &.{ workspace_root, entry.repository });
        try validateRevisionAncestor(allocator, io, repository_root, entry.revision);
        try validateSourceHash(allocator, io, repository_root, entry.path, entry.sha256);
    }
    for (manifest.hot_functions) |entry| {
        const repository_root = try std.fs.path.join(allocator, &.{ workspace_root, entry.repository });
        try validateRevisionAncestor(allocator, io, repository_root, entry.revision);
        try validateSourceHash(allocator, io, repository_root, entry.source, entry.source_sha256);
    }
}

pub fn validateHotMeasurement(
    manifest: Manifest,
    source_sha256: []const u8,
    function: []const u8,
    measurement: HotMeasurement,
) !void {
    for (manifest.hot_functions) |entry| {
        if (!std.mem.eql(u8, entry.source_sha256, source_sha256) or
            !std.mem.eql(u8, entry.function, function)) continue;
        for (entry.budgets) |budget| {
            try validateObservedBudget(budget, hotMeasurementValue(measurement, budget.metric) orelse
                return error.InvalidStructuralBudget);
        }
        return;
    }
    return error.HotFunctionNotRegistered;
}

fn validateRevisionAncestor(
    allocator: Allocator,
    io: std.Io,
    repository_root: []const u8,
    revision: []const u8,
) !void {
    _ = try successfulCommand(allocator, io, &.{
        "git", "-C", repository_root, "merge-base", "--is-ancestor", revision, "HEAD",
    });
}

fn validateSourceHash(
    allocator: Allocator,
    io: std.Io,
    repository_root: []const u8,
    path: []const u8,
    expected: []const u8,
) !void {
    const source_path = try std.fs.path.join(allocator, &.{ repository_root, path });
    const source = try std.Io.Dir.cwd().readFileAlloc(io, source_path, allocator, .limited(16 * 1024 * 1024));
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &digest, .{});
    const actual = std.fmt.bytesToHex(digest, .lower);
    if (!std.mem.eql(u8, &actual, expected)) return error.QualificationSourceMismatch;
}

pub fn writeCoveragePlan(
    allocator: Allocator,
    io: std.Io,
    manifest: Manifest,
    path: []const u8,
) !PlanSummary {
    const plan = try buildCoveragePlan(allocator, manifest);
    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, plan.bytes);
    return .{
        .pairwise_cases = plan.pairwise_cases,
        .risk_triplets = manifest.interactions.risk_triplets.len,
        .sha256 = plan.sha256,
    };
}

const BuiltPlan = struct {
    bytes: []const u8,
    pairwise_cases: usize,
    sha256: [64]u8,
};

fn buildCoveragePlan(allocator: Allocator, manifest: Manifest) !BuiltPlan {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.writeAll("kind\tid\tseed\tfirst_axis\tfirst_state\tsecond_axis\tsecond_state\trisk_triplet\n");
    var pairwise_cases: usize = 0;
    for (manifest.interactions.axes, 0..) |first, first_index| {
        for (manifest.interactions.axes[first_index + 1 ..]) |second| {
            for (0..4) |combination| {
                const case_seed = manifest.interactions.pairwise_seed +% pairwise_cases;
                try output.writer.print("pairwise\tpair-{d}\t{d}\t{s}\t{d}\t{s}\t{d}\t-\n", .{
                    pairwise_cases,
                    case_seed,
                    first,
                    combination & 1,
                    second,
                    (combination >> 1) & 1,
                });
                pairwise_cases += 1;
            }
        }
    }
    for (manifest.interactions.risk_triplets, 0..) |triplet, index| {
        try output.writer.print("triplet\trisk-{d}\t{d}\t-\t-\t-\t-\t{s}\n", .{
            index,
            manifest.interactions.triplet_seed +% index,
            triplet,
        });
    }
    const bytes = try output.toOwnedSlice();
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return .{
        .bytes = bytes,
        .pairwise_cases = pairwise_cases,
        .sha256 = std.fmt.bytesToHex(digest, .lower),
    };
}

fn auditOracle(oracle: Oracle) !void {
    if (oracle.executable.len == 0 or oracle.version_line.len == 0 or
        oracle.source_repository.len == 0 or oracle.source_tag.len == 0 or
        oracle.target_triple.len == 0 or oracle.cpu.len == 0 or oracle.features.len == 0 or
        oracle.floating_point.len == 0 or oracle.linker.len == 0 or oracle.libraries.len == 0)
    {
        return error.IncompleteOraclePin;
    }
    if (!std.mem.eql(u8, oracle.optimization, "-O3")) return error.InvalidOracleOptimization;
    try requireHex(oracle.source_revision, 40);
}

fn auditBaselines(baselines: []const Baseline) !void {
    if (baselines.len == 0) return error.MissingBaseline;
    for (baselines, 0..) |baseline, index| {
        if (baseline.id.len == 0 or baseline.repository.len == 0 or baseline.source.len == 0 or
            baseline.command.len == 0 or baseline.metric.len == 0 or baseline.value.len == 0)
        {
            return error.IncompleteBaseline;
        }
        if (!oneOf(baseline.status, &.{ "accepted", "diagnostic-red", "candidate" }))
            return error.InvalidBaselineStatus;
        try requireHex(baseline.revision, 40);
        for (baselines[0..index]) |previous| if (std.mem.eql(u8, previous.id, baseline.id))
            return error.DuplicateRegistryEntry;
    }
}

fn auditWorkspaceBaseline(repositories: []const WorkspaceRepository) !void {
    if (repositories.len < 2) return error.IncompleteWorkspaceBaseline;
    var has_silex = false;
    var has_benchmarks = false;
    for (repositories, 0..) |entry, index| {
        if (entry.repository.len == 0 or entry.role.len == 0) return error.IncompleteWorkspaceBaseline;
        try requireHex(entry.revision, 40);
        has_silex = has_silex or std.mem.eql(u8, entry.repository, "Silex");
        has_benchmarks = has_benchmarks or std.mem.eql(u8, entry.repository, "Silex-Benchmarks");
        for (repositories[0..index]) |previous| if (std.mem.eql(u8, previous.repository, entry.repository))
            return error.DuplicateRegistryEntry;
    }
    if (!has_silex or !has_benchmarks) return error.IncompleteWorkspaceBaseline;
}

fn auditInventory(comptime TaggedUnion: type, families: []const InventoryFamily) !void {
    if (families.len == 0) return error.EmptyInventory;
    const fields = @typeInfo(TaggedUnion).@"union".fields;
    inline for (fields) |field| {
        var occurrences: usize = 0;
        for (families) |family| for (family.operations) |operation| {
            if (std.mem.eql(u8, operation, field.name)) occurrences += 1;
        };
        if (occurrences == 0) return error.UnregisteredOperation;
        if (occurrences > 1) return error.DuplicateOperation;
    }
    for (families, 0..) |family, family_index| {
        if (family.family.len == 0 or family.operations.len == 0) return error.EmptyInventory;
        for (families[0..family_index]) |previous| if (std.mem.eql(u8, previous.family, family.family))
            return error.DuplicateRegistryEntry;
        for (family.operations) |operation| if (!hasField(fields, operation))
            return error.UnknownOperation;
    }
}

fn auditNames(comptime fields: anytype, names: []const []const u8) !void {
    inline for (fields) |field| {
        var occurrences: usize = 0;
        for (names) |name| if (std.mem.eql(u8, name, field.name)) {
            occurrences += 1;
        };
        if (occurrences == 0) return error.UnregisteredOperation;
        if (occurrences > 1) return error.DuplicateOperation;
    }
    for (names) |name| if (!hasField(fields, name)) return error.UnknownOperation;
}

fn auditPasses(passes: []const Pass) !void {
    if (passes.len != Silex.ReleaseOptimizer.pass_descriptors.len) return error.IncompletePassRegistry;
    for (Silex.ReleaseOptimizer.pass_descriptors, passes) |descriptor, pass| {
        if (!std.mem.eql(u8, pass.id, @tagName(descriptor.id)) or pass.families.len == 0)
            return error.IncompletePassRegistry;
        if (descriptor.precondition.len == 0 or descriptor.postcondition.len == 0 or descriptor.preserves.len == 0)
            return error.IncompletePassDescriptor;
    }
}

fn auditCoverage(coverage: []const Coverage) !void {
    if (coverage.len == 0) return error.EmptyCoverageRegistry;
    for (coverage, 0..) |entry, index| {
        if (entry.id.len == 0 or entry.owner_part.len == 0 or entry.targets.len == 0 or entry.evidence.len == 0)
            return error.IncompleteCoverageEntry;
        if (!oneOf(entry.state, &.{ "equivalent", "gap", "not-measurable", "irrelevant" }))
            return error.InvalidCoverageState;
        if (!std.mem.startsWith(u8, entry.owner_part, "silex-llvm-opt-")) return error.InvalidPartOwner;
        if (std.mem.eql(u8, entry.state, "equivalent") and
            (!entry.semantic or !entry.cost_model or !entry.debug or !entry.release or !entry.structure))
        {
            return error.UnprovedEquivalentEntry;
        }
        for (coverage[0..index]) |previous| if (std.mem.eql(u8, previous.id, entry.id))
            return error.DuplicateRegistryEntry;
        try auditUniqueStrings(entry.targets);
        try auditUniqueStrings(entry.evidence);
        _ = entry.llvm;
    }
}

fn auditHotFunctions(entries: []const HotFunction) !void {
    if (entries.len == 0) return error.EmptyHotFunctionRegistry;
    for (entries, 0..) |entry, index| {
        if (entry.id.len == 0 or entry.repository.len == 0 or entry.source.len == 0 or
            entry.function.len == 0 or entry.owner_part.len == 0 or entry.evidence.len == 0 or
            entry.budgets.len == 0)
        {
            return error.IncompleteHotFunction;
        }
        try requireHex(entry.revision, 40);
        try requireHex(entry.source_sha256, 64);
        if (!oneOf(entry.state, &.{ "accepted", "candidate", "diagnostic-red" }))
            return error.InvalidHotFunctionState;
        if (!std.mem.startsWith(u8, entry.owner_part, "silex-llvm-opt-")) return error.InvalidPartOwner;
        for (entries[0..index]) |previous| if (std.mem.eql(u8, previous.id, entry.id))
            return error.DuplicateRegistryEntry;
        if (entry.budgets.len != hot_metric_names.len) return error.InvalidStructuralBudget;
        for (entry.budgets, 0..) |budget, budget_index| {
            if (budget.metric.len == 0 or budget.unit.len == 0 or
                !oneOf(budget.direction, &.{ "max", "min", "exact" }) or
                !oneOf(budget.metric, &hot_metric_names)) return error.InvalidStructuralBudget;
            try validateObservedBudget(budget, budget.observed);
            for (entry.budgets[0..budget_index]) |previous| if (std.mem.eql(u8, previous.metric, budget.metric))
                return error.DuplicateRegistryEntry;
        }
    }
}

fn hotMeasurementValue(measurement: HotMeasurement, metric: []const u8) ?u64 {
    inline for (@typeInfo(HotMeasurement).@"struct".fields) |field| {
        if (std.mem.eql(u8, metric, field.name)) return @field(measurement, field.name);
    }
    return null;
}

fn validateObservedBudget(budget: StructuralBudget, observed: u64) !void {
    if ((std.mem.eql(u8, budget.direction, "max") and observed > budget.limit) or
        (std.mem.eql(u8, budget.direction, "min") and observed < budget.limit) or
        (std.mem.eql(u8, budget.direction, "exact") and observed != budget.limit))
    {
        return error.StructuralBudgetExceeded;
    }
}

fn auditQualification(cases: []const QualificationCase) !void {
    if (cases.len == 0) return error.EmptyQualificationCorpus;
    for (cases, 0..) |entry, index| {
        if (!entry.sealed or entry.id.len == 0 or entry.repository.len == 0 or entry.path.len == 0)
            return error.UnsealedQualificationCase;
        try requireHex(entry.revision, 40);
        try requireHex(entry.sha256, 64);
        for (cases[0..index]) |previous| if (std.mem.eql(u8, previous.id, entry.id))
            return error.DuplicateRegistryEntry;
    }
}

fn auditTransposition(entries: []const Transposition) !void {
    if (entries.len == 0) return error.EmptyTranspositionMap;
    for (entries, 0..) |entry, index| {
        if (entry.family.len == 0 or entry.owner_part.len == 0 or entry.source.len == 0 or entry.proof.len == 0)
            return error.IncompleteTranspositionEntry;
        if (!oneOf(entry.verdict, &.{ "adapted", "existing-equivalent", "gap", "irrelevant" }))
            return error.InvalidTranspositionVerdict;
        if (!std.mem.startsWith(u8, entry.owner_part, "silex-llvm-opt-")) return error.InvalidPartOwner;
        for (entries[0..index]) |previous| if (std.mem.eql(u8, previous.family, entry.family))
            return error.DuplicateRegistryEntry;
    }
}

fn auditUniqueStrings(values: []const []const u8) !void {
    if (values.len == 0) return error.EmptyRegistryList;
    for (values, 0..) |value, index| {
        if (value.len == 0) return error.EmptyRegistryList;
        for (values[0..index]) |previous| if (std.mem.eql(u8, previous, value))
            return error.DuplicateRegistryEntry;
    }
}

fn requireHex(value: []const u8, length: usize) !void {
    if (value.len != length) return error.InvalidDigest;
    for (value) |character| if (!std.ascii.isHex(character)) return error.InvalidDigest;
}

fn hasField(comptime fields: anytype, name: []const u8) bool {
    inline for (fields) |field| if (std.mem.eql(u8, name, field.name)) return true;
    return false;
}

fn oneOf(value: []const u8, candidates: []const []const u8) bool {
    for (candidates) |candidate| if (std.mem.eql(u8, value, candidate)) return true;
    return false;
}

fn firstLine(text: []const u8) []const u8 {
    return std.mem.trim(u8, text[0 .. std.mem.indexOfScalar(u8, text, '\n') orelse text.len], " \t\r");
}

fn successfulCommand(allocator: Allocator, io: std.Io, arguments: []const []const u8) !std.process.RunResult {
    const result = try std.process.run(allocator, io, .{
        .argv = arguments,
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
    });
    return switch (result.term) {
        .exited => |code| if (code == 0) result else error.CommandFailed,
        else => error.CommandFailed,
    };
}

test "the checked-in optimization registry covers every current IR operation and pass" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const bytes = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        "Benchmarks/Optimizer/Coverage.json",
        arena.allocator(),
        .limited(4 * 1024 * 1024),
    );
    const manifest = try std.json.parseFromSliceLeaky(Manifest, arena.allocator(), bytes, .{});
    try audit(manifest);
}

test "coverage audit rejects a stable entry without its cost proof" {
    const entry: Coverage = .{
        .id = "new-capability",
        .state = "equivalent",
        .owner_part = "silex-llvm-opt-02",
        .semantic = true,
        .cost_model = false,
        .debug = true,
        .release = true,
        .llvm = true,
        .structure = true,
        .targets = &.{"arm64"},
        .evidence = &.{"case.sx"},
    };
    try std.testing.expectError(error.UnprovedEquivalentEntry, auditCoverage(&.{entry}));
}

test "a current hot measurement must satisfy its versioned structural budget" {
    const budget: StructuralBudget = .{
        .metric = "machine_calls",
        .direction = "max",
        .limit = 0,
        .observed = 0,
        .unit = "instructions",
    };
    try std.testing.expectError(error.StructuralBudgetExceeded, validateObservedBudget(budget, 1));
}

test "pairwise and risk plans are deterministic and cover every binary pair" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const bytes = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        "Benchmarks/Optimizer/Coverage.json",
        arena.allocator(),
        .limited(4 * 1024 * 1024),
    );
    const manifest = try std.json.parseFromSliceLeaky(Manifest, arena.allocator(), bytes, .{});
    const first = try buildCoveragePlan(arena.allocator(), manifest);
    const repeated = try buildCoveragePlan(arena.allocator(), manifest);
    try std.testing.expectEqualStrings(first.bytes, repeated.bytes);
    const axis_count = manifest.interactions.axes.len;
    try std.testing.expectEqual(axis_count * (axis_count - 1) / 2 * 4, first.pairwise_cases);
    try std.testing.expect(std.mem.indexOf(u8, first.bytes, "alias+call+loop") != null);
}
