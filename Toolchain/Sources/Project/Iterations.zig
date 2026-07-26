const Ast = @import("../Ast.zig");

pub fn activate(self: anytype, module: usize, loop: Ast.ForStatement) !void {
    switch (loop.source) {
        .collection => |source| try self.activateExpression(module, source),
        .range => |range| {
            try self.activateExpression(module, range.start);
            try self.activateExpression(module, range.end);
        },
    }
    for (loop.statements) |statement| try self.activateStatement(module, statement);
}

pub fn rewrite(self: anytype, module: usize, loop: Ast.ForStatement, type_map: []const Ast.Type) !Ast.ForStatement {
    var value = loop;
    switch (value.source) {
        .collection => |source| try self.rewriteExpression(module, source, type_map),
        .range => |range| {
            try self.rewriteExpression(module, range.start, type_map);
            try self.rewriteExpression(module, range.end, type_map);
        },
    }
    value.statements = try self.rewriteStatements(module, loop.statements, type_map);
    return value;
}
