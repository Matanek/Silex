const std = @import("std");
const Ast = @import("../Ast.zig");
const Model = @import("Model.zig");
const Support = @import("Support.zig");
const Resources = @import("Resources.zig");

pub fn analyzeIdentifier(self: anytype, builder: anytype, position: @import("../Source.zig").Position, name: []const u8) !Model.TypedValue {
    const binding = Support.findBinding(builder.bindings.items, name) orelse {
        const message = if (self.anonymous_function_context)
            try std.fmt.allocPrint(self.allocator, "anonymous functions cannot capture surrounding value '{s}' yet", .{name})
        else
            try std.fmt.allocPrint(self.allocator, "unknown variable '{s}'", .{name});
        return self.fail(position, message);
    };
    if (!binding.available) {
        const message = try std.fmt.allocPrint(self.allocator, "value '{s}' was moved and is unavailable", .{name});
        return self.fail(position, message);
    }
    if (binding.borrowed_root == null) try ensureRootReadable(self, builder, name, position);
    const borrowed_root = binding.borrowed_root orelse if (binding.parameter_mode != .value) binding.name else null;
    const borrowed_mode = if (binding.borrowed_mode != .value) binding.borrowed_mode else binding.parameter_mode;
    if (binding.refined_type) |type_value| return .{
        .type = type_value,
        .value = binding.refined_value.?,
        .borrowed_root = borrowed_root,
        .borrowed_mode = borrowed_mode,
        .reference = binding.reference,
    };
    if (!binding.type.hasRuntimeValue()) {
        const message = try std.fmt.allocPrint(self.allocator, "values of type '{s}' are not executable yet", .{binding.type.name()});
        return self.fail(position, message);
    }
    if (binding.local) |local| {
        const result = try self.newValue(builder, binding.type);
        try self.emit(builder, .{ .local_load = .{ .result = result, .local = local } });
        return .{ .type = binding.type, .value = result, .borrowed_root = borrowed_root, .borrowed_mode = borrowed_mode, .reference = binding.reference };
    }
    if (binding.reference) |reference| {
        const result = try self.newValue(builder, binding.type);
        try self.emit(builder, .{ .reference_load = .{ .result = result, .reference = reference } });
        return .{ .type = binding.type, .value = result, .borrowed_root = borrowed_root, .borrowed_mode = borrowed_mode, .reference = reference };
    }
    return .{ .type = binding.type, .value = binding.value.?, .borrowed_root = borrowed_root, .borrowed_mode = borrowed_mode, .reference = binding.reference };
}

pub fn requireOwned(self: anytype, value: Model.TypedValue, position: @import("../Source.zig").Position, action: []const u8) !void {
    const root = value.borrowed_root orelse return;
    const message = if (value.borrowed_mode == .read)
        try std.fmt.allocPrint(self.allocator, "read-reference parameter '{s}' cannot be {s}", .{ root, action })
    else
        try std.fmt.allocPrint(self.allocator, "mutable-reference parameter '{s}' cannot be {s}", .{ root, action });
    return self.fail(position, message);
}

pub fn validateReadArguments(self: anytype, parameters: []const Ast.Parameter, arguments: []const *Ast.Expression) !void {
    for (parameters[0..arguments.len], arguments, 0..) |parameter, argument, index| {
        if (parameter.mode == .value) continue;
        const root = rootName(argument) orelse continue;
        for (parameters[0..arguments.len], arguments, 0..) |other_parameter, other, other_index| {
            if (index == other_index or other_parameter.mode == .value or parameter.mode == other_parameter.mode) continue;
            if (sameRoot(other, root)) {
                const message = try std.fmt.allocPrint(self.allocator, "cannot borrow '{s}' as both '@' and '&' in the same call", .{root});
                return self.fail(other.position, message);
            }
        }
    }
    for (parameters[0..arguments.len], arguments, 0..) |parameter, argument, index| {
        if (parameter.mode != .read) continue;
        const root = rootName(argument) orelse continue;
        for (parameters[0..arguments.len], arguments, 0..) |other_parameter, other, other_index| {
            if (index == other_index or other_parameter.mode != .value or !Resources.containsClass(self, other_parameter.type)) continue;
            if (sameRoot(other, root)) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "cannot pass '{s}' as both a read reference and a mutation-capable class value",
                    .{root},
                );
                return self.fail(other.position, message);
            }
        }
    }
    for (parameters[0..arguments.len], arguments, 0..) |parameter, argument, index| {
        if (parameter.mode != .read) continue;
        const root = rootName(argument) orelse continue;
        for (arguments[index + 1 ..]) |later| if (conflictsWithRead(later, root)) {
            const message = try std.fmt.allocPrint(self.allocator, "cannot move or mutate '{s}' while it is passed as '@{s}'", .{ root, parameter.type.name() });
            return self.fail(later.position, message);
        };
    }
}

