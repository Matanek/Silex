const std = @import("std");
const Ast = @import("../Ast.zig");
const LexerModule = @import("../Lexer.zig");
const ParserModule = @import("../Parser.zig");
const ExtensionMerger = @import("../Extensions.zig");
const Types = @import("Types.zig");

const Allocator = std.mem.Allocator;
const CompletionItem = Types.CompletionItem;
const Token = LexerModule.Token;
const TokenTag = LexerModule.TokenTag;

const CompletionKind = struct {
    const method: u8 = 2;
    const function: u8 = 3;
    const field: u8 = 5;
    const variable: u8 = 6;
    const class: u8 = 7;
    const interface: u8 = 8;
    const structure: u8 = 22;
    const value: u8 = 12;
    const enum_type: u8 = 13;
    const enum_member: u8 = 20;
    const keyword: u8 = 14;
};

const ContextKind = enum {
    none,
    member,
    type_name,
    use_path,
    module_declaration,
    structure_declaration,
    aggregate_field,
    statement,
    expression,
};

const Context = struct {
    kind: ContextKind,
    prefix: []const u8,
    prefix_start: usize,
    receiver: ?[]const u8 = null,
    nominal_relation: bool = false,
    in_loop: bool = false,
    after_conditional: bool = false,
    allow_conversion: bool = false,
    cascade: bool = false,
    system_callback: bool = false,
    aggregate: ?AggregateContext = null,
};

pub const AggregateContext = struct {
    type_name: []const u8,
    supplied_fields: []const []const u8,
};

const Candidate = struct {
    item: CompletionItem,
    priority: u8,
    callable: bool = false,
};

const ExpectedType = struct {
    name: []const u8,
    strict: bool = false,
    function_type: ?Ast.Type = null,
};

const builtin_types = [_][]const u8{
    "void",    "bool",   "str",
    "int",     "int8",   "int16",
    "int32",   "int64",  "uint",
    "uint8",   "uint16", "uint32",
    "uint64",  "float",  "float32",
    "float64",
};

pub fn itemsAt(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
    trigger_kind: Types.CompletionTriggerKind,
) ![]const CompletionItem {
    _ = trigger_kind;
    if (cursor > source.len or !cursorAllowsCode(source, cursor)) return allocator.alloc(CompletionItem, 0);

    const context = try classifyContext(allocator, source, cursor);
    if (context.kind == .none or context.kind == .use_path) return allocator.alloc(CompletionItem, 0);

    var candidates: std.ArrayList(Candidate) = .empty;
    const completing_try_alternative = try isTryAlternativePositionAt(allocator, source, context.prefix_start);
    const program = try parseForCompletion(allocator, source, cursor, context);
    const expected_type = if (program) |parsed| expectedTypeAt(source, parsed, cursor, context) else null;
    const completing_try_error = try isTryErrorBindingPositionAt(allocator, source, context.prefix_start);

    if (completing_try_error) {
        const error_type: ?[]const u8 = if (program) |parsed|
            try tryErrorTypeAt(allocator, source, parsed, context.prefix_start)
        else
            null;
        try appendCandidate(allocator, &candidates, context, .{
            .label = "error",
            .kind = CompletionKind.variable,
            .detail = if (error_type) |name|
                try std.fmt.allocPrint(allocator, "error:{s}", .{name})
            else
                "Silex implicit error binding",
            .insertText = "error {$0}",
            .insertTextFormat = 2,
        }, 0, false);
        try appendCandidate(allocator, &candidates, context, .{
            .label = "{}",
            // This is a language construct whose insertion uses snippet syntax. Reporting
            // CompletionItemKind.Snippet would let editors hide it with user snippets.
            .kind = CompletionKind.keyword,
            .detail = "Silex fallback block",
            .insertText = "{$0}",
            .insertTextFormat = 2,
        }, 1, false);
    }

    const contextual_try_alternative = completing_try_alternative and program != null;
    if (contextual_try_alternative) {
        try appendCandidate(allocator, &candidates, context, .{
            .label = "else",
            // Keep the semantic kind independent from InsertTextFormat.Snippet: Zed may
            // disable user snippets while language keywords must remain available.
            .kind = CompletionKind.keyword,
            .detail = "Silex fallback branch",
            .insertText = "else {$0}",
            .insertTextFormat = 2,
        }, 0, false);
        try appendCandidate(allocator, &candidates, context, .{
            .label = "else error",
            .kind = CompletionKind.keyword,
            .detail = "Silex fallback branch with implicit error binding",
            .insertText = "else error {$0}",
            .insertTextFormat = 2,
        }, 1, false);
    }

    if (!contextual_try_alternative and !completing_try_error) switch (context.kind) {
        .member => if (program) |parsed| try appendMembers(
            allocator,
            &candidates,
            source,
            parsed,
            cursor,
            context,
        ),
        .type_name => {
            try appendCandidate(allocator, &candidates, context, .{
                .label = "Result",
                .kind = CompletionKind.enum_type,
                .detail = "Silex intrinsic result type",
            }, 7, false);
            for (builtin_types) |name| try appendCandidate(allocator, &candidates, context, .{
                .label = name,
                .kind = CompletionKind.keyword,
                .detail = "Silex fundamental type",
            }, 10, false);
            if (program) |parsed| for (parsed.structures) |structure| {
                if (structure.is_tuple) continue;
                try appendCandidate(
                    allocator,
                    &candidates,
                    context,
                    .{
                        .label = structure.name,
                        .kind = structureCompletionKind(structure),
                        .detail = structureDetail(structure),
                    },
                    8,
                    false,
                );
            };
            if (program) |parsed| for (parsed.enums) |enumeration| try appendCandidate(
                allocator,
                &candidates,
                context,
                .{
                    .label = enumeration.name,
                    .kind = CompletionKind.enum_type,
                    .detail = "Silex enum",
                },
                8,
                false,
            );
            if (program) |parsed| for (parsed.uses) |use| {
                if (use.type_target == null or use.alias == null) continue;
                try appendCandidate(allocator, &candidates, context, .{
                    .label = use.alias.?,
                    .kind = CompletionKind.structure,
                    .detail = try std.fmt.allocPrint(allocator, "type {s} = {s}", .{
                        use.alias.?,
                        use.type_target.?.name(),
                    }),
                }, 8, false);
            };
        },
        .module_declaration => try appendKeywords(allocator, &candidates, context, &.{
            .{ "use", "Silex module import" },
            .{ "public", "Silex visibility" },
            .{ "internal", "Silex package visibility" },
            .{ "local", "Silex file visibility" },
            .{ "struct", "Silex value type declaration" },
            .{ "class", "Silex reference type declaration" },
            .{ "static", "Silex static class declaration" },
            .{ "protocol", "Silex nominal contract declaration" },
            .{ "enum", "Silex enumeration declaration" },
            .{ "func", "Silex function declaration" },
            .{ "test", "Silex source-local test" },
            .{ "extend", "Silex type extension" },
        }, 70),
        .structure_declaration => try appendKeywords(allocator, &candidates, context, &.{
            .{ "public", "Silex visibility" },
            .{ "internal", "Silex package visibility" },
            .{ "local", "Silex file visibility" },
            .{ "private", "Silex type visibility" },
            .{ "let", "Silex immutable field" },
            .{ "var", "Silex mutable field" },
            .{ "init", "Silex value constructor" },
            .{ "func", "Silex method declaration" },
            .{ "static", "Silex static member" },
            .{ "struct", "Silex nested value type" },
            .{ "class", "Silex nested reference type" },
            .{ "drop", "Silex deterministic destruction" },
        }, 70),
        .aggregate_field => if (program) |parsed| {
            const aggregate = context.aggregate.?;
            var native_initializer = false;
            for (parsed.structures) |structure| {
                if (!std.mem.eql(u8, structure.name, aggregate.type_name) or structure.constructors.len != 0) continue;
                native_initializer = true;
                for (structure.fields) |field| {
                    if (field.is_local or field.is_private or field.is_protected or
                        suppliedAggregateField(aggregate, field.name)) continue;
                    try appendCandidate(allocator, &candidates, context, .{
                        .label = field.name,
                        .kind = CompletionKind.field,
                        .detail = try std.fmt.allocPrint(allocator, "{s}:{s}", .{
                            field.name,
                            typeName(parsed, field.type),
                        }),
                    }, 0, false);
                }
                break;
            }
            if (!native_initializer) {
                var expression_context = context;
                expression_context.kind = .expression;
                const expression_expected = expectedTypeAt(source, parsed, cursor, expression_context);
                try appendExpressionSymbols(
                    allocator,
                    &candidates,
                    source,
                    parsed,
                    cursor,
                    expression_context,
                    expression_expected,
                );
            }
        },
        .statement, .expression => if (program) |parsed| {
            try appendExpressionSymbols(
                allocator,
                &candidates,
                source,
                parsed,
                cursor,
                context,
                expected_type,
            );
            if (context.kind == .statement) try appendStatementKeywords(allocator, &candidates, context);
            if (context.kind == .expression) try appendKeywords(allocator, &candidates, context, &.{
                .{ "try", "Silex result propagation" },
            }, 50);
            if (context.allow_conversion) try appendKeywords(allocator, &candidates, context, &.{
                .{ "as", "Silex explicit conversion" },
            }, 65);
        } else try appendLexicalSymbols(allocator, &candidates, source, cursor, context),
        else => {},
    };

    std.mem.sort(Candidate, candidates.items, {}, candidateLessThan);
    const result = try allocator.alloc(CompletionItem, candidates.items.len);
    for (candidates.items, 0..) |candidate, index| {
        result[index] = candidate.item;
        result[index].sortText = try std.fmt.allocPrint(allocator, "{d:0>3}-{d:0>6}", .{ candidate.priority, index });
        result[index].filterText = candidate.item.label;
        result[index].insertText = candidate.item.insertText orelse if (candidate.callable)
            try insertTextForAt(allocator, candidate.item, source, cursor)
        else
            candidate.item.label;
        result[index].insertTextFormat = candidate.item.insertTextFormat orelse if (candidate.callable)
            insertTextFormatForAt(candidate.item, source, cursor)
        else
            null;
    }
    const expanded = try expandOptionalCallVariants(allocator, result, source, cursor);
    const unique = deduplicateCallableShapes(expanded);
    disambiguateCallableLabels(unique);
    return unique;
}

pub fn parameterItemsAt(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
) ![]const CompletionItem {
    const call = try activeCallAt(allocator, source, cursor) orelse
        return allocator.alloc(CompletionItem, 0);
    const lookup_source = try sourceForParameterLookup(allocator, source, cursor, call);
    const callables = try itemsAt(allocator, lookup_source, call.callee_end, .invoked);
    return parameterItemsFromCallables(allocator, callables, call);
}

pub fn parameterItemsFromCallables(
    allocator: Allocator,
    callables: []const CompletionItem,
    call: ActiveCall,
) ![]const CompletionItem {
    var result: std.ArrayList(CompletionItem) = .empty;
    for (callables) |item| {
        const name = item.filterText orelse item.label;
        if (!std.mem.eql(u8, name, call.callee_name)) continue;
        const signature = signatureParameters(item.detail, name) orelse continue;
        var start: usize = 0;
        var depth: usize = 0;
        var parameter_index: usize = 0;
        var index: usize = 0;
        while (index <= signature.len) : (index += 1) {
            const at_end = index == signature.len;
            if (!at_end) switch (signature[index]) {
                '(', '[', '<' => depth += 1,
                ')', ']', '>' => depth -|= 1,
                else => {},
            };
            if (!at_end and (signature[index] != ',' or depth != 0)) continue;
            const parameter = std.mem.trim(u8, signature[start..index], " \t\r\n");
            start = index + 1;
            defer parameter_index += 1;
            const colon = std.mem.indexOfScalar(u8, parameter, ':') orelse continue;
            const parameter_name = std.mem.trim(u8, parameter[0..colon], " \t\r\n");
            if (parameter_index < call.positional_count or suppliedParameter(call, parameter_name) or
                !std.mem.startsWith(u8, parameter_name, call.prefix)) continue;
            var duplicate = false;
            for (result.items) |existing| if (std.mem.eql(u8, existing.label, parameter_name)) {
                duplicate = true;
                break;
            };
            if (duplicate) continue;
            try result.append(allocator, .{
                .label = parameter_name,
                .kind = CompletionKind.variable,
                .detail = parameter,
                .sortText = try std.fmt.allocPrint(allocator, "000-{d:0>6}", .{parameter_index}),
                .filterText = parameter_name,
                .insertText = try std.fmt.allocPrint(allocator, "{s}:", .{parameter_name}),
            });
        }
    }
    std.mem.sort(CompletionItem, result.items, {}, parameterItemLessThan);
    return result.toOwnedSlice(allocator);
}

pub const ActiveCall = struct {
    callee_name: []const u8,
    callee_end: usize,
    prefix: []const u8,
    prefix_start: usize,
    positional_count: usize,
    supplied_parameters: []const []const u8,
    named_mode: bool,
};

pub const ActiveArgument = struct {
    callee_name: []const u8,
    callee_end: usize,
    parameter_name: ?[]const u8,
    positional_index: usize,
    value_start: usize,
};

pub fn activeArgumentAt(allocator: Allocator, source: []const u8, cursor: usize) !?ActiveArgument {
    if (cursor > source.len) return null;
    const tokens = try tokensUntil(allocator, source, cursor);
    var openings: std.ArrayList(usize) = .empty;
    for (tokens, 0..) |token, index| switch (token.tag) {
        .left_parenthesis => try openings.append(allocator, index),
        .right_parenthesis => {
            if (openings.items.len != 0) _ = openings.pop();
        },
        else => {},
    };
    const opening_index = if (openings.items.len != 0) openings.items[openings.items.len - 1] else return null;
    if (opening_index == 0 or tokens[opening_index - 1].tag != .identifier) return null;

    var segment_start = opening_index + 1;
    var positional_index: usize = 0;
    var parenthesis_depth: usize = 0;
    var bracket_depth: usize = 0;
    for (tokens[opening_index + 1 ..], opening_index + 1..) |token, index| switch (token.tag) {
        .left_parenthesis => parenthesis_depth += 1,
        .right_parenthesis => parenthesis_depth -|= 1,
        .left_bracket => bracket_depth += 1,
        .right_bracket => bracket_depth -|= 1,
        .comma => if (parenthesis_depth == 0 and bracket_depth == 0) {
            positional_index += 1;
            segment_start = index + 1;
        },
        else => {},
    };

    const current = tokens[segment_start..];
    const named = current.len >= 2 and current[0].tag == .identifier and current[1].tag == .colon;
    const value_token = if (named) @as(usize, 2) else 0;
    const value_start = if (current.len > value_token) current[value_token].start else cursor;
    const callee = tokens[opening_index - 1];
    return .{
        .callee_name = callee.lexeme,
        .callee_end = callee.end,
        .parameter_name = if (named) current[0].lexeme else null,
        .positional_index = positional_index,
        .value_start = value_start,
    };
}

pub fn sourceForArgumentLookup(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
    argument: ActiveArgument,
) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}true{s}", .{
        source[0..argument.value_start],
        source[cursor..],
    });
}

pub fn callablesExpectFunctionArgument(callables: []const CompletionItem, argument: ActiveArgument) bool {
    for (callables) |item| {
        const name = item.filterText orelse item.label;
        if (!std.mem.eql(u8, name, argument.callee_name)) continue;
        const signature = signatureParameters(item.detail, name) orelse continue;
        var start: usize = 0;
        var depth: usize = 0;
        var parameter_index: usize = 0;
        var index: usize = 0;
        while (index <= signature.len) : (index += 1) {
            const at_end = index == signature.len;
            if (!at_end) switch (signature[index]) {
                '(', '[', '<' => depth += 1,
                ')', ']', '>' => depth -|= 1,
                else => {},
            };
            if (!at_end and (signature[index] != ',' or depth != 0)) continue;
            const parameter = std.mem.trim(u8, signature[start..index], " \t\r\n");
            start = index + 1;
            defer parameter_index += 1;
            const colon = std.mem.indexOfScalar(u8, parameter, ':') orelse continue;
            const parameter_name = std.mem.trim(u8, parameter[0..colon], " \t\r\n");
            const selected = if (argument.parameter_name) |expected_name|
                std.mem.eql(u8, parameter_name, expected_name)
            else
                parameter_index == argument.positional_index;
            if (!selected) continue;
            const type_name = std.mem.trim(u8, parameter[colon + 1 ..], " \t\r\n");
            if (std.mem.eql(u8, type_name, "function") or std.mem.startsWith(u8, type_name, "func(")) return true;
        }
    }
    return false;
}

pub fn insertFunctionReferences(allocator: Allocator, items: []const CompletionItem) ![]const CompletionItem {
    const result = try allocator.dupe(CompletionItem, items);
    for (result) |*item| {
        if (item.kind != CompletionKind.function and item.kind != CompletionKind.method) continue;
        item.insertText = item.filterText orelse item.label;
        item.insertTextFormat = null;
    }
    return result;
}

pub fn sourceForParameterLookup(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
    call: ActiveCall,
) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
        source[0..call.prefix_start],
        if (call.named_mode) "__parameter_completion:true" else "__parameter_completion",
        source[cursor..],
    });
}

pub fn activeCallAt(allocator: Allocator, source: []const u8, cursor: usize) !?ActiveCall {
    if (cursor > source.len) return null;
    const tokens = try tokensUntil(allocator, source, cursor);
    var openings: std.ArrayList(usize) = .empty;
    for (tokens, 0..) |token, index| switch (token.tag) {
        .left_parenthesis => try openings.append(allocator, index),
        .right_parenthesis => {
            if (openings.items.len != 0) _ = openings.pop();
        },
        else => {},
    };
    const opening_index = if (openings.items.len != 0) openings.items[openings.items.len - 1] else return null;
    if (opening_index == 0 or tokens[opening_index - 1].tag != .identifier) return null;

    var supplied: std.ArrayList([]const u8) = .empty;
    var segment_start = opening_index + 1;
    var positional_count: usize = 0;
    var saw_named = false;
    var parenthesis_depth: usize = 0;
    var bracket_depth: usize = 0;
    for (tokens[opening_index + 1 ..], opening_index + 1..) |token, index| {
        switch (token.tag) {
            .left_parenthesis => parenthesis_depth += 1,
            .right_parenthesis => parenthesis_depth -|= 1,
            .left_bracket => bracket_depth += 1,
            .right_bracket => bracket_depth -|= 1,
            .comma => if (parenthesis_depth == 0 and bracket_depth == 0) {
                const named = try appendSuppliedParameter(&supplied, allocator, tokens[segment_start..index]);
                saw_named = saw_named or named;
                if (!named and !saw_named and index != segment_start) positional_count += 1;
                segment_start = index + 1;
            },
            else => {},
        }
    }
    const current = tokens[segment_start..];
    if (current.len > 1 or (current.len == 1 and current[0].tag != .identifier)) return null;
    const prefix = if (current.len == 1) current[0].lexeme else "";
    const prefix_start = if (current.len == 1) current[0].start else cursor;
    const callee = tokens[opening_index - 1];
    return .{
        .callee_name = callee.lexeme,
        .callee_end = callee.end,
        .prefix = prefix,
        .prefix_start = prefix_start,
        .positional_count = positional_count,
        .supplied_parameters = try supplied.toOwnedSlice(allocator),
        .named_mode = saw_named,
    };
}

fn appendSuppliedParameter(
    supplied: *std.ArrayList([]const u8),
    allocator: Allocator,
    tokens: []const Token,
) !bool {
    if (tokens.len < 2 or tokens[0].tag != .identifier or tokens[1].tag != .colon) return false;
    try supplied.append(allocator, tokens[0].lexeme);
    return true;
}

