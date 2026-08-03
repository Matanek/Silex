const std = @import("std");
const Ast = @import("../Ast.zig");
const Arguments = @import("Arguments.zig");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const Support = @import("Support.zig");
const Model = @import("Model.zig");
const Optionals = @import("Optionals.zig");
const Control = @import("Control.zig");
const Borrowing = @import("Borrowing.zig");
const MutableReferences = @import("MutableReferences.zig");
const Resources = @import("Resources.zig");
const Visibility = @import("Visibility.zig");
const Inheritance = @import("Inheritance.zig");

const AnalyzeError = error{ InvalidSource, OutOfMemory };

pub fn restrictedFieldDefault(self: anytype, expression: *const Ast.Expression) bool {
    return switch (expression.value) {
        .integer, .floating, .boolean, .null_value, .string => true,
        .unary => |unary| unary.operator == .negate and switch (unary.operand.value) {
            .integer, .floating => true,
            else => false,
        },
        .call => |call| call.arguments.len == 0 and self.structureIndex(call.name) != null and blk: {
            for (call.named_arguments) |argument| {
                if (!restrictedFieldDefault(self, argument.value)) break :blk false;
            }
            break :blk true;
        },
        else => false,
    };
}

pub fn analyze(
    self: anytype,
    structure_index: usize,
    constructor_index: usize,
    constructor: Ast.Constructor,
) !Ir.Function {
    const previous_owner_context = self.owner_context;
    self.owner_context = self.program.structures[structure_index].owner;
    defer self.owner_context = previous_owner_context;
    const previous_specialization_file = self.specialization_file;
    self.specialization_file = constructor.specialization_file;
    defer self.specialization_file = previous_specialization_file;
    const previous_context = self.member_context;
    const declaration = self.program.structures[structure_index];
    const nominal_index = self.structureIndex(declaration.name) orelse return error.InvalidSource;
    self.member_context = nominal_index;
    defer self.member_context = previous_context;
    const previous_constructor = self.constructor_context;
    self.constructor_context = nominal_index;
    defer self.constructor_context = previous_constructor;
    const structure_type = Ast.Type.structure(nominal_index);
    var builder: Model.FunctionBuilder = .{};
    try builder.blocks.append(self.allocator, .{});

    const parameter_types = try self.allocator.alloc(Ast.Type, constructor.parameters.len);
    for (constructor.parameters, 0..) |parameter, value| {
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

    const initialized = try self.allocator.alloc(bool, declaration.fields.len);
    var initial_fields: std.ArrayList(Ir.ValueId) = .empty;
    if (self.structures[nominal_index].base) |base_index| {
        const base_declaration = Inheritance.findDeclaration(self, base_index) orelse return error.InvalidSource;
        const base_value = if (base_declaration.constructors.len == 0) implicit: {
            if (constructor.super_arguments.len != 0) return self.fail(constructor.position, "base class has no positional constructor");
            break :implicit try self.emitIntrinsic(&builder, .structure(base_index), constructor.position);
        } else try analyzeCall(self, &builder, base_index, base_declaration, .{
            .name = base_declaration.name,
            .name_position = constructor.position,
            .arguments = constructor.super_arguments,
        });
        for (self.structures[base_index].fields, 0..) |field, field_index| {
            const value = try self.newValue(&builder, field.type);
            try self.emit(&builder, .{ .field_load = .{ .result = value, .base = base_value.value, .field = field_index } });
            try initial_fields.append(self.allocator, value);
        }
    }
    for (declaration.fields, 0..) |field, field_index| {
        var value = if (field.default) |expression|
            try self.analyzeExpressionExpected(
                &builder,
                expression,
                Optionals.expectedContext(field.type, expression),
            )
        else
            try self.emitIntrinsic(&builder, field.type, constructor.position);
        if (value.type != field.type and self.canImplicitlyConvert(value.type, field.type)) {
            value = try self.coerce(&builder, value, field.type, constructor.position);
        }
        try initial_fields.append(self.allocator, value.value);
        initialized[field_index] = field.mutable or field.default != null;
    }
    const initial_self = try self.newValue(&builder, structure_type);
    try self.emit(&builder, .{ .structure_init = .{
        .result = initial_self,
        .structure = nominal_index,
        .fields = try initial_fields.toOwnedSlice(self.allocator),
    } });
    const self_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, structure_type);
    try self.emit(&builder, .{ .local_store = .{ .local = self_local, .operand = initial_self } });
    try builder.bindings.append(self.allocator, .{
        .name = "self",
        .type = structure_type,
        .local = self_local,
        .mutable = true,
    });

    const function = Ast.Function{
        .position = constructor.position,
        .name_position = constructor.position,
        .name = declaration.name,
        .parameters = constructor.parameters,
        .return_type = structure_type,
        .statements = constructor.statements,
    };
    const terminated = try analyzeStatements(self, &builder, function, declaration, self_local, constructor.statements, initialized);
    if (!terminated) {
        for (declaration.fields, 0..) |field, field_index| {
            if (!initialized[field_index]) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "field '{s}' is not initialized on every constructor path",
                    .{field.name},
                );
                return self.fail(constructor.position, message);
            }
        }
        const result = try self.newValue(&builder, structure_type);
        try self.emit(&builder, .{ .local_load = .{ .result = result, .local = self_local } });
        try Resources.emitActiveDrops(self, &builder, 0);
        self.terminate(&builder, .{ .return_value = result });
    }

    const blocks = try self.allocator.alloc(Ir.Block, builder.blocks.items.len);
    for (builder.blocks.items, 0..) |*block, block_index| blocks[block_index] = .{
        .instructions = try block.instructions.toOwnedSlice(self.allocator),
        .terminator = block.terminator orelse return error.InvalidSource,
    };
    return .{
        .name = try std.fmt.allocPrint(self.allocator, "{s}.init#{d}", .{ declaration.name, constructor_index }),
        .parameter_types = parameter_types,
        .return_type = structure_type,
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .blocks = blocks,
    };
}

