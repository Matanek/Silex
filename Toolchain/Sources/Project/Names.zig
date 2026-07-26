const std = @import("std");
const Ast = @import("../Ast.zig");
const Result = @import("../Intrinsics/Result.zig");
const Source = @import("../Source.zig");

pub fn canonical(allocator: std.mem.Allocator, module: []const u8, declaration: []const u8) std.mem.Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}.{s}", .{ module, declaration });
}

pub fn nominal(allocator: std.mem.Allocator, module: []const u8, declaration: []const u8) std.mem.Allocator.Error![]const u8 {
    if (std.mem.eql(u8, declaration, Result.name)) return Result.name;
    if (std.mem.eql(u8, lastSegment(module), declaration)) return allocator.dupe(u8, module);
    return canonical(allocator, module, declaration);
}

pub fn find(names: []const []const u8, name: []const u8) ?usize {
    for (names, 0..) |candidate, index| if (std.mem.eql(u8, candidate, name)) return index;
    return null;
}

pub fn findStructure(program: Ast.Program, name: []const u8) ?Ast.Structure {
    for (program.structures) |structure| if (std.mem.eql(u8, structure.name, name)) return structure;
    return null;
}

pub fn findEnum(program: Ast.Program, name: []const u8) ?Ast.Enum {
    for (program.enums) |enumeration| if (std.mem.eql(u8, enumeration.name, name)) return enumeration;
    return null;
}

pub fn expression(allocator: std.mem.Allocator, value: *const Ast.Expression) std.mem.Allocator.Error!?[]const u8 {
    return switch (value.value) {
        .identifier => |name| name,
        .generic_reference => |reference| reference.name,
        .field_access => |access| if (try expression(allocator, access.base)) |prefix|
            try std.fmt.allocPrint(allocator, "{s}.{s}", .{ prefix, access.name })
        else
            null,
        else => null,
    };
}

pub fn lastSegment(path: []const u8) []const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, path, '.') orelse return path;
    return path[separator + 1 ..];
}

pub fn sameParent(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, parent(left), parent(right));
}

pub fn parent(path: []const u8) []const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, path, '.') orelse return "";
    return path[0..separator];
}

pub fn expressionPosition(module: usize) Source.Position {
    return .{ .offset = 0, .line = 1, .column = 1, .file = module };
}

pub fn pathInside(path: []const u8, directory: []const u8) bool {
    if (!std.mem.startsWith(u8, path, directory) or path.len <= directory.len) return false;
    return path[directory.len] == std.fs.path.sep;
}