fn suppliedParameter(call: ActiveCall, name: []const u8) bool {
    for (call.supplied_parameters) |supplied| if (std.mem.eql(u8, supplied, name)) return true;
    return false;
}

fn signatureParameters(detail: []const u8, name: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, detail, name) or detail.len <= name.len or detail[name.len] != '(') return null;
    var depth: usize = 0;
    for (detail[name.len + 1 ..], name.len + 1..) |character, index| switch (character) {
        '(' => depth += 1,
        ')' => {
            if (depth == 0) return detail[name.len + 1 .. index];
            depth -= 1;
        },
        else => {},
    };
    return null;
}

fn parameterItemLessThan(_: void, left: CompletionItem, right: CompletionItem) bool {
    const order = std.mem.order(u8, left.sortText.?, right.sortText.?);
    if (order != .eq) return order == .lt;
    return std.mem.lessThan(u8, left.label, right.label);
}

pub fn disambiguateCallableLabels(items: []CompletionItem) void {
    for (items) |*item| {
        const filter = item.filterText orelse item.label;
        const display = callableDisplayLabel(item.*, filter) orelse continue;
        var signatures: usize = 0;
        for (items) |other| {
            const other_filter = other.filterText orelse other.label;
            if (!std.mem.eql(u8, filter, other_filter)) continue;
            if (callableDisplayLabel(other, other_filter) != null) signatures += 1;
        }
        if (signatures > 1) item.label = display;
    }
}

fn callableDisplayLabel(item: CompletionItem, filter: []const u8) ?[]const u8 {
    if (item.kind != CompletionKind.method and item.kind != CompletionKind.function and item.kind != CompletionKind.enum_member and
        item.kind != CompletionKind.structure and item.kind != CompletionKind.class) return null;
    if (!std.mem.startsWith(u8, item.detail, filter) or item.detail.len <= filter.len or item.detail[filter.len] != '(') return null;
    const closing = std.mem.lastIndexOf(u8, item.detail, ") ") orelse return null;
    if (closing < filter.len) return null;
    return item.detail[0 .. closing + 1];
}

pub fn insertTextFor(allocator: Allocator, item: CompletionItem) ![]const u8 {
    const signature = callableSignature(item) orelse return item.label;
    if (std.mem.startsWith(u8, signature, "()")) return std.fmt.allocPrint(allocator, "{s}()", .{item.label});
    if (std.mem.indexOfScalar(u8, signature, ':') == null) return std.fmt.allocPrint(allocator, "{s}($0)", .{item.label});
    return parameterCallSnippet(allocator, item.label, signature);
}

pub fn insertTextFormatFor(item: CompletionItem) ?u8 {
    const signature = callableSignature(item) orelse return null;
    return if (std.mem.startsWith(u8, signature, "()")) null else 2;
}

pub fn insertTextForAt(
    allocator: Allocator,
    item: CompletionItem,
    source: []const u8,
    cursor: usize,
) ![]const u8 {
    if (callFollows(source, cursor)) return item.label;
    return insertTextFor(allocator, item);
}

pub fn insertTextFormatForAt(item: CompletionItem, source: []const u8, cursor: usize) ?u8 {
    if (callFollows(source, cursor)) return null;
    return insertTextFormatFor(item);
}

pub fn expandOptionalCallVariants(
    allocator: Allocator,
    items: []const CompletionItem,
    source: []const u8,
    cursor: usize,
) ![]CompletionItem {
    const should_expand = !callFollows(source, cursor);
    var additional: usize = 0;
    if (should_expand) for (items) |item| if (optionalCallLayout(item) != null) {
        additional += 1;
    };
    const result = try allocator.alloc(CompletionItem, items.len + additional);
    var index: usize = 0;
    for (items) |item| {
        if (if (should_expand) optionalCallLayout(item) else null) |layout| {
            const signature = callableSignature(item).?;
            result[index] = item;
            result[index].detail = try std.fmt.allocPrint(allocator, "{s}({s}){s}", .{
                item.label,
                signature[1..layout.required_end],
                signature[layout.closing + 1 ..],
            });
            result[index].insertText = try insertTextFor(allocator, result[index]);
            result[index].insertTextFormat = insertTextFormatFor(result[index]);
            index += 1;
        }
        result[index] = item;
        index += 1;
    }
    return result;
}

const OptionalCallLayout = struct {
    closing: usize,
    required_end: usize,
};

fn optionalCallLayout(item: CompletionItem) ?OptionalCallLayout {
    const signature = callableSignature(item) orelse return null;
    var depth: usize = 0;
    var parameter_start: usize = 1;
    var parameter_has_default = false;
    var saw_optional = false;
    var required_end: usize = 1;
    var previous_segment_end: usize = 1;
    var index: usize = 1;
    while (index < signature.len) : (index += 1) {
        switch (signature[index]) {
            '(', '[', '<' => depth += 1,
            ')', ']', '>' => if (depth != 0) {
                depth -= 1;
            } else {
                if (index == parameter_start) return null;
                if (parameter_has_default) {
                    if (!saw_optional) required_end = previous_segment_end;
                    saw_optional = true;
                } else if (saw_optional) return null;
                return if (saw_optional) .{ .closing = index, .required_end = required_end } else null;
            },
            '=' => {
                if (depth == 0) parameter_has_default = true;
            },
            ',' => if (depth == 0) {
                if (index == parameter_start) return null;
                if (parameter_has_default) {
                    if (!saw_optional) required_end = previous_segment_end;
                    saw_optional = true;
                } else if (saw_optional) return null;
                previous_segment_end = index;
                parameter_start = index + 1;
                parameter_has_default = false;
            },
            else => {},
        }
    }
    return null;
}

pub fn callFollows(source: []const u8, cursor: usize) bool {
    var index = cursor;
    while (index < source.len and isIdentifierContinue(source[index])) index += 1;
    while (index < source.len and (source[index] == ' ' or source[index] == '\t')) index += 1;
    return index < source.len and source[index] == '(';
}

fn callableSignature(item: CompletionItem) ?[]const u8 {
    if (item.kind != CompletionKind.method and item.kind != CompletionKind.function and item.kind != CompletionKind.enum_member and
        item.kind != CompletionKind.structure and item.kind != CompletionKind.class) return null;
    const name = item.filterText orelse item.label;
    if (!std.mem.startsWith(u8, item.detail, name)) return null;
    const signature = item.detail[name.len..];
    return if (std.mem.startsWith(u8, signature, "(")) signature else null;
}

pub fn deduplicateCallableShapes(items: []CompletionItem) []CompletionItem {
    var count: usize = 0;
    for (items) |item| {
        var duplicate = false;
        for (items[0..count]) |existing| if (sameCallableShape(existing, item)) {
            duplicate = true;
            break;
        };
        if (duplicate) continue;
        items[count] = item;
        count += 1;
    }
    return items[0..count];
}

fn sameCallableShape(left: CompletionItem, right: CompletionItem) bool {
    const left_name = left.filterText orelse left.label;
    const right_name = right.filterText orelse right.label;
    if (!std.mem.eql(u8, left_name, right_name)) return false;
    const left_signature = callableSignature(left) orelse return false;
    const right_signature = callableSignature(right) orelse return false;
    var left_cursor: usize = 1;
    var right_cursor: usize = 1;
    while (true) {
        const left_parameter = nextParameterLabel(left_signature, &left_cursor);
        const right_parameter = nextParameterLabel(right_signature, &right_cursor);
        if (left_parameter == null or right_parameter == null) return left_parameter == null and right_parameter == null;
        if (!std.mem.eql(u8, left_parameter.?, right_parameter.?)) return false;
    }
}

fn nextParameterLabel(signature: []const u8, cursor: *usize) ?[]const u8 {
    while (cursor.* < signature.len and std.ascii.isWhitespace(signature[cursor.*])) cursor.* += 1;
    if (cursor.* >= signature.len or signature[cursor.*] == ')') return null;
    const start = cursor.*;
    var colon: ?usize = null;
    var depth: usize = 0;
    while (cursor.* < signature.len) : (cursor.* += 1) switch (signature[cursor.*]) {
        '(', '[', '<' => depth += 1,
        ')', ']', '>' => if (depth != 0) {
            depth -= 1;
        } else {
            const end = colon orelse cursor.*;
            return std.mem.trim(u8, signature[start..end], " \t\r\n");
        },
        ':' => if (depth == 0 and colon == null) {
            colon = cursor.*;
        },
        ',' => if (depth == 0) {
            const end = colon orelse cursor.*;
            cursor.* += 1;
            return std.mem.trim(u8, signature[start..end], " \t\r\n");
        },
        else => {},
    };
    return null;
}

fn parameterCallSnippet(allocator: Allocator, label: []const u8, signature: []const u8) ![]const u8 {
    var result: []const u8 = try std.fmt.allocPrint(allocator, "{s}(", .{label});
    var start: usize = 1;
    var depth: usize = 0;
    var placeholder: usize = 1;
    var index: usize = 1;
    while (index < signature.len) : (index += 1) {
        const character = signature[index];
        switch (character) {
            '(', '[', '<' => depth += 1,
            ')', ']', '>' => if (depth != 0) {
                depth -= 1;
            } else {
                if (index > start) result = try appendParameterPlaceholder(allocator, result, signature[start..index], placeholder);
                return std.fmt.allocPrint(allocator, "{s})$0", .{result});
            },
            ',' => if (depth == 0) {
                result = try appendParameterPlaceholder(allocator, result, signature[start..index], placeholder);
                placeholder += 1;
                start = index + 1;
            },
            else => {},
        }
    }
    return std.fmt.allocPrint(allocator, "{s}$0)", .{result});
}

fn appendParameterPlaceholder(allocator: Allocator, prefix: []const u8, parameter_text: []const u8, placeholder: usize) ![]const u8 {
    const parameter = std.mem.trim(u8, parameter_text, " \t\r\n");
    const colon = std.mem.indexOfScalar(u8, parameter, ':') orelse return prefix;
    const name = std.mem.trim(u8, parameter[0..colon], " \t\r\n");
    return std.fmt.allocPrint(allocator, "{s}{s}${{{d}:{s}}}", .{
        prefix,
        if (placeholder == 1) "" else ", ",
        placeholder,
        name,
    });
}

fn classifyContext(allocator: Allocator, source: []const u8, cursor: usize) !Context {
    const prefix_start = identifierPrefixStart(source, cursor);
    const prefix = source[prefix_start..cursor];
    const tokens = try tokensUntil(allocator, source, prefix_start);
    if (tokens.len == 0) return .{ .kind = .module_declaration, .prefix = prefix, .prefix_start = prefix_start };

    const scope = scopeAt(tokens);
    const current_line = lineAtOffset(source, prefix_start);
    const line_start = currentLineTokenStart(tokens, current_line);
    const line_tokens = tokens[line_start..];

    if (isUsePath(line_tokens)) return .{
        .kind = .use_path,
        .prefix = prefix,
        .prefix_start = prefix_start,
    };

    if (tokens[tokens.len - 1].tag == .dot or tokens[tokens.len - 1].tag == .question_dot or
        tokens[tokens.len - 1].tag == .dot_dot) return .{
        .kind = .member,
        .prefix = prefix,
        .prefix_start = prefix_start,
        .receiver = if (tokens[tokens.len - 1].tag == .dot_dot)
            cascadeReceiver(source, tokens[tokens.len - 1].start)
        else
            memberReceiver(source, tokens[tokens.len - 1].start),
        .in_loop = scope.in_loop,
        .cascade = tokens[tokens.len - 1].tag == .dot_dot,
        .system_callback = insideSystemRegistration(tokens),
    };

    const nominal_relation = isNominalRelationPosition(line_tokens);
    if (isTypePosition(tokens, line_tokens, scope.pending_callable, nominal_relation) or
        isTypeArgumentPrefix(source, prefix_start)) return .{
        .kind = .type_name,
        .prefix = prefix,
        .prefix_start = prefix_start,
        .nominal_relation = nominal_relation,
        .in_loop = scope.in_loop,
    };

    if (scope.interpolation_depth != 0) return .{
        .kind = .expression,
        .prefix = prefix,
        .prefix_start = prefix_start,
        .in_loop = scope.in_loop,
        .allow_conversion = expressionCanConvert(line_tokens),
    };

    if (try aggregateContextAt(allocator, source, cursor)) |aggregate| return .{
        .kind = .aggregate_field,
        .prefix = prefix,
        .prefix_start = prefix_start,
        .aggregate = aggregate,
        .in_loop = scope.in_loop,
    };

    if (scope.in_callable) {
        const expression = lineIsExpression(line_tokens);
        return .{
            .kind = if (expression) .expression else .statement,
            .prefix = prefix,
            .prefix_start = prefix_start,
            .in_loop = scope.in_loop,
            .after_conditional = !expression and followsConditional(tokens),
            .allow_conversion = expression and expressionCanConvert(line_tokens),
        };
    }
    return .{
        .kind = if (scope.in_structure) .structure_declaration else .module_declaration,
        .prefix = prefix,
        .prefix_start = prefix_start,
    };
}

pub fn isTypePositionAt(allocator: Allocator, source: []const u8, prefix_start: usize) !bool {
    const tokens = try tokensUntil(allocator, source, prefix_start);
    if (tokens.len == 0) return false;
    if (tokens[tokens.len - 1].tag == .keyword_extend) return true;
    const current_line = lineAtOffset(source, prefix_start);
    const line_start = currentLineTokenStart(tokens, current_line);
    const line_tokens = tokens[line_start..];
    const scope = scopeAt(tokens);
    return isTypePosition(
        tokens,
        line_tokens,
        scope.pending_callable,
        isNominalRelationPosition(line_tokens),
    ) or isTypeArgumentPrefix(source, prefix_start);
}

pub fn isQualifiedTypePositionAt(
    allocator: Allocator,
    source: []const u8,
    prefix_start: usize,
) !bool {
    var start = prefix_start;
    while (start != 0) {
        const character = source[start - 1];
        if (!std.ascii.isAlphanumeric(character) and character != '_' and character != '.') break;
        start -= 1;
    }
    return isTypePositionAt(allocator, source, start);
}

pub fn isReturnExpressionAt(allocator: Allocator, source: []const u8, cursor: usize) !bool {
    if (cursor > source.len) return false;
    const context = try classifyContext(allocator, source, cursor);
    if (context.kind != .expression and context.kind != .aggregate_field and context.kind != .member) return false;
    const tokens = try tokensUntil(allocator, source, context.prefix_start);
    if (tokens.len == 0) return false;
    const current_line = lineAtOffset(source, context.prefix_start);
    const line_start = currentLineTokenStart(tokens, current_line);
    const line_tokens = tokens[line_start..];
    return line_tokens.len != 0 and line_tokens[0].tag == .keyword_return;
}

fn followsConditional(tokens: []const Token) bool {
    if (tokens.len == 0 or tokens[tokens.len - 1].tag != .right_brace) return false;
    var depth: usize = 0;
    var index = tokens.len;
    while (index != 0) {
        index -= 1;
        switch (tokens[index].tag) {
            .right_brace => depth += 1,
            .left_brace => {
                depth -|= 1;
                if (depth != 0) continue;
                var owner = index;
                while (owner != 0) {
                    owner -= 1;
                    switch (tokens[owner].tag) {
                        .keyword_if, .keyword_elif => return true,
                        .keyword_while, .left_brace, .right_brace, .semicolon => return false,
                        else => {},
                    }
                }
                return false;
            },
            else => {},
        }
    }
    return false;
}

const Scope = struct {
    in_callable: bool = false,
    in_structure: bool = false,
    in_loop: bool = false,
    interpolation_depth: usize = 0,
    pending_callable: bool = false,
};

fn scopeAt(tokens: []const Token) Scope {
    const Block = enum { plain, structure, callable, loop };
    var blocks: [128]Block = undefined;
    var count: usize = 0;
    var pending: Block = .plain;
    var pending_callable = false;
    var interpolation_depth: usize = 0;
    for (tokens) |token| {
        if (count == 0 and token.tag == .identifier and std.mem.eql(u8, token.lexeme, "test")) {
            pending = .callable;
            pending_callable = true;
            continue;
        }
        switch (token.tag) {
            .keyword_struct, .keyword_extend => pending = .structure,
            .keyword_func, .keyword_init => {
                pending = .callable;
                pending_callable = true;
            },
            .keyword_while, .keyword_for => pending = .loop,
            .left_brace => {
                if (count < blocks.len) {
                    blocks[count] = pending;
                    count += 1;
                }
                if (pending == .callable) pending_callable = false;
                pending = .plain;
            },
            .right_brace => if (count != 0) {
                count -= 1;
            },
            .interpolation_start => interpolation_depth += 1,
            .interpolation_end => interpolation_depth -|= 1,
            else => {},
        }
    }
    var result: Scope = .{ .interpolation_depth = interpolation_depth, .pending_callable = pending_callable };
    for (blocks[0..count]) |block| switch (block) {
        .structure => result.in_structure = true,
        .callable => result.in_callable = true,
        .loop => {
            result.in_callable = true;
            result.in_loop = true;
        },
        .plain => {},
    };
    return result;
}

fn isUsePath(line_tokens: []const Token) bool {
    for (line_tokens) |token| {
        if (token.tag == .keyword_use) return true;
        if (token.tag != .keyword_public) return false;
    }
    return false;
}

fn isTypePosition(
    tokens: []const Token,
    line_tokens: []const Token,
    pending_callable: bool,
    nominal_relation: bool,
) bool {
    if (tokens.len == 0) return false;
    const previous = tokens[tokens.len - 1].tag;
    if (previous == .keyword_as) return true;
    if (nominal_relation and (previous == .colon or previous == .comma)) return true;
    if (previous == .colon) {
        const parenthesis = lastUnclosedParenthesis(tokens);
        if (parenthesis) |index| {
            if (index == 0) return false;
            if (tokens[index - 1].tag == .keyword_init) return true;
            if (tokens[index - 1].tag == .keyword_func) return true;
            if (tokens[index - 1].tag != .identifier) return false;
            if (index >= 2 and tokens[index - 2].tag == .keyword_func) return true;
            return false;
        }
        for (line_tokens) |token| if (token.tag == .keyword_let or token.tag == .keyword_var) return true;
        return false;
    }
    if (!pending_callable or previous != .right_parenthesis) return false;
    return true;
}

fn isNominalRelationPosition(line_tokens: []const Token) bool {
    var declaration = false;
    for (line_tokens) |token| switch (token.tag) {
        .keyword_struct, .keyword_class, .keyword_extend => declaration = true,
        .colon => if (declaration) return true,
        else => {},
    };
    return false;
}

fn lastUnclosedParenthesis(tokens: []const Token) ?usize {
    var depth: usize = 0;
    var index = tokens.len;
    while (index != 0) {
        index -= 1;
        switch (tokens[index].tag) {
            .right_parenthesis => depth += 1,
            .left_parenthesis => {
                if (depth == 0) return index;
                depth -= 1;
            },
            else => {},
        }
    }
    return null;
}

fn lineIsExpression(tokens: []const Token) bool {
    if (tokens.len == 0) return false;
    const first = tokens[0].tag;
    if (first == .keyword_let or first == .keyword_var) {
        for (tokens) |token| if (token.tag == .equal) return true;
        return false;
    }
    return switch (first) {
        .keyword_return, .keyword_if, .keyword_while, .keyword_for => true,
        .keyword_print, .keyword_assert, .keyword_panic => true,
        .identifier, .keyword_self, .integer, .floating, .keyword_true, .keyword_false, .string, .string_start => true,
        else => false,
    };
}

