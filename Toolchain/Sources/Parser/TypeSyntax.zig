const std = @import("std");
const Ast = @import("../Ast.zig");
const Collections = @import("Collections.zig");
const Generics = @import("Generics.zig");

pub fn parseParameter(self: anytype) !Ast.Parameter {
    if (self.current.tag != .identifier) return self.fail("expected parameter name");
    const position = self.current.position;
    const name = self.current.lexeme;
    if (std.mem.eql(u8, name, "map_error")) return self.failAt(position, "'map_error' is a reserved intrinsic function name");
    try self.advance();
    try self.expect(.colon, "expected ':' after parameter name");
    const mode: Ast.Parameter.Mode = switch (self.current.tag) {
        .at => mode: {
            try self.advance();
            break :mode .read;
        },
        .amp => mode: {
            try self.advance();
            break :mode .mutable;
        },
        else => .value,
    };
    const parameter_type = try parseType(self);
    const default = if (self.current.tag == .equal) default: {
        try self.advance();
        break :default try self.parseExpression(false);
    } else null;
    return .{ .position = position, .name = name, .type = parameter_type, .mode = mode, .default = default };
}

pub fn parseType(self: anytype) !Ast.Type {
    const type_position = self.current.position;
    var result: Ast.Type = switch (self.current.tag) {
        .keyword_void => .void,
        .keyword_int => .int,
        .keyword_int8 => .int8,
        .keyword_int16 => .int16,
        .keyword_int32 => .int32,
        .keyword_int64 => .int,
        .keyword_uint => .uint,
        .keyword_uint8 => .uint8,
        .keyword_uint16 => .uint16,
        .keyword_uint32 => .uint32,
        .keyword_uint64 => .uint,
        .keyword_bool => .bool,
        .keyword_float, .keyword_float32 => .float32,
        .keyword_float64 => .float64,
        .keyword_str => .str,
        .identifier => identifier: {
            for (self.type_parameters, 0..) |parameter, index| {
                if (std.mem.eql(u8, parameter.name, self.current.lexeme)) break :identifier .genericParameter(index);
            }
            var name = self.current.lexeme;
            while (true) {
                var lexer = self.lexer;
                const dot = lexer.next() catch break;
                if (dot.tag != .dot) break;
                const part = lexer.next() catch break;
                if (part.tag != .identifier) break;
                try self.advance();
                try self.advance();
                name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ name, self.current.lexeme });
            }
            break :identifier try self.internTypeName(name);
        },
        else => return self.fail("expected type name"),
    };
    try self.advance();
    if (self.current.tag == .less) {
        const arguments = try Generics.parseTypeArguments(self);
        result = try self.internGenericType(type_position, result, arguments);
    }
    while (self.current.tag == .left_bracket) {
        const bracket_position = self.current.position;
        try self.advance();
        if (self.current.tag == .right_bracket) {
            try self.advance();
            if (result == .void) return self.failAt(bracket_position, "list element type cannot be 'void'");
            result = try Collections.internDynamicType(self, type_position, result);
            continue;
        }
        if (self.current.tag != .integer) return self.fail("fixed array length must be an integer literal");
        const length = std.fmt.parseInt(usize, self.current.lexeme, 10) catch return self.failAt(self.current.position, "fixed array length is too large");
        try self.advance();
        try self.expect(.right_bracket, "expected ']' after fixed array length");
        if (result == .void) return self.failAt(bracket_position, "array element type cannot be 'void'");
        result = try Collections.internFixedType(self, type_position, result, length);
    }
    if (self.current.tag == .question) {
        if (result == .void) return self.fail("'void?' is not a valid type");
        result = .optional(result);
        try self.advance();
        if (self.current.tag == .question) return self.fail("nested optional types are not supported");
    }
    return result;
}
