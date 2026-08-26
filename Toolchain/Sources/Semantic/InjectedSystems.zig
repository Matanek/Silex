const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Ownership = @import("Resources.zig");
const Source = @import("../Source.zig");

const application_name = "GFX.Application";
const resources_name = "GFX.Application.Resources";
const commands_name = "GFX.ECS.Commands";

pub fn analyze(self: anytype, function: Ast.Function, adapter: Ast.SystemAdapter) !Ir.Function {
    const application = structureIndex(self.program, application_name) orelse return error.InvalidSource;
    const resources = structureIndex(self.program, resources_name) orelse return error.InvalidSource;
    var builder: Model.FunctionBuilder = .{ .return_type = .void };
    try builder.blocks.append(self.allocator, .{});
    for (function.parameters) |parameter| try builder.value_types.append(self.allocator, parameter.type);

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

    switch (adapter.mode) {
        .query_dispatch => |dispatch| analyzeDispatch(self, &builder, adapter, dispatch, application, resources, resources_local) catch |err| {
            if (self.diagnostic == null) return self.fail(adapter.target_position, "internal parallel ECS query dispatch lowering failed");
            return err;
        },
        .direct, .query_range => {
            var writer_local: ?Ir.LocalId = null;
            const arguments = injectDependencies(self, &builder, adapter, resources, resources_local, &writer_local) catch |err| {
                if (self.diagnostic == null) return self.fail(adapter.target_position, "internal parallel ECS query worker lowering failed");
                return err;
            };
            const target = targetFunction(self.program, adapter) orelse return error.InvalidSource;
            const result = try targetCallResult(self, &builder, adapter);
            try self.emit(&builder, .{ .call = .{
                .result = result,
                .function = target,
                .arguments = arguments,
            } });
            if (writer_local) |local| {
                try finishWriter(self, &builder, local);
                try Ownership.emitDrop(self, &builder, builder.local_types.items[local], try loadLocal(self, &builder, local, builder.local_types.items[local]));
            }
        },
    }
    try Ownership.emitDrop(self, &builder, .structure(resources), try loadLocal(self, &builder, resources_local, .structure(resources)));
    self.terminate(&builder, .return_void);
    return finishFunction(self, function, &builder);
}

fn targetCallResult(self: anytype, builder: anytype, adapter: Ast.SystemAdapter) !?Ir.ValueId {
    const receiver_type = adapter.receiver_type orelse return null;
    const owner = receiver_type.structureIndex() orelse return error.InvalidSource;
    if (owner >= self.program.structures.len) return error.InvalidSource;
    const requested = if (std.mem.lastIndexOfScalar(u8, adapter.target, '.')) |dot|
        adapter.target[dot + 1 ..]
    else
        adapter.target;
    for (self.program.structures[owner].methods, 0..) |method, method_index| {
        if (method.is_static or !std.mem.eql(u8, method.name, requested)) continue;
        const flat = flatMethodIndex(self.program, owner, method_index);
        if (flat < self.method_mutability.len and self.method_mutability[flat]) {
            return try self.newValue(builder, receiver_type);
        }
    }
    return null;
}

fn flatMethodIndex(program: Ast.Program, structure_index: usize, method_index: usize) usize {
    var result: usize = 0;
    for (program.structures[0..structure_index]) |structure| result += structure.methods.len;
    return result + method_index;
}

