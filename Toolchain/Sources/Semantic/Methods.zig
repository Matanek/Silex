const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Numeric = @import("../Numeric.zig");
const Support = @import("Support.zig");
const Optionals = @import("Optionals.zig");
const Control = @import("Control.zig");
const Borrowing = @import("Borrowing.zig");
const MutableReferences = @import("MutableReferences.zig");
const Resources = @import("Resources.zig");
const Visibility = @import("Visibility.zig");
const Inheritance = @import("Inheritance.zig");
const ProtocolValues = @import("ProtocolValues.zig");

const AnalyzeError = error{ InvalidSource, OutOfMemory };

const Place = struct {
    local: ?Ir.LocalId,
    reference: ?Ir.ValueId,
    root_type: Ast.Type,
    fields: []const usize,
};

pub fn inferMutability(allocator: std.mem.Allocator, program: Ast.Program) ![]const bool {
    const count = methodCount(program);
    const mutating = try allocator.alloc(bool, count);
    @memset(mutating, false);
    var flat: usize = 0;
    for (program.structures) |structure| {
        for (structure.methods) |method| {
            mutating[flat] = method.return_mode == .mutable or statementsWriteSelf(method.statements);
            flat += 1;
        }
    }

    var changed = true;
    while (changed) {
        changed = false;
        flat = 0;
        for (program.structures, 0..) |structure, structure_index| {
            for (structure.methods) |method| {
                if (!mutating[flat] and statementsCallMutatingSelf(program, structure_index, method.statements, mutating)) {
                    mutating[flat] = true;
                    changed = true;
                }
                flat += 1;
            }
        }
    }
    return mutating;
}

pub fn extendStructures(
    allocator: std.mem.Allocator,
    program: Ast.Program,
    base: []const Ir.Structure,
    mutating: []const bool,
) ![]const Ir.Structure {
    var extra: usize = 0;
    var flat: usize = 0;
    for (program.structures) |structure| {
        for (structure.methods) |method| {
            if (mutating[flat] and method.return_type != .void and method.return_mode != .mutable) extra += 1;
            flat += 1;
        }
    }
    const structures = try allocator.alloc(Ir.Structure, base.len + extra);
    @memcpy(structures[0..base.len], base);
    var next = base.len;
    flat = 0;
    for (program.structures, 0..) |structure, structure_index| {
        for (structure.methods, 0..) |method, method_index| {
            if (mutating[flat] and method.return_type != .void and method.return_mode != .mutable) {
                const fields = try allocator.alloc(Ir.StructureField, 2);
                fields[0] = .{ .name = "self", .type = .structure(structure_index), .mutable = false };
                fields[1] = .{ .name = "value", .type = method.return_type, .mutable = false };
                structures[next] = .{
                    .name = try std.fmt.allocPrint(allocator, "{s}.{s}#result{d}", .{ structure.name, method.name, method_index }),
                    .fields = fields,
                };
                next += 1;
            }
            flat += 1;
        }
    }
    return structures;
}

pub fn analyze(self: anytype, structure_index: usize, method_index: usize, source_method: Ast.Function) !Ir.Function {
    const previous_specialization_file = self.specialization_file;
    self.specialization_file = source_method.specialization_file;
    defer self.specialization_file = previous_specialization_file;
    if (source_method.is_static) return analyzeStatic(self, structure_index, method_index, source_method);
    const previous_context = self.member_context;
    self.member_context = structure_index;
    defer self.member_context = previous_context;
    const previous_extension_context = self.extension_context;
    self.extension_context = source_method.extension != null;
    defer self.extension_context = previous_extension_context;
    var method = source_method;
    if (method.return_mode != .value and method.return_provenance == null) {
        var compatible: usize = 0;
        for (method.parameters) |parameter| {
            const accepts = if (method.return_mode == .read) parameter.mode != .value else parameter.mode == .mutable;
            if (accepts) compatible += 1;
        }
        if (compatible != 0) return self.fail(method.name_position, "borrowed method return provenance is ambiguous; qualify it with 'self' or a parameter name");
        method.return_provenance = "self";
    }
    const structure = self.program.structures[structure_index];
    const flat = flatMethodIndex(self.program, structure_index, method_index);
    const mutating = self.method_mutability[flat];
    const borrowed_mutable = method.return_mode == .mutable;
    const receiver_type = Ast.Type.structure(structure_index);
    var builder: Model.FunctionBuilder = .{ .return_type = if (mutating and !borrowed_mutable) null else method.return_type };
    try builder.blocks.append(self.allocator, .{});

    const parameter_types = try self.allocator.alloc(Ast.Type, method.parameters.len + 1);
    parameter_types[0] = if (borrowed_mutable) .address else receiver_type;
    try builder.value_types.append(self.allocator, parameter_types[0]);
    var self_local: ?Ir.LocalId = null;
    if (borrowed_mutable) {
        try builder.bindings.append(self.allocator, .{
            .name = "self",
            .type = receiver_type,
            .reference = 0,
            .mutable = true,
            .parameter = true,
            .parameter_mode = .mutable,
            .borrowed_root = "self",
            .borrowed_mode = .mutable,
        });
    } else if (mutating) {
        self_local = builder.local_types.items.len;
        try builder.local_types.append(self.allocator, receiver_type);
        try self.emit(&builder, .{ .local_store = .{ .local = self_local.?, .operand = 0 } });
        try builder.bindings.append(self.allocator, .{
            .name = "self",
            .type = receiver_type,
            .local = self_local,
            .mutable = true,
        });
    } else try builder.bindings.append(self.allocator, .{
        .name = "self",
        .type = receiver_type,
        .value = 0,
        .parameter = true,
        .borrowed_root = if (method.return_mode == .read) "self" else null,
        .borrowed_mode = if (method.return_mode == .read) .read else .value,
    });

    for (method.parameters, 0..) |parameter, parameter_index| {
        const value = parameter_index + 1;
        const lowered_type: Ast.Type = if (parameter.mode == .mutable) .address else parameter.type;
        parameter_types[value] = lowered_type;
        try builder.value_types.append(self.allocator, lowered_type);
        try builder.bindings.append(self.allocator, .{
            .name = parameter.name,
            .type = parameter.type,
            .value = if (parameter.mode == .mutable) null else value,
            .reference = if (parameter.mode == .mutable) value else null,
            .mutable = parameter.mode == .mutable,
            .parameter = true,
            .parameter_mode = parameter.mode,
        });
    }

    const terminated = if (mutating and !borrowed_mutable)
        try analyzeMutatingStatements(self, &builder, method, structure_index, flat, self_local.?, method.statements)
    else
        try self.analyzeStatements(&builder, method, method.statements);
    if (!terminated) {
        if (method.return_type != .void) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "method '{s}' must return '{s}' on every path",
                .{ method.name, self.typeName(method.return_type) },
            );
            return self.fail(method.name_position, message);
        }
        if (mutating and !borrowed_mutable) {
            try emitMutatingReturn(self, &builder, structure_index, flat, self_local.?, method, null);
        } else {
            try Resources.emitActiveDrops(self, &builder, 0);
            self.terminate(&builder, .return_void);
        }
    }

    const blocks = try self.allocator.alloc(Ir.Block, builder.blocks.items.len);
    for (builder.blocks.items, 0..) |*block, block_index| blocks[block_index] = .{
        .instructions = try block.instructions.toOwnedSlice(self.allocator),
        .terminator = block.terminator orelse return error.InvalidSource,
    };
    return .{
        .name = try std.fmt.allocPrint(self.allocator, "{s}.{s}#{d}", .{ structure.name, method.name, method_index }),
        .parameter_types = parameter_types,
        .return_type = methodIrReturnType(self, structure_index, flat, method),
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .blocks = blocks,
    };
}

