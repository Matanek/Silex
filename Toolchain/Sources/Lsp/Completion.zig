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
    const keyword: u8 = 14;
};

const ContextKind = enum {
    none,
    member,
    type_name,
    use_path,
    module_declaration,
    structure_declaration,
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
    const program = try parseForCompletion(allocator, source, cursor, context);
    const expected_type = if (program) |parsed| expectedTypeAt(source, parsed, cursor, context) else null;

    switch (context.kind) {
        .member => if (program) |parsed| try appendMembers(
            allocator,
            &candidates,
            source,
            parsed,
            cursor,
            context,
        ),
        .type_name => {
            for (builtin_types) |name| try appendCandidate(allocator, &candidates, context, .{
                .label = name,
                .kind = CompletionKind.keyword,
                .detail = "Silex fundamental type",
            }, 10, false);
            if (program) |parsed| for (parsed.structures) |structure| try appendCandidate(
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
            .{ "internal", "Silex file visibility" },
            .{ "struct", "Silex value type declaration" },
            .{ "class", "Silex reference type declaration" },
            .{ "static", "Silex static class declaration" },
            .{ "protocol", "Silex nominal contract declaration" },
            .{ "enum", "Silex enumeration declaration" },
            .{ "func", "Silex function declaration" },
            .{ "extend", "Silex type extension" },
        }, 70),
        .structure_declaration => try appendKeywords(allocator, &candidates, context, &.{
            .{ "public", "Silex visibility" },
            .{ "internal", "Silex file visibility" },
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
            if (context.allow_conversion) try appendKeywords(allocator, &candidates, context, &.{
                .{ "as", "Silex explicit conversion" },
            }, 65);
        } else try appendLexicalSymbols(allocator, &candidates, source, cursor, context),
        else => {},
    }

    std.mem.sort(Candidate, candidates.items, {}, candidateLessThan);
    const result = try allocator.alloc(CompletionItem, candidates.items.len);
    for (candidates.items, 0..) |candidate, index| {
        result[index] = candidate.item;
        result[index].sortText = try std.fmt.allocPrint(allocator, "{d:0>3}-{d:0>6}", .{ candidate.priority, index });
        result[index].filterText = candidate.item.label;
        result[index].insertText = if (candidate.callable)
            try insertTextFor(allocator, candidate.item)
        else
            candidate.item.label;
        result[index].insertTextFormat = if (candidate.callable) insertTextFormatFor(candidate.item) else null;
    }
    return result;
}

pub fn insertTextFor(allocator: Allocator, item: CompletionItem) ![]const u8 {
    const signature = callableSignature(item) orelse return item.label;
    if (std.mem.startsWith(u8, signature, "()")) return std.fmt.allocPrint(allocator, "{s}()", .{item.label});
    return std.fmt.allocPrint(allocator, "{s}($0)", .{item.label});
}

pub fn insertTextFormatFor(item: CompletionItem) ?u8 {
    const signature = callableSignature(item) orelse return null;
    return if (std.mem.startsWith(u8, signature, "()")) null else 2;
}

fn callableSignature(item: CompletionItem) ?[]const u8 {
    if (item.kind != CompletionKind.method and item.kind != CompletionKind.function and
        item.kind != CompletionKind.structure and item.kind != CompletionKind.class) return null;
    if (!std.mem.startsWith(u8, item.detail, item.label)) return null;
    const signature = item.detail[item.label.len..];
    return if (std.mem.startsWith(u8, signature, "(")) signature else null;
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

    if (tokens[tokens.len - 1].tag == .dot or tokens[tokens.len - 1].tag == .question_dot) return .{
        .kind = .member,
        .prefix = prefix,
        .prefix_start = prefix_start,
        .receiver = memberReceiver(source, tokens[tokens.len - 1].start),
        .in_loop = scope.in_loop,
    };

    const nominal_relation = isNominalRelationPosition(line_tokens);
    if (isTypePosition(tokens, line_tokens, scope.pending_callable, nominal_relation)) return .{
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
    for (tokens) |token| switch (token.tag) {
        .keyword_struct, .keyword_extend => pending = .structure,
        .keyword_func, .keyword_init => {
            pending = .callable;
            pending_callable = true;
        },
        .keyword_while => pending = .loop,
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
    };
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
        .keyword_return, .keyword_if, .keyword_while => true,
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
                    return acceptsArity(parameters, arity);
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
    const type_name = resolveReceiverType(allocator, source, program, cursor, receiver) orelse return;
    if (std.mem.eql(u8, type_name, "str")) {
        try appendCandidate(allocator, candidates, context, .{
            .label = "count",
            .kind = CompletionKind.field,
            .detail = "count:int",
        }, 0, false);
        return;
    }
    const structure = findStructure(program, type_name) orelse return;
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
            if (!method.is_static or !callAcceptsParameters(source, cursor, program, method.parameters)) continue;
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

fn appendExpressionSymbols(
    allocator: Allocator,
    candidates: *std.ArrayList(Candidate),
    source: []const u8,
    program: Ast.Program,
    cursor: usize,
    context: Context,
    expected_type: ?ExpectedType,
) !void {
    const callable = containingCallable(source, program, cursor);
    if (callable) |current| {
        const locals = try visibleLocals(allocator, source, current.position, cursor);
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
        for (current.parameters) |parameter| {
            const parameter_type = typeName(program, parameter.type);
            if (!matchesExpectedType(expected_type, parameter_type)) continue;
            try appendCandidate(allocator, candidates, context, .{
                .label = parameter.name,
                .kind = CompletionKind.variable,
                .detail = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ parameter.name, parameter_type }),
            }, typedPriority(12, expected_type, parameter_type), false);
        }
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
        try appendCandidate(allocator, candidates, context, .{
            .label = function.name,
            .kind = CompletionKind.function,
            .detail = try functionSignature(allocator, source, program, function),
        }, typedPriority(25, expected_type, if (passed_as_value) "function" else return_type), !passed_as_value);
    }
    for (program.structures) |structure| {
        if (structure.is_protocol) continue;
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
    for (tokens, 0..) |token, index| {
        if (token.tag != .identifier or index == 0) continue;
        const previous = tokens[index - 1].tag;
        if (previous == .keyword_let or previous == .keyword_var) try appendCandidate(allocator, candidates, context, .{
            .label = token.lexeme,
            .kind = CompletionKind.variable,
            .detail = "Silex local binding",
        }, 10, false);
        if (previous == .keyword_func) try appendCandidate(allocator, candidates, context, .{
            .label = token.lexeme,
            .kind = CompletionKind.function,
            .detail = "Silex function",
        }, 25, true);
    }
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
    const matches = if (item.kind == CompletionKind.keyword or item.kind == CompletionKind.value)
        std.mem.startsWith(u8, item.label, context.prefix)
    else
        std.mem.indexOf(u8, item.label, context.prefix) != null;
    if (!matches) return;
    for (candidates.items, 0..) |existing, index| {
        if (!std.mem.eql(u8, existing.item.label, item.label)) continue;
        if (callable and existing.callable and !std.mem.eql(u8, existing.item.detail, item.detail)) continue;
        if (priority < existing.priority) candidates.items[index] = .{ .item = item, .priority = priority, .callable = callable };
        return;
    }
    try candidates.append(allocator, .{ .item = item, .priority = priority, .callable = callable });
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
};

fn containingCallable(source: []const u8, program: Ast.Program, cursor: usize) ?Callable {
    var result: ?Callable = null;
    for (program.functions) |function| {
        if (bodyContainsCursor(source, function.position.offset, cursor) and
            (result == null or function.position.offset > result.?.position)) result = .{
            .position = function.position.offset,
            .parameters = function.parameters,
            .return_type = function.return_type,
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

fn visibleLocals(allocator: Allocator, source: []const u8, start: usize, cursor: usize) ![]const Local {
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
                    .type_name = inferDeclarationType(tokens[index..end]),
                    .depth = depth,
                });
            },
            else => {},
        }
    }
    return locals.toOwnedSlice(allocator);
}