fn injectDependencies(
    self: anytype,
    builder: anytype,
    adapter: Ast.SystemAdapter,
    resources: usize,
    resources_local: Ir.LocalId,
    writer_local: *?Ir.LocalId,
) ![]const Ir.ValueId {
    var arguments: std.ArrayList(Ir.ValueId) = .empty;
    if (adapter.receiver) |receiver| {
        const current = try loadLocal(self, builder, resources_local, .structure(resources));
        try requireDependency(self, builder, adapter.target, adapter.target_position, receiver, resources, current);
        const getter = methodIndex(self.program.structures[resources], receiver.get_method) orelse return error.InvalidSource;
        const value = try self.newValue(builder, receiver.type);
        try self.emit(builder, .{ .call = .{
            .result = value,
            .function = methodFunctionId(self.program, resources, getter),
            .arguments = try self.allocator.dupe(Ir.ValueId, &.{current}),
        } });
        try arguments.append(self.allocator, value);
    }
    for (adapter.dependencies) |dependency| {
        if (isCommands(self, dependency)) {
            const parent_address = switch (adapter.mode) {
                .query_range => @as(Ir.ValueId, 4),
                else => try commandAddress(self, builder, adapter, dependency, resources, resources_local),
            };
            const start = switch (adapter.mode) {
                .query_range => @as(Ir.ValueId, 2),
                else => try emitInt(self, builder, 0),
            };
            const writer = try createWriter(self, builder, dependency.type, parent_address, 1, start);
            const local = builder.local_types.items.len;
            try builder.local_types.append(self.allocator, dependency.type);
            try self.emit(builder, .{ .local_store = .{ .local = local, .operand = writer } });
            const reference = try self.newValue(builder, .address);
            try self.emit(builder, .{ .local_address = .{ .result = reference, .local = local } });
            try arguments.append(self.allocator, reference);
            writer_local.* = local;
            continue;
        }

        const current = try loadLocal(self, builder, resources_local, .structure(resources));
        try requireDependency(self, builder, adapter.target, adapter.target_position, dependency, resources, current);
        const getter = methodIndex(self.program.structures[resources], dependency.get_method) orelse return error.InvalidSource;
        if (dependency.mode == .mutable) {
            const reference = try self.newValue(builder, .address);
            try self.emit(builder, .{ .local_address = .{ .result = reference, .local = resources_local } });
            const value = try self.newValue(builder, .address);
            try self.emit(builder, .{ .call = .{
                .result = value,
                .function = methodFunctionId(self.program, resources, getter),
                .arguments = try self.allocator.dupe(Ir.ValueId, &.{reference}),
            } });
            try arguments.append(self.allocator, value);
            continue;
        }

        const value = try self.newValue(builder, dependency.source_type);
        try self.emit(builder, .{ .call = .{
            .result = value,
            .function = methodFunctionId(self.program, resources, getter),
            .arguments = try self.allocator.dupe(Ir.ValueId, &.{current}),
        } });
        if (dependency.kind != .query) {
            try arguments.append(self.allocator, value);
            continue;
        }
        // Query is a class, so the captured World is owned by a class-field
        // edge. Destroying the transferred query releases that same edge.
        try Ownership.retainValueOwned(self, builder, dependency.source_type, value, .edge);
        const query_structure = dependency.type.structureIndex() orelse return error.InvalidSource;
        const range_start = switch (adapter.mode) {
            .query_range => @as(Ir.ValueId, 2),
            else => try emitInt(self, builder, 0),
        };
        const range_end = switch (adapter.mode) {
            .query_range => @as(Ir.ValueId, 3),
            else => try emitInt(self, builder, std.math.maxInt(u64)),
        };
        const query = try self.newValue(builder, dependency.type);
        try self.emit(builder, .{ .structure_init = .{
            .result = query,
            .structure = query_structure,
            .fields = try self.allocator.dupe(Ir.ValueId, &.{ value, range_start, range_end }),
        } });
        try arguments.append(self.allocator, query);
        // A freshly constructed query is transferred to the target's value
        // parameter. The callee owns and destroys that query root.
    }
    return arguments.toOwnedSlice(self.allocator);
}

fn analyzeDispatch(
    self: anytype,
    builder: anytype,
    adapter: Ast.SystemAdapter,
    dispatch: Ast.SystemAdapter.QueryDispatch,
    application: usize,
    resources: usize,
    resources_local: Ir.LocalId,
) !void {
    if (dispatch.dependency >= adapter.dependencies.len) return error.InvalidSource;
    const query_dependency = adapter.dependencies[dispatch.dependency];
    const current = try loadLocal(self, builder, resources_local, .structure(resources));
    try requireDependency(self, builder, adapter.target, adapter.target_position, query_dependency, resources, current);
    const getter = methodIndex(self.program.structures[resources], query_dependency.get_method) orelse return error.InvalidSource;
    const world = try self.newValue(builder, query_dependency.source_type);
    try self.emit(builder, .{ .call = .{
        .result = world,
        .function = methodFunctionId(self.program, resources, getter),
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{current}),
    } });
    const world_index = query_dependency.source_type.structureIndex() orelse return error.InvalidSource;
    const count_method = methodIndex(self.program.structures[world_index], "query_count") orelse {
        const message = try std.fmt.allocPrint(self.allocator, "parallel ECS query expected World, found '{s}'", .{self.typeName(query_dependency.source_type)});
        return self.fail(adapter.target_position, message);
    };
    const required_type = self.program.structures[world_index].methods[count_method].parameters[0].type;
    const required = try requiredComponents(self, builder, query_dependency, world, adapter.target_position);
    const count = try self.newValue(builder, .int);
    try self.emit(builder, .{ .call = .{
        .result = count,
        .function = methodFunctionId(self.program, world_index, count_method),
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{ world, required }),
    } });
    try Ownership.emitDrop(self, builder, required_type, required);

    var commands_address = try emitIntOfType(self, builder, 0, .uint);
    for (adapter.dependencies) |dependency| if (isCommands(self, dependency)) {
        commands_address = try commandAddress(self, builder, adapter, dependency, resources, resources_local);
        break;
    };
    const run_method = methodIndex(self.program.structures[application], "__silex_run_query") orelse
        return self.fail(adapter.target_position, "parallel ECS query requires the internal Application runner");
    const run = self.program.structures[application].methods[run_method];
    if (run.parameters.len != 4) return self.fail(adapter.target_position, "parallel ECS query runner has an incompatible signature");
    const callback_type = run.parameters[3].type;
    const worker = functionExact(self.program, dispatch.worker) orelse
        return self.fail(adapter.target_position, "parallel ECS query worker adapter is missing");
    const callback = try self.newValue(builder, callback_type);
    try self.emit(builder, .{ .function_reference = .{ .result = callback, .function = worker } });
    const updated_application = try self.newValue(builder, .structure(application));
    try self.emit(builder, .{ .call = .{
        .result = updated_application,
        .function = methodFunctionId(self.program, application, run_method),
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{ 0, count, 1, commands_address, callback }),
    } });
}