pub fn analyzeCall(
    self: anytype,
    builder: anytype,
    structure_index: usize,
    declaration: Ast.Structure,
    call: Ast.Expression.Call,
) !Model.TypedValue {
    if (call.named_arguments.len != 0) return analyzeNamedCall(self, builder, structure_index, declaration, call);

    var arity_count: usize = 0;
    var sole: ?usize = null;
    var inaccessible = false;
    var inaccessible_local = false;
    var inaccessible_internal = false;
    for (declaration.constructors, 0..) |constructor, constructor_index| {
        if (!Visibility.memberVisible(self, structure_index, constructor, call.name_position)) {
            inaccessible = true;
            inaccessible_local = inaccessible_local or constructor.is_local;
            inaccessible_internal = inaccessible_internal or constructor.is_internal;
            continue;
        }
        if (Support.acceptsArity(constructor.parameters, call.arguments.len)) {
            arity_count += 1;
            sole = constructor_index;
        }
    }
    if (arity_count == 0) {
        if (inaccessible) {
            const message = if (inaccessible_local)
                try std.fmt.allocPrint(self.allocator, "constructor of '{s}' is local to its source file", .{declaration.name})
            else if (inaccessible_internal)
                try std.fmt.allocPrint(self.allocator, "constructor of '{s}' is internal to its package", .{declaration.name})
            else
                try std.fmt.allocPrint(self.allocator, "constructor of '{s}' is unavailable here", .{declaration.name});
            return self.fail(call.name_position, message);
        }
        const message = try std.fmt.allocPrint(
            self.allocator,
            "no constructor of '{s}' accepts {d} arguments",
            .{ declaration.name, call.arguments.len },
        );
        return self.fail(call.name_position, message);
    }

    var arguments: std.ArrayList(Model.TypedValue) = .empty;
    for (call.arguments, 0..) |argument, argument_index| {
        const expected = if (arity_count == 1) expected: {
            const parameter_type = declaration.constructors[sole.?].parameters[argument_index].type;
            break :expected Optionals.expectedContext(parameter_type, argument);
        } else null;
        try arguments.append(self.allocator, try self.analyzeExpressionExpected(builder, argument, expected));
    }

    var selected: ?usize = null;
    var selected_cost: usize = std.math.maxInt(usize);
    var ambiguous = false;
    for (declaration.constructors, 0..) |constructor, constructor_index| {
        if (!Support.acceptsArity(constructor.parameters, arguments.items.len)) continue;
        if (!Visibility.memberVisible(self, structure_index, constructor, call.name_position)) continue;
        var cost: usize = 0;
        var viable = true;
        for (constructor.parameters[0..arguments.items.len], arguments.items) |parameter, argument| {
            if (parameter.type == argument.type) continue;
            if (!self.canImplicitlyConvert(argument.type, parameter.type)) {
                viable = false;
                break;
            }
            cost += 1;
        }
        if (!viable) continue;
        if (cost < selected_cost) {
            selected = constructor_index;
            selected_cost = cost;
            ambiguous = false;
        } else if (cost == selected_cost) ambiguous = true;
    }
    if (ambiguous) {
        const message = try std.fmt.allocPrint(self.allocator, "call to constructor of '{s}' is ambiguous", .{declaration.name});
        return self.fail(call.name_position, message);
    }
    const constructor_index = selected orelse {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "no constructor of '{s}' matches the argument types",
            .{declaration.name},
        );
        return self.fail(call.name_position, message);
    };
    const constructor = declaration.constructors[constructor_index];
    try Borrowing.validateReadArguments(self, constructor.parameters, call.arguments);
    var argument_ids: std.ArrayList(Ir.ValueId) = .empty;
    var mutable_arguments: std.ArrayList(MutableReferences.Prepared) = .empty;
    for (arguments.items, constructor.parameters[0..arguments.items.len], 0..) |argument, parameter, index| {
        if (parameter.mode == .mutable) {
            const prepared = try MutableReferences.prepare(self, builder, call.arguments[index], parameter.type);
            try mutable_arguments.append(self.allocator, prepared);
            try argument_ids.append(self.allocator, prepared.reference);
            continue;
        }
        if (parameter.mode != .read) try Borrowing.requireOwned(self, argument, call.arguments[index].position, "passed by value");
        const converted = try self.coerce(builder, argument, parameter.type, call.arguments[index].position);
        if (parameter.mode == .value and Resources.containsClass(self, parameter.type)) {
            try Resources.retainValue(self, builder, parameter.type, converted.value);
        }
        try argument_ids.append(self.allocator, converted.value);
    }
    for (constructor.parameters[arguments.items.len..]) |parameter| {
        const value = try self.analyzeParameterDefault(builder, parameter);
        try argument_ids.append(self.allocator, value.value);
    }
    const result_type = Ast.Type.structure(structure_index);
    const result = try self.newValue(builder, result_type);
    try self.emit(builder, .{ .call = .{
        .result = result,
        .function = constructorFunctionId(self.program, declaration.name, constructor_index),
        .arguments = try argument_ids.toOwnedSlice(self.allocator),
    } });
    for (mutable_arguments.items) |prepared| try MutableReferences.writeBack(self, builder, prepared);
    for (arguments.items) |argument| if (argument.transferred and Resources.containsClass(self, argument.type)) {
        try Resources.emitDrop(self, builder, argument.type, argument.value);
    };
    return .{
        .type = result_type,
        .value = result,
        .transferred = Resources.containsClass(self, result_type) and !Resources.isClassType(self, result_type),
    };
}

