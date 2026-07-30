const std = @import("std");
const Ast = @import("../Ast.zig");
const Collections = @import("Collections.zig");
const Generics = @import("Generics.zig");
const Tuples = @import("Tuples.zig");

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
    var consumed = false;
    var result: Ast.Type = switch (self.current.tag) {
        .left_parenthesis => tuple: {
            consumed = true;
            break :tuple try Tuples.parseType(self, type_position);
        },
        .keyword_func => function: {
            try self.advance();
            try self.expect(.left_parenthesis, "expected '(' after 'func' in function type");
            var parameters: std.ArrayList(Ast.FunctionType.ParameterType) = .empty;
            if (self.current.tag != .right_parenthesis) while (true) {
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
                try parameters.append(self.allocator, .{ .type = try parseType(self), .mode = mode });
                if (self.current.tag != .comma) break;
                try self.advance();
                if (self.current.tag == .right_parenthesis) break;
            };
            try self.expect(.right_parenthesis, "expected ')' after function parameter types");
            const has_return_type = startsType(self.current.tag) or self.current.tag == .at or self.current.tag == .amp;
            const return_mode: Ast.Parameter.Mode = if (!has_return_type) .value else switch (self.current.tag) {
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
            const signature: Ast.FunctionType = .{
                .parameters = try parameters.toOwnedSlice(self.allocator),
                .return_type = if (has_return_type) try parseType(self) else .void,
                .return_mode = return_mode,
            };
            consumed = true;
            for (self.function_types.items, 0..) |existing, index| {
                if (sameFunctionType(existing, signature)) break :function .function(index);
            }
            const index = self.function_types.items.len;
            try self.function_types.append(self.allocator, signature);
            break :function .function(index);
        },
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
                if (std.mem.eql(u8, parameter.name, self.current.lexeme)) {
                    try self.advance();
                    consumed = true;
                    break :identifier .genericParameter(index);
                }
            }
            var name = self.current.lexeme;
            var arguments: std.ArrayList(Ast.Type) = .empty;
            try self.advance();
            consumed = true;
            while (true) {
                if (self.current.tag == .less) {
                    try arguments.appendSlice(self.allocator, try Generics.parseTypeArguments(self));
                }
                if (self.current.tag != .dot) break;
                try self.advance();
                if (self.current.tag != .identifier) return self.fail("expected nested type name after '.'");
                name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ name, self.current.lexeme });
                try self.advance();
            }
            if (std.mem.eql(u8, name, "C.Size")) break :identifier .uint;
            if (std.mem.eql(u8, name, "C.SignedSize")) break :identifier .int;
            const base = try self.internTypeName(try self.resolveTypeName(name));
            break :identifier if (arguments.items.len == 0)
                base
            else
                try self.internGenericType(type_position, base, try arguments.toOwnedSlice(self.allocator));
        },
        else => return self.fail("expected type name"),
    };
    if (!consumed) try self.advance();
    if (self.current.tag == .less) {
        const arguments = try Generics.parseTypeArguments(self);
        result = try self.internGenericType(type_position, result, arguments);
    }
    while (true) switch (self.current.tag) {
        .question => {
            if (result == .void) return self.fail("'void?' is not a valid type");
            if (result.optionalChild() != null) return self.fail("nested optional types are not supported");
            result = .optional(result);
            try self.advance();
        },
        .left_bracket => {
            const bracket_position = self.current.position;
            try self.advance();
            if (self.current.tag == .dot_dot) {
                try self.advance();
                try self.expect(.right_bracket, "expected ']' after view type");
                if (result == .void) return self.failAt(bracket_position, "view element type cannot be 'void'");
                result = try Collections.internViewType(self, type_position, result);
                continue;
            }
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
        },
        else => break,
    };
    return result;
}

fn startsType(tag: anytype) bool {
    return switch (tag) {
        .keyword_func,
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
        .left_parenthesis,
        => true,
        else => false,
    };
}

fn sameFunctionType(left: Ast.FunctionType, right: Ast.FunctionType) bool {
    if (left.return_type != right.return_type or left.return_mode != right.return_mode or left.parameters.len != right.parameters.len) return false;
    for (left.parameters, right.parameters) |left_parameter, right_parameter| {
        if (left_parameter.type != right_parameter.type or left_parameter.mode != right_parameter.mode) return false;
    }
    return true;
}
