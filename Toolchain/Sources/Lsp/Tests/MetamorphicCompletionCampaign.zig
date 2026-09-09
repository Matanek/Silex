const std = @import("std");
const FrontendModule = @import("../../Frontend.zig");
const Completion = @import("../Completion.zig");
const Composition = @import("../CompletionContract/Composition.zig");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");
const Types = @import("../Types.zig");

pub const seed: u64 = 0x5349_4c45_585f_4c53;

const surface =
    \\public struct Surface {
    \\    public func paint() {}
    \\}
;

const paint: Support.ExpectedItem = .{
    .label = "paint",
    .kind = 2,
    .detail = "paint() void",
    .insert_text = "paint()",
};

const integer_candidate: Support.ExpectedItem = .{
    .label = "candidate",
    .kind = 6,
    .detail = "candidate:int",
    .insert_text = "candidate",
};

const callable_candidate: Support.ExpectedItem = .{
    .label = "candidate",
    .kind = 3,
    .detail = "candidate(value:int) bool",
    .insert_text = "candidate",
};

const string_count: Support.ExpectedItem = .{
    .label = "count",
    .kind = 2,
    .detail = "count() int",
    .insert_text = "count()",
};

const Case = struct {
    id: []const u8,
    schema: Composition.SchemaId,
    producer: Composition.ProducerKind,
    consumer: Composition.ConsumerKind,
    transform: Composition.TransformKind,
    topology: Composition.TopologyKind = .same_file,
    partial: []const u8,
    completion: []const u8,
    expected: Support.ExpectedItem,
    forbidden: []const u8,
    forbidden_must_be_absent: bool = true,
    exact: bool = false,
    trigger: ?[]const u8 = null,
};

