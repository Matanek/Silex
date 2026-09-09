const std = @import("std");
const Ast = @import("../Ast.zig");
const Lexer = @import("../Lexer.zig");
const Parser = @import("../Parser.zig");

pub const marker = "<|>";

pub const Capability = enum {
    declarations,
    types,
    statements,
    expressions,
    call_arguments,
    aggregate_fields,
    lexical_scope,
    member_local,
    member_imported,
    cascade_local,
    cascade_imported,
    topology,
    visibility,
    overlay_protocol,
    lsp_contract,
    invariants,
};

pub const GapOwner = enum { part_02, part_03, part_04, part_05, part_06 };

pub const Status = union(enum) {
    protected: []const u8,
    assigned_gap: GapOwner,
    irrelevant: []const u8,
};

pub const Scenario = struct {
    id: []const u8,
    capability: Capability,
    canonical_source: []const u8,
    partial_source: []const u8,
    required: []const []const u8,
    forbidden: []const []const u8,
    provenance: []const u8,
    status: Status,
};

pub const scenarios = [_]Scenario{
    .{
        .id = "declaration-module-empty",
        .capability = .declarations,
        .canonical_source = "public struct Player {}\nfunc main() {}",
        .partial_source = "pub<|>",
        .required = &.{"public"},
        .forbidden = &.{"break"},
        .provenance = "FR/Language/Declarations",
        .status = .{ .assigned_gap = .part_03 },
    },
    .{
        .id = "type-qualified-import",
        .capability = .types,
        .canonical_source = "struct Player { var position:Math.Vec2 }",
        .partial_source = "struct Player { var position:Math.<|> }",
        .required = &.{"Vec2"},
        .forbidden = &.{"print"},
        .provenance = "FR/Language/Types",
        .status = .{ .assigned_gap = .part_03 },
    },
    .{
        .id = "statement-loop-control",
        .capability = .statements,
        .canonical_source = "func main() { while true { break } }",
        .partial_source = "func main() { while true { br<|> } }",
        .required = &.{"break"},
        .forbidden = &.{"public"},
        .provenance = "FR/Language/Statements",
        .status = .{ .assigned_gap = .part_03 },
    },
    .{
        .id = "expression-typed-prefix",
        .capability = .expressions,
        .canonical_source = "struct Recipe {}\nfunc world_factory() Recipe { return Recipe() }\nfunc main() { var value:Recipe = world_factory() }",
        .partial_source = "struct Recipe {}\nfunc world_factory() Recipe { return Recipe() }\nfunc main() { var value:Recipe = world_f<|> }",
        .required = &.{"world_factory"},
        .forbidden = &.{"while"},
        .provenance = "regression 38742fd",
        .status = .{ .protected = "Lsp.Tests.WorkspaceContracts: typed initializers preserve prefixed workspace expression roots" },
    },
    .{
        .id = "call-label-middle",
        .capability = .call_arguments,
        .canonical_source = "func spawn(health:int, force:int) {}\nfunc main() { spawn(health:100, force:10) }",
        .partial_source = "func spawn(health:int, force:int) {}\nfunc main() { spawn(health:100, <|>) }",
        .required = &.{"force"},
        .forbidden = &.{"health"},
        .provenance = "FR/Language/Functions",
        .status = .{ .assigned_gap = .part_03 },
    },
    .{
        .id = "aggregate-remaining-field",
        .capability = .aggregate_fields,
        .canonical_source = "struct Player { var health:int var force:int }\nfunc main() { Player(health:100, force:10) }",
        .partial_source = "struct Player { var health:int var force:int }\nfunc main() { Player(health:100, <|>) }",
        .required = &.{"force"},
        .forbidden = &.{"health"},
        .provenance = "FR/Language/Structures",
        .status = .{ .assigned_gap = .part_03 },
    },
    .{
        .id = "lexical-query-destructuring",
        .capability = .lexical_scope,
        .canonical_source = "class Query<T> {}\nstruct Motion {}\nfunc update(query:Query<(&Motion,)>) { for motion in query { print(motion) } }",
        .partial_source = "class Query<T> {}\nstruct Motion {}\nfunc update(query:Query<(&Motion,)>) { for motion in query { mot<|> } }",
        .required = &.{"motion"},
        .forbidden = &.{"query_internal"},
        .provenance = "FR/Language/Control-flow",
        .status = .{ .assigned_gap = .part_03 },
    },
    .{
        .id = "member-local-incomplete-if",
        .capability = .member_local,
        .canonical_source = "struct Input { func pressed() bool { return true } }\nfunc main() { let input = Input() if input.pressed() {} }",
        .partial_source = "struct Input { func pressed() bool { return true } }\nfunc main() { let input = Input() if input.<|> }",
        .required = &.{"pressed"},
        .forbidden = &.{"if"},
        .provenance = "incomplete condition neighbour",
        .status = .{ .protected = "Lsp.Completion: recover member completion in an unfinished conditional" },
    },
    .{
        .id = "member-imported-field-chain",
        .capability = .member_imported,
        .canonical_source = "func update() { if transform.position.length() > 0.0 {} }",
        .partial_source = "func update() { if transform.position.<|> }",
        .required = &.{ "length", "normalized" },
        .forbidden = &.{"position"},
        .provenance = "Sandbox/Main.sx transform.position : Math.Vec2",
        .status = .{ .assigned_gap = .part_04 },
    },
    .{
        .id = "cascade-local-incomplete",
        .capability = .cascade_local,
        .canonical_source = "class Recipe { func with(value:int) Recipe { return self } }\nfunc main() { Recipe()..with(1) }",
        .partial_source = "class Recipe { func with(value:int) Recipe { return self } }\nfunc main() { Recipe()..<|> }",
        .required = &.{"with"},
        .forbidden = &.{"if"},
        .provenance = "regression 3e96726",
        .status = .{ .protected = "Lsp.Completion: incomplete cascade recovery" },
    },
    .{
        .id = "cascade-imported-principal-reexport",
        .capability = .cascade_imported,
        .canonical_source = "use GFX.Canvas\nfunc draw_player() Canvas { return Canvas()..paint(func () {}) }",
        .partial_source = "use GFX.Canvas\nfunc draw_player() Canvas { return Canvas()..<|> }",
        .required = &.{ "paint", "clear" },
        .forbidden = &.{"spawn"},
        .provenance = "Sandbox/Main.sx and GFX.Canvas principal reexport",
        .status = .{ .protected = "Lsp.Tests.WorkspaceContracts: server completes a cascade on an imported homonymous principal type" },
    },
    .{
        .id = "topology-catalog-fragment-field-chain",
        .capability = .topology,
        .canonical_source = "use GFX.Components\nuse STD.Math\nfunc update() { var pos:Math.Vec2 = transform.position print(pos.length()) }",
        .partial_source = "use GFX.Components\nuse STD.Math\nfunc update() { var pos:Math.Vec2 = transform.position if pos.<|> }",
        .required = &.{ "length", "normalized" },
        .forbidden = &.{"position"},
        .provenance = "Sandbox/Main.sx catalog plus @Vec2.sx fragment",
        .status = .{ .assigned_gap = .part_05 },
    },
    .{
        .id = "visibility-imported-private-negative",
        .capability = .visibility,
        .canonical_source = "public class Api { private func secret() {} func visible() {} }",
        .partial_source = "use Package.Api\nfunc main(api:&Api) { api.<|> }",
        .required = &.{"visible"},
        .forbidden = &.{"secret"},
        .provenance = "FR/Language/Visibility",
        .status = .{ .assigned_gap = .part_05 },
    },
    .{
        .id = "overlay-unsaved-import",
        .capability = .overlay_protocol,
        .canonical_source = "public struct BufferType {}",
        .partial_source = "use Api\nfunc test() Result<Api.<|>, str>",
        .required = &.{"BufferType"},
        .forbidden = &.{"DiskType"},
        .provenance = "unsaved imported document overlay",
        .status = .{ .protected = "Lsp.Tests.WorkspaceContracts: workspace completion uses the unsaved contents of imported documents" },
    },
    .{
        .id = "lsp-utf16-trigger-metadata",
        .capability = .lsp_contract,
        .canonical_source = "func café() {}\nfunc main() { café() }",
        .partial_source = "func café() {}\nfunc main() { caf<|> }",
        .required = &.{"café"},
        .forbidden = &.{"duplicate:café"},
        .provenance = "LSP UTF-16 completion contract",
        .status = .{ .assigned_gap = .part_06 },
    },
    .{
        .id = "invariant-deterministic-no-duplicates",
        .capability = .invariants,
        .canonical_source = "func paint() {}\nfunc main() { paint() }",
        .partial_source = "func paint() {}\nfunc main() { pa<|> }",
        .required = &.{"same response twice"},
        .forbidden = &.{ "duplicate identity", "internal compiler name" },
        .provenance = "universal completion invariants",
        .status = .{ .assigned_gap = .part_06 },
    },
    .{
        .id = "recovery-error-before-cursor",
        .capability = .invariants,
        .canonical_source = "struct Input { func pressed() bool { return true } }\nfunc helper() {}\nfunc main() { let input = Input() input.pressed() }",
        .partial_source = "struct Input { func pressed() bool { return true } }\nfunc helper( { }\nfunc main() { let input = Input() input.<|> }",
        .required = &.{"pressed"},
        .forbidden = &.{"empty response caused by unrelated parse error"},
        .provenance = "global completion loss after a syntax error",
        .status = .{ .assigned_gap = .part_02 },
    },
    .{
        .id = "recovery-error-at-cursor",
        .capability = .invariants,
        .canonical_source = "struct Input { func pressed() bool { return true } }\nfunc main() { let input = Input() if input.pressed() {} }",
        .partial_source = "struct Input { func pressed() bool { return true } }\nfunc main() { let input = Input() if (input.<|> }",
        .required = &.{"pressed"},
        .forbidden = &.{"empty response caused by the incomplete expression"},
        .provenance = "completion site is itself a syntax error while typing",
        .status = .{ .assigned_gap = .part_02 },
    },
    .{
        .id = "recovery-error-after-cursor",
        .capability = .invariants,
        .canonical_source = "struct Input { func pressed() bool { return true } }\nfunc main() { let input = Input() input.pressed() }\nfunc helper() {}",
        .partial_source = "struct Input { func pressed() bool { return true } }\nfunc main() { let input = Input() input.<|> }\nfunc helper( { }",
        .required = &.{"pressed"},
        .forbidden = &.{"empty response caused by following parse error"},
        .provenance = "global completion loss after a syntax error",
        .status = .{ .assigned_gap = .part_02 },
    },
    .{
        .id = "recovery-error-neighbour-block",
        .capability = .invariants,
        .canonical_source = "struct Input { func pressed() bool { return true } }\nfunc helper() {}\nfunc main() { let input = Input() input.pressed() }",
        .partial_source = "struct Input { func pressed() bool { return true } }\nfunc helper() { if }\nfunc main() { let input = Input() input.<|> }",
        .required = &.{"pressed"},
        .forbidden = &.{"context imported from broken neighbour"},
        .provenance = "global completion loss after a syntax error",
        .status = .{ .assigned_gap = .part_02 },
    },
};

