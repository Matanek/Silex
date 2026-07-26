const std = @import("std");
const Ast = @import("Ast.zig");
const Result = @import("Intrinsics/Result.zig");

pub fn accepts(enums: anytype, return_type: Ast.Type) bool {
    const index = enumerationIndex(enums, return_type) orelse return false;
    const enumeration = enums[index];
    return Result.isConcrete(enumeration) and
        Result.successType(enumeration) == .void and
        Result.errorType(enumeration) == .str;
}

pub fn enumerationIndex(enums: anytype, type_value: Ast.Type) ?usize {
    const type_index = type_value.structureIndex() orelse return null;
    for (enums, 0..) |enumeration, index| {
        if (enumeration.type_index == type_index and Result.isConcrete(enumeration)) return index;
    }
    return null;
}

pub fn variantIndex(enumeration: anytype, name: []const u8) ?usize {
    for (enumeration.variants, 0..) |variant, index| {
        if (std.mem.eql(u8, variant.name, name)) return index;
    }
    return null;
}