fn analyzeNamedCall(
    self: anytype,
    builder: anytype,
    structure_index: usize,
    declaration: Ast.Structure,
    call: Ast.Expression.Call,
) !Model.TypedValue {
    var candidates: std.ArrayList(usize) = .empty;
    var first_problem: ?Arguments.Problem = null;
    var template: ?[]const ?*Ast.Expression = null;
    for (declaration.constructors, 0..) |constructor, index| {
        if (!Visibility.memberVisible(self, structure_index, constructor, call.name_position)) continue;
        switch (try Arguments.map(self.allocator, constructor.parameters, call.arguments, call.named_arguments)) {
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
        try failArgumentProblem(self, call, declaration.name, first_problem orelse .too_many);
        unreachable;
    }
    const sources = template.?;
    const typed = try self.allocator.alloc(?Model.TypedValue, sources.len);
    @memset(typed, null);
    for (sources, 0..) |maybe_source, index| {
        const source = maybe_source orelse continue;
        const expected = if (candidates.items.len == 1)
            Optionals.expectedContext(declaration.constructors[candidates.items[0]].parameters[index].type, source)
        else
            null;
        typed[index] = try self.analyzeExpressionExpected(builder, source, expected);
    }

    var selected: ?usize = null;
    var best_cost: usize = std.math.maxInt(usize);
    var ambiguous = false;
    for (candidates.items) |index| {
        const constructor = declaration.constructors[index];
        const mapped = (try Arguments.map(self.allocator, constructor.parameters, call.arguments, call.named_arguments)).arguments;
        var cost: usize = 0;
        var viable = true;
        for (mapped, 0..) |maybe_source, parameter_index| {
            if (maybe_source == null) continue;
            const argument = typed[parameter_index].?;
            if (!self.canImplicitlyConvert(argument.type, constructor.parameters[parameter_index].type)) {
                viable = false;
                break;
            }
            if (argument.type != constructor.parameters[parameter_index].type) cost += 1;
        }
        if (!viable) continue;
        if (cost < best_cost) {
            selected = index;
            best_cost = cost;
            ambiguous = false;
        } else if (cost == best_cost) ambiguous = true;
    }
    if (ambiguous) {
        const message = try std.fmt.allocPrint(self.allocator, "call to constructor of '{s}' is ambiguous", .{declaration.name});
        return self.fail(call.name_position, message);
    }
    const constructor_index = selected orelse {
        const message = try std.fmt.allocPrint(self.allocator, "no constructor of '{s}' matches the argument types", .{declaration.name});
        return self.fail(call.name_position, message);
    };
    const constructor = declaration.constructors[constructor_index];
    const mapped = (try Arguments.map(self.allocator, constructor.parameters, call.arguments, call.named_arguments)).arguments;
    try Borrowing.validateMappedReadArguments(self, constructor.parameters, mapped);
    var ids: std.ArrayList(Ir.ValueId) = .empty;
    var mutable_arguments: std.ArrayList(MutableReferences.Prepared) = .empty;
    for (constructor.parameters, mapped, 0..) |parameter, maybe_source, index| {
        const source = maybe_source orelse {
            try ids.append(self.allocator, (try self.analyzeParameterDefault(builder, parameter)).value);
            continue;
        };
        const argument = typed[index].?;
        if (parameter.mode == .mutable) {
            const prepared = try MutableReferences.prepare(self, builder, source, parameter.type);
            try mutable_arguments.append(self.allocator, prepared);
            try ids.append(self.allocator, prepared.reference);
            continue;
        }
        if (parameter.mode != .read) try Borrowing.requireOwned(self, argument, source.position, "passed by value");
        const converted = try self.coerce(builder, argument, parameter.type, source.position);
        if (parameter.mode == .value and Resources.containsClass(self, parameter.type)) try Resources.retainValue(self, builder, parameter.type, converted.value);
        try ids.append(self.allocator, converted.value);
    }
    const result_type = Ast.Type.structure(structure_index);
    const result = try self.newValue(builder, result_type);
    try self.emit(builder, .{ .call = .{ .result = result, .function = constructorFunctionId(self.program, declaration.name, constructor_index), .arguments = try ids.toOwnedSlice(self.allocator) } });
    for (mutable_arguments.items) |prepared| try MutableReferences.writeBack(self, builder, prepared);
    for (typed) |maybe_argument| if (maybe_argument) |argument| {
        if (argument.transferred and Resources.containsClass(self, argument.type)) {
            try Resources.emitDrop(self, builder, argument.type, argument.value);
        }
    };
    return .{
        .type = result_type,
        .value = result,
        .transferred = Resources.containsClass(self, result_type) and !Resources.isClassType(self, result_type),
    };
}

fn failArgumentProblem(self: anytype, call: Ast.Expression.Call, structure_name: []const u8, problem: Arguments.Problem) !void {
    const message = switch (problem) {
        .too_many => try std.fmt.allocPrint(self.allocator, "too many arguments for constructor of '{s}'", .{structure_name}),
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

fn constructorFunctionId(program: Ast.Program, structure_name: []const u8, constructor_index: usize) Ir.FunctionId {
    var result = program.functions.len;
    for (program.structures) |structure| {
        if (std.mem.eql(u8, structure.name, structure_name)) return result + constructor_index;
        result += structure.constructors.len;
    }
    return result + constructor_index;
}

fn analyzeStatements(
    self: anytype,
    builder: anytype,
    function: Ast.Function,
    structure: Ast.Structure,
    self_local: Ir.LocalId,
    statements: []const Ast.Statement,
    initialized: []bool,
) AnalyzeError!bool {
    for (statements) |statement| {
        const terminated = switch (statement) {
            .assignment_statement => |assignment| assignment_statement: {
                if (std.mem.eql(u8, assignment.target.name, "self")) {
                    try analyzeSelfAssignment(self, builder, structure, self_local, assignment, initialized);
                    break :assignment_statement false;
                }
                try validateStatementReads(self, structure, statement, initialized);
                const one = [_]Ast.Statement{statement};
                break :assignment_statement try self.analyzeStatements(builder, function, &one);
            },
            .if_statement => |conditional| try analyzeIf(self, builder, function, structure, self_local, conditional, initialized),
            .return_statement => return self.fail(statement.position(), "constructors return 'self' implicitly"),
            .while_statement => return self.fail(statement.position(), "while is not available during constructor initialization yet"),
            .for_statement => return self.fail(statement.position(), "for is not available during constructor initialization yet"),
            .mutex_statement => |mutex| mutex_statement: {
                try self.emit(builder, .mutex_lock);
                builder.mutex_depth += 1;
                defer builder.mutex_depth -= 1;
                const terminated = try analyzeStatements(self, builder, function, structure, self_local, mutex.statements, initialized);
                if (!terminated) try self.emit(builder, .mutex_unlock);
                break :mutex_statement terminated;
            },
            .break_statement, .continue_statement => return self.fail(statement.position(), "loop control is not valid in a constructor"),
            else => ordinary: {
                try validateStatementReads(self, structure, statement, initialized);
                const one = [_]Ast.Statement{statement};
                break :ordinary try self.analyzeStatements(builder, function, &one);
            },
        };
        if (terminated) return true;
    }
    return false;
}

fn analyzeIf(
    self: anytype,
    builder: anytype,
    function: Ast.Function,
    structure: Ast.Structure,
    self_local: Ir.LocalId,
    conditional: Ast.IfStatement,
    initialized: []bool,
) AnalyzeError!bool {
    const incoming = try self.allocator.dupe(bool, initialized);
    var merged: ?[]bool = null;
    var exits: std.ArrayList(Ir.BlockId) = .empty;
    for (conditional.branches) |branch| {
        try validateExpressionReads(self, structure, branch.condition.source(), incoming);
        const analyzed = try Control.analyzeCondition(self, builder, branch.condition, "if");
        const body_block = try self.newBlock(builder);
        const next_block = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{
            .condition = analyzed.condition.value,
            .then_block = body_block,
            .else_block = next_block,
        } });

        builder.current_block = body_block;
        const branch_state = try self.allocator.dupe(bool, incoming);
        const binding_count = builder.bindings.items.len;
        if (analyzed.binding) |binding| try Control.enterBinding(self, builder, binding);
        const terminated = try analyzeStatements(self, builder, function, structure, self_local, branch.statements, branch_state);
        if (!terminated) try Resources.emitActiveDrops(self, builder, binding_count);
        builder.bindings.shrinkRetainingCapacity(binding_count);
        if (!terminated) {
            try exits.append(self.allocator, builder.current_block);
            mergeState(&merged, branch_state);
        }
        builder.current_block = next_block;
    }

    if (conditional.else_statements) |statements| {
        const else_state = try self.allocator.dupe(bool, incoming);
        const binding_count = builder.bindings.items.len;
        const terminated = try analyzeStatements(self, builder, function, structure, self_local, statements, else_state);
        if (!terminated) try Resources.emitActiveDrops(self, builder, binding_count);
        builder.bindings.shrinkRetainingCapacity(binding_count);
        if (!terminated) {
            try exits.append(self.allocator, builder.current_block);
            mergeState(&merged, else_state);
        }
    } else {
        try exits.append(self.allocator, builder.current_block);
        mergeState(&merged, incoming);
    }

    if (exits.items.len == 0) return true;
    const merge_block = try self.newBlock(builder);
    for (exits.items) |block_id| builder.blocks.items[block_id].terminator = .{ .jump = merge_block };
    builder.current_block = merge_block;
    @memcpy(initialized, merged.?);
    return false;
}

fn mergeState(merged: *?[]bool, candidate: []bool) void {
    if (merged.* == null) {
        merged.* = candidate;
        return;
    }
    for (merged.*.?, candidate) |*value, other| value.* = value.* and other;
}

fn analyzeSelfAssignment(
    self: anytype,
    builder: anytype,
    structure: Ast.Structure,
    self_local: Ir.LocalId,
    assignment: Ast.AssignmentStatement,
    initialized: []bool,
) !void {
    if (assignment.target.fields.len != 1) {
        return self.fail(assignment.target.name_position, "constructor initialization target must be a direct field of 'self'");
    }
    const target = assignment.target.fields[0];
    var selected: ?usize = null;
    for (structure.fields, 0..) |field, field_index| {
        if (std.mem.eql(u8, field.name, target.name)) {
            selected = field_index;
            break;
        }
    }
    const field_index = selected orelse {
        const owner_index = fieldOwnerIndex(self, structure.name);
        if (Inheritance.fieldByName(self, owner_index, target.name)) |inherited| if (inherited.owner != owner_index) {
            const one = [_]Ast.Statement{.{ .assignment_statement = assignment }};
            _ = try self.analyzeStatements(builder, .{
                .position = assignment.position,
                .name_position = assignment.position,
                .name = structure.name,
                .parameters = &.{},
                .return_type = .void,
                .statements = &one,
            }, &one);
            return;
        };
        const message = try std.fmt.allocPrint(self.allocator, "structure '{s}' has no field named '{s}'", .{ structure.name, target.name });
        return self.fail(target.name_position, message);
    };
    const field = structure.fields[field_index];
    if (assignment.operator != .assign) {
        if (!initialized[field_index]) {
            const message = try std.fmt.allocPrint(self.allocator, "field '{s}' is read before initialization", .{field.name});
            return self.fail(target.name_position, message);
        }
        if (!field.mutable) {
            const message = try std.fmt.allocPrint(self.allocator, "cannot update immutable field '{s}'", .{field.name});
            return self.fail(target.name_position, message);
        }
        const one = [_]Ast.Statement{.{ .assignment_statement = assignment }};
        _ = try self.analyzeStatements(builder, .{
            .position = assignment.position,
            .name_position = assignment.position,
            .name = structure.name,
            .parameters = &.{},
            .return_type = .void,
            .statements = &one,
        }, &one);
        return;
    }
    if (!field.mutable and initialized[field_index]) {
        const message = try std.fmt.allocPrint(self.allocator, "immutable field '{s}' is initialized more than once", .{field.name});
        return self.fail(target.name_position, message);
    }
    try validateExpressionReads(self, structure, assignment.value.?, initialized);
    var value = try self.analyzeExpressionExpected(
        builder,
        assignment.value.?,
        Optionals.expectedContext(field.type, assignment.value.?),
    );
    if (value.type != field.type and self.canImplicitlyConvert(value.type, field.type)) {
        value = try self.coerce(builder, value, field.type, assignment.value.?.position);
    }
    if (value.type != field.type) {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "initialization of field '{s}' expects '{s}', found '{s}'",
            .{ field.name, self.typeName(field.type), self.typeName(value.type) },
        );
        return self.fail(assignment.value.?.position, message);
    }
    if (Resources.containsClass(self, field.type)) {
        try Resources.retainValue(self, builder, field.type, value.value);
    }

    const structure_index = fieldOwnerIndex(self, structure.name);
    const structure_type = Ast.Type.structure(structure_index);
    const base = try self.newValue(builder, structure_type);
    try self.emit(builder, .{ .local_load = .{ .result = base, .local = self_local } });
    const fields = try self.allocator.alloc(Ir.ValueId, self.structures[structure_index].fields.len);
    const inherited_count = if (self.structures[structure_index].base) |parent| self.structures[parent].fields.len else 0;
    const flattened_target = inherited_count + field_index;
    for (self.structures[structure_index].fields, 0..) |other, index| {
        if (index == flattened_target) {
            fields[index] = value.value;
        } else {
            fields[index] = try self.newValue(builder, other.type);
            try self.emit(builder, .{ .field_load = .{ .result = fields[index], .base = base, .field = index } });
        }
    }
    const replacement = try self.newValue(builder, structure_type);
    try self.emit(builder, .{ .structure_init = .{
        .result = replacement,
        .structure = structure_index,
        .fields = fields,
    } });
    try self.emit(builder, .{ .local_store = .{ .local = self_local, .operand = replacement } });
    initialized[field_index] = true;
}

