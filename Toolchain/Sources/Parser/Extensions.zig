const std = @import("std");
const Ast = @import("../Ast.zig");

pub fn parse(self: anytype) !Ast.Extension {
    const position = self.current.position;
    try self.advance();
    const target_position = self.current.position;
    const target = try self.parseType();
    var conformances: std.ArrayList(Ast.Type) = .empty;
    if (self.current.tag == .colon) {
        try self.advance();
        while (true) {
            try conformances.append(self.allocator, try self.parseType());
            if (self.current.tag != .comma) break;
            try self.advance();
        }
    }
    try self.expect(.left_brace, "expected '{' after extension target");
    var methods: std.ArrayList(Ast.Function) = .empty;
    while (self.current.tag != .right_brace and self.current.tag != .end) {
        if (self.current.tag == .keyword_override) return self.fail("extension methods cannot declare override");
        var is_public = false;
        var is_internal = false;
        var is_private = false;
        var explicit = false;
        if (self.current.tag == .keyword_public or self.current.tag == .keyword_internal or
            self.current.tag == .keyword_private or self.current.tag == .keyword_protected)
        {
            explicit = true;
            if (self.current.tag == .keyword_protected) return self.fail("extension methods cannot be protected");
            is_public = self.current.tag == .keyword_public;
            is_internal = self.current.tag == .keyword_internal;
            is_private = self.current.tag == .keyword_private;
            try self.advance();
        }
        var is_static = false;
        if (self.current.tag == .keyword_static) {
            is_static = true;
            try self.advance();
        }
        if (self.current.tag != .keyword_func) return self.fail("an extension may declare methods only");
        var method = try self.parseFunction(is_public, is_internal);
        method.is_static = is_static;
        method.is_private = is_private;
        method.visibility_explicit = explicit;
        try methods.append(self.allocator, method);
    }
    try self.expect(.right_brace, "expected '}' after extension methods");
    return .{
        .position = position,
        .target_position = target_position,
        .target = target,
        .conformances = try conformances.toOwnedSlice(self.allocator),
        .methods = try methods.toOwnedSlice(self.allocator),
    };
}
