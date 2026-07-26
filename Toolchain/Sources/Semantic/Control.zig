const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Source = @import("../Source.zig");
const Optionals = @import("Optionals.zig");

pub fn analyzeIf(self: anytype, builder: anytype, function: Ast.Function, conditional: Ast.IfStatement) !bool {
    var exits: std.ArrayList(Ir.BlockId) = .empty;
    var fallthrough_refinements: std.ArrayList(Optionals.SavedRefinement) = .empty;
    for (conditional.branches) |branch| {
        const condition = try self.analyzeExpression(builder, branch.condition);
        if (condition.type != .bool) return self.fail(branch.condition.position, "if condition expects 'bool'");
        const proof = Optionals.presenceProof(branch.condition);

        const body_block = try self.newBlock(builder);
        const next_block = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{
            .condition = condition.value,
            .then_block = body_block,
            .else_block = next_block,
        } });

        builder.current_block = body_block;
        const binding_count = builder.bindings.items.len;
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
    const condition = try self.analyzeExpression(builder, loop.condition);
    if (condition.type != .bool) return self.fail(loop.condition.position, "while condition expects 'bool'");
    self.terminate(builder, .{ .branch = .{
        .condition = condition.value,
        .then_block = body_block,
        .else_block = exit_block,
    } });

    builder.current_block = body_block;
    try builder.loops.append(self.allocator, .{
        .continue_block = condition_block,
        .break_block = exit_block,
    });
    const binding_count = builder.bindings.items.len;
    const terminated = try self.analyzeStatements(builder, function, loop.statements);
    builder.bindings.shrinkRetainingCapacity(binding_count);
    builder.loops.items.len -= 1;
    if (!terminated) self.terminate(builder, .{ .jump = condition_block });

    builder.current_block = exit_block;
    return false;
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