fn analyzeStatic(self: anytype, structure_index: usize, method_index: usize, method: Ast.Function) !Ir.Function {
    const previous_context = self.member_context;
    self.member_context = structure_index;
    defer self.member_context = previous_context;
    const previous_extension_context = self.extension_context;
    self.extension_context = method.extension != null;
    defer self.extension_context = previous_extension_context;
    var builder: Model.FunctionBuilder = .{};
    try builder.blocks.append(self.allocator, .{});
    const parameter_types = try self.allocator.alloc(Ast.Type, method.parameters.len);
    for (method.parameters, 0..) |parameter, index| {
        const lowered: Ast.Type = if (parameter.mode == .mutable) .address else parameter.type;
        parameter_types[index] = lowered;
        try builder.value_types.append(self.allocator, lowered);
        try builder.bindings.append(self.allocator, .{
            .name = parameter.name,
            .type = parameter.type,
            .value = if (parameter.mode == .mutable) null else index,
            .reference = if (parameter.mode == .mutable) index else null,
            .mutable = parameter.mode == .mutable,
            .parameter = true,
            .parameter_mode = parameter.mode,
        });
    }
    const terminated = try self.analyzeStatements(&builder, method, method.statements);
    if (!terminated) {
        if (method.return_type != .void) {
            const message = try std.fmt.allocPrint(self.allocator, "static method '{s}' must return '{s}' on every path", .{ method.name, self.typeName(method.return_type) });
            return self.fail(method.name_position, message);
        }
        try Resources.emitActiveDrops(self, &builder, 0);
        self.terminate(&builder, .return_void);
    }
    const blocks = try self.allocator.alloc(Ir.Block, builder.blocks.items.len);
    for (builder.blocks.items, 0..) |*block, block_index| blocks[block_index] = .{
        .instructions = try block.instructions.toOwnedSlice(self.allocator),
        .terminator = block.terminator orelse return error.InvalidSource,
    };
    return .{
        .name = try std.fmt.allocPrint(self.allocator, "{s}.{s}#static{d}", .{ self.program.structures[structure_index].name, method.name, method_index }),
        .parameter_types = parameter_types,
        .return_type = method.return_type,
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .blocks = blocks,
    };
}

pub fn analyzeCall(self: anytype, builder: anytype, call: Ast.Expression.Call) !?Model.TypedValue {
    const receiver_expression = call.receiver.?;
    const receiver = if (receiver_expression.value == .identifier and std.mem.eql(u8, receiver_expression.value.identifier, "super")) receiver: {
        var self_expression = receiver_expression.*;
        self_expression.value = .{ .identifier = "self" };
        break :receiver try self.analyzeExpression(builder, &self_expression);
    } else try self.analyzeExpression(builder, receiver_expression);
    if (call.safe) return analyzeSafeCall(self, builder, call, receiver);
    return analyzeCallWithReceiver(self, builder, call, receiver, null);
}

fn analyzeSafeCall(self: anytype, builder: anytype, call: Ast.Expression.Call, optional_receiver: Model.TypedValue) !?Model.TypedValue {
    if (optional_receiver.type.optionalChild() == null) {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "safe access '?.' requires an optional receiver, found '{s}'",
            .{self.typeName(optional_receiver.type)},
        );
        return self.fail(call.name_position, message);
    }
    const presence = try Optionals.emitPresence(self, builder, optional_receiver);
    const present_block = try self.newBlock(builder);
    const absent_block = try self.newBlock(builder);
    const merge_block = try self.newBlock(builder);
    self.terminate(builder, .{ .branch = .{
        .condition = presence.value,
        .then_block = present_block,
        .else_block = absent_block,
    } });

    builder.current_block = present_block;
    const receiver = try Optionals.unwrap(self, builder, optional_receiver);
    const call_result = try analyzeCallWithReceiver(self, builder, call, receiver, optional_receiver.type);
    const result: ?Model.TypedValue = if (call_result) |value|
        if (value.type.optionalChild() != null)
            value
        else
            (try Optionals.promote(self, builder, value, .optional(value.type))).?
    else
        null;
    self.terminate(builder, .{ .jump = merge_block });

    builder.current_block = absent_block;
    if (result) |value| try self.emit(builder, .{ .optional_null = .{ .result = value.value } });
    self.terminate(builder, .{ .jump = merge_block });
    builder.current_block = merge_block;
    return result;
}