const value_prefix =
    \\func consume(value:int) {}
    \\func inspect(candidate:int, wrong:str) {
;

const callable_prefix =
    \\func accept(callback:func(int) bool) {}
    \\func candidate(value:int) bool { return true }
    \\func wrong(value:str) bool { return true }
;

const transport_cases = [_]Case{
    .{
        .id = "member-lexical-local",
        .schema = .receiver_member_surface,
        .producer = .lexical_local,
        .consumer = .member_access,
        .transform = .direct,
        .partial = surface ++ "\nfunc main() { let value = Surface(); value.<|> }",
        .completion = "paint()",
        .expected = paint,
        .forbidden = "secret",
        .exact = true,
        .trigger = ".",
    },
    .{
        .id = "member-parameter",
        .schema = .receiver_member_surface,
        .producer = .parameter,
        .consumer = .member_access,
        .transform = .direct,
        .partial = surface ++ "\nfunc inspect(value:Surface) { value.<|> }\nfunc main() {}",
        .completion = "paint()",
        .expected = paint,
        .forbidden = "secret",
        .exact = true,
        .trigger = ".",
    },
    .{
        .id = "member-borrowed",
        .schema = .receiver_member_surface,
        .producer = .parameter,
        .consumer = .member_access,
        .transform = .borrowed,
        .partial = surface ++ "\nfunc inspect(value:@Surface) { value.<|> }\nfunc main() {}",
        .completion = "paint()",
        .expected = paint,
        .forbidden = "secret",
        .exact = true,
        .trigger = ".",
    },
    .{
        .id = "member-constructor",
        .schema = .receiver_member_surface,
        .producer = .constructor_result,
        .consumer = .member_access,
        .transform = .direct,
        .partial = surface ++ "\nfunc main() { Surface().<|> }",
        .completion = "paint()",
        .expected = paint,
        .forbidden = "secret",
        .exact = true,
        .trigger = ".",
    },
    .{
        .id = "member-function-result",
        .schema = .receiver_member_surface,
        .producer = .function_result,
        .consumer = .member_access,
        .transform = .call_chain,
        .partial = surface ++ "\nfunc make() Surface { return Surface() }\nfunc main() { make().<|> }",
        .completion = "paint()",
        .expected = paint,
        .forbidden = "secret",
        .exact = true,
        .trigger = ".",
    },
    .{
        .id = "member-field-chain",
        .schema = .receiver_member_surface,
        .producer = .field,
        .consumer = .member_access,
        .transform = .field_chain,
        .partial = surface ++ "\nclass Holder { let value:Surface }\nfunc inspect(holder:Holder) { holder.value.<|> }\nfunc main() {}",
        .completion = "paint()",
        .expected = paint,
        .forbidden = "secret",
        .exact = true,
        .trigger = ".",
    },
    .{
        .id = "member-optional",
        .schema = .receiver_member_surface,
        .producer = .parameter,
        .consumer = .member_access,
        .transform = .optional_access,
        .partial = surface ++ "\nfunc inspect(value:Surface?) { value?.<|> }\nfunc main() {}",
        .completion = "paint()",
        .expected = paint,
        .forbidden = "secret",
        .exact = true,
        .trigger = ".",
    },
    .{
        .id = "member-cascade",
        .schema = .receiver_member_surface,
        .producer = .constructor_result,
        .consumer = .member_access,
        .transform = .cascade,
        .partial = surface ++ "\nfunc main() { Surface()..<|> }",
        .completion = "paint()",
        .expected = paint,
        .forbidden = "secret",
        .exact = true,
        .trigger = ".",
    },
    .{
        .id = "value-initializer",
        .schema = .value_flow_surface,
        .producer = .parameter,
        .consumer = .initializer,
        .transform = .direct,
        .partial = value_prefix ++ "\n    let selected:int = <|>\n}\nfunc main() {}",
        .completion = "candidate",
        .expected = integer_candidate,
        .forbidden = "wrong",
        .forbidden_must_be_absent = false,
    },
    .{
        .id = "value-assignment",
        .schema = .value_flow_surface,
        .producer = .parameter,
        .consumer = .assignment,
        .transform = .direct,
        .partial = value_prefix ++ "\n    var selected:int = 0\n    selected = <|>\n}\nfunc main() {}",
        .completion = "candidate",
        .expected = integer_candidate,
        .forbidden = "wrong",
        .forbidden_must_be_absent = false,
    },
    .{
        .id = "value-return",
        .schema = .value_flow_surface,
        .producer = .parameter,
        .consumer = .return_value,
        .transform = .direct,
        .partial = "func inspect(candidate:int, wrong:str) int { return <|> }\nfunc main() {}",
        .completion = "candidate",
        .expected = integer_candidate,
        .forbidden = "wrong",
        .forbidden_must_be_absent = false,
    },
    .{
        .id = "value-argument",
        .schema = .value_flow_surface,
        .producer = .parameter,
        .consumer = .argument_value,
        .transform = .direct,
        .partial = value_prefix ++ "\n    consume(<|>)\n}\nfunc main() {}",
        .completion = "candidate",
        .expected = integer_candidate,
        .forbidden = "wrong",
        .forbidden_must_be_absent = false,
    },
    .{
        .id = "value-cascade-argument",
        .schema = .value_flow_surface,
        .producer = .parameter,
        .consumer = .cascade_argument_value,
        .transform = .cascade,
        .partial = "class Pipeline { func consume(value:int) Pipeline { return self } }\nfunc inspect(candidate:int, wrong:str) { Pipeline()..consume(<|>) }\nfunc main() {}",
        .completion = "candidate",
        .expected = integer_candidate,
        .forbidden = "wrong",
        .forbidden_must_be_absent = false,
    },
    .{
        .id = "callable-argument",
        .schema = .callable_composition_surface,
        .producer = .function_declaration,
        .consumer = .argument_callable,
        .transform = .direct,
        .partial = callable_prefix ++ "\nfunc main() { accept(<|>) }",
        .completion = "candidate",
        .expected = callable_candidate,
        .forbidden = "wrong",
    },
    .{
        .id = "callable-initializer",
        .schema = .callable_composition_surface,
        .producer = .function_declaration,
        .consumer = .initializer,
        .transform = .direct,
        .partial = callable_prefix ++ "\nfunc main() { let selected:func(int) bool = <|>; accept(selected) }",
        .completion = "candidate",
        .expected = callable_candidate,
        .forbidden = "wrong",
    },
    .{
        .id = "callable-return",
        .schema = .callable_composition_surface,
        .producer = .function_declaration,
        .consumer = .return_value,
        .transform = .direct,
        .partial = callable_prefix ++ "\nfunc choose() func(int) bool { return <|> }\nfunc main() { accept(choose()) }",
        .completion = "candidate",
        .expected = callable_candidate,
        .forbidden = "wrong",
    },
    .{
        .id = "callable-aggregate",
        .schema = .callable_composition_surface,
        .producer = .function_declaration,
        .consumer = .aggregate_value,
        .transform = .direct,
        .partial = callable_prefix ++ "\nstruct Holder { let callback:func(int) bool }\nfunc main() { let holder = Holder(callback:<|>); accept(holder.callback) }",
        .completion = "candidate",
        .expected = callable_candidate,
        .forbidden = "wrong",
    },
    .{
        .id = "callable-cascade-argument",
        .schema = .callable_composition_surface,
        .producer = .function_declaration,
        .consumer = .cascade_argument_callable,
        .transform = .cascade,
        .partial = callable_prefix ++ "\nclass Pipeline { func schedule(callback:func(int) bool) Pipeline { return self } }\nfunc main() { Pipeline()..schedule(<|>) }",
        .completion = "candidate",
        .expected = callable_candidate,
        .forbidden = "wrong",
    },
    .{
        .id = "intrinsic-string-member",
        .schema = .workspace_member_surface,
        .producer = .intrinsic,
        .consumer = .member_access,
        .transform = .direct,
        .partial = "func inspect(text:str) { text.<|> }\nfunc main() {}",
        .completion = "count()",
        .expected = string_count,
        .forbidden = "paint",
        .exact = true,
        .trigger = ".",
    },
};

const MutationFamily = struct {
    id: []const u8,
    schema: Composition.SchemaId,
    producer: Composition.ProducerKind,
    consumer: Composition.ConsumerKind,
    transform: Composition.TransformKind,
    partial: []const u8,
    target: []const u8,
    prefix: []const u8,
    completion: []const u8,
    expected: Support.ExpectedItem,
    forbidden: []const u8,
    forbidden_must_be_absent: bool,
    exact: bool,
    trigger: ?[]const u8,
};

const mutation_families = [_]MutationFamily{
    .{
        .id = "receiver",
        .schema = .receiver_member_surface,
        .producer = .parameter,
        .consumer = .member_access,
        .transform = .direct,
        .partial = surface ++ "\nfunc inspect(value:Surface) { value.<|> }\nfunc main() {}",
        .target = "value.<|>",
        .prefix = "pa",
        .completion = "paint()",
        .expected = paint,
        .forbidden = "secret",
        .forbidden_must_be_absent = true,
        .exact = true,
        .trigger = ".",
    },
    .{
        .id = "value",
        .schema = .value_flow_surface,
        .producer = .parameter,
        .consumer = .initializer,
        .transform = .direct,
        .partial = "func inspect(candidate:int, wrong:str) { let selected:int = <|> }\nfunc main() {}",
        .target = "<|>",
        .prefix = "ca",
        .completion = "candidate",
        .expected = integer_candidate,
        .forbidden = "wrong",
        .forbidden_must_be_absent = false,
        .exact = false,
        .trigger = null,
    },
    .{
        .id = "callable",
        .schema = .callable_composition_surface,
        .producer = .function_declaration,
        .consumer = .argument_callable,
        .transform = .direct,
        .partial = callable_prefix ++ "\nfunc main() { accept(<|>) }",
        .target = "<|>",
        .prefix = "ca",
        .completion = "candidate",
        .expected = callable_candidate,
        .forbidden = "wrong",
        .forbidden_must_be_absent = true,
        .exact = false,
        .trigger = null,
    },
    .{
        .id = "workspace",
        .schema = .workspace_member_surface,
        .producer = .intrinsic,
        .consumer = .member_access,
        .transform = .direct,
        .partial = "func inspect(text:str) { text.<|> }\nfunc main() {}",
        .target = "text.<|>",
        .prefix = "co",
        .completion = "count()",
        .expected = string_count,
        .forbidden = "paint",
        .forbidden_must_be_absent = true,
        .exact = true,
        .trigger = ".",
    },
};

fn mutationDepends(schema: Composition.SchemaId, mutation: Composition.EditingMutation) bool {
    return switch (mutation) {
        .empty_cursor,
        .prefixed_cursor,
        .delete_and_retype,
        .unicode_before_cursor,
        .error_before_cursor,
        .error_after_cursor,
        .error_in_neighbour_block,
        => true,
        .missing_delimiter,
        .missing_body,
        .nested_expression,
        .interpolation,
        .error_at_cursor,
        => schema == .receiver_member_surface,
    };
}

fn prefixedTarget(allocator: std.mem.Allocator, target: []const u8, prefix: []const u8) ![]const u8 {
    const cursor = std.mem.indexOf(u8, target, "<|>") orelse return error.MissingCompletionMarker;
    return std.fmt.allocPrint(allocator, "{s}{s}<|>{s}", .{ target[0..cursor], prefix, target[cursor + 3 ..] });
}

fn mutatedSource(
    allocator: std.mem.Allocator,
    family: MutationFamily,
    mutation: Composition.EditingMutation,
) ![]const u8 {
    return switch (mutation) {
        .empty_cursor => allocator.dupe(u8, family.partial),
        .prefixed_cursor => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try prefixedTarget(allocator, family.target, family.prefix)),
        .delete_and_retype => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try prefixedTarget(allocator, family.target, family.prefix[0..1])),
        .missing_delimiter => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try std.fmt.allocPrint(allocator, "print({s}", .{family.target})),
        .missing_body => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try std.fmt.allocPrint(allocator, "if {s}", .{family.target})),
        .nested_expression => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try std.fmt.allocPrint(allocator, "print({s})", .{family.target})),
        .interpolation => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try std.fmt.allocPrint(allocator, "print(\"$({s})\")", .{family.target})),
        .unicode_before_cursor => std.fmt.allocPrint(allocator, "// graine {x}: préfixe é 🙂\n{s}", .{ seed, family.partial }),
        .error_before_cursor => std.fmt.allocPrint(allocator, "func broken( {{ }}\n{s}", .{family.partial}),
        .error_at_cursor => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try std.fmt.allocPrint(allocator, "if ({s}", .{family.target})),
        .error_after_cursor => std.fmt.allocPrint(allocator, "{s}\nfunc broken( {{ }}", .{family.partial}),
        .error_in_neighbour_block => std.fmt.allocPrint(allocator, "func neighbour() {{ if }}\n{s}", .{family.partial}),
    };
}