fn expressionCanConvert(tokens: []const Token) bool {
    if (tokens.len == 0) return false;
    return switch (tokens[tokens.len - 1].tag) {
        .identifier, .keyword_self, .integer, .floating, .keyword_true, .keyword_false, .string, .string_end, .right_parenthesis => true,
        else => false,
    };
}

pub fn callAcceptsParameters(
    source: []const u8,
    cursor: usize,
    program: Ast.Program,
    parameters: []const Ast.Parameter,
) bool {
    var name_end = cursor;
    while (name_end < source.len and isIdentifierContinue(source[name_end])) name_end += 1;
    while (name_end < source.len and std.ascii.isWhitespace(source[name_end])) name_end += 1;
    if (name_end >= source.len or source[name_end] != '(') return true;

    var lexer = LexerModule.Lexer.init(source[name_end..]);
    const opening = lexer.next() catch return true;
    if (opening.tag != .left_parenthesis) return true;
    var depth: usize = 1;
    var argument_index: usize = 0;
    var has_argument = false;
    var has_token = false;
    var incomplete = false;
    while (true) {
        const token = lexer.next() catch return true;
        if (token.tag == .end) return true;
        switch (token.tag) {
            .left_parenthesis, .left_bracket => {
                if (depth == 1 and !has_token) {
                    has_argument = true;
                    has_token = true;
                }
                depth += 1;
            },
            .right_parenthesis => {
                if (depth == 1) {
                    const arity = if (has_argument) argument_index + 1 else 0;
                    return if (incomplete) arity <= parameters.len else acceptsArity(parameters, arity);
                }
                depth -|= 1;
            },
            .right_bracket => depth -|= 1,
            .comma => if (depth == 1) {
                argument_index += 1;
                has_token = false;
            },
            else => if (depth == 1 and !has_token) {
                has_argument = true;
                has_token = true;
                incomplete = token.tag == .identifier and
                    std.mem.eql(u8, token.lexeme, "__parameter_completion");
                if (argument_index >= parameters.len or
                    !literalAcceptsType(token.tag, parameters[argument_index].type, program)) return false;
            },
        }
    }
}

fn acceptsArity(parameters: []const Ast.Parameter, arity: usize) bool {
    var required = parameters.len;
    for (parameters, 0..) |parameter, index| if (parameter.default != null) {
        required = index;
        break;
    };
    return arity >= required and arity <= parameters.len;
}

fn literalAcceptsType(tag: TokenTag, expected: Ast.Type, program: Ast.Program) bool {
    _ = program;
    return switch (tag) {
        .keyword_true, .keyword_false => expected == .bool,
        .string, .string_start => expected == .str,
        .integer, .floating => expected.isNumeric(),
        else => true,
    };
}

fn appendMembers(
    allocator: Allocator,
    candidates: *std.ArrayList(Candidate),
    source: []const u8,
    program: Ast.Program,
    cursor: usize,
    context: Context,
) !void {
    const receiver = context.receiver orelse return;
    const trimmed_receiver = std.mem.trim(u8, receiver, " \t\r\n");
    if (try appendIntrinsicResultMembers(allocator, candidates, context, trimmed_receiver)) return;
    if (findEnum(program, trimmed_receiver)) |enumeration| {
        for (enumeration.variants) |variant| try appendCandidate(allocator, candidates, context, .{
            .label = variant.name,
            .kind = CompletionKind.enum_member,
            .detail = try variantSignature(allocator, program, enumeration, variant),
        }, 0, variant.associated_types.len != 0);
        return;
    }
    const type_name = resolveReceiverType(allocator, source, program, cursor, receiver) orelse return;
    if (std.mem.eql(u8, type_name, "str")) {
        try appendCandidate(allocator, candidates, context, .{
            .label = "count",
            .kind = CompletionKind.field,
            .detail = "count:int",
        }, 0, false);
        return;
    }
    const structure = findStructure(program, nominalReceiverName(type_name)) orelse return;
    if (structure.collection) |collection| {
        try appendCollectionMembers(allocator, candidates, source, cursor, context, collection);
        return;
    }
    if (structure.is_tuple and !structure.tuple_named) return;
    if (std.mem.eql(u8, std.mem.trim(u8, receiver, " \t\r\n"), structure.name)) {
        for (program.structures) |nested| {
            const enclosing = nested.enclosing orelse continue;
            if (!std.mem.eql(u8, enclosing, structure.name)) continue;
            const label = if (std.mem.lastIndexOfScalar(u8, nested.name, '.')) |dot| nested.name[dot + 1 ..] else nested.name;
            try appendCandidate(allocator, candidates, context, .{
                .label = label,
                .kind = structureCompletionKind(nested),
                .detail = try std.fmt.allocPrint(allocator, "nested type {s}", .{nested.name}),
            }, 0, true);
        }
        for (structure.static_fields) |field| try appendCandidate(allocator, candidates, context, .{
            .label = field.name,
            .kind = CompletionKind.field,
            .detail = try std.fmt.allocPrint(allocator, "static {s}:{s}", .{ field.name, typeName(program, field.type) }),
        }, 0, false);
        for (structure.methods) |method| {
            if ((!method.is_static and !context.system_callback) or
                !callAcceptsParameters(source, cursor, program, method.parameters)) continue;
            try appendCandidate(allocator, candidates, context, .{
                .label = method.name,
                .kind = CompletionKind.method,
                .detail = try functionSignature(allocator, source, program, method),
            }, 0, true);
        }
        return;
    }
    for (structure.fields) |field| try appendCandidate(allocator, candidates, context, .{
        .label = field.name,
        .kind = CompletionKind.field,
        .detail = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ field.name, typeName(program, field.type) }),
    }, 0, false);
    for (structure.methods) |method| {
        if (!callAcceptsParameters(source, cursor, program, method.parameters)) continue;
        try appendCandidate(allocator, candidates, context, .{
            .label = method.name,
            .kind = CompletionKind.method,
            .detail = try functionSignature(allocator, source, program, method),
        }, 0, true);
    }
}

fn insideSystemRegistration(tokens: []const Token) bool {
    var depth: usize = 0;
    var index = tokens.len;
    while (index > 0) {
        index -= 1;
        switch (tokens[index].tag) {
            .right_parenthesis => depth += 1,
            .left_parenthesis => if (depth != 0) {
                depth -= 1;
            } else {
                if (index == 0 or tokens[index - 1].tag != .identifier) return false;
                const name = tokens[index - 1].lexeme;
                return std.mem.eql(u8, name, "add_system") or std.mem.eql(u8, name, "add_after_system");
            },
            else => {},
        }
    }
    return false;
}

const ResultArguments = struct {
    success: []const u8,
    failure: []const u8,
};

fn appendIntrinsicResultMembers(
    allocator: Allocator,
    candidates: *std.ArrayList(Candidate),
    context: Context,
    receiver: []const u8,
) !bool {
    const arguments = resultArguments(receiver) orelse return false;
    const success_void = std.mem.eql(u8, arguments.success, "void");
    try appendCandidate(allocator, candidates, context, .{
        .label = "success",
        .kind = CompletionKind.enum_member,
        .detail = if (success_void)
            try std.fmt.allocPrint(allocator, "success() {s}", .{receiver})
        else
            try std.fmt.allocPrint(allocator, "success({s}) {s}", .{ arguments.success, receiver }),
    }, 0, true);
    try appendCandidate(allocator, candidates, context, .{
        .label = "failure",
        .kind = CompletionKind.enum_member,
        .detail = if (std.mem.eql(u8, arguments.failure, "void"))
            try std.fmt.allocPrint(allocator, "failure() {s}", .{receiver})
        else
            try std.fmt.allocPrint(allocator, "failure({s}) {s}", .{ arguments.failure, receiver }),
    }, 0, true);
    return true;
}

fn resultArguments(receiver: []const u8) ?ResultArguments {
    if (!std.mem.startsWith(u8, receiver, "Result<") or receiver.len <= "Result<>".len or
        receiver[receiver.len - 1] != '>') return null;
    const arguments = receiver["Result<".len .. receiver.len - 1];
    var depth: usize = 0;
    for (arguments, 0..) |character, index| switch (character) {
        '<', '(', '[' => depth += 1,
        '>', ')', ']' => depth -|= 1,
        ',' => if (depth == 0) {
            const success = std.mem.trim(u8, arguments[0..index], " \t\r\n");
            const failure = std.mem.trim(u8, arguments[index + 1 ..], " \t\r\n");
            if (success.len == 0 or failure.len == 0) return null;
            return .{ .success = success, .failure = failure };
        },
        else => {},
    };
    return null;
}

fn appendCollectionMembers(
    allocator: Allocator,
    candidates: *std.ArrayList(Candidate),
    source: []const u8,
    cursor: usize,
    context: Context,
    collection: Ast.Collection,
) !void {
    try appendCandidate(allocator, candidates, context, .{
        .label = "count",
        .kind = CompletionKind.method,
        .detail = "count() int",
    }, 0, true);
    try appendCandidate(allocator, candidates, context, .{
        .label = "is_empty",
        .kind = CompletionKind.method,
        .detail = "is_empty() bool",
    }, 0, true);
    if (!collection.view) {
        const mutations = [_]struct { label: []const u8, detail: []const u8 }{
            .{ .label = "append", .detail = "append(value)" },
            .{ .label = "prepend", .detail = "prepend(value)" },
            .{ .label = "insert", .detail = "insert(index, value)" },
            .{ .label = "replace", .detail = "replace(index, value)" },
            .{ .label = "clear", .detail = "clear()" },
        };
        for (mutations) |mutation| try appendCandidate(allocator, candidates, context, .{
            .label = mutation.label,
            .kind = CompletionKind.method,
            .detail = mutation.detail,
        }, 0, true);
    }
    const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..cursor], '\n')) |newline| newline + 1 else 0;
    if (!collection.view and isForSourceLine(source[line_start..cursor])) try appendCandidate(allocator, candidates, context, .{
        .label = "indexed",
        .kind = CompletionKind.method,
        .detail = "indexed() indexed collection traversal",
    }, 0, true);
}

fn appendExpressionSymbols(
    allocator: Allocator,
    candidates: *std.ArrayList(Candidate),
    source: []const u8,
    program: Ast.Program,
    cursor: usize,
    context: Context,
    expected_type: ?ExpectedType,
) !void {
    try appendEmbeddedFileIntrinsics(allocator, candidates, context, expected_type);
    if (matchesExpectedType(expected_type, "Result")) try appendCandidate(
        allocator,
        candidates,
        context,
        .{
            .label = "Result",
            .kind = CompletionKind.enum_type,
            .detail = "Silex intrinsic result type",
        },
        typedPriority(5, expected_type, "Result"),
        false,
    );
    const callable = containingCallable(source, program, cursor);
    if (callable) |current| {
        const lexical_callables = try containingCallables(allocator, source, program, cursor);
        const lexical_start = if (lexical_callables.len == 0) current.position else lexical_callables[0].position;
        const locals = try visibleLocals(allocator, source, program, lexical_start, cursor);
        var index = locals.len;
        while (index != 0) {
            index -= 1;
            const local = locals[index];
            if (!matchesExpectedType(expected_type, local.type_name)) continue;
            try appendCandidate(allocator, candidates, context, .{
                .label = local.name,
                .kind = CompletionKind.variable,
                .detail = if (local.type_name) |name|
                    try std.fmt.allocPrint(allocator, "{s}:{s}", .{ local.name, name })
                else
                    "Silex local binding",
            }, typedPriority(10, expected_type, local.type_name), false);
        }
        for (lexical_callables) |scope| for (scope.parameters) |parameter| {
            const parameter_type = typeName(program, parameter.type);
            if (!matchesExpectedType(expected_type, parameter_type)) continue;
            try appendCandidate(allocator, candidates, context, .{
                .label = parameter.name,
                .kind = CompletionKind.variable,
                .detail = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ parameter.name, parameter_type }),
            }, typedPriority(12, expected_type, parameter_type), false);
        };
        if (current.structure_name) |name| if (matchesExpectedType(expected_type, name)) try appendCandidate(
            allocator,
            candidates,
            context,
            .{
                .label = "self",
                .kind = CompletionKind.variable,
                .detail = try std.fmt.allocPrint(allocator, "self:{s}", .{name}),
            },
            typedPriority(14, expected_type, name),
            false,
        );
    }

    for (program.functions) |function| {
        if (function.is_anonymous or std.mem.eql(u8, function.name, "main")) continue;
        if (function.is_test) {
            if (function.is_test_entry) continue;
            const current = callable orelse continue;
            const owner = function.test_owner orelse continue;
            if (current.test_owner == null or !std.mem.eql(u8, current.test_owner.?, owner)) continue;
        }
        if (!callAcceptsParameters(source, cursor, program, function.parameters)) continue;
        const return_type = typeName(program, function.return_type);
        const passed_as_value = if (expected_type) |expected|
            if (expected.function_type) |function_type|
                functionMatchesType(program, function, function_type)
            else
                false
        else
            false;
        if (!passed_as_value and !matchesExpectedType(expected_type, return_type)) continue;
        var displayed = function;
        displayed.name = function.test_source_name orelse function.name;
        try appendCandidate(allocator, candidates, context, .{
            .label = displayed.name,
            .kind = CompletionKind.function,
            .detail = try functionSignature(allocator, source, program, displayed),
        }, typedPriority(25, expected_type, if (passed_as_value) "function" else return_type), !passed_as_value);
    }
    for (program.structures) |structure| {
        if (structure.is_protocol or structure.is_tuple) continue;
        if (!matchesExpectedType(expected_type, structure.name)) continue;
        if (structure.constructors.len == 0) {
            try appendCandidate(allocator, candidates, context, .{
                .label = structure.name,
                .kind = structureCompletionKind(structure),
                .detail = try std.fmt.allocPrint(allocator, "{s}() {s}", .{ structure.name, structure.name }),
            }, typedPriority(30, expected_type, structure.name), true);
        } else for (structure.constructors) |constructor| {
            if (!callAcceptsParameters(source, cursor, program, constructor.parameters)) continue;
            try appendCandidate(allocator, candidates, context, .{
                .label = structure.name,
                .kind = structureCompletionKind(structure),
                .detail = try constructorSignature(allocator, source, program, structure.name, constructor),
            }, typedPriority(30, expected_type, structure.name), true);
        }
    }
    if (matchesExpectedType(expected_type, "bool")) {
        try appendCandidate(allocator, candidates, context, .{
            .label = "true",
            .kind = CompletionKind.value,
            .detail = "true:bool",
        }, typedPriority(55, expected_type, "bool"), false);
        try appendCandidate(allocator, candidates, context, .{
            .label = "false",
            .kind = CompletionKind.value,
            .detail = "false:bool",
        }, typedPriority(55, expected_type, "bool"), false);
    }
}

fn appendEmbeddedFileIntrinsics(
    allocator: Allocator,
    candidates: *std.ArrayList(Candidate),
    context: Context,
    expected_type: ?ExpectedType,
) !void {
    if (matchesExpectedType(expected_type, "str")) try appendCandidate(allocator, candidates, context, .{
        .label = "embed_text",
        .kind = CompletionKind.function,
        .detail = "embed_text(file:str) str",
    }, typedPriority(18, expected_type, "str"), true);
    if (matchesExpectedType(expected_type, "uint8[]")) try appendCandidate(allocator, candidates, context, .{
        .label = "embed_bytes",
        .kind = CompletionKind.function,
        .detail = "embed_bytes(file:str) uint8[]",
    }, typedPriority(18, expected_type, "uint8[]"), true);
}

fn appendStatementKeywords(allocator: Allocator, candidates: *std.ArrayList(Candidate), context: Context) !void {
    try appendKeywords(allocator, candidates, context, &.{
        .{ "let", "Silex immutable binding" },
        .{ "var", "Silex mutable binding" },
        .{ "if", "Silex conditional" },
        .{ "while", "Silex loop" },
        .{ "mutex", "Silex critical section" },
        .{ "return", "Silex return statement" },
        .{ "print", "Silex observable effect" },
        .{ "assert", "Silex assertion" },
        .{ "panic", "Silex failure effect" },
    }, 70);
    if (context.in_loop) try appendKeywords(allocator, candidates, context, &.{
        .{ "break", "Silex loop exit" },
        .{ "continue", "Silex loop continuation" },
    }, 68);
    if (context.after_conditional) try appendKeywords(allocator, candidates, context, &.{
        .{ "elif", "Silex conditional branch" },
        .{ "else", "Silex fallback branch" },
    }, 68);
}

fn appendKeywords(
    allocator: Allocator,
    candidates: *std.ArrayList(Candidate),
    context: Context,
    keywords: []const struct { []const u8, []const u8 },
    priority: u8,
) !void {
    for (keywords) |keyword| try appendCandidate(allocator, candidates, context, .{
        .label = keyword[0],
        .kind = CompletionKind.keyword,
        .detail = keyword[1],
    }, priority, false);
}

fn appendLexicalSymbols(
    allocator: Allocator,
    candidates: *std.ArrayList(Candidate),
    source: []const u8,
    cursor: usize,
    context: Context,
) !void {
    const tokens = try tokensUntil(allocator, source, cursor);
    const LocalSymbol = struct { name: []const u8, depth: usize };
    var locals: std.ArrayList(LocalSymbol) = .empty;
    var depth: usize = 0;
    for (tokens, 0..) |token, index| {
        if (token.tag == .left_brace) {
            depth += 1;
            continue;
        }
        if (token.tag == .right_brace) {
            var local_index = locals.items.len;
            while (local_index != 0) {
                local_index -= 1;
                if (locals.items[local_index].depth >= depth) _ = locals.orderedRemove(local_index);
            }
            depth -|= 1;
            continue;
        }
        if (token.tag != .identifier or index == 0) continue;
        const previous = tokens[index - 1].tag;
        if (previous == .keyword_let or previous == .keyword_var) try locals.append(allocator, .{ .name = token.lexeme, .depth = depth });
        if (previous == .keyword_func) try appendCandidate(allocator, candidates, context, .{
            .label = token.lexeme,
            .kind = CompletionKind.function,
            .detail = "Silex function",
        }, 25, true);
    }
    for (locals.items) |local| try appendCandidate(allocator, candidates, context, .{
        .label = local.name,
        .kind = CompletionKind.variable,
        .detail = "Silex local binding",
    }, 10, false);
    if (context.kind == .statement) try appendStatementKeywords(allocator, candidates, context);
}

fn appendCandidate(
    allocator: Allocator,
    candidates: *std.ArrayList(Candidate),
    context: Context,
    item: CompletionItem,
    priority: u8,
    callable: bool,
) !void {
    if (isReservedCompilerName(item.label)) return;
    const prefix_match = std.mem.startsWith(u8, item.label, context.prefix);
    const matches = prefix_match or
        (item.kind != CompletionKind.keyword and item.kind != CompletionKind.value and
            std.mem.indexOf(u8, item.label, context.prefix) != null);
    if (!matches) return;
    const ranked_priority = if (prefix_match) priority else priority +| 80;
    for (candidates.items, 0..) |existing, index| {
        if (!std.mem.eql(u8, existing.item.label, item.label)) continue;
        if (callable and existing.callable and !std.mem.eql(u8, existing.item.detail, item.detail)) continue;
        if (ranked_priority < existing.priority) candidates.items[index] = .{
            .item = item,
            .priority = ranked_priority,
            .callable = callable,
        };
        return;
    }
    try candidates.append(allocator, .{
        .item = item,
        .priority = ranked_priority,
        .callable = callable,
    });
}

pub fn isReservedCompilerName(name: []const u8) bool {
    return std.mem.startsWith(u8, name, "__silex_");
}

