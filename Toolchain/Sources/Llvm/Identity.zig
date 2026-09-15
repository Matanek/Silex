const std = @import("std");
const Ir = @import("../Ir.zig");
const Allocator = std.mem.Allocator;

pub fn name(allocator: Allocator, prefix: []const u8, bytes: []const u8) ![]const u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.Blake3.hash(bytes, &digest, .{});
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, std.fmt.bytesToHex(digest, .lower) });
}

pub fn typeName(allocator: Allocator, program: Ir.Program, value: Ir.Type) Allocator.Error![]const u8 {
    if (value.optionalChild()) |child|
        return std.fmt.allocPrint(allocator, "?{s}", .{try typeName(allocator, program, child)});
    if (value.structureIndex()) |index| return program.structures[index].name;
    if (value.functionIndex()) |index| {
        const signature = program.function_types[index];
        return signatureName(allocator, program, signature.parameter_types, signature.return_type);
    }
    return value.name();
}

fn signatureName(allocator: Allocator, program: Ir.Program, parameters: []const Ir.Type, result: Ir.Type) Allocator.Error![]const u8 {
    var text: std.ArrayList(u8) = .empty;
    try text.appendSlice(allocator, "(");
    for (parameters) |parameter| {
        const part = try typeName(allocator, program, parameter);
        try text.appendSlice(allocator, try std.fmt.allocPrint(allocator, "{d}:{s}", .{ part.len, part }));
    }
    try text.appendSlice(allocator, ")->");
    try text.appendSlice(allocator, try typeName(allocator, program, result));
    return text.toOwnedSlice(allocator);
}

pub fn functionName(allocator: Allocator, program: Ir.Program, function: Ir.Function) ![]const u8 {
    const signature = try signatureName(allocator, program, function.parameter_types, function.return_type);
    const captures = try signatureName(allocator, program, function.capture_types, .void);
    const source = if (function.source_position) |position| program.files[position.file] else "";
    // Names and typed signatures distinguish overloads. Source provenance also
    // distinguishes private functions belonging to different consumers.
    return name(allocator, "@sx.fn.", try std.fmt.allocPrint(allocator, "{d}:{s}{d}:{s}{d}:{s}{s}", .{
        source.len, source, function.name.len, function.name, signature.len, signature, captures,
    }));
}

pub fn typeTag(program: Ir.Program, index: usize) u64 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.Blake3.hash(program.structures[index].name, &digest, .{});
    return std.mem.readInt(u64, digest[0..8], .little) & std.math.maxInt(i64);
}