fn fieldOwnerIndex(self: anytype, name: []const u8) usize {
    for (self.program.structures, 0..) |structure, index| {
        if (std.mem.eql(u8, structure.name, name)) return index;
    }
    unreachable;
}

fn validateStatementReads(self: anytype, structure: Ast.Structure, statement: Ast.Statement, initialized: []const bool) !void {
    switch (statement) {
        .variable_declaration => |declaration| if (declaration.initializer) |value| try validateExpressionReads(self, structure, value, initialized),
        .assignment_statement => |assignment| if (assignment.value) |value| try validateExpressionReads(self, structure, value, initialized),
        .return_statement => |statement_value| if (statement_value.value) |value| try validateExpressionReads(self, structure, value, initialized),
        .expression_statement => |value| try validateExpressionReads(self, structure, value, initialized),
        .print_statement => |print_statement| for (print_statement.values) |value| try validateExpressionReads(self, structure, value, initialized),
        .assert_statement => |assertion| {
            try validateExpressionReads(self, structure, assertion.condition, initialized);
            try validateExpressionReads(self, structure, assertion.message, initialized);
        },
        .panic_statement => |panic_statement| try validateExpressionReads(self, structure, panic_statement.value, initialized),
        .mutex_statement => |mutex| for (mutex.statements) |nested| try validateStatementReads(self, structure, nested, initialized),
        else => {},
    }
}

