const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");
const std = @import("std");

// Anonymous bodies are lifted by the parser, but their generic calls must be
// specialized where the callback is defined, with the lexical binding types.
// This is type information only: semantic analysis still owns capture discovery
// and the lifetime of borrowed environments.
pub fn specialize(
    self: anytype,
    name: []const u8,
    arguments: []const Ast.Type,
    position: Source.Position,
    locals: anytype,
) (Source.Error || std.mem.Allocator.Error)!?[]const u8 {
    for (self.source.functions) |function| {
        const matches = std.mem.eql(u8, function.name, name) or
            (function.name.len > name.len and std.mem.endsWith(u8, function.name, name) and
                function.name[function.name.len - name.len - 1] == '.');
        if (!function.is_anonymous or !matches or
            function.position.file != position.file or function.position.offset != position.offset or
            function.type_parameters.len != arguments.len) continue;
        return try self.instantiate(function, arguments, position, locals);
    }
    return null;
}
