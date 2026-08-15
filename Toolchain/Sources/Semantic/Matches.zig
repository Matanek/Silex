const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Enums = @import("Enums.zig");
const Model = @import("Model.zig");
const Support = @import("Support.zig");
const Availability = @import("Availability.zig");
const Resources = @import("Resources.zig");

const Prepared = struct {
    subject: Model.TypedValue,
    enum_index: usize,
    variant_indices: []const ?usize,
    branch_blocks: []const Ir.BlockId,
    next_blocks: []const ?Ir.BlockId,
    merge_block: Ir.BlockId,
};

pub fn analyze(self: anytype, builder: anytype, match_value: Ast.Expression.Match) !Model.TypedValue {
    if (match_value.imperative) return self.fail(match_value.subject.position, "imperative match cannot be used as a value");
    const prepared = try prepare(self, builder, match_value);
    const availability_count = builder.bindings.items.len;
    const branch_availability = try Availability.snapshot(self.allocator, builder.bindings.items, availability_count);
    var exit_availabilities: std.ArrayList([]const bool) = .empty;
    var result: ?Ir.ValueId = null;
    var result_type: ?Ast.Type = null;
    for (match_value.branches, prepared.branch_blocks, prepared.variant_indices, 0..) |branch, branch_block, variant_index, branch_index| {
        Availability.restore(builder.bindings.items, branch_availability);
        builder.current_block = branch_block;
        const binding_count = builder.bindings.items.len;
        defer builder.bindings.shrinkRetainingCapacity(binding_count);
        try bindBranch(self, builder, prepared, branch, variant_index);
        try enterGuardedBody(self, builder, prepared, branch, branch_index, binding_count);
        const branch_value = try self.analyzeExpression(builder, branch.value.?);
        if (result_type) |expected| {
            if (branch_value.type != expected) {
                const message = try std.fmt.allocPrint(self.allocator, "match branch expects exact type '{s}', found '{s}'", .{
                    self.typeName(expected), self.typeName(branch_value.type),
                });
                return self.fail(branch.value.?.position, message);
            }
        } else {
            result_type = branch_value.type;
            result = try self.newValue(builder, branch_value.type);
        }
        if (Resources.requiresRetain(self, branch_value.type) and !branch_value.transferred) {
            try Resources.retainValue(self, builder, branch_value.type, branch_value.value);
        }
        try self.emit(builder, .{ .copy = .{ .result = result.?, .operand = branch_value.value } });
        try Resources.emitActiveDrops(self, builder, binding_count);
        try exit_availabilities.append(self.allocator, try Availability.snapshot(self.allocator, builder.bindings.items, availability_count));
        self.terminate(builder, .{ .jump = prepared.merge_block });
    }
    const merged_availability = try self.allocator.dupe(bool, exit_availabilities.items[0]);
    for (exit_availabilities.items[1..]) |state| Availability.merge(merged_availability, state);
    Availability.restore(builder.bindings.items, merged_availability);
    builder.current_block = prepared.merge_block;
    return .{
        .type = result_type.?,
        .value = result.?,
        .transferred = Resources.ownsValue(self, result_type.?),
    };
}

pub fn analyzeStatement(
    self: anytype,
    builder: anytype,
    function: Ast.Function,
    match_value: Ast.Expression.Match,
) !bool {
    return analyzeStatementUsing(self, builder, function, match_value, {}, analyzeOrdinaryBranch);
}

fn analyzeOrdinaryBranch(
    _: void,
    self: anytype,
    builder: anytype,
    function: Ast.Function,
    statements: []const Ast.Statement,
) !bool {
    return self.analyzeStatements(builder, function, statements);
}