fn analyzeCallWithReceiver(
    self: anytype,
    builder: anytype,
    call: Ast.Expression.Call,
    receiver: Model.TypedValue,
    safe_receiver_type: ?Ast.Type,
) !?Model.TypedValue {
    const receiver_expression = call.receiver.?;
    const super_call = receiver_expression.value == .identifier and std.mem.eql(u8, receiver_expression.value.identifier, "super");
    var resolved_receiver = receiver;
    if (super_call) {
        const context = self.member_context orelse return self.fail(receiver_expression.position, "'super' is only available in a class method");
        const base_index = self.structures[context].base orelse return self.fail(receiver_expression.position, "class has no base implementation");
        resolved_receiver = try self.coerce(builder, receiver, .structure(base_index), receiver_expression.position);
    }
    if (resolved_receiver.type == .str and std.mem.eql(u8, call.name, "count") and call.arguments.len == 0 and call.named_arguments.len == 0) {
        return try self.emitStringCount(builder, receiver.value);
    }
    const receiver_structure_index = resolved_receiver.type.structureIndex() orelse {
        if (std.mem.eql(u8, call.name, "count")) return self.fail(call.name_position, "count() expects 'str'");
        const message = try std.fmt.allocPrint(self.allocator, "type '{s}' has no methods", .{self.typeName(receiver.type)});
        return self.fail(call.name_position, message);
    };
    if (receiver_structure_index >= self.program.structures.len) return error.InvalidSource;
    const receiver_structure = self.program.structures[receiver_structure_index];
    if (receiver_structure.is_internal and call.name_position.file != receiver_structure.position.file) {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "members of internal structure '{s}' are unavailable outside its source file",
            .{receiver_structure.name},
        );
        return self.fail(call.name_position, message);
    }
    if (call.named_arguments.len != 0) return self.fail(call.name_position, "methods use positional arguments");
    const candidates = try Inheritance.methodCandidates(self, self.allocator, receiver_structure_index, call.name);

    var arity_count: usize = 0;
    var sole: ?usize = null;
    var inaccessible_internal = false;
    for (candidates, 0..) |candidate, candidate_index| {
        if (!Visibility.memberVisible(self, candidate.owner, candidate.method, call.name_position)) {
            inaccessible_internal = true;
            continue;
        }
        if (Support.acceptsArity(candidate.method.parameters, call.arguments.len)) {
            arity_count += 1;
            sole = candidate_index;
        }
    }
    if (arity_count == 0) {
        if (inaccessible_internal) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "method '{s}' is internal to its source file",
                .{call.name},
            );
            return self.fail(call.name_position, message);
        }
        const message = try std.fmt.allocPrint(
            self.allocator,
            "structure '{s}' has no method named '{s}' accepting {d} arguments",
            .{ receiver_structure.name, call.name, call.arguments.len },
        );
        return self.fail(call.name_position, message);
    }

    var arguments: std.ArrayList(Model.TypedValue) = .empty;
    for (call.arguments, 0..) |argument, argument_index| {
        const expected = if (arity_count == 1) expected: {
            const parameter_type = candidates[sole.?].method.parameters[argument_index].type;
            break :expected Optionals.expectedContext(parameter_type, argument);
        } else null;
        try arguments.append(self.allocator, try self.analyzeExpressionExpected(builder, argument, expected));
    }

    var selected: ?usize = null;
    var selected_cost: usize = std.math.maxInt(usize);
    var ambiguous = false;
    for (candidates, 0..) |candidate, candidate_index| {
        const method = candidate.method;
        if (!Support.acceptsArity(method.parameters, arguments.items.len)) continue;
        if (!Visibility.memberVisible(self, candidate.owner, method, call.name_position)) continue;
        var cost: usize = 0;
        var viable = true;
        for (method.parameters[0..arguments.items.len], arguments.items) |parameter, argument| {
            if (parameter.type == argument.type) continue;
            if (!self.canImplicitlyConvert(argument.type, parameter.type)) {
                viable = false;
                break;
            }
            cost += 1;
        }
        if (!viable) continue;
        if (cost < selected_cost) {
            selected = candidate_index;
            selected_cost = cost;
            ambiguous = false;
        } else if (cost == selected_cost) ambiguous = true;
    }
    if (ambiguous) {
        const message = try std.fmt.allocPrint(self.allocator, "call to method '{s}' is ambiguous", .{call.name});
        return self.fail(call.name_position, message);
    }
    const selected_candidate = candidates[
        selected orelse {
            const message = try std.fmt.allocPrint(self.allocator, "no overload of method '{s}' matches the argument types", .{call.name});
            return self.fail(call.name_position, message);
        }
    ];
    const structure_index = selected_candidate.owner;
    const method_index = selected_candidate.index;
    const method = selected_candidate.method;
    if (receiver_structure.is_protocol) return analyzeProtocolCall(
        self,
        builder,
        call,
        resolved_receiver,
        safe_receiver_type,
        method,
        arguments.items,
    );
    try Borrowing.validateReadArguments(self, method.parameters, call.arguments);
    const flat = flatMethodIndex(self.program, structure_index, method_index);
    const mutating = self.method_mutability[flat];
    const class_receiver = self.structures[receiver_structure_index].is_class;
    const borrowed_mutable = method.return_mode == .mutable;
    const place = if (mutating and !borrowed_mutable and !class_receiver)
        try requireMutablePlace(self, builder, receiver_expression, call.name)
    else
        null;
    const borrowed_receiver = if (borrowed_mutable)
        try MutableReferences.prepare(self, builder, receiver_expression, receiver.type)
    else
        null;

    var argument_ids: std.ArrayList(Ir.ValueId) = .empty;
    var mutable_arguments: std.ArrayList(MutableReferences.Prepared) = .empty;
    const method_receiver = if (receiver_structure_index != structure_index and borrowed_receiver == null)
        try self.coerce(builder, resolved_receiver, .structure(structure_index), call.name_position)
    else
        resolved_receiver;
    try argument_ids.append(self.allocator, if (borrowed_receiver) |prepared| prepared.reference else method_receiver.value);
    for (arguments.items, method.parameters[0..arguments.items.len], 0..) |argument, parameter, index| {
        if (parameter.mode == .mutable) {
            const prepared = try MutableReferences.prepare(self, builder, call.arguments[index], parameter.type);
            try mutable_arguments.append(self.allocator, prepared);
            try argument_ids.append(self.allocator, prepared.reference);
            continue;
        }
        if (parameter.mode == .value) try Resources.requireTransfer(self, call.arguments[index], argument.type, "passing it by value");
        if (parameter.mode != .read) try Borrowing.requireOwned(self, argument, call.arguments[index].position, "passed by value");
        try argument_ids.append(
            self.allocator,
            (try self.coerce(builder, argument, parameter.type, call.arguments[index].position)).value,
        );
    }
    for (method.parameters[arguments.items.len..]) |parameter| {
        const value = try self.analyzeParameterDefault(builder, parameter);
        try argument_ids.append(self.allocator, value.value);
    }

    const ir_return_type = methodIrReturnType(self, structure_index, flat, method);
    const call_result: ?Ir.ValueId = if (ir_return_type == .void) null else try self.newValue(builder, ir_return_type);
    const arguments_slice = try argument_ids.toOwnedSlice(self.allocator);
    const implementations = if (method.extension == null and class_receiver and !super_call and
        !(self.constructor_context != null and receiver_expression.value == .identifier and std.mem.eql(u8, receiver_expression.value.identifier, "self")) and
        (method.is_public or method.is_protected))
        try Inheritance.implementations(self, self.allocator, structure_index, method_index)
    else
        &.{};
    if (implementations.len == 0) {
        try self.emit(builder, .{ .call = .{
            .result = call_result,
            .function = methodFunctionId(self.program, structure_index, method_index),
            .arguments = arguments_slice,
        } });
    } else try self.emit(builder, .{ .dynamic_call = .{
        .result = call_result,
        .function = methodFunctionId(self.program, structure_index, method_index),
        .receiver = method_receiver.value,
        .arguments = arguments_slice,
        .implementations = implementations,
    } });
    for (mutable_arguments.items) |prepared| try MutableReferences.writeBack(self, builder, prepared);

    if (borrowed_mutable) {
        try MutableReferences.writeBack(self, builder, borrowed_receiver.?);
        const root = receiver.borrowed_root orelse Borrowing.rootName(receiver_expression) orelse return self.fail(receiver_expression.position, "borrowed return cannot originate from a temporary");
        const loaded = try self.newValue(builder, method.return_type);
        try self.emit(builder, .{ .reference_load = .{ .result = loaded, .reference = call_result.? } });
        return .{ .type = method.return_type, .value = loaded, .borrowed_root = root, .borrowed_mode = .mutable, .reference = call_result.? };
    }
    if (!mutating) {
        if (call_result) |value| return .{
            .type = method.return_type,
            .value = value,
            .borrowed_root = if (method.return_mode == .read) receiver.borrowed_root orelse Borrowing.rootName(receiver_expression) else null,
            .borrowed_mode = method.return_mode,
        };
        return null;
    }
    if (method.return_type == .void) {
        if (class_receiver) return null;
        const replacement = if (safe_receiver_type) |optional_type|
            (try Optionals.promote(self, builder, .{ .type = receiver.type, .value = call_result.? }, optional_type)).?.value
        else
            call_result.?;
        try writePlace(self, builder, place.?, replacement);
        return null;
    }
    if (class_receiver) {
        const value = try self.newValue(builder, method.return_type);
        try self.emit(builder, .{ .field_load = .{ .result = value, .base = call_result.?, .field = 1 } });
        return .{ .type = method.return_type, .value = value };
    }
    const updated_receiver = try self.newValue(builder, receiver.type);
    try self.emit(builder, .{ .field_load = .{ .result = updated_receiver, .base = call_result.?, .field = 0 } });
    const replacement = if (safe_receiver_type) |optional_type|
        (try Optionals.promote(self, builder, .{ .type = receiver.type, .value = updated_receiver }, optional_type)).?.value
    else
        updated_receiver;
    try writePlace(self, builder, place.?, replacement);
    const value = try self.newValue(builder, method.return_type);
    try self.emit(builder, .{ .field_load = .{ .result = value, .base = call_result.?, .field = 1 } });
    return .{ .type = method.return_type, .value = value };
}