fn candidateLessThan(_: void, left: Candidate, right: Candidate) bool {
    if (left.priority != right.priority) return left.priority < right.priority;
    const labels = std.mem.order(u8, left.item.label, right.item.label);
    if (labels != .eq) return labels == .lt;
    return std.mem.lessThan(u8, left.item.detail, right.item.detail);
}

fn typedPriority(base: u8, expected: ?ExpectedType, actual: ?[]const u8) u8 {
    const wanted = if (expected) |value| value.name else return base;
    const provided = actual orelse return base + 8;
    return if (std.mem.eql(u8, wanted, provided)) base -| 5 else base + 12;
}

fn matchesExpectedType(expected: ?ExpectedType, actual: ?[]const u8) bool {
    const wanted = expected orelse return true;
    if (!wanted.strict) return true;
    return std.mem.eql(u8, wanted.name, actual orelse return false);
}

const Callable = struct {
    position: usize,
    parameters: []const Ast.Parameter,
    return_type: Ast.Type,
    structure_name: ?[]const u8 = null,
    test_owner: ?[]const u8 = null,
};

fn containingCallable(source: []const u8, program: Ast.Program, cursor: usize) ?Callable {
    var result: ?Callable = null;
    for (program.functions) |function| {
        if (bodyContainsCursor(source, function.position.offset, cursor) and
            (result == null or function.position.offset > result.?.position)) result = .{
            .position = function.position.offset,
            .parameters = function.parameters,
            .return_type = function.return_type,
            .test_owner = function.test_owner,
        };
    }
    for (program.structures) |structure| {
        for (structure.methods) |method| {
            if (bodyContainsCursor(source, method.position.offset, cursor) and
                (result == null or method.position.offset > result.?.position)) result = .{
                .position = method.position.offset,
                .parameters = method.parameters,
                .return_type = method.return_type,
                .structure_name = structure.name,
            };
        }
        for (structure.constructors) |constructor| {
            if (bodyContainsCursor(source, constructor.position.offset, cursor) and
                (result == null or constructor.position.offset > result.?.position)) result = .{
                .position = constructor.position.offset,
                .parameters = constructor.parameters,
                .return_type = .structure(findStructureIndex(program, structure.name) orelse 0),
                .structure_name = structure.name,
            };
        }
    }
    for (program.extensions) |extension| {
        const target_name = typeName(program, extension.target);
        for (extension.methods) |method| {
            if (bodyContainsCursor(source, method.position.offset, cursor) and
                (result == null or method.position.offset > result.?.position)) result = .{
                .position = method.position.offset,
                .parameters = method.parameters,
                .return_type = method.return_type,
                .structure_name = target_name,
            };
        }
    }
    return result;
}

fn containingCallables(allocator: Allocator, source: []const u8, program: Ast.Program, cursor: usize) ![]const Callable {
    var result: std.ArrayList(Callable) = .empty;
    for (program.functions) |function| if (bodyContainsCursor(source, function.position.offset, cursor)) {
        try result.append(allocator, .{
            .position = function.position.offset,
            .parameters = function.parameters,
            .return_type = function.return_type,
            .test_owner = function.test_owner,
        });
    };
    for (program.structures) |structure| {
        for (structure.methods) |method| if (bodyContainsCursor(source, method.position.offset, cursor)) {
            try result.append(allocator, .{
                .position = method.position.offset,
                .parameters = method.parameters,
                .return_type = method.return_type,
                .structure_name = structure.name,
            });
        };
        for (structure.constructors) |constructor| if (bodyContainsCursor(source, constructor.position.offset, cursor)) {
            try result.append(allocator, .{
                .position = constructor.position.offset,
                .parameters = constructor.parameters,
                .return_type = .structure(findStructureIndex(program, structure.name) orelse 0),
                .structure_name = structure.name,
            });
        };
    }
    for (program.extensions) |extension| {
        const target_name = typeName(program, extension.target);
        for (extension.methods) |method| if (bodyContainsCursor(source, method.position.offset, cursor)) {
            try result.append(allocator, .{
                .position = method.position.offset,
                .parameters = method.parameters,
                .return_type = method.return_type,
                .structure_name = target_name,
            });
        };
    }
    std.mem.sort(Callable, result.items, {}, struct {
        fn lessThan(_: void, left: Callable, right: Callable) bool {
            return left.position < right.position;
        }
    }.lessThan);
    return result.toOwnedSlice(allocator);
}

fn bodyContainsCursor(source: []const u8, start: usize, cursor: usize) bool {
    if (cursor < start) return false;
    var lexer = LexerModule.Lexer.init(source);
    var started = false;
    var depth: usize = 0;
    while (true) {
        const token = lexer.next() catch return false;
        if (token.tag == .end) return started;
        if (token.start < start) continue;
        if (!started) {
            if (token.tag == .left_brace) {
                started = true;
                depth = 1;
            }
            continue;
        }
        if (token.start >= cursor) return depth != 0;
        switch (token.tag) {
            .left_brace => depth += 1,
            .right_brace => {
                depth -|= 1;
                if (depth == 0) return cursor <= token.end;
            },
            else => {},
        }
    }
}

const Local = struct { name: []const u8, type_name: ?[]const u8, depth: usize };

fn visibleLocals(allocator: Allocator, source: []const u8, program: Ast.Program, start: usize, cursor: usize) ![]const Local {
    const tokens = try tokensUntil(allocator, source, cursor);
    var locals: std.ArrayList(Local) = .empty;
    var depth: usize = 0;
    var index: usize = 0;
    while (index < tokens.len) : (index += 1) {
        const token = tokens[index];
        if (token.start < start) continue;
        switch (token.tag) {
            .left_brace => depth += 1,
            .right_brace => {
                var local_index = locals.items.len;
                while (local_index != 0) {
                    local_index -= 1;
                    if (locals.items[local_index].depth >= depth) _ = locals.orderedRemove(local_index);
                }
                depth -|= 1;
            },
            .keyword_let, .keyword_var => {
                if (index + 1 >= tokens.len or tokens[index + 1].tag != .identifier) continue;
                const name = tokens[index + 1].lexeme;
                const declaration_line = token.position.line;
                var end = index + 2;
                var completed = false;
                while (end < tokens.len) : (end += 1) {
                    if (tokens[end].tag == .semicolon or tokens[end].tag == .right_brace or
                        tokens[end].position.line > declaration_line)
                    {
                        completed = true;
                        break;
                    }
                }
                if (!completed and lineAtOffset(source, cursor) <= declaration_line) continue;
                try locals.append(allocator, .{
                    .name = name,
                    .type_name = inferDeclarationType(source, tokens[index..end]),
                    .depth = depth,
                });
            },
            .keyword_for => {
                var binding = index + 1;
                if (binding < tokens.len and tokens[binding].tag == .left_parenthesis) {
                    const callable = containingCallable(source, program, cursor);
                    const tuple_type = inferDestructuredForType(program, callable, tokens, binding) orelse continue;
                    const tuple = structureForType(program, tuple_type) orelse continue;
                    if (!tuple.is_tuple) continue;
                    var field_index: usize = 0;
                    var cursor_index = binding + 1;
                    while (cursor_index < tokens.len and tokens[cursor_index].tag != .right_parenthesis) : (cursor_index += 1) {
                        if (tokens[cursor_index].tag != .identifier or field_index >= tuple.fields.len) continue;
                        try locals.append(allocator, .{
                            .name = tokens[cursor_index].lexeme,
                            .type_name = memberTypeName(program, tuple.fields[field_index].type),
                            .depth = depth + 1,
                        });
                        field_index += 1;
                    }
                    continue;
                }
                if (binding < tokens.len and (tokens[binding].tag == .keyword_let or tokens[binding].tag == .keyword_var)) {
                    binding += 1;
                }
                if (binding >= tokens.len or tokens[binding].tag != .identifier) continue;
                try locals.append(allocator, .{
                    .name = tokens[binding].lexeme,
                    .type_name = inferForElementType(program, containingCallable(source, program, cursor), locals.items, tokens, binding),
                    // A for binding starts at the loop body, whose opening brace
                    // has not yet been consumed at this point.
                    .depth = depth + 1,
                });
            },
            .keyword_else => if (tryErrorLocal(program, tokens, index, depth)) |local| {
                try locals.append(allocator, local);
            },
            else => {},
        }
    }
    try appendCurrentMatchBindings(allocator, tokens, &locals, depth);
    return locals.toOwnedSlice(allocator);
}

fn appendCurrentMatchBindings(
    allocator: Allocator,
    tokens: []const Token,
    locals: *std.ArrayList(Local),
    depth: usize,
) !void {
    var arrow: ?usize = null;
    var guard_if: ?usize = null;
    for (tokens, 0..) |token, token_index| {
        if (token.tag == .fat_arrow) arrow = token_index;
        if (token.tag == .keyword_if) guard_if = token_index;
    }

    const marker = if (arrow != null and (guard_if == null or arrow.? > guard_if.?)) arrow.? else guard_if orelse return;
    if (arrow == null or marker != arrow.?) {
        for (tokens[marker + 1 ..]) |token| if (token.tag == .semicolon or token.tag == .right_brace) return;
    } else {
        var body_depth: usize = 0;
        var has_block = false;
        for (tokens[marker + 1 ..]) |token| switch (token.tag) {
            .left_brace => {
                has_block = true;
                body_depth += 1;
            },
            .right_brace => body_depth -|= 1,
            .semicolon => if (!has_block) return,
            else => {},
        };
        if (has_block and body_depth == 0) return;
    }

    var boundary: usize = 0;
    for (tokens[0..marker], 0..) |token, token_index| switch (token.tag) {
        .left_brace, .right_brace, .semicolon, .fat_arrow => boundary = token_index + 1,
        else => {},
    };
    var opening: ?usize = null;
    var cursor = boundary;
    while (cursor + 1 < marker) : (cursor += 1) {
        if (tokens[cursor].tag == .identifier and tokens[cursor + 1].tag == .left_parenthesis) {
            opening = cursor + 1;
            break;
        }
    }
    const start = opening orelse return;
    var nesting: usize = 1;
    cursor = start + 1;
    while (cursor < marker and nesting != 0) : (cursor += 1) switch (tokens[cursor].tag) {
        .left_parenthesis => nesting += 1,
        .right_parenthesis => nesting -= 1,
        .identifier => if (nesting == 1 and !std.mem.eql(u8, tokens[cursor].lexeme, "_")) {
            try locals.append(allocator, .{
                .name = tokens[cursor].lexeme,
                .type_name = null,
                .depth = depth,
            });
        },
        else => {},
    };
}

fn inferDestructuredForType(program: Ast.Program, callable: ?Callable, tokens: []const Token, opening: usize) ?Ast.Type {
    var index = opening + 1;
    while (index < tokens.len and tokens[index].tag != .keyword_in) : (index += 1) {}
    if (index + 1 >= tokens.len or tokens[index + 1].tag != .identifier) return null;
    const source_name = tokens[index + 1].lexeme;
    const owner = callable orelse return null;
    var source_type: ?Ast.Type = null;
    for (owner.parameters) |parameter| if (std.mem.eql(u8, parameter.name, source_name)) {
        source_type = parameter.type;
        break;
    };
    const generic_index = (source_type orelse return null).genericInstantiationIndex() orelse return null;
    if (generic_index >= program.generic_types.len) return null;
    const generic = program.generic_types[generic_index];
    if (generic.arguments.len == 0) return null;
    return generic.arguments[0];
}

fn inferForElementType(
    program: Ast.Program,
    callable: ?Callable,
    locals: []const Local,
    tokens: []const Token,
    binding: usize,
) ?[]const u8 {
    var index = binding + 1;
    while (index < tokens.len and tokens[index].tag != .keyword_in) : (index += 1) {}
    if (index + 1 >= tokens.len or tokens[index].tag != .keyword_in) return null;
    if (tokens[index + 1].tag == .string or tokens[index + 1].tag == .string_start) return "uint32";
    if (tokens[index + 1].tag != .identifier and tokens[index + 1].tag != .keyword_self) return null;
    index += 1;
    const root = tokens[index].lexeme;
    var current: ?Ast.Type = null;
    if (std.mem.eql(u8, root, "self")) {
        const owner = callable orelse return null;
        current = .structure(findStructureIndex(program, owner.structure_name orelse return null) orelse return null);
    } else if (callable) |owner| {
        for (owner.parameters) |parameter| if (std.mem.eql(u8, parameter.name, root)) {
            current = parameter.type;
            break;
        };
    }
    if (current == null) {
        var local_index = locals.len;
        while (local_index != 0) {
            local_index -= 1;
            if (!std.mem.eql(u8, locals[local_index].name, root)) continue;
            const spelling = locals[local_index].type_name orelse break;
            current = typeForSpelling(program, spelling);
            break;
        }
    }
    if (current == null and index + 1 < tokens.len and tokens[index + 1].tag == .left_parenthesis) {
        for (program.functions) |function| if (std.mem.eql(u8, function.name, root)) {
            current = function.return_type;
            break;
        };
    }
    index += 1;
    while (index + 1 < tokens.len and tokens[index].tag == .dot and tokens[index + 1].tag == .identifier) {
        const owner = structureForType(program, current orelse return null) orelse return null;
        const name = tokens[index + 1].lexeme;
        const call = index + 2 < tokens.len and tokens[index + 2].tag == .left_parenthesis;
        var next: ?Ast.Type = null;
        if (call) {
            for (owner.methods) |method| if (std.mem.eql(u8, method.name, name)) {
                next = method.return_type;
                break;
            };
        } else for (owner.fields) |field| if (std.mem.eql(u8, field.name, name)) {
            next = field.type;
            break;
        };
        current = next orelse return null;
        index += 2;
        if (call) {
            var depth: usize = 0;
            while (index < tokens.len) : (index += 1) switch (tokens[index].tag) {
                .left_parenthesis => depth += 1,
                .right_parenthesis => {
                    depth -|= 1;
                    if (depth == 0) {
                        index += 1;
                        break;
                    }
                },
                else => {},
            };
        }
    }
    const source_type = current orelse return null;
    const element = if (source_type == .str)
        Ast.Type.uint32
    else
        collectionElementType(program, source_type) orelse iteratorElementType(program, source_type) orelse return null;
    return typeName(program, element);
}

fn iteratorElementType(program: Ast.Program, type_value: Ast.Type) ?Ast.Type {
    const structure = structureForType(program, type_value) orelse return null;
    var result: ?Ast.Type = null;
    for (structure.methods) |method| {
        if (method.is_static or !std.mem.eql(u8, method.name, "next") or requiredParameterCount(method.parameters) != 0) continue;
        const element = method.return_type.optionalChild() orelse continue;
        if (result != null and result.? != element) return null;
        result = element;
    }
    return result;
}

fn requiredParameterCount(parameters: []const Ast.Parameter) usize {
    for (parameters, 0..) |parameter, index| if (parameter.default != null) return index;
    return parameters.len;
}

fn typeForSpelling(program: Ast.Program, spelling: []const u8) ?Ast.Type {
    for (program.type_names, 0..) |name, index| if (std.mem.eql(u8, name, spelling)) return .structure(index);
    return null;
}

fn structureForType(program: Ast.Program, type_value: Ast.Type) ?Ast.Structure {
    if (type_value.genericInstantiationIndex()) |index| {
        if (index >= program.generic_types.len) return null;
        return structureForType(program, program.generic_types[index].base);
    }
    return findStructure(program, nominalReceiverName(typeName(program, type_value)));
}

fn collectionElementType(program: Ast.Program, type_value: Ast.Type) ?Ast.Type {
    if (type_value.genericInstantiationIndex()) |index| {
        if (index >= program.generic_types.len) return null;
        const generic = program.generic_types[index];
        const base = structureForType(program, generic.base) orelse return null;
        if (base.collection == null or generic.arguments.len == 0) return null;
        return generic.arguments[0];
    }
    const structure = structureForType(program, type_value) orelse return null;
    return if (structure.collection) |collection| collection.element else null;
}

fn tryErrorLocal(program: Ast.Program, tokens: []const Token, else_index: usize, depth: usize) ?Local {
    if (else_index + 2 >= tokens.len or tokens[else_index + 1].tag != .identifier or
        !std.mem.eql(u8, tokens[else_index + 1].lexeme, "error") or
        tokens[else_index + 2].tag != .left_brace) return null;

    var index = else_index;
    while (index != 0) {
        index -= 1;
        const token = tokens[index];
        if (token.tag == .semicolon or token.tag == .left_brace or token.tag == .right_brace) return null;
        if (token.tag != .keyword_try) continue;
        const type_name = if (index + 2 < else_index and tokens[index + 1].tag == .identifier and
            tokens[index + 2].tag == .left_parenthesis)
            tryCallErrorType(program, tokens[index + 1].lexeme)
        else
            null;
        return .{ .name = "error", .type_name = type_name, .depth = depth + 1 };
    }
    return null;
}

pub fn isTryErrorBindingPositionAt(allocator: Allocator, source: []const u8, prefix_start: usize) !bool {
    const tokens = try tokensUntil(allocator, source, prefix_start);
    if (tokens.len == 0 or tokens[tokens.len - 1].tag != .keyword_else) return false;
    var index = tokens.len - 1;
    while (index != 0) {
        index -= 1;
        switch (tokens[index].tag) {
            .semicolon, .left_brace, .right_brace => return false,
            .keyword_try => return true,
            else => {},
        }
    }
    return false;
}

pub fn isTryAlternativePositionAt(allocator: Allocator, source: []const u8, prefix_start: usize) !bool {
    const tokens = try tokensUntil(allocator, source, prefix_start);
    if (tokens.len == 0 or tokens[tokens.len - 1].tag != .right_parenthesis) return false;
    const trailing = source[tokens[tokens.len - 1].end..prefix_start];
    if (std.mem.trim(u8, trailing, " \t\r\n").len != 0) return false;
    var index = tokens.len - 1;
    while (index != 0) {
        index -= 1;
        switch (tokens[index].tag) {
            .keyword_try => return true,
            .keyword_else, .semicolon, .left_brace, .right_brace => return false,
            else => {},
        }
    }
    return false;
}

fn tryErrorTypeAt(
    allocator: Allocator,
    source: []const u8,
    program: Ast.Program,
    prefix_start: usize,
) !?[]const u8 {
    const tokens = try tokensUntil(allocator, source, prefix_start);
    if (tokens.len == 0 or tokens[tokens.len - 1].tag != .keyword_else) return null;
    var index = tokens.len - 1;
    while (index != 0) {
        index -= 1;
        const token = tokens[index];
        if (token.tag == .semicolon or token.tag == .left_brace or token.tag == .right_brace) return null;
        if (token.tag != .keyword_try) continue;
        if (index + 2 >= tokens.len or tokens[index + 1].tag != .identifier or
            tokens[index + 2].tag != .left_parenthesis) return null;
        return tryCallErrorType(program, tokens[index + 1].lexeme);
    }
    return null;
}

fn tryCallErrorType(program: Ast.Program, function_name: []const u8) ?[]const u8 {
    var result: ?[]const u8 = null;
    for (program.functions) |function| {
        if (!std.mem.eql(u8, function.name, function_name)) continue;
        const generic_index = function.return_type.genericInstantiationIndex() orelse continue;
        if (generic_index >= program.generic_types.len) continue;
        const generic = program.generic_types[generic_index];
        if (!std.mem.eql(u8, typeName(program, generic.base), "Result") or generic.arguments.len != 2) continue;
        const candidate = memberTypeName(program, generic.arguments[1]);
        if (result != null and !std.mem.eql(u8, result.?, candidate)) return null;
        result = candidate;
    }
    return result;
}

