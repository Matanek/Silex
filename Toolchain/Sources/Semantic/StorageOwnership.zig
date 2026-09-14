const Ir = @import("../Ir.zig");
const Ast = @import("../Ast.zig");
const Resources = @import("Resources.zig");
const AnalyzeError = error{ InvalidSource, OutOfMemory };

/// Ownership belongs to the storage place, not to the bits loaded from it.
/// A mutable parameter preserves that information through internal calls.
pub const Domain = union(enum) {
    root,
    edge,
    dynamic: Ir.ValueId,
};

pub fn reference(self: anytype, builder: anytype, value: Ir.ValueId) AnalyzeError!Domain {
    const edge = try self.newValue(builder, .bool);
    try self.emit(builder, .{ .unary = .{ .result = edge, .operator = .reference_is_edge, .operand = value } });
    return .{ .dynamic = edge };
}

pub const Operation = enum { retain, drop, release, retain_elements, drop_elements, adopt, adopt_elements, to_root };

pub fn apply(self: anytype, builder: anytype, domain: Domain, operation: Operation, type_value: Ast.Type, value: Ir.ValueId) AnalyzeError!void {
    switch (domain) {
        .root => try applyStatic(self, builder, .root, operation, type_value, value),
        .edge => try applyStatic(self, builder, .edge, operation, type_value, value),
        .dynamic => |edge| {
            const edge_block = try self.newBlock(builder);
            const root_block = try self.newBlock(builder);
            const merge_block = try self.newBlock(builder);
            self.terminate(builder, .{ .branch = .{ .condition = edge, .then_block = edge_block, .else_block = root_block } });
            builder.current_block = edge_block;
            try applyStatic(self, builder, .edge, operation, type_value, value);
            self.terminate(builder, .{ .jump = merge_block });
            builder.current_block = root_block;
            try applyStatic(self, builder, .root, operation, type_value, value);
            self.terminate(builder, .{ .jump = merge_block });
            builder.current_block = merge_block;
        },
    }
}

fn applyStatic(self: anytype, builder: anytype, domain: Ir.Ownership, operation: Operation, type_value: Ast.Type, value: Ir.ValueId) AnalyzeError!void {
    switch (operation) {
        .retain_elements => try Resources.emitCollectionElementsRetainOwned(self, builder, type_value, value, domain),
        .drop_elements => try Resources.emitCollectionElementsDropOwned(self, builder, type_value, value, domain),
        .adopt => if (domain == .edge) {
            try Resources.retainValueOwned(self, builder, type_value, value, .edge);
            try Resources.releaseTransferredRoot(self, builder, type_value, value);
        },
        .adopt_elements => if (domain == .edge) {
            try Resources.emitCollectionElementsRetainOwned(self, builder, type_value, value, .edge);
            try Resources.releaseCollectionElementsTransferredRoot(self, builder, type_value, value);
        },
        .to_root => if (domain == .edge) {
            try Resources.retainValue(self, builder, type_value, value);
            try Resources.releaseTransferredValue(self, builder, type_value, value, .edge);
        },
        .retain => try Resources.retainValueOwned(self, builder, type_value, value, domain),
        .drop => try Resources.emitDropOwned(self, builder, type_value, value, domain),
        .release => try Resources.releaseTransferredValue(self, builder, type_value, value, domain),
    }
}

/// Emit one existing owning operation in the domain carried by a borrow.
/// Locals merge branch results without duplicating any source evaluation.
pub fn emit(self: anytype, builder: anytype, domain: Domain, instruction: Ir.Instruction) AnalyzeError!void {
    switch (instruction) {
        inline .list_edit, .list_drop, .collection_replace => |value, instruction_tag| {
            const tag = @tagName(instruction_tag);
            const T = @TypeOf(value);
            var root_value = value;
            root_value.ownership = .root;
            var edge_value = value;
            edge_value.ownership = .edge;
            switch (domain) {
                .root => try self.emit(builder, @unionInit(Ir.Instruction, tag, root_value)),
                .edge => try self.emit(builder, @unionInit(Ir.Instruction, tag, edge_value)),
                .dynamic => |edge| {
                    const result_local = if (@hasField(T, "result")) local: {
                        const local = builder.local_types.items.len;
                        try builder.local_types.append(self.allocator, builder.value_types.items[value.result]);
                        root_value.result = try self.newValue(builder, builder.value_types.items[value.result]);
                        edge_value.result = try self.newValue(builder, builder.value_types.items[value.result]);
                        break :local local;
                    } else {};
                    const removed_local = if (@hasField(T, "removed")) local: {
                        const removed = value.removed orelse break :local null;
                        const local = builder.local_types.items.len;
                        try builder.local_types.append(self.allocator, builder.value_types.items[removed]);
                        root_value.removed = try self.newValue(builder, builder.value_types.items[removed]);
                        edge_value.removed = try self.newValue(builder, builder.value_types.items[removed]);
                        break :local @as(?Ir.LocalId, local);
                    } else {};
                    const edge_block = try self.newBlock(builder);
                    const root_block = try self.newBlock(builder);
                    const merge_block = try self.newBlock(builder);
                    self.terminate(builder, .{ .branch = .{ .condition = edge, .then_block = edge_block, .else_block = root_block } });
                    builder.current_block = edge_block;
                    try self.emit(builder, @unionInit(Ir.Instruction, tag, edge_value));
                    if (@hasField(T, "result")) try self.emit(builder, .{ .local_store = .{ .local = result_local, .operand = edge_value.result } });
                    if (@hasField(T, "removed")) if (removed_local) |local| try self.emit(builder, .{ .local_store = .{ .local = local, .operand = edge_value.removed.? } });
                    self.terminate(builder, .{ .jump = merge_block });
                    builder.current_block = root_block;
                    try self.emit(builder, @unionInit(Ir.Instruction, tag, root_value));
                    if (@hasField(T, "result")) try self.emit(builder, .{ .local_store = .{ .local = result_local, .operand = root_value.result } });
                    if (@hasField(T, "removed")) if (removed_local) |local| try self.emit(builder, .{ .local_store = .{ .local = local, .operand = root_value.removed.? } });
                    self.terminate(builder, .{ .jump = merge_block });
                    builder.current_block = merge_block;
                    if (@hasField(T, "result")) try self.emit(builder, .{ .local_load = .{ .result = value.result, .local = result_local } });
                    if (@hasField(T, "removed")) if (removed_local) |local| try self.emit(builder, .{ .local_load = .{ .result = value.removed.?, .local = local } });
                },
            }
        },
        else => unreachable,
    }
}

pub fn replaceReference(self: anytype, builder: anytype, target: Ir.ValueId, type_value: Ast.Type, replacement: Ir.ValueId) AnalyzeError!void {
    const domain = try reference(self, builder, target);
    try apply(self, builder, domain, .adopt, type_value, replacement);
    const previous = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .reference_load = .{ .result = previous, .reference = target } });
    try self.emit(builder, .{ .reference_store = .{ .reference = target, .operand = replacement } });
    try apply(self, builder, domain, .release, type_value, previous);
}
