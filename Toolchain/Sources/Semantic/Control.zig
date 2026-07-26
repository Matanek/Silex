const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");

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
