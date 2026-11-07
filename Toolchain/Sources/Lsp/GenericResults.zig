const std = @import("std");
const Ast = @import("../Ast.zig");
const Lexer = @import("../Lexer.zig").Lexer;
const Completion = @import("Completion.zig");

/// Infer a local free-function result from its supplied arguments. Unknown,
/// constrained or ambiguous calls keep the existing open completion context.
pub fn spelling(a: std.mem.Allocator, source: []const u8, program: Ast.Program, cursor: usize, expression: []const u8) ?[]const u8 {
    const call = Completion.directCall(expression) orelse return null;
    var selected: ?[]const u8 = null;
    for (program.functions) |function| {
        if (!std.mem.eql(u8, function.name, call.name) or function.type_parameters.len == 0 or call.arity > function.parameters.len) continue;
        for (function.type_parameters) |parameter| if (parameter.constraint != null) return null;
        const bindings = a.alloc(?Ast.Type, function.type_parameters.len) catch return null;
        @memset(bindings, null);
        const provided = a.alloc(bool, function.parameters.len) catch return null;
        @memset(provided, false);
        const open = std.mem.indexOfScalar(u8, expression, '(') orelse return null;
        const arguments = expression[open + 1 .. expression.len - 1];
        var lexer = Lexer.init(arguments);
        var start: usize = 0;
        var depth: usize = 0;
        var positional: usize = 0;
        var valid = true;
        while (true) {
            const token = lexer.next() catch return null;
            if (token.tag == .end or (token.tag == .comma and depth == 0)) {
                const segment = std.mem.trim(u8, arguments[start..token.start], " \t\r\n");
                if (segment.len != 0) valid = bind(a, source, program, cursor, function, segment, &positional, provided, bindings) and valid;
                start = token.end;
                if (token.tag == .end) break;
                continue;
            }
            switch (token.tag) {
                .left_parenthesis, .left_bracket, .left_brace, .less => depth += 1,
                .right_parenthesis, .right_bracket, .right_brace, .greater => depth -|= 1,
                else => {},
            }
        }
        for (provided, function.parameters) |present, parameter| valid = valid and (present or parameter.default != null);
        for (bindings) |binding| valid = valid and binding != null;
        if (!valid) continue;
        var receiver: []const u8 = "__inferred<";
        for (bindings, 0..) |binding, index| receiver = std.fmt.allocPrint(a, "{s}{s}{s}", .{
            receiver, if (index == 0) "" else ",", Completion.boundTypeSpelling(a, program, 0, "", binding.?) catch return null,
        }) catch return null;
        receiver = std.fmt.allocPrint(a, "{s}>", .{receiver}) catch return null;
        const candidate = Completion.boundTypeSpelling(a, program, bindings.len, receiver, function.return_type) catch return null;
        if (selected != null and !std.mem.eql(u8, selected.?, candidate)) return null;
        selected = candidate;
    }
    return selected;
}
fn bind(a: std.mem.Allocator, source: []const u8, program: Ast.Program, cursor: usize, function: Ast.Function, segment: []const u8, positional: *usize, provided: []bool, bindings: []?Ast.Type) bool {
    var lexer = Lexer.init(segment);
    const first = lexer.next() catch return false;
    const second = lexer.next() catch return false;
    var parameter = positional.*;
    var expression = segment;
    if (first.tag == .identifier and second.tag == .colon) {
        parameter = for (function.parameters, 0..) |candidate, index| {
            if (std.mem.eql(u8, candidate.name, first.lexeme)) break index;
        } else return false;
        expression = std.mem.trim(u8, segment[second.end..], " \t\r\n");
    } else positional.* += 1;
    if (parameter >= provided.len or provided[parameter]) return false;
    provided[parameter] = true;
    const actual = Completion.expressionTypeAt(a, source, program, cursor, expression) orelse literal(expression) orelse return false;
    return Completion.inferCallbackBinding(program, function.parameters[parameter].type, actual, bindings);
}
fn literal(expression: []const u8) ?Ast.Type {
    var lexer = Lexer.init(expression);
    const value = lexer.next() catch return null;
    if ((lexer.next() catch return null).tag != .end) return null;
    return switch (value.tag) {
        .integer => .int,
        .floating => .float32,
        .string => .str,
        .keyword_true, .keyword_false => .bool,
        else => null,
    };
}