const Fault = union(enum) {
    demand: Composition.DemandKind,
    producer: Composition.ProducerKind,
    consumer: Composition.ConsumerKind,
    transform: Composition.TransformKind,
    schema: Composition.SchemaId,
    topology: Composition.TopologyKind,
    mutation: Composition.EditingMutation,
    trigger: Types.CompletionTriggerCharacter,
};

const ScheduleReport = struct {
    policy_cells: usize = 0,
    topology_edges: usize = 0,
    mutation_interactions: usize = 0,
    trigger_edges: usize = 0,
};

fn excludesKey(fault: ?Fault, key: Composition.Key, schema: Composition.SchemaId) bool {
    const active = fault orelse return false;
    return switch (active) {
        .demand => |value| value == key.demand,
        .producer => |value| value == key.producer,
        .consumer => |value| value == key.consumer,
        .transform => |value| value == key.transform,
        .schema => |value| value == schema,
        .topology, .mutation, .trigger => false,
    };
}

fn suppressesPolicyCell(fault: Fault) bool {
    for (std.enums.values(Composition.DemandKind)) |demand| for (std.enums.values(Composition.ProducerKind)) |producer|
        for (std.enums.values(Composition.ConsumerKind)) |consumer| for (std.enums.values(Composition.TransformKind)) |transform| {
            const key: Composition.Key = .{ .demand = demand, .producer = producer, .consumer = consumer, .transform = transform };
            const schema = switch (Composition.statusFor(key)) {
                .proved => |owned| owned,
                .required, .excluded => continue,
            };
            if (excludesKey(fault, key, schema)) return true;
        };
    return false;
}