fn inferDeclarationType(source: []const u8, tokens: []const Token) ?[]const u8 {
    for (tokens, 0..) |token, index| {
        if (token.tag == .colon and index + 1 < tokens.len) {
            var end = tokens.len;
            for (tokens[index + 1 ..], index + 1..) |candidate, candidate_index| if (candidate.tag == .equal) {
                end = candidate_index;
                break;
            };
            if (end == index + 1) return null;
            return std.mem.trim(u8, source[tokens[index + 1].start..tokens[end - 1].end], " \t\r\n");
        }
        if (token.tag != .equal or index + 1 >= tokens.len) continue;
        const value = tokens[index + 1];
        return switch (value.tag) {
            .string, .string_start => "str",
            .keyword_true, .keyword_false => "bool",
            .integer => "int",
            .floating => "float",
            .identifier => if (index + 2 < tokens.len and tokens[index + 2].tag == .left_parenthesis) value.lexeme else null,
            else => null,
        };
    }
    return null;
}

pub fn resolveReceiverType(
    allocator: Allocator,
    source: []const u8,
    program: Ast.Program,
    cursor: usize,
    receiver: []const u8,
) ?[]const u8 {
    _ = allocator;
    const trimmed = std.mem.trim(u8, receiver, " \t\r\n");
    if (trimmed.len == 0) return null;
    if (findStructure(program, trimmed) != null) return trimmed;
    if (trimmed[trimmed.len - 1] == ')') {
        const open = std.mem.lastIndexOfScalar(u8, trimmed, '(') orelse return null;
        const name = std.mem.trim(u8, trimmed[0..open], " \t");
        if (findStructure(program, name)) |_| return name;
        for (program.functions) |function| if (std.mem.eql(u8, function.name, name)) return memberTypeName(program, function.return_type);
        const qualified = qualifiedCall(trimmed) orelse return null;
        const owner = findStructure(program, qualified.owner) orelse return null;
        var return_type: ?[]const u8 = null;
        for (owner.methods) |method| {
            if (!method.is_static or !std.mem.eql(u8, method.name, qualified.name) or
                !acceptsArity(method.parameters, qualified.arity)) continue;
            const candidate = memberTypeName(program, method.return_type);
            if (return_type != null and !std.mem.eql(u8, return_type.?, candidate)) return null;
            return_type = candidate;
        }
        return return_type;
    }

    var parts = std.mem.splitScalar(u8, trimmed, '.');
    const first = parts.next() orelse return null;
    var current_type: ?[]const u8 = null;
    if (std.mem.eql(u8, first, "self")) {
        if (containingCallable(source, program, cursor)) |callable| current_type = callable.structure_name;
    } else if (containingCallable(source, program, cursor)) |callable| {
        for (callable.parameters) |parameter| if (std.mem.eql(u8, parameter.name, first)) {
            current_type = memberTypeName(program, parameter.type);
            break;
        };
        if (current_type == null) {
            const locals = visibleLocals(std.heap.page_allocator, source, program, callable.position, cursor) catch return null;
            defer std.heap.page_allocator.free(locals);
            var index = locals.len;
            while (index != 0) {
                index -= 1;
                if (std.mem.eql(u8, locals[index].name, first)) {
                    current_type = locals[index].type_name;
                    break;
                }
            }
        }
    }
    if (current_type) |candidate| if (findStructure(program, candidate) == null) {
        for (program.functions) |function| if (std.mem.eql(u8, function.name, candidate)) {
            current_type = memberTypeName(program, function.return_type);
            break;
        };
    };
    while (parts.next()) |field_name| {
        if (current_type) |candidate| if (findStructure(program, candidate) == null) {
            for (program.functions) |function| if (std.mem.eql(u8, function.name, candidate)) {
                current_type = memberTypeName(program, function.return_type);
                break;
            };
        };
        const owner = findStructure(program, current_type orelse return null) orelse return null;
        var next: ?[]const u8 = null;
        for (owner.fields) |field| if (std.mem.eql(u8, field.name, field_name)) {
            next = memberTypeName(program, field.type);
            break;
        };
        current_type = next orelse return null;
    }
    return current_type;
}

fn expectedTypeAt(source: []const u8, program: Ast.Program, cursor: usize, context: Context) ?ExpectedType {
    if (context.kind != .expression and context.kind != .statement) return null;
    const callable = containingCallable(source, program, cursor);
    const line = lineAtOffset(source, cursor);
    var lexer = LexerModule.Lexer.init(source[0..context.prefix_start]);
    var line_tokens: [128]Token = undefined;
    var count: usize = 0;
    while (lexer.next() catch null) |token| {
        if (token.tag == .end) break;
        if (token.position.line != line) continue;
        if (count < line_tokens.len) {
            line_tokens[count] = token;
            count += 1;
        }
    }
    const tokens = line_tokens[0..count];
    if (tokens.len == 0) return null;
    if (tokens[0].tag == .keyword_if or tokens[0].tag == .keyword_while) return .{ .name = "bool" };
    if (tokens[0].tag == .keyword_return) {
        if (expectedCallArgumentType(source[tokens[0].end..context.prefix_start], program)) |expected| return expected;
        return if (callable) |current| .{
            .name = baseTypeName(program, current.return_type),
            .strict = true,
        } else null;
    }
    if (expectedCallArgumentType(source[0..context.prefix_start], program)) |expected| return expected;
    if (tokens[0].tag == .keyword_panic) return .{ .name = "str" };
    var annotation: ?[]const u8 = null;
    var has_equal = false;
    for (tokens, 0..) |token, index| {
        if (token.tag == .colon and index + 1 < tokens.len) annotation = tokens[index + 1].lexeme;
        if (token.tag == .equal) has_equal = true;
    }
    return if (has_equal and annotation != null) .{ .name = annotation.?, .strict = true } else null;
}

fn expectedCallArgumentType(source: []const u8, program: Ast.Program) ?ExpectedType {
    const Call = struct {
        name: ?[]const u8,
        receiver: ?[]const u8,
        argument: usize = 0,
        bracket_depth: usize = 0,
    };
    var calls: [128]Call = undefined;
    var call_count: usize = 0;
    var previous: ?Token = null;
    var lexer = LexerModule.Lexer.init(source);
    while (true) {
        const token = lexer.next() catch return null;
        if (token.tag == .end) break;
        switch (token.tag) {
            .left_parenthesis => {
                if (call_count == calls.len) return null;
                calls[call_count] = .{
                    .name = if (previous != null and previous.?.tag == .identifier) previous.?.lexeme else null,
                    .receiver = if (previous != null and previous.?.tag == .identifier and previous.?.start != 0 and
                        source[previous.?.start - 1] == '.')
                        memberReceiver(source, previous.?.start - 1)
                    else
                        null,
                };
                call_count += 1;
            },
            .right_parenthesis => if (call_count != 0) {
                call_count -= 1;
            },
            .left_bracket => if (call_count != 0) {
                calls[call_count - 1].bracket_depth += 1;
            },
            .right_bracket => if (call_count != 0) {
                calls[call_count - 1].bracket_depth -|= 1;
            },
            .comma => if (call_count != 0 and calls[call_count - 1].bracket_depth == 0) {
                calls[call_count - 1].argument += 1;
            },
            else => {},
        }
        previous = token;
    }
    var index = call_count;
    while (index != 0) {
        index -= 1;
        const call = calls[index];
        const name = call.name orelse return null;
        if (call.argument == 0) if (call.receiver) |receiver| if (resultArguments(
            std.mem.trim(u8, receiver, " \t\r\n"),
        )) |arguments| {
            const argument_type = if (std.mem.eql(u8, name, "success"))
                arguments.success
            else if (std.mem.eql(u8, name, "failure"))
                arguments.failure
            else
                null;
            if (argument_type) |type_name| {
                if (std.mem.eql(u8, type_name, "void")) return null;
                return .{
                    .name = nominalReceiverName(type_name),
                    .strict = true,
                };
            }
        };
        var selected: ?Ast.Type = null;
        for (program.functions) |function| {
            if (!std.mem.eql(u8, function.name, name) or call.argument >= function.parameters.len) continue;
            const candidate = function.parameters[call.argument].type;
            if (selected != null and selected.? != candidate) return null;
            selected = candidate;
        }
        const type_value = selected orelse return null;
        return .{
            .name = typeName(program, type_value),
            .strict = true,
            .function_type = if (type_value.functionIndex() != null) type_value else null,
        };
    }
    return null;
}

fn functionMatchesType(program: Ast.Program, function: Ast.Function, type_value: Ast.Type) bool {
    const index = type_value.functionIndex() orelse return false;
    if (index >= program.function_types.len) return false;
    const expected = program.function_types[index];
    if (expected.return_type != function.return_type or expected.return_mode != function.return_mode or
        expected.parameters.len != function.parameters.len) return false;
    for (expected.parameters, function.parameters) |expected_parameter, parameter| {
        if (expected_parameter.type != parameter.type or expected_parameter.mode != parameter.mode) return false;
    }
    return true;
}

fn structureDetail(structure: Ast.Structure) []const u8 {
    if (structure.is_protocol) return "Silex protocol";
    return if (structure.is_class) "Silex class" else "Silex structure";
}

fn structureCompletionKind(structure: Ast.Structure) u8 {
    if (structure.is_protocol) return CompletionKind.interface;
    if (structure.is_class) return CompletionKind.class;
    return CompletionKind.structure;
}

fn parseForCompletion(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
    context: Context,
) !?Ast.Program {
    var parser = ParserModule.Parser.init(allocator, source);
    if (parser.parse()) |program| return mergeExtensionsForCompletion(allocator, program) else |_| {}

    if (context.cascade) {
        const recovered = try recoverCascadeForParsing(allocator, source, cursor) orelse return null;
        parser = ParserModule.Parser.init(allocator, recovered);
        const program = parser.parse() catch return null;
        return mergeExtensionsForCompletion(allocator, program);
    }

    const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..context.prefix_start], '\n')) |newline|
        newline + 1
    else
        0;
    const before_prefix = std.mem.trim(u8, source[line_start..context.prefix_start], " \t\r");
    const for_source = isForSourceLine(before_prefix);
    const for_body_follows = for_source and blockFollowsCompletion(source, cursor);
    const control_body_missing = lineStartsControlCondition(before_prefix) and !blockFollowsCompletion(source, cursor);
    const completing_try_error = try isTryErrorBindingPositionAt(allocator, source, context.prefix_start);
    const completing_try_alternative = try isTryAlternativePositionAt(allocator, source, context.prefix_start);
    const placeholder: []const u8 = if (completing_try_error)
        "error"
    else if (completing_try_alternative)
        "else {}"
    else switch (context.kind) {
        .member => if (callFollows(source, cursor))
            if (context.prefix.len == 0) "__completion" else ""
        else if (context.prefix.len != 0)
            "()"
        else if (memberFollowedByAssignment(source, cursor))
            "__completion"
        else if ((for_source and !for_body_follows) or control_body_missing)
            "__completion() {}"
        else
            "__completion()",
        .type_name => "int",
        .aggregate_field => "__completion:true",
        .statement => "print(true)",
        .expression => if (for_source and !for_body_follows)
            "true {}"
        else if (before_prefix.len == 0)
            "print(true)"
        else
            "true",
        else => return null,
    };
    const replacement_start = if (context.kind == .member or context.prefix.len == 0)
        cursor
    else
        context.prefix_start;
    const recovered = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
        source[0..replacement_start],
        placeholder,
        source[cursor..],
    });
    parser = ParserModule.Parser.init(allocator, recovered);
    const program = parser.parse() catch blk: {
        if (context.kind != .type_name and !context.nominal_relation) return null;
        const line_end = if (std.mem.indexOfScalarPos(u8, source, cursor, '\n')) |newline|
            newline + 1
        else
            source.len;
        const without_incomplete_declaration = try std.fmt.allocPrint(allocator, "{s}{s}", .{
            source[0..line_start],
            source[line_end..],
        });
        parser = ParserModule.Parser.init(allocator, without_incomplete_declaration);
        break :blk parser.parse() catch return null;
    };
    return mergeExtensionsForCompletion(allocator, program);
}

fn isForSourceLine(line: []const u8) bool {
    var lexer = LexerModule.Lexer.init(line);
    const first = lexer.next() catch return false;
    if (first.tag != .keyword_for) return false;
    while (true) {
        const token = lexer.next() catch return false;
        if (token.tag == .end) return false;
        if (token.tag == .keyword_in) return true;
    }
}

pub fn lineStartsControlCondition(line: []const u8) bool {
    return std.mem.startsWith(u8, line, "if ") or
        std.mem.startsWith(u8, line, "elif ") or
        std.mem.startsWith(u8, line, "while ");
}

fn blockFollowsCompletion(source: []const u8, cursor: usize) bool {
    var index = cursor;
    while (index < source.len and (source[index] == ' ' or source[index] == '\t' or source[index] == '\r')) index += 1;
    return index < source.len and source[index] == '{';
}

pub fn aggregateContextAt(allocator: Allocator, source: []const u8, cursor: usize) !?AggregateContext {
    if (cursor > source.len) return null;
    const prefix_start = identifierPrefixStart(source, cursor);
    const tokens = try tokensUntil(allocator, source, prefix_start);

    var openings: std.ArrayList(usize) = .empty;
    for (tokens, 0..) |token, index| switch (token.tag) {
        .left_parenthesis => try openings.append(allocator, index),
        .right_parenthesis => if (openings.items.len != 0) {
            _ = openings.pop();
        },
        else => {},
    };
    if (openings.items.len == 0) return null;
    const opening = openings.items[openings.items.len - 1];
    if (opening == 0 or tokens[opening - 1].tag != .identifier) return null;

    var supplied: std.ArrayList([]const u8) = .empty;
    var nesting: usize = 0;
    var segment_start = opening + 1;
    var index = segment_start;
    while (index < tokens.len) : (index += 1) {
        const token = tokens[index];
        switch (token.tag) {
            .left_parenthesis, .left_bracket, .left_brace => nesting += 1,
            .right_parenthesis, .right_bracket, .right_brace => nesting -|= 1,
            .comma => if (nesting == 0) {
                try appendSuppliedAggregateField(&supplied, allocator, tokens[segment_start..index]);
                segment_start = index + 1;
            },
            else => {},
        }
    }

    // At a field position, the current top-level segment contains only the
    // identifier prefix, which is deliberately excluded from `tokens`.
    if (segment_start != tokens.len) return null;
    return .{
        .type_name = tokens[opening - 1].lexeme,
        .supplied_fields = try supplied.toOwnedSlice(allocator),
    };
}

fn appendSuppliedAggregateField(
    fields: *std.ArrayList([]const u8),
    allocator: Allocator,
    tokens: []const Token,
) !void {
    if (tokens.len < 2 or tokens[0].tag != .identifier or tokens[1].tag != .colon) return;
    try fields.append(allocator, tokens[0].lexeme);
}

pub fn suppliedAggregateField(context: AggregateContext, name: []const u8) bool {
    for (context.supplied_fields) |field| if (std.mem.eql(u8, field, name)) return true;
    return false;
}

fn memberFollowedByAssignment(source: []const u8, cursor: usize) bool {
    var index = cursor;
    while (index < source.len and (source[index] == ' ' or source[index] == '\t')) index += 1;
    if (index >= source.len) return false;
    if (source[index] == '=') return true;
    if (index + 1 >= source.len or source[index + 1] != '=') return false;
    return source[index] == '+' or source[index] == '-' or source[index] == '*' or source[index] == '/';
}

fn mergeExtensionsForCompletion(allocator: Allocator, program: Ast.Program) ?Ast.Program {
    var merger = ExtensionMerger.Merger.init(allocator);
    return merger.merge(program, true, true) catch program;
}

pub fn functionSignature(
    allocator: Allocator,
    source: []const u8,
    program: Ast.Program,
    function: Ast.Function,
) ![]const u8 {
    var result = try std.fmt.allocPrint(allocator, "{s}(", .{function.name});
    for (function.parameters, 0..) |parameter, index| {
        result = try std.fmt.allocPrint(allocator, "{s}{s}{s}:{s}", .{
            result,
            if (index == 0) "" else ", ",
            parameter.name,
            typeName(program, parameter.type),
        });
        if (parameter.default != null) if (parameterDefaultText(source, parameter.position.offset)) |text| {
            result = try std.fmt.allocPrint(allocator, "{s} = {s}", .{ result, text });
        };
    }
    return std.fmt.allocPrint(allocator, "{s}) {s}", .{ result, typeName(program, function.return_type) });
}

pub fn constructorSignature(
    allocator: Allocator,
    source: []const u8,
    program: Ast.Program,
    name: []const u8,
    constructor: Ast.Constructor,
) ![]const u8 {
    var result = try std.fmt.allocPrint(allocator, "{s}(", .{name});
    for (constructor.parameters, 0..) |parameter, index| {
        result = try std.fmt.allocPrint(allocator, "{s}{s}{s}:{s}", .{
            result,
            if (index == 0) "" else ", ",
            parameter.name,
            typeName(program, parameter.type),
        });
        if (parameter.default != null) if (parameterDefaultText(source, parameter.position.offset)) |text| {
            result = try std.fmt.allocPrint(allocator, "{s} = {s}", .{ result, text });
        };
    }
    return std.fmt.allocPrint(allocator, "{s}) {s}", .{ result, name });
}

pub fn variantSignature(
    allocator: Allocator,
    program: Ast.Program,
    enumeration: Ast.Enum,
    variant: Ast.EnumVariant,
) ![]const u8 {
    if (variant.associated_types.len == 0) {
        return std.fmt.allocPrint(allocator, "{s} {s}", .{ variant.name, enumeration.name });
    }
    var result = try std.fmt.allocPrint(allocator, "{s}(", .{variant.name});
    for (variant.associated_types, 0..) |associated, index| {
        result = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
            result,
            if (index == 0) "" else ", ",
            typeName(program, associated),
        });
    }
    return std.fmt.allocPrint(allocator, "{s}) {s}", .{ result, enumeration.name });
}

fn parameterDefaultText(source: []const u8, start: usize) ?[]const u8 {
    if (start >= source.len) return null;
    var lexer = LexerModule.Lexer.init(source[start..]);
    var depth: usize = 0;
    var value_start: ?usize = null;
    while (true) {
        const token = lexer.next() catch return null;
        if (token.tag == .end) return null;
        if (value_start) |offset| {
            if (depth == 0 and (token.tag == .comma or token.tag == .right_parenthesis)) {
                return std.mem.trim(u8, source[start + offset .. start + token.start], " \t\r\n");
            }
        }
        switch (token.tag) {
            .left_parenthesis, .left_bracket => depth += 1,
            .right_parenthesis, .right_bracket => {
                if (depth != 0) depth -= 1;
            },
            .equal => {
                if (depth == 0 and value_start == null) value_start = token.end;
            },
            else => {},
        }
    }
}

pub fn typeName(program: Ast.Program, type_value: Ast.Type) []const u8 {
    const index = type_value.structureIndex() orelse return type_value.name();
    return if (index < program.type_names.len) program.type_names[index] else "structure";
}

fn baseTypeName(program: Ast.Program, source_type: Ast.Type) []const u8 {
    const type_value = source_type.optionalChild() orelse source_type;
    if (type_value.genericInstantiationIndex()) |index| {
        if (index < program.generic_types.len) return typeName(program, program.generic_types[index].base);
    }
    return typeName(program, type_value);
}

fn memberTypeName(program: Ast.Program, type_value: Ast.Type) []const u8 {
    const direct = type_value.optionalChild() orelse type_value;
    if (direct.genericInstantiationIndex()) |index| {
        if (index < program.generic_types.len) return typeName(program, program.generic_types[index].base);
    }
    return typeName(program, direct);
}

