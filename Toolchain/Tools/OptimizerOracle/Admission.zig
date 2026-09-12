const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Manifest = struct {
    schema_version: u32,
    relevant_roots: []const []const u8,
    protected_contracts: []const []const u8,
    checks: []const Check,
    rules: []const Rule,
};

pub const Check = struct {
    id: []const u8,
    kind: []const u8,
    command: []const u8,
    status_context: []const u8,
};

pub const Rule = struct {
    id: []const u8,
    prefixes: []const []const u8,
    required_checks: []const []const u8,
    implementation_change: bool,
};

pub const Selection = struct {
    rules: []bool,
    checks: []bool,
};

pub fn load(allocator: Allocator, io: std.Io, corpus_directory: []const u8) !Manifest {
    const path = try std.fs.path.join(allocator, &.{ corpus_directory, "Admission.json" });
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024));
    return std.json.parseFromSliceLeaky(Manifest, allocator, bytes, .{});
}

pub fn audit(manifest: Manifest) !void {
    if (manifest.schema_version != 1) return error.UnsupportedAdmissionSchema;
    if (manifest.relevant_roots.len == 0 or manifest.checks.len == 0 or manifest.rules.len == 0)
        return error.IncompleteAdmissionManifest;
    try uniqueNonEmptyStrings(manifest.relevant_roots);
    try uniqueNonEmptyStrings(manifest.protected_contracts);

    for (manifest.checks, 0..) |check, index| {
        try nonEmpty(check.id);
        try nonEmpty(check.kind);
        try nonEmpty(check.command);
        try nonEmpty(check.status_context);
        for (manifest.checks[0..index]) |previous| {
            if (std.mem.eql(u8, previous.id, check.id)) return error.DuplicateAdmissionCheck;
            if (std.mem.eql(u8, previous.status_context, check.status_context))
                return error.DuplicateAdmissionStatus;
        }
    }

    for (manifest.rules, 0..) |rule, index| {
        try nonEmpty(rule.id);
        if (rule.prefixes.len == 0 or rule.required_checks.len == 0)
            return error.IncompleteAdmissionRule;
        try uniqueNonEmptyStrings(rule.prefixes);
        try uniqueNonEmptyStrings(rule.required_checks);
        for (manifest.rules[0..index]) |previous| {
            if (std.mem.eql(u8, previous.id, rule.id)) return error.DuplicateAdmissionRule;
        }
        var has_quick = false;
        for (rule.required_checks) |check_id| {
            if (findCheck(manifest, check_id) == null) return error.UnknownAdmissionCheck;
            has_quick = has_quick or std.mem.eql(u8, check_id, "optimizer-admission-quick");
        }
        if (!has_quick) return error.AdmissionRuleWithoutQuickGate;
    }

    for (manifest.relevant_roots) |root| {
        var covered = false;
        for (manifest.rules) |rule| {
            for (rule.prefixes) |prefix| {
                if (std.mem.startsWith(u8, prefix, root) or std.mem.startsWith(u8, root, prefix))
                    covered = true;
            }
        }
        if (!covered) return error.UnclassifiedAdmissionRoot;
    }
    for (manifest.protected_contracts) |protected| {
        if (!isRelevant(manifest, protected)) return error.IrrelevantProtectedContract;
        if (!hasRule(manifest, protected)) return error.UnclassifiedProtectedContract;
    }
}

pub fn select(allocator: Allocator, manifest: Manifest, raw_paths: []const []const u8) !Selection {
    return selectWithPolicy(allocator, manifest, raw_paths, true);
}

pub fn plan(allocator: Allocator, manifest: Manifest, raw_paths: []const []const u8) !Selection {
    return selectWithPolicy(allocator, manifest, raw_paths, false);
}

fn selectWithPolicy(
    allocator: Allocator,
    manifest: Manifest,
    raw_paths: []const []const u8,
    enforce_protected_separation: bool,
) !Selection {
    if (raw_paths.len == 0) return error.MissingChangedPaths;
    const selected_rules = try allocator.alloc(bool, manifest.rules.len);
    errdefer allocator.free(selected_rules);
    const selected_checks = try allocator.alloc(bool, manifest.checks.len);
    errdefer allocator.free(selected_checks);
    var selected = Selection{ .rules = selected_rules, .checks = selected_checks };
    @memset(selected.rules, false);
    @memset(selected.checks, false);

    var protected_change = false;
    var implementation_change = false;
    for (raw_paths) |raw_path| {
        const path = normalizedPath(raw_path);
        if (path.len == 0) return error.InvalidChangedPath;
        if (!isRelevant(manifest, path)) continue;

        var classified = false;
        for (manifest.rules, 0..) |rule, rule_index| {
            if (!ruleMatches(rule, path)) continue;
            classified = true;
            selected.rules[rule_index] = true;
            implementation_change = implementation_change or rule.implementation_change;
            for (rule.required_checks) |check_id| {
                const check_index = findCheck(manifest, check_id) orelse unreachable;
                selected.checks[check_index] = true;
            }
        }
        if (!classified) return error.UnclassifiedImpact;
        protected_change = protected_change or hasPrefix(path, manifest.protected_contracts);
    }
    if (enforce_protected_separation and protected_change and implementation_change)
        return error.BaselineSelfValidation;
    return selected;
}