fn inferDeclarationType(tokens: []const Token) ?[]const u8 {
    for (tokens, 0..) |token, index| {
        if (token.tag == .colon and index + 1 < tokens.len) return tokens[index + 1].lexeme;
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

fn resolveReceiverType(
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
        return null;
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
            const locals = visibleLocals(std.heap.page_allocator, source, callable.position, cursor) catch return null;
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
    while (parts.next()) |field_name| {
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
    if (expectedCallArgumentType(source[0..context.prefix_start], program)) |type_value| return .{
        .name = typeName(program, type_value),
        .strict = true,
        .function_type = if (type_value.functionIndex() != null) type_value else null,
    };
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
    if (tokens[0].tag == .keyword_return) return if (callable) |current|
        .{ .name = typeName(program, current.return_type) }
    else
        null;
    if (tokens[0].tag == .keyword_panic) return .{ .name = "str" };
    var annotation: ?[]const u8 = null;
    var has_equal = false;
    for (tokens, 0..) |token, index| {
        if (token.tag == .colon and index + 1 < tokens.len) annotation = tokens[index + 1].lexeme;
        if (token.tag == .equal) has_equal = true;
    }
    return if (has_equal and annotation != null) .{ .name = annotation.?, .strict = true } else null;
}

fn expectedCallArgumentType(source: []const u8, program: Ast.Program) ?Ast.Type {
    const Call = struct {
        name: ?[]const u8,
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
        var selected: ?Ast.Type = null;
        for (program.functions) |function| {
            if (!std.mem.eql(u8, function.name, name) or call.argument >= function.parameters.len) continue;
            const candidate = function.parameters[call.argument].type;
            if (selected != null and selected.? != candidate) return null;
            selected = candidate;
        }
        return selected;
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

    const line_start = if (std.mem.lastIndexOfScalar(u8, source[0..context.prefix_start], '\n')) |newline|
        newline + 1
    else
        0;
    const before_prefix = std.mem.trim(u8, source[line_start..context.prefix_start], " \t\r");
    const placeholder: []const u8 = switch (context.kind) {
        .member => if (context.prefix.len != 0)
            "()"
        else if (memberFollowedByAssignment(source, cursor))
            "__completion"
        else
            "__completion()",
        .type_name => "int",
        .statement => "print(true)",
        .expression => if (before_prefix.len == 0) "print(true)" else "true",
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
        if (!context.nominal_relation) return null;
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

fn memberTypeName(program: Ast.Program, type_value: Ast.Type) []const u8 {
    return typeName(program, type_value.optionalChild() orelse type_value);
}

fn findStructure(program: Ast.Program, name: []const u8) ?Ast.Structure {
    for (program.structures) |structure| {
        if (std.mem.eql(u8, structure.name, name) or std.mem.endsWith(u8, name, structure.name)) return structure;
    }
    return null;
}

fn findStructureIndex(program: Ast.Program, name: []const u8) ?usize {
    for (program.type_names, 0..) |candidate, index| if (std.mem.eql(u8, candidate, name)) return index;
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

fn memberReceiver(source: []const u8, dot: usize) ?[]const u8 {
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
    while (start != 0 and (isIdentifierContinue(source[start - 1]) or source[start - 1] == '.')) start -= 1;
    return source[start..dot];
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
    for (items) |item| if (std.mem.eql(u8, item.label, label)) return true;
    return false;
}

fn indexOf(items: []const CompletionItem, label: []const u8) ?usize {
    for (items, 0..) |item, index| if (std.mem.eql(u8, item.label, label)) return index;
    return null;
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

test "keep overload signatures and default values distinct" {
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
    for (items) |item| if (std.mem.eql(u8, item.label, "convert")) {
        signatures += 1;
        try std.testing.expect(item.insertText != null);
    };
    try std.testing.expectEqual(@as(usize, 2), signatures);
    try std.testing.expect(std.mem.indexOf(u8, items[indexOf(items, "convert").?].detail, "radix:int = 10") != null);
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

test "complete internal declarations and members inside their file" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\internal struct Handle {
        \\    internal var value:int
        \\    internal func read() int { return self.value }
        \\}
        \\internal func helper() int { return 1 }
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

    const keyword_items = try itemsAt(arena.allocator(), "inte", "inte".len, .invoked);
    try std.testing.expect(contains(keyword_items, "internal"));
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

test "do not complete ordinary string text or comments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const string_source = "func main() { print(\"value";
    try std.testing.expectEqual(@as(usize, 0), (try itemsAt(arena.allocator(), string_source, string_source.len, .invoked)).len);
    const comment_source = "func main() { // val";
    try std.testing.expectEqual(@as(usize, 0), (try itemsAt(arena.allocator(), comment_source, comment_source.len, .invoked)).len);
}