fn findStructure(program: Ast.Program, name: []const u8) ?Ast.Structure {
    for (program.structures) |structure| {
        if (std.mem.eql(u8, structure.name, name)) return structure;
        if (structure.name.len > name.len and std.mem.endsWith(u8, structure.name, name) and
            structure.name[structure.name.len - name.len - 1] == '.') return structure;
        if (name.len > structure.name.len and std.mem.endsWith(u8, name, structure.name) and
            name[name.len - structure.name.len - 1] == '.') return structure;
    }
    return null;
}

fn findEnum(program: Ast.Program, name: []const u8) ?Ast.Enum {
    const nominal_name = nominalReceiverName(name);
    for (program.enums) |enumeration| {
        if (std.mem.eql(u8, enumeration.name, nominal_name) or std.mem.endsWith(u8, nominal_name, enumeration.name)) return enumeration;
    }
    return null;
}

fn findStructureIndex(program: Ast.Program, name: []const u8) ?usize {
    for (program.type_names, 0..) |candidate, index| {
        if (std.mem.eql(u8, candidate, name)) return index;
        if (candidate.len > name.len and std.mem.endsWith(u8, candidate, name) and
            candidate[candidate.len - name.len - 1] == '.') return index;
    }
    return null;
}

fn tokensUntil(allocator: Allocator, source: []const u8, end: usize) ![]const Token {
    var tokens: std.ArrayList(Token) = .empty;
    var lexer = LexerModule.Lexer.init(source[0..end]);
    while (true) {
        const token = lexer.next() catch break;
        if (token.tag == .end) break;
        try tokens.append(allocator, token);
    }
    return tokens.toOwnedSlice(allocator);
}

fn identifierPrefixStart(source: []const u8, cursor: usize) usize {
    var start = cursor;
    while (start != 0 and isIdentifierContinue(source[start - 1])) start -= 1;
    return start;
}

fn isIdentifierContinue(character: u8) bool {
    return std.ascii.isAlphanumeric(character) or character == '_';
}

pub fn isTypeArgumentPrefix(source: []const u8, end: usize) bool {
    if (end > source.len) return false;
    var lexer = LexerModule.Lexer.init(source[0..end]);
    var candidates: [128]bool = undefined;
    var depth: usize = 0;
    var previous: ?Token = null;
    while (true) {
        const token = lexer.next() catch return false;
        if (token.tag == .end) break;
        switch (token.tag) {
            .less => {
                if (depth == candidates.len) return false;
                candidates[depth] = if (previous) |owner|
                    owner.tag == .identifier and owner.end == token.start
                else
                    false;
                depth += 1;
            },
            .greater => depth -|= 1,
            .shift_right => depth -|= 2,
            else => {},
        }
        previous = token;
    }
    for (candidates[0..depth]) |candidate| if (candidate) return true;
    return false;
}

pub fn memberReceiver(source: []const u8, dot: usize) ?[]const u8 {
    if (dot == 0) return null;
    var start = dot;
    if (source[start - 1] == ')') {
        var depth: usize = 0;
        while (start != 0) {
            start -= 1;
            if (source[start] == ')') depth += 1;
            if (source[start] == '(') {
                depth -|= 1;
                if (depth == 0) break;
            }
        }
    }
    if (start != 0 and source[start - 1] == '>') {
        var depth: usize = 0;
        while (start != 0) {
            start -= 1;
            if (source[start] == '>') depth += 1;
            if (source[start] == '<') {
                depth -|= 1;
                if (depth == 0) break;
            }
        }
    }
    while (start != 0) {
        if (isIdentifierContinue(source[start - 1])) {
            start -= 1;
            continue;
        }
        if (source[start - 1] != '.') break;
        // A range boundary is not part of the member receiver. Without this
        // guard, `0...self.` resolves the receiver as `0...self`.
        if (start >= 3 and std.mem.eql(u8, source[start - 3 .. start], "...")) break;
        start -= 1;
    }
    return source[start..dot];
}

pub fn cascadeReceiver(source: []const u8, dot_dot: usize) ?[]const u8 {
    if (dot_dot + 1 >= source.len or source[dot_dot] != '.' or source[dot_dot + 1] != '.') return null;
    const cascade_start = cascadeRecoveryStart(source, dot_dot);
    const base_end = if (cascade_start < dot_dot) cascade_start else dot_dot;
    var end = base_end;
    while (end != 0 and (source[end - 1] == ' ' or source[end - 1] == '\t' or source[end - 1] == '\r' or
        source[end - 1] == '\n')) end -= 1;
    if (end == 0) return null;

    const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..end], '\n')) |newline| newline + 1 else 0;
    const line = std.mem.trimStart(u8, source[line_start..end], " \t");
    if (bindingName(line)) |name| return name;
    return memberReceiver(source, end);
}

pub fn recoverCascadeForParsing(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
) !?[]const u8 {
    const prefix_start = identifierPrefixStart(source, cursor);
    if (prefix_start < 2 or source[prefix_start - 2] != '.' or source[prefix_start - 1] != '.') return null;
    const start = cascadeRecoveryStart(source, prefix_start - 2);
    const end = if (start == prefix_start - 2)
        cursor
    else if (std.mem.indexOfScalarPos(u8, source, cursor, '\n')) |newline|
        newline
    else
        source.len;
    const recovered: []const u8 = try std.fmt.allocPrint(allocator, "{s}{s}", .{ source[0..start], source[end..] });
    return recovered;
}

fn cascadeRecoveryStart(source: []const u8, dot_dot: usize) usize {
    const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..dot_dot], '\n')) |newline| newline + 1 else 0;
    if (std.mem.trim(u8, source[line_start..dot_dot], " \t\r").len != 0) return dot_dot;
    const indentation = source[line_start..dot_dot];

    var recovery_start = line_start;
    var scan = line_start;
    while (scan != 0) {
        const previous_end = scan - 1;
        const previous_start = if (std.mem.lastIndexOfScalar(u8, source[0..previous_end], '\n')) |newline|
            newline + 1
        else
            0;
        const previous_line = source[previous_start..previous_end];
        const previous = std.mem.trimStart(u8, previous_line, " \t");
        const previous_indentation = previous_line[0 .. previous_line.len - previous.len];
        if (!std.mem.startsWith(u8, previous_indentation, indentation)) break;
        if (std.mem.eql(u8, previous_indentation, indentation) and std.mem.startsWith(u8, previous, "..")) {
            recovery_start = previous_start;
            scan = previous_start;
            continue;
        }

        // A cascade operation can span nested calls and nested cascades. Keep
        // walking through their more deeply indented lines and through closing
        // delimiters aligned with the outer cascade until its preceding `..`
        // is found.
        if (previous_indentation.len > indentation.len or previous.len == 0 or
            previous[0] == ')' or previous[0] == ']')
        {
            scan = previous_start;
            continue;
        }
        break;
    }
    return recovery_start;
}

fn bindingName(line: []const u8) ?[]const u8 {
    const keyword_length: usize = if (std.mem.startsWith(u8, line, "let "))
        "let ".len
    else if (std.mem.startsWith(u8, line, "var "))
        "var ".len
    else
        return null;
    var end = keyword_length;
    while (end < line.len and isIdentifierContinue(line[end])) end += 1;
    if (end == keyword_length) return null;
    if (std.mem.indexOfScalar(u8, line[end..], '=') == null) return null;
    return line[keyword_length..end];
}

pub fn nominalReceiverName(receiver: []const u8) []const u8 {
    const trimmed = std.mem.trim(u8, receiver, " \t\r\n");
    const generic = std.mem.indexOfScalar(u8, trimmed, '<') orelse return trimmed;
    return trimmed[0..generic];
}

pub const QualifiedCall = struct {
    owner: []const u8,
    name: []const u8,
    arity: usize,
};

pub const DirectCall = struct {
    name: []const u8,
    arity: usize,
};

pub fn directCall(receiver: []const u8) ?DirectCall {
    var tokens: [256]Token = undefined;
    var count: usize = 0;
    var lexer = LexerModule.Lexer.init(receiver);
    while (true) {
        const token = lexer.next() catch return null;
        if (token.tag == .end) break;
        if (count == tokens.len) return null;
        tokens[count] = token;
        count += 1;
    }
    if (count < 3 or tokens[0].tag != .identifier or tokens[1].tag != .left_parenthesis or
        tokens[count - 1].tag != .right_parenthesis) return null;

    var nesting: usize = 0;
    var arguments: usize = 0;
    var has_argument = false;
    for (tokens[2 .. count - 1]) |token| switch (token.tag) {
        .left_parenthesis, .left_bracket, .left_brace => {
            nesting += 1;
            has_argument = true;
        },
        .right_parenthesis, .right_bracket, .right_brace => nesting -|= 1,
        .comma => if (nesting == 0) {
            arguments += 1;
        } else {
            has_argument = true;
        },
        else => has_argument = true,
    };
    if (has_argument) arguments += 1;
    return .{ .name = tokens[0].lexeme, .arity = arguments };
}

pub fn qualifiedCall(receiver: []const u8) ?QualifiedCall {
    var tokens: [256]Token = undefined;
    var count: usize = 0;
    var lexer = LexerModule.Lexer.init(receiver);
    while (true) {
        const token = lexer.next() catch return null;
        if (token.tag == .end) break;
        if (count == tokens.len) return null;
        tokens[count] = token;
        count += 1;
    }
    if (count < 5 or tokens[count - 1].tag != .right_parenthesis) return null;

    var depth: usize = 0;
    var open: ?usize = null;
    var index = count;
    while (index != 0) {
        index -= 1;
        switch (tokens[index].tag) {
            .right_parenthesis => depth += 1,
            .left_parenthesis => {
                depth -|= 1;
                if (depth == 0) {
                    open = index;
                    break;
                }
            },
            else => {},
        }
    }
    const opening = open orelse return null;
    if (opening < 3 or tokens[opening - 2].tag != .dot or tokens[opening - 1].tag != .identifier) return null;
    for (tokens[0 .. opening - 2], 0..) |token, owner_index| {
        if (owner_index % 2 == 0) {
            if (token.tag != .identifier) return null;
        } else if (token.tag != .dot) return null;
    }

    var nesting: usize = 0;
    var arguments: usize = 0;
    var has_argument = false;
    for (tokens[opening + 1 .. count - 1]) |token| switch (token.tag) {
        .left_parenthesis, .left_bracket, .left_brace => {
            nesting += 1;
            has_argument = true;
        },
        .right_parenthesis, .right_bracket, .right_brace => nesting -|= 1,
        .comma => if (nesting == 0) {
            arguments += 1;
        } else {
            has_argument = true;
        },
        else => has_argument = true,
    };
    if (has_argument) arguments += 1;
    return .{
        .owner = receiver[tokens[0].start..tokens[opening - 2].start],
        .name = tokens[opening - 1].lexeme,
        .arity = arguments,
    };
}

fn currentLineTokenStart(tokens: []const Token, line: usize) usize {
    var index = tokens.len;
    while (index != 0 and tokens[index - 1].position.line == line) index -= 1;
    return index;
}

fn lineAtOffset(source: []const u8, offset: usize) usize {
    var line: usize = 1;
    for (source[0..offset]) |character| if (character == '\n') {
        line += 1;
    };
    return line;
}

fn cursorAllowsCode(source: []const u8, cursor: usize) bool {
    var lexer = LexerModule.Lexer.init(source[0..cursor]);
    var string_depth: usize = 0;
    var interpolation_depth: usize = 0;
    var last_token_end: usize = 0;
    while (true) {
        const token = lexer.next() catch return false;
        if (token.tag == .end) break;
        last_token_end = token.end;
        switch (token.tag) {
            .string_start => string_depth += 1,
            .interpolation_start => interpolation_depth += 1,
            .interpolation_end => interpolation_depth -|= 1,
            .string_end => string_depth -|= 1,
            else => {},
        }
    }
    const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..cursor], '\n')) |newline| newline + 1 else 0;
    if (std.mem.indexOf(u8, source[@max(line_start, last_token_end)..cursor], "//") != null) return false;
    return string_depth == 0 or interpolation_depth != 0;
}

fn contains(items: []const CompletionItem, label: []const u8) bool {
    for (items) |item| if (completionNameMatches(item, label)) return true;
    return false;
}

fn indexOf(items: []const CompletionItem, label: []const u8) ?usize {
    for (items, 0..) |item, index| if (completionNameMatches(item, label)) return index;
    return null;
}

fn completionNameMatches(item: CompletionItem, label: []const u8) bool {
    return std.mem.eql(u8, item.label, label) or
        (item.filterText != null and std.mem.eql(u8, item.filterText.?, label));
}

test "complete remaining fields in a local structure aggregate" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Settings {
        \\    let title:str = "Window"
        \\    let width:int = 1280
        \\    let resizable:bool = true
        \\}
        \\func main() {
        \\    let settings = Settings(
        \\        title:"Silex",
        \\        width:1024,
        \\        re
        \\    )
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "re\n").? + "re".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "resizable"));
    try std.testing.expect(!contains(items, "title"));
    try std.testing.expect(!contains(items, "width"));
    try std.testing.expect(!contains(items, "return"));
}

test "complete the first field of native structure and class initializers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Error { let message:str }
        \\class Failure { public let message:str }
        \\struct Explicit {
        \\    let message:str
        \\    init(value:str) { self.message = value }
        \\}
        \\func main() {
        \\    let memory = "local"
        \\    print(Error(me))
        \\    print(Failure(me))
        \\    print(Explicit(me))
        \\}
    ;
    const structure_cursor = std.mem.indexOf(u8, source, "Error(me)").? + "Error(me".len;
    const structure_items = try itemsAt(arena.allocator(), source, structure_cursor, .invoked);
    try std.testing.expect(contains(structure_items, "message"));
    try std.testing.expect(!contains(structure_items, "memory"));
    const structure_field = structure_items[indexOf(structure_items, "message").?];
    try std.testing.expectEqual(CompletionKind.field, structure_field.kind);
    try std.testing.expectEqualStrings("message:str", structure_field.detail);
    try std.testing.expectEqualStrings("message", structure_field.insertText.?);

    const class_cursor = std.mem.indexOf(u8, source, "Failure(me)").? + "Failure(me".len;
    const class_items = try itemsAt(arena.allocator(), source, class_cursor, .invoked);
    try std.testing.expect(contains(class_items, "message"));
    try std.testing.expect(!contains(class_items, "memory"));

    const explicit_cursor = std.mem.indexOf(u8, source, "Explicit(me)").? + "Explicit(me".len;
    const explicit_items = try itemsAt(arena.allocator(), source, explicit_cursor, .invoked);
    try std.testing.expect(!contains(explicit_items, "message"));
    try std.testing.expect(contains(explicit_items, "memory"));
}

test "complete an instance with only its own members" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Other { func ignore() {} }
        \\struct Vector3 {
        \\    var x:float
        \\    var y:float
        \\    func to_str() str { return "vector" }
        \\}
        \\func main() {
        \\    let pos = Vector3()
        \\    print(pos.t)
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "pos.t").? + "pos.t".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expectEqual(@as(usize, 1), items.len);
    try std.testing.expectEqualStrings("to_str", items[0].label);
    try std.testing.expectEqualStrings("to_str() str", items[0].detail);
    try std.testing.expect(!contains(items, "if"));
    try std.testing.expect(!contains(items, "float"));
    try std.testing.expect(!contains(items, "ignore"));
}

test "complete indexed collection traversal while writing a for source" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func main() {
        \\    var list:str[] = ["foo", "bar"]
        \\    for index, value in list.
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "list.\n").? + "list.".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "count"));
    try std.testing.expect(contains(items, "is_empty"));
    const indexed = items[indexOf(items, "indexed").?];
    try std.testing.expectEqual(CompletionKind.method, indexed.kind);
    try std.testing.expectEqualStrings("indexed() indexed collection traversal", indexed.detail);
    try std.testing.expectEqualStrings("indexed()", indexed.insertText.?);
    try std.testing.expect(indexed.insertTextFormat == null);

    const fixed_source =
        \\func main() {
        \\    let values:int[2] = [1, 2]
        \\    for index, value in values.
        \\}
    ;
    const fixed_cursor = std.mem.indexOf(u8, fixed_source, "values.\n").? + "values.".len;
    try std.testing.expect(contains(
        try itemsAt(arena.allocator(), fixed_source, fixed_cursor, .trigger_character),
        "indexed",
    ));
}

test "offer indexed only in the collection traversal context" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func main() {
        \\    let values:int[] = [1, 2]
        \\    print(values.)
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "values.").? + "values.".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "count"));
    try std.testing.expect(contains(items, "is_empty"));
    try std.testing.expect(!contains(items, "indexed"));
}

test "complete members of the original receiver in a cascade" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\class Application {
        \\    public func install() Application { return self }
        \\    public func run() int { return 0 }
        \\}
        \\func main() {
        \\    var app = Application()
        \\        ..
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "..\n").? + "..".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expectEqual(@as(usize, 2), items.len);
    try std.testing.expect(contains(items, "install"));
    try std.testing.expect(contains(items, "run"));
    try std.testing.expect(!contains(items, "if"));

    const continued_source =
        \\class Application {
        \\    public func install() Application { return self }
        \\    public func run() int { return 0 }
        \\}
        \\func main() {
        \\    var app = Application()
        \\        ..install()
        \\        ..r
        \\}
    ;
    const continued_cursor = std.mem.indexOf(u8, continued_source, "..r").? + "..r".len;
    const continued = try itemsAt(arena.allocator(), continued_source, continued_cursor, .trigger_character);
    try std.testing.expectEqual(@as(usize, 1), continued.len);
    try std.testing.expectEqualStrings("run", continued[0].label);
}

test "resume an outer cascade after a nested cascade argument" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Settings {
        \\    var title:str
        \\}
        \\struct Plugin {}
        \\class Application {
        \\    public func install(plugin:Plugin) Application { return self }
        \\    public func run() int { return 0 }
        \\}
        \\func main() {
        \\    Application()
        \\        ..install(Plugin(Settings()
        \\            ..title = "Silex"
        \\        ))
        \\        ..
        \\        ..run()
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "        ..\n").? + "        ..".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "install"));
    try std.testing.expect(contains(items, "run"));
    try std.testing.expect(!contains(items, "title"));
}

test "complete local types in explicit cascade method arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\protocol Plugin {}
        \\struct FooPlugin : Plugin {}
        \\class Application {
        \\    func install<T:Plugin>() Application { return self }
        \\    func run() int { return 0 }
        \\}
        \\func main() {
        \\    var app = Application()
        \\        ..install<FooP>()
        \\        ..run()
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "FooP>").? + "FooP".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "FooPlugin"));
    try std.testing.expect(!contains(items, "if"));
}

test "complete empty enum variants as values and payload variants as calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\enum State { ready; value(int) }
        \\func main() { let state = State. }
    ;
    const cursor = std.mem.indexOf(u8, source, "State.").? + "State.".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    const ready = items[indexOf(items, "ready").?];
    const value = items[indexOf(items, "value").?];
    try std.testing.expectEqualStrings("ready", ready.insertText.?);
    try std.testing.expect(ready.insertTextFormat == null);
    try std.testing.expectEqualStrings("value($0)", value.insertText.?);
    try std.testing.expectEqual(@as(?u8, 2), value.insertTextFormat);
}

test "complete variants on a specialized generic enum" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\enum Choice<T> { empty; value(T) }
        \\func main() { let choice = Choice<int>. }
    ;
    const cursor = std.mem.indexOf(u8, source, "Choice<int>.").? + "Choice<int>.".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expectEqualStrings("empty", items[indexOf(items, "empty").?].insertText.?);
    try std.testing.expectEqualStrings("value($0)", items[indexOf(items, "value").?].insertText.?);
}

