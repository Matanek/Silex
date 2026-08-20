const std = @import("std");
const Ast = @import("../Ast.zig");
const Uses = @import("Uses.zig");

pub fn parse(parser: anytype) !Ast.CatalogContribution {
    const position = parser.current.position;
    try parser.expect(.keyword_contribute, "expected 'contribute'");
    if (parser.current.tag != .identifier) return parser.fail("expected umbrella module path after 'contribute'");

    const target_position = parser.current.position;
    var target = parser.current.lexeme;
    try parser.advance();
    while (parser.current.tag == .dot) {
        try parser.advance();
        if (parser.current.tag != .identifier) return parser.fail("expected name after '.' in umbrella module path");
        target = try std.fmt.allocPrint(parser.allocator, "{s}.{s}", .{ target, parser.current.lexeme });
        try parser.advance();
    }

    try parser.expect(.left_brace, "expected '{' after umbrella module path");
    var uses: std.ArrayList(Ast.Use) = .empty;
    while (parser.current.tag != .right_brace) {
        if (parser.current.tag != .keyword_public) {
            return parser.fail("an umbrella contribution can only contain public use declarations");
        }
        try parser.advance();
        if (parser.current.tag != .keyword_use) {
            return parser.fail("an umbrella contribution can only contain public use declarations");
        }
        const use = try Uses.parse(parser, true);
        if (use.type_target != null) {
            return parser.failAt(use.position, "an umbrella contribution can only reexport named declarations");
        }
        try uses.append(parser.allocator, use);
    }
    try parser.advance();
    if (uses.items.len == 0) return parser.failAt(position, "an umbrella contribution cannot be empty");
    return .{
        .position = position,
        .target_position = target_position,
        .target = target,
        .uses = try uses.toOwnedSlice(parser.allocator),
    };
}
