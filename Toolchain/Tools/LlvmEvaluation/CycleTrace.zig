// Type-directed visitors read LLVM storage rather than native word layouts.
const std = @import("std");
const E = @import("Emitter.zig");
const Ir = @import("root").silex_compiler_api.Ir;
const Identity = @import("../../Sources/Llvm/Identity.zig");

pub fn emit(allocator: std.mem.Allocator, output: *std.ArrayList(u8), program: Ir.Program, stable_tags: bool) E.Error!void {
    var writer: Writer = .{ .allocator = allocator, .output = output, .program = program, .stable_tags = stable_tags };
    defer writer.types.deinit(allocator);
    try writer.write("declare i32 @silex_llvm_cycle_collect(ptr, ptr)\ndeclare void @silex_llvm_cycle_edge(ptr, ptr)\ndeclare void @silex_llvm_cycle_reject(ptr)\n", .{});
    try writer.write("define internal void @sx.cycle.trace(ptr %ctx, ptr %object) {{\nentry:\n  %tag = load i64, ptr %object\n  switch i64 %tag, label %unknown [\n", .{});
    for (program.structures, 0..) |_, index| {
        if (!E.materialClassStorage(program, index)) continue;
        try writer.write("    i64 {d}, label %class{d}\n", .{ writer.tag(index), index });
    }
    try writer.write("  ]\n", .{});
    for (program.structures, 0..) |_, index| {
        if (!E.materialClassStorage(program, index)) continue;
        try writer.write("class{d}:\n  call void @sx.cycle.class.{d}(ptr %ctx, ptr %object)\n  ret void\n", .{ index, index });
    }
    try writer.write("unknown:\n  call void @silex_llvm_cycle_reject(ptr %ctx)\n  ret void\n}}\n", .{});
    for (program.structures, 0..) |structure, index| {
        if (!E.materialClassStorage(program, index)) continue;
        try writer.write("define internal void @sx.cycle.class.{d}(ptr %ctx, ptr %object) {{\nentry:\n", .{index});
        for (structure.fields, 0..) |field, field_index| {
            if (!containsClass(program, field.type, 0)) continue;
            try writer.write("  %p{d} = getelementptr i8, ptr %object, i64 {d}\n", .{ field_index, 8 * (4 + try E.classFieldStorageOffset(program, index, field_index)) });
            try writer.call(field.type, try std.fmt.allocPrint(allocator, "%p{d}", .{field_index}));
        }
        try writer.write("  ret void\n}}\n", .{});
    }
    var cursor: usize = 0;
    while (cursor < writer.types.items.len) : (cursor += 1) try writer.value(writer.types.items[cursor]);
}

pub fn containsClass(program: Ir.Program, value: Ir.Type, depth: usize) bool {
    if (depth > program.structures.len + program.enums.len + 8) return false;
    if (value.optionalChild()) |child| return containsClass(program, child, depth + 1);
    if (value.functionIndex() != null) return true;
    const index = value.structureIndex() orelse return false;
    if (index >= program.structures.len) return false;
    const structure = program.structures[index];
    if (structure.is_class or structure.is_protocol) return true;
    if (structure.collection) |collection| return !collection.view and containsClass(program, collection.element, depth + 1);
    if (E.enumIndexForStructure(program, index)) |enumeration| {
        for (program.enums[enumeration].variants) |variant| for (variant.associated_types) |child| {
            if (containsClass(program, child, depth + 1)) return true;
        };
    }
    for (structure.fields) |field| if (containsClass(program, field.type, depth + 1)) return true;
    return false;
}