test "complete anonymous function parameters without exposing synthetic functions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func apply(callback:func(int)) {}
        \\func main() {
        \\    apply(func(value:int) {
        \\        print(val)
        \\    })
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "print(val").? + "print(val".len;
    const context = try classifyContext(arena.allocator(), source, cursor);
    try std.testing.expectEqual(ContextKind.expression, context.kind);
    const parsed = (try parseForCompletion(arena.allocator(), source, cursor, context)).?;
    const callable = containingCallable(source, parsed, cursor).?;
    try std.testing.expectEqualStrings("value", callable.parameters[0].name);
    try std.testing.expect(expectedTypeAt(source, parsed, cursor, context) == null);
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "value"));
    for (items) |item| try std.testing.expect(!std.mem.startsWith(u8, item.label, "__silex_anonymous_"));
}

test "nested anonymous functions retain outer lexical completion scopes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func apply(value:int, callback:func(int) int) int { return callback(value) }
        \\func main() {
        \\    let base = 30
        \\    apply(5, func(outer:int) int {
        \\        let offset = 2
        \\        return apply(outer, func(inner:int) int {
        \\            return ba
        \\        })
        \\    })
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "return ba").? + "return ba".len;
    const context = try classifyContext(arena.allocator(), source, cursor);
    const parsed = (try parseForCompletion(arena.allocator(), source, cursor, context)).?;
    const expected = expectedTypeAt(source, parsed, cursor, context);
    try std.testing.expectEqualStrings("int", expected.?.name);
    const callables = try containingCallables(arena.allocator(), source, parsed, cursor);
    try std.testing.expectEqual(@as(usize, 3), callables.len);
    try std.testing.expectEqualStrings("outer", callables[1].parameters[0].name);
    try std.testing.expectEqualStrings("inner", callables[2].parameters[0].name);
    const locals = try visibleLocals(arena.allocator(), source, parsed, callables[0].position, cursor);
    try std.testing.expectEqualStrings("base", locals[0].name);
    try std.testing.expectEqualStrings("offset", locals[1].name);
}

test "complete loop element members inside string interpolation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Attribute { var key:str; var value:str }
        \\class Element {
        \\    var attributes:Attribute[]
        \\    public func get_attributes() Attribute[] { return self.attributes }
        \\}
        \\func format(e:Element) str {
        \\    var result = ""
        \\    for attr in e.get_attributes() {
        \\        result = result + " $(attr.)"
        \\    }
        \\    return result
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "attr.)").? + "attr.".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "key"));
    try std.testing.expect(contains(items, "value"));
}

test "preserve local member types in loops and mutable methods" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const child_source =
        \\struct Tag {
        \\    var tags:Tag[]
        \\    func to_str() str {
        \\        var content = ""
        \\        for child in self.tags {
        \\            content = content + child.
        \\        }
        \\        return content
        \\    }
        \\}
    ;
    const child_cursor = std.mem.indexOf(u8, child_source, "child.").? + "child.".len;
    const child_items = try itemsAt(arena.allocator(), child_source, child_cursor, .trigger_character);
    try std.testing.expect(contains(child_items, "to_str"));

    const array_source =
        \\struct Tag {
        \\    var attr_names:str[]
        \\    func set_attribute() {
        \\        self.attr_names.
        \\    }
        \\}
    ;
    const array_cursor = std.mem.indexOf(u8, array_source, "attr_names.").? + "attr_names.".len;
    const array_items = try itemsAt(arena.allocator(), array_source, array_cursor, .trigger_character);
    try std.testing.expect(contains(array_items, "append"));
    try std.testing.expect(contains(array_items, "prepend"));
    try std.testing.expect(contains(array_items, "count"));
}

test "preserve specialized field types during member completion" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Dictionary<K, V> {
        \\    func values() V[] { return [] }
        \\    func count() int { return 0 }
        \\}
        \\struct Store {
        \\    var attributes:Dictionary<str, str>
        \\    func inspect() {
        \\        self.attributes.
        \\    }
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "attributes.").? + "attributes.".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "values"));
    try std.testing.expect(contains(items, "count"));
    try std.testing.expect(!contains(items, "Dictionary"));
}

test "preserve tuple element types in query-style for destructuring" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\class Query<Pattern> {}
        \\struct Rotator3D { func rotate() {} }
        \\struct Transform3D {}
        \\func rotate_entities(rotators:Query<(@Rotator3D, &Transform3D)>) {
        \\    for (rotator, transform) in rotators {
        \\        rotator.
        \\    }
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "rotator.").? + "rotator.".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "rotate"));
}

test "complete an inline cascade" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Tag {
        \\    private var hidden:int
        \\    public var visible:int
        \\    private func secret() {}
        \\    public func show() {}
        \\}
        \\func main() { var tag = Tag().. }
    ;
    const cursor = std.mem.indexOf(u8, source, ".. }").? + "..".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "visible"));
    try std.testing.expect(contains(items, "show"));
}

test "complete test-local helpers only inside their block" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\test "local" {
        \\    func helper() int { return 42 }
        \\    print(hel)
        \\}
        \\test "other" {
        \\    print(hel)
        \\}
        \\func main() { print(hel) }
    ;
    const first = std.mem.indexOf(u8, source, "print(hel)").? + "print(hel".len;
    const second_start = std.mem.indexOfPos(u8, source, first, "print(hel)").?;
    const second = second_start + "print(hel".len;
    const outside_start = std.mem.lastIndexOf(u8, source, "print(hel)").?;
    const outside = outside_start + "print(hel".len;

    const local_items = try itemsAt(arena.allocator(), source, first, .invoked);
    try std.testing.expect(contains(local_items, "helper"));
    for (local_items) |item| try std.testing.expect(!std.mem.startsWith(u8, item.label, "__silex_test_"));
    try std.testing.expect(!contains(try itemsAt(arena.allocator(), source, second, .invoked), "helper"));
    try std.testing.expect(!contains(try itemsAt(arena.allocator(), source, outside, .invoked), "helper"));
}

test "insert nominal types without constructor parentheses in anonymous parameters" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct MyTask {}
        \\func submit(callback:func(MyTask)) {}
        \\func main() {
        \\    submit(func(task:MyTa) {})
        \\}
    ;
    const cursor = std.mem.lastIndexOf(u8, source, "MyTa").? + "MyTa".len;
    const context = try classifyContext(arena.allocator(), source, cursor);
    try std.testing.expectEqual(ContextKind.type_name, context.kind);
    try std.testing.expect((try parseForCompletion(arena.allocator(), source, cursor, context)) != null);
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    const item_index = indexOf(items, "MyTask");
    try std.testing.expect(item_index != null);
    const item = items[item_index.?];
    try std.testing.expectEqualStrings("MyTask", item.insertText.?);
    try std.testing.expect(item.insertTextFormat == null);
}

test "distinguish function values from calls in argument completion" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const callback_source =
        \\struct MyTask {}
        \\func handle(task:MyTask) {}
        \\func submit(task:MyTask, callback:func(MyTask)) {}
        \\func main() { submit(MyTask(), han) }
    ;
    const callback_cursor = std.mem.indexOf(u8, callback_source, "han)").? + "han".len;
    const callback_items = try itemsAt(arena.allocator(), callback_source, callback_cursor, .invoked);
    const callback = callback_items[indexOf(callback_items, "handle").?];
    try std.testing.expectEqualStrings("handle", callback.insertText.?);
    try std.testing.expect(callback.insertTextFormat == null);

    const value_source =
        \\struct MyTask {}
        \\func make() MyTask { return MyTask() }
        \\func consume(task:MyTask) {}
        \\func main() { consume(mak) }
    ;
    const value_cursor = std.mem.indexOf(u8, value_source, "mak)").? + "mak".len;
    const value_items = try itemsAt(arena.allocator(), value_source, value_cursor, .invoked);
    const value = value_items[indexOf(value_items, "make").?];
    try std.testing.expectEqualStrings("make()", value.insertText.?);
}

test "complete a terminal member expression from its static type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const inferred_source =
        \\protocol Printable { func to_str() str }
        \\struct Vec3 : Printable {
        \\    var x:float
        \\    var y:float
        \\    var z:float
        \\    func to_str() str { return "vec" }
        \\}
        \\func main() {
        \\    var pos = Vec3()
        \\    pos.
        \\    print(pos.to_str())
        \\}
    ;
    const inferred_cursor = std.mem.indexOf(u8, inferred_source, "pos.\n").? + "pos.".len;
    const inferred = try itemsAt(arena.allocator(), inferred_source, inferred_cursor, .trigger_character);
    try std.testing.expectEqual(@as(usize, 4), inferred.len);
    try std.testing.expect(contains(inferred, "x"));
    try std.testing.expect(contains(inferred, "y"));
    try std.testing.expect(contains(inferred, "z"));
    try std.testing.expect(contains(inferred, "to_str"));

    const protocol_source =
        \\protocol Printable { func to_str() str }
        \\struct Vec3 : Printable {
        \\    var x:float
        \\    var y:float
        \\    var z:float
        \\    func to_str() str { return "vec" }
        \\}
        \\func main() {
        \\    var pos:Printable = Vec3()
        \\    pos.
        \\    print(pos.to_str())
        \\}
    ;
    const protocol_cursor = std.mem.indexOf(u8, protocol_source, "pos.\n").? + "pos.".len;
    const protocol_items = try itemsAt(arena.allocator(), protocol_source, protocol_cursor, .trigger_character);
    try std.testing.expectEqual(@as(usize, 1), protocol_items.len);
    try std.testing.expect(contains(protocol_items, "to_str"));
    try std.testing.expect(!contains(protocol_items, "x"));
}

test "complete named tuple members returned by a function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func size() (width:int, height:int) { return (width:1280, height:720) }
        \\func main() {
        \\    let value = size()
        \\    print(value.)
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "value.").? + "value.".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expectEqual(@as(usize, 2), items.len);
    try std.testing.expect(contains(items, "width"));
    try std.testing.expect(contains(items, "height"));
    const width = items[indexOf(items, "width").?];
    try std.testing.expectEqualStrings("width:int", width.detail);
}

test "do not invent members for positional tuples" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func pair() (int, int) { return (1, 2) }
        \\func main() { print(pair().) }
    ;
    const cursor = std.mem.indexOf(u8, source, "pair().").? + "pair().".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expectEqual(@as(usize, 0), items.len);
}

test "complete self members immediately after the dot" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const assignment_source =
        \\struct MyTask {
        \\    var name:str
        \\    func execute() {
        \\        self. = "done"
        \\    }
        \\}
        \\func main() {}
    ;
    const assignment_cursor = std.mem.indexOf(u8, assignment_source, "self.").? + "self.".len;
    const assignment_items = try itemsAt(arena.allocator(), assignment_source, assignment_cursor, .trigger_character);
    try std.testing.expect(contains(assignment_items, "name"));
    try std.testing.expect(contains(assignment_items, "execute"));

    const expression_source =
        \\struct MyTask {
        \\    var name:str
        \\    func execute() {
        \\        self.
        \\    }
        \\}
        \\func main() {}
    ;
    const expression_cursor = std.mem.indexOf(u8, expression_source, "self.").? + "self.".len;
    const expression_items = try itemsAt(arena.allocator(), expression_source, expression_cursor, .trigger_character);
    try std.testing.expect(contains(expression_items, "name"));
    try std.testing.expect(contains(expression_items, "execute"));
}

test "complete a dynamic protocol value with only its requirements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\protocol Drawable { func draw(); func label() str }
        \\struct Sprite : Drawable {
        \\    func draw() {}
        \\    func label() str { return "sprite" }
        \\    func hidden() {}
        \\}
        \\func main() {
        \\    var value:Drawable = Sprite()
        \\    value.draw()
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "value.draw").? + "value.dr".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "draw"));
    try std.testing.expect(!contains(items, "hidden"));
}

test "complete local extension methods on their exact target" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Value {}
        \\extend Value { func extra() int { return 1 } }
        \\func main() {
        \\    let value = Value()
        \\    value.extra()
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "value.extra").? + "value.ex".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "extra"));
}

test "complete methods supplied by a protocol conformance extension" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\protocol Drawable { func draw() str }
        \\struct Sprite {}
        \\extend Sprite : Drawable { func draw() str { return "sprite" } }
        \\func main() {
        \\    let sprite = Sprite()
        \\    sprite.draw()
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "sprite.draw").? + "sprite.dr".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "draw"));
}

test "complete direct nested types from their declaring owner" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Api {
        \\    struct Entry {}
        \\    static class State { public static var count:int = 0 }
        \\}
        \\func main() { print(Api.) }
    ;
    const cursor = std.mem.indexOf(u8, source, "Api.)").? + "Api.".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "Entry"));
    try std.testing.expect(contains(items, "State"));
}

test "prioritize visible symbols before a valid statement keyword" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct image {}
        \\func initialize() int { return 1 }
        \\func main() {
        \\    let image_count:int = 3
        \\    if true {}
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "if true").? + 1;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(indexOf(items, "image_count").? < indexOf(items, "if").?);
    try std.testing.expect(indexOf(items, "image").? < indexOf(items, "if").?);
    try std.testing.expect(indexOf(items, "initialize").? < indexOf(items, "if").?);
}

test "complete mutex in statement position" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source = "func main() { mut }";
    const cursor = std.mem.indexOf(u8, source, "mut").? + 3;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "mutex"));
}

test "treat interpolation as an expression rather than a statement" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func main() {
        \\    let image_count:int = 3
        \\    print("$(image_count)")
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "image_count)").? + 1;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "image_count"));
    try std.testing.expect(!contains(items, "if"));
}

test "complete a try error binding inside an interpolation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Error { let message:str }
        \\func test(fails:bool) Result<int, Error> {
        \\    if fails { return Result<int, Error>.failure(Error(message:"Oops")) }
        \\    return Result<int, Error>.success(10)
        \\}
        \\func main() {
        \\    if true {
        \\        let erased = Error(message:"old")
        \\    }
        \\    var value = try test(true) else error {
        \\        print("Error: $(er)")
        \\        return
        \\    }
        \\    print(er)
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "$(er)").? + "$(er".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "error"));
    try std.testing.expect(!contains(items, "erased"));
    const error_item = items[indexOf(items, "error").?];
    try std.testing.expectEqual(CompletionKind.variable, error_item.kind);
    try std.testing.expectEqualStrings("error:Error", error_item.detail);
    try std.testing.expectEqualStrings("error", error_item.insertText.?);

    const outside_cursor = std.mem.indexOf(u8, source, "print(er)").? + "print(er".len;
    const outside_items = try itemsAt(arena.allocator(), source, outside_cursor, .invoked);
    try std.testing.expect(!contains(outside_items, "error"));
}

test "complete fundamental and nominal names only in a type position" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source = "struct Image {} func bar(value:float32) {}";
    const cursor = std.mem.indexOf(u8, source, "float32").? + 1;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "float"));
    try std.testing.expect(contains(items, "float32"));
    try std.testing.expect(contains(items, "float64"));
    try std.testing.expect(!contains(items, "func"));
}

test "complete declaration keywords from partial module input" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const function_items = try itemsAt(arena.allocator(), "f", 1, .invoked);
    try std.testing.expect(contains(function_items, "func"));

    const class_items = try itemsAt(arena.allocator(), "c", 1, .invoked);
    try std.testing.expect(contains(class_items, "class"));

    const structure_items = try itemsAt(arena.allocator(), "s", 1, .invoked);
    try std.testing.expect(contains(structure_items, "struct"));
    try std.testing.expect(contains(structure_items, "static"));
}

test "complete every accessible local type after a colon" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Vec3 {}
        \\class State {}
        \\enum Axis { x }
        \\func test(value:) {}
    ;
    const cursor = std.mem.indexOf(u8, source, "value:").? + "value:".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "int"));
    try std.testing.expect(contains(items, "float"));
    try std.testing.expect(contains(items, "Vec3"));
    try std.testing.expect(contains(items, "State"));
    try std.testing.expect(contains(items, "Axis"));
    try std.testing.expect(!contains(items, "func"));
}

test "complete an incomplete function return and its generic type arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root_source =
        \\struct Error { let message:str }
        \\func test() Res
        \\func main() {}
    ;
    const root_cursor = std.mem.indexOf(u8, root_source, "Res").? + "Res".len;
    const root_items = try itemsAt(allocator, root_source, root_cursor, .invoked);
    try std.testing.expect(contains(root_items, "Result"));
    try std.testing.expect(!contains(root_items, "Error"));
    try std.testing.expect(!contains(root_items, "int"));
    try std.testing.expect(!contains(root_items, "print"));
    const result = root_items[indexOf(root_items, "Result").?];
    try std.testing.expectEqual(CompletionKind.enum_type, result.kind);
    try std.testing.expectEqualStrings("Result", result.insertText.?);

    const empty_source = "struct Error { let message:str }\n" ++
        "func test() " ++
        "\nfunc main() {}";
    const empty_cursor = std.mem.indexOf(u8, empty_source, "() \n").? + "() ".len;
    const empty_items = try itemsAt(allocator, empty_source, empty_cursor, .invoked);
    try std.testing.expect(contains(empty_items, "Result"));
    try std.testing.expect(contains(empty_items, "Error"));
    try std.testing.expect(contains(empty_items, "int"));
    try std.testing.expect(!contains(empty_items, "print"));

    const generic_source =
        \\struct Error { let message:str }
        \\func test() Result<int, Er
        \\func main() {}
    ;
    const generic_cursor = std.mem.indexOf(u8, generic_source, ", Er").? + ", Er".len;
    const generic_items = try itemsAt(allocator, generic_source, generic_cursor, .invoked);
    try std.testing.expect(contains(generic_items, "Error"));
    try std.testing.expect(!contains(generic_items, "print"));
    const local_error = generic_items[indexOf(generic_items, "Error").?];
    try std.testing.expectEqual(CompletionKind.structure, local_error.kind);
    try std.testing.expectEqualStrings("Error", local_error.insertText.?);
}

test "complete a return expression from its exact result type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Error { let message:str }
        \\func number() int { return 1 }
        \\func test(error:bool) Result<int, Error> {
        \\    return Re
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "return Re").? + "return Re".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "Result"));
    try std.testing.expect(!contains(items, "Error"));
    try std.testing.expect(!contains(items, "error"));
    try std.testing.expect(!contains(items, "number"));
    const result = items[indexOf(items, "Result").?];
    try std.testing.expectEqual(CompletionKind.enum_type, result.kind);
    try std.testing.expectEqualStrings("Result", result.insertText.?);
}

test "complete specialized intrinsic Result variants" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Error { let message:str }
        \\func test() Result<int, Error> {
        \\    return Result<int, Error>.
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "Error>.").? + "Error>.".len;
    const items = try itemsAt(allocator, source, cursor, .invoked);
    try std.testing.expectEqual(@as(usize, 2), items.len);

    const success = items[indexOf(items, "success").?];
    try std.testing.expectEqual(CompletionKind.enum_member, success.kind);
    try std.testing.expectEqualStrings("success(int) Result<int, Error>", success.detail);
    try std.testing.expectEqualStrings("success($0)", success.insertText.?);
    try std.testing.expectEqual(@as(?u8, 2), success.insertTextFormat);

    const failure = items[indexOf(items, "failure").?];
    try std.testing.expectEqual(CompletionKind.enum_member, failure.kind);
    try std.testing.expectEqualStrings("failure(Error) Result<int, Error>", failure.detail);
    try std.testing.expectEqualStrings("failure($0)", failure.insertText.?);
    try std.testing.expectEqual(@as(?u8, 2), failure.insertTextFormat);

    const void_source =
        \\struct Error {}
        \\func test() Result<void, Error> {
        \\    return Result<void, Error>.
        \\}
    ;
    const void_cursor = std.mem.indexOf(u8, void_source, "Error>.").? + "Error>.".len;
    const void_items = try itemsAt(allocator, void_source, void_cursor, .invoked);
    const void_success = void_items[indexOf(void_items, "success").?];
    try std.testing.expectEqualStrings("success() Result<void, Error>", void_success.detail);
    try std.testing.expectEqualStrings("success()", void_success.insertText.?);
    try std.testing.expect(void_success.insertTextFormat == null);
}

