const std = @import("std");
const Ast = @import("../Ast.zig");

pub fn parse(parser: anytype, is_public: bool, is_internal: bool) !Ast.Enum {
    const position = parser.current.position;
    try parser.advance();
    if (parser.current.tag != .identifier) return parser.fail("expected enum name");
    const name = parser.current.lexeme;
    const name_position = parser.current.position;
    _ = try parser.internTypeName(name);
    try parser.advance();
    try parser.expect(.left_brace, "expected '{' after enum name");
    var variants: std.ArrayList(Ast.EnumVariant) = .empty;
    while (parser.current.tag != .right_brace and parser.current.tag != .end) {
        if (parser.current.tag != .identifier) return parser.fail("expected enum variant name");
        const variant_name = parser.current.lexeme;
        const variant_position = parser.current.position;
        try parser.advance();
        var associated_types: std.ArrayList(Ast.Type) = .empty;
        if (parser.current.tag == .left_parenthesis) {
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
        for (variants.items) |variant| if (std.mem.eql(u8, variant.name, variant_name)) {
            return parser.failAt(variant_position, "enum variant is already declared");
        };
        try variants.append(parser.allocator, .{
            .position = variant_position,
            .name = variant_name,
            .associated_types = try associated_types.toOwnedSlice(parser.allocator),
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
        .variants = try variants.toOwnedSlice(parser.allocator),
    };
}
