const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Borrowing = @import("Borrowing.zig");
const Optionals = @import("Optionals.zig");
const Resources = @import("Resources.zig");

pub fn requiresRuntime(self: anytype, type_value: Ast.Type) bool {
    if (type_value.optionalChild()) |child| return requiresRuntime(self, child);
    const structure_index = type_value.structureIndex() orelse return false;
    if (structure_index >= self.structures.len) return false;
    const structure = self.structures[structure_index];
    if (structure.collection) |collection| {
        return collection.length == null and !collection.view;
    }
    if (structure.is_class or structure.is_protocol) return false;
    for (structure.fields) |field| if (requiresRuntime(self, field.type)) return true;
    return false;
}

pub fn analyze(self: anytype) !?Ir.Function {
    var has_runtime_field = false;
    for (self.globals) |global| has_runtime_field = has_runtime_field or global.runtime_initialized;
    if (!has_runtime_field) return null;

    const previous_member_context = self.member_context;
    const previous_owner_context = self.owner_context;
    const previous_module_context = self.module_context;
    const previous_function_context = self.function_context;
    const previous_initialization_limit = self.static_initialization_limit;
    defer {
        self.member_context = previous_member_context;
        self.owner_context = previous_owner_context;
        self.module_context = previous_module_context;
        self.function_context = previous_function_context;
        self.static_initialization_limit = previous_initialization_limit;
    }

    var builder: Model.FunctionBuilder = .{ .return_type = .void };
    try builder.blocks.append(self.allocator, .{});
    var global_index: usize = 0;
    for (self.program.structures, 0..) |structure, structure_index| {
        for (structure.static_fields) |field| {
            defer global_index += 1;
            if (!self.globals[global_index].runtime_initialized) continue;

            self.member_context = structure_index;
            self.owner_context = structure.owner;
            self.module_context = if (std.mem.lastIndexOfScalar(u8, structure.name, '.')) |separator|
                structure.name[0..separator]
            else
                null;
            self.function_context = null;
            self.static_initialization_limit = global_index;
            try Resources.validateStoredType(self, field.type, field.name_position, "in a static field");

            var value = if (field.default) |expression|
                try self.analyzeExpressionExpected(&builder, expression, Optionals.expectedContext(field.type, expression))
            else
                try self.emitIntrinsic(&builder, field.type, field.name_position);
            try Borrowing.requireOwned(
                self,
                value,
                if (field.default) |expression| expression.position else field.name_position,
                "stored in a static field",
            );
            if (value.type != field.type and self.canImplicitlyConvert(value.type, field.type)) {
                value = try self.coerce(
                    &builder,
                    value,
                    field.type,
                    if (field.default) |expression| expression.position else field.name_position,
                );
            }
            if (value.type != field.type) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "static field '{s}' expects '{s}', found '{s}'",
                    .{ field.name, self.typeName(field.type), self.typeName(value.type) },
                );
                return self.fail(field.name_position, message);
            }
            if (value.lexical_captures) return self.fail(field.name_position, "capturing function value cannot be stored in static state");
            if (Resources.requiresRetain(self, field.type) and !value.transferred) {
                try Resources.retainValue(self, &builder, field.type, value.value);
            }
            try self.emit(&builder, .{ .global_store = .{ .global = global_index, .operand = value.value } });
        }
    }
    self.terminate(&builder, .return_void);

    const blocks = try self.allocator.alloc(Ir.Block, builder.blocks.items.len);
    for (builder.blocks.items, 0..) |*block, index| blocks[index] = .{
        .instructions = try block.instructions.toOwnedSlice(self.allocator),
        .terminator = block.terminator orelse return error.InvalidSource,
    };
    return .{
        .name = "<static.init>",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .blocks = blocks,
    };
}

pub fn attachToEntries(self: anytype, functions: *std.ArrayList(Ir.Function), initializer: Ir.FunctionId) !void {
    for (self.program.functions, 0..) |source, function_id| {
        if (!source.is_test_entry and !std.mem.eql(u8, source.name, "main")) continue;
        const function = &functions.items[function_id];
        if (function.blocks.len == 0) return error.InvalidSource;
        const first = function.blocks[0];
        const instructions = try self.allocator.alloc(Ir.Instruction, first.instructions.len + 1);
        instructions[0] = .{ .call = .{ .result = null, .function = initializer, .arguments = &.{} } };
        @memcpy(instructions[1..], first.instructions);
        @constCast(function.blocks)[0].instructions = instructions;
    }
}
