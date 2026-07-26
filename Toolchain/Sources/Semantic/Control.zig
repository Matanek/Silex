const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Source = @import("../Source.zig");
const Model = @import("Model.zig");
const Optionals = @import("Optionals.zig");
const Support = @import("Support.zig");

pub const ConditionalValue = struct {
    condition: Model.TypedValue,
    binding: ?BindingValue = null,
    expression: ?*Ast.Expression = null,
};

const BindingValue = struct {
    declaration: Ast.ConditionalBinding,
    source: Model.TypedValue,
    child_type: Ast.Type,
};

pub fn analyzeIf(self: anytype, builder: anytype, function: Ast.Function, conditional: Ast.IfStatement) !bool {
    var exits: std.ArrayList(Ir.BlockId) = .empty;
    var fallthrough_refinements: std.ArrayList(Optionals.SavedRefinement) = .empty;
    for (conditional.branches) |branch| {
        const analyzed = try analyzeCondition(self, builder, branch.condition, "if");
        const proof = if (analyzed.expression) |expression| Optionals.presenceProof(expression) else null;

        const body_block = try self.newBlock(builder);
        const next_block = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{
            .condition = analyzed.condition.value,
            .then_block = body_block,
            .else_block = next_block,
        } });

        builder.current_block = body_block;
        const binding_count = builder.bindings.items.len;
        if (analyzed.binding) |binding| try enterBinding(self, builder, binding);
        const body_refinement = if (proof != null and proof.?.present_when_true)
            try Optionals.applyRefinement(self, builder, proof.?)
        else
            null;
        const terminated = try self.analyzeStatements(builder, function, branch.statements);
        builder.bindings.shrinkRetainingCapacity(binding_count);
        if (body_refinement) |saved| Optionals.restoreRefinement(builder, saved);
        if (!terminated) try exits.append(self.allocator, builder.current_block);
        builder.current_block = next_block;
        if (proof != null and !proof.?.present_when_true) {
            if (try Optionals.applyRefinement(self, builder, proof.?)) |saved| {
                try fallthrough_refinements.append(self.allocator, saved);
            }
        }
    }

    if (conditional.else_statements) |statements| {
        const binding_count = builder.bindings.items.len;
        const terminated = try self.analyzeStatements(builder, function, statements);
        builder.bindings.shrinkRetainingCapacity(binding_count);
        if (!terminated) try exits.append(self.allocator, builder.current_block);
    } else {
        try exits.append(self.allocator, builder.current_block);
    }

    var refinement_index = fallthrough_refinements.items.len;
    while (refinement_index != 0) {
        refinement_index -= 1;
        Optionals.restoreRefinement(builder, fallthrough_refinements.items[refinement_index]);
    }

    if (exits.items.len == 0) return true;
    const merge_block = try self.newBlock(builder);
    for (exits.items) |block_id| builder.blocks.items[block_id].terminator = .{ .jump = merge_block };
    builder.current_block = merge_block;
    return false;
}

pub fn analyzeWhile(self: anytype, builder: anytype, function: Ast.Function, loop: Ast.WhileStatement) !bool {
    const condition_block = try self.newBlock(builder);
    const body_block = try self.newBlock(builder);
    const exit_block = try self.newBlock(builder);
    self.terminate(builder, .{ .jump = condition_block });

    builder.current_block = condition_block;
    const analyzed = try analyzeCondition(self, builder, loop.condition, "while");
    self.terminate(builder, .{ .branch = .{
        .condition = analyzed.condition.value,
        .then_block = body_block,
        .else_block = exit_block,
    } });

    builder.current_block = body_block;
    try builder.loops.append(self.allocator, .{
        .continue_block = condition_block,
        .break_block = exit_block,
    });
    const binding_count = builder.bindings.items.len;
    if (analyzed.binding) |binding| try enterBinding(self, builder, binding);
    const terminated = try self.analyzeStatements(builder, function, loop.statements);
    builder.bindings.shrinkRetainingCapacity(binding_count);
    builder.loops.items.len -= 1;
    if (!terminated) self.terminate(builder, .{ .jump = condition_block });

    builder.current_block = exit_block;
    return false;
}

pub fn analyzeCondition(self: anytype, builder: anytype, condition: Ast.Condition, keyword: []const u8) !ConditionalValue {
    return switch (condition) {
        .expression => |expression| expression_condition: {
            const value = try self.analyzeExpression(builder, expression);
            if (value.type != .bool) {
                const message = try std.fmt.allocPrint(self.allocator, "{s} condition expects 'bool'", .{keyword});
                return self.fail(expression.position, message);
            }
            break :expression_condition .{ .condition = value, .expression = expression };
        },
        .binding => |binding| binding_condition: {
            if (Support.findBinding(builder.bindings.items, binding.name) != null) {
                const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' is already declared in this scope", .{binding.name});
                return self.fail(binding.name_position, message);
            }
            const source = try self.analyzeExpression(builder, binding.source);
            const child = source.type.optionalChild() orelse {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "conditional binding '{s}' expects an optional source, found '{s}'",
                    .{ binding.name, self.typeName(source.type) },
                );
                return self.fail(binding.source.position, message);
            };
            const absent = (try Optionals.intrinsic(self, builder, source.type)).?;
            const result = try self.newValue(builder, .bool);
            try self.emit(builder, .{ .binary = .{
                .result = result,
                .operator = .not_equal,
                .left = source.value,
                .right = absent.value,
            } });
            break :binding_condition .{
                .condition = .{ .type = .bool, .value = result },
                .binding = .{ .declaration = binding, .source = source, .child_type = child },
            };
        },
    };
}

pub fn enterBinding(self: anytype, builder: anytype, binding: BindingValue) !void {
    const value = try self.newValue(builder, binding.child_type);
    try self.emit(builder, .{ .optional_unwrap = .{ .result = value, .operand = binding.source.value } });
    if (binding.declaration.mutable) {
        const local = builder.local_types.items.len;
        try builder.local_types.append(self.allocator, binding.child_type);
        try self.emit(builder, .{ .local_store = .{ .local = local, .operand = value } });
        try builder.bindings.append(self.allocator, .{
            .name = binding.declaration.name,
            .type = binding.child_type,
            .local = local,
            .mutable = true,
        });
    } else try builder.bindings.append(self.allocator, .{
        .name = binding.declaration.name,
        .type = binding.child_type,
        .value = value,
    });
}

pub fn analyzeLoopControl(
    self: anytype,
    builder: anytype,
    position: Source.Position,
    is_continue: bool,
) !bool {
    if (builder.loops.items.len == 0) {
        return self.fail(position, if (is_continue)
            "'continue' is only valid inside a loop"
        else
            "'break' is only valid inside a loop");
    }
    const loop = builder.loops.items[builder.loops.items.len - 1];
    self.terminate(builder, .{ .jump = if (is_continue) loop.continue_block else loop.break_block });
    return true;
}
