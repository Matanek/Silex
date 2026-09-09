const std = @import("std");
const Ast = @import("../../Ast.zig");
const FrontendModule = @import("../../Frontend.zig");

pub const Parameter = struct {
    name: []const u8,
    type_name: []const u8,
};

pub const InstanceMember = struct {
    name: []const u8,
    kind: u8,
    detail: []const u8,
    insert_text: []const u8,
    insert_text_format: ?u8 = null,
};

pub fn parameter(
    allocator: std.mem.Allocator,
    source: []const u8,
    function_name: []const u8,
    parameter_name: []const u8,
) !Parameter {
    var frontend = FrontendModule.Frontend.init(allocator);
    const program = (try frontend.compile(source)).ast;
    for (program.functions) |function| {
        if (function.is_anonymous or !std.mem.eql(u8, function.name, function_name)) continue;
        for (function.parameters) |candidate| {
            if (!std.mem.eql(u8, candidate.name, parameter_name)) continue;
            return .{
                .name = candidate.name,
                .type_name = typeName(program, candidate.type),
            };
        }
        return error.MissingOracleParameter;
    }
    return error.MissingOracleFunction;
}

pub fn publicInstanceMembers(
    allocator: std.mem.Allocator,
    source: []const u8,
    type_name: []const u8,
) ![]const []const u8 {
    var frontend = FrontendModule.Frontend.init(allocator);
    const program = (try frontend.compile(source)).ast;
    var labels: std.ArrayList([]const u8) = .empty;
    for (program.structures) |structure| {
        if (!matchesType(structure.name, type_name)) continue;
        for (structure.fields) |field| {
            if (field.is_static or !field.is_public or field.is_private or field.is_protected or field.is_local) continue;
            try labels.append(allocator, field.name);
        }
        for (structure.methods) |method| {
            if (method.is_static or !method.is_public or method.is_private or method.is_protected or method.is_local) continue;
            try labels.append(allocator, method.name);
        }
        std.mem.sort([]const u8, labels.items, {}, struct {
            fn lessThan(_: void, left: []const u8, right: []const u8) bool {
                return std.mem.lessThan(u8, left, right);
            }
        }.lessThan);
        return labels.toOwnedSlice(allocator);
    }
    return error.MissingOracleType;
}

pub fn publicInstanceMember(
    allocator: std.mem.Allocator,
    source: []const u8,
    type_name: []const u8,
    member_name: []const u8,
) !InstanceMember {
    var frontend = FrontendModule.Frontend.init(allocator);
    const program = (try frontend.compile(source)).ast;
    for (program.structures) |structure| {
        if (!matchesType(structure.name, type_name)) continue;
        for (structure.fields) |field| {
            if (field.is_static or !field.is_public or field.is_private or field.is_protected or field.is_local or
                !std.mem.eql(u8, field.name, member_name)) continue;
            const member_type = if (field.property) |property| property.value_type else field.type;
            return .{
                .name = field.name,
                .kind = if (field.property != null) 10 else 5,
                .detail = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ field.name, typeName(program, member_type) }),
                .insert_text = field.name,
            };
        }
        for (structure.methods) |method| {
            if (method.is_static or !method.is_public or method.is_private or method.is_protected or method.is_local or
                method.accessor != null or !std.mem.eql(u8, method.name, member_name)) continue;
            if (method.parameters.len != 0) return error.OracleSnippetNotImplemented;
            return .{
                .name = method.name,
                .kind = 2,
                .detail = try std.fmt.allocPrint(
                    allocator,
                    "{s}() {s}",
                    .{ method.name, typeName(program, method.return_type) },
                ),
                .insert_text = try std.fmt.allocPrint(allocator, "{s}()", .{method.name}),
            };
        }
        return error.MissingOracleMember;
    }
    return error.MissingOracleType;
}

fn matchesType(candidate: []const u8, requested: []const u8) bool {
    if (std.mem.eql(u8, candidate, requested)) return true;
    return candidate.len > requested.len + 1 and
        std.mem.startsWith(u8, candidate, requested) and
        candidate[requested.len] == '<' and
        candidate[candidate.len - 1] == '>';
}

fn typeName(program: Ast.Program, type_value: Ast.Type) []const u8 {
    const index = type_value.structureIndex() orelse return type_value.name();
    return if (index < program.type_names.len) program.type_names[index] else "structure";
}
