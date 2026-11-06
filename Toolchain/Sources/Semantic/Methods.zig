const std = @import("std");
const Ast = @import("../Ast.zig");
const Arguments = @import("Arguments.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Numeric = @import("../Numeric.zig");
const Support = @import("Support.zig");
const Optionals = @import("Optionals.zig");
const Control = @import("Control.zig");
const Availability = @import("Availability.zig");
const Borrowing = @import("Borrowing.zig");
const MutableReferences = @import("MutableReferences.zig");
const Resources = @import("Resources.zig");
const Collections = @import("Collections.zig");
const ProjectionOwnership = @import("ProjectionOwnership.zig");
const Visibility = @import("Visibility.zig");
const Inheritance = @import("Inheritance.zig");
const ProtocolValues = @import("ProtocolValues.zig");
const Matches = @import("Matches.zig");
const TypedResources = @import("TypedResources.zig");
const EcsComponents = @import("EcsComponents.zig");

const StorageOwnership = @import("StorageOwnership.zig");

const AnalyzeError = error{ InvalidSource, OutOfMemory };

const Layout = @import("MethodLayout.zig");
pub const inferMutability = @import("MethodMutability.zig").infer;
pub const extendStructures = Layout.extendStructures;
pub const methodIrReturnType = Layout.methodIrReturnType;
pub const flatMethodIndex = Layout.flatMethodIndex;
const methodResultType = Layout.methodResultType;
const methodFunctionId = Layout.methodFunctionId;

const Places = @import("MethodPlaces.zig");
const Place = Places.Place;
const requireMutablePlace = Places.requireMutablePlace;
const findMutablePlace = Places.findMutablePlace;
const prepareReceiverPlace = Places.prepareReceiverPlace;
const writePlace = Places.writePlace;
const ProtocolReceivers = @import("ProtocolReceivers.zig");

pub fn validateAccessors(self: anytype) !void {
    var flat: usize = 0;
    for (self.program.structures) |structure| {
        for (structure.methods) |method| {
            if (method.accessor) |accessor| if (accessor.kind == .get and !method.is_static and self.method_mutability[flat]) {
                return self.fail(method.name_position, "a getter cannot mutate self; use an explicit method for observable mutation");
            };
            flat += 1;
        }
    }
}

pub fn analyze(self: anytype, structure_index: usize, method_index: usize, source_method: Ast.Function) !Ir.Function {
    const previous_owner_context = self.owner_context;
    self.owner_context = source_method.owner;
    defer self.owner_context = previous_owner_context;
    const previous_specialization_file = self.specialization_file;
    self.specialization_file = if (source_method.protocol_witness) |origin| origin.file else source_method.specialization_file;
    defer self.specialization_file = previous_specialization_file;
    if (source_method.is_static) return analyzeStatic(self, structure_index, method_index, source_method);
    if (source_method.intrinsic) |intrinsic| return switch (intrinsic) {
        .component_get_mut, .world_component_get_mut => EcsComponents.analyze(self, structure_index, source_method),
        else => TypedResources.analyze(self, structure_index, method_index, source_method),
    };
    const previous_context = self.member_context;
    self.member_context = structure_index;
    defer self.member_context = previous_context;
    const previous_extension_context = self.extension_context;
    self.extension_context = source_method.extension != null;
    defer self.extension_context = previous_extension_context;
    var method = source_method;
    const previous_function_context = self.function_context;
    self.function_context = method;
    defer self.function_context = previous_function_context;
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
    const nominal_receiver = structure.is_protocol and method.protocol_default;
    var builder: Model.FunctionBuilder = .{ .return_type = method.return_type };
    try builder.blocks.append(self.allocator, .{});

    const parameter_types = try self.allocator.alloc(Ast.Type, method.parameters.len + 1);
    parameter_types[0] = if (borrowed_mutable) .address else receiver_type;
    try builder.value_types.append(self.allocator, parameter_types[0]);
    var self_local: ?Ir.LocalId = null;
    if (borrowed_mutable) {
        try builder.bindings.append(self.allocator, .{
            .name = "self",
            .nominal_receiver = nominal_receiver,
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
        builder.mutating_return = .{
            .structure_index = structure_index,
            .flat = flat,
            .self_local = self_local.?,
        };
        try builder.bindings.append(self.allocator, .{
            .name = "self",
            .nominal_receiver = nominal_receiver,
            .type = receiver_type,
            .local = self_local,
            .mutable = true,
        });
    } else if (nominal_receiver) {
        const local = builder.local_types.items.len;
        try builder.local_types.append(self.allocator, receiver_type);
        try self.emit(&builder, .{ .local_store = .{ .local = local, .operand = 0 } });
        try builder.bindings.append(self.allocator, .{ .name = "self", .nominal_receiver = true, .owned_receiver = true, .type = receiver_type, .local = local, .mutable = true });
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
        if (parameter.mode == .mutable and Collections.isViewType(self.structures, parameter.type)) {
            parameter_types[value] = try Collections.bindFunctionParameter(self, &builder, parameter, value);
        } else {
            const lowered: Ast.Type = if (parameter.mode == .mutable) .address else parameter.type;
            parameter_types[value] = lowered;
            try builder.value_types.append(self.allocator, lowered);
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
    }

    // Parameter values occupy the leading IR IDs. Retaining a nominal receiver
    // can emit temporaries, so do it only after those IDs have been registered.
    if (nominal_receiver and !mutating and !borrowed_mutable and Resources.requiresRetain(self, receiver_type))
        try Resources.retainValue(self, &builder, receiver_type, 0);

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
        .instruction_positions = try block.instruction_positions.toOwnedSlice(self.allocator),
        .terminator = block.terminator orelse return error.InvalidSource,
        .terminator_position = block.terminator_position,
    };
    return .{
        .name = try std.fmt.allocPrint(self.allocator, "{s}.{s}#{d}", .{ structure.name, method.name, method_index }),
        .source_position = method.name_position,
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
    const previous_function_context = self.function_context;
    self.function_context = method;
    defer self.function_context = previous_function_context;
    var builder: Model.FunctionBuilder = .{ .return_type = method.return_type };
    try builder.blocks.append(self.allocator, .{});
    const parameter_types = try self.allocator.alloc(Ast.Type, method.parameters.len);
    for (method.parameters, 0..) |parameter, index| {
        if (parameter.mode == .mutable and Collections.isViewType(self.structures, parameter.type)) {
            parameter_types[index] = try Collections.bindFunctionParameter(self, &builder, parameter, index);
        } else {
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
        .instruction_positions = try block.instruction_positions.toOwnedSlice(self.allocator),
        .terminator = block.terminator orelse return error.InvalidSource,
        .terminator_position = block.terminator_position,
    };
    return .{
        .name = try std.fmt.allocPrint(self.allocator, "{s}.{s}#static{d}", .{ self.program.structures[structure_index].name, method.name, method_index }),
        .source_position = method.name_position,
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

pub fn analyzeCallWithReceiver(
    self: anytype,
    builder: anytype,
    call: Ast.Expression.Call,
    receiver: Model.TypedValue,
    safe_receiver_type: ?Ast.Type,
) !?Model.TypedValue {
    // A stored receiver may lose its owner in an argument or reentrant callback.
    // Hold its identity through dispatch, result extraction and receiver writeback.
    const expression = call.receiver.?;
    const self_call = expression.value == .identifier and
        (std.mem.eql(u8, expression.value.identifier, "self") or std.mem.eql(u8, expression.value.identifier, "super"));
    const rooted = if (receiver.type.structureIndex()) |index|
        index < self.structures.len and self.structures[index].is_class and !receiver.transferred and !self_call
    else
        false;
    const protocol_rooted = ProtocolValues.index(self, receiver.type) != null and !receiver.transferred and !self_call;
    if (rooted) try Resources.retainValue(self, builder, receiver.type, receiver.value);
    if (protocol_rooted) try ProtocolReceivers.apply(self, builder, receiver, true);
    const result = try @import("Try.zig").finishCall(self, builder, call, try analyzeReceiverCall(self, builder, call, receiver, safe_receiver_type));
    if (protocol_rooted) try ProtocolReceivers.apply(self, builder, receiver, false);
    if (rooted) try Resources.emitDrop(self, builder, receiver.type, receiver.value);
    return result;
}

fn candidateVisible(self: anytype, call: Ast.Expression.Call, owner: usize, method: Ast.Function) bool {
    if (call.generic_contract) |name| {
        const protocol = self.structureIndex(name) orelse return false;
        if (protocol >= self.program.structures.len) return false;
        for (self.program.structures[protocol].methods) |requirement| {
            if (Inheritance.sameSignature(method, requirement)) return true;
        }
        // A same-named overload is not automatically a protocol witness.
        return Visibility.memberVisible(self, owner, method, call.name_position);
    }
    return call.compiler_generated or Visibility.memberVisible(self, owner, method, call.name_position);
}

fn analyzeReceiverCall(
    self: anytype,
    builder: anytype,
    call: Ast.Expression.Call,
    receiver: Model.TypedValue,
    safe_receiver_type: ?Ast.Type,
) AnalyzeError!?Model.TypedValue {
    const receiver_expression = call.receiver.?;
    const super_call = receiver_expression.value == .identifier and std.mem.eql(u8, receiver_expression.value.identifier, "super");
    var resolved_receiver = receiver;
    if (super_call) {
        const context = self.member_context orelse return self.fail(receiver_expression.position, "'super' is only available in a class method");
        const base_index = self.structures[context].base orelse return self.fail(receiver_expression.position, "class has no base implementation");
        resolved_receiver = try self.coerce(builder, receiver, .structure(base_index), receiver_expression.position);
    }
    if (resolved_receiver.type == .str and std.mem.eql(u8, call.name, "count") and call.arguments.len == 0 and call.named_arguments.len == 0) {
        const result = try self.emitStringCount(builder, resolved_receiver.value);
        return try ProjectionOwnership.finishLoad(self, builder, resolved_receiver, result);
    }
    if (try Collections.analyzeCallWithValue(self, builder, call, resolved_receiver)) |value| return value;
    const receiver_structure_index = resolved_receiver.type.structureIndex() orelse {
        if (std.mem.eql(u8, call.name, "count")) return self.fail(call.name_position, "count() expects 'str'");
        const message = try std.fmt.allocPrint(self.allocator, "type '{s}' has no methods", .{self.typeName(receiver.type)});
        return self.fail(call.name_position, message);
    };
    if (receiver_structure_index >= self.program.structures.len) return error.InvalidSource;
    const receiver_structure = self.program.structures[receiver_structure_index];
    if (!call.compiler_generated and receiver_structure.is_local and call.name_position.file != receiver_structure.position.file) {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "members of local structure '{s}' are unavailable outside its source file",
            .{receiver_structure.name},
        );
        return self.fail(call.name_position, message);
    }
    if (!call.compiler_generated and receiver_structure.is_internal and !Visibility.packageVisible(self, receiver_structure.owner)) {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "members of package-visible structure '{s}' are unavailable outside its package",
            .{receiver_structure.name},
        );
        return self.fail(call.name_position, message);
    }
    if (call.named_arguments.len != 0) {
        return analyzeNamedCall(self, builder, call, receiver_expression, receiver, resolved_receiver, receiver_structure_index, safe_receiver_type, super_call);
    }
    const candidates = try Inheritance.methodCandidates(self, self.allocator, receiver_structure_index, call.name);

    var arity_count: usize = 0;
    var sole: ?usize = null;
    var inaccessible = false;
    var inaccessible_local = false;
    var inaccessible_internal = false;
    var inaccessible_module = false;
    var iterator_nonoptional: ?Ast.Type = null;
    for (candidates, 0..) |candidate, candidate_index| {
        if (!candidateVisible(self, call, candidate.owner, candidate.method)) {
            inaccessible = true;
            inaccessible_local = inaccessible_local or candidate.method.is_local;
            inaccessible_internal = inaccessible_internal or candidate.method.is_internal;
            inaccessible_module = inaccessible_module or
                (!candidate.method.is_public and !candidate.method.is_internal and !candidate.method.is_local and
                    !candidate.method.is_private and !candidate.method.is_protected);
            continue;
        }
        if (call.iterator_next and candidate.method.return_type.optionalChild() == null) {
            if (Support.acceptsArity(candidate.method.parameters, call.arguments.len)) {
                iterator_nonoptional = candidate.method.return_type;
            }
            continue;
        }
        if (Support.acceptsArity(candidate.method.parameters, call.arguments.len)) {
            arity_count += 1;
            sole = candidate_index;
        }
    }
    if (arity_count == 0) {
        if (call.iterator_next) if (iterator_nonoptional) |found| {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "iterator next() must return 'T?', found '{s}'",
                .{self.typeName(found)},
            );
            return self.fail(call.name_position, message);
        };
        if (inaccessible) {
            const message = if (inaccessible_local)
                try std.fmt.allocPrint(self.allocator, "method '{s}' is local to its source file", .{call.name})
            else if (inaccessible_internal)
                try std.fmt.allocPrint(self.allocator, "method '{s}' is package-visible and unavailable outside its package", .{call.name})
            else if (inaccessible_module)
                try std.fmt.allocPrint(self.allocator, "method '{s}' is module-visible and unavailable outside its module", .{call.name})
            else
                try std.fmt.allocPrint(self.allocator, "method '{s}' is private and unavailable here", .{call.name});
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
        if (call.iterator_next and method.return_type.optionalChild() == null) continue;
        if (!Support.acceptsArity(method.parameters, arguments.items.len)) continue;
        if (!candidateVisible(self, call, candidate.owner, method)) continue;
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
        const message = if (call.iterator_next)
            try std.fmt.allocPrint(self.allocator, "iterator next() is ambiguous", .{})
        else
            try std.fmt.allocPrint(self.allocator, "call to method '{s}' is ambiguous", .{call.name});
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
    if (mutating) if (Borrowing.rootName(receiver_expression)) |root| {
        try Borrowing.ensureRootUnborrowed(self, builder, root, receiver_expression.position);
    };
    if (mutating and receiver.borrowed_mode == .read) {
        const message = try std.fmt.allocPrint(self.allocator, "mutating method '{s}' cannot be called through a read reference", .{call.name});
        return self.fail(call.name_position, message);
    }
    // Class mutations update their shared identity in place. Writing the
    // receiver back could overwrite a replacement made by a reentrant call.
    var place = if (mutating and !borrowed_mutable and !class_receiver)
        try requireMutablePlace(self, builder, receiver_expression, call.name)
    else
        null;
    if (place) |target| if (!class_receiver) {
        place = try prepareReceiverPlace(self, builder, target, receiver, safe_receiver_type);
    };
    const borrowed_receiver = if (borrowed_mutable)
        try MutableReferences.prepare(self, builder, receiver_expression, receiver.type)
    else
        null;

    var argument_ids: std.ArrayList(Ir.ValueId) = .empty;
    var read_temporaries: std.ArrayList(Model.TypedValue) = .empty;
    var mutable_arguments: std.ArrayList(MutableReferences.Prepared) = .empty;
    const method_receiver = if (receiver_structure_index != structure_index and borrowed_receiver == null)
        try self.coerce(builder, resolved_receiver, .structure(structure_index), call.name_position)
    else
        resolved_receiver;
    try argument_ids.append(self.allocator, if (borrowed_receiver) |prepared| prepared.reference else method_receiver.value);
    for (arguments.items, method.parameters[0..arguments.items.len], 0..) |argument, parameter, index| {
        if (parameter.mode == .mutable) {
            if (Collections.isViewType(self.structures, parameter.type)) {
                if (argument.borrowed_mode != .mutable) return self.fail(call.arguments[index].position, "mutable view parameter requires an '&T[..]' argument");
                try argument_ids.append(self.allocator, argument.value);
                continue;
            }
            const prepared = try MutableReferences.prepare(self, builder, call.arguments[index], parameter.type);
            try mutable_arguments.append(self.allocator, prepared);
            try argument_ids.append(self.allocator, prepared.reference);
            continue;
        }
        if (parameter.mode != .read) try Borrowing.requireOwned(self, argument, call.arguments[index].position, "passed by value");
        const converted = try self.coerce(builder, argument, parameter.type, call.arguments[index].position);
        if (parameter.mode == .value and Resources.requiresRetain(self, parameter.type) and !converted.transferred) {
            try Resources.retainValue(self, builder, parameter.type, converted.value);
        }
        if (parameter.mode == .read and converted.transferred and Resources.ownsValue(self, converted.type)) {
            try read_temporaries.append(self.allocator, converted);
        }
        try argument_ids.append(self.allocator, converted.value);
    }
    for (method.parameters[arguments.items.len..]) |parameter| {
        const value = try self.analyzeParameterDefault(builder, parameter);
        if (parameter.mode == .read and value.transferred and Resources.ownsValue(self, value.type)) {
            try read_temporaries.append(self.allocator, value);
        }
        try argument_ids.append(self.allocator, value.value);
    }

    const ir_return_type = methodIrReturnType(self, structure_index, flat, method);
    const call_result: ?Ir.ValueId = if (ir_return_type == .void) null else try self.newValue(builder, ir_return_type);
    const arguments_slice = try argument_ids.toOwnedSlice(self.allocator);
    const dispatchable = method.extension == null and class_receiver and !super_call and
        !(self.constructor_context != null and receiver_expression.value == .identifier and std.mem.eql(u8, receiver_expression.value.identifier, "self")) and
        !method.is_private;
    const implementations = if (dispatchable)
        try Inheritance.implementations(self, self.allocator, structure_index, method_index)
    else
        &.{};
    const requires_dynamic_receiver = dispatchable and mutating and Inheritance.hasStrictDescendant(self, receiver_structure_index);
    if (implementations.len == 0 and !requires_dynamic_receiver) {
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
    try Resources.emitReadTemporaryDrops(self, builder, read_temporaries.items);
    if (receiver.transferred and Resources.requiresRetain(self, receiver.type)) {
        try Resources.emitDrop(self, builder, receiver.type, receiver.value);
    }

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
            .transferred = method.return_mode == .value and Resources.ownsValue(self, method.return_type),
        };
        return null;
    }
    if (method.return_type == .void) {
        if (class_receiver) {
            if (place) |target| {
                const updated_receiver = try restoreClassReceiver(
                    self,
                    builder,
                    call_result.?,
                    structure_index,
                    receiver_structure_index,
                );
                try writePlace(self, builder, target, updated_receiver);
            }
            return null;
        }
        const replacement = if (safe_receiver_type) |optional_type|
            (try Optionals.promote(self, builder, .{ .type = receiver.type, .value = call_result.? }, optional_type)).?.value
        else
            call_result.?;
        try writePlace(self, builder, place.?, replacement);
        return null;
    }
    if (class_receiver) {
        if (place) |target| {
            const returned_receiver = try self.newValue(builder, .structure(structure_index));
            try self.emit(builder, .{ .field_load = .{ .result = returned_receiver, .base = call_result.?, .field = 0 } });
            const updated_receiver = try restoreClassReceiver(
                self,
                builder,
                returned_receiver,
                structure_index,
                receiver_structure_index,
            );
            try writePlace(self, builder, target, updated_receiver);
        }
        const value = try self.newValue(builder, method.return_type);
        try self.emit(builder, .{ .field_load = .{ .result = value, .base = call_result.?, .field = 1 } });
        return .{
            .type = method.return_type,
            .value = value,
            .transferred = Resources.ownsValue(self, method.return_type) or if (method.intrinsic) |intrinsic| switch (intrinsic) {
                .resource_remove => true,
                else => false,
            } else false,
        };
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
    return .{
        .type = method.return_type,
        .value = value,
        .transferred = Resources.ownsValue(self, method.return_type),
    };
}

fn analyzeNamedCall(
    self: anytype,
    builder: anytype,
    call: Ast.Expression.Call,
    receiver_expression: *Ast.Expression,
    receiver: Model.TypedValue,
    resolved_receiver: Model.TypedValue,
    receiver_structure_index: usize,
    safe_receiver_type: ?Ast.Type,
    super_call: bool,
) !?Model.TypedValue {
    const all_candidates = try Inheritance.methodCandidates(self, self.allocator, receiver_structure_index, call.name);
    var candidates: std.ArrayList(usize) = .empty;
    var first_problem: ?Arguments.Problem = null;
    var template: ?[]const ?*Ast.Expression = null;
    for (all_candidates, 0..) |candidate, index| {
        if (!candidateVisible(self, call, candidate.owner, candidate.method)) continue;
        switch (try Arguments.map(self.allocator, candidate.method.parameters, call.arguments, call.named_arguments)) {
            .arguments => |mapped| {
                try candidates.append(self.allocator, index);
                if (template == null) template = mapped;
            },
            .problem => |problem| if (first_problem == null) {
                first_problem = problem;
            },
        }
    }
    if (candidates.items.len == 0) {
        try failArgumentProblem(self, call, first_problem orelse .too_many);
        unreachable;
    }
    const sources = template.?;
    const typed = try self.allocator.alloc(?Model.TypedValue, sources.len);
    @memset(typed, null);
    for (sources, 0..) |maybe_source, index| {
        const source = maybe_source orelse continue;
        // A shared parameter supplies context even before another argument
        // selects the overload. Conflicting parameter types supply no context.
        const expected = expected: {
            const parameter_type = all_candidates[candidates.items[0]].method.parameters[index].type;
            for (candidates.items[1..]) |candidate_index| {
                const parameters = all_candidates[candidate_index].method.parameters;
                if (index >= parameters.len or parameters[index].type != parameter_type) break :expected null;
            }
            break :expected Optionals.expectedContext(parameter_type, source);
        };
        typed[index] = try self.analyzeExpressionExpected(builder, source, expected);
    }
    var selected: ?usize = null;
    var best_cost: usize = std.math.maxInt(usize);
    var ambiguous = false;
    for (candidates.items) |candidate_index| {
        const candidate = all_candidates[candidate_index];
        const mapped = (try Arguments.map(self.allocator, candidate.method.parameters, call.arguments, call.named_arguments)).arguments;
        var cost: usize = 0;
        var viable = true;
        for (mapped, 0..) |maybe_source, index| {
            if (maybe_source == null) continue;
            const argument = typed[index].?;
            if (!self.canImplicitlyConvert(argument.type, candidate.method.parameters[index].type)) {
                viable = false;
                break;
            }
            if (argument.type != candidate.method.parameters[index].type) cost += 1;
        }
        if (!viable) continue;
        if (cost < best_cost) {
            selected = candidate_index;
            best_cost = cost;
            ambiguous = false;
        } else if (cost == best_cost) ambiguous = true;
    }
    if (ambiguous) {
        const message = try std.fmt.allocPrint(self.allocator, "call to method '{s}' is ambiguous", .{call.name});
        return self.fail(call.name_position, message);
    }
    const selected_candidate = all_candidates[
        selected orelse {
            const message = try std.fmt.allocPrint(self.allocator, "no overload of method '{s}' matches the argument types", .{call.name});
            return self.fail(call.name_position, message);
        }
    ];
    const structure_index = selected_candidate.owner;
    const method_index = selected_candidate.index;
    const method = selected_candidate.method;
    const mapped = (try Arguments.map(self.allocator, method.parameters, call.arguments, call.named_arguments)).arguments;
    try Borrowing.validateMappedReadArguments(self, method.parameters, mapped);
    if (self.structures[receiver_structure_index].is_protocol) {
        const sources_ordered = try self.allocator.alloc(*Ast.Expression, mapped.len);
        const values_ordered = try self.allocator.alloc(Model.TypedValue, mapped.len);
        for (mapped, 0..) |source, index| {
            sources_ordered[index] = source orelse return error.InvalidSource;
            values_ordered[index] = typed[index] orelse return error.InvalidSource;
        }
        var ordered_call = call;
        ordered_call.arguments = sources_ordered;
        ordered_call.named_arguments = &.{};
        return analyzeProtocolCall(self, builder, ordered_call, resolved_receiver, safe_receiver_type, method, values_ordered);
    }
    const flat = flatMethodIndex(self.program, structure_index, method_index);
    const mutating = self.method_mutability[flat];
    const class_receiver = self.structures[receiver_structure_index].is_class;
    const borrowed_mutable = method.return_mode == .mutable;
    if (mutating) if (Borrowing.rootName(receiver_expression)) |root| try Borrowing.ensureRootUnborrowed(self, builder, root, receiver_expression.position);
    if (mutating and receiver.borrowed_mode == .read) {
        const message = try std.fmt.allocPrint(self.allocator, "mutating method '{s}' cannot be called through a read reference", .{call.name});
        return self.fail(call.name_position, message);
    }
    // Class mutations update their shared identity in place. Writing the
    // receiver back could overwrite a replacement made by a reentrant call.
    var place = if (mutating and !borrowed_mutable and !class_receiver)
        try requireMutablePlace(self, builder, receiver_expression, call.name)
    else
        null;
    if (place) |target| if (!class_receiver) {
        place = try prepareReceiverPlace(self, builder, target, receiver, safe_receiver_type);
    };
    const borrowed_receiver = if (borrowed_mutable) try MutableReferences.prepare(self, builder, receiver_expression, receiver.type) else null;
    const method_receiver = if (receiver_structure_index != structure_index and borrowed_receiver == null)
        try self.coerce(builder, resolved_receiver, .structure(structure_index), call.name_position)
    else
        resolved_receiver;
    var ids: std.ArrayList(Ir.ValueId) = .empty;
    try ids.append(self.allocator, if (borrowed_receiver) |prepared| prepared.reference else method_receiver.value);
    var read_temporaries: std.ArrayList(Model.TypedValue) = .empty;
    var mutable_arguments: std.ArrayList(MutableReferences.Prepared) = .empty;
    for (method.parameters, mapped, 0..) |parameter, maybe_source, index| {
        const source = maybe_source orelse {
            const value = try self.analyzeParameterDefault(builder, parameter);
            if (parameter.mode == .read and value.transferred and Resources.ownsValue(self, value.type)) {
                try read_temporaries.append(self.allocator, value);
            }
            try ids.append(self.allocator, value.value);
            continue;
        };
        const argument = typed[index].?;
        if (parameter.mode == .mutable) {
            if (Collections.isViewType(self.structures, parameter.type)) {
                if (argument.borrowed_mode != .mutable) return self.fail(source.position, "mutable view parameter requires an '&T[..]' argument");
                try ids.append(self.allocator, argument.value);
                continue;
            }
            const prepared = try MutableReferences.prepare(self, builder, source, parameter.type);
            try mutable_arguments.append(self.allocator, prepared);
            try ids.append(self.allocator, prepared.reference);
            continue;
        }
        if (parameter.mode != .read) try Borrowing.requireOwned(self, argument, source.position, "passed by value");
        const converted = try self.coerce(builder, argument, parameter.type, source.position);
        if (parameter.mode == .value and Resources.requiresRetain(self, parameter.type) and !converted.transferred) {
            try Resources.retainValue(self, builder, parameter.type, converted.value);
        }
        if (parameter.mode == .read and converted.transferred and Resources.ownsValue(self, converted.type)) {
            try read_temporaries.append(self.allocator, converted);
        }
        try ids.append(self.allocator, converted.value);
    }
    const ir_return_type = methodIrReturnType(self, structure_index, flat, method);
    const call_result: ?Ir.ValueId = if (ir_return_type == .void) null else try self.newValue(builder, ir_return_type);
    const arguments_slice = try ids.toOwnedSlice(self.allocator);
    const dispatchable = method.extension == null and class_receiver and !super_call and
        !(self.constructor_context != null and receiver_expression.value == .identifier and std.mem.eql(u8, receiver_expression.value.identifier, "self")) and
        !method.is_private;
    const implementations = if (dispatchable)
        try Inheritance.implementations(self, self.allocator, structure_index, method_index)
    else
        &.{};
    const requires_dynamic_receiver = dispatchable and mutating and Inheritance.hasStrictDescendant(self, receiver_structure_index);
    if (implementations.len == 0 and !requires_dynamic_receiver) try self.emit(builder, .{ .call = .{
        .result = call_result,
        .function = methodFunctionId(self.program, structure_index, method_index),
        .arguments = arguments_slice,
    } }) else try self.emit(builder, .{ .dynamic_call = .{
        .result = call_result,
        .function = methodFunctionId(self.program, structure_index, method_index),
        .receiver = method_receiver.value,
        .arguments = arguments_slice,
        .implementations = implementations,
    } });
    for (mutable_arguments.items) |prepared| try MutableReferences.writeBack(self, builder, prepared);
    try Resources.emitReadTemporaryDrops(self, builder, read_temporaries.items);
    if (receiver.transferred and Resources.requiresRetain(self, receiver.type)) try Resources.emitDrop(self, builder, receiver.type, receiver.value);
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
            .transferred = method.return_mode == .value and Resources.ownsValue(self, method.return_type),
        };
        return null;
    }
    if (method.return_type == .void) {
        if (class_receiver) {
            if (place) |target| {
                const updated_receiver = try restoreClassReceiver(
                    self,
                    builder,
                    call_result.?,
                    structure_index,
                    receiver_structure_index,
                );
                try writePlace(self, builder, target, updated_receiver);
            }
            return null;
        }
        const replacement = if (safe_receiver_type) |optional_type|
            (try Optionals.promote(self, builder, .{ .type = receiver.type, .value = call_result.? }, optional_type)).?.value
        else
            call_result.?;
        try writePlace(self, builder, place.?, replacement);
        return null;
    }
    if (class_receiver) {
        if (place) |target| {
            const returned_receiver = try self.newValue(builder, .structure(structure_index));
            try self.emit(builder, .{ .field_load = .{ .result = returned_receiver, .base = call_result.?, .field = 0 } });
            const updated_receiver = try restoreClassReceiver(
                self,
                builder,
                returned_receiver,
                structure_index,
                receiver_structure_index,
            );
            try writePlace(self, builder, target, updated_receiver);
        }
        const value = try self.newValue(builder, method.return_type);
        try self.emit(builder, .{ .field_load = .{ .result = value, .base = call_result.?, .field = 1 } });
        return .{ .type = method.return_type, .value = value, .transferred = Resources.ownsValue(self, method.return_type) };
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
    return .{ .type = method.return_type, .value = value, .transferred = Resources.ownsValue(self, method.return_type) };
}

fn failArgumentProblem(self: anytype, call: Ast.Expression.Call, problem: Arguments.Problem) !void {
    const message = switch (problem) {
        .too_many => try std.fmt.allocPrint(self.allocator, "too many arguments for method '{s}'", .{call.name}),
        .unknown => |argument| try std.fmt.allocPrint(self.allocator, "unknown parameter label '{s}'", .{argument.name}),
        .duplicate => |argument| try std.fmt.allocPrint(self.allocator, "parameter '{s}' is provided more than once", .{argument.name}),
        .missing => |parameter| try std.fmt.allocPrint(self.allocator, "required parameter '{s}' is missing", .{parameter.name}),
    };
    const position = switch (problem) {
        .unknown => |argument| argument.position,
        .duplicate => |argument| argument.position,
        else => call.name_position,
    };
    return self.fail(position, message);
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
    // Property getters are nonmutating for every conformer. A constructor
    // parameter or borrowed projection can be read without receiver writeback.
    const getter = if (requirement.accessor) |accessor| accessor.kind == .get else false;
    const place: ?Place = if (getter) null else try prepareReceiverPlace(self, builder, try requireMutablePlace(self, builder, call.receiver.?, call.name), receiver, safe_receiver_type);
    var argument_ids: std.ArrayList(Ir.ValueId) = .empty;
    var read_temporaries: std.ArrayList(Model.TypedValue) = .empty;
    var mutable_arguments: std.ArrayList(MutableReferences.Prepared) = .empty;
    for (arguments, requirement.parameters[0..arguments.len], 0..) |argument, parameter, index| {
        if (parameter.mode == .mutable) {
            if (Collections.isViewType(self.structures, parameter.type)) {
                if (argument.borrowed_mode != .mutable) return self.fail(call.arguments[index].position, "mutable view parameter requires an '&T[..]' argument");
                try argument_ids.append(self.allocator, argument.value);
                continue;
            }
            const prepared = try MutableReferences.prepare(self, builder, call.arguments[index], parameter.type);
            try mutable_arguments.append(self.allocator, prepared);
            try argument_ids.append(self.allocator, prepared.reference);
        } else {
            if (parameter.mode != .read) try Borrowing.requireOwned(self, argument, call.arguments[index].position, "passed by value");
            const converted = try self.coerce(builder, argument, parameter.type, call.arguments[index].position);
            if (parameter.mode == .value and Resources.requiresRetain(self, parameter.type) and !converted.transferred) {
                try Resources.retainValue(self, builder, parameter.type, converted.value);
            }
            if (parameter.mode == .read and converted.transferred and Resources.ownsValue(self, converted.type)) {
                try read_temporaries.append(self.allocator, converted);
            }
            try argument_ids.append(self.allocator, converted.value);
        }
    }
    for (requirement.parameters[arguments.len..]) |parameter| {
        const value = try self.analyzeParameterDefault(builder, parameter);
        if (parameter.mode == .read and value.transferred and Resources.ownsValue(self, value.type)) {
            try read_temporaries.append(self.allocator, value);
        }
        try argument_ids.append(self.allocator, value.value);
    }

    const protocol_index = ProtocolValues.index(self, receiver.type) orelse return error.InvalidSource;
    const conformers = try ProtocolValues.conformers(self, protocol_index);
    if (conformers.len == 0) {
        try Resources.emitReadTemporaryDrops(self, builder, read_temporaries.items);
        return ProtocolValues.uninhabitedCall(self, builder, requirement.return_type, call.name_position);
    }
    var has_class = false;
    var has_value = false;
    for (conformers) |index| {
        if (self.structures[index].is_class) has_class = true else has_value = true;
    }
    const writeback = if (!getter and has_class and has_value) try self.newValue(builder, .bool) else null;
    const updated = if (getter) null else try self.newValue(builder, receiver.type);
    const result = if (requirement.return_type == .void) null else try self.newValue(builder, requirement.return_type);
    const merge_block = try self.newBlock(builder);
    for (conformers, 0..) |structure_index, conformer_index| {
        const witness_file = ProtocolValues.witnessFile(self, structure_index, protocol_index) orelse return error.InvalidSource;
        const implementation = ProtocolValues.implementationAt(self, structure_index, requirement, witness_file) orelse return error.InvalidSource;
        // Typed protocol values contain one of this program's conformers.
        // The final witness is exhaustive: an unmatched fallthrough would
        // reach the merge without defining its result or updated receiver.
        const next_block: ?Ir.BlockId = if (conformer_index + 1 < conformers.len) next: {
            const action = try self.newBlock(builder);
            const next = try self.newBlock(builder);
            const matches = try ProtocolValues.emitTest(self, builder, receiver.value, structure_index);
            self.terminate(builder, .{ .branch = .{ .condition = matches, .then_block = action, .else_block = next } });
            builder.current_block = action;
            break :next next;
        } else null;
        if (writeback) |flag| try self.emit(builder, .{ .constant_bool = .{
            .result = flag,
            .value = !self.structures[structure_index].is_class,
        } });
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
        if (updated) |target| try self.emit(builder, .{ .protocol_init = .{ .result = target, .operand = replacement, .structure = structure_index } });
        if (result) |target| {
            const source = if (mutating) source: {
                const value = try self.newValue(builder, requirement.return_type);
                try self.emit(builder, .{ .field_load = .{ .result = value, .base = concrete_result.?, .field = 1 } });
                break :source value;
            } else concrete_result.?;
            try self.emit(builder, .{ .copy = .{ .result = target, .operand = source } });
        }
        self.terminate(builder, .{ .jump = merge_block });
        if (next_block) |next| builder.current_block = next;
    }
    builder.current_block = merge_block;
    for (mutable_arguments.items) |prepared| try MutableReferences.writeBack(self, builder, prepared);
    try Resources.emitReadTemporaryDrops(self, builder, read_temporaries.items);
    if (place) |target| {
        const replacement = if (safe_receiver_type) |optional_type|
            (try Optionals.promote(self, builder, .{ .type = receiver.type, .value = updated.? }, optional_type)).?.value
        else
            updated.?;
        // Class witnesses mutate shared identity; writing them back would
        // overwrite a reentrant replacement and churn the stored class edge.
        if (!has_class) {
            try writePlace(self, builder, target, replacement);
        } else if (!has_value) {
            if (target.receiver_type) |type_value| try Resources.emitDrop(self, builder, type_value, replacement);
        } else {
            const write_block = try self.newBlock(builder);
            const release_block = try self.newBlock(builder);
            const done = try self.newBlock(builder);
            self.terminate(builder, .{ .branch = .{ .condition = writeback.?, .then_block = write_block, .else_block = release_block } });
            builder.current_block = write_block;
            try writePlace(self, builder, target, replacement);
            self.terminate(builder, .{ .jump = done });
            builder.current_block = release_block;
            if (target.receiver_type) |type_value| try Resources.emitDrop(self, builder, type_value, replacement);
            self.terminate(builder, .{ .jump = done });
            builder.current_block = done;
        }
    }
    return if (result) |value| .{ .type = requirement.return_type, .value = value, .transferred = Resources.ownsValue(self, requirement.return_type) } else null;
}

fn restoreClassReceiver(
    self: anytype,
    builder: anytype,
    returned_receiver: Ir.ValueId,
    owner: usize,
    receiver: usize,
) !Ir.ValueId {
    if (owner == receiver) return returned_receiver;
    const restored = try self.newValue(builder, .structure(receiver));
    try self.emit(builder, .{ .class_cast = .{ .result = restored, .operand = returned_receiver } });
    return restored;
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
                try analyzeMutatingReturnStatement(self, builder, method, .{
                    .structure_index = structure_index,
                    .flat = flat,
                    .self_local = self_local,
                }, return_statement);
                break :returned true;
            },
            .if_statement => |conditional| try analyzeMutatingIf(self, builder, method, structure_index, flat, self_local, conditional),
            .while_statement => |loop| try analyzeMutatingWhile(self, builder, method, structure_index, flat, self_local, loop),
            .for_statement => |loop| try Control.analyzeForUsing(
                self,
                builder,
                method,
                loop,
                MutatingMatchContext{ .structure_index = structure_index, .flat = flat, .self_local = self_local },
                analyzeMutatingMatchBranch,
            ),
            .mutex_statement => |mutex| protected: {
                if (mutex.synchronized) {
                    try self.emit(builder, .mutex_lock);
                    builder.mutex_depth += 1;
                }
                defer if (mutex.synchronized) {
                    builder.mutex_depth -= 1;
                };
                const binding_count = builder.bindings.items.len;
                const ended = try analyzeMutatingStatements(self, builder, method, structure_index, flat, self_local, mutex.statements);
                if (!ended) {
                    try Resources.emitActiveDrops(self, builder, binding_count);
                    if (mutex.synchronized) try self.emit(builder, .mutex_unlock);
                }
                builder.bindings.shrinkRetainingCapacity(binding_count);
                break :protected ended;
            },
            .expression_statement => |expression| switch (expression.value) {
                .match_expression => |match_value| try Matches.analyzeStatementUsing(
                    self,
                    builder,
                    method,
                    match_value,
                    MutatingMatchContext{ .structure_index = structure_index, .flat = flat, .self_local = self_local },
                    analyzeMutatingMatchBranch,
                ),
                else => ordinary: {
                    const one = [_]Ast.Statement{statement};
                    break :ordinary try self.analyzeStatements(builder, method, &one);
                },
            },
            else => ordinary: {
                const one = [_]Ast.Statement{statement};
                break :ordinary try self.analyzeStatements(builder, method, &one);
            },
        };
        if (terminated) return true;
    }
    return false;
}

const MutatingMatchContext = struct {
    structure_index: usize,
    flat: usize,
    self_local: Ir.LocalId,
};

fn analyzeMutatingMatchBranch(
    context: MutatingMatchContext,
    self: anytype,
    builder: anytype,
    method: Ast.Function,
    statements: []const Ast.Statement,
) AnalyzeError!bool {
    return analyzeMutatingStatements(
        self,
        builder,
        method,
        context.structure_index,
        context.flat,
        context.self_local,
        statements,
    );
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
    const availability_count = builder.bindings.items.len;
    const header_availability = try Availability.snapshot(self.allocator, builder.bindings.items, availability_count);
    const condition_block = try self.newBlock(builder);
    const body_block = try self.newBlock(builder);
    const exit_block = try self.newBlock(builder);
    self.terminate(builder, .{ .jump = condition_block });
    builder.current_block = condition_block;
    const analyzed = try Control.analyzeCondition(self, builder, loop.condition, "while");
    const false_availability = try Availability.snapshot(self.allocator, builder.bindings.items, availability_count);
    self.terminate(builder, .{ .branch = .{ .condition = analyzed.condition.value, .then_block = body_block, .else_block = exit_block } });
    builder.current_block = body_block;
    try builder.loops.append(self.allocator, .{
        .continue_block = condition_block,
        .break_block = exit_block,
        .availability_count = availability_count,
        .drop_binding_count = availability_count,
        .header_availability = header_availability,
        .mutex_depth = builder.mutex_depth,
    });
    const loop_index = builder.loops.items.len - 1;
    const binding_count = builder.bindings.items.len;
    if (analyzed.binding) |binding| try Control.enterBinding(self, builder, binding);
    const terminated = try analyzeMutatingStatements(self, builder, method, structure_index, flat, self_local, loop.statements);
    if (!terminated) try Resources.emitActiveDrops(self, builder, binding_count);
    builder.bindings.shrinkRetainingCapacity(binding_count);
    const loop_context = builder.loops.items[loop_index];
    builder.loops.items.len -= 1;
    if (!terminated) {
        try Availability.requireHeader(self, builder.bindings.items, header_availability, loop.position);
        self.terminate(builder, .{ .jump = condition_block });
    }
    builder.current_block = exit_block;
    const exit_availability = try self.allocator.dupe(bool, false_availability);
    for (loop_context.break_availabilities.items) |state| Availability.merge(exit_availability, state);
    Availability.restore(builder.bindings.items, exit_availability);
    return false;
}

pub fn analyzeMutatingReturnStatement(
    self: anytype,
    builder: anytype,
    method: Ast.Function,
    context: Model.MutatingReturnContext,
    return_statement: Ast.ReturnStatement,
) !void {
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
    try emitMutatingReturn(self, builder, context.structure_index, context.flat, context.self_local, method, value);
}

pub fn emitMutatingReturn(
    self: anytype,
    builder: anytype,
    structure_index: usize,
    flat: usize,
    self_local: Ir.LocalId,
    method: Ast.Function,
    value: ?Model.TypedValue,
) !void {
    if (value) |returned| if (Resources.requiresRetain(self, method.return_type) and !returned.transferred) {
        try Resources.retainValue(self, builder, method.return_type, returned.value);
    };
    try Resources.emitActiveDrops(self, builder, 0);
    try Resources.emitMutexUnlocks(self, builder, 0);
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
        .fields = try self.allocator.dupe(Ir.ValueId, &.{ receiver, value.?.value }),
    } });
    self.terminate(builder, .{ .return_value = result });
}
