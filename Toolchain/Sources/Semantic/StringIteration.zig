const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Availability = @import("Availability.zig");
const Resources = @import("Resources.zig");

pub fn analyze(
    self: anytype,
    builder: anytype,
    function: Ast.Function,
    loop: Ast.ForStatement,
    source_expression: *Ast.Expression,
    source: Model.TypedValue,
) !bool {
    if (loop.bindings.len != 0) return self.fail(loop.name_position, "string traversal requires one binding");
    if (loop.mode == .mutable) return self.fail(loop.name_position, "for var is unavailable for immutable string scalars");

    const outer_binding_count = builder.bindings.items.len;
    const string_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .str);
    if (!source.transferred) try Resources.retainValue(self, builder, .str, source.value);
    try self.emit(builder, .{ .local_store = .{ .local = string_local, .operand = source.value } });
    try builder.bindings.append(self.allocator, .{
        .name = "$for-string",
        .type = .str,
        .local = string_local,
    });

    const index_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .uint);
    try self.emit(builder, .{ .local_store = .{ .local = index_local, .operand = try constant(self, builder, .uint, 0) } });
    const width_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .uint);
    const scalar_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .uint32);

    const availability_count = builder.bindings.items.len;
    const header_availability = try Availability.snapshot(self.allocator, builder.bindings.items, availability_count);
    const condition_block = try self.newBlock(builder);
    const body_block = try self.newBlock(builder);
    const update_block = try self.newBlock(builder);
    const exit_block = try self.newBlock(builder);
    self.terminate(builder, .{ .jump = condition_block });

    builder.current_block = condition_block;
    const text = try loadLocal(self, builder, string_local, .str);
    const byte_count = try self.newValue(builder, .uint);
    try self.emit(builder, .{ .string_byte_count = .{ .result = byte_count, .operand = text } });
    const index = try loadLocal(self, builder, index_local, .uint);
    const has_byte = try binary(self, builder, .less, index, byte_count, .bool);
    self.terminate(builder, .{ .branch = .{ .condition = has_byte, .then_block = body_block, .else_block = exit_block } });

    builder.current_block = body_block;
    try decodeScalar(self, builder, source_expression.position, string_local, index_local, scalar_local, width_local);
    const scalar = try loadLocal(self, builder, scalar_local, .uint32);
    const binding_count = builder.bindings.items.len;
    try builder.bindings.append(self.allocator, .{
        .name = loop.name,
        .type = .uint32,
        .value = scalar,
        .borrowed_root = if (loop.mode == .read) "$for-string" else null,
        .borrowed_mode = if (loop.mode == .read) .read else .value,
    });
    try builder.loops.append(self.allocator, .{
        .continue_block = update_block,
        .break_block = exit_block,
        .availability_count = availability_count,
        .drop_binding_count = binding_count,
        .header_availability = header_availability,
        .mutex_depth = builder.mutex_depth,
    });
    const loop_index = builder.loops.items.len - 1;
    const terminated = try self.analyzeStatements(builder, function, loop.statements);
    const loop_context = builder.loops.items[loop_index];
    builder.loops.items.len -= 1;
    if (!terminated) try Resources.emitActiveDrops(self, builder, binding_count);
    builder.bindings.shrinkRetainingCapacity(binding_count);
    if (!terminated) self.terminate(builder, .{ .jump = update_block });

    builder.current_block = update_block;
    const next = try binary(
        self,
        builder,
        .add,
        try loadLocal(self, builder, index_local, .uint),
        try loadLocal(self, builder, width_local, .uint),
        .uint,
    );
    try self.emit(builder, .{ .local_store = .{ .local = index_local, .operand = next } });
    self.terminate(builder, .{ .jump = condition_block });

    builder.current_block = exit_block;
    const exit_availability = try self.allocator.dupe(bool, header_availability);
    for (loop_context.break_availabilities.items) |state| Availability.merge(exit_availability, state);
    Availability.restore(builder.bindings.items, exit_availability);
    try Resources.emitActiveDrops(self, builder, outer_binding_count);
    builder.bindings.shrinkRetainingCapacity(outer_binding_count);
    return false;
}

