const std = @import("std");
const Source = @import("../Source.zig");
const Model = @import("Model.zig");
const Optionals = @import("Optionals.zig");
const Resources = @import("Resources.zig");

const Error = std.mem.Allocator.Error || Source.Error;

// Lower a diagnostic using the portable scalar/string IR. Error types need no
// display protocol or conventionally named member. Bound recursive class graphs
// and summarize collections rather than traversing user data indefinitely.
pub fn format(self: anytype, builder: anytype, value: Model.TypedValue, depth: usize) Error!Model.TypedValue {
    if (value.type == .str) return value;
    if (value.type.isNumeric() or value.type == .bool) {
        const result = try self.newValue(builder, .str);
        try self.emit(builder, .{ .format_value = .{ .result = result, .operand = value.value } });
        return .{ .type = .str, .value = result, .transferred = true };
    }
    if (depth == 4) return self.emitString(builder, self.typeName(value.type));
    if (value.type.optionalChild() != null) {
        const presence = try Optionals.emitPresence(self, builder, value);
        const present = try self.newBlock(builder);
        const absent = try self.newBlock(builder);
        const merge = try self.newBlock(builder);
        const result = try self.newValue(builder, .str);
        self.terminate(builder, .{ .branch = .{ .condition = presence.value, .then_block = present, .else_block = absent } });
        builder.current_block = present;
        const payload = try Optionals.unwrap(self, builder, value);
        try copyText(self, builder, result, try format(self, builder, payload, depth + 1));
        self.terminate(builder, .{ .jump = merge });
        builder.current_block = absent;
        try copyText(self, builder, result, try self.emitString(builder, "null"));
        self.terminate(builder, .{ .jump = merge });
        builder.current_block = merge;
        return .{ .type = .str, .value = result, .transferred = true };
    }
    const type_index = value.type.structureIndex() orelse return self.emitString(builder, self.typeName(value.type));
    for (self.enums, 0..) |enumeration, enum_index| {
        if (enumeration.type_index != type_index) continue;
        const merge = try self.newBlock(builder);
        const result = try self.newValue(builder, .str);
        for (enumeration.variants, 0..) |variant, variant_index| {
            const selected = try self.newValue(builder, .bool);
            try self.emit(builder, .{ .enum_test = .{ .result = selected, .operand = value.value, .enumeration = enum_index, .variant = variant_index } });
            const branch = try self.newBlock(builder);
            const next = try self.newBlock(builder);
            self.terminate(builder, .{ .branch = .{ .condition = selected, .then_block = branch, .else_block = next } });
            builder.current_block = branch;
            var text = try self.emitString(builder, variant.name);
            if (variant.associated_types.len != 0) text = try append(self, builder, text, "(");
            for (variant.associated_types, 0..) |payload_type, index| {
                if (index != 0) text = try append(self, builder, text, ", ");
                const payload = try self.newValue(builder, payload_type);
                try self.emit(builder, .{ .enum_payload = .{ .result = payload, .operand = value.value, .enumeration = enum_index, .variant = variant_index, .index = index } });
                text = try concat(self, builder, text, try format(self, builder, .{ .type = payload_type, .value = payload }, depth + 1));
            }
            if (variant.associated_types.len != 0) text = try append(self, builder, text, ")");
            try copyText(self, builder, result, text);
            self.terminate(builder, .{ .jump = merge });
            builder.current_block = next;
        }
        try copyText(self, builder, result, try self.emitString(builder, enumeration.name));
        self.terminate(builder, .{ .jump = merge });
        builder.current_block = merge;
        return .{ .type = .str, .value = result, .transferred = true };
    }
    const structure = self.structures[type_index];
    var text = try self.emitString(builder, structure.name);
    if (structure.collection != null) {
        const count = try self.newValue(builder, .int);
        try self.emit(builder, .{ .collection_count = .{ .result = count, .collection = value.value } });
        text = try append(self, builder, text, " (count: ");
        text = try concat(self, builder, text, try format(self, builder, .{ .type = .int, .value = count }, depth + 1));
        return append(self, builder, text, ")");
    }
    if (structure.fields.len == 0) return text;
    text = try append(self, builder, text, " { ");
    for (structure.fields, 0..) |field, index| {
        if (index != 0) text = try append(self, builder, text, ", ");
        text = try append(self, builder, text, field.name);
        text = try append(self, builder, text, ": ");
        const field_value = try self.newValue(builder, field.type);
        try self.emit(builder, .{ .field_load = .{ .result = field_value, .base = value.value, .field = index } });
        text = try concat(self, builder, text, try format(self, builder, .{ .type = field.type, .value = field_value }, depth + 1));
    }
    return append(self, builder, text, " }");
}

fn copyText(self: anytype, builder: anytype, result: usize, text: Model.TypedValue) Error!void {
    if (!text.transferred) try Resources.retainValue(self, builder, .str, text.value);
    try self.emit(builder, .{ .copy = .{ .result = result, .operand = text.value } });
}

pub fn concat(self: anytype, builder: anytype, left: Model.TypedValue, right: Model.TypedValue) Error!Model.TypedValue {
    const result = try self.newValue(builder, .str);
    try self.emit(builder, .{ .string_concat = .{ .result = result, .left = left.value, .right = right.value } });
    if (left.transferred) try Resources.emitDrop(self, builder, .str, left.value);
    if (right.transferred) try Resources.emitDrop(self, builder, .str, right.value);
    return .{ .type = .str, .value = result, .transferred = true };
}

fn append(self: anytype, builder: anytype, left: Model.TypedValue, right: []const u8) Error!Model.TypedValue {
    return concat(self, builder, left, try self.emitString(builder, right));
}
