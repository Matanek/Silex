const std = @import("std");
const Ast = @import("../Ast.zig");
const Numeric = @import("../Numeric.zig");
const Borrowing = @import("Borrowing.zig");
const Optionals = @import("Optionals.zig");
const Support = @import("Support.zig");
const Resources = @import("Resources.zig");

pub fn analyzeVariable(self: anytype, builder: anytype, declaration: Ast.VariableDeclaration) !void {
    if (Support.findBinding(builder.bindings.items, declaration.name) != null) {
        const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' is already declared in this scope", .{declaration.name});
        return self.fail(declaration.name_position, message);
    }

    var initializer = if (declaration.initializer) |expression|
        try self.analyzeExpressionExpected(
            builder,
            expression,
            if (declaration.annotation) |annotation| Optionals.expectedContext(annotation, expression) else null,
        )
    else intrinsic: {
        const annotation = declaration.annotation.?;
        break :intrinsic try self.emitIntrinsic(builder, annotation, declaration.name_position);
    };
    const declared_type = declaration.annotation orelse initializer.type;
    if (initializer.borrowed_root != null or declaration.annotation_mode != .value) {
        if (initializer.borrowed_root == null) return self.fail(declaration.name_position, "borrowed alias requires a borrowed initializer");
        const alias_mode: Ast.Parameter.Mode = if (declaration.annotation_mode != .value)
            declaration.annotation_mode
        else if (declaration.mutable)
            initializer.borrowed_mode
        else
            .read;
        if (alias_mode == .mutable and (!declaration.mutable or initializer.borrowed_mode != .mutable or initializer.reference == null)) {
            return self.fail(declaration.name_position, "mutable alias requires 'var' and a mutable borrowed value");
        }
        if (declaration.initializer) |expression| if (expression.value == .identifier) {
            const source = Support.findBinding(builder.bindings.items, expression.value.identifier);
            if (source != null and source.?.borrowed_mode == .mutable) return self.fail(expression.position, "a mutable alias cannot be copied or weakened by another declaration");
        };
        try builder.bindings.append(self.allocator, .{
            .name = declaration.name,
            .type = declared_type,
            .value = if (alias_mode == .read) initializer.value else null,
            .reference = if (alias_mode == .mutable) initializer.reference else null,
            .mutable = alias_mode == .mutable,
            .borrowed_root = initializer.borrowed_root,
            .borrowed_mode = alias_mode,
        });
        return;
    }
    if (declaration.initializer) |expression| try Resources.requireTransfer(self, expression, declared_type, "storing it");
    try Borrowing.requireOwned(self, initializer, if (declaration.initializer) |value| value.position else declaration.name_position, "stored");
    if (initializer.type != declared_type and (Numeric.canWiden(initializer.type, declared_type) or Optionals.canConvert(initializer.type, declared_type))) {
        initializer = try self.coerce(builder, initializer, declared_type, declaration.initializer.?.position);
    }
    if (initializer.type != declared_type) {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "variable '{s}' expects '{s}', found '{s}'",
            .{ declaration.name, self.typeName(declared_type), self.typeName(initializer.type) },
        );
        return self.fail(if (declaration.initializer) |value| value.position else declaration.name_position, message);
    }
    if (declaration.mutable) {
        const local = builder.local_types.items.len;
        try builder.local_types.append(self.allocator, declared_type);
        try self.emit(builder, .{ .local_store = .{ .local = local, .operand = initializer.value } });
        try builder.bindings.append(self.allocator, .{
            .name = declaration.name,
            .type = declared_type,
            .local = local,
            .mutable = true,
        });
    } else try builder.bindings.append(self.allocator, .{
        .name = declaration.name,
        .type = declared_type,
        .value = initializer.value,
    });
}

pub fn analyzeReturn(self: anytype, builder: anytype, function: Ast.Function, statement: Ast.ReturnStatement) !void {
    if (statement.value) |expression| {
        if (function.return_type == .void) return self.fail(statement.position, "a void function cannot return a value");
        var value = try self.analyzeExpressionExpected(
            builder,
            expression,
            Optionals.expectedContext(function.return_type, expression),
        );
        if (value.type != function.return_type and (Numeric.canWiden(value.type, function.return_type) or Optionals.canConvert(value.type, function.return_type))) {
            value = try self.coerce(builder, value, function.return_type, expression.position);
        }
        if (value.type != function.return_type) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "return expects '{s}', found '{s}'",
                .{ self.typeName(function.return_type), self.typeName(value.type) },
            );
            return self.fail(expression.position, message);
        }
        if (function.return_mode != .value) {
            const provenance = function.return_provenance orelse return self.fail(function.name_position, "borrowed return provenance is ambiguous; qualify it with a parameter name");
            if (value.borrowed_root == null or !std.mem.eql(u8, value.borrowed_root.?, provenance)) {
                const message = try std.fmt.allocPrint(self.allocator, "borrowed return must originate from parameter '{s}'", .{provenance});
                return self.fail(expression.position, message);
            }
            if (function.return_mode == .mutable and (value.borrowed_mode != .mutable or value.reference == null)) {
                return self.fail(expression.position, "mutable borrowed return requires a mutable place from an '&' parameter");
            }
            self.terminate(builder, .{ .return_value = if (function.return_mode == .mutable) value.reference.? else value.value });
            return;
        }
        try Resources.requireTransfer(self, expression, value.type, "returning it");
        try Borrowing.requireOwned(self, value, expression.position, "returned");
        self.terminate(builder, .{ .return_value = value.value });
        return;
    }

    if (function.return_type != .void) {
        const message = try std.fmt.allocPrint(self.allocator, "expected return value of type '{s}'", .{self.typeName(function.return_type)});
        return self.fail(statement.position, message);
    }
    self.terminate(builder, .return_void);
}
