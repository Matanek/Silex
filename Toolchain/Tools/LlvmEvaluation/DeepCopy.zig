// Clone LLVM storage with a per-operation identity map. Source headers are never
// modified; registering each new class before its fields preserves graph cycles.
const std = @import("std");
const E = @import("Emitter.zig");
const Ir = @import("root").silex_compiler_api.Ir;
const Identity = @import("../../Sources/Llvm/Identity.zig");
const Dispatch = @import("ClassDispatch.zig");

pub fn emit(allocator: std.mem.Allocator, output: *std.ArrayList(u8), program: Ir.Program, functions: []const ?Ir.Function, stable_tags: bool) E.Error!void {
    var writer: Writer = .{ .allocator = allocator, .output = output, .program = program, .stable_tags = stable_tags };
    defer writer.types.deinit(allocator);
    defer writer.classes.deinit(allocator);
    var roots: std.ArrayList(Ir.Type) = .empty;
    defer roots.deinit(allocator);
    for (functions) |maybe_function| {
        const function = maybe_function orelse continue;
        for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
            .deep_copy => |copy| {
                const value_type = function.value_types[copy.result];
                if (std.mem.indexOfScalar(Ir.Type, roots.items, value_type) == null) try roots.append(allocator, value_type);
            },
            else => {},
        };
    }
    if (roots.items.len == 0) return;
    try output.appendSlice(allocator, runtime);
    for (roots.items) |value_type| {
        const name = try E.llvmType(allocator, program, value_type);
        try writer.write("define internal fastcc {s} @sx.copy.root.{d}({s} %source) {{\nentry:\n  %ctx = alloca ptr\n  store ptr null, ptr %ctx\n  %value = alloca {s}\n  store {s} %source, ptr %value\n", .{ name, @intFromEnum(value_type), name, name, name });
        try writer.call(value_type, "%value", "false");
        try writer.write("  call void @sx.copy.clear(ptr %ctx)\n  %result = load {s}, ptr %value\n  ret {s} %result\n}}\n", .{ name, name });
    }
    var cursor: usize = 0;
    var class_cursor: usize = 0;
    while (cursor < writer.types.items.len or class_cursor < writer.classes.items.len) {
        while (cursor < writer.types.items.len) : (cursor += 1) try writer.value(writer.types.items[cursor]);
        while (class_cursor < writer.classes.items.len) : (class_cursor += 1) try writer.class(writer.classes.items[class_cursor]);
    }
    try writer.write("define internal ptr @sx.copy.object(ptr %ctx, ptr %source, i1 %edge) {{\nentry:\n  %known = call ptr @sx.copy.find(ptr %ctx, ptr %source)\n  %found = icmp ne ptr %known, null\n  br i1 %found, label %retain, label %dispatch\nretain:\n  %offset = select i1 %edge, i64 16, i64 8\n  call fastcc void @sx_typed_class_retain(ptr %known, i64 %offset)\n  ret ptr %known\ndispatch:\n  %tag = load i64, ptr %source\n  switch i64 %tag, label %unknown [\n", .{});
    for (writer.classes.items) |index| try writer.write("    i64 {d}, label %class{d}\n", .{ writer.tag(index), index });
    try writer.write("  ]\n", .{});
    for (writer.classes.items) |index| try writer.write("class{d}:\n  %copy{d} = call ptr @sx.copy.class.{d}(ptr %ctx, ptr %source, i1 %edge)\n  ret ptr %copy{d}\n", .{ index, index, index, index });
    try writer.write("unknown:\n  call void @exit(i32 1)\n  unreachable\n}}\n", .{});
}

fn needsCopy(program: Ir.Program, value: Ir.Type, depth: usize) bool {
    if (depth > program.structures.len + program.enums.len + 8) return false;
    if (value.optionalChild()) |child| return needsCopy(program, child, depth + 1);
    if (value == .str or value.functionIndex() != null) return true;
    const index = value.structureIndex() orelse return false;
    const structure = program.structures[index];
    if (structure.is_class or structure.is_protocol) return true;
    if (structure.collection) |collection| return !collection.view and (collection.length == null or needsCopy(program, collection.element, depth + 1));
    if (E.enumIndexForStructure(program, index)) |enumeration| {
        if (program.enums[enumeration].raw_type) |raw| return needsCopy(program, raw, depth + 1);
        for (program.enums[enumeration].variants) |variant| for (variant.associated_types) |child| {
            if (needsCopy(program, child, depth + 1)) return true;
        };
    }
    for (structure.fields) |field| if (needsCopy(program, field.type, depth + 1)) return true;
    return false;
}