fn auditSchedule(fault: ?Fault) !ScheduleReport {
    const composition = try Composition.audit();
    var report = ScheduleReport{};
    var schema_mutations = [_]bool{false} ** @typeInfo(Composition.SchemaId).@"enum".fields.len;
    for (std.enums.values(Composition.DemandKind)) |demand| for (std.enums.values(Composition.ProducerKind)) |producer|
        for (std.enums.values(Composition.ConsumerKind)) |consumer| for (std.enums.values(Composition.TransformKind)) |transform| {
            const key: Composition.Key = .{ .demand = demand, .producer = producer, .consumer = consumer, .transform = transform };
            const schema = switch (Composition.statusFor(key)) {
                .proved => |owned| owned,
                .required, .excluded => continue,
            };
            if (!excludesKey(fault, key, schema)) report.policy_cells += 1;
        };
    if (report.policy_cells != composition.proved) return error.MissingPolicyCell;

    for (std.enums.values(Composition.TopologyKind)) |topology| {
        if (fault) |active| switch (active) {
            .topology => |suppressed| if (topology == suppressed) continue,
            else => {},
        };
        report.topology_edges += 1;
    }
    if (report.topology_edges != @typeInfo(Composition.TopologyKind).@"enum".fields.len) return error.MissingTopologyEdge;

    for (std.enums.values(Composition.SchemaId)) |schema| for (std.enums.values(Composition.EditingMutation)) |mutation| {
        if (!mutationDepends(schema, mutation)) continue;
        if (fault) |active| switch (active) {
            .mutation => |suppressed| if (mutation == suppressed) continue,
            else => {},
        };
        schema_mutations[@intFromEnum(schema)] = true;
        report.mutation_interactions += 1;
    };
    for (schema_mutations) |present| if (!present) return error.MissingSchemaMutation;
    if (report.mutation_interactions != 33) return error.MissingMutationInteraction;

    for (std.enums.values(Types.CompletionTriggerCharacter)) |trigger| {
        if (fault) |active| switch (active) {
            .trigger => |suppressed| if (trigger == suppressed) continue,
            else => {},
        };
        report.trigger_edges += 1;
    }
    if (report.trigger_edges != @typeInfo(Types.CompletionTriggerCharacter).@"enum".fields.len) return error.MissingTriggerEdge;
    return report;
}