fn decodeScalar(self: anytype, builder: anytype, position: anytype, string_local: Ir.LocalId, index_local: Ir.LocalId, scalar_local: Ir.LocalId, width_local: Ir.LocalId) !void {
    const first = try byteAt(self, builder, position, string_local, index_local, 0);
    const ascii_block = try self.newBlock(builder);
    const multibyte_block = try self.newBlock(builder);
    const two_block = try self.newBlock(builder);
    const three_or_four_block = try self.newBlock(builder);
    const three_block = try self.newBlock(builder);
    const four_block = try self.newBlock(builder);
    const merge_block = try self.newBlock(builder);
    const ascii = try binary(self, builder, .less, first, try constant(self, builder, .uint32, 0x80), .bool);
    self.terminate(builder, .{ .branch = .{ .condition = ascii, .then_block = ascii_block, .else_block = multibyte_block } });

    builder.current_block = ascii_block;
    try storeDecoded(self, builder, scalar_local, width_local, first, 1, merge_block);

    builder.current_block = multibyte_block;
    const two = try binary(self, builder, .less, first, try constant(self, builder, .uint32, 0xE0), .bool);
    self.terminate(builder, .{ .branch = .{ .condition = two, .then_block = two_block, .else_block = three_or_four_block } });

    builder.current_block = two_block;
    const second = try byteAt(self, builder, position, string_local, index_local, 1);
    try storeDecoded(self, builder, scalar_local, width_local, try combine(self, builder, &.{ first, second }, &.{ 0x1F, 0x3F }), 2, merge_block);

    builder.current_block = three_or_four_block;
    const three = try binary(self, builder, .less, first, try constant(self, builder, .uint32, 0xF0), .bool);
    self.terminate(builder, .{ .branch = .{ .condition = three, .then_block = three_block, .else_block = four_block } });

    builder.current_block = three_block;
    const third_second = try byteAt(self, builder, position, string_local, index_local, 1);
    const third = try byteAt(self, builder, position, string_local, index_local, 2);
    try storeDecoded(self, builder, scalar_local, width_local, try combine(self, builder, &.{ first, third_second, third }, &.{ 0x0F, 0x3F, 0x3F }), 3, merge_block);

    builder.current_block = four_block;
    const fourth_second = try byteAt(self, builder, position, string_local, index_local, 1);
    const fourth_third = try byteAt(self, builder, position, string_local, index_local, 2);
    const fourth = try byteAt(self, builder, position, string_local, index_local, 3);
    try storeDecoded(self, builder, scalar_local, width_local, try combine(self, builder, &.{ first, fourth_second, fourth_third, fourth }, &.{ 0x07, 0x3F, 0x3F, 0x3F }), 4, merge_block);

    builder.current_block = merge_block;
}

fn byteAt(self: anytype, builder: anytype, position: anytype, string_local: Ir.LocalId, index_local: Ir.LocalId, offset: u64) !Ir.ValueId {
    const index = if (offset == 0)
        try loadLocal(self, builder, index_local, .uint)
    else
        try binary(self, builder, .add, try loadLocal(self, builder, index_local, .uint), try constant(self, builder, .uint, offset), .uint);
    const byte = try self.newValue(builder, .uint8);
    try self.emit(builder, .{ .string_byte_at = .{ .result = byte, .operand = try loadLocal(self, builder, string_local, .str), .index = index } });
    const widened = try self.newValue(builder, .uint32);
    try self.emit(builder, .{ .convert = .{ .result = widened, .operand = byte, .source = .uint8, .target = .uint32, .position = position, .checked = false } });
    return widened;
}

fn combine(self: anytype, builder: anytype, bytes: []const Ir.ValueId, masks: []const u64) !Ir.ValueId {
    var result = try binary(self, builder, .bit_and, bytes[0], try constant(self, builder, .uint32, masks[0]), .uint32);
    for (bytes[1..], masks[1..]) |byte, mask| {
        result = try binary(self, builder, .multiply, result, try constant(self, builder, .uint32, 64), .uint32);
        const payload = try binary(self, builder, .bit_and, byte, try constant(self, builder, .uint32, mask), .uint32);
        result = try binary(self, builder, .add, result, payload, .uint32);
    }
    return result;
}

fn storeDecoded(self: anytype, builder: anytype, scalar_local: Ir.LocalId, width_local: Ir.LocalId, scalar: Ir.ValueId, width: u64, merge: Ir.BlockId) !void {
    try self.emit(builder, .{ .local_store = .{ .local = scalar_local, .operand = scalar } });
    try self.emit(builder, .{ .local_store = .{ .local = width_local, .operand = try constant(self, builder, .uint, width) } });
    self.terminate(builder, .{ .jump = merge });
}

fn constant(self: anytype, builder: anytype, type_value: Ast.Type, bits: u64) !Ir.ValueId {
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .constant_int = .{ .result = result, .bits = bits } });
    return result;
}

fn loadLocal(self: anytype, builder: anytype, local: Ir.LocalId, type_value: Ast.Type) !Ir.ValueId {
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .local_load = .{ .result = result, .local = local } });
    return result;
}

fn binary(self: anytype, builder: anytype, operator: Ir.BinaryOperator, left: Ir.ValueId, right: Ir.ValueId, type_value: Ast.Type) !Ir.ValueId {
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .binary = .{ .result = result, .operator = operator, .left = left, .right = right, .checked = false } });
    return result;
}