fn analyzeProtocolCall(
    self: anytype,
    builder: anytype,
    call: Ast.Expression.Call,
    receiver: Model.TypedValue,
    safe_receiver_type: ?Ast.Type,
    requirement: Ast.Function,
    arguments: []const Model.TypedValue,
) !?Model.TypedValue {
    if (requirement.return_mode != .value) return self.fail(call.name_position, "dynamic protocol methods cannot return '@T' or '&T'");
    try Borrowing.validateReadArguments(self, requirement.parameters, call.arguments);
    const place = try requireMutablePlace(self, builder, call.receiver.?, call.name);
    var argument_ids: std.ArrayList(Ir.ValueId) = .empty;
    var mutable_arguments: std.ArrayList(MutableReferences.Prepared) = .empty;
    for (arguments, requirement.parameters[0..arguments.len], 0..) |argument, parameter, index| {
        if (parameter.mode == .mutable) {
            const prepared = try MutableReferences.prepare(self, builder, call.arguments[index], parameter.type);
            try mutable_arguments.append(self.allocator, prepared);
            try argument_ids.append(self.allocator, prepared.reference);
        } else {
            if (parameter.mode == .value) try Resources.requireTransfer(self, call.arguments[index], argument.type, "passing it by value");
            if (parameter.mode != .read) try Borrowing.requireOwned(self, argument, call.arguments[index].position, "passed by value");
            try argument_ids.append(self.allocator, (try self.coerce(builder, argument, parameter.type, call.arguments[index].position)).value);
        }
    }
    for (requirement.parameters[arguments.len..]) |parameter| {
        const value = try self.analyzeParameterDefault(builder, parameter);
        try argument_ids.append(self.allocator, value.value);
    }

    const protocol_index = ProtocolValues.index(self, receiver.type) orelse return error.InvalidSource;
    const conformers = try ProtocolValues.conformers(self, protocol_index);
    if (conformers.len == 0) return self.fail(call.name_position, "dynamic protocol has no concrete conforming type in this program");
    const updated = try self.newValue(builder, receiver.type);
    const result = if (requirement.return_type == .void) null else try self.newValue(builder, requirement.return_type);
    const merge_block = try self.newBlock(builder);
    for (conformers) |structure_index| {
        const witness_file = ProtocolValues.witnessFile(self, structure_index, protocol_index) orelse return error.InvalidSource;
        const implementation = ProtocolValues.implementationAt(self, structure_index, requirement, witness_file) orelse return error.InvalidSource;
        const action_block = try self.newBlock(builder);
        const next_block = try self.newBlock(builder);
        const matches = try ProtocolValues.emitTest(self, builder, receiver.value, structure_index);
        self.terminate(builder, .{ .branch = .{ .condition = matches, .then_block = action_block, .else_block = next_block } });
        builder.current_block = action_block;
        const concrete = try ProtocolValues.emitExtract(self, builder, receiver.value, structure_index);
        const method_receiver = if (structure_index != implementation.owner)
            (try self.coerce(builder, .{ .type = Ast.Type.structure(structure_index), .value = concrete }, Ast.Type.structure(implementation.owner), call.name_position)).value
        else
            concrete;
        var call_arguments: std.ArrayList(Ir.ValueId) = .empty;
        try call_arguments.append(self.allocator, method_receiver);
        try call_arguments.appendSlice(self.allocator, argument_ids.items);
        const flat = flatMethodIndex(self.program, implementation.owner, implementation.index);
        const mutating = self.method_mutability[flat];
        const ir_return_type = methodIrReturnType(self, implementation.owner, flat, implementation.method);
        const concrete_result: ?Ir.ValueId = if (ir_return_type == .void) null else try self.newValue(builder, ir_return_type);
        try self.emit(builder, .{ .call = .{
            .result = concrete_result,
            .function = methodFunctionId(self.program, implementation.owner, implementation.index),
            .arguments = try call_arguments.toOwnedSlice(self.allocator),
        } });
        const returned_receiver = if (mutating) replacement: {
            if (implementation.method.return_type == .void) break :replacement concrete_result.?;
            const value = try self.newValue(builder, Ast.Type.structure(implementation.owner));
            try self.emit(builder, .{ .field_load = .{ .result = value, .base = concrete_result.?, .field = 0 } });
            break :replacement value;
        } else concrete;
        const replacement = if (mutating and structure_index != implementation.owner) replacement: {
            const value = try self.newValue(builder, Ast.Type.structure(structure_index));
            try self.emit(builder, .{ .class_cast = .{ .result = value, .operand = returned_receiver } });
            break :replacement value;
        } else returned_receiver;
        try self.emit(builder, .{ .protocol_init = .{ .result = updated, .operand = replacement, .structure = structure_index } });
        if (result) |target| {
            const source = if (mutating) source: {
                const value = try self.newValue(builder, requirement.return_type);
                try self.emit(builder, .{ .field_load = .{ .result = value, .base = concrete_result.?, .field = 1 } });
                break :source value;
            } else concrete_result.?;
            try self.emit(builder, .{ .copy = .{ .result = target, .operand = source } });
        }
        self.terminate(builder, .{ .jump = merge_block });
        builder.current_block = next_block;
    }
    self.terminate(builder, .{ .jump = merge_block });
    builder.current_block = merge_block;
    for (mutable_arguments.items) |prepared| try MutableReferences.writeBack(self, builder, prepared);
    const replacement = if (safe_receiver_type) |optional_type|
        (try Optionals.promote(self, builder, .{ .type = receiver.type, .value = updated }, optional_type)).?.value
    else
        updated;
    try writePlace(self, builder, place, replacement);
    return if (result) |value| .{ .type = requirement.return_type, .value = value } else null;
}

