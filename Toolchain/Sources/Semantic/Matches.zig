const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Enums = @import("Enums.zig");
const Model = @import("Model.zig");
const Support = @import("Support.zig");

pub fn analyze(self: anytype, builder: anytype, match_value: Ast.Expression.Match) !Model.TypedValue {
    const subject = try self.analyzeExpression(builder, match_value.subject);
    const enum_index = Enums.findByType(self, subject.type) orelse {
        const message = try std.fmt.allocPrint(self.allocator, "match requires an enum subject, found '{s}'", .{self.typeName(subject.type)});
        return self.fail(match_value.subject.position, message);
    };
    const enumeration = self.program.enums[enum_index];
    var else_index: ?usize = null;
    for (match_value.branches, 0..) |branch, branch_index| if (branch.is_else) {
        if (else_index != null) return self.fail(branch.position, "match can contain only one else branch");
        if (branch_index + 1 != match_value.branches.len) return self.fail(branch.position, "else match branch must be last");
        else_index = branch_index;
    };
    if (else_index == null and match_value.branches.len != enumeration.variants.len) {
        for (enumeration.variants) |variant| {
            var found = false;
            for (match_value.branches) |branch| if (!branch.is_else and std.mem.eql(u8, branch.variant, variant.name)) {
                found = true;
            };
            if (!found) {
                const message = try std.fmt.allocPrint(self.allocator, "match is missing variant '{s}'", .{variant.name});
                return self.fail(match_value.subject.position, message);
            }
        }
    }

    const variant_indices = try self.allocator.alloc(?usize, match_value.branches.len);
    for (match_value.branches, 0..) |branch, branch_index| {
        if (branch.is_else) {
            variant_indices[branch_index] = null;
            continue;
        }
        var selected: ?usize = null;
        for (enumeration.variants, 0..) |variant, variant_index| {
            if (std.mem.eql(u8, branch.variant, variant.name)) selected = variant_index;
        }
        const variant_index = selected orelse {
            const message = try std.fmt.allocPrint(self.allocator, "enum '{s}' has no variant named '{s}'", .{ enumeration.name, branch.variant });
            return self.fail(branch.position, message);
        };
        for (match_value.branches[0..branch_index]) |previous| {
            if (!previous.is_else and std.mem.eql(u8, previous.variant, branch.variant)) {
                const message = try std.fmt.allocPrint(self.allocator, "variant '{s}' is matched more than once", .{branch.variant});
                return self.fail(branch.position, message);
            }
        }
        const variant = enumeration.variants[variant_index];
        if (branch.bindings.len != variant.associated_types.len) {
            const message = try std.fmt.allocPrint(self.allocator, "variant '{s}' exposes {d} associated values, pattern binds {d}", .{
                branch.variant, variant.associated_types.len, branch.bindings.len,
            });
            return self.fail(branch.position, message);
        }
        for (branch.bindings, 0..) |binding, binding_index| {
            if (Support.findBinding(builder.bindings.items, binding.name) != null) {
                const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' is already declared in this scope", .{binding.name});
                return self.fail(binding.position, message);
            }
            for (branch.bindings[0..binding_index]) |previous| if (std.mem.eql(u8, previous.name, binding.name)) {
                const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' is already declared in this pattern", .{binding.name});
                return self.fail(binding.position, message);
            };
        }
        variant_indices[branch_index] = variant_index;
    }
    if (else_index != null and match_value.branches.len - 1 == enumeration.variants.len) {
        return self.fail(match_value.branches[else_index.?].position, "else match branch is unreachable because every variant is already covered");
    }

    const branch_blocks = try self.allocator.alloc(Ir.BlockId, match_value.branches.len);
    for (branch_blocks) |*block| block.* = try self.newBlock(builder);
    const merge_block = try self.newBlock(builder);
    for (branch_blocks[0 .. branch_blocks.len - 1], 0..) |branch_block, branch_index| {
        const test_value = try self.newValue(builder, .bool);
        try self.emit(builder, .{ .enum_test = .{
            .result = test_value,
            .operand = subject.value,
            .enumeration = enum_index,
            .variant = variant_indices[branch_index].?,
        } });
        const next = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{
            .condition = test_value,
            .then_block = branch_block,
            .else_block = next,
        } });
        builder.current_block = next;
    }
    self.terminate(builder, .{ .jump = branch_blocks[branch_blocks.len - 1] });

    var result: ?Ir.ValueId = null;
    var result_type: ?Ast.Type = null;
    for (match_value.branches, branch_blocks, variant_indices) |branch, branch_block, optional_variant_index| {
        builder.current_block = branch_block;
        const binding_count = builder.bindings.items.len;
        defer builder.bindings.shrinkRetainingCapacity(binding_count);
        const associated_types = if (optional_variant_index) |variant_index|
            enumeration.variants[variant_index].associated_types
        else
            &.{};
        for (branch.bindings, associated_types, 0..) |binding, binding_type, payload_index| {
            const payload = try self.newValue(builder, binding_type);
            try self.emit(builder, .{ .enum_payload = .{
                .result = payload,
                .operand = subject.value,
                .enumeration = enum_index,
                .variant = optional_variant_index.?,
                .index = payload_index,
            } });
            if (binding.mutable) {
                const local = builder.local_types.items.len;
                try builder.local_types.append(self.allocator, binding_type);
                try self.emit(builder, .{ .local_store = .{ .local = local, .operand = payload } });
                try builder.bindings.append(self.allocator, .{ .name = binding.name, .type = binding_type, .local = local, .mutable = true });
            } else try builder.bindings.append(self.allocator, .{ .name = binding.name, .type = binding_type, .value = payload });
        }
        const branch_value = try self.analyzeExpression(builder, branch.value);
        if (result_type) |expected| {
            if (branch_value.type != expected) {
                const message = try std.fmt.allocPrint(self.allocator, "match branch expects exact type '{s}', found '{s}'", .{
                    self.typeName(expected), self.typeName(branch_value.type),
                });
                return self.fail(branch.value.position, message);
            }
        } else {
            result_type = branch_value.type;
            result = try self.newValue(builder, branch_value.type);
        }
        try self.emit(builder, .{ .copy = .{ .result = result.?, .operand = branch_value.value } });
        self.terminate(builder, .{ .jump = merge_block });
    }
    builder.current_block = merge_block;
    return .{ .type = result_type.?, .value = result.? };
}