fn requiredComponents(self: anytype, builder: anytype, dependency: Ast.SystemDependency, world: Ir.ValueId, position: Source.Position) !Ir.ValueId {
    const query_index = dependency.type.structureIndex() orelse return self.fail(position, "parallel ECS query has no concrete query type");
    const query = self.program.structures[query_index];
    const pattern_type = query.query_pattern orelse return self.fail(position, "parallel ECS query has no access pattern");
    const pattern_index = pattern_type.structureIndex() orelse return self.fail(position, "parallel ECS query access pattern is not concrete");
    const pattern = self.program.structures[pattern_index];
    const world_index = dependency.source_type.structureIndex() orelse return self.fail(position, "parallel ECS query World type is not concrete");
    const world_structure = self.program.structures[world_index];
    const count_method = methodIndex(world_structure, "query_count") orelse return self.fail(position, "parallel ECS query is missing query_count");
    const result_type = world_structure.methods[count_method].parameters[0].type;
    var values: std.ArrayList(Ir.ValueId) = .empty;
    for (pattern.fields) |field| {
        if (std.mem.eql(u8, self.typeName(field.type), "GFX.ECS.Entity")) continue;
        const name = try std.fmt.allocPrint(self.allocator, "query_component_id<{s}>", .{self.typeName(field.type)});
        const method = methodIndex(world_structure, name) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "parallel ECS query is missing internal component id method '{s}'", .{name});
            return self.fail(position, message);
        };
        const id = try self.newValue(builder, .int);
        try self.emit(builder, .{ .call = .{
            .result = id,
            .function = methodFunctionId(self.program, world_index, method),
            .arguments = try self.allocator.dupe(Ir.ValueId, &.{world}),
        } });
        try values.append(self.allocator, id);
    }
    const result = try self.newValue(builder, result_type);
    try self.emit(builder, .{ .list_init = .{ .result = result, .values = try values.toOwnedSlice(self.allocator) } });
    return result;
}

fn commandAddress(self: anytype, builder: anytype, adapter: Ast.SystemAdapter, dependency: Ast.SystemDependency, resources: usize, resources_local: Ir.LocalId) !Ir.ValueId {
    const current = try loadLocal(self, builder, resources_local, .structure(resources));
    try requireDependency(self, builder, adapter.target, adapter.target_position, dependency, resources, current);
    const getter = methodIndex(self.program.structures[resources], dependency.get_method) orelse return error.InvalidSource;
    const resources_reference = try self.newValue(builder, .address);
    try self.emit(builder, .{ .local_address = .{ .result = resources_reference, .local = resources_local } });
    const reference = try self.newValue(builder, .address);
    try self.emit(builder, .{ .call = .{
        .result = reference,
        .function = methodFunctionId(self.program, resources, getter),
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{resources_reference}),
    } });
    const commands = try self.newValue(builder, dependency.type);
    try self.emit(builder, .{ .reference_load = .{ .result = commands, .reference = reference } });
    const commands_index = dependency.type.structureIndex() orelse return error.InvalidSource;
    const address_method = methodIndex(self.program.structures[commands_index], "__silex_address") orelse return error.InvalidSource;
    const address = try self.newValue(builder, .uint);
    try self.emit(builder, .{ .call = .{
        .result = address,
        .function = methodFunctionId(self.program, commands_index, address_method),
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{commands}),
    } });
    return address;
}

fn createWriter(self: anytype, builder: anytype, type_value: Ast.Type, parent: Ir.ValueId, order: Ir.ValueId, start: Ir.ValueId) !Ir.ValueId {
    const commands_index = type_value.structureIndex() orelse return error.InvalidSource;
    const method = methodIndex(self.program.structures[commands_index], "__silex_writer") orelse return error.InvalidSource;
    const writer = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .call = .{
        .result = writer,
        .function = methodFunctionId(self.program, commands_index, method),
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{ parent, order, start }),
    } });
    return writer;
}