pub const Position = enum { module, structure, modifier, type_name, statement, expression, member, argument, call_label, aggregate_field, nominal_relation, use_path };
pub const Origin = enum { intrinsic, lexical, local, imported, extension, protocol_member, alias, reexport, catalog, atom };
pub const Receiver = enum { value, reference, optional, static_type, module, principal_type, generic, tuple, dynamic_protocol, call_result, field_result, chain, cascade };
pub const Topology = enum { loose, package, dependency, development_dependency, friend, submodule, merged_extension, suite_extension, catalog, overlay, platform_fragment };
pub const Editing = enum {
    empty,
    prefixed,
    deleted,
    delimiter_missing,
    body_missing,
    nested,
    interpolation,
    unicode_before_cursor,
    syntax_error_before_cursor,
    syntax_error_at_cursor,
    syntax_error_after_cursor,
    syntax_error_neighbour_block,
};
pub const Trigger = enum { invoked, dot, colon, less, comma, space, closing_parenthesis };
pub const Observable = enum { labels, order, kind, detail, insertion, snippet, duplicates, deterministic };

pub fn positionCapability(value: Position) Capability {
    return switch (value) {
        .module, .structure, .modifier => .declarations,
        .type_name, .nominal_relation => .types,
        .statement => .statements,
        .expression => .expressions,
        .member => .member_local,
        .argument, .call_label => .call_arguments,
        .aggregate_field => .aggregate_fields,
        .use_path => .topology,
    };
}

