const Ast = @import("../Ast.zig");
const Types = @import("../Types.zig");
const Source = @import("../Source.zig");
const Support = @import("Support.zig");
const Model = @import("Model.zig");

pub const PresenceProof = struct {
    name: []const u8,
    present_when_true: bool,
};

pub const SavedRefinement = struct {
    index: usize,
    binding: Model.Binding,
};

pub fn expectedContext(type_value: Types.Type, expression: *const Ast.Expression) ?Types.Type {
    if (expression.value == .cascade) return expectedContext(type_value, expression.value.cascade.receiver);
    if (expression.value == .sequence_literal) return type_value;
    if (expression.value == .tuple_literal) return type_value.optionalChild() orelse type_value;
    if (type_value.optionalChild() != null) return type_value;
    if (type_value.functionIndex() != null) return type_value;
    return if (type_value.isNumeric() and Support.acceptsNumericContext(expression)) type_value else null;
}

pub fn analyzeNull(
    self: anytype,
    builder: anytype,
    expected: ?Types.Type,
    position: Source.Position,
) !Model.TypedValue {
    const type_value = expected orelse return self.fail(position, "'null' requires an expected optional type");
    if (type_value.optionalChild() == null) return self.fail(position, "'null' requires an expected optional type");
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .optional_null = .{ .result = result } });
    // An absent optional owns no payload. Treating it as a transferred value
    // prevents callers from generating a full recursive retain graph for a
    // value that is known to be empty.
    return .{ .type = type_value, .value = result, .transferred = true };
}

pub fn promote(
    self: anytype,
    builder: anytype,
    value: Model.TypedValue,
    target: Types.Type,
) !?Model.TypedValue {
    const child = target.optionalChild() orelse return null;
    const payload = if (child == value.type)
        value
    else
        (try promote(self, builder, value, child)) orelse return null;
    const result = try self.newValue(builder, target);
    try self.emit(builder, .{ .optional_some = .{ .result = result, .operand = payload.value } });
    return .{
        .type = target,
        .value = result,
        .transferred = payload.transferred,
        .borrowed_root = payload.borrowed_root,
        .borrowed_mode = payload.borrowed_mode,
        .lexical_captures = payload.lexical_captures,
        .lexical_borrows = payload.lexical_borrows,
    };
}

pub fn intrinsic(self: anytype, builder: anytype, type_value: Types.Type) !?Model.TypedValue {
    if (type_value.optionalChild() == null) return null;
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .optional_null = .{ .result = result } });
    return .{ .type = type_value, .value = result, .transferred = true };
}

pub fn emitPresence(self: anytype, builder: anytype, source: Model.TypedValue) !Model.TypedValue {
    if (source.type.optionalChild() == null) return error.InvalidSource;
    const absent = (try intrinsic(self, builder, source.type)).?;
    const result = try self.newValue(builder, .bool);
    try self.emit(builder, .{ .binary = .{
        .result = result,
        .operator = .not_equal,
        .left = source.value,
        .right = absent.value,
    } });
    return .{ .type = .bool, .value = result };
}

pub fn unwrap(self: anytype, builder: anytype, source: Model.TypedValue) !Model.TypedValue {
    const child = source.type.optionalChild() orelse return error.InvalidSource;
    const result = try self.newValue(builder, child);
    try self.emit(builder, .{ .optional_unwrap = .{ .result = result, .operand = source.value } });
    return .{
        .type = child,
        .value = result,
        .transferred = source.transferred,
        .borrowed_root = source.borrowed_root,
        .borrowed_mode = source.borrowed_mode,
        .lexical_captures = source.lexical_captures,
        .lexical_borrows = source.lexical_borrows,
    };
}

pub fn unwrapOrPanic(
    self: anytype,
    builder: anytype,
    source: Model.TypedValue,
    position: Source.Position,
    message: []const u8,
) !Model.TypedValue {
    if (source.type.optionalChild() == null) return error.InvalidSource;
    const presence = try emitPresence(self, builder, source);
    const present = try self.newBlock(builder);
    const absent = try self.newBlock(builder);
    self.terminate(builder, .{ .branch = .{ .condition = presence.value, .then_block = present, .else_block = absent } });
    builder.current_block = absent;
    const diagnostic = try self.emitString(builder, message);
    self.terminate(builder, .{ .panic = .{ .message = diagnostic.value, .position = position } });
    builder.current_block = present;
    return unwrap(self, builder, source);
}

pub fn conversionCost(source: Types.Type, target: Types.Type) ?u8 {
    var current = target;
    var cost: u8 = 0;
    while (current.optionalChild()) |child| {
        cost +|= 1;
        if (child == source) return cost;
        current = child;
    }
    return null;
}

pub fn canConvert(source: Types.Type, target: Types.Type) bool {
    return source == target or conversionCost(source, target) != null;
}

pub fn presenceProof(expression: *const Ast.Expression) ?PresenceProof {
    const binary = switch (expression.value) {
        .binary => |binary| binary,
        else => return null,
    };
    if (binary.operator != .equal and binary.operator != .not_equal) return null;
    const name = switch (binary.left.value) {
        .identifier => |name| switch (binary.right.value) {
            .null_value => name,
            else => return null,
        },
        .null_value => switch (binary.right.value) {
            .identifier => |name| name,
            else => return null,
        },
        else => return null,
    };
    return .{ .name = name, .present_when_true = binary.operator == .not_equal };
}

pub fn applyRefinement(self: anytype, builder: anytype, proof: PresenceProof) !?SavedRefinement {
    const index = Support.findBindingIndex(builder.bindings.items, proof.name) orelse return null;
    const binding = builder.bindings.items[index];
    if (binding.refined_type != null) return null;
    const child = binding.type.optionalChild() orelse return null;
    const operand = if (binding.local) |local| operand: {
        const value = try self.newValue(builder, binding.type);
        try self.emit(builder, .{ .local_load = .{ .result = value, .local = local } });
        break :operand value;
    } else binding.value.?;
    const result = try self.newValue(builder, child);
    try self.emit(builder, .{ .optional_unwrap = .{ .result = result, .operand = operand } });
    builder.bindings.items[index].refined_type = child;
    builder.bindings.items[index].refined_value = result;
    return .{ .index = index, .binding = binding };
}

pub fn restoreRefinement(builder: anytype, saved: SavedRefinement) void {
    builder.bindings.items[saved.index] = saved.binding;
}

pub fn invalidateRefinement(builder: anytype, name: []const u8) void {
    const index = Support.findBindingIndex(builder.bindings.items, name) orelse return;
    builder.bindings.items[index].refined_type = null;
    builder.bindings.items[index].refined_value = null;
}