fn requireMutablePlace(self: anytype, builder: anytype, expression: *const Ast.Expression, method_name: []const u8) !Place {
    var names: std.ArrayList([]const u8) = .empty;
    var current = expression;
    while (true) switch (current.value) {
        .identifier => |name| {
            const binding = Support.findBinding(builder.bindings.items, name) orelse {
                const message = try std.fmt.allocPrint(self.allocator, "unknown variable '{s}'", .{name});
                return self.fail(current.position, message);
            };
            if (!binding.mutable or (binding.local == null and binding.reference == null)) {
                const message = try std.fmt.allocPrint(self.allocator, "mutating method '{s}' requires a var receiver", .{method_name});
                return self.fail(expression.position, message);
            }
            std.mem.reverse([]const u8, names.items);
            const field_indices = try self.allocator.alloc(usize, names.items.len);
            var type_value = binding.type;
            for (names.items, 0..) |field_name, path_index| {
                const structure_index = type_value.structureIndex() orelse return error.InvalidSource;
                const structure = self.structures[structure_index];
                var selected: ?usize = null;
                for (structure.fields, 0..) |field, field_index| {
                    if (std.mem.eql(u8, field.name, field_name)) {
                        selected = field_index;
                        break;
                    }
                }
                const field_index = selected orelse return error.InvalidSource;
                if (!structure.fields[field_index].mutable) {
                    const message = try std.fmt.allocPrint(self.allocator, "mutating method '{s}' cannot write through immutable field '{s}'", .{ method_name, field_name });
                    return self.fail(expression.position, message);
                }
                field_indices[path_index] = field_index;
                type_value = structure.fields[field_index].type;
            }
            return .{ .local = binding.local, .reference = binding.reference, .root_type = binding.type, .fields = field_indices };
        },
        .field_access => |access| {
            try names.append(self.allocator, access.name);
            current = access.base;
        },
        else => {
            const message = try std.fmt.allocPrint(self.allocator, "mutating method '{s}' requires a var receiver", .{method_name});
            return self.fail(expression.position, message);
        },
    };
}