test "complete specialized intrinsic Result arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Error { let message:str }
        \\func test(error:bool, cause:Error, value:int) Result<int, Error> {
        \\    if error { return Result<int, Error>.failure(Er) }
        \\    return Result<int, Error>.success()
        \\}
    ;

    const failure_cursor = std.mem.indexOf(u8, source, "failure(Er").? + "failure(Er".len;
    const failure_items = try itemsAt(allocator, source, failure_cursor, .invoked);
    try std.testing.expect(contains(failure_items, "Error"));
    try std.testing.expect(!contains(failure_items, "Result"));
    try std.testing.expect(!contains(failure_items, "error"));
    try std.testing.expect(!contains(failure_items, "value"));

    const empty_failure_source =
        \\struct Error { let message:str }
        \\func test(error:bool, cause:Error) Result<int, Error> {
        \\    return Result<int, Error>.failure()
        \\}
    ;
    const empty_failure_cursor = std.mem.indexOf(u8, empty_failure_source, "failure(").? + "failure(".len;
    const empty_failure_items = try itemsAt(allocator, empty_failure_source, empty_failure_cursor, .invoked);
    try std.testing.expect(contains(empty_failure_items, "Error"));
    try std.testing.expect(contains(empty_failure_items, "cause"));
    try std.testing.expect(!contains(empty_failure_items, "error"));

    const success_cursor = std.mem.indexOf(u8, source, "success(").? + "success(".len;
    const success_items = try itemsAt(allocator, source, success_cursor, .invoked);
    try std.testing.expect(contains(success_items, "value"));
    try std.testing.expect(!contains(success_items, "Error"));
    try std.testing.expect(!contains(success_items, "cause"));
}

test "complete local relations in partial structure and class declarations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const structure_source =
        \\protocol Runnable { func run() }
        \\class Base {}
        \\struct MyTask : Run
    ;
    const structure_items = try itemsAt(
        arena.allocator(),
        structure_source,
        structure_source.len,
        .invoked,
    );
    try std.testing.expect(contains(structure_items, "Runnable"));
    try std.testing.expect(!contains(structure_items, "return"));

    const class_source =
        \\protocol Runnable { func run() }
        \\class Base {}
        \\class Child : Ba
    ;
    const class_items = try itemsAt(arena.allocator(), class_source, class_source.len, .invoked);
    try std.testing.expect(contains(class_items, "Base"));

    const conformance_source =
        \\protocol Runnable { func run() }
        \\class Base {}
        \\class Child : Base, Run
    ;
    const conformance_items = try itemsAt(
        arena.allocator(),
        conformance_source,
        conformance_source.len,
        .invoked,
    );
    try std.testing.expect(contains(conformance_items, "Runnable"));
}

test "complete a for source expression and self members" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Node {
        \\    var level:int
        \\    var children:Node[]
        \\    func build() {
        \\        for i in 0...s {
        \\        }
        \\    }
        \\}
    ;

    const source_cursor = std.mem.indexOf(u8, source, "0...s").? + "0...s".len;
    const source_items = try itemsAt(arena.allocator(), source, source_cursor, .invoked);
    try std.testing.expect(contains(source_items, "self"));
    try std.testing.expect(!contains(source_items, "return"));

    const member_source =
        \\struct Node {
        \\    var level:int
        \\    var children:Node[]
        \\    func build() {
        \\        for i in 0...self. {
        \\        }
        \\    }
        \\}
    ;
    const member_cursor = std.mem.indexOf(u8, member_source, "self.").? + "self.".len;
    const member_items = try itemsAt(arena.allocator(), member_source, member_cursor, .trigger_character);
    try std.testing.expect(contains(member_items, "level"));
}

test "keep for bindings inside their loop body" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func build(values:int[]) {
        \\    for child in values {
        \\        child
        \\    }
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "        child").? + "        child".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "child"));
}

test "infer custom iterator bindings from next optional payload" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Item { func inspect() {} }
        \\struct Cursor { func next() Item? { return null } }
        \\func build(cursor:Cursor) {
        \\    for item in cursor {
        \\        item.
        \\    }
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "item.").? + "item.".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "inspect"));
}

test "infer string iterator bindings as uint32 scalars" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func build() {
        \\    for scalar in "A🙂é" {
        \\        print(scalar)
        \\    }
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "scalar)").? + "scalar".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    const scalar = items[indexOf(items, "scalar").?];
    try std.testing.expectEqualStrings("scalar:uint32", scalar.detail);
}

test "anonymous scopes expose locals only before their closing brace" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func build() {
        \\    { let scoped:int = 1; sco }
        \\    sco
        \\}
    ;
    const inside_cursor = std.mem.indexOf(u8, source, "sco }").? + "sco".len;
    const inside = try itemsAt(arena.allocator(), source, inside_cursor, .invoked);
    try std.testing.expect(contains(inside, "scoped"));
    const outside_cursor = std.mem.lastIndexOf(u8, source, "sco\n").? + "sco".len;
    const outside = try itemsAt(arena.allocator(), source, outside_cursor, .invoked);
    try std.testing.expect(!contains(outside, "scoped"));
}

test "match visible symbols containing the typed text inside a function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func available() int { return 1 }
        \\func test(value:int) {
        \\    v
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "    v").? + "    v".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "value"));
    try std.testing.expect(contains(items, "available"));
}

test "restrict an explicitly typed initializer to compatible values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Vec3 {}
        \\struct Other {}
        \\func make_vec() Vec3 { return Vec3() }
        \\func main() {
        \\    var existing:Vec3 = Vec3()
        \\    var value:Vec3 =
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "var value:Vec3 =").? + "var value:Vec3 =".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "Vec3"));
    try std.testing.expect(contains(items, "existing"));
    try std.testing.expect(contains(items, "make_vec"));
    try std.testing.expect(!contains(items, "Other"));
    try std.testing.expect(!contains(items, "true"));
}

test "complete only static members from a type receiver" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Foo {
        \\    static func Bar() {}
        \\    func instance_only() {}
        \\}
        \\func main() { Foo. }
    ;
    const cursor = std.mem.indexOf(u8, source, "Foo.").? + "Foo.".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "Bar"));
    try std.testing.expect(!contains(items, "instance_only"));
}

test "complete types after an explicit conversion operator" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source = "struct Index {} func main() { var value = 10 as int32 }";
    const cursor = std.mem.indexOf(u8, source, "int32").?;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "int"));
    try std.testing.expect(contains(items, "int8"));
    try std.testing.expect(contains(items, "int32"));
    try std.testing.expect(contains(items, "Index"));
    try std.testing.expect(!contains(items, "if"));
    try std.testing.expect(!contains(items, "value"));
}

test "complete an untyped initializer with expressions and no statement keywords" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Vector3 {}
        \\func make_value() int { return 1 }
        \\func main(input:int) {
        \\    let previous:int = 2
        \\    var x =
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "var x =").? + "var x =".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "previous"));
    try std.testing.expect(contains(items, "input"));
    try std.testing.expect(contains(items, "make_value"));
    try std.testing.expect(contains(items, "Vector3"));
    try std.testing.expect(contains(items, "true"));
    try std.testing.expect(!contains(items, "x"));
    try std.testing.expect(!contains(items, "if"));
    try std.testing.expect(!contains(items, "as"));
}

test "complete embedded file intrinsics in expressions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source = "func main() { let value = emb }";
    const cursor = std.mem.indexOf(u8, source, "emb").? + "emb".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "embed_text"));
    try std.testing.expect(contains(items, "embed_bytes"));
}

test "deduplicate overloads by labels while preserving distinct call shapes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func convert(value:int, radix:int = 10) int { return value }
        \\func convert(value:str) int { return value.count }
        \\func main() {
        \\    print(convert)
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "convert)").? + 3;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    var signatures: usize = 0;
    for (items) |item| if (item.filterText != null and std.mem.eql(u8, item.filterText.?, "convert")) {
        signatures += 1;
        try std.testing.expect(item.insertText != null);
    };
    try std.testing.expectEqual(@as(usize, 2), signatures);
    try std.testing.expect(contains(items, "convert(value:int)"));
    try std.testing.expect(contains(items, "convert(value:int, radix:int = 10)"));
    try std.testing.expect(!contains(items, "convert(value:str)"));
    var saw_default = false;
    for (items) |item| if (completionNameMatches(item, "convert") and
        std.mem.indexOf(u8, item.detail, "radix:int = 10") != null)
    {
        saw_default = true;
    };
    try std.testing.expect(saw_default);
}

test "offer omitted and explicit calls when every parameter has a default" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Settings {}
        \\func configure(settings:Settings = Settings()) {}
        \\func main() { confi }
    ;
    const cursor = std.mem.indexOf(u8, source, "confi }").? + "confi".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    var configure_count: usize = 0;
    for (items) |item| if (item.filterText != null and std.mem.eql(u8, item.filterText.?, "configure")) {
        configure_count += 1;
    };
    try std.testing.expectEqual(@as(usize, 2), configure_count);
    var saw_empty = false;
    var saw_explicit = false;
    for (items) |item| {
        if (item.filterText == null or !std.mem.eql(u8, item.filterText.?, "configure")) continue;
        saw_empty = saw_empty or std.mem.eql(u8, item.insertText.?, "configure()");
        saw_explicit = saw_explicit or std.mem.indexOf(u8, item.insertText.?, "${1:settings}") != null;
        try std.testing.expect(std.mem.indexOf(u8, item.insertText.?, "settings:") == null);
    }
    try std.testing.expect(saw_empty);
    try std.testing.expect(saw_explicit);
}

test "offer required parameters before the complete defaulted signature" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func schedule(stage:int, callback:func(), priority:int = 0) {}
        \\func callback() {}
        \\func main() { sche }
    ;
    const cursor = std.mem.indexOf(u8, source, "sche }").? + "sche".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    var matches: std.ArrayList(CompletionItem) = .empty;
    for (items) |item| if (item.filterText != null and std.mem.eql(u8, item.filterText.?, "schedule")) {
        try matches.append(arena.allocator(), item);
    };
    try std.testing.expectEqual(@as(usize, 2), matches.items.len);
    try std.testing.expectEqualStrings("schedule(${1:stage}, ${2:callback})$0", matches.items[0].insertText.?);
    try std.testing.expectEqualStrings("schedule(${1:stage}, ${2:callback}, ${3:priority})$0", matches.items[1].insertText.?);
}

test "recover member completion in an unfinished conditional" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Input { func pressed() bool { return true } }
        \\func main() {
        \\    let input = Input()
        \\    if input.
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "input.\n").? + "input.".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "pressed"));
}

test "hide reserved compiler hooks from local member completion" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\class Application {
        \\    internal func __silex_add_system() {}
        \\    func add_system() {}
        \\}
        \\func main() { Application(). }
    ;
    const cursor = std.mem.indexOf(u8, source, ". }").? + 1;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "add_system"));
    try std.testing.expect(!contains(items, "__silex_add_system"));
}

test "filter overload signatures with arguments already present" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func convert(value:int, radix:int = 10) int { return value }
        \\func convert(value:str) int { return value.count }
        \\func convert(left:int, right:int) int { return left + right }
        \\func main() { print(convert(1)) }
    ;
    const cursor = std.mem.indexOf(u8, source, "convert(1)").? + 3;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    var signatures: usize = 0;
    for (items) |item| if (std.mem.eql(u8, item.label, "convert")) {
        signatures += 1;
        try std.testing.expect(std.mem.indexOf(u8, item.detail, "value:int") != null);
        try std.testing.expect(std.mem.indexOf(u8, item.detail, "radix:int = 10") != null);
    };
    try std.testing.expectEqual(@as(usize, 1), signatures);
}

test "complete remaining call parameter labels before expression symbols" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Vec3 {
        \\    init(x:float, y:float, z:float) {}
        \\}
        \\func main() {
        \\    let value = Vec3(x:0, )
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "x:0, ").? + "x:0, ".len;
    const items = try parameterItemsAt(arena.allocator(), source, cursor);
    try std.testing.expectEqual(@as(usize, 2), items.len);
    try std.testing.expectEqualStrings("y", items[0].label);
    try std.testing.expectEqualStrings("y:float", items[0].detail);
    try std.testing.expectEqualStrings("y:", items[0].insertText.?);
    try std.testing.expectEqualStrings("z", items[1].label);
}

test "complete the next method parameter after a nested positional argument" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\static class Asset {
        \\    static func javascript(source:str, path:str) Asset { return Asset() }
        \\}
        \\func wrap(value:str) str { return value }
        \\func main() {
        \\    let asset = Asset.javascript(wrap("app.js"), )
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "wrap(\"app.js\"), ").? + "wrap(\"app.js\"), ".len;
    const items = try parameterItemsAt(arena.allocator(), source, cursor);
    try std.testing.expectEqual(@as(usize, 1), items.len);
    try std.testing.expectEqualStrings("path", items[0].label);
    try std.testing.expectEqualStrings("path:str", items[0].detail);
    try std.testing.expectEqualStrings("path:", items[0].insertText.?);
}

test "complete self and fundamental string members exclusively" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Vector {
        \\    var x:int
        \\    func inspect() { print(self.x) }
        \\}
        \\func main() {
        \\    let text:str = "value"
        \\    print(text.count)
        \\}
    ;
    const self_cursor = std.mem.indexOf(u8, source, "self.x").? + "self.x".len;
    const self_items = try itemsAt(arena.allocator(), source, self_cursor, .trigger_character);
    try std.testing.expectEqual(@as(usize, 1), self_items.len);
    try std.testing.expectEqualStrings("x", self_items[0].label);

    const string_cursor = std.mem.indexOf(u8, source, "text.count").? + "text.c".len;
    const string_items = try itemsAt(arena.allocator(), source, string_cursor, .trigger_character);
    try std.testing.expectEqual(@as(usize, 1), string_items.len);
    try std.testing.expectEqualStrings("count", string_items[0].label);
}

test "complete local declarations and members inside their file" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\local struct Handle {
        \\    local var value:int
        \\    local func read() int { return self.value }
        \\}
        \\local func helper() int { return 1 }
        \\func main() {
        \\    let handle = Handle(value:1)
        \\    print(handle.read() + helper())
        \\}
    ;
    const member_cursor = std.mem.indexOf(u8, source, "handle.read").? + "handle.r".len;
    const member_items = try itemsAt(arena.allocator(), source, member_cursor, .trigger_character);
    try std.testing.expect(contains(member_items, "read"));

    const helper_cursor = std.mem.indexOf(u8, source, "helper())").? + 3;
    const helper_items = try itemsAt(arena.allocator(), source, helper_cursor, .invoked);
    try std.testing.expect(contains(helper_items, "helper"));

    const internal_items = try itemsAt(arena.allocator(), "inte", "inte".len, .invoked);
    try std.testing.expect(contains(internal_items, "internal"));
    const local_items = try itemsAt(arena.allocator(), "loc", "loc".len, .invoked);
    try std.testing.expect(contains(local_items, "local"));
}

test "offer branch continuations only after a conditional block" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const conditional = "func main() { if true {} else {} }";
    const cursor = std.mem.indexOf(u8, conditional, "else").? + 2;
    const items = try itemsAt(arena.allocator(), conditional, cursor, .invoked);
    try std.testing.expect(contains(items, "elif"));
    try std.testing.expect(contains(items, "else"));

    const ordinary = "func main() { while true {} let value:int = 1 }";
    const ordinary_cursor = std.mem.indexOf(u8, ordinary, "let value").?;
    const ordinary_items = try itemsAt(arena.allocator(), ordinary, ordinary_cursor, .invoked);
    try std.testing.expect(!contains(ordinary_items, "elif"));
    try std.testing.expect(!contains(ordinary_items, "else"));
}

test "offer loop control only inside a loop" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source = "func main() { while true { break } break }";
    const inside = std.mem.indexOf(u8, source, "break").? + 1;
    const inside_items = try itemsAt(arena.allocator(), source, inside, .invoked);
    try std.testing.expect(contains(inside_items, "break"));
    const outside_start = std.mem.lastIndexOf(u8, source, "break").?;
    const outside_items = try itemsAt(arena.allocator(), source, outside_start + 1, .invoked);
    try std.testing.expect(!contains(outside_items, "break"));
    try std.testing.expect(!contains(outside_items, "continue"));
}

test "remove locals whose lexical branch ended before the cursor" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func main() {
        \\    if true {
        \\        let branch:int = 1
        \\    }
        \\    let outer:int = 2
        \\    print(outer)
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "outer)").? + "outer".len;
    const items = try itemsAt(arena.allocator(), source, cursor, .invoked);
    try std.testing.expect(contains(items, "outer"));
    try std.testing.expect(!contains(items, "branch"));
}

test "complete match payload bindings in their guard and branch only" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\enum Choice { value(int, int); empty }
        \\func inspect(choice:Choice) int {
        \\    return match choice {
        \\        value(number, _) if number > 0 => number
        \\        empty => 0
        \\    }
        \\}
    ;
    const guard_cursor = std.mem.indexOf(u8, source, "number >").? + "number".len;
    const guard_items = try itemsAt(arena.allocator(), source, guard_cursor, .invoked);
    try std.testing.expect(contains(guard_items, "number"));
    try std.testing.expect(!contains(guard_items, "_"));

    const body_start = std.mem.indexOf(u8, source, "=> number").? + 3;
    const body_items = try itemsAt(arena.allocator(), source, body_start + "number".len, .invoked);
    try std.testing.expect(contains(body_items, "number"));

    const outside_cursor = std.mem.indexOf(u8, source, "empty =>").? + "empty".len;
    const outside_items = try itemsAt(arena.allocator(), source, outside_cursor, .invoked);
    try std.testing.expect(!contains(outside_items, "number"));
}

test "return an empty list for an unresolved member receiver" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source = "func main() { print(unknown.member) }";
    const cursor = std.mem.indexOf(u8, source, "member").? + 1;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expectEqual(@as(usize, 0), items.len);
}

test "complete members after safe optional access" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Profile { let name:str; func rename(value:str) {} }
        \\func inspect(profile:Profile?) { print(profile?.) }
    ;
    const cursor = std.mem.indexOf(u8, source, "?.").? + 2;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(contains(items, "name"));
    try std.testing.expect(contains(items, "rename"));
}

test "safe completion preserves directly nested optional layers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\struct Box { let value:int }
        \\func inspect(box:Box??) { print(box?.) }
    ;
    const cursor = std.mem.indexOf(u8, source, "?.").? + 2;
    const items = try itemsAt(arena.allocator(), source, cursor, .trigger_character);
    try std.testing.expect(!contains(items, "value"));
}

test "do not complete ordinary string text or comments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const string_source = "func main() { print(\"value";
    try std.testing.expectEqual(@as(usize, 0), (try itemsAt(arena.allocator(), string_source, string_source.len, .invoked)).len);
    const comment_source = "func main() { // val";
    try std.testing.expectEqual(@as(usize, 0), (try itemsAt(arena.allocator(), comment_source, comment_source.len, .invoked)).len);
}
