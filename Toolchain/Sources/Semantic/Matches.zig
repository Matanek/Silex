const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const Enums = @import("Enums.zig");
const Model = @import("Model.zig");
const Support = @import("Support.zig");
const Availability = @import("Availability.zig");
const Resources = @import("Resources.zig");

const Literal = union(enum) {
    integer: u64,
    boolean: bool,
    string: []const u8,
};

const Prepared = struct {
    subject: ?Model.TypedValue,
    enum_index: ?usize,
    variant_indices: []const ?usize,
    literals: []const ?Literal,
    branch_blocks: []const Ir.BlockId,
    branch_availabilities: []const []const bool,
    next_blocks: []const ?Ir.BlockId,
    merge_block: Ir.BlockId,
};

pub fn analyze(self: anytype, builder: anytype, match_value: Ast.Expression.Match) !Model.TypedValue {
    const prepared = try prepare(self, builder, match_value);
    const availability_count = builder.bindings.items.len;
    var exit_availabilities: std.ArrayList([]const bool) = .empty;
    var result: ?Ir.ValueId = null;
    var result_type: ?Ast.Type = null;
    for (match_value.branches, prepared.branch_blocks, prepared.variant_indices, 0..) |branch, branch_block, variant_index, branch_index| {
        Availability.restore(builder.bindings.items, prepared.branch_availabilities[branch_index]);
        builder.current_block = branch_block;
        const binding_count = builder.bindings.items.len;
        defer builder.bindings.shrinkRetainingCapacity(binding_count);
        try bindBranch(self, builder, prepared, branch, variant_index);
        try enterGuardedBody(self, builder, prepared, branch, branch_index, binding_count);
        try releaseLiteralSubject(self, builder, prepared);
        const branch_expression = if (branch.value) |value| value else yielded: {
            const statements = branch.statements.?;
            if (statements.len == 0 or statements[statements.len - 1] != .yield_statement) {
                return self.fail(branch.position, "value-producing match block must end with 'yield value'");
            }
            const function = self.function_context orelse return self.fail(branch.position, "yield requires an enclosing function");
            if (try self.analyzeStatements(builder, function, statements[0 .. statements.len - 1])) {
                return self.fail(statements[statements.len - 1].position(), "yield is unreachable");
            }
            break :yielded statements[statements.len - 1].yield_statement.value.?;
        };
        const branch_value = try self.analyzeExpression(builder, branch_expression);
        if (result_type) |expected| {
            if (branch_value.type != expected) {
                const message = try std.fmt.allocPrint(self.allocator, "match branch expects exact type '{s}', found '{s}'", .{
                    self.typeName(expected), self.typeName(branch_value.type),
                });
                return self.fail(branch_expression.position, message);
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
    const prepared = try prepare(self, builder, match_value);
    const availability_count = builder.bindings.items.len;
    var exit_availabilities: std.ArrayList([]const bool) = .empty;
    var all_terminated = true;
    for (match_value.branches, prepared.branch_blocks, prepared.variant_indices, 0..) |branch, branch_block, variant_index, branch_index| {
        Availability.restore(builder.bindings.items, prepared.branch_availabilities[branch_index]);
        builder.current_block = branch_block;
        const binding_count = builder.bindings.items.len;
        defer builder.bindings.shrinkRetainingCapacity(binding_count);
        try bindBranch(self, builder, prepared, branch, variant_index);
        try enterGuardedBody(self, builder, prepared, branch, branch_index, binding_count);
        try releaseLiteralSubject(self, builder, prepared);
        const statements = if (branch.statements) |statements| statements else expression: {
            if (!isStatementExpression(branch.value.?)) {
                return self.fail(branch.value.?.position, "match statement expression branch must be a call, cascade, propagated result, or nested match");
            }
            const one = try self.allocator.alloc(Ast.Statement, 1);
            one[0] = .{ .expression_statement = branch.value.? };
            break :expression one;
        };
        for (statements) |statement| if (statement == .yield_statement) {
            return self.fail(statement.position(), "yield is only valid as the final statement of a value-producing match block");
        };
        const terminated = try analyze_branch(context, self, builder, function, statements);
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
    const subject = if (match_value.subject) |expression| try self.analyzeExpression(builder, expression) else null;
    const enum_index = if (subject) |value| Enums.findByType(self, value.type) else null;
    var else_index: ?usize = null;
    for (match_value.branches, 0..) |branch, branch_index| if (branch.is_else) {
        if (else_index != null) return self.fail(branch.position, "match can contain only one else branch");
        if (branch_index + 1 != match_value.branches.len) return self.fail(branch.position, "else match branch must be last");
        else_index = branch_index;
    };
    const variant_indices = try self.allocator.alloc(?usize, match_value.branches.len);
    @memset(variant_indices, null);
    const literals = try self.allocator.alloc(?Literal, match_value.branches.len);
    @memset(literals, null);
    if (subject == null) {
        if (else_index == null) return self.fail(match_value.branches[0].position, "condition match requires an else branch");
    } else if (enum_index) |index| {
        try prepareEnum(self, builder, match_value, index, else_index, variant_indices);
    } else {
        try prepareLiterals(self, match_value, subject.?.type, else_index, literals);
    }

    const branch_blocks = try self.allocator.alloc(Ir.BlockId, match_value.branches.len);
    const branch_availabilities = try self.allocator.alloc([]const bool, match_value.branches.len);
    const next_blocks = try self.allocator.alloc(?Ir.BlockId, match_value.branches.len);
    @memset(next_blocks, null);
    for (branch_blocks) |*block| block.* = try self.newBlock(builder);
    const subject_availability = if (subject != null)
        try Availability.snapshot(self.allocator, builder.bindings.items, builder.bindings.items.len)
    else
        null;
    for (branch_blocks[0 .. branch_blocks.len - 1], 0..) |branch_block, branch_index| {
        const test_value = if (subject == null) condition: {
            const expression = match_value.branches[branch_index].condition orelse
                return self.fail(match_value.branches[branch_index].position, "condition match branch requires a condition");
            const value = try self.analyzeExpression(builder, expression);
            if (value.type != .bool) {
                const message = try std.fmt.allocPrint(self.allocator, "condition match branch requires bool, found '{s}'", .{self.typeName(value.type)});
                return self.fail(expression.position, message);
            }
            branch_availabilities[branch_index] = try Availability.snapshot(self.allocator, builder.bindings.items, builder.bindings.items.len);
            break :condition value.value;
        } else pattern_test: {
            branch_availabilities[branch_index] = subject_availability.?;
            const value = try self.newValue(builder, .bool);
            if (enum_index) |index| {
                try self.emit(builder, .{ .enum_test = .{
                    .result = value,
                    .operand = subject.?.value,
                    .enumeration = index,
                    .variant = variant_indices[branch_index].?,
                } });
            } else {
                const pattern_value = try emitLiteral(self, builder, subject.?.type, literals[branch_index].?);
                try self.emit(builder, .{ .binary = .{
                    .result = value,
                    .operator = .equal,
                    .left = subject.?.value,
                    .right = pattern_value,
                } });
            }
            break :pattern_test value;
        };
        const next = try self.newBlock(builder);
        next_blocks[branch_index] = next;
        self.terminate(builder, .{ .branch = .{ .condition = test_value, .then_block = branch_block, .else_block = next } });
        builder.current_block = next;
    }
    branch_availabilities[branch_availabilities.len - 1] = if (subject_availability) |availability|
        availability
    else
        try Availability.snapshot(self.allocator, builder.bindings.items, builder.bindings.items.len);
    self.terminate(builder, .{ .jump = branch_blocks[branch_blocks.len - 1] });
    const merge_block = try self.newBlock(builder);
    return .{
        .subject = subject,
        .enum_index = enum_index,
        .variant_indices = variant_indices,
        .literals = literals,
        .branch_blocks = branch_blocks,
        .branch_availabilities = branch_availabilities,
        .next_blocks = next_blocks,
        .merge_block = merge_block,
    };
}

fn prepareEnum(
    self: anytype,
    builder: anytype,
    match_value: Ast.Expression.Match,
    enum_index: usize,
    else_index: ?usize,
    variant_indices: []?usize,
) !void {
    const enumeration = self.program.enums[enum_index];
    const unguarded_variants = try self.allocator.alloc(bool, enumeration.variants.len);
    @memset(unguarded_variants, false);
    for (match_value.branches, 0..) |branch, branch_index| {
        if (branch.is_else) {
            continue;
        }
        if (branch.literal != null) return self.fail(branch.position, "enum match requires enum variant branches");
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
            return self.fail(match_value.subject.?.position, message);
        };
    }
    var every_variant_covered = true;
    for (unguarded_variants) |covered| every_variant_covered = every_variant_covered and covered;
    if (else_index != null and every_variant_covered) {
        return self.fail(match_value.branches[else_index.?].position, "else match branch is unreachable because every variant is already covered");
    }
}

fn prepareLiterals(
    self: anytype,
    match_value: Ast.Expression.Match,
    subject_type: Ast.Type,
    else_index: ?usize,
    literals: []?Literal,
) !void {
    if (!subject_type.isInteger() and subject_type != .bool and subject_type != .str) {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "literal match requires a bool, integer, or str subject, found '{s}'",
            .{self.typeName(subject_type)},
        );
        return self.fail(match_value.subject.?.position, message);
    }
    var true_covered = false;
    var false_covered = false;
    for (match_value.branches, 0..) |branch, branch_index| {
        if (branch.is_else) continue;
        const source_literal = branch.literal orelse return self.fail(branch.position, "literal match requires literal branches");
        const literal = try resolveLiteral(self, source_literal, subject_type, branch.position);
        for (literals[0..branch_index], match_value.branches[0..branch_index]) |previous, previous_branch| {
            if (previous == null or !literalEqual(previous.?, literal) or previous_branch.guard != null) continue;
            return self.fail(branch.position, if (branch.guard == null)
                "literal is matched more than once"
            else
                "guarded branch for literal is unreachable after its unguarded branch");
        }
        literals[branch_index] = literal;
        if (branch.guard == null) switch (literal) {
            .boolean => |value| if (value) {
                true_covered = true;
            } else {
                false_covered = true;
            },
            else => {},
        };
    }
    const exhaustive = subject_type == .bool and true_covered and false_covered;
    if (else_index == null and !exhaustive) {
        if (subject_type == .bool) {
            return self.fail(match_value.subject.?.position, if (!true_covered)
                "match is missing literal 'true'"
            else
                "match is missing literal 'false'");
        }
        const message = try std.fmt.allocPrint(self.allocator, "match on '{s}' requires an else branch", .{self.typeName(subject_type)});
        return self.fail(match_value.subject.?.position, message);
    }
    if (else_index != null and exhaustive) {
        return self.fail(match_value.branches[else_index.?].position, "else match branch is unreachable because every boolean value is already covered");
    }
}

fn resolveLiteral(
    self: anytype,
    literal: Ast.Expression.MatchLiteral,
    subject_type: Ast.Type,
    position: @import("../Source.zig").Position,
) !Literal {
    return switch (literal) {
        .integer => |integer| integer_literal: {
            if (!subject_type.isInteger()) return literalTypeMismatch(self, position, subject_type, "integer");
            const magnitude = try Support.parseIntegerMagnitude(self, integer.lexeme, position);
            if (!Numeric.fitsMagnitude(magnitude, integer.negative, subject_type)) {
                const message = try std.fmt.allocPrint(self.allocator, "integer literal is outside the range of '{s}'", .{self.typeName(subject_type)});
                return self.fail(position, message);
            }
            break :integer_literal .{ .integer = Numeric.fromMagnitude(magnitude, integer.negative, subject_type).bits };
        },
        .boolean => |value| if (subject_type == .bool)
            .{ .boolean = value }
        else
            literalTypeMismatch(self, position, subject_type, "bool"),
        .string => |value| if (subject_type == .str)
            .{ .string = value }
        else
            literalTypeMismatch(self, position, subject_type, "str"),
    };
}

fn literalTypeMismatch(self: anytype, position: @import("../Source.zig").Position, subject_type: Ast.Type, found: []const u8) !Literal {
    const message = try std.fmt.allocPrint(
        self.allocator,
        "match branch expects a literal of type '{s}', found '{s}'",
        .{ self.typeName(subject_type), found },
    );
    return self.fail(position, message);
}

fn literalEqual(left: Literal, right: Literal) bool {
    return switch (left) {
        .integer => |value| right == .integer and value == right.integer,
        .boolean => |value| right == .boolean and value == right.boolean,
        .string => |value| right == .string and std.mem.eql(u8, value, right.string),
    };
}

fn emitLiteral(self: anytype, builder: anytype, subject_type: Ast.Type, literal: Literal) !Ir.ValueId {
    const result = try self.newValue(builder, subject_type);
    try self.emit(builder, switch (literal) {
        .integer => |bits| .{ .constant_int = .{ .result = result, .bits = bits } },
        .boolean => |value| .{ .constant_bool = .{ .result = result, .value = value } },
        .string => |value| .{ .constant_str = .{ .result = result, .value = value } },
    });
    return result;
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
    const enum_index = prepared.enum_index orelse return;
    const enumeration = self.program.enums[enum_index];
    const associated_types = if (optional_variant_index) |variant_index| enumeration.variants[variant_index].associated_types else &.{};
    for (branch.bindings, associated_types, 0..) |binding, binding_type, payload_index| {
        const payload = try self.newValue(builder, binding_type);
        try self.emit(builder, .{ .enum_payload = .{
            .result = payload,
            .operand = prepared.subject.?.value,
            .enumeration = enum_index,
            .variant = optional_variant_index.?,
            .index = payload_index,
        } });
        if (binding.ignored) {
            if (!prepared.subject.?.transferred and Resources.requiresRetain(self, binding_type)) {
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
            if (!prepared.subject.?.transferred and Resources.requiresRetain(self, binding_type)) {
                try Resources.retainValue(self, builder, binding_type, payload);
            }
            const local = builder.local_types.items.len;
            try builder.local_types.append(self.allocator, binding_type);
            try self.emit(builder, .{ .local_store = .{ .local = local, .operand = payload } });
            try builder.bindings.append(self.allocator, .{ .name = binding.name, .type = binding_type, .local = local, .mutable = true });
        } else {
            if (!prepared.subject.?.transferred and Resources.requiresRetain(self, binding_type)) {
                try Resources.retainValue(self, builder, binding_type, payload);
            }
            try builder.bindings.append(self.allocator, .{ .name = binding.name, .type = binding_type, .value = payload });
        }
    }
}

fn releaseLiteralSubject(self: anytype, builder: anytype, prepared: Prepared) !void {
    const subject = prepared.subject orelse return;
    if (prepared.enum_index == null and subject.transferred and Resources.needsDrop(self, subject.type)) {
        try Resources.emitDrop(self, builder, subject.type, subject.value);
    }
}

fn isStatementExpression(expression: *const Ast.Expression) bool {
    return switch (expression.value) {
        .call, .cascade, .match_expression => true,
        .unary => |unary| unary.operator == .propagate,
        else => false,
    };
}