fn writePlace(self: anytype, builder: anytype, place: Place, replacement_value: Ir.ValueId) !void {
    if (place.fields.len == 0) {
        if (place.local) |local| try self.emit(builder, .{ .local_store = .{ .local = local, .operand = replacement_value } }) else try self.emit(builder, .{ .reference_store = .{ .reference = place.reference.?, .operand = replacement_value } });
        return;
    }
    const root = try self.newValue(builder, place.root_type);
    if (place.local) |local| try self.emit(builder, .{ .local_load = .{ .result = root, .local = local } }) else try self.emit(builder, .{ .reference_load = .{ .result = root, .reference = place.reference.? } });
    const bases = try self.allocator.alloc(Ir.ValueId, place.fields.len);
    const structure_indices = try self.allocator.alloc(usize, place.fields.len);
    var current = root;
    var current_type = place.root_type;
    for (place.fields, 0..) |field_index, path_index| {
        bases[path_index] = current;
        structure_indices[path_index] = current_type.structureIndex().?;
        if (path_index + 1 < place.fields.len) {
            const field_type = self.structures[structure_indices[path_index]].fields[field_index].type;
            current = try self.newValue(builder, field_type);
            try self.emit(builder, .{ .field_load = .{ .result = current, .base = bases[path_index], .field = field_index } });
            current_type = field_type;
        }
    }

    var replacement = replacement_value;
    var path_index = place.fields.len;
    while (path_index != 0) {
        path_index -= 1;
        const structure_index = structure_indices[path_index];
        const structure = self.structures[structure_index];
        const fields = try self.allocator.alloc(Ir.ValueId, structure.fields.len);
        for (structure.fields, 0..) |field, field_index| {
            if (field_index == place.fields[path_index]) {
                fields[field_index] = replacement;
            } else {
                fields[field_index] = try self.newValue(builder, field.type);
                try self.emit(builder, .{ .field_load = .{ .result = fields[field_index], .base = bases[path_index], .field = field_index } });
            }
        }
        replacement = try self.newValue(builder, .structure(structure_index));
        try self.emit(builder, .{ .structure_init = .{
            .result = replacement,
            .structure = structure_index,
            .fields = fields,
        } });
    }
    if (place.local) |local| try self.emit(builder, .{ .local_store = .{ .local = local, .operand = replacement } }) else try self.emit(builder, .{ .reference_store = .{ .reference = place.reference.?, .operand = replacement } });
}

fn analyzeMutatingStatements(
    self: anytype,
    builder: anytype,
    method: Ast.Function,
    structure_index: usize,
    flat: usize,
    self_local: Ir.LocalId,
    statements: []const Ast.Statement,
) AnalyzeError!bool {
    for (statements) |statement| {
        const terminated = switch (statement) {
            .return_statement => |return_statement| returned: {
                var value: ?Model.TypedValue = null;
                if (return_statement.value) |expression| {
                    if (method.return_type == .void) return self.fail(return_statement.position, "a void method cannot return a value");
                    value = try self.analyzeExpressionExpected(
                        builder,
                        expression,
                        Optionals.expectedContext(method.return_type, expression),
                    );
                    if (value.?.type != method.return_type and self.canImplicitlyConvert(value.?.type, method.return_type)) {
                        value = try self.coerce(builder, value.?, method.return_type, expression.position);
                    }
                    if (value.?.type != method.return_type) {
                        const message = try std.fmt.allocPrint(self.allocator, "return expects '{s}', found '{s}'", .{ self.typeName(method.return_type), self.typeName(value.?.type) });
                        return self.fail(expression.position, message);
                    }
                } else if (method.return_type != .void) {
                    const message = try std.fmt.allocPrint(self.allocator, "expected return value of type '{s}'", .{self.typeName(method.return_type)});
                    return self.fail(return_statement.position, message);
                }
                try emitMutatingReturn(self, builder, structure_index, flat, self_local, method, if (value) |typed| typed.value else null);
                break :returned true;
            },
            .if_statement => |conditional| try analyzeMutatingIf(self, builder, method, structure_index, flat, self_local, conditional),
            .while_statement => |loop| try analyzeMutatingWhile(self, builder, method, structure_index, flat, self_local, loop),
            else => ordinary: {
                const one = [_]Ast.Statement{statement};
                break :ordinary try self.analyzeStatements(builder, method, &one);
            },
        };
        if (terminated) return true;
    }
    return false;
}