pub fn originCapability(value: Origin) Capability {
    return switch (value) {
        .intrinsic, .lexical, .local => .lexical_scope,
        .imported, .extension, .protocol_member, .alias, .reexport, .catalog, .atom => .member_imported,
    };
}

pub fn receiverCapability(value: Receiver) Capability {
    return switch (value) {
        .value, .reference, .optional, .generic, .tuple, .dynamic_protocol => .member_local,
        .static_type, .module, .principal_type, .call_result, .field_result, .chain => .member_imported,
        .cascade => .cascade_imported,
    };
}

pub fn topologyCapability(value: Topology) Capability {
    return switch (value) {
        .loose, .package, .dependency, .development_dependency, .friend, .submodule, .merged_extension, .suite_extension, .catalog, .platform_fragment => .topology,
        .overlay => .overlay_protocol,
    };
}

pub fn editingCapability(value: Editing) Capability {
    return switch (value) {
        .empty,
        .prefixed,
        .deleted,
        .delimiter_missing,
        .body_missing,
        .nested,
        .interpolation,
        .unicode_before_cursor,
        .syntax_error_before_cursor,
        .syntax_error_at_cursor,
        .syntax_error_after_cursor,
        .syntax_error_neighbour_block,
        => .invariants,
    };
}

pub fn triggerCapability(value: Trigger) Capability {
    return switch (value) {
        .invoked, .dot, .colon, .less, .comma, .space, .closing_parenthesis => .lsp_contract,
    };
}

