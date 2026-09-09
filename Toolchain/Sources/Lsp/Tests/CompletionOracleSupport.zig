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

pub fn functionValue(
    allocator: std.mem.Allocator,
    source: []const u8,
    function_name: []const u8,
) !InstanceMember {
    var frontend = FrontendModule.Frontend.init(allocator);
    const program = (try frontend.compile(source)).ast;
    for (program.functions) |function| {
        if (function.is_anonymous or !std.mem.eql(u8, function.name, function_name)) continue;
        if (function.parameters.len != 0) return error.OracleSnippetNotImplemented;
        return .{
            .name = function.name,
            .kind = 3,
            .detail = try std.fmt.allocPrint(
                allocator,
                "{s}() {s}",
                .{ function.name, typeName(program, function.return_type) },
            ),
            .insert_text = try std.fmt.allocPrint(allocator, "{s}()", .{function.name}),
        };
    }
    return error.MissingOracleFunction;
}

pub fn functionReference(
    allocator: std.mem.Allocator,
    source: []const u8,
    function_name: []const u8,
) !InstanceMember {
    var frontend = FrontendModule.Frontend.init(allocator);
    const program = (try frontend.compile(source)).ast;
    for (program.functions) |function| {
        if (function.is_anonymous or !std.mem.eql(u8, function.name, function_name)) continue;
        return .{
            .name = function.name,
            .kind = 3,
            .detail = try callableDeclarationSignature(allocator, program, function),
            .insert_text = function.name,
        };
    }
    return error.MissingOracleFunction;
}

pub fn methodReference(
    allocator: std.mem.Allocator,
    source: []const u8,
    type_name: []const u8,
    method_name: []const u8,
) !InstanceMember {
    var frontend = FrontendModule.Frontend.init(allocator);
    const program = (try frontend.compile(source)).ast;
    for (program.structures) |structure| {
        if (!matchesType(structure.name, type_name)) continue;
        for (structure.methods) |method| {
            if (!std.mem.eql(u8, method.name, method_name)) continue;
            return .{
                .name = method.name,
                .kind = 2,
                .detail = try callableDeclarationSignature(allocator, program, method),
                .insert_text = method.name,
            };
        }
        return error.MissingOracleMember;
    }
    return error.MissingOracleType;
}

fn callableDeclarationSignature(
    allocator: std.mem.Allocator,
    program: Ast.Program,
    function: Ast.Function,
) ![]const u8 {
    var result = try std.fmt.allocPrint(allocator, "{s}(", .{function.name});
    for (function.parameters, 0..) |parameter_value, index| result = try std.fmt.allocPrint(
        allocator,
        "{s}{s}{s}:{s}",
        .{
            result,
            if (index == 0) "" else ", ",
            parameter_value.name,
            typeName(program, parameter_value.type),
        },
    );
    return std.fmt.allocPrint(allocator, "{s}) {s}", .{ result, typeName(program, function.return_type) });
}

pub fn publicInstanceMembers(
    allocator: std.mem.Allocator,
    source: []const u8,
    type_name: []const u8,
) ![]const []const u8 {
    var frontend = FrontendModule.Frontend.init(allocator);
    const program = (try frontend.compile(source)).ast;
    return publicInstanceMembersFromProgram(allocator, program, type_name);
}

pub fn publicInstanceMembersFromProgram(
    allocator: std.mem.Allocator,
    program: Ast.Program,
    type_name: []const u8,
) ![]const []const u8 {
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
    return publicInstanceMemberFromProgram(allocator, program, type_name, member_name);
}

pub fn publicInstanceMemberFromProgram(
    allocator: std.mem.Allocator,
    program: Ast.Program,
    type_name: []const u8,
    member_name: []const u8,
) !InstanceMember {
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

pub fn namedTupleFieldsFromFunction(
    allocator: std.mem.Allocator,
    source: []const u8,
    function_name: []const u8,
) ![]const InstanceMember {
    var frontend = FrontendModule.Frontend.init(allocator);
    const program = (try frontend.compile(source)).ast;
    var return_type: ?Ast.Type = null;
    for (program.functions) |function| {
        if (!function.is_anonymous and std.mem.eql(u8, function.name, function_name)) {
            return_type = function.return_type;
            break;
        }
    }
    const tuple_name = typeName(program, return_type orelse return error.MissingOracleFunction);
    for (program.structures) |structure| {
        if (!structure.is_tuple or !structure.tuple_named or !std.mem.eql(u8, structure.name, tuple_name)) continue;
        var members: std.ArrayList(InstanceMember) = .empty;
        for (structure.fields) |field| try members.append(allocator, .{
            .name = field.name,
            .kind = 5,
            .detail = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ field.name, typeName(program, field.type) }),
            .insert_text = field.name,
        });
        std.mem.sort(InstanceMember, members.items, {}, struct {
            fn lessThan(_: void, left: InstanceMember, right: InstanceMember) bool {
                return std.mem.lessThan(u8, left.name, right.name);
            }
        }.lessThan);
        return members.toOwnedSlice(allocator);
    }
    return error.MissingOracleTuple;
}

fn matchesType(candidate: []const u8, requested: []const u8) bool {
    if (std.mem.eql(u8, candidate, requested)) return true;
    if (candidate.len > requested.len and std.mem.endsWith(u8, candidate, requested) and
        candidate[candidate.len - requested.len - 1] == '.') return true;
    return candidate.len > requested.len + 1 and
        std.mem.startsWith(u8, candidate, requested) and
        candidate[requested.len] == '<' and
        candidate[candidate.len - 1] == '>';
}

fn typeName(program: Ast.Program, type_value: Ast.Type) []const u8 {
    const index = type_value.structureIndex() orelse return type_value.name();
    return if (index < program.type_names.len) program.type_names[index] else "structure";
}
