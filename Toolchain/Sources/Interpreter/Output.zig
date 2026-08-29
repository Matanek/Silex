const std = @import("std");
const Ir = @import("../Ir.zig");
const Value = @import("Value.zig").Value;

pub fn appendValueText(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: Value) !void {
    switch (value) {
        .integer => |number| try appendNumber(output, allocator, "{d}", number),
        .typed_integer => |number| if (number.type.isSignedInteger())
            try appendNumber(output, allocator, "{d}", number.signed())
        else
            try appendNumber(output, allocator, "{d}", number.bits),
        .float32 => |number| try appendFloat(output, allocator, number),
        .float64 => |number| try appendFloat(output, allocator, number),
        .boolean => |flag| try output.appendSlice(allocator, if (flag) "true" else "false"),
        .string => |text| try output.appendSlice(allocator, text),
        .optional => |optional| if (optional.value) |payload|
            try appendValueText(output, allocator, payload.*)
        else
            try output.appendSlice(allocator, "null"),
        .reference, .function, .structure, .class, .protocol, .view, .enumeration, .storage, .void => return error.InvalidProgram,
    }
}

fn appendNumber(output: *std.ArrayList(u8), allocator: std.mem.Allocator, comptime format: []const u8, number: anytype) !void {
    var buffer: [32]u8 = undefined;
    try output.appendSlice(allocator, std.fmt.bufPrint(&buffer, format, .{number}) catch unreachable);
}

fn appendFloat(output: *std.ArrayList(u8), allocator: std.mem.Allocator, number: anytype) !void {
    if (std.math.isNan(number)) return output.appendSlice(allocator, "nan");
    if (std.math.isPositiveInf(number)) return output.appendSlice(allocator, "inf");
    if (std.math.isNegativeInf(number)) return output.appendSlice(allocator, "-inf");
    if (number == 0) return output.appendSlice(allocator, if (std.math.signbit(number)) "-0.0" else "0.0");
    var buffer: [std.fmt.float.bufferSize(.decimal, f64)]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{d}", .{number}) catch unreachable;
    try output.appendSlice(allocator, text);
    if (std.mem.indexOfAny(u8, text, ".eE") == null) try output.appendSlice(allocator, ".0");
}

pub fn appendRuntimeError(session: anytype, program: Ir.Program, position: @import("../Source.zig").Position, prefix: []const u8, message: []const u8) !void {
    const path = if (position.file < program.files.len) program.files[position.file] else "<source>";
    const header = try std.fmt.allocPrint(session.allocator, "{s}:{d}:{d}: runtime error: {s}", .{ path, position.line, position.column, prefix });
    try session.stderr.appendSlice(session.allocator, header);
    try session.stderr.appendSlice(session.allocator, message);
    try session.stderr.append(session.allocator, '\n');
}