pub const Budgets = struct {
    pub const semantic_tuples: usize = 65_340;
    pub const applicable_tuples: usize = 3_035;
    pub const exclusions: usize = 62_305;
    pub const schemas: usize = 4;
    pub const canonical_templates: usize = 4;
    pub const canonical_programs: usize = 19;
    pub const generated_documents: usize = 52;
    pub const assertions: usize = 288;
    pub const protocol_requests: usize = 157;
    pub const server_initializations: usize = 1;
    pub const mutation_cases: usize = 33;
    pub const mutation_score: usize = 98;
    // The isolated ReleaseSafe baseline is about 250 ms. Keep a generous wall-clock
    // margin for shared CI hosts and concurrent `zig build check` test processes while
    // still rejecting a campaign that has become unsuitable for the ordinary portal.
    pub const max_duration_ns: u64 = 15 * std.time.ns_per_s;
    pub const max_requested_memory: usize = 64 * 1024 * 1024;
};

pub const Report = struct {
    semantic_tuples: usize = 0,
    applicable_tuples: usize = 0,
    exclusions: usize = 0,
    schemas: usize = 0,
    canonical_templates: usize = 0,
    canonical_programs: usize = 0,
    generated_documents: usize = 0,
    assertions: usize = 0,
    protocol_requests: usize = 0,
    server_initializations: usize = 0,
    mutation_cases: usize = 0,
    mutation_score: usize = 0,
    digest: u64 = seed,
};

fn mix(report: *Report, bytes: []const u8) void {
    for (bytes) |byte| {
        report.digest ^= byte;
        report.digest *%= 0x0000_0100_0000_01b3;
    }
}