const Writer = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    program: Ir.Program,
    stable_tags: bool,
    types: std.ArrayList(Ir.Type) = .empty,
    classes: std.ArrayList(usize) = .empty,

    fn write(self: *Writer, comptime format: []const u8, args: anytype) E.Error!void {
        try self.output.appendSlice(self.allocator, try std.fmt.allocPrint(self.allocator, format, args));
    }
    fn tag(self: *Writer, index: usize) u64 {
        return if (self.stable_tags) Identity.typeTag(self.program, index) else index;
    }
    fn call(self: *Writer, value_type: Ir.Type, pointer: []const u8, edge: []const u8) E.Error!void {
        if (!needsCopy(self.program, value_type, 0)) return;
        if (std.mem.indexOfScalar(Ir.Type, self.types.items, value_type) == null) try self.types.append(self.allocator, value_type);
        try self.write("  call void @sx.copy.value.{d}(ptr %ctx, ptr {s}, i1 {s})\n", .{ @intFromEnum(value_type), pointer, edge });
    }
    fn registerClasses(self: *Writer, base: ?usize) E.Error!void {
        for (self.program.structures, 0..) |structure, index| {
            if (!structure.is_copyable or !E.materialClassStorage(self.program, index)) continue;
            if (base) |ancestor| if (!Dispatch.isAncestor(self.program, ancestor, index)) continue;
            if (std.mem.indexOfScalar(usize, self.classes.items, index) == null) try self.classes.append(self.allocator, index);
        }
    }
    fn class(self: *Writer, index: usize) E.Error!void {
        const bytes = 8 * try E.classStorageSlots(self.program, index);
        try self.write("define internal ptr @sx.copy.class.{d}(ptr %ctx, ptr %source, i1 %edge) {{\nentry:\n  %value = call fastcc ptr @sx_typed_class_alloc(i64 {d}, i64 {d})\n  %offset = select i1 %edge, i64 16, i64 8\n  call fastcc void @sx_typed_class_retain(ptr %value, i64 %offset)\n  call void @sx.copy.insert(ptr %ctx, ptr %source, ptr %value)\n  %from = getelementptr i8, ptr %source, i64 32\n  %to = getelementptr i8, ptr %value, i64 32\n  call void @llvm.memcpy.p0.p0.i64(ptr %to, ptr %from, i64 {d}, i1 false)\n", .{ index, bytes, self.tag(index), bytes });
        for (self.program.structures[index].fields, 0..) |field, field_index| {
            if (!needsCopy(self.program, field.type, 0)) continue;
            const pointer = try std.fmt.allocPrint(self.allocator, "%p{d}", .{field_index});
            try self.write("  {s} = getelementptr i8, ptr %value, i64 {d}\n", .{ pointer, 8 * (4 + try E.classFieldStorageOffset(self.program, index, field_index)) });
            try self.call(field.type, pointer, "true");
        }
        try self.write("  ret ptr %value\n}}\n", .{});
    }
    fn value(self: *Writer, value_type: Ir.Type) E.Error!void {
        try self.write("define internal void @sx.copy.value.{d}(ptr %ctx, ptr %value, i1 %edge) {{\nentry:\n", .{@intFromEnum(value_type)});
        const name = try E.llvmType(self.allocator, self.program, value_type);
        if (value_type.optionalChild()) |child| {
            try self.write("  %present = load i1, ptr %value\n  br i1 %present, label %payload, label %done\npayload:\n  %p = getelementptr {s}, ptr %value, i32 0, i32 1\n", .{name});
            try self.call(child, "%p", "%edge");
            try self.write("  br label %done\ndone:\n", .{});
        } else if (value_type == .str) {
            try self.write("  %text = load ptr, ptr %value\n  %offset = select i1 %edge, i64 -16, i64 -24\n  call fastcc void @sx_string_retain(ptr %text, i64 %offset)\n", .{});
        } else if (value_type.functionIndex() != null) {
            try self.registerClasses(null);
            try self.write("  %op = getelementptr {{ ptr, ptr, ptr }}, ptr %value, i32 0, i32 2\n  %owner = load ptr, ptr %op\n  %owned = icmp ne ptr %owner, null\n  br i1 %owned, label %clone, label %done\nclone:\n  %copy = call ptr @sx.copy.object(ptr %ctx, ptr %owner, i1 %edge)\n  store ptr %copy, ptr %op\n  %env = getelementptr {{ ptr, ptr, ptr }}, ptr %value, i32 0, i32 1\n  store ptr %copy, ptr %env\n  br label %done\ndone:\n", .{});
        } else {
            const index = value_type.structureIndex() orelse return error.InvalidProgram;
            const structure = self.program.structures[index];
            if (structure.is_class) {
                try self.registerClasses(index);
                try self.write("  %source = load ptr, ptr %value\n  %copy = call ptr @sx.copy.object(ptr %ctx, ptr %source, i1 %edge)\n  store ptr %copy, ptr %value\n", .{});
            } else if (structure.collection) |collection| {
                if (collection.view) return error.InvalidProgram;
                const element = try E.llvmType(self.allocator, self.program, collection.element);
                if (collection.length) |length| {
                    try self.write("  %data = getelementptr i8, ptr %value, i64 0\n  %count = add i64 0, {d}\n", .{length});
                } else {
                    try self.write("  %source = load ptr, ptr %value\n  %cp = getelementptr {{ ptr, i64 }}, ptr %value, i32 0, i32 1\n  %count = load i64, ptr %cp\n  %end = getelementptr {s}, ptr null, i64 %count\n  %bytes = ptrtoint ptr %end to i64\n  %data = call fastcc ptr @sx_alloc(i64 %bytes)\n  call void @llvm.memcpy.p0.p0.i64(ptr %data, ptr %source, i64 %bytes, i1 false)\n  store ptr %data, ptr %value\n  %roots = getelementptr i8, ptr %data, i64 -24\n  %edges = getelementptr i8, ptr %data, i64 -16\n  %rc = select i1 %edge, i64 0, i64 1\n  %ec = select i1 %edge, i64 1, i64 0\n  store i64 %rc, ptr %roots\n  store i64 %ec, ptr %edges\n", .{element});
                }
                if (needsCopy(self.program, collection.element, 0)) {
                    try self.write("  br label %loop\nloop:\n  %i = phi i64 [ 0, %entry ], [ %next, %body ]\n  %more = icmp ult i64 %i, %count\n  br i1 %more, label %body, label %done\nbody:\n  %p = getelementptr {s}, ptr %data, i64 %i\n", .{element});
                    try self.call(collection.element, "%p", "%edge");
                    try self.write("  %next = add i64 %i, 1\n  br label %loop\ndone:\n", .{});
                }
            } else if (structure.is_protocol) {
                try self.write("  %tag = load i64, ptr %value\n  %p = getelementptr i8, ptr %value, i64 8\n  switch i64 %tag, label %unknown [\n", .{});
                for (self.program.structures, 0..) |concrete, candidate| {
                    if (concrete.is_protocol or !concrete.is_copyable or !E.irConforms(self.program, candidate, index)) continue;
                    try self.write("    i64 {d}, label %variant{d}\n", .{ self.tag(candidate), candidate });
                }
                try self.write("  ]\n", .{});
                for (self.program.structures, 0..) |concrete, candidate| {
                    if (concrete.is_protocol or !concrete.is_copyable or !E.irConforms(self.program, candidate, index)) continue;
                    try self.write("variant{d}:\n", .{candidate});
                    try self.call(.structure(candidate), "%p", "%edge");
                    try self.write("  br label %done\n", .{});
                }
                try self.write("unknown:\n  call void @exit(i32 1)\n  unreachable\ndone:\n", .{});
            } else if (E.enumIndexForStructure(self.program, index)) |enumeration| {
                if (self.program.enums[enumeration].raw_type) |raw| {
                    try self.write("  %p = getelementptr {s}, ptr %value, i32 0, i32 1\n", .{name});
                    try self.call(raw, "%p", "%edge");
                } else {
                    try self.write("  %tag = load i64, ptr %value\n  switch i64 %tag, label %unknown [\n", .{});
                    for (self.program.enums[enumeration].variants, 0..) |_, variant| try self.write("    i64 {d}, label %variant{d}\n", .{ variant, variant });
                    try self.write("  ]\n", .{});
                    for (self.program.enums[enumeration].variants, 0..) |variant, number| {
                        try self.write("variant{d}:\n", .{number});
                        var offset: usize = 8;
                        for (variant.associated_types, 0..) |child, child_index| {
                            const pointer = try std.fmt.allocPrint(self.allocator, "%p{d}.{d}", .{ number, child_index });
                            try self.write("  {s} = getelementptr i8, ptr %value, i64 {d}\n", .{ pointer, offset });
                            try self.call(child, pointer, "%edge");
                            offset += 8 * try E.llvmStorageSlots(self.program, child, 0);
                        }
                        try self.write("  br label %done\n", .{});
                    }
                    try self.write("unknown:\n  call void @exit(i32 1)\n  unreachable\ndone:\n", .{});
                }
            } else {
                for (structure.fields, 0..) |field, field_index| {
                    if (!needsCopy(self.program, field.type, 0)) continue;
                    const pointer = try std.fmt.allocPrint(self.allocator, "%p{d}", .{field_index});
                    try self.write("  {s} = getelementptr {s}, ptr %value, i32 0, i32 {d}\n", .{ pointer, name, field_index });
                    try self.call(field.type, pointer, "%edge");
                }
            }
        }
        try self.write("  ret void\n}}\n", .{});
    }
};

