const std = @import("std");
const Ast = @import("../Ast.zig");
const Generics = @import("Generics.zig");

pub fn parse(parser: anytype, is_public: bool) !Ast.Use {
    const position = parser.current.position;
    try parser.expect(.keyword_use, "expected 'use'");
    if (isTypeToken(parser.current.tag) and parser.current.tag != .identifier) {
        const type_target = try parser.parseType();
        return finishTypeAlias(parser, position, type_target, is_public);
    }
    if (parser.current.tag != .identifier) return parser.fail("expected module path after 'use'");
    var implicit_alias = parser.current.lexeme;
    var implicit_alias_position = parser.current.position;
    var path = parser.current.lexeme;
    try parser.advance();
    while (parser.current.tag == .dot) {
        try parser.advance();
        if (parser.current.tag != .identifier) return parser.fail("expected name after '.' in use path");
        implicit_alias = parser.current.lexeme;
        implicit_alias_position = parser.current.position;
        path = try std.fmt.allocPrint(parser.allocator, "{s}.{s}", .{ path, parser.current.lexeme });
        try parser.advance();
    }

    if (parser.current.tag == .less) {
        const base = try parser.internTypeName(path);
        const arguments = try Generics.parseTypeArguments(parser);
        var type_target = try parser.internGenericType(position, base, arguments);
        if (parser.current.tag == .question) {
            type_target = .optional(type_target);
            try parser.advance();
        }
        return finishTypeAlias(parser, position, type_target, is_public);
    }

    var alias: ?[]const u8 = null;
    var alias_position: ?@import("../Source.zig").Position = null;
    if (parser.current.tag == .keyword_as) {
        try parser.advance();
        if (parser.current.tag != .identifier) return parser.fail("expected alias after 'as'");
        alias = parser.current.lexeme;
        alias_position = parser.current.position;
        try parser.advance();
    }
    if (is_public and alias == null) {
        alias = implicit_alias;
        alias_position = implicit_alias_position;
    }
    if (alias) |name| try validateAlias(parser, alias_position.?, name);
    try parser.expectStatementTerminator();
    return .{
        .position = position,
        .path = path,
        .alias = alias,
        .alias_position = alias_position,
        .is_public = is_public,
    };
}

fn finishTypeAlias(parser: anytype, position: @import("../Source.zig").Position, type_target: Ast.Type, is_public: bool) !Ast.Use {
    try parser.expect(.keyword_as, "type alias requires 'as'");
    if (parser.current.tag != .identifier) return parser.fail("expected alias after 'as'");
    const alias = parser.current.lexeme;
    const alias_position = parser.current.position;
    try validateAlias(parser, alias_position, alias);
    try parser.advance();
    try parser.expectStatementTerminator();
    return .{
        .position = position,
        .path = "",
        .type_target = type_target,
        .alias = alias,
        .alias_position = alias_position,
        .is_public = is_public,
    };
}

fn validateAlias(parser: anytype, position: @import("../Source.zig").Position, alias: []const u8) !void {
    if (std.mem.eql(u8, alias, "Result")) return parser.failAt(position, "'Result' is a reserved intrinsic type name");
    if (std.mem.eql(u8, alias, "map_error")) return parser.failAt(position, "'map_error' is a reserved intrinsic function name");
    if (std.mem.eql(u8, alias, "embed_text")) return parser.failAt(position, "'embed_text' is a reserved intrinsic function name");
}

fn isTypeToken(tag: anytype) bool {
    return switch (tag) {
        .keyword_void,
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
        .keyword_bool,
        .keyword_float,
        .keyword_float32,
        .keyword_float64,
        .keyword_str,
        .identifier,
        => true,
        else => false,
    };
}
