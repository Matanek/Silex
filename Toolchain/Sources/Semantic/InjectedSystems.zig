const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Ownership = @import("Resources.zig");

const application_name = "GFX.Bootstrap.Application";
const resources_name = "GFX.Bootstrap.Resources";

pub fn analyze(self: anytype, function: Ast.Function, adapter: Ast.SystemAdapter) !Ir.Function {
    const application = structureIndex(self.program, application_name) orelse return error.InvalidSource;
    const resources = structureIndex(self.program, resources_name) orelse return error.InvalidSource;
    var builder: Model.FunctionBuilder = .{ .return_type = .void };
    try builder.blocks.append(self.allocator, .{});
    try builder.value_types.append(self.allocator, .structure(application));

    const resources_method = methodIndex(self.program.structures[application], "resources") orelse return error.InvalidSource;
    const resources_value = try self.newValue(&builder, .structure(resources));
    try self.emit(&builder, .{ .call = .{
        .result = resources_value,
        .function = methodFunctionId(self.program, application, resources_method),
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{0}),
    } });
    const resources_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .structure(resources));
    try self.emit(&builder, .{ .local_store = .{ .local = resources_local, .operand = resources_value } });

    var arguments: std.ArrayList(Ir.ValueId) = .empty;
    for (adapter.dependencies) |dependency| {
        const current = try loadLocal(self, &builder, resources_local, .structure(resources));
        const has_method = methodIndex(self.program.structures[resources], dependency.has_method) orelse return error.InvalidSource;
        const present = try self.newValue(&builder, .bool);
        try self.emit(&builder, .{ .call = .{
            .result = present,
            .function = methodFunctionId(self.program, resources, has_method),
            .arguments = try self.allocator.dupe(Ir.ValueId, &.{current}),
        } });
        const found = try self.newBlock(&builder);
        const missing = try self.newBlock(&builder);
        self.terminate(&builder, .{ .branch = .{ .condition = present, .then_block = found, .else_block = missing } });

        builder.current_block = missing;
        const message = try self.newValue(&builder, .str);
        try self.emit(&builder, .{ .constant_str = .{
            .result = message,
            .value = try std.fmt.allocPrint(
                self.allocator,
                "system '{s}' requires resource '{s}'",
                .{ displayName(adapter.target), self.typeName(dependency.source_type) },
            ),
        } });
        self.terminate(&builder, .{ .panic = .{ .message = message, .position = adapter.target_position } });

        builder.current_block = found;
        const getter = methodIndex(self.program.structures[resources], dependency.get_method) orelse return error.InvalidSource;
        if (dependency.mode == .mutable) {
            const reference = try self.newValue(&builder, .address);
            try self.emit(&builder, .{ .local_address = .{ .result = reference, .local = resources_local } });
            const value = try self.newValue(&builder, .address);
            try self.emit(&builder, .{ .call = .{
                .result = value,
                .function = methodFunctionId(self.program, resources, getter),
                .arguments = try self.allocator.dupe(Ir.ValueId, &.{reference}),
            } });
            try arguments.append(self.allocator, value);
        } else {
            const value = try self.newValue(&builder, dependency.source_type);
            try self.emit(&builder, .{ .call = .{
                .result = value,
                .function = methodFunctionId(self.program, resources, getter),
                .arguments = try self.allocator.dupe(Ir.ValueId, &.{current}),
            } });
            if (dependency.kind == .query) {
                try Ownership.retainValue(self, &builder, dependency.source_type, value);
                const query_structure = dependency.type.structureIndex() orelse return error.InvalidSource;
                const query = try self.newValue(&builder, dependency.type);
                try self.emit(&builder, .{ .structure_init = .{
                    .result = query,
                    .structure = query_structure,
                    .fields = try self.allocator.dupe(Ir.ValueId, &.{value}),
                } });
                try arguments.append(self.allocator, query);
            } else try arguments.append(self.allocator, value);
        }
    }

    const target = targetFunction(self.program, adapter) orelse return error.InvalidSource;
    try self.emit(&builder, .{ .call = .{
        .result = null,
        .function = target,
        .arguments = try arguments.toOwnedSlice(self.allocator),
    } });
    self.terminate(&builder, .return_void);

    const blocks = try self.allocator.alloc(Ir.Block, builder.blocks.items.len);
    for (builder.blocks.items, 0..) |*block, index| blocks[index] = .{
        .instructions = try block.instructions.toOwnedSlice(self.allocator),
        .terminator = block.terminator orelse return error.InvalidSource,
    };
    return .{
        .name = function.name,
        .parameter_types = try self.allocator.dupe(Ast.Type, &.{.structure(application)}),
        .return_type = .void,
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .blocks = blocks,
    };
}

fn displayName(name: []const u8) []const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, name, '.') orelse return name;
    return name[separator + 1 ..];
}

fn structureIndex(program: Ast.Program, name: []const u8) ?usize {
    for (program.structures, 0..) |structure, index| if (std.mem.eql(u8, structure.name, name)) return index;
    return null;
}

fn methodIndex(structure: Ast.Structure, name: []const u8) ?usize {
    for (structure.methods, 0..) |method, index| if (std.mem.eql(u8, method.name, name)) return index;
    return null;
}

fn methodFunctionId(program: Ast.Program, structure_index: usize, method_index: usize) Ir.FunctionId {
    var result = program.functions.len;
    for (program.structures) |structure| result += structure.constructors.len;
    for (program.structures[0..structure_index]) |structure| {
        if (!structure.is_protocol) result += structure.methods.len;
    }
    return result + method_index;
}

fn targetFunction(program: Ast.Program, adapter: Ast.SystemAdapter) ?Ir.FunctionId {
    for (program.functions, 0..) |function, index| {
        if (!functionNameMatches(function.name, adapter.target)) continue;
        if (function.return_type != .void or function.parameters.len != adapter.dependencies.len) continue;
        var matches = true;
        for (function.parameters, adapter.dependencies) |parameter, dependency| {
            if (parameter.type != dependency.type or parameter.mode != dependency.mode) {
                matches = false;
                break;
            }
        }
        if (matches) return index;
    }
    return null;
}

fn functionNameMatches(candidate: []const u8, requested: []const u8) bool {
    if (std.mem.eql(u8, candidate, requested)) return true;
    if (!std.mem.endsWith(u8, candidate, requested) or candidate.len == requested.len) return false;
    return candidate[candidate.len - requested.len - 1] == '.';
}

fn loadLocal(self: anytype, builder: anytype, local: Ir.LocalId, type_value: Ast.Type) !Ir.ValueId {
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .local_load = .{ .result = result, .local = local } });
    return result;
}