pub fn observableCapability(value: Observable) Capability {
    return switch (value) {
        .labels, .order, .kind, .detail, .insertion, .snippet => .lsp_contract,
        .duplicates, .deterministic => .invariants,
    };
}

pub fn parserProductionCapability(value: Parser.CompletionSites.Production) Capability {
    return switch (value) {
        .use_path => .topology,
        .use_alias, .module_declaration, .structure_declaration, .modifier => .declarations,
        .type_annotation, .generic_parameter, .generic_argument, .nominal_relation, .parameter, .return_type => .types,
        .statement => .statements,
        .expression => .expressions,
        .member_access => .member_local,
        .cascade_operation => .cascade_local,
        .call_argument, .call_label => .call_arguments,
        .aggregate_field => .aggregate_fields,
        .interpolation_expression, .match_branch, .for_source => .expressions,
        .try_alternative => .statements,
    };
}

pub const TokenPolicy = enum { choice, context, recovery, irrelevant };

pub fn tokenPolicy(tag: Lexer.TokenTag) TokenPolicy {
    return switch (tag) {
        .keyword_let,
        .keyword_var,
        .keyword_if,
        .keyword_elif,
        .keyword_else,
        .keyword_while,
        .keyword_mutex,
        .keyword_for,
        .keyword_range,
        .keyword_in,
        .keyword_break,
        .keyword_continue,
        .keyword_return,
        .keyword_try,
        .keyword_move,
        .keyword_copy,
        .keyword_struct,
        .keyword_class,
        .keyword_protocol,
        .keyword_extend,
        .keyword_contribute,
        .keyword_enum,
        .keyword_match,
        .keyword_init,
        .keyword_drop,
        .keyword_super,
        .keyword_override,
        .keyword_static,
        .keyword_func,
        .keyword_use,
        .keyword_private,
        .keyword_package,
        .keyword_module,
        .keyword_local,
        .keyword_protected,
        .keyword_public,
        .keyword_as,
        => .choice,

        .keyword_void,
        .keyword_self,
        .keyword_true,
        .keyword_false,
        .keyword_null,
        .keyword_int,
        .keyword_int8,
        .keyword_int16,
        .keyword_int32,
        .keyword_int64,
        .keyword_uint,
        .keyword_uint8,
        .keyword_uint16,
        .keyword_uint32,
        .keyword_uint64,
        .keyword_float,
        .keyword_float32,
        .keyword_float64,
        .keyword_bool,
        .keyword_str,
        .keyword_print,
        .keyword_assert,
        .keyword_panic,
        .identifier,
        .integer,
        .floating,
        .string,
        .string_start,
        .string_text,
        .interpolation_start,
        .interpolation_end,
        .string_end,
        => .context,

        .plus,
        .plus_plus,
        .plus_equal,
        .minus,
        .minus_minus,
        .minus_equal,
        .star,
        .star_equal,
        .slash,
        .slash_equal,
        .percent,
        .percent_equal,
        .bang,
        .equal,
        .equal_equal,
        .fat_arrow,
        .bang_equal,
        .less,
        .less_equal,
        .shift_left,
        .greater,
        .greater_equal,
        .shift_right,
        .amp_amp,
        .amp,
        .at,
        .caret,
        .question,
        .question_question,
        .question_dot,
        .pipe_pipe,
        .colon,
        .comma,
        .dot,
        .dot_dot,
        .dot_dot_dot,
        .left_parenthesis,
        .right_parenthesis,
        .left_brace,
        .right_brace,
        .left_bracket,
        .right_bracket,
        .semicolon,
        => .recovery,

        .legacy_internal, .end => .irrelevant,
    };
}