pub fn validateMappedReadArguments(self: anytype, parameters: []const Ast.Parameter, arguments: []const ?*Ast.Expression) !void {
    for (parameters, arguments, 0..) |parameter, maybe_argument, index| {
        const argument = maybe_argument orelse continue;
        if (parameter.mode == .value) continue;
        const root = rootName(argument) orelse continue;
        for (parameters, arguments, 0..) |other_parameter, maybe_other, other_index| {
            const other = maybe_other orelse continue;
            if (index == other_index or other_parameter.mode == .value or parameter.mode == other_parameter.mode) continue;
            if (sameRoot(other, root)) {
                const message = try std.fmt.allocPrint(self.allocator, "cannot borrow '{s}' as both '@' and '&' in the same call", .{root});
                return self.fail(other.position, message);
            }
        }
    }
    for (parameters, arguments, 0..) |parameter, maybe_argument, index| {
        const argument = maybe_argument orelse continue;
        if (parameter.mode != .read) continue;
        const root = rootName(argument) orelse continue;
        for (parameters, arguments, 0..) |other_parameter, maybe_other, other_index| {
            const other = maybe_other orelse continue;
            if (index == other_index or other_parameter.mode != .value or !Resources.containsClass(self, other_parameter.type)) continue;
            if (sameRoot(other, root)) {
                const message = try std.fmt.allocPrint(self.allocator, "cannot pass '{s}' as both a read reference and a mutation-capable class value", .{root});
                return self.fail(other.position, message);
            }
        }
    }
    for (parameters, arguments, 0..) |parameter, maybe_argument, index| {
        const argument = maybe_argument orelse continue;
        if (parameter.mode != .read) continue;
        const root = rootName(argument) orelse continue;
        for (arguments[index + 1 ..]) |maybe_later| {
            const later = maybe_later orelse continue;
            if (conflictsWithRead(later, root)) {
                const message = try std.fmt.allocPrint(self.allocator, "cannot move or mutate '{s}' while it is passed as '@{s}'", .{ root, parameter.type.name() });
                return self.fail(later.position, message);
            }
        }
    }
}

pub fn ensureRootUnborrowed(self: anytype, builder: anytype, root: []const u8, position: @import("../Source.zig").Position) !void {
    for (builder.bindings.items) |binding| {
        const borrowed_root = binding.borrowed_root orelse continue;
        if (!std.mem.eql(u8, borrowed_root, root)) continue;
        const message = try std.fmt.allocPrint(self.allocator, "cannot mutate or move '{s}' while alias '{s}' is alive", .{ root, binding.name });
        return self.fail(position, message);
    }
}

pub fn ensureRootReadable(self: anytype, builder: anytype, root: []const u8, position: @import("../Source.zig").Position) !void {
    for (builder.bindings.items) |binding| {
        const borrowed_root = binding.borrowed_root orelse continue;
        if (binding.borrowed_mode != .mutable or !std.mem.eql(u8, borrowed_root, root)) continue;
        const message = try std.fmt.allocPrint(self.allocator, "cannot read '{s}' while mutable alias '{s}' is alive", .{ root, binding.name });
        return self.fail(position, message);
    }
}

pub fn rootName(expression: *const Ast.Expression) ?[]const u8 {
    return switch (expression.value) {
        .identifier => |name| name,
        .field_access => |access| rootName(access.base),
        .index_access => |access| rootName(access.base),
        .slice_access => |access| rootName(access.base),
        else => null,
    };
}

fn conflictsWithRead(expression: *const Ast.Expression, root: []const u8) bool {
    return switch (expression.value) {
        .unary => |unary| (unary.operator == .move and sameRoot(unary.operand, root)) or conflictsWithRead(unary.operand, root),
        .call => |call| call_conflict: {
            if (call.receiver) |receiver| {
                if (sameRoot(receiver, root) and isCollectionMutation(call.name)) break :call_conflict true;
                if (conflictsWithRead(receiver, root)) break :call_conflict true;
            }
            for (call.arguments) |argument| if (conflictsWithRead(argument, root)) break :call_conflict true;
            for (call.named_arguments) |argument| if (conflictsWithRead(argument.value, root)) break :call_conflict true;
            break :call_conflict false;
        },
        .cascade => |cascade| cascade_conflict: {
            if (conflictsWithRead(cascade.receiver, root)) break :cascade_conflict true;
            for (cascade.operations) |operation| switch (operation) {
                .method_call => |method| {
                    for (method.arguments) |argument| if (conflictsWithRead(argument, root)) break :cascade_conflict true;
                    for (method.named_arguments) |argument| if (conflictsWithRead(argument.value, root)) break :cascade_conflict true;
                },
                .field_assignment => |field| if (conflictsWithRead(field.value, root)) break :cascade_conflict true,
            };
            break :cascade_conflict false;
        },
        .field_access => |access| conflictsWithRead(access.base, root),
        .binary => |binary| conflictsWithRead(binary.left, root) or conflictsWithRead(binary.right, root),
        .conversion => |conversion| conflictsWithRead(conversion.operand, root),
        .string_count => |operand| conflictsWithRead(operand, root),
        .sequence_literal => |literal| for (literal.values) |value| {
            if (conflictsWithRead(value, root)) break true;
        } else false,
        .index_access => |access| conflictsWithRead(access.base, root) or conflictsWithRead(access.index, root),
        .slice_access => |access| conflictsWithRead(access.base, root) or conflictsWithRead(access.start, root) or conflictsWithRead(access.end, root),
        .interpolated_string => |interpolation| for (interpolation.parts) |part| switch (part) {
            .expression => |value| if (conflictsWithRead(value, root)) break true,
            else => {},
        } else false,
        .match_expression => |match_value| conflictsWithRead(match_value.subject, root),
        else => false,
    };
}

fn sameRoot(expression: *const Ast.Expression, root: []const u8) bool {
    const candidate = rootName(expression) orelse return false;
    return std.mem.eql(u8, candidate, root);
}

fn isCollectionMutation(name: []const u8) bool {
    return std.mem.eql(u8, name, "swap") or std.mem.eql(u8, name, "reverse") or std.mem.eql(u8, name, "replace") or
        std.mem.eql(u8, name, "append") or std.mem.eql(u8, name, "prepend") or std.mem.eql(u8, name, "insert") or
        std.mem.eql(u8, name, "take") or std.mem.eql(u8, name, "take_first") or std.mem.eql(u8, name, "take_last") or
        std.mem.eql(u8, name, "clear");
}