pub fn analyzeStatementUsing(
    self: anytype,
    builder: anytype,
    function: Ast.Function,
    match_value: Ast.Expression.Match,
    context: anytype,
    comptime analyze_branch: anytype,
) !bool {
    if (!match_value.imperative) return self.fail(match_value.subject.position, "match statement requires block branches");
    const prepared = try prepare(self, builder, match_value);
    const availability_count = builder.bindings.items.len;
    const branch_availability = try Availability.snapshot(self.allocator, builder.bindings.items, availability_count);
    var exit_availabilities: std.ArrayList([]const bool) = .empty;
    var all_terminated = true;
    for (match_value.branches, prepared.branch_blocks, prepared.variant_indices, 0..) |branch, branch_block, variant_index, branch_index| {
        Availability.restore(builder.bindings.items, branch_availability);
        builder.current_block = branch_block;
        const binding_count = builder.bindings.items.len;
        defer builder.bindings.shrinkRetainingCapacity(binding_count);
        try bindBranch(self, builder, prepared, branch, variant_index);
        try enterGuardedBody(self, builder, prepared, branch, branch_index, binding_count);
        const terminated = try analyze_branch(context, self, builder, function, branch.statements.?);
        if (!terminated) {
            try Resources.emitActiveDrops(self, builder, binding_count);
            all_terminated = false;
            try exit_availabilities.append(self.allocator, try Availability.snapshot(self.allocator, builder.bindings.items, availability_count));
            self.terminate(builder, .{ .jump = prepared.merge_block });
        }
    }
    if (all_terminated) {
        if (prepared.merge_block + 1 == builder.blocks.items.len) {
            builder.blocks.items.len -= 1;
        } else {
            // A nested control-flow construct may have appended blocks after
            // the match merge. Keep the now-unreachable merge structurally
            // valid without renumbering every later block.
            builder.blocks.items[prepared.merge_block].terminator = .{ .jump = prepared.branch_blocks[0] };
        }
        return true;
    }
    const merged_availability = try self.allocator.dupe(bool, exit_availabilities.items[0]);
    for (exit_availabilities.items[1..]) |state| Availability.merge(merged_availability, state);
    Availability.restore(builder.bindings.items, merged_availability);
    builder.current_block = prepared.merge_block;
    return false;
}

fn prepare(self: anytype, builder: anytype, match_value: Ast.Expression.Match) !Prepared {
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
    const variant_indices = try self.allocator.alloc(?usize, match_value.branches.len);
    const unguarded_variants = try self.allocator.alloc(bool, enumeration.variants.len);
    @memset(unguarded_variants, false);
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
            if (previous.is_else or !std.mem.eql(u8, previous.variant, branch.variant) or previous.guard != null) continue;
            const message = if (branch.guard == null)
                try std.fmt.allocPrint(self.allocator, "variant '{s}' is matched more than once", .{branch.variant})
            else
                try std.fmt.allocPrint(self.allocator, "guarded branch for variant '{s}' is unreachable after its unguarded branch", .{branch.variant});
            return self.fail(branch.position, message);
        }
        const variant = enumeration.variants[variant_index];
        if (branch.bindings.len != variant.associated_types.len) {
            const message = try std.fmt.allocPrint(self.allocator, "variant '{s}' exposes {d} associated values, pattern binds {d}", .{
                branch.variant, variant.associated_types.len, branch.bindings.len,
            });
            return self.fail(branch.position, message);
        }
        for (branch.bindings, 0..) |binding, binding_index| {
            if (binding.ignored) continue;
            if (Support.findBinding(builder.bindings.items, binding.name) != null) {
                const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' is already declared in this scope", .{binding.name});
                return self.fail(binding.position, message);
            }
            for (branch.bindings[0..binding_index]) |previous| if (!previous.ignored and std.mem.eql(u8, previous.name, binding.name)) {
                const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' is already declared in this pattern", .{binding.name});
                return self.fail(binding.position, message);
            };
        }
        variant_indices[branch_index] = variant_index;
        if (branch.guard == null) unguarded_variants[variant_index] = true;
    }
    if (else_index == null) {
        for (enumeration.variants, unguarded_variants) |variant, covered| if (!covered) {
            var mentioned = false;
            for (match_value.branches) |branch| if (!branch.is_else and std.mem.eql(u8, branch.variant, variant.name)) {
                mentioned = true;
                break;
            };
            const message = if (mentioned)
                try std.fmt.allocPrint(self.allocator, "match is missing unguarded branch for variant '{s}'", .{variant.name})
            else
                try std.fmt.allocPrint(self.allocator, "match is missing variant '{s}'", .{variant.name});
            return self.fail(match_value.subject.position, message);
        };
    }
    var every_variant_covered = true;
    for (unguarded_variants) |covered| every_variant_covered = every_variant_covered and covered;
    if (else_index != null and every_variant_covered) {
        return self.fail(match_value.branches[else_index.?].position, "else match branch is unreachable because every variant is already covered");
    }

    const branch_blocks = try self.allocator.alloc(Ir.BlockId, match_value.branches.len);
    const next_blocks = try self.allocator.alloc(?Ir.BlockId, match_value.branches.len);
    @memset(next_blocks, null);
    for (branch_blocks) |*block| block.* = try self.newBlock(builder);
    for (branch_blocks[0 .. branch_blocks.len - 1], 0..) |branch_block, branch_index| {
        const test_value = try self.newValue(builder, .bool);
        try self.emit(builder, .{ .enum_test = .{
            .result = test_value,
            .operand = subject.value,
            .enumeration = enum_index,
            .variant = variant_indices[branch_index].?,
        } });
        const next = try self.newBlock(builder);
        next_blocks[branch_index] = next;
        self.terminate(builder, .{ .branch = .{ .condition = test_value, .then_block = branch_block, .else_block = next } });
        builder.current_block = next;
    }
    self.terminate(builder, .{ .jump = branch_blocks[branch_blocks.len - 1] });
    const merge_block = try self.newBlock(builder);
    return .{
        .subject = subject,
        .enum_index = enum_index,
        .variant_indices = variant_indices,
        .branch_blocks = branch_blocks,
        .next_blocks = next_blocks,
        .merge_block = merge_block,
    };
}