fn validateExpressionReads(self: anytype, structure: Ast.Structure, expression: *const Ast.Expression, initialized: []const bool) !void {
    switch (expression.value) {
        .identifier => |name| if (std.mem.eql(u8, name, "self") and !allInitialized(initialized)) {
            return self.fail(expression.position, "self cannot be used before all fields are initialized");
        },
        .field_access => |access| {
            if (access.base.value == .identifier and std.mem.eql(u8, access.base.value.identifier, "self")) {
                for (structure.fields, 0..) |field, field_index| {
                    if (!std.mem.eql(u8, field.name, access.name)) continue;
                    if (!initialized[field_index]) {
                        const message = try std.fmt.allocPrint(self.allocator, "field '{s}' is read before initialization", .{field.name});
                        return self.fail(access.name_position, message);
                    }
                    return;
                }
            }
            try validateExpressionReads(self, structure, access.base, initialized);
        },
        .call => |call| {
            if (call.receiver) |receiver| try validateExpressionReads(self, structure, receiver, initialized);
            for (call.arguments) |argument| try validateExpressionReads(self, structure, argument, initialized);
            for (call.named_arguments) |argument| try validateExpressionReads(self, structure, argument.value, initialized);
        },
        .cascade => |cascade| {
            try validateExpressionReads(self, structure, cascade.receiver, initialized);
            for (cascade.operations) |operation| switch (operation) {
                .method_call => |method| {
                    for (method.arguments) |argument| try validateExpressionReads(self, structure, argument, initialized);
                    for (method.named_arguments) |argument| try validateExpressionReads(self, structure, argument.value, initialized);
                },
                .field_assignment => |field| try validateExpressionReads(self, structure, field.value, initialized),
            };
        },
        .unary => |unary| try validateExpressionReads(self, structure, unary.operand, initialized),
        .binary => |binary| {
            try validateExpressionReads(self, structure, binary.left, initialized);
            try validateExpressionReads(self, structure, binary.right, initialized);
        },
        .conversion => |conversion| try validateExpressionReads(self, structure, conversion.operand, initialized),
        .string_count => |operand| try validateExpressionReads(self, structure, operand, initialized),
        .interpolated_string => |interpolated| for (interpolated.parts) |part| switch (part) {
            .text => {},
            .expression => |value| try validateExpressionReads(self, structure, value, initialized),
        },
        else => {},
    }
}

fn allInitialized(initialized: []const bool) bool {
    for (initialized) |value| if (!value) return false;
    return true;
}