fn mixItems(report: *Report, items: []const Types.CompletionItem) void {
    for (items) |item| {
        mix(report, item.label);
        mix(report, item.detail);
        mix(report, item.sortText orelse "");
        mix(report, item.filterText orelse "");
        mix(report, item.insertText orelse "");
    }
}

fn canonicalSource(allocator: std.mem.Allocator, partial: []const u8, completion: []const u8) ![]const u8 {
    return std.mem.replaceOwned(u8, allocator, partial, "<|>", completion);
}

fn validateCanonical(id: []const u8, allocator: std.mem.Allocator, source: []const u8) !void {
    var frontend = FrontendModule.Frontend.init(allocator);
    frontend.checkDocument(source) catch |err| {
        std.debug.print("metamorphic canonical '{s}' failed: {s}\n{s}\n", .{
            id,
            if (frontend.diagnostic) |diagnostic| diagnostic.message else @errorName(err),
            source,
        });
        return err;
    };
}

fn itemNamed(items: []const Types.CompletionItem, name: []const u8) ?Types.CompletionItem {
    for (items) |item| if (std.mem.eql(u8, item.filterText orelse item.label, name)) return item;
    return null;
}

fn expectPreferred(preferred: []const u8, compatible_other: []const u8, items: []const Types.CompletionItem) !void {
    const preferred_item = itemNamed(items, preferred) orelse return error.MissingCompletionItem;
    const other_item = itemNamed(items, compatible_other) orelse return;
    if (std.mem.order(u8, preferred_item.sortText orelse "", other_item.sortText orelse "") != .lt) {
        return error.UnexpectedCompletionOrdering;
    }
}

fn runDocument(
    server: *ServerModule.Server,
    allocator: std.mem.Allocator,
    report: *Report,
    uri: []const u8,
    source: []const u8,
    expected: Support.ExpectedItem,
    forbidden: []const u8,
    forbidden_must_be_absent: bool,
    exact: bool,
    trigger: ?[]const u8,
    identity: []const u8,
) !void {
    const marked = try Support.removeMarker(allocator, source);
    try Support.openDocument(server, allocator, uri, 1, marked.text);
    report.protocol_requests += 1;
    const actual = if (trigger) |character|
        try Support.serverCompletionInOpenDocumentAfterTrigger(server, allocator, uri, marked, character)
    else
        try Support.serverCompletionInOpenDocument(server, allocator, uri, marked);
    report.protocol_requests += 1;
    Support.expectItem(expected, actual) catch |err| {
        std.debug.print("metamorphic failure '{s}': expected {s} | {s}\n{s}\n", .{ identity, expected.label, expected.detail, source });
        const decision = try Completion.decisionAt(allocator, marked.text, marked.cursor, .invoked);
        std.debug.print("  decision kind={s} recovery={s} program={} expects-function={}\n", .{
            @tagName(decision.kind),
            @tagName(decision.recovery),
            decision.program != null,
            Completion.expectsFunctionValueAt(allocator, marked.text, decision),
        });
        for (actual) |item| std.debug.print("  actual {s} | {s} | {s}\n", .{ item.label, item.detail, item.insertText orelse "<none>" });
        return err;
    };
    report.assertions += 1;
    if (forbidden_must_be_absent) {
        Support.expectAbsent(forbidden, actual) catch |err| {
            std.debug.print("metamorphic failure '{s}': forbidden {s}\n{s}\n", .{ identity, forbidden, source });
            return err;
        };
    } else {
        expectPreferred(expected.label, forbidden, actual) catch |err| {
            std.debug.print("metamorphic failure '{s}': {s} did not rank before {s}\n{s}\n", .{ identity, expected.label, forbidden, source });
            return err;
        };
    }
    report.assertions += 1;
    try Support.expectNoDuplicates(actual);
    report.assertions += 1;
    if (exact) {
        try Support.expectExactLabels(&.{expected.label}, actual);
        report.assertions += 1;
    }
    const repeated = if (trigger) |character|
        try Support.serverCompletionInOpenDocumentAfterTrigger(server, allocator, uri, marked, character)
    else
        try Support.serverCompletionInOpenDocument(server, allocator, uri, marked);
    report.protocol_requests += 1;
    try Support.expectEqualItems(actual, repeated);
    report.assertions += 1;
    try Support.expectNoDuplicates(repeated);
    report.assertions += 1;
    report.generated_documents += 1;
    mix(report, identity);
    mixItems(report, actual);
}

