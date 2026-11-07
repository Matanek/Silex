const std = @import("std");
const Ast = @import("../Ast.zig");

// Keep parsed type indices stable while making declaration references available
// to local inference, even when no explicit callback annotation exists.
pub fn install(a: std.mem.Allocator, source: Ast.Program) !Ast.Program {
    var signatures: std.ArrayList(Ast.FunctionType) = .empty;
    try signatures.appendSlice(a, source.function_types);
    for (source.functions) |function| if (function.type_parameters.len == 0) try intern(a, &signatures, function);
    for (source.structures) |structure| for (structure.methods) |method| if (method.type_parameters.len == 0) try intern(a, &signatures, method);
    var result = source;
    result.function_types = try signatures.toOwnedSlice(a);
    return result;
}
fn intern(a: std.mem.Allocator, signatures: *std.ArrayList(Ast.FunctionType), function: Ast.Function) !void {
    for (signatures.items) |signature| if (matches(function, signature)) return;
    const parameters = try a.alloc(Ast.FunctionType.ParameterType, function.parameters.len);
    for (function.parameters, parameters) |parameter, *target| target.* = .{ .type = parameter.type, .mode = parameter.mode };
    try signatures.append(a, .{ .parameters = parameters, .return_type = function.return_type, .return_mode = function.return_mode });
}
fn matches(function: Ast.Function, signature: Ast.FunctionType) bool {
    if (function.return_type != signature.return_type or function.return_mode != signature.return_mode or function.parameters.len != signature.parameters.len) return false;
    for (function.parameters, signature.parameters) |parameter, target| if (parameter.type != target.type or parameter.mode != target.mode) return false;
    return true;
}
pub fn typeOf(program: Ast.Program, function: Ast.Function) ?Ast.Type {
    if (function.type_parameters.len != 0) return null;
    for (program.function_types, 0..) |signature, index| if (matches(function, signature)) return .function(index);
    return null;
}
pub fn named(program: Ast.Program, name: []const u8) ?Ast.Type {
    var result: ?Ast.Type = null;
    for (program.functions) |function| if (!function.is_anonymous and std.mem.eql(u8, function.name, name)) {
        if (result != null) return null;
        result = typeOf(program, function) orelse return null;
    };
    return result;
}
