const std = @import("std");
const Ast = @import("../Ast.zig");
const Strings = @import("../Strings.zig");
const Generics = @import("Generics.zig");

pub fn parse(parser: anytype, is_public: bool, is_internal: bool) !Ast.Enum {
    const position = parser.current.position;
    try parser.advance();
    if (parser.current.tag != .identifier) return parser.fail("expected enum name");
    const name = parser.current.lexeme;
    const name_position = parser.current.position;
    _ = try parser.internTypeName(name);
    try parser.advance();
    const type_parameters = try Generics.parseTypeParameters(parser);
    const enclosing_type_parameters = parser.type_parameters;
    parser.type_parameters = type_parameters;
    defer parser.type_parameters = enclosing_type_parameters;
    var raw_type: ?Ast.Type = null;
    if (parser.current.tag == .colon) {
        try parser.advance();
        raw_type = switch (parser.current.tag) {
            .keyword_int => .int,
            .keyword_str => .str,
            else => return parser.fail("raw enum type must be 'int' or 'str'"),
        };
        try parser.advance();
        if (type_parameters.len != 0) return parser.failAt(name_position, "raw enums cannot be generic");
    }
    try parser.expect(.left_brace, "expected '{' after enum name");
    var variants: std.ArrayList(Ast.EnumVariant) = .empty;
    while (parser.current.tag != .right_brace and parser.current.tag != .end) {
        if (parser.current.tag != .identifier) return parser.fail("expected enum variant name");
        const variant_name = parser.current.lexeme;
        const variant_position = parser.current.position;
        try parser.advance();
        var associated_types: std.ArrayList(Ast.Type) = .empty;
        if (parser.current.tag == .left_parenthesis) {
            if (raw_type != null) return parser.fail("raw enum variants cannot carry associated values");
            try parser.advance();
            if (parser.current.tag == .right_parenthesis) return parser.fail("an empty enum variant does not use parentheses");
            while (true) {
                try associated_types.append(parser.allocator, try parser.parseType());
                if (parser.current.tag != .comma) break;
                try parser.advance();
                if (parser.current.tag == .right_parenthesis) return parser.fail("expected associated value type after ','");
            }
            try parser.expect(.right_parenthesis, "expected ')' after associated value types");
        }
        var raw_value: ?Ast.EnumRawValue = null;
        if (raw_type) |expected| {
            if (parser.current.tag != .equal) return parser.fail("raw enum variant requires a literal value");
            try parser.advance();
            raw_value = try parseRawValue(parser, expected);
            if (parser.current.tag != .semicolon and parser.current.tag != .right_brace and parser.current.tag != .end and
                parser.current.position.line == parser.previous.position.line)
            {
                return parser.fail("raw enum value must be one literal");
            }
        } else if (parser.current.tag == .equal) {
            return parser.fail("associated enum variants cannot declare raw values");
        }
        for (variants.items) |variant| if (std.mem.eql(u8, variant.name, variant_name)) {
            return parser.failAt(variant_position, "enum variant is already declared");
        };
        if (raw_value) |value| for (variants.items) |variant| {
            if (rawValueEqual(value, variant.raw_value.?)) return parser.failAt(variant_position, "raw enum value is already used by another variant");
        };
        try variants.append(parser.allocator, .{
            .position = variant_position,
            .name = variant_name,
            .associated_types = try associated_types.toOwnedSlice(parser.allocator),
            .raw_value = raw_value,
        });
        try parser.expectStatementTerminator();
    }
    try parser.expect(.right_brace, "expected '}' after enum variants");
    if (variants.items.len == 0) return parser.failAt(name_position, "an enum requires at least one variant");
    return .{
        .is_public = is_public,
        .is_internal = is_internal,
        .position = position,
        .name_position = name_position,
        .name = name,
        .type_parameters = type_parameters,
        .raw_type = raw_type,
        .variants = try variants.toOwnedSlice(parser.allocator),
    };
}

fn parseRawValue(parser: anytype, expected: Ast.Type) !Ast.EnumRawValue {
    if (expected == .str) {
        if (parser.current.tag != .string) return parser.fail("raw enum value must be a 'str' literal");
        const value = try Strings.decode(parser.allocator, parser.current.lexeme);
        try parser.advance();
        return .{ .string = value };
    }
    const negative = parser.current.tag == .minus;
    if (negative) try parser.advance();
    if (parser.current.tag != .integer) return parser.fail("raw enum value must be an 'int' literal");
    const magnitude = parseMagnitude(parser.current.lexeme) catch return parser.fail("raw enum integer is outside the range of 'int'");
    if (!negative and magnitude > std.math.maxInt(i64)) return parser.fail("raw enum integer is outside the range of 'int'");
    const value: i64 = if (negative)
        if (magnitude == @as(u64, 1) << 63) std.math.minInt(i64) else -@as(i64, @intCast(magnitude))
    else
        @intCast(magnitude);
    try parser.advance();
    return .{ .integer = value };
}

fn parseMagnitude(lexeme: []const u8) !u64 {
    var digits_buffer: [256]u8 = undefined;
    if (lexeme.len > digits_buffer.len) return error.InvalidInteger;
    var length: usize = 0;
    for (lexeme) |character| if (character != '_') {
        digits_buffer[length] = character;
        length += 1;
    };
    const normalized = digits_buffer[0..length];
    const prefix = if (normalized.len >= 2 and normalized[0] == '0') normalized[1] else 0;
    const base: u8 = switch (prefix) {
        'b', 'B' => 2,
        'o', 'O' => 8,
        'x', 'X' => 16,
        else => 10,
    };
    const digits = if (base == 10) normalized else normalized[2..];
    const magnitude = try std.fmt.parseInt(u64, digits, base);
    if (magnitude > @as(u64, 1) << 63) return error.InvalidInteger;
    return magnitude;
}

fn rawValueEqual(left: Ast.EnumRawValue, right: Ast.EnumRawValue) bool {
    return switch (left) {
        .integer => |value| switch (right) {
            .integer => |other| value == other,
            else => false,
        },
        .string => |value| switch (right) {
            .string => |other| std.mem.eql(u8, value, other),
            else => false,
        },
    };
}