fn enterGuardedBody(
    self: anytype,
    builder: anytype,
    prepared: Prepared,
    branch: Ast.Expression.MatchBranch,
    branch_index: usize,
    binding_count: usize,
) !void {
    const guard = branch.guard orelse return;
    const condition = try self.analyzeExpression(builder, guard);
    if (condition.type != .bool) {
        const message = try std.fmt.allocPrint(self.allocator, "match guard requires bool, found '{s}'", .{self.typeName(condition.type)});
        return self.fail(guard.position, message);
    }
    const active = try Availability.snapshot(self.allocator, builder.bindings.items, builder.bindings.items.len);
    const body_block = try self.newBlock(builder);
    const cleanup_block = try self.newBlock(builder);
    self.terminate(builder, .{ .branch = .{
        .condition = condition.value,
        .then_block = body_block,
        .else_block = cleanup_block,
    } });
    builder.current_block = cleanup_block;
    try Resources.emitActiveDrops(self, builder, binding_count);
    self.terminate(builder, .{ .jump = prepared.next_blocks[branch_index].? });
    Availability.restore(builder.bindings.items, active);
    builder.current_block = body_block;
}

fn bindBranch(
    self: anytype,
    builder: anytype,
    prepared: Prepared,
    branch: Ast.Expression.MatchBranch,
    optional_variant_index: ?usize,
) !void {
    const enumeration = self.program.enums[prepared.enum_index];
    const associated_types = if (optional_variant_index) |variant_index| enumeration.variants[variant_index].associated_types else &.{};
    for (branch.bindings, associated_types, 0..) |binding, binding_type, payload_index| {
        const payload = try self.newValue(builder, binding_type);
        try self.emit(builder, .{ .enum_payload = .{
            .result = payload,
            .operand = prepared.subject.value,
            .enumeration = prepared.enum_index,
            .variant = optional_variant_index.?,
            .index = payload_index,
        } });
        if (binding.ignored) {
            if (!prepared.subject.transferred and Resources.requiresRetain(self, binding_type)) {
                try Resources.retainValue(self, builder, binding_type, payload);
            }
            try builder.bindings.append(self.allocator, .{
                .name = "__ignored_match_payload",
                .type = binding_type,
                .value = payload,
            });
            continue;
        }
        if (binding.mutable) {
            if (!prepared.subject.transferred and Resources.requiresRetain(self, binding_type)) {
                try Resources.retainValue(self, builder, binding_type, payload);
            }
            const local = builder.local_types.items.len;
            try builder.local_types.append(self.allocator, binding_type);
            try self.emit(builder, .{ .local_store = .{ .local = local, .operand = payload } });
            try builder.bindings.append(self.allocator, .{ .name = binding.name, .type = binding_type, .local = local, .mutable = true });
        } else {
            if (!prepared.subject.transferred and Resources.requiresRetain(self, binding_type)) {
                try Resources.retainValue(self, builder, binding_type, payload);
            }
            try builder.bindings.append(self.allocator, .{ .name = binding.name, .type = binding_type, .value = payload });
        }
    }
}