fn analyzeMutatingIf(
    self: anytype,
    builder: anytype,
    method: Ast.Function,
    structure_index: usize,
    flat: usize,
    self_local: Ir.LocalId,
    conditional: Ast.IfStatement,
) AnalyzeError!bool {
    var exits: std.ArrayList(Ir.BlockId) = .empty;
    for (conditional.branches) |branch| {
        const analyzed = try Control.analyzeCondition(self, builder, branch.condition, "if");
        const body_block = try self.newBlock(builder);
        const next_block = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{ .condition = analyzed.condition.value, .then_block = body_block, .else_block = next_block } });
        builder.current_block = body_block;
        const binding_count = builder.bindings.items.len;
        if (analyzed.binding) |binding| try Control.enterBinding(self, builder, binding);
        const terminated = try analyzeMutatingStatements(self, builder, method, structure_index, flat, self_local, branch.statements);
        if (!terminated) try Resources.emitActiveDrops(self, builder, binding_count);
        builder.bindings.shrinkRetainingCapacity(binding_count);
        if (!terminated) try exits.append(self.allocator, builder.current_block);
        builder.current_block = next_block;
    }
    if (conditional.else_statements) |statements| {
        const binding_count = builder.bindings.items.len;
        const terminated = try analyzeMutatingStatements(self, builder, method, structure_index, flat, self_local, statements);
        if (!terminated) try Resources.emitActiveDrops(self, builder, binding_count);
        builder.bindings.shrinkRetainingCapacity(binding_count);
        if (!terminated) try exits.append(self.allocator, builder.current_block);
    } else try exits.append(self.allocator, builder.current_block);
    if (exits.items.len == 0) return true;
    const merge = try self.newBlock(builder);
    for (exits.items) |block| builder.blocks.items[block].terminator = .{ .jump = merge };
    builder.current_block = merge;
    return false;
}

fn analyzeMutatingWhile(
    self: anytype,
    builder: anytype,
    method: Ast.Function,
    structure_index: usize,
    flat: usize,
    self_local: Ir.LocalId,
    loop: Ast.WhileStatement,
) AnalyzeError!bool {
    const condition_block = try self.newBlock(builder);
    const body_block = try self.newBlock(builder);
    const exit_block = try self.newBlock(builder);
    self.terminate(builder, .{ .jump = condition_block });
    builder.current_block = condition_block;
    const analyzed = try Control.analyzeCondition(self, builder, loop.condition, "while");
    self.terminate(builder, .{ .branch = .{ .condition = analyzed.condition.value, .then_block = body_block, .else_block = exit_block } });
    builder.current_block = body_block;
    try builder.loops.append(self.allocator, .{ .continue_block = condition_block, .break_block = exit_block });
    const binding_count = builder.bindings.items.len;
    if (analyzed.binding) |binding| try Control.enterBinding(self, builder, binding);
    const terminated = try analyzeMutatingStatements(self, builder, method, structure_index, flat, self_local, loop.statements);
    if (!terminated) try Resources.emitActiveDrops(self, builder, binding_count);
    builder.bindings.shrinkRetainingCapacity(binding_count);
    builder.loops.items.len -= 1;
    if (!terminated) self.terminate(builder, .{ .jump = condition_block });
    builder.current_block = exit_block;
    return false;
}

fn emitMutatingReturn(
    self: anytype,
    builder: anytype,
    structure_index: usize,
    flat: usize,
    self_local: Ir.LocalId,
    method: Ast.Function,
    value: ?Ir.ValueId,
) !void {
    try Resources.emitActiveDrops(self, builder, 0);
    const receiver_type = Ast.Type.structure(structure_index);
    const receiver = try self.newValue(builder, receiver_type);
    try self.emit(builder, .{ .local_load = .{ .result = receiver, .local = self_local } });
    if (method.return_type == .void) {
        self.terminate(builder, .{ .return_value = receiver });
        return;
    }
    const result_type = methodResultType(self.program, self.method_mutability, self.program.type_names.len, flat).?;
    const result = try self.newValue(builder, result_type);
    try self.emit(builder, .{ .structure_init = .{
        .result = result,
        .structure = result_type.structureIndex().?,
        .fields = try self.allocator.dupe(Ir.ValueId, &.{ receiver, value.? }),
    } });
    self.terminate(builder, .{ .return_value = result });
}

fn methodIrReturnType(self: anytype, structure_index: usize, flat: usize, method: Ast.Function) Ast.Type {
    if (method.return_mode == .mutable) return .address;
    if (!self.method_mutability[flat]) return method.return_type;
    if (method.return_type == .void) return .structure(structure_index);
    return methodResultType(self.program, self.method_mutability, self.program.type_names.len, flat).?;
}

fn methodResultType(program: Ast.Program, mutating: []const bool, base_count: usize, target_flat: usize) ?Ast.Type {
    var result = base_count;
    var flat: usize = 0;
    for (program.structures) |structure| {
        for (structure.methods) |method| {
            if (flat == target_flat) return if (mutating[flat] and method.return_type != .void and method.return_mode != .mutable) .structure(result) else null;
            if (mutating[flat] and method.return_type != .void and method.return_mode != .mutable) result += 1;
            flat += 1;
        }
    }
    return null;
}

fn methodFunctionId(program: Ast.Program, structure_index: usize, method_index: usize) Ir.FunctionId {
    var result = program.functions.len;
    for (program.structures) |structure| result += structure.constructors.len;
    for (program.structures[0..structure_index]) |structure| if (!structure.is_protocol) {
        result += structure.methods.len;
    };
    return result + method_index;
}

fn flatMethodIndex(program: Ast.Program, structure_index: usize, method_index: usize) usize {
    var result: usize = 0;
    for (program.structures[0..structure_index]) |structure| result += structure.methods.len;
    return result + method_index;
}

