const std = @import("std");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Resources = @import("Resources.zig");

/// Static storage owns roots for the duration of the isolated execution.
/// Release them after entry-local cleanup using the ordinary typed drop plans.
pub fn attachToEntries(self: anytype, functions: *std.ArrayList(Ir.Function)) !void {
    var builder: Model.FunctionBuilder = .{ .return_type = .void };
    try builder.blocks.append(self.allocator, .{});
    var index = self.globals.len;
    var owns_storage = false;
    while (index > 0) {
        index -= 1;
        const global = self.globals[index];
        if (!Resources.ownsValue(self, global.type)) continue;
        owns_storage = true;
        const value = try self.newValue(&builder, global.type);
        try self.emit(&builder, .{ .global_load = .{ .result = value, .global = index } });
        // A lazy nullable cache must no longer expose the object while its
        // destructor runs. The loaded value still owns the root being released.
        if (global.mutable and global.type.optionalChild() != null) {
            const absent = try self.newValue(&builder, global.type);
            try self.emit(&builder, .{ .optional_null = .{ .result = absent } });
            try self.emit(&builder, .{ .global_store = .{ .global = index, .operand = absent } });
        }
        try Resources.emitDrop(self, &builder, global.type, value);
    }
    if (!owns_storage) return;
    self.terminate(&builder, .return_void);
    const blocks = try self.allocator.alloc(Ir.Block, builder.blocks.items.len);
    for (builder.blocks.items, 0..) |*block, block_index| blocks[block_index] = .{
        .instructions = try block.instructions.toOwnedSlice(self.allocator),
        .terminator = block.terminator orelse return error.InvalidSource,
    };
    const finalizer = functions.items.len;
    try functions.append(self.allocator, .{
        .name = "<static.drop>",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .blocks = blocks,
    });
    for (self.program.functions, 0..) |source, function_id| {
        if (!source.is_test_entry and !std.mem.eql(u8, source.name, "main")) continue;
        for (@constCast(functions.items[function_id].blocks)) |*block| {
            switch (block.terminator) {
                .return_void, .return_value => {},
                else => continue,
            }
            const instructions = try self.allocator.alloc(Ir.Instruction, block.instructions.len + 1);
            @memcpy(instructions[0..block.instructions.len], block.instructions);
            instructions[block.instructions.len] = .{ .call = .{
                .result = null,
                .function = finalizer,
                .arguments = &.{},
            } };
            block.instructions = instructions;
        }
    }
}