pub fn report(io: std.Io, allocator: Allocator, manifest: Manifest, selection: Selection) !void {
    for (manifest.rules, selection.rules) |rule, enabled| {
        if (!enabled) continue;
        const line = try std.fmt.allocPrint(allocator, "CLASSIFICATION {s}\n", .{rule.id});
        try std.Io.File.stdout().writeStreamingAll(io, line);
    }
    for (manifest.checks, selection.checks) |check, enabled| {
        if (!enabled) continue;
        const line = try std.fmt.allocPrint(
            allocator,
            "REQUIRED_CHECK {s}\t{s}\t{s}\n",
            .{ check.id, check.status_context, check.command },
        );
        try std.Io.File.stdout().writeStreamingAll(io, line);
    }
}

fn findCheck(manifest: Manifest, id: []const u8) ?usize {
    for (manifest.checks, 0..) |check, index| {
        if (std.mem.eql(u8, check.id, id)) return index;
    }
    return null;
}

fn hasRule(manifest: Manifest, path: []const u8) bool {
    for (manifest.rules) |rule| if (ruleMatches(rule, path)) return true;
    return false;
}

fn ruleMatches(rule: Rule, path: []const u8) bool {
    return hasPrefix(path, rule.prefixes);
}

fn hasPrefix(path: []const u8, prefixes: []const []const u8) bool {
    for (prefixes) |prefix| {
        if (std.mem.startsWith(u8, path, prefix)) return true;
    }
    return false;
}

fn isRelevant(manifest: Manifest, path: []const u8) bool {
    return hasPrefix(path, manifest.relevant_roots);
}

fn normalizedPath(path: []const u8) []const u8 {
    var result = std.mem.trim(u8, path, " \t\r\n");
    while (std.mem.startsWith(u8, result, "./")) result = result[2..];
    return result;
}

fn nonEmpty(value: []const u8) !void {
    if (value.len == 0) return error.EmptyAdmissionValue;
}

fn uniqueNonEmptyStrings(values: []const []const u8) !void {
    for (values, 0..) |value, index| {
        try nonEmpty(value);
        for (values[0..index]) |previous| {
            if (std.mem.eql(u8, previous, value)) return error.DuplicateAdmissionValue;
        }
    }
}

const test_checks = [_]Check{
    .{ .id = "optimizer-admission-quick", .kind = "local", .command = "zig build check", .status_context = "optimizer admission / quick" },
    .{ .id = "external", .kind = "external", .command = "qualify", .status_context = "optimizer admission / external" },
};
const test_rules = [_]Rule{
    .{
        .id = "compiler",
        .prefixes = &.{"Toolchain/Sources/"},
        .required_checks = &.{ "optimizer-admission-quick", "external" },
        .implementation_change = true,
    },
    .{
        .id = "contract",
        .prefixes = &.{"Toolchain/Benchmarks/Optimizer/PerformanceBaselines.json"},
        .required_checks = &.{"optimizer-admission-quick"},
        .implementation_change = false,
    },
};
const test_manifest = Manifest{
    .schema_version = 1,
    .relevant_roots = &.{"Toolchain/"},
    .protected_contracts = &.{"Toolchain/Benchmarks/Optimizer/PerformanceBaselines.json"},
    .checks = &test_checks,
    .rules = &test_rules,
};

test "impact selects the union of required checks" {
    try audit(test_manifest);
    const selection = try select(std.testing.allocator, test_manifest, &.{"./Toolchain/Sources/Optimize/Release.zig"});
    defer std.testing.allocator.free(selection.rules);
    defer std.testing.allocator.free(selection.checks);
    try std.testing.expect(selection.rules[0]);
    try std.testing.expect(selection.checks[0]);
    try std.testing.expect(selection.checks[1]);
}

test "relevant unclassified paths are rejected" {
    try std.testing.expectError(
        error.UnclassifiedImpact,
        select(std.testing.allocator, test_manifest, &.{"Toolchain/Unknown.zig"}),
    );
}

test "an implementation cannot self-validate a protected baseline" {
    try std.testing.expectError(
        error.BaselineSelfValidation,
        select(std.testing.allocator, test_manifest, &.{
            "Toolchain/Sources/Optimize/Release.zig",
            "Toolchain/Benchmarks/Optimizer/PerformanceBaselines.json",
        }),
    );
}

test "a multi-commit plan keeps both checks after commit-level validation" {
    const selection = try plan(std.testing.allocator, test_manifest, &.{
        "Toolchain/Sources/Optimize/Release.zig",
        "Toolchain/Benchmarks/Optimizer/PerformanceBaselines.json",
    });
    defer std.testing.allocator.free(selection.rules);
    defer std.testing.allocator.free(selection.checks);
    try std.testing.expect(selection.rules[0]);
    try std.testing.expect(selection.rules[1]);
    try std.testing.expect(selection.checks[0]);
    try std.testing.expect(selection.checks[1]);
}

test "every rule must retain the quick gate" {
    const invalid_rules = [_]Rule{.{
        .id = "compiler",
        .prefixes = &.{"Toolchain/Sources/"},
        .required_checks = &.{"external"},
        .implementation_change = true,
    }};
    var invalid = test_manifest;
    invalid.rules = &invalid_rules;
    try std.testing.expectError(error.AdmissionRuleWithoutQuickGate, audit(invalid));
}

test "the live coverage contract cannot change alongside compiler implementation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const manifest = try load(arena.allocator(), std.testing.io, "Benchmarks/Optimizer");
    try audit(manifest);
    try std.testing.expectError(error.BaselineSelfValidation, select(arena.allocator(), manifest, &.{
        "Toolchain/Sources/Optimize/Release.zig",
        "Toolchain/Benchmarks/Optimizer/Assurance.json",
    }));
}