fn methodCount(program: Ast.Program) usize {
    var result: usize = 0;
    for (program.structures) |structure| result += structure.methods.len;
    return result;
}

fn statementsWriteSelf(statements: []const Ast.Statement) bool {
    for (statements) |statement| switch (statement) {
        .assignment_statement => |assignment| if (std.mem.eql(u8, assignment.target.name, "self")) return true,
        .if_statement => |conditional| {
            for (conditional.branches) |branch| if (statementsWriteSelf(branch.statements)) return true;
            if (conditional.else_statements) |nested| if (statementsWriteSelf(nested)) return true;
        },
        .while_statement => |loop| if (statementsWriteSelf(loop.statements)) return true,
        .for_statement => |loop| if (statementsWriteSelf(loop.statements)) return true,
        else => {},
    };
    return false;
}

fn statementsCallMutatingSelf(program: Ast.Program, structure_index: usize, statements: []const Ast.Statement, mutating: []const bool) bool {
    for (statements) |statement| switch (statement) {
        .variable_declaration => |declaration| if (declaration.initializer) |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) return true,
        .assignment_statement => |assignment| if (assignment.value) |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) return true,
        .return_statement => |returned| if (returned.value) |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) return true,
        .expression_statement => |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) return true,
        .print_statement => |printed| for (printed.values) |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) return true,
        .assert_statement => |assertion| if (expressionCallsMutatingSelf(program, structure_index, assertion.condition, mutating) or expressionCallsMutatingSelf(program, structure_index, assertion.message, mutating)) return true,
        .panic_statement => |panic_statement| if (expressionCallsMutatingSelf(program, structure_index, panic_statement.value, mutating)) return true,
        .if_statement => |conditional| {
            for (conditional.branches) |branch| {
                if (expressionCallsMutatingSelf(program, structure_index, branch.condition.source(), mutating) or statementsCallMutatingSelf(program, structure_index, branch.statements, mutating)) return true;
            }
            if (conditional.else_statements) |nested| if (statementsCallMutatingSelf(program, structure_index, nested, mutating)) return true;
        },
        .while_statement => |loop| if (expressionCallsMutatingSelf(program, structure_index, loop.condition.source(), mutating) or statementsCallMutatingSelf(program, structure_index, loop.statements, mutating)) return true,
        .for_statement => |loop| {
            switch (loop.source) {
                .collection => |source| if (expressionCallsMutatingSelf(program, structure_index, source, mutating)) return true,
                .range => |range| if (expressionCallsMutatingSelf(program, structure_index, range.start, mutating) or expressionCallsMutatingSelf(program, structure_index, range.end, mutating)) return true,
            }
            if (statementsCallMutatingSelf(program, structure_index, loop.statements, mutating)) return true;
        },
        else => {},
    };
    return false;
}

fn expressionCallsMutatingSelf(program: Ast.Program, structure_index: usize, expression: *const Ast.Expression, mutating: []const bool) bool {
    return switch (expression.value) {
        .call => |call| calls: {
            if (call.receiver) |receiver| {
                if (receiverStructure(program, structure_index, receiver)) |target| {
                    if (mutatingMethodInStructure(program, target, call.name, call.arguments.len, mutating)) break :calls true;
                }
                if (expressionCallsMutatingSelf(program, structure_index, receiver, mutating)) break :calls true;
            }
            for (call.arguments) |argument| if (expressionCallsMutatingSelf(program, structure_index, argument, mutating)) break :calls true;
            for (call.named_arguments) |argument| if (expressionCallsMutatingSelf(program, structure_index, argument.value, mutating)) break :calls true;
            break :calls false;
        },
        .field_access => |access| expressionCallsMutatingSelf(program, structure_index, access.base, mutating),
        .unary => |unary| expressionCallsMutatingSelf(program, structure_index, unary.operand, mutating),
        .binary => |binary| expressionCallsMutatingSelf(program, structure_index, binary.left, mutating) or expressionCallsMutatingSelf(program, structure_index, binary.right, mutating),
        .conversion => |conversion| expressionCallsMutatingSelf(program, structure_index, conversion.operand, mutating),
        .string_count => |operand| expressionCallsMutatingSelf(program, structure_index, operand, mutating),
        .interpolated_string => |interpolated| parts: {
            for (interpolated.parts) |part| switch (part) {
                .text => {},
                .expression => |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) break :parts true,
            };
            break :parts false;
        },
        else => false,
    };
}

fn receiverStructure(program: Ast.Program, root_structure: usize, expression: *const Ast.Expression) ?usize {
    return switch (expression.value) {
        .identifier => |name| if (std.mem.eql(u8, name, "self"))
            root_structure
        else if (std.mem.eql(u8, name, "super") and root_structure < program.structures.len)
            if (program.structures[root_structure].base) |base| base.structureIndex() else null
        else
            null,
        .field_access => |access| if (receiverStructure(program, root_structure, access.base)) |base| field: {
            if (base >= program.structures.len) break :field null;
            for (program.structures[base].fields) |field_value| {
                if (std.mem.eql(u8, field_value.name, access.name)) break :field field_value.type.structureIndex();
            }
            break :field null;
        } else null,
        else => null,
    };
}

fn mutatingMethodInStructure(program: Ast.Program, structure_index: usize, name: []const u8, arity: usize, mutating: []const bool) bool {
    if (structure_index >= program.structures.len) return false;
    const offset = flatMethodIndex(program, structure_index, 0);
    for (program.structures[structure_index].methods, 0..) |method, method_index| {
        if (mutating[offset + method_index] and std.mem.eql(u8, method.name, name) and Support.acceptsArity(method.parameters, arity)) return true;
    }
    return false;
}
