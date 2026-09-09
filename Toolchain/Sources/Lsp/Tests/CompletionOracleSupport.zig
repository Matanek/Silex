const std = @import("std");
const FrontendModule = @import("../../Frontend.zig");

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

fn matchesType(candidate: []const u8, requested: []const u8) bool {
    if (std.mem.eql(u8, candidate, requested)) return true;
    return candidate.len > requested.len + 1 and
        std.mem.startsWith(u8, candidate, requested) and
        candidate[requested.len] == '<' and
        candidate[candidate.len - 1] == '>';
}
