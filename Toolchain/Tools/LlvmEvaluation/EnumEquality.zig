// Compare the active variant, never the union's padding or inactive payload.
const std = @import("std");
const E = @import("Emitter.zig");
const Ir = @import("root").silex_compiler_api.Ir;

pub fn emit(self: anytype, value: Ir.Instruction.Binary, value_type: Ir.Type) E.Error!void {
    if (value.operator != .equal and value.operator != .not_equal) return error.UnsupportedInstruction;
    const left = try std.fmt.allocPrint(self.allocator, "%v{d}", .{value.left});
    const right = try std.fmt.allocPrint(self.allocator, "%v{d}", .{value.right});
    const result = try equal(self, value_type, left, right, 0);
    try self.write("  %v{d} = xor i1 {s}, {s}\n", .{ value.result, result, if (value.operator == .equal) "false" else "true" });
}

pub fn equal(self: anytype, value_type: Ir.Type, left: []const u8, right: []const u8, depth: usize) E.Error![]const u8 {
    if (depth > self.program.structures.len + self.program.enums.len + 8) return error.UnsupportedType;
    const serial = self.nextTemporary();
    const name = try E.llvmType(self.allocator, self.program, value_type);
    const result = try std.fmt.allocPrint(self.allocator, "%t{d}.equal", .{serial});
    if (value_type.isNumeric() or value_type == .bool or value_type == .address) {
        try self.write("  {s} = {s} {s} {s}, {s}\n", .{ result, if (value_type.isFloat()) "fcmp oeq" else "icmp eq", name, left, right });
        return result;
    }
    if (value_type == .str) {
        try self.write("  {s} = call fastcc i1 @sx_string_equal(ptr {s}, ptr {s})\n", .{ result, left, right });
        return result;
    }
    if (value_type.optionalChild()) |child| {
        try self.write("  %t{d}.equal.slot = alloca i1\n", .{serial});
        try self.write("  %t{d}.equal.lp = extractvalue {s} {s}, 0\n", .{ serial, name, left });
        try self.write("  %t{d}.equal.rp = extractvalue {s} {s}, 0\n", .{ serial, name, right });
        try self.write("  %t{d}.equal.presence = icmp eq i1 %t{d}.equal.lp, %t{d}.equal.rp\n", .{ serial, serial, serial });
        try self.write("  store i1 %t{d}.equal.presence, ptr %t{d}.equal.slot\n", .{ serial, serial });
        try self.write("  %t{d}.equal.both = and i1 %t{d}.equal.lp, %t{d}.equal.rp\n", .{ serial, serial, serial });
        try self.write("  br i1 %t{d}.equal.both, label %equal.payload{d}, label %equal.done{d}\nequal.payload{d}:\n", .{ serial, serial, serial, serial });
        const l = try extract(self, name, left, 1);
        const r = try extract(self, name, right, 1);
        const payload = try equal(self, child, l, r, depth + 1);
        try self.write("  store i1 {s}, ptr %t{d}.equal.slot\n  br label %equal.done{d}\nequal.done{d}:\n", .{ payload, serial, serial, serial });
        try self.write("  {s} = load i1, ptr %t{d}.equal.slot\n", .{ result, serial });
        return result;
    }
    const index = value_type.structureIndex() orelse return error.UnsupportedType;
    if (index >= self.program.structures.len) return error.InvalidProgram;
    const structure = self.program.structures[index];
    if (structure.is_class) {
        try self.write("  {s} = icmp eq ptr {s}, {s}\n", .{ result, left, right });
        return result;
    }
    if (E.enumIndexForStructure(self.program, index)) |enum_index| {
        const enumeration = self.program.enums[enum_index];
        var has_payload = false;
        for (enumeration.variants) |variant| has_payload = has_payload or variant.associated_types.len != 0;
        if (!has_payload and enumeration.raw_type == null) {
            try self.write("  {s} = icmp eq i64 {s}, {s}\n", .{ result, left, right });
            return result;
        }
        const ltag = try extract(self, name, left, 0);
        const rtag = try extract(self, name, right, 0);
        if (enumeration.raw_type != null) {
            try self.write("  {s} = icmp eq i64 {s}, {s}\n", .{ result, ltag, rtag });
            return result;
        }
        try self.write("  %t{d}.equal.slot = alloca i1\n  store i1 false, ptr %t{d}.equal.slot\n", .{ serial, serial });
        try self.write("  %t{d}.equal.left = alloca {s}\n  store {s} {s}, ptr %t{d}.equal.left\n", .{ serial, name, name, left, serial });
        try self.write("  %t{d}.equal.right = alloca {s}\n  store {s} {s}, ptr %t{d}.equal.right\n", .{ serial, name, name, right, serial });
        try self.write("  %t{d}.equal.tags = icmp eq i64 {s}, {s}\n", .{ serial, ltag, rtag });
        try self.write("  br i1 %t{d}.equal.tags, label %equal.variant{d}, label %equal.done{d}\nequal.variant{d}:\n", .{ serial, serial, serial, serial });
        try self.write("  switch i64 {s}, label %equal.done{d} [\n", .{ ltag, serial });
        for (enumeration.variants, 0..) |_, variant| try self.write("    i64 {d}, label %equal.variant{d}.{d}\n", .{ variant, serial, variant });
        try self.write("  ]\n", .{});
        for (enumeration.variants, 0..) |variant, variant_index| {
            try self.write("equal.variant{d}.{d}:\n", .{ serial, variant_index });
            var offset: usize = 8;
            var matched: []const u8 = "true";
            for (variant.associated_types) |child| {
                const child_serial = self.nextTemporary();
                const child_name = try E.llvmType(self.allocator, self.program, child);
                try self.write("  %t{d}.equal.lp = getelementptr i8, ptr %t{d}.equal.left, i64 {d}\n", .{ child_serial, serial, offset });
                try self.write("  %t{d}.equal.rp = getelementptr i8, ptr %t{d}.equal.right, i64 {d}\n", .{ child_serial, serial, offset });
                try self.write("  %t{d}.equal.l = load {s}, ptr %t{d}.equal.lp\n", .{ child_serial, child_name, child_serial });
                try self.write("  %t{d}.equal.r = load {s}, ptr %t{d}.equal.rp\n", .{ child_serial, child_name, child_serial });
                const l = try std.fmt.allocPrint(self.allocator, "%t{d}.equal.l", .{child_serial});
                const r = try std.fmt.allocPrint(self.allocator, "%t{d}.equal.r", .{child_serial});
                matched = try combine(self, matched, try equal(self, child, l, r, depth + 1));
                offset += 8 * try E.llvmStorageSlots(self.program, child, 0);
            }
            try self.write("  store i1 {s}, ptr %t{d}.equal.slot\n  br label %equal.done{d}\n", .{ matched, serial, serial });
        }
        try self.write("equal.done{d}:\n  {s} = load i1, ptr %t{d}.equal.slot\n", .{ serial, result, serial });
        return result;
    }
    if (structure.is_static or structure.is_protocol or structure.collection != null) return error.UnsupportedType;
    var matched: []const u8 = "true";
    for (structure.fields, 0..) |field, field_index| {
        const l = try extract(self, name, left, field_index);
        const r = try extract(self, name, right, field_index);
        matched = try combine(self, matched, try equal(self, field.type, l, r, depth + 1));
    }
    return matched;
}

fn extract(self: anytype, name: []const u8, value: []const u8, index: usize) E.Error![]const u8 {
    const result = try std.fmt.allocPrint(self.allocator, "%t{d}.equal.field", .{self.nextTemporary()});
    try self.write("  {s} = extractvalue {s} {s}, {d}\n", .{ result, name, value, index });
    return result;
}

fn combine(self: anytype, left: []const u8, right: []const u8) E.Error![]const u8 {
    const result = try std.fmt.allocPrint(self.allocator, "%t{d}.equal.and", .{self.nextTemporary()});
    try self.write("  {s} = and i1 {s}, {s}\n", .{ result, left, right });
    return result;
}
