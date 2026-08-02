const std = @import("std");
const Ast = @import("../Ast.zig");

const Allocator = std.mem.Allocator;

pub const Problem = union(enum) {
    too_many,
    unknown: Ast.Expression.NamedArgument,
    duplicate: Ast.Expression.NamedArgument,
    missing: Ast.Parameter,
};

pub const Mapping = union(enum) {
    arguments: []const ?*Ast.Expression,
    problem: Problem,
};

pub fn map(
    allocator: Allocator,
    parameters: []const Ast.Parameter,
    positional: []const *Ast.Expression,
    named: []const Ast.Expression.NamedArgument,
) Allocator.Error!Mapping {
    if (positional.len > parameters.len) return .{ .problem = .too_many };
    const arguments = try allocator.alloc(?*Ast.Expression, parameters.len);
    @memset(arguments, null);
    for (positional, 0..) |argument, index| arguments[index] = argument;

    for (named) |argument| {
        var parameter_index: ?usize = null;
        for (parameters, 0..) |parameter, index| {
            if (std.mem.eql(u8, parameter.name, argument.name)) {
                parameter_index = index;
                break;
            }
        }
        const index = parameter_index orelse return .{ .problem = .{ .unknown = argument } };
        if (arguments[index] != null) return .{ .problem = .{ .duplicate = argument } };
        arguments[index] = argument.value;
    }

    for (parameters, arguments) |parameter, argument| {
        if (argument == null and parameter.default == null) {
            return .{ .problem = .{ .missing = parameter } };
        }
    }
    return .{ .arguments = arguments };
}

pub fn labelsCompatible(left: []const Ast.Parameter, right: []const Ast.Parameter) bool {
    const common = @min(left.len, right.len);
    for (left[0..common], right[0..common]) |left_parameter, right_parameter| {
        if (!std.mem.eql(u8, left_parameter.name, right_parameter.name)) return false;
    }
    return true;
}

pub fn arityRangesOverlap(left: []const Ast.Parameter, right: []const Ast.Parameter) bool {
    const first = @max(requiredCount(left), requiredCount(right));
    const last = @min(left.len, right.len);
    return first <= last;
}

fn requiredCount(parameters: []const Ast.Parameter) usize {
    for (parameters, 0..) |parameter, index| {
        if (parameter.default != null) return index;
    }
    return parameters.len;
}