const runtime =
    \\define internal ptr @sx.copy.find(ptr %ctx, ptr %source) {
    \\entry:
    \\  %head = load ptr, ptr %ctx
    \\  br label %loop
    \\loop:
    \\  %node = phi ptr [ %head, %entry ], [ %next, %advance ]
    \\  %empty = icmp eq ptr %node, null
    \\  br i1 %empty, label %missing, label %check
    \\check:
    \\  %key = load ptr, ptr %node
    \\  %equal = icmp eq ptr %key, %source
    \\  br i1 %equal, label %found, label %advance
    \\advance:
    \\  %np = getelementptr { ptr, ptr, ptr }, ptr %node, i32 0, i32 2
    \\  %next = load ptr, ptr %np
    \\  br label %loop
    \\found:
    \\  %vp = getelementptr { ptr, ptr, ptr }, ptr %node, i32 0, i32 1
    \\  %value = load ptr, ptr %vp
    \\  ret ptr %value
    \\missing:
    \\  ret ptr null
    \\}
    \\define internal void @sx.copy.insert(ptr %ctx, ptr %source, ptr %value) {
    \\entry:
    \\  %node = call ptr @malloc(i64 24)
    \\  %null = icmp eq ptr %node, null
    \\  br i1 %null, label %fail, label %ready
    \\fail:
    \\  call void @exit(i32 1)
    \\  unreachable
    \\ready:
    \\  %head = load ptr, ptr %ctx
    \\  store ptr %source, ptr %node
    \\  %vp = getelementptr { ptr, ptr, ptr }, ptr %node, i32 0, i32 1
    \\  store ptr %value, ptr %vp
    \\  %np = getelementptr { ptr, ptr, ptr }, ptr %node, i32 0, i32 2
    \\  store ptr %head, ptr %np
    \\  store ptr %node, ptr %ctx
    \\  ret void
    \\}
    \\define internal void @sx.copy.clear(ptr %ctx) {
    \\entry:
    \\  %head = load ptr, ptr %ctx
    \\  br label %loop
    \\loop:
    \\  %node = phi ptr [ %head, %entry ], [ %next, %release ]
    \\  %empty = icmp eq ptr %node, null
    \\  br i1 %empty, label %done, label %release
    \\release:
    \\  %np = getelementptr { ptr, ptr, ptr }, ptr %node, i32 0, i32 2
    \\  %next = load ptr, ptr %np
    \\  call void @free(ptr %node)
    \\  br label %loop
    \\done:
    \\  ret void
    \\}
    \\
;