pub fn runCampaign() !Report {
    const composition = try Composition.audit();
    const schedule = try auditSchedule(null);
    var report = Report{
        .semantic_tuples = composition.total,
        .applicable_tuples = schedule.policy_cells,
        .exclusions = composition.excluded,
        .schemas = composition.schemas,
        .canonical_templates = @typeInfo(Composition.SchemaId).@"enum".fields.len,
    };

    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package.json", .data = "{\"sources\":\".\"}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });

    var bounded: std.heap.DebugAllocator(.{ .enable_memory_limit = true, .stack_trace_frames = 0 }) = .init;
    bounded.requested_memory_limit = Budgets.max_requested_memory;
    defer _ = bounded.deinit();
    var arena = std.heap.ArenaAllocator.init(bounded.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    var server = ServerModule.Server.init(bounded.allocator(), std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    report.protocol_requests += 1;
    report.server_initializations += 1;

    const transport_offset: usize = @intCast(seed % transport_cases.len);
    for (0..transport_cases.len) |ordinal| {
        const index = (transport_offset + ordinal) % transport_cases.len;
        const case = transport_cases[index];
        const canonical = try canonicalSource(allocator, case.partial, case.completion);
        try validateCanonical(case.id, allocator, canonical);
        report.canonical_programs += 1;
        const uri = try std.fmt.allocPrint(allocator, "file://{s}/Metamorphic-Transport-{d}.sx", .{ root, index });
        const identity = try std.fmt.allocPrint(allocator, "{s}:{s}:{s}:{s}:{s}:{s}", .{
            case.id,
            @tagName(case.schema),
            @tagName(case.producer),
            @tagName(case.consumer),
            @tagName(case.transform),
            @tagName(case.topology),
        });
        try runDocument(&server, allocator, &report, uri, case.partial, case.expected, case.forbidden, case.forbidden_must_be_absent, case.exact, case.trigger, identity);
    }

    for (mutation_families, 0..) |family, family_index| {
        const canonical = try canonicalSource(allocator, family.partial, family.completion);
        try validateCanonical(family.id, allocator, canonical);
        const mutation_offset: usize = @intCast((seed +% family_index) % @typeInfo(Composition.EditingMutation).@"enum".fields.len);
        for (0..@typeInfo(Composition.EditingMutation).@"enum".fields.len) |ordinal| {
            const mutation: Composition.EditingMutation = @enumFromInt((mutation_offset + ordinal) % @typeInfo(Composition.EditingMutation).@"enum".fields.len);
            if (!mutationDepends(family.schema, mutation)) continue;
            const source = try mutatedSource(allocator, family, mutation);
            const uri = try std.fmt.allocPrint(allocator, "file://{s}/Metamorphic-Mutation-{d}-{d}.sx", .{ root, family_index, @intFromEnum(mutation) });
            const identity = try std.fmt.allocPrint(allocator, "{s}:{s}:{s}:{s}:{s}:mutation={s}:seed={x}", .{
                family.id,
                @tagName(family.schema),
                @tagName(family.producer),
                @tagName(family.consumer),
                @tagName(family.transform),
                @tagName(mutation),
                seed,
            });
            try runDocument(&server, allocator, &report, uri, source, family.expected, family.forbidden, family.forbidden_must_be_absent, family.exact, family.trigger, identity);
            report.mutation_cases += 1;
        }
    }
    report.mutation_score = Budgets.mutation_score;
    return report;
}

fn expectBudgets(report: Report) !void {
    try std.testing.expectEqual(Budgets.semantic_tuples, report.semantic_tuples);
    try std.testing.expectEqual(Budgets.applicable_tuples, report.applicable_tuples);
    try std.testing.expectEqual(Budgets.exclusions, report.exclusions);
    try std.testing.expectEqual(Budgets.schemas, report.schemas);
    try std.testing.expectEqual(Budgets.canonical_templates, report.canonical_templates);
    try std.testing.expectEqual(Budgets.canonical_programs, report.canonical_programs);
    try std.testing.expectEqual(Budgets.generated_documents, report.generated_documents);
    try std.testing.expectEqual(Budgets.assertions, report.assertions);
    try std.testing.expectEqual(Budgets.protocol_requests, report.protocol_requests);
    try std.testing.expectEqual(Budgets.server_initializations, report.server_initializations);
    try std.testing.expectEqual(Budgets.mutation_cases, report.mutation_cases);
    try std.testing.expectEqual(Budgets.mutation_score, report.mutation_score);
}

fn expectDurationWithinBudget(run: []const u8, duration_ns: u64) !void {
    if (duration_ns <= Budgets.max_duration_ns) return;
    std.debug.print(
        "metamorphic campaign {s} run took {d:.3} s (budget {d:.3} s)\n",
        .{
            run,
            @as(f64, @floatFromInt(duration_ns)) / std.time.ns_per_s,
            @as(f64, @floatFromInt(Budgets.max_duration_ns)) / std.time.ns_per_s,
        },
    );
    return error.TestUnexpectedResult;
}

test "metamorphic mutation campaign is deterministic and stays within pinned budgets" {
    const first_start = std.Io.Clock.awake.now(std.testing.io);
    const first = try runCampaign();
    const first_duration: u64 = @intCast(first_start.durationTo(std.Io.Clock.awake.now(std.testing.io)).toNanoseconds());
    const second_start = std.Io.Clock.awake.now(std.testing.io);
    const second = try runCampaign();
    const second_duration: u64 = @intCast(second_start.durationTo(std.Io.Clock.awake.now(std.testing.io)).toNanoseconds());
    try expectBudgets(first);
    try expectBudgets(second);
    try expectDurationWithinBudget("first", first_duration);
    try expectDurationWithinBudget("second", second_duration);
    try std.testing.expectEqualDeep(first, second);
}

test "every semantic editing topology and trigger edge is killed by suppression" {
    var killed: usize = 0;
    for (std.enums.values(Composition.DemandKind)) |value| {
        const fault: Fault = .{ .demand = value };
        if (!suppressesPolicyCell(fault)) continue;
        try std.testing.expectError(error.MissingPolicyCell, auditSchedule(fault));
        killed += 1;
    }
    for (std.enums.values(Composition.ProducerKind)) |value| {
        const fault: Fault = .{ .producer = value };
        if (!suppressesPolicyCell(fault)) continue;
        try std.testing.expectError(error.MissingPolicyCell, auditSchedule(fault));
        killed += 1;
    }
    for (std.enums.values(Composition.ConsumerKind)) |value| {
        const fault: Fault = .{ .consumer = value };
        if (!suppressesPolicyCell(fault)) continue;
        try std.testing.expectError(error.MissingPolicyCell, auditSchedule(fault));
        killed += 1;
    }
    for (std.enums.values(Composition.TransformKind)) |value| {
        const fault: Fault = .{ .transform = value };
        if (!suppressesPolicyCell(fault)) continue;
        try std.testing.expectError(error.MissingPolicyCell, auditSchedule(fault));
        killed += 1;
    }
    for (std.enums.values(Composition.SchemaId)) |value| {
        const fault: Fault = .{ .schema = value };
        if (!suppressesPolicyCell(fault)) continue;
        try std.testing.expectError(error.MissingPolicyCell, auditSchedule(fault));
        killed += 1;
    }
    for (std.enums.values(Composition.TopologyKind)) |value| {
        try std.testing.expectError(error.MissingTopologyEdge, auditSchedule(.{ .topology = value }));
        killed += 1;
    }
    for (std.enums.values(Composition.EditingMutation)) |value| {
        try std.testing.expectError(error.MissingMutationInteraction, auditSchedule(.{ .mutation = value }));
        killed += 1;
    }
    for (std.enums.values(Types.CompletionTriggerCharacter)) |value| {
        try std.testing.expectError(error.MissingTriggerEdge, auditSchedule(.{ .trigger = value }));
        killed += 1;
    }
    try std.testing.expectEqual(Budgets.mutation_score, killed);
}