pub fn expressionCapability(tag: std.meta.Tag(Ast.Expression.Value)) Capability {
    return switch (tag) {
        .integer,
        .floating,
        .boolean,
        .null_value,
        .string,
        .interpolated_string,
        .identifier,
        .generic_reference,
        .unary,
        .binary,
        .conversion,
        .string_count,
        .sequence_literal,
        .tuple_literal,
        .index_access,
        .slice_access,
        .match_expression,
        => .expressions,
        .call, .field_access => .member_local,
        .cascade => .cascade_local,
    };
}

pub fn statementCapability(tag: std.meta.Tag(Ast.Statement)) Capability {
    return switch (tag) {
        .variable_declaration => .lexical_scope,
        .assignment_statement,
        .return_statement,
        .expression_statement,
        .print_statement,
        .assert_statement,
        .panic_statement,
        .if_statement,
        .while_statement,
        .for_statement,
        .mutex_statement,
        .break_statement,
        .continue_statement,
        => .statements,
    };
}

pub fn audit(registry: []const Scenario) !void {
    var covered = [_]bool{false} ** @typeInfo(Capability).@"enum".fields.len;
    for (registry, 0..) |scenario, index| {
        if (scenario.id.len == 0) return error.MissingIdentifier;
        if (scenario.canonical_source.len == 0) return error.MissingCanonicalSource;
        if (countOccurrences(scenario.partial_source, marker) != 1) return error.InvalidCursorCount;
        if (scenario.required.len == 0) return error.MissingRequiredCandidate;
        if (scenario.forbidden.len == 0) return error.MissingForbiddenCandidate;
        if (scenario.provenance.len == 0) return error.MissingProvenance;
        if (containsInfrastructurePath(scenario)) return error.InfrastructureDependency;
        switch (scenario.status) {
            .protected => |proof| if (proof.len == 0) return error.MissingProof,
            .assigned_gap => {},
            .irrelevant => |reason| if (reason.len == 0) return error.MissingReason,
        }
        for (registry[index + 1 ..]) |other| {
            if (std.mem.eql(u8, scenario.id, other.id)) return error.DuplicateIdentifier;
        }
        covered[@intFromEnum(scenario.capability)] = true;
    }
    for (covered) |present| if (!present) return error.MissingCapability;
}

fn countOccurrences(haystack: []const u8, needle: []const u8) usize {
    var count: usize = 0;
    var offset: usize = 0;
    while (std.mem.indexOfPos(u8, haystack, offset, needle)) |index| {
        count += 1;
        offset = index + needle.len;
    }
    return count;
}

fn containsInfrastructurePath(scenario: Scenario) bool {
    const values = [_][]const u8{
        scenario.canonical_source,
        scenario.partial_source,
        scenario.provenance,
    };
    for (values) |value| {
        if (std.mem.indexOf(u8, value, ".specs/") != null or
            std.mem.indexOf(u8, value, ".agents/") != null or
            std.mem.indexOf(u8, value, "/Users/") != null) return true;
    }
    return false;
}

test "completion registry is classified and self contained" {
    try audit(&scenarios);
}

test "closed compiler and completion inventories require exhaustive policies" {
    inline for (@typeInfo(Position).@"enum".fields) |field| _ = positionCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Origin).@"enum".fields) |field| _ = originCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Receiver).@"enum".fields) |field| _ = receiverCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Topology).@"enum".fields) |field| _ = topologyCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Editing).@"enum".fields) |field| _ = editingCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Trigger).@"enum".fields) |field| _ = triggerCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Observable).@"enum".fields) |field| _ = observableCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Parser.CompletionSites.Production).@"enum".fields) |field| {
        const production: Parser.CompletionSites.Production = @enumFromInt(field.value);
        _ = Parser.CompletionSites.policy(production);
        _ = parserProductionCapability(production);
    }
    inline for (@typeInfo(Lexer.TokenTag).@"enum".fields) |field| _ = tokenPolicy(@enumFromInt(field.value));
    inline for (@typeInfo(std.meta.Tag(Ast.Expression.Value)).@"enum".fields) |field| {
        _ = expressionCapability(@enumFromInt(field.value));
    }
    inline for (@typeInfo(std.meta.Tag(Ast.Statement)).@"enum".fields) |field| {
        _ = statementCapability(@enumFromInt(field.value));
    }
}

test "registry mutations expose missing rows and missing proofs" {
    try std.testing.expectError(error.MissingCapability, audit(scenarios[1..]));
    var missing_proof = scenarios;
    missing_proof[3].status = .{ .protected = "" };
    try std.testing.expectError(error.MissingProof, audit(&missing_proof));
    var missing_cursor = scenarios;
    missing_cursor[0].partial_source = "public";
    try std.testing.expectError(error.InvalidCursorCount, audit(&missing_cursor));
}