fn finishWriter(self: anytype, builder: anytype, local: Ir.LocalId) !void {
    const type_value = builder.local_types.items[local];
    const commands_index = type_value.structureIndex() orelse return error.InvalidSource;
    const method = methodIndex(self.program.structures[commands_index], "__silex_finish") orelse return error.InvalidSource;
    const writer = try loadLocal(self, builder, local, type_value);
    const updated = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .call = .{
        .result = updated,
        .function = methodFunctionId(self.program, commands_index, method),
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{writer}),
    } });
    try self.emit(builder, .{ .local_store = .{ .local = local, .operand = updated } });
}

fn requireDependency(
    self: anytype,
    builder: anytype,
    target_name: []const u8,
    position: Source.Position,
    dependency: Ast.SystemDependency,
    resources: usize,
    current: Ir.ValueId,
) !void {
    const has_method = methodIndex(self.program.structures[resources], dependency.has_method) orelse return error.InvalidSource;
    const present = try self.newValue(builder, .bool);
    try self.emit(builder, .{ .call = .{
        .result = present,
        .function = methodFunctionId(self.program, resources, has_method),
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{current}),
    } });
    const found = try self.newBlock(builder);
    const missing = try self.newBlock(builder);
    self.terminate(builder, .{ .branch = .{ .condition = present, .then_block = found, .else_block = missing } });
    builder.current_block = missing;
    const message = try self.newValue(builder, .str);
    try self.emit(builder, .{ .constant_str = .{
        .result = message,
        .value = try std.fmt.allocPrint(self.allocator, "system '{s}' requires resource '{s}'", .{ displayName(target_name), self.typeName(dependency.source_type) }),
    } });
    self.terminate(builder, .{ .panic = .{ .message = message, .position = position } });
    builder.current_block = found;
}

fn finishFunction(self: anytype, function: Ast.Function, builder: anytype) !Ir.Function {
    const blocks = try self.allocator.alloc(Ir.Block, builder.blocks.items.len);
    for (builder.blocks.items, 0..) |*block, index| blocks[index] = .{
        .instructions = try block.instructions.toOwnedSlice(self.allocator),
        .instruction_positions = try block.instruction_positions.toOwnedSlice(self.allocator),
        .terminator = block.terminator orelse return error.InvalidSource,
        .terminator_position = block.terminator_position,
    };
    const parameter_types = try self.allocator.alloc(Ast.Type, function.parameters.len);
    for (function.parameters, 0..) |parameter, index| parameter_types[index] = parameter.type;
    return .{
        .name = function.name,
        .source_position = function.name_position,
        .parameter_types = parameter_types,
        .return_type = .void,
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .blocks = blocks,
    };
}

fn isCommands(self: anytype, dependency: Ast.SystemDependency) bool {
    return dependency.mode == .mutable and std.mem.eql(u8, self.typeName(dependency.type), commands_name);
}

fn emitInt(self: anytype, builder: anytype, bits: u64) !Ir.ValueId {
    return emitIntOfType(self, builder, bits, .int);
}

fn emitIntOfType(self: anytype, builder: anytype, bits: u64, type_value: Ast.Type) !Ir.ValueId {
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .constant_int = .{ .result = result, .bits = bits } });
    return result;
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
    if (adapter.receiver_type) |receiver_type| {
        const owner = receiver_type.structureIndex() orelse return null;
        if (owner >= program.structures.len) return null;
        const requested = if (std.mem.lastIndexOfScalar(u8, adapter.target, '.')) |dot|
            adapter.target[dot + 1 ..]
        else
            adapter.target;
        for (program.structures[owner].methods, 0..) |method, method_index| {
            if (method.is_static or !std.mem.eql(u8, method.name, requested)) continue;
            if (method.return_type != .void or method.parameters.len != adapter.dependencies.len) continue;
            var matches = true;
            for (method.parameters, adapter.dependencies) |parameter, dependency| if (parameter.type != dependency.type or parameter.mode != dependency.mode) {
                matches = false;
                break;
            };
            if (matches) return methodFunctionId(program, owner, method_index);
        }
        return null;
    }
    for (program.functions, 0..) |function, index| {
        if (!functionNameMatches(function.name, adapter.target)) continue;
        if (function.return_type != .void or function.parameters.len != adapter.dependencies.len) continue;
        var matches = true;
        for (function.parameters, adapter.dependencies) |parameter, dependency| if (parameter.type != dependency.type or parameter.mode != dependency.mode) {
            matches = false;
            break;
        };
        if (matches) return index;
    }
    return null;
}

fn functionExact(program: Ast.Program, name: []const u8) ?Ir.FunctionId {
    for (program.functions, 0..) |function, index| if (std.mem.eql(u8, function.name, name)) return index;
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
