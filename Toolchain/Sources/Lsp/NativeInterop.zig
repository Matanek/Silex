const std = @import("std");
const Ast = @import("../Ast.zig");

// These contexts describe native entries, not an invocation of the selected
// Silex function. Keep this predicate shared by local and imported choices.
pub fn callbackArguments(callee: []const u8) ?[]const u8 {
    const name = "C.function_address";
    if (std.mem.eql(u8, callee, name)) return "";
    if (!std.mem.startsWith(u8, callee, name ++ "<") or !std.mem.endsWith(u8, callee, ">")) return null;
    return callee[name.len + 1 .. callee.len - 1];
}
pub fn callSignature(callee: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, callee, "C.call<") or !std.mem.endsWith(u8, callee, ">")) return null;
    return callee[7 .. callee.len - 1];
}
fn argumentAt(arguments: []const u8, wanted: usize) ?[]const u8 {
    if (std.mem.trim(u8, arguments, " \t\r\n").len == 0) return null;
    var depth: usize = 0;
    var start: usize = 0;
    var index: usize = 0;
    for (arguments, 0..) |character, position| switch (character) {
        '<', '(', '[' => depth += 1,
        '>', ')', ']' => depth -|= 1,
        ',' => if (depth == 0) {
            if (index == wanted) return std.mem.trim(u8, arguments[start..position], " \t\r\n");
            index += 1;
            start = position + 1;
        },
        else => {},
    };
    return if (index == wanted) std.mem.trim(u8, arguments[start..], " \t\r\n") else null;
}
fn typeName(program: Ast.Program, value: Ast.Type) []const u8 {
    const index = value.structureIndex() orelse return value.name();
    return if (index < program.type_names.len) program.type_names[index] else "";
}
fn scalar(name: []const u8) bool {
    inline for (.{ "int", "int64", "uint", "uint64", "int32", "uint32", "uint8", "uint16", "float32", "float64", "float", "C.Size", "C.SignedSize" }) |allowed|
        if (std.mem.eql(u8, name, allowed)) return true;
    return false;
}
fn namedType(program: Ast.Program, name: []const u8, record: bool) bool {
    if (scalar(name)) return true;
    inline for (.{ "str", "bool", "void", "int8", "int16" }) |excluded|
        if (std.mem.eql(u8, name, excluded)) return false;
    for (program.structures) |structure| if (std.mem.eql(u8, name, structure.name)) {
        if (!record or structure.is_class or structure.is_protocol or structure.is_static or structure.drop != null or structure.base != null or structure.collection != null or structure.fields.len == 0) return false;
        for (structure.fields) |field| {
            const field_name = typeName(program, field.type);
            if (!std.mem.eql(u8, field_name, "int") and !std.mem.eql(u8, field_name, "uint") and !std.mem.eql(u8, field_name, "float64")) return false;
        }
        return true;
    };
    for (program.enums) |enumeration| if (std.mem.eql(u8, enumeration.name, name)) return false;
    // Imported aliases cannot be rejected without their declaration. The
    // workspace resolves them; an unknown spelling is not proof of an error.
    return name.len != 0;
}
fn compatibleType(program: Ast.Program, function: Ast.Function, value: Ast.Type, arguments: []const u8, record: bool, allow_void: bool) bool {
    if (value == .void) return allow_void;
    switch (value) {
        .address, .int, .uint, .int32, .uint32, .uint8, .uint16, .float32, .float64 => return true,
        else => {},
    }
    if (value.genericParameterIndex()) |index| return namedType(program, argumentAt(arguments, index) orelse return false, record);
    if (value.structureIndex() != null) {
        const name = typeName(program, value);
        for (function.type_parameters, 0..) |parameter, index| if (std.mem.eql(u8, name, parameter.name))
            return namedType(program, argumentAt(arguments, index) orelse return false, record);
        return namedType(program, name, record);
    }
    if (value.genericInstantiationIndex()) |index| if (index < program.generic_types.len) {
        const generic = program.generic_types[index];
        const base = typeName(program, generic.base);
        return std.mem.eql(u8, base, "C.Pointer") or std.mem.eql(u8, base, "C.MutablePointer");
    };
    return false;
}
pub fn compatible(program: Ast.Program, function: Ast.Function, arguments: []const u8) bool {
    if (function.operator != null or function.accessor != null or function.return_mode != .value) return false;
    if (function.type_parameters.len == 0) {
        if (argumentAt(arguments, 0) != null) return false;
    } else {
        if (argumentAt(arguments, function.type_parameters.len - 1) == null or argumentAt(arguments, function.type_parameters.len) != null) return false;
    }
    if (!compatibleType(program, function, function.return_type, arguments, false, true)) return false;
    for (function.parameters) |parameter| if (parameter.mode != .value or !compatibleType(program, function, parameter.type, arguments, true, false)) return false;
    return true;
}

pub fn compatibleValue(program: Ast.Program, signature: Ast.FunctionType, arguments: []const u8) bool {
    if (signature.return_mode != .value or argumentAt(arguments, 0) != null) return false;
    const empty: Ast.Function = .{ .position = .{ .offset = 0, .line = 1, .column = 1 }, .name_position = .{ .offset = 0, .line = 1, .column = 1 }, .name = "", .parameters = &.{}, .return_type = .void, .statements = &.{} };
    if (!compatibleType(program, empty, signature.return_type, "", false, true)) return false;
    for (signature.parameters) |parameter| if (parameter.mode != .value or !compatibleType(program, empty, parameter.type, "", true, false)) return false;
    return true;
}