const Writer = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    program: Ir.Program,
    stable_tags: bool,
    types: std.ArrayList(Ir.Type) = .empty,

    fn write(self: *Writer, comptime format: []const u8, args: anytype) E.Error!void {
        try self.output.appendSlice(self.allocator, try std.fmt.allocPrint(self.allocator, format, args));
    }

    fn tag(self: *Writer, index: usize) u64 {
        return if (self.stable_tags) Identity.typeTag(self.program, index) else index;
    }

    fn call(self: *Writer, value_type: Ir.Type, pointer: []const u8) E.Error!void {
        if (!containsClass(self.program, value_type, 0)) return;
        if (std.mem.indexOfScalar(Ir.Type, self.types.items, value_type) == null) try self.types.append(self.allocator, value_type);
        try self.write("  call void @sx.cycle.value.{d}(ptr %ctx, ptr {s})\n", .{ @intFromEnum(value_type), pointer });
    }

    fn value(self: *Writer, value_type: Ir.Type) E.Error!void {
        try self.write("define internal void @sx.cycle.value.{d}(ptr %ctx, ptr %value) {{\nentry:\n", .{@intFromEnum(value_type)});
        if (value_type.optionalChild()) |child| {
            const name = try E.llvmType(self.allocator, self.program, value_type);
            try self.write("  %present = load i1, ptr %value\n  br i1 %present, label %payload, label %done\npayload:\n  %p = getelementptr {s}, ptr %value, i32 0, i32 1\n", .{name});
            try self.call(child, "%p");
            try self.write("  br label %done\ndone:\n", .{});
        } else if (value_type.functionIndex() != null) {
            try self.write("  %p = getelementptr {{ ptr, ptr, ptr }}, ptr %value, i32 0, i32 2\n  %owner = load ptr, ptr %p\n  %owned = icmp ne ptr %owner, null\n  br i1 %owned, label %edge, label %done\nedge:\n  call void @silex_llvm_cycle_edge(ptr %ctx, ptr %owner)\n  br label %done\ndone:\n", .{});
        } else {
            const index = value_type.structureIndex() orelse return error.InvalidProgram;
            const structure = self.program.structures[index];
            if (structure.is_class) {
                try self.write("  %owner = load ptr, ptr %value\n  call void @silex_llvm_cycle_edge(ptr %ctx, ptr %owner)\n", .{});
            } else if (structure.collection) |collection| {
                const element = try E.llvmType(self.allocator, self.program, collection.element);
                if (collection.length) |length| {
                    try self.write("  %data = getelementptr i8, ptr %value, i64 0\n  %count = add i64 0, {d}\n", .{length});
                } else {
                    try self.write("  %data = load ptr, ptr %value\n  %cp = getelementptr {{ ptr, i64 }}, ptr %value, i32 0, i32 1\n  %count = load i64, ptr %cp\n", .{});
                }
                try self.write("  br label %loop\nloop:\n  %i = phi i64 [ 0, %entry ], [ %next, %body ]\n  %more = icmp ult i64 %i, %count\n  br i1 %more, label %body, label %done\nbody:\n  %p = getelementptr {s}, ptr %data, i64 %i\n", .{element});
                try self.call(collection.element, "%p");
                try self.write("  %next = add i64 %i, 1\n  br label %loop\ndone:\n", .{});
            } else if (structure.is_protocol) {
                try self.write("  %tag = load i64, ptr %value\n  %p = getelementptr i8, ptr %value, i64 8\n  switch i64 %tag, label %unknown [\n", .{});
                for (self.program.structures, 0..) |concrete, candidate| {
                    if (concrete.is_protocol or !E.irConforms(self.program, candidate, index)) continue;
                    try self.write("    i64 {d}, label %variant{d}\n", .{ self.tag(candidate), candidate });
                }
                try self.write("  ]\n", .{});
                for (self.program.structures, 0..) |concrete, candidate| {
                    if (concrete.is_protocol or !E.irConforms(self.program, candidate, index)) continue;
                    try self.write("variant{d}:\n", .{candidate});
                    try self.call(.structure(candidate), "%p");
                    try self.write("  br label %done\n", .{});
                }
                try self.write("unknown:\n  call void @silex_llvm_cycle_reject(ptr %ctx)\n  br label %done\ndone:\n", .{});
            } else if (E.enumIndexForStructure(self.program, index)) |enumeration| {
                try self.write("  %tag = load i64, ptr %value\n  switch i64 %tag, label %unknown [\n", .{});
                for (self.program.enums[enumeration].variants, 0..) |_, variant| try self.write("    i64 {d}, label %variant{d}\n", .{ variant, variant });
                try self.write("  ]\n", .{});
                for (self.program.enums[enumeration].variants, 0..) |variant, number| {
                    try self.write("variant{d}:\n", .{number});
                    var offset: usize = 8;
                    for (variant.associated_types, 0..) |child, child_index| {
                        const pointer = try std.fmt.allocPrint(self.allocator, "%p{d}.{d}", .{ number, child_index });
                        try self.write("  {s} = getelementptr i8, ptr %value, i64 {d}\n", .{ pointer, offset });
                        try self.call(child, pointer);
                        offset += 8 * try E.llvmStorageSlots(self.program, child, 0);
                    }
                    try self.write("  br label %done\n", .{});
                }
                try self.write("unknown:\n  call void @silex_llvm_cycle_reject(ptr %ctx)\n  br label %done\ndone:\n", .{});
            } else {
                const name = try E.llvmType(self.allocator, self.program, value_type);
                for (structure.fields, 0..) |field, field_index| {
                    if (!containsClass(self.program, field.type, 0)) continue;
                    const pointer = try std.fmt.allocPrint(self.allocator, "%p{d}", .{field_index});
                    try self.write("  {s} = getelementptr {s}, ptr %value, i32 0, i32 {d}\n", .{ pointer, name, field_index });
                    try self.call(field.type, pointer);
                }
            }
        }
        try self.write("  ret void\n}}\n", .{});
    }
};
