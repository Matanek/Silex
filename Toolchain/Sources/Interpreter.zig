const std = @import("std");
const Boundary = @import("Boundary.zig");
const Ir = @import("Ir.zig");
const MainBoundary = @import("MainBoundary.zig");
const Numeric = @import("Numeric.zig");
const RuntimeValue = @import("Interpreter/Value.zig");
const Dispatch = @import("Interpreter/Dispatch.zig");
const Globals = @import("Interpreter/Globals.zig");
const Classes = @import("Interpreter/Classes.zig");
const Protocols = @import("Interpreter/Protocols.zig");
const Output = @import("Interpreter/Output.zig");
const SnapshotGate = @import("Runtime/SnapshotGate.zig");

const Allocator = std.mem.Allocator;
const max_call_depth = 512;

pub const Error = Allocator.Error || error{
    InvalidProgram,
    IntegerOverflow,
    DivisionByZero,
    CallStackOverflow,
    RuntimeTerminated,
    UnsupportedBoundary,
    InvalidConversion,
    InvalidShift,
};

pub const Value = RuntimeValue.Value;

pub const RunResult = struct {
    exit_code: u8,
    stdout: []const u8,
    stderr: []const u8,
};

pub const Session = struct {
    allocator: Allocator,
    io: ?std.Io = null,
    boundaries: []const Boundary.Function = &.{},
    stdout: std.ArrayList(u8) = .empty,
    stderr: std.ArrayList(u8) = .empty,
    terminated: bool = false,
    globals: []Value = &.{},
    classes: std.ArrayList(Classes.Entry) = .empty,
    snapshot_gate: SnapshotGate.Gate = .{},
    mutex_depth: usize = 0,
};

pub fn run(allocator: Allocator, program: Ir.Program) Error!u8 {
    return (try runCapture(allocator, program)).exit_code;
}

pub fn runCapture(allocator: Allocator, program: Ir.Program) Error!RunResult {
    return runCaptureWithBoundaries(allocator, null, program, &.{});
}

pub fn runCaptureWithBoundaries(
    allocator: Allocator,
    io: ?std.Io,
    program: Ir.Program,
    boundaries: []const Boundary.Function,
) Error!RunResult {
    var main: ?Ir.FunctionId = null;
    for (program.functions, 0..) |function, function_id| {
        if (!std.mem.eql(u8, function.name, "main")) continue;
        if (main != null) return error.InvalidProgram;
        main = function_id;
    }
    const function_id = main orelse return error.InvalidProgram;
    const function = program.functions[function_id];
    const recoverable = MainBoundary.accepts(program.enums, function.return_type);
    if (function.parameter_types.len != 0 or (function.return_type != .void and !recoverable)) return error.InvalidProgram;
    var session: Session = .{
        .allocator = allocator,
        .io = io,
        .boundaries = boundaries,
        .globals = try Globals.initialize(allocator, program.globals),
    };
    const result = invokeDepth(allocator, program, function_id, &.{}, 0, &session) catch |err| switch (err) {
        error.RuntimeTerminated => return .{
            .exit_code = 1,
            .stdout = try session.stdout.toOwnedSlice(allocator),
            .stderr = try session.stderr.toOwnedSlice(allocator),
        },
        else => |other| return other,
    };
    if (session.mutex_depth != 0) return error.InvalidProgram;
    if (function.return_type == .void) {
        if (result != .void) return error.InvalidProgram;
    } else {
        const value = switch (result) {
            .enumeration => |enumeration| enumeration,
            else => return error.InvalidProgram,
        };
        const enumeration_index = MainBoundary.enumerationIndex(program.enums, function.return_type) orelse return error.InvalidProgram;
        if (value.enumeration != enumeration_index) return error.InvalidProgram;
        const enumeration = program.enums[enumeration_index];
        const success = MainBoundary.variantIndex(enumeration, "success") orelse return error.InvalidProgram;
        const failure = MainBoundary.variantIndex(enumeration, "failure") orelse return error.InvalidProgram;
        if (value.variant == failure) {
            if (value.values.len != 1 or value.values[0] != .string) return error.InvalidProgram;
            try session.stderr.appendSlice(allocator, "error: ");
            try session.stderr.appendSlice(allocator, value.values[0].string);
            try session.stderr.append(allocator, '\n');
            return .{
                .exit_code = 1,
                .stdout = try session.stdout.toOwnedSlice(allocator),
                .stderr = try session.stderr.toOwnedSlice(allocator),
            };
        }
        if (value.variant != success or value.values.len != 0) return error.InvalidProgram;
    }
    return .{
        .exit_code = 0,
        .stdout = try session.stdout.toOwnedSlice(allocator),
        .stderr = try session.stderr.toOwnedSlice(allocator),
    };
}

pub fn invoke(
    allocator: Allocator,
    program: Ir.Program,
    function: Ir.FunctionId,
    arguments: []const Value,
) Error!Value {
    var session: Session = .{ .allocator = allocator };
    return invokeDepth(allocator, program, function, arguments, 0, &session);
}

pub fn invokeDepth(
    allocator: Allocator,
    program: Ir.Program,
    function_id: Ir.FunctionId,
    arguments: []const Value,
    depth: usize,
    session: *Session,
) Error!Value {
    if (depth >= max_call_depth) return error.CallStackOverflow;
    if (function_id >= program.functions.len) return error.InvalidProgram;
    const function = program.functions[function_id];
    if (arguments.len != function.parameter_types.len or function.parameter_types.len > function.value_types.len) {
        return error.InvalidProgram;
    }

    const values = try allocator.alloc(?Value, function.value_types.len);
    defer allocator.free(values);
    @memset(values, null);
    const locals = try allocator.alloc(?Value, function.local_types.len);
    defer allocator.free(locals);
    @memset(locals, null);
    for (arguments, function.parameter_types, 0..) |argument, parameter_type, index| {
        if (argument.typeOf() != parameter_type) return error.InvalidProgram;
        values[index] = try cloneValue(allocator, argument);
    }

    var block_id: Ir.BlockId = 0;
    while (true) {
        if (block_id >= function.blocks.len) return error.InvalidProgram;
        const block = function.blocks[block_id];
        for (block.instructions) |*instruction| {
            if (try executeInstruction(allocator, program, function, values, locals, instruction, depth, session)) |result| return result;
        }
        switch (block.terminator) {
            .jump => |target| block_id = target,
            .branch => |branch| block_id = if (try boolean(try load(values, branch.condition))) branch.then_block else branch.else_block,
            .return_value => |value_id| {
                const result = try load(values, value_id);
                if (result.typeOf() != function.return_type or function.return_type == .void) return error.InvalidProgram;
                return cloneValue(allocator, result);
            },
            .return_void => {
                if (function.return_type != .void) return error.InvalidProgram;
                return .void;
            },
            .panic => |panic_value| {
                const message = try string(try load(values, panic_value.message));
                try Output.appendRuntimeError(session, program, panic_value.position, "", message);
                session.terminated = true;
                return error.RuntimeTerminated;
            },
        }
    }
}

fn executeInstruction(
    allocator: Allocator,
    program: Ir.Program,
    function: Ir.Function,
    values: []?Value,
    locals: []?Value,
    instruction: *const Ir.Instruction,
    depth: usize,
    session: *Session,
) Error!?Value {
    switch (instruction.*) {
        .string_address => return error.UnsupportedBoundary,
        .string_byte_count => |count| {
            const text = try string(try load(values, count.operand));
            try store(function, values, count.result, .{ .typed_integer = .{ .type = .uint, .bits = text.len } });
        },
        .string_byte_at => |access| {
            const text = try string(try load(values, access.operand));
            const index = try numericInteger(try load(values, access.index));
            if (index.bits >= text.len) return error.InvalidProgram;
            try store(function, values, access.result, .{ .typed_integer = .{ .type = .uint8, .bits = text[@intCast(index.bits)] } });
        },
        .string_from_bytes => |conversion| {
            const source = switch (try load(values, conversion.bytes)) {
                .view => |view| view.fields,
                else => return error.InvalidProgram,
            };
            const result = try allocator.alloc(u8, source.len);
            for (source, 0..) |item, index| {
                const byte = switch (item) {
                    .typed_integer => |integer_value| if (integer_value.type == .uint8) integer_value.bits else return error.InvalidProgram,
                    else => return error.InvalidProgram,
                };
                result[index] = @intCast(byte);
            }
            try store(function, values, conversion.result, .{ .string = result });
        },
        .boundary_call => |call| try executeBoundary(function, values, call, session),
        .constant_int => |constant| {
            const type_value = function.value_types[constant.result];
            const value: Value = if (type_value.functionIndex() != null)
                .{ .function = .{ .type = type_value, .id = std.math.maxInt(Ir.FunctionId) } }
            else if (type_value == .int)
                .{ .integer = @bitCast(constant.bits) }
            else
                .{ .typed_integer = .{ .type = type_value, .bits = constant.bits } };
            try store(function, values, constant.result, value);
        },
        .constant_bool => |constant| try store(function, values, constant.result, .{ .boolean = constant.value }),
        .constant_str => |constant| try store(function, values, constant.result, .{ .string = constant.value }),
        .constant_float32 => |constant| try store(function, values, constant.result, .{ .float32 = @bitCast(constant.bits) }),
        .constant_float64 => |constant| try store(function, values, constant.result, .{ .float64 = @bitCast(constant.bits) }),
        .function_reference => |reference| {
            if (reference.function >= program.functions.len) return error.InvalidProgram;
            try store(function, values, reference.result, .{ .function = .{
                .type = function.value_types[reference.result],
                .id = reference.function,
            } });
        },
        .optional_null => |optional| {
            const type_value = function.value_types[optional.result];
            if (type_value.optionalChild() == null) return error.InvalidProgram;
            try store(function, values, optional.result, .{ .optional = .{ .type = type_value, .value = null } });
        },
        .optional_some => |optional| {
            const operand = try load(values, optional.operand);
            const type_value = function.value_types[optional.result];
            if (type_value.optionalChild() != operand.typeOf()) return error.InvalidProgram;
            const payload = try allocator.create(Value);
            payload.* = try cloneValue(allocator, operand);
            try store(function, values, optional.result, .{ .optional = .{ .type = type_value, .value = payload } });
        },
        .optional_unwrap => |optional| {
            const value = switch (try load(values, optional.operand)) {
                .optional => |value| value.value orelse return error.InvalidProgram,
                else => return error.InvalidProgram,
            };
            try store(function, values, optional.result, try cloneValue(allocator, value.*));
        },
        .copy => |copy| try store(function, values, copy.result, try cloneValue(allocator, try load(values, copy.operand))),
        .deep_copy => |copy| {
            const guard = session.snapshot_gate.capture();
            defer guard.release();
            var classes = std.AutoHashMap(*Value.Structure, *Value.Structure).init(allocator);
            defer classes.deinit();
            try store(function, values, copy.result, try deepCloneValue(allocator, program, try load(values, copy.operand), session, &classes));
        },
        .class_cast => |cast| {
            var value = switch (try load(values, cast.operand)) {
                .class => |class| class,
                else => return error.InvalidProgram,
            };
            value.static_type = function.value_types[cast.result];
            try store(function, values, cast.result, .{ .class = value });
        },
        .class_retain => |retain| {
            const class = switch (try load(values, retain.operand)) {
                .class => |value| value,
                else => return error.InvalidProgram,
            };
            const guard = session.snapshot_gate.mutation();
            defer guard.release();
            try Classes.retain(session.classes.items, class.instance);
        },
        .class_drop => |drop| {
            const class = switch (try load(values, drop.operand)) {
                .class => |value| value,
                else => return error.InvalidProgram,
            };
            const should_finalize = finalize: {
                const guard = session.snapshot_gate.mutation();
                defer guard.release();
                break :finalize try Classes.release(session.classes.items, class.instance);
            };
            if (should_finalize) {
                const dynamic_type = class.instance.type.structureIndex() orelse return error.InvalidProgram;
                const plan = for (drop.plans) |candidate| {
                    if (candidate.structure == dynamic_type) break candidate;
                } else return error.InvalidProgram;
                for (plan.functions) |finalizer| {
                    const result = try invokeDepth(allocator, program, finalizer.function, &.{.{ .class = .{
                        .static_type = .structure(finalizer.structure),
                        .instance = class.instance,
                    } }}, depth + 1, session);
                    if (result != .void) return error.InvalidProgram;
                }
            }
        },
        .global_load => |load_value| try store(function, values, load_value.result, try Globals.load(allocator, session.globals, load_value)),
        .global_store => |store_value| {
            const guard = session.snapshot_gate.mutation();
            defer guard.release();
            try Globals.store(allocator, program, session.globals, store_value, try load(values, store_value.operand));
        },
        .structure_init => |initialization| {
            if (initialization.structure >= program.structures.len or
                initialization.fields.len != program.structures[initialization.structure].fields.len)
            {
                return error.InvalidProgram;
            }
            const fields = try allocator.alloc(Value, initialization.fields.len);
            for (initialization.fields, 0..) |field, index| {
                fields[index] = try cloneValue(allocator, try load(values, field));
                if (fields[index].typeOf() != program.structures[initialization.structure].fields[index].type) {
                    return error.InvalidProgram;
                }
            }
            const aggregate = Value.Structure{
                .type = .structure(initialization.structure),
                .fields = fields,
            };
            if (program.structures[initialization.structure].is_class) {
                const instance = try allocator.create(Value.Structure);
                instance.* = aggregate;
                const guard = session.snapshot_gate.mutation();
                defer guard.release();
                try Classes.register(allocator, &session.classes, instance);
                try store(function, values, initialization.result, .{ .class = .{
                    .static_type = .structure(initialization.structure),
                    .instance = instance,
                } });
            } else try store(function, values, initialization.result, .{ .structure = aggregate });
        },
        .protocol_init => |initialization| try Protocols.initialize(allocator, function, values, initialization),
        .protocol_test => |test_value| try Protocols.testValue(function, values, test_value),
        .protocol_extract => |extraction| try Protocols.extract(allocator, function, values, extraction),
        .list_init => |initialization| try executeListInit(allocator, function, values, initialization),
        .enum_init => |initialization| {
            if (initialization.enumeration >= program.enums.len) return error.InvalidProgram;
            const enumeration = program.enums[initialization.enumeration];
            if (initialization.variant >= enumeration.variants.len) return error.InvalidProgram;
            const variant = enumeration.variants[initialization.variant];
            if (initialization.values.len != variant.associated_types.len) return error.InvalidProgram;
            const payload = try allocator.alloc(Value, initialization.values.len);
            for (initialization.values, 0..) |value, index| {
                payload[index] = try cloneValue(allocator, try load(values, value));
                if (payload[index].typeOf() != variant.associated_types[index]) return error.InvalidProgram;
            }
            const value = try allocator.create(Value.Enumeration);
            value.* = .{
                .type = .structure(enumeration.type_index),
                .enumeration = initialization.enumeration,
                .variant = initialization.variant,
                .values = payload,
            };
            try store(function, values, initialization.result, .{ .enumeration = value });
        },
        .enum_test => |test_value| {
            const value = switch (try load(values, test_value.operand)) {
                .enumeration => |enumeration| enumeration,
                else => return error.InvalidProgram,
            };
            if (value.enumeration != test_value.enumeration) return error.InvalidProgram;
            try store(function, values, test_value.result, .{ .boolean = value.variant == test_value.variant });
        },
        .enum_payload => |payload| {
            const value = switch (try load(values, payload.operand)) {
                .enumeration => |enumeration| enumeration,
                else => return error.InvalidProgram,
            };
            if (value.enumeration != payload.enumeration or value.variant != payload.variant or
                payload.index >= value.values.len) return error.InvalidProgram;
            try store(function, values, payload.result, try cloneValue(allocator, value.values[payload.index]));
        },
        .enum_raw => |raw| {
            if (raw.enumeration >= program.enums.len) return error.InvalidProgram;
            const value = switch (try load(values, raw.operand)) {
                .enumeration => |enumeration| enumeration,
                else => return error.InvalidProgram,
            };
            if (value.enumeration != raw.enumeration) return error.InvalidProgram;
            const raw_value = program.enums[raw.enumeration].variants[value.variant].raw_value orelse return error.InvalidProgram;
            try store(function, values, raw.result, switch (raw_value) {
                .integer => |raw_integer| .{ .integer = raw_integer },
                .string => |raw_string| .{ .string = raw_string },
            });
        },
        .field_load => |field| {
            const aggregate = switch (try load(values, field.base)) {
                .structure => |value| value,
                .class => |value| value.instance.*,
                else => return error.InvalidProgram,
            };
            if (field.field >= aggregate.fields.len) return error.InvalidProgram;
            try store(function, values, field.result, try cloneValue(allocator, aggregate.fields[field.field]));
        },
        .field_store => |field| {
            const guard = session.snapshot_gate.mutation();
            defer guard.release();
            const instance = switch (try load(values, field.base)) {
                .class => |value| value,
                else => return error.InvalidProgram,
            };
            if (field.field >= instance.instance.fields.len) return error.InvalidProgram;
            instance.instance.fields[field.field] = try cloneValue(allocator, try load(values, field.replacement));
            try store(function, values, field.result, .{ .class = instance });
        },
        .collection_load => |access| try executeCollectionLoad(allocator, program, function, values, access, session),
        .collection_reference => |access| try executeCollectionReference(allocator, program, function, values, access, session),
        .collection_replace => |replacement| try executeCollectionReplace(allocator, program, function, values, replacement, session),
        .collection_count => |count| try executeCollectionCount(function, values, count),
        .list_edit => |edit| try executeListEdit(allocator, program, function, values, edit, session),
        .collection_slice => |slice| try executeCollectionSlice(allocator, function, values, slice),
        .collection_view => |view| try executeCollectionView(function, values, view),
        .local_load => |local| {
            const value = try cloneValue(allocator, try loadLocal(function, locals, local.local));
            try store(function, values, local.result, value);
        },
        .local_store => |local| try storeLocal(
            function,
            locals,
            local.local,
            try cloneValue(allocator, try load(values, local.operand)),
        ),
        .local_address => |address| {
            if (address.local >= locals.len or locals[address.local] == null) return error.InvalidProgram;
            try store(function, values, address.result, .{ .reference = .{ .optional = &locals[address.local] } });
        },
        .reference_load => |reference| {
            const pointer = switch (try load(values, reference.reference)) {
                .reference => |value| value,
                else => return error.InvalidProgram,
            };
            try store(function, values, reference.result, try cloneValue(allocator, try pointer.load()));
        },
        .address_load, .address_store => return error.UnsupportedBoundary,
        .reference_store => |reference| {
            const guard = session.snapshot_gate.mutation();
            defer guard.release();
            const pointer = switch (try load(values, reference.reference)) {
                .reference => |value| value,
                else => return error.InvalidProgram,
            };
            pointer.store(try cloneValue(allocator, try load(values, reference.operand)));
        },
        .reference_field => |field| {
            const pointer = switch (try load(values, field.reference)) {
                .reference => |value| value,
                else => return error.InvalidProgram,
            };
            const root = switch (pointer) {
                .optional => |value| value.* orelse return error.InvalidProgram,
                .value => |value| value.*,
            };
            if (root != .structure) return error.InvalidProgram;
            var structure = root.structure;
            if (structure.type.structureIndex() != field.structure or field.field >= structure.fields.len) return error.InvalidProgram;
            try store(function, values, field.result, .{ .reference = .{ .value = &structure.fields[field.field] } });
        },
        .convert => |conversion| {
            const operand = try load(values, conversion.operand);
            const converted = convert(operand, conversion.target, conversion.checked) catch |err| switch (err) {
                error.InvalidConversion => {
                    try Output.appendRuntimeError(session, program, conversion.position, "", "invalid numeric conversion");
                    session.terminated = true;
                    return error.RuntimeTerminated;
                },
                else => |other| return other,
            };
            try store(function, values, conversion.result, converted);
        },
        .format_value => |format| {
            var text: std.ArrayList(u8) = .empty;
            try Output.appendValueText(&text, allocator, try load(values, format.operand));
            try store(function, values, format.result, .{ .string = try text.toOwnedSlice(allocator) });
        },
        .string_concat => |concat| {
            const left = try string(try load(values, concat.left));
            const right = try string(try load(values, concat.right));
            const result = try allocator.alloc(u8, left.len + right.len);
            @memcpy(result[0..left.len], left);
            @memcpy(result[left.len..], right);
            try store(function, values, concat.result, .{ .string = result });
        },
        .string_count => |count| {
            const value = try string(try load(values, count.operand));
            const scalar_count = std.unicode.utf8CountCodepoints(value) catch return error.InvalidProgram;
            try store(function, values, count.result, .{ .integer = @intCast(scalar_count) });
        },
        .unary => |unary| {
            const operand = try load(values, unary.operand);
            const result = try negateValue(operand);
            try store(function, values, unary.result, result);
        },
        .binary => |binary| {
            const left = try load(values, binary.left);
            const right = try load(values, binary.right);
            const result = try calculate(binary.operator, left, right, function.value_types[binary.result]);
            try store(function, values, binary.result, result);
        },
        .call => |call| {
            if (call.function >= program.functions.len) return error.InvalidProgram;
            const callee = program.functions[call.function];
            if (call.arguments.len != callee.parameter_types.len) return error.InvalidProgram;
            const call_arguments = try allocator.alloc(Value, call.arguments.len);
            defer allocator.free(call_arguments);
            for (call.arguments, 0..) |argument, index| call_arguments[index] = try load(values, argument);
            const result = try invokeDepth(allocator, program, call.function, call_arguments, depth + 1, session);
            if (call.result) |result_id| {
                if (callee.return_type == .void or result == .void) return error.InvalidProgram;
                try store(function, values, result_id, result);
            } else if (callee.return_type != .void or result != .void) {
                return error.InvalidProgram;
            }
        },
        .indirect_call => |call| {
            const callback = switch (try load(values, call.callee)) {
                .function => |value| value,
                else => return error.InvalidProgram,
            };
            if (callback.id >= program.functions.len) return error.InvalidProgram;
            const callee = program.functions[callback.id];
            if (call.arguments.len != callee.parameter_types.len) return error.InvalidProgram;
            const call_arguments = try allocator.alloc(Value, call.arguments.len);
            defer allocator.free(call_arguments);
            for (call.arguments, 0..) |argument, index| call_arguments[index] = try load(values, argument);
            const result = try invokeDepth(allocator, program, callback.id, call_arguments, depth + 1, session);
            if (call.result) |result_id| {
                if (callee.return_type == .void or result == .void) return error.InvalidProgram;
                try store(function, values, result_id, result);
            } else if (callee.return_type != .void or result != .void) return error.InvalidProgram;
        },
        .dynamic_call => |call| try Dispatch.execute(allocator, program, function, values, call, depth, session, invokeDepth),
        .print => |print_value| {
            try Output.appendValueText(&session.stdout, session.allocator, try load(values, print_value.value));
            if (print_value.newline) try session.stdout.append(session.allocator, '\n');
        },
        .assert => |assertion| {
            const condition = try boolean(try load(values, assertion.condition));
            if (!condition) {
                const message = try string(try load(values, assertion.message));
                try Output.appendRuntimeError(session, program, assertion.position, "assertion failed: ", message);
                session.terminated = true;
                return error.RuntimeTerminated;
            }
        },
        .mutex_lock => session.mutex_depth += 1,
        .mutex_unlock => {
            if (session.mutex_depth == 0) return error.InvalidProgram;
            session.mutex_depth -= 1;
        },
    }
    return null;
}

pub fn supportsBoundary(boundary: Boundary.Function) bool {
    return std.mem.eql(u8, boundary.provider, "MacOS.lib_system") and
        std.mem.eql(u8, boundary.source_name, "arc4random") and
        boundary.parameters.len == 0 and boundary.return_type == .uint32;
}

fn executeBoundary(
    function: Ir.Function,
    values: []?Value,
    call: Ir.Instruction.BoundaryCall,
    session: *Session,
) Error!void {
    if (call.function >= session.boundaries.len) return error.UnsupportedBoundary;
    const boundary = session.boundaries[call.function];
    if (!supportsBoundary(boundary) or call.arguments.len != 0) return error.UnsupportedBoundary;
    const io = session.io orelse return error.UnsupportedBoundary;
    const result = call.result orelse return error.InvalidProgram;
    var bits: u32 = undefined;
    io.random(std.mem.asBytes(&bits));
    try store(function, values, result, .{
        .typed_integer = .{ .type = .uint32, .bits = bits },
    });
}

fn store(function: Ir.Function, values: []?Value, id: Ir.ValueId, value: Value) Error!void {
    if (id >= values.len or function.value_types[id] != value.typeOf()) return error.InvalidProgram;
    values[id] = value;
}

fn load(values: []const ?Value, id: Ir.ValueId) Error!Value {
    if (id >= values.len) return error.InvalidProgram;
    return values[id] orelse error.InvalidProgram;
}

const cloneValue = RuntimeValue.clone;

fn deepCloneValue(
    allocator: Allocator,
    program: Ir.Program,
    value: Value,
    session: *Session,
    classes: *std.AutoHashMap(*Value.Structure, *Value.Structure),
) Error!Value {
    return switch (value) {
        .structure => |aggregate| cloned: {
            const fields = try allocator.alloc(Value, aggregate.fields.len);
            for (aggregate.fields, 0..) |field, index| fields[index] = try deepCloneValue(allocator, program, field, session, classes);
            break :cloned .{ .structure = .{ .type = aggregate.type, .fields = fields } };
        },
        .class => |class| cloned: {
            const dynamic_type = class.instance.type.structureIndex() orelse return error.InvalidProgram;
            if (dynamic_type >= program.structures.len or !program.structures[dynamic_type].is_class) return error.InvalidProgram;
            if (classes.get(class.instance)) |existing| break :cloned .{ .class = .{ .static_type = class.static_type, .instance = existing } };
            const instance = try allocator.create(Value.Structure);
            instance.* = .{ .type = class.instance.type, .fields = &.{} };
            try Classes.register(allocator, &session.classes, instance);
            try classes.put(class.instance, instance);
            const fields = try allocator.alloc(Value, class.instance.fields.len);
            instance.fields = fields;
            for (class.instance.fields, 0..) |field, index| fields[index] = try deepCloneValue(allocator, program, field, session, classes);
            break :cloned .{ .class = .{ .static_type = class.static_type, .instance = instance } };
        },
        .protocol => |protocol| cloned: {
            const concrete = try allocator.create(Value);
            concrete.* = try deepCloneValue(allocator, program, protocol.concrete.*, session, classes);
            break :cloned .{ .protocol = .{ .type = protocol.type, .concrete = concrete } };
        },
        .enumeration => |enumeration| cloned: {
            const payload = try allocator.alloc(Value, enumeration.values.len);
            for (enumeration.values, 0..) |item, index| payload[index] = try deepCloneValue(allocator, program, item, session, classes);
            const copy = try allocator.create(Value.Enumeration);
            copy.* = .{
                .type = enumeration.type,
                .enumeration = enumeration.enumeration,
                .variant = enumeration.variant,
                .values = payload,
            };
            break :cloned .{ .enumeration = copy };
        },
        .optional => |optional| cloned: {
            const payload = if (optional.value) |present| payload: {
                const copy = try allocator.create(Value);
                copy.* = try deepCloneValue(allocator, program, present.*, session, classes);
                break :payload copy;
            } else null;
            break :cloned .{ .optional = .{ .type = optional.type, .value = payload } };
        },
        .view => error.InvalidProgram,
        else => value,
    };
}

fn storeLocal(function: Ir.Function, locals: []?Value, id: Ir.LocalId, value: Value) Error!void {
    if (id >= locals.len or function.local_types[id] != value.typeOf()) return error.InvalidProgram;
    locals[id] = value;
}

fn loadLocal(function: Ir.Function, locals: []const ?Value, id: Ir.LocalId) Error!Value {
    if (id >= locals.len) return error.InvalidProgram;
    const value = locals[id] orelse return error.InvalidProgram;
    if (function.local_types[id] != value.typeOf()) return error.InvalidProgram;
    return value;
}

fn integer(value: Value) Error!i64 {
    return switch (value) {
        .integer => |result| result,
        else => error.InvalidProgram,
    };
}

fn normalizedCollectionIndex(index: i64, count: usize) ?usize {
    const normalized = if (index < 0) index + @as(i64, @intCast(count)) else index;
    if (normalized < 0 or normalized >= count) return null;
    return @intCast(normalized);
}

fn executeListInit(allocator: Allocator, function: Ir.Function, values: []?Value, initialization: Ir.Instruction.ListInit) Error!void {
    const fields = try allocator.alloc(Value, initialization.values.len);
    for (initialization.values, 0..) |value, index| fields[index] = try cloneValue(allocator, try load(values, value));
    try store(function, values, initialization.result, .{ .structure = .{
        .type = function.value_types[initialization.result],
        .fields = fields,
    } });
}

fn executeCollectionCount(function: Ir.Function, values: []?Value, count: Ir.Instruction.CollectionCount) Error!void {
    const collection = switch (try load(values, count.collection)) {
        .structure => |value| value,
        .view => |value| Value.Structure{ .type = value.type, .fields = value.fields },
        else => return error.InvalidProgram,
    };
    try store(function, values, count.result, .{ .integer = @intCast(collection.fields.len) });
}

fn executeListEdit(
    allocator: Allocator,
    program: Ir.Program,
    function: Ir.Function,
    values: []?Value,
    edit: Ir.Instruction.ListEdit,
    session: *Session,
) Error!void {
    const source = switch (try load(values, edit.collection)) {
        .structure => |value| value,
        else => return error.InvalidProgram,
    };
    var index: usize = 0;
    if (edit.kind == .insert or edit.kind == .take) {
        const raw = try integer(try load(values, edit.index.?));
        index = normalizedCollectionIndex(raw, source.fields.len) orelse {
            const message = try std.fmt.allocPrint(allocator, "collection index {d} is out of bounds for count {d}", .{ raw, source.fields.len });
            try Output.appendRuntimeError(session, program, edit.position, "", message);
            session.terminated = true;
            return error.RuntimeTerminated;
        };
    } else if (edit.kind == .take_first or edit.kind == .take_last) {
        if (source.fields.len == 0) {
            try Output.appendRuntimeError(session, program, edit.position, "", "cannot take an element from an empty list");
            session.terminated = true;
            return error.RuntimeTerminated;
        }
        index = if (edit.kind == .take_last) source.fields.len - 1 else 0;
    }
    const argument_values: []const Value = if (edit.kind == .append_sequence) switch (try load(values, edit.argument.?)) {
        .structure => |value| value.fields,
        else => return error.InvalidProgram,
    } else &.{};
    const new_len = switch (edit.kind) {
        .append, .prepend, .insert => source.fields.len + 1,
        .append_sequence => source.fields.len + argument_values.len,
        .take, .take_first, .take_last => source.fields.len - 1,
        .clear => 0,
        .reverse => source.fields.len,
    };
    const result = try allocator.alloc(Value, new_len);
    switch (edit.kind) {
        .append => {
            for (source.fields, 0..) |item, at| result[at] = try cloneValue(allocator, item);
            result[new_len - 1] = try cloneValue(allocator, try load(values, edit.argument.?));
        },
        .append_sequence => {
            for (source.fields, 0..) |item, at| result[at] = try cloneValue(allocator, item);
            for (argument_values, source.fields.len..) |item, at| result[at] = try cloneValue(allocator, item);
        },
        .prepend, .insert => {
            const insertion = if (edit.kind == .prepend) 0 else index;
            for (result, 0..) |*item, at| item.* = try cloneValue(allocator, if (at == insertion)
                try load(values, edit.argument.?)
            else
                source.fields[if (at < insertion) at else at - 1]);
        },
        .take, .take_first, .take_last => {
            for (result, 0..) |*item, at| item.* = try cloneValue(allocator, source.fields[if (at < index) at else at + 1]);
            try store(function, values, edit.removed.?, try cloneValue(allocator, source.fields[index]));
        },
        .clear => {},
        .reverse => {
            for (result, 0..) |*item, at| item.* = try cloneValue(allocator, source.fields[source.fields.len - 1 - at]);
        },
    }
    try store(function, values, edit.result, .{ .structure = .{ .type = source.type, .fields = result } });
}

fn executeCollectionSlice(allocator: Allocator, function: Ir.Function, values: []?Value, slice: Ir.Instruction.CollectionSlice) Error!void {
    const source = switch (try load(values, slice.collection)) {
        .structure => |value| value,
        .view => |value| Value.Structure{ .type = value.type, .fields = value.fields },
        else => return error.InvalidProgram,
    };
    const count: i64 = @intCast(source.fields.len);
    var start = try integer(try load(values, slice.start));
    var end = try integer(try load(values, slice.end));
    if (start < 0) start += count;
    if (end < 0) end += count;
    start = std.math.clamp(start, 0, count);
    end = std.math.clamp(end, 0, count);
    const length: usize = if (start < end) @intCast(end - start) else 0;
    const result = try allocator.alloc(Value, length);
    for (result, 0..) |*item, index| item.* = try cloneValue(allocator, source.fields[@as(usize, @intCast(start)) + index]);
    try store(function, values, slice.result, .{ .structure = .{
        .type = function.value_types[slice.result],
        .fields = result,
    } });
}

fn executeCollectionView(function: Ir.Function, values: []?Value, view: Ir.Instruction.CollectionSlice) Error!void {
    const source_value = if (view.reference) |reference| switch (try load(values, reference)) {
        .reference => |pointer| try pointer.load(),
        else => return error.InvalidProgram,
    } else try load(values, view.collection);
    const fields = switch (source_value) {
        .structure => |value| value.fields,
        .view => |value| value.fields,
        else => return error.InvalidProgram,
    };
    const count: i64 = @intCast(fields.len);
    var start = try integer(try load(values, view.start));
    var end = try integer(try load(values, view.end));
    if (start < 0) start += count;
    if (end < 0) end += count;
    start = std.math.clamp(start, 0, count);
    end = std.math.clamp(end, 0, count);
    const length: usize = if (start < end) @intCast(end - start) else 0;
    const offset: usize = @intCast(start);
    try store(function, values, view.result, .{ .view = .{
        .type = function.value_types[view.result],
        .fields = fields[offset .. offset + length],
    } });
}

fn executeCollectionLoad(
    allocator: Allocator,
    program: Ir.Program,
    function: Ir.Function,
    values: []?Value,
    access: Ir.Instruction.CollectionLoad,
    session: *Session,
) Error!void {
    const aggregate = switch (try load(values, access.collection)) {
        .structure => |value| value,
        .view => |value| Value.Structure{ .type = value.type, .fields = value.fields },
        else => return error.InvalidProgram,
    };
    const source_index = try integer(try load(values, access.index));
    const offset = normalizedCollectionIndex(source_index, aggregate.fields.len) orelse {
        const message = try std.fmt.allocPrint(allocator, "collection index {d} is out of bounds for count {d}", .{ source_index, aggregate.fields.len });
        try Output.appendRuntimeError(session, program, access.position, "", message);
        session.terminated = true;
        return error.RuntimeTerminated;
    };
    try store(function, values, access.result, try cloneValue(allocator, aggregate.fields[offset]));
}

fn executeCollectionReference(
    allocator: Allocator,
    program: Ir.Program,
    function: Ir.Function,
    values: []?Value,
    access: Ir.Instruction.CollectionReference,
    session: *Session,
) Error!void {
    const source = if (access.reference) |reference| switch (try load(values, reference)) {
        .reference => |pointer| try pointer.load(),
        else => return error.InvalidProgram,
    } else try load(values, access.collection);
    const fields = switch (source) {
        .structure => |value| value.fields,
        .view => |value| value.fields,
        else => return error.InvalidProgram,
    };
    const source_index = try integer(try load(values, access.index));
    const offset = normalizedCollectionIndex(source_index, fields.len) orelse {
        const message = try std.fmt.allocPrint(allocator, "collection index {d} is out of bounds for count {d}", .{ source_index, fields.len });
        try Output.appendRuntimeError(session, program, access.position, "", message);
        session.terminated = true;
        return error.RuntimeTerminated;
    };
    try store(function, values, access.result, .{ .reference = .{ .value = &fields[offset] } });
}

fn executeCollectionReplace(
    allocator: Allocator,
    program: Ir.Program,
    function: Ir.Function,
    values: []?Value,
    replacement: Ir.Instruction.CollectionReplace,
    session: *Session,
) Error!void {
    const source = try load(values, replacement.collection);
    const aggregate = switch (source) {
        .structure => |value| value,
        .view => |value| Value.Structure{ .type = value.type, .fields = value.fields },
        else => return error.InvalidProgram,
    };
    const source_index = try integer(try load(values, replacement.index));
    const offset = normalizedCollectionIndex(source_index, aggregate.fields.len) orelse {
        const message = try std.fmt.allocPrint(allocator, "collection index {d} is out of bounds for count {d}", .{ source_index, aggregate.fields.len });
        try Output.appendRuntimeError(session, program, replacement.position, "", message);
        session.terminated = true;
        return error.RuntimeTerminated;
    };
    if (source == .view) {
        aggregate.fields[offset] = try cloneValue(allocator, try load(values, replacement.replacement));
        try store(function, values, replacement.result, source);
        return;
    }
    const fields = try allocator.alloc(Value, aggregate.fields.len);
    for (aggregate.fields, 0..) |field, index| {
        fields[index] = try cloneValue(allocator, if (index == offset) try load(values, replacement.replacement) else field);
    }
    try store(function, values, replacement.result, .{ .structure = .{ .type = aggregate.type, .fields = fields } });
}

fn numericInteger(value: Value) Error!Numeric.Integer {
    return switch (value) {
        .integer => |result| .{ .type = .int, .bits = @bitCast(result) },
        .typed_integer => |result| result,
        else => error.InvalidProgram,
    };
}

fn negate(value: i64) Error!i64 {
    if (value == std.math.minInt(i64)) return error.IntegerOverflow;
    return -value;
}

fn negateValue(value: Value) Error!Value {
    const type_value = value.typeOf();
    if (type_value.isFloat()) return switch (value) {
        .float32 => |number| .{ .float32 = -number },
        .float64 => |number| .{ .float64 = -number },
        else => error.InvalidProgram,
    };
    const number = try numericInteger(value);
    if (!number.type.isSignedInteger()) {
        if (number.bits != 0) return error.IntegerOverflow;
        return .{ .typed_integer = number };
    }
    const signed = number.signed();
    if (signed == Numeric.integerMin(number.type)) return error.IntegerOverflow;
    const bits: u64 = @bitCast(-signed);
    return if (number.type == .int) .{ .integer = @bitCast(bits) } else .{
        .typed_integer = .{ .type = number.type, .bits = Numeric.normalize(bits, number.type) },
    };
}

fn calculate(operator: Ir.BinaryOperator, left: Value, right: Value, result_type: Ir.Type) Error!Value {
    if ((operator == .equal or operator == .not_equal) and !left.typeOf().isNumeric()) {
        const result = try equal(left, right);
        return .{ .boolean = if (operator == .equal) result else !result };
    }
    if (left.typeOf().isFloat()) return calculateFloat(operator, left, right, result_type);
    const left_integer = try numericInteger(left);
    const right_integer = try numericInteger(right);
    return switch (operator) {
        .add, .subtract, .multiply, .divide, .remainder => integerArithmetic(operator, left_integer, right_integer),
        .bit_and => integerResult(left_integer.type, left_integer.bits & right_integer.bits),
        .bit_xor => integerResult(left_integer.type, left_integer.bits ^ right_integer.bits),
        .shift_left, .shift_right => shiftInteger(operator, left_integer, right_integer),
        .less => .{ .boolean = integerLess(left_integer, right_integer) },
        .less_equal => .{ .boolean = !integerLess(right_integer, left_integer) },
        .greater => .{ .boolean = integerLess(right_integer, left_integer) },
        .greater_equal => .{ .boolean = !integerLess(left_integer, right_integer) },
        .equal => .{ .boolean = try equal(left, right) },
        .not_equal => .{ .boolean = !try equal(left, right) },
    };
}

fn integerArithmetic(operator: Ir.BinaryOperator, left: Numeric.Integer, right: Numeric.Integer) Error!Value {
    if (left.type != right.type) return error.InvalidProgram;
    if (left.type.isSignedInteger()) {
        const a: i128 = left.signed();
        const b: i128 = right.signed();
        if ((operator == .divide or operator == .remainder) and b == 0) return error.DivisionByZero;
        if ((operator == .divide or operator == .remainder) and
            a == Numeric.integerMin(left.type) and b == -1) return error.IntegerOverflow;
        const result: i128 = switch (operator) {
            .add => a + b,
            .subtract => a - b,
            .multiply => a * b,
            .divide => @divTrunc(a, b),
            .remainder => @rem(a, b),
            else => unreachable,
        };
        if (result < Numeric.integerMin(left.type) or result > Numeric.integerMax(left.type)) return error.IntegerOverflow;
        return integerResult(left.type, @bitCast(@as(i64, @intCast(result))));
    }

    const a: u128 = left.bits;
    const b: u128 = right.bits;
    if ((operator == .divide or operator == .remainder) and b == 0) return error.DivisionByZero;
    if (operator == .subtract and b > a) return error.IntegerOverflow;
    const result: u128 = switch (operator) {
        .add => a + b,
        .subtract => a - b,
        .multiply => a * b,
        .divide => a / b,
        .remainder => a % b,
        else => unreachable,
    };
    if (result > Numeric.integerMax(left.type)) return error.IntegerOverflow;
    return integerResult(left.type, @intCast(result));
}

fn integerResult(type_value: Ir.Type, bits: u64) Value {
    const normalized = Numeric.normalize(bits, type_value);
    return if (type_value == .int)
        .{ .integer = @bitCast(normalized) }
    else
        .{ .typed_integer = .{ .type = type_value, .bits = normalized } };
}

fn integerLess(left: Numeric.Integer, right: Numeric.Integer) bool {
    std.debug.assert(left.type == right.type);
    return if (left.type.isSignedInteger()) left.signed() < right.signed() else left.bits < right.bits;
}

fn shiftInteger(operator: Ir.BinaryOperator, left: Numeric.Integer, right: Numeric.Integer) Error!Value {
    const count: u64 = if (right.type.isSignedInteger()) count: {
        const signed = right.signed();
        if (signed < 0) return error.InvalidShift;
        break :count @intCast(signed);
    } else right.bits;
    if (count >= left.type.bitWidth()) return error.InvalidShift;
    const shifted = if (operator == .shift_left) left.bits << @intCast(count) else left.bits >> @intCast(count);
    return integerResult(left.type, shifted);
}

fn calculateFloat(operator: Ir.BinaryOperator, left: Value, right: Value, result_type: Ir.Type) Error!Value {
    if (left.typeOf() != right.typeOf()) return error.InvalidProgram;
    if (left.typeOf() == .float32) {
        const a = left.float32;
        const b = right.float32;
        return switch (operator) {
            .add => .{ .float32 = a + b },
            .subtract => .{ .float32 = a - b },
            .multiply => .{ .float32 = a * b },
            .divide => .{ .float32 = a / b },
            .less => .{ .boolean = a < b },
            .less_equal => .{ .boolean = a <= b },
            .greater => .{ .boolean = a > b },
            .greater_equal => .{ .boolean = a >= b },
            .equal => .{ .boolean = a == b },
            .not_equal => .{ .boolean = a != b },
            else => error.InvalidProgram,
        };
    }
    _ = result_type;
    const a = left.float64;
    const b = right.float64;
    return switch (operator) {
        .add => .{ .float64 = a + b },
        .subtract => .{ .float64 = a - b },
        .multiply => .{ .float64 = a * b },
        .divide => .{ .float64 = a / b },
        .less => .{ .boolean = a < b },
        .less_equal => .{ .boolean = a <= b },
        .greater => .{ .boolean = a > b },
        .greater_equal => .{ .boolean = a >= b },
        .equal => .{ .boolean = a == b },
        .not_equal => .{ .boolean = a != b },
        else => error.InvalidProgram,
    };
}

fn convert(value: Value, target: Ir.Type, checked: bool) Error!Value {
    const source = value.typeOf();
    if (source == target) return value;
    if (source.isInteger() and target.isInteger()) {
        const number = try numericInteger(value);
        if (target.isSignedInteger()) {
            const signed: i128 = if (source.isSignedInteger()) number.signed() else number.bits;
            if (signed < Numeric.integerMin(target) or signed > Numeric.integerMax(target)) return error.InvalidConversion;
            return integerResult(target, @bitCast(@as(i64, @intCast(signed))));
        }
        if (source.isSignedInteger() and number.signed() < 0) return error.InvalidConversion;
        if (number.bits > Numeric.integerMax(target)) return error.InvalidConversion;
        return integerResult(target, number.bits);
    }
    if (source.isInteger() and target.isFloat()) {
        const number = try numericInteger(value);
        if (target == .float32) {
            const result: f32 = if (source.isSignedInteger()) @floatFromInt(number.signed()) else @floatFromInt(number.bits);
            const exact: f64 = if (source.isSignedInteger()) @floatFromInt(number.signed()) else @floatFromInt(number.bits);
            if (checked and @as(f64, result) != exact) return error.InvalidConversion;
            return .{ .float32 = result };
        }
        const result: f64 = if (source.isSignedInteger()) @floatFromInt(number.signed()) else @floatFromInt(number.bits);
        if (source.isSignedInteger()) {
            if (checked and @as(i128, @intFromFloat(result)) != number.signed()) return error.InvalidConversion;
        } else if (checked and @as(u128, @intFromFloat(result)) != number.bits) return error.InvalidConversion;
        return .{ .float64 = result };
    }
    if (source == .float32 and target == .float64) return .{ .float64 = @floatCast(value.float32) };
    if (source == .float64 and target == .float32) {
        const result: f32 = @floatCast(value.float64);
        if (@as(f64, @floatCast(result)) != value.float64) return error.InvalidConversion;
        return .{ .float32 = result };
    }
    if (source.isFloat() and target.isInteger()) {
        const number: f64 = if (source == .float32) value.float32 else value.float64;
        if (!std.math.isFinite(number) or @trunc(number) != number) return error.InvalidConversion;
        if (target.isSignedInteger()) {
            const lower: f64 = @floatFromInt(Numeric.integerMin(target));
            const upper_exclusive: f64 = @floatFromInt(@as(i128, Numeric.integerMax(target)) + 1);
            if (number < lower or number >= upper_exclusive) return error.InvalidConversion;
            return integerResult(target, @bitCast(@as(i64, @intFromFloat(number))));
        }
        if (number < 0 or number >= @as(f64, @floatFromInt(@as(u128, Numeric.integerMax(target)) + 1))) return error.InvalidConversion;
        return integerResult(target, @intFromFloat(number));
    }
    return error.InvalidConversion;
}

fn boolean(value: Value) Error!bool {
    return switch (value) {
        .boolean => |result| result,
        else => error.InvalidProgram,
    };
}

fn string(value: Value) Error![]const u8 {
    return switch (value) {
        .string => |result| result,
        else => error.InvalidProgram,
    };
}

const equal = RuntimeValue.equal;

fn checkedAdd(left: i64, right: i64) Error!i64 {
    const result = @addWithOverflow(left, right);
    if (result[1] != 0) return error.IntegerOverflow;
    return result[0];
}

fn checkedSubtract(left: i64, right: i64) Error!i64 {
    const result = @subWithOverflow(left, right);
    if (result[1] != 0) return error.IntegerOverflow;
    return result[0];
}

fn checkedMultiply(left: i64, right: i64) Error!i64 {
    const result = @mulWithOverflow(left, right);
    if (result[1] != 0) return error.IntegerOverflow;
    return result[0];
}

fn checkedDivide(left: i64, right: i64) Error!i64 {
    if (right == 0) return error.DivisionByZero;
    if (left == std.math.minInt(i64) and right == -1) return error.IntegerOverflow;
    return @divTrunc(left, right);
}

fn checkedRemainder(left: i64, right: i64) Error!i64 {
    if (right == 0) return error.DivisionByZero;
    if (left == std.math.minInt(i64) and right == -1) return 0;
    return @rem(left, right);
}

fn compile(source: []const u8, allocator: Allocator) !Ir.Program {
    var frontend = @import("Frontend.zig").Frontend.init(allocator);
    return (try frontend.compile(source)).ir;
}

test "interpret answer as 42 and run main successfully" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func answer() int {
        \\    return 40 + 2
        \\}
        \\func main() {
        \\    answer()
        \\}
    , allocator);
    const answer = try invoke(allocator, program, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqual(@as(u8, 0), try run(allocator, program));
}

test "interpret parameters booleans nested calls and arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func combine(left:int, right:int) int {
        \\    return (left * 3 + right) / 2 % 10
        \\}
        \\func nested() int { return combine(combine(4, 2), -2) }
        \\func invert(value:int) int { return -value }
        \\func truth() bool { return true }
        \\func main() { nested(); truth() }
    , allocator);
    try std.testing.expectEqual(@as(i64, 7), (try invoke(allocator, program, 0, &.{ .{ .integer = 4 }, .{ .integer = 2 } })).integer);
    try std.testing.expectEqual(@as(i64, 9), (try invoke(allocator, program, 1, &.{})).integer);
    try std.testing.expectEqual(@as(i64, -7), (try invoke(allocator, program, 2, &.{.{ .integer = 7 }})).integer);
    try std.testing.expect((try invoke(allocator, program, 3, &.{})).boolean);
    try std.testing.expectEqual(@as(u8, 0), try run(allocator, program));
}

test "report checked arithmetic errors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const overflow = try compile(
        "func value() int { return 9223372036854775807 + 1 } func main() {}",
        allocator,
    );
    try std.testing.expectError(error.IntegerOverflow, invoke(allocator, overflow, 0, &.{}));

    const division = try compile("func value() int { return 1 / 0 } func main() {}", allocator);
    try std.testing.expectError(error.DivisionByZero, invoke(allocator, division, 0, &.{}));

    const negation = try compile(
        "func value() int { let minimum = -9223372036854775808; return -minimum } func main() {}",
        allocator,
    );
    try std.testing.expectError(error.IntegerOverflow, invoke(allocator, negation, 0, &.{}));
}

test "limit recursive call depth" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile("func recurse() int { return recurse() } func main() {}", allocator);
    try std.testing.expectError(error.CallStackOverflow, invoke(allocator, program, 0, &.{}));
}

test "reject inconsistent typed IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const blocks = [_]Ir.Block{.{ .instructions = &.{}, .terminator = .return_void }};
    const functions = [_]Ir.Function{.{
        .name = "value",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{},
        .blocks = &blocks,
    }};
    try std.testing.expectError(error.InvalidProgram, invoke(arena.allocator(), .{ .functions = &functions }, 0, &.{}));
}

test "execute UTF-8 strings through parameters returns and intrinsic values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func identity(value:str) str { return value }
        \\func empty() str { let value:str; return value }
        \\func main() {
        \\    print(identity("Silex\n\u{1f525}\0ok"))
        \\    print(empty())
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualSlices(u8, "Silex\n🔥\x00ok\n\n", result.stdout);
    try std.testing.expectEqualStrings("", result.stderr);
}

test "execute alternatives and short-circuit logical operands" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("Frontend.zig").Frontend.init(allocator);
    const program = (try frontend.compile(
        \\func observed() bool { print("evaluated"); return true }
        \\func main() {
        \\    if false && observed() { print("bad") }
        \\    elif true || observed() { print("selected") }
        \\    else { print("bad") }
        \\}
    )).ir;
    const result = try runCapture(allocator, program);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("selected\n", result.stdout);
    try std.testing.expectEqualStrings("", result.stderr);
}

test "execute integer families floats conversions and unsigned bit operations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("Frontend.zig").Frontend.init(allocator);
    const program = (try frontend.compile(
        \\func preserve(value:uint16) uint16 { return value }
        \\func half(value:float64) float64 { return value / 2.0 }
        \\func main() {
        \\    let minimum:int8 = -128
        \\    let maximum:uint = 18446744073709551615
        \\    let flags:uint8 = 0x81
        \\    let byte:uint8 = (255 as uint8) ^ (15 as uint8)
        \\    print(minimum)
        \\    print(maximum)
        \\    print(preserve(65535))
        \\    print(flags >> 7)
        \\    print(byte)
        \\    print(half(5.0))
        \\}
    )).ir;
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings(
        "-128\n18446744073709551615\n65535\n1\n240\n2.5\n",
        result.stdout,
    );
}

test "execute immutable UTF-8 string operations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("Frontend.zig").Frontend.init(allocator);
    const program = (try frontend.compile(
        \\func join(left:str, right:str) str { return left + right }
        \\func main() {
        \\    let greeting = join("Bonjour, ", "Silex")
        \\    print(greeting)
        \\    print(greeting == "Bonjour, Silex")
        \\    print("Aé🔥".count())
        \\    print("A\0B".count())
        \\}
    )).ir;
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("Bonjour, Silex\ntrue\n3\n3\n", result.stdout);
}

test "format IEEE floating special values deterministically" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("Frontend.zig").Frontend.init(allocator);
    const program = (try frontend.compile(
        \\func main() {
        \\    let zero:float64 = 0.0
        \\    print(-zero)
        \\    print(1.0 / zero)
        \\    print(-1.0 / zero)
        \\    print(zero / zero)
        \\}
    )).ir;
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("-0.0\ninf\n-inf\nnan\n", result.stdout);
}

test "interpolate values and print multiple arguments without separators" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func observed(value:int) int { print("observed"); return value }
        \\func main() {
        \\    let value = 21
        \\    let message = "Value: $(value * 2), $(true), $(1.5), $value, ${value}, $$(value)"
        \\    print("Before ", observed(value), ": ", message)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualSlices(
        u8,
        "observed\nBefore 21: Value: 42, true, 1.5, $value, ${value}, $(value)\n",
        result.stdout,
    );
}

test "print reference values once and in source order" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func square(value:int) int { return value * value }
        \\func main() {
        \\    print("answer")
        \\    print(square(5))
        \\    print(true)
        \\    print(false)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("answer\n25\ntrue\nfalse\n", result.stdout);
}

test "execute mutable locals and evaluate assignments once" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func observed() int { print("observed"); return 42 }
        \\func main() {
        \\    var signed:int8
        \\    var unsigned:uint64
        \\    var decimal:float64
        \\    var enabled:bool
        \\    var message:str
        \\    signed = -8
        \\    unsigned = 18446744073709551615
        \\    decimal = 2.5
        \\    enabled = true
        \\    message = "Value: $(observed())"
        \\    print(signed, " ", unsigned, " ", decimal, " ", enabled, " ", message)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("observed\n-8 18446744073709551615 2.5 true Value: 42\n", result.stdout);
}

test "execute structure defaults nested aggregates and chained reads" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\struct Position {
        \\    var x:int
        \\    let layer:int = 7
        \\}
        \\struct Entity {
        \\    var position:Position = Position(x:5)
        \\    var name:str
        \\}
        \\func main() {
        \\    let empty = Entity()
        \\    let configured = Entity(name:"Ada", position:Position(x:42,),)
        \\    print(empty.position.x, " ", empty.position.layer, " ", empty.name)
        \\    print(configured.name, " ", configured.position.x, " ", configured.position.layer)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("5 7 \nAda 42 7\n", result.stdout);
}

test "transport and recursively compare structure values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\struct Point { var x:int; var label:str }
        \\struct Pair { var first:Point; var second:Point }
        \\func identity(value:Pair) Pair { return value }
        \\func nested(value:Pair) Pair { return identity(identity(value)) }
        \\func main() {
        \\    var original = Pair(first:Point(x:1, label:"A\0B"), second:Point(x:2, label:"C"))
        \\    let copied = nested(original)
        \\    original = Pair()
        \\    print(copied == Pair(first:Point(x:1, label:"A\0B"), second:Point(x:2, label:"C")))
        \\    print(original != copied)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("true\ntrue\n", result.stdout);
}

test "mutate nested fields once while preserving independent copies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\struct Score { var value:int; var label:str }
        \\struct Player { var score:Score; var reserve:int }
        \\func observed() int { print("observed"); return 2 }
        \\func main() {
        \\    var player = Player(score:Score(value:10, label:"A"), reserve:7)
        \\    let duplicate = player
        \\    player.score.value += observed()
        \\    player.score.value *= 3
        \\    player.score.value -= 6
        \\    player.score.value /= 3
        \\    player.score.value++
        \\    player.score.value--
        \\    player.score.label = "B"
        \\    print(player.score.value, " ", player.score.label, " ", player.reserve)
        \\    print(duplicate.score.value, " ", duplicate.score.label, " ", duplicate.reserve)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("observed\n10 B 7\n10 A 7\n", result.stdout);
}

test "execute overloaded value constructors and implicit self return" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\struct Position {
        \\    let x:int
        \\    let y:int
        \\    var label:str = "point"
        \\    init(x:int, y:int) { self.x = x; self.y = y }
        \\    init(enabled:bool) {
        \\        if enabled { self.x = 20 } else { self.x = 0 }
        \\        self.y = 22
        \\    }
        \\}
        \\func main() {
        \\    let first = Position(10, 5)
        \\    let second = Position(true)
        \\    print(first.x, " ", first.y, " ", first.label)
        \\    print(second.x + second.y)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("10 5 point\n42\n", result.stdout);
}

test "execute mutating nonmutating overloaded and chained methods" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\struct Counter {
        \\    var value:int
        \\    func increment() { self.value++ }
        \\    func forward() { self.increment() }
        \\    func add(amount:int) int { self.value += amount; return self.value }
        \\    func choose(amount:int) { self.value += amount }
        \\    func choose(enabled:bool) { if enabled { self.increment() } }
        \\    func current() int { return self.value }
        \\    func duplicate() Counter { return self }
        \\}
        \\func observed() int { print("observed"); return 2 }
        \\func make() Counter { print("make"); return Counter(value:40) }
        \\func main() {
        \\    var counter = Counter(value:1)
        \\    counter.forward()
        \\    let returned = counter.add(observed())
        \\    counter.choose(true)
        \\    counter.choose(3)
        \\    let immutable = counter
        \\    print(returned, " ", counter.current(), " ", immutable.duplicate().current())
        \\    print(make().current())
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("observed\n4 8 8\nmake\n40\n", result.stdout);
}

test "evaluate function constructor and method defaults at each omitted argument" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func observed() int { print("default"); return 2 }
        \\func selected(value:int = observed()) int { return value }
        \\struct Box {
        \\    var value:int
        \\    init(value:int = 40) { self.value = value }
        \\    func plus(value:int = 2) int { return self.value + value }
        \\    func bump(value:int = 1) { self.value += value }
        \\    func forward() { self.bump() }
        \\}
        \\func main() {
        \\    let box = Box()
        \\    print(box.plus())
        \\    print(selected(), " ", selected(), " ", selected(42))
        \\    var mutable = Box(40)
        \\    mutable.forward()
        \\    print(mutable.value)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("42\ndefault\ndefault\n2 2 42\n41\n", result.stdout);
}

test "execute while with zero iterations nested break and continue" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func main() {
        \\    var untouched = 7
        \\    while false { untouched = 0 }
        \\    var outer = 0
        \\    var score = 0
        \\    while outer < 3 {
        \\        outer = outer + 1
        \\        var inner = 0
        \\        while inner < 4 {
        \\            inner = inner + 1
        \\            if inner == 2 { continue }
        \\            if inner == 4 { break }
        \\            score = score + 1
        \\        }
        \\    }
        \\    print(untouched, " ", outer, " ", score)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("7 3 6\n", result.stdout);
}

test "execute compound assignments once across numeric families" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func observed() int8 { print("observed"); return 2 }
        \\func main() {
        \\    var signed:int8 = 10
        \\    signed += observed()
        \\    signed *= 3
        \\    signed -= 6
        \\    signed /= 3
        \\    signed++
        \\    signed--
        \\    var unsigned:uint16 = 40
        \\    unsigned++
        \\    unsigned -= 1
        \\    var decimal:float64 = 1.5
        \\    decimal += 0.5
        \\    decimal *= 4.0
        \\    decimal -= 2.0
        \\    decimal /= 3.0
        \\    print(signed, " ", unsigned, " ", decimal)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("observed\n10 40 2.0\n", result.stdout);
}

test "compound assignments preserve checked arithmetic failures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const overflow = try compile(
        "func value() int { var result = 9223372036854775807; result++; return result } func main() {}",
        allocator,
    );
    try std.testing.expectError(error.IntegerOverflow, invoke(allocator, overflow, 0, &.{}));

    const division = try compile(
        "func value() int { var result = 1; result /= 0; return result } func main() {}",
        allocator,
    );
    try std.testing.expectError(error.DivisionByZero, invoke(allocator, division, 0, &.{}));
}

test "print evaluates a nested effectful call exactly once" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func observed() int {
        \\    print("inside")
        \\    return 42
        \\}
        \\func main() { print(observed()) }
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("inside\n42\n", result.stdout);
}

test "compare fundamental values with defined precedence" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const program = try compile(
        \\func main() {
        \\    print(1 + 2 * 3 < 8 == true)
        \\    print(4 <= 4)
        \\    print(5 > 9)
        \\    print(false != true)
        \\}
    , allocator);
    const result = try runCapture(allocator, program);
    try std.testing.expectEqualStrings("true\ntrue\nfalse\ntrue\n", result.stdout);
}

test "assert and panic return structured runtime output" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var assertion = try compile(
        \\func main() {
        \\    print("before")
        \\    assert(false, "planned failure")
        \\    print("after")
        \\}
    , allocator);
    assertion.files = &.{"Sandbox/Main.sx"};
    const failed = try runCapture(allocator, assertion);
    try std.testing.expectEqual(@as(u8, 1), failed.exit_code);
    try std.testing.expectEqualStrings("before\n", failed.stdout);
    try std.testing.expectEqualStrings(
        "Sandbox/Main.sx:3:5: runtime error: assertion failed: planned failure\n",
        failed.stderr,
    );

    var panic_program = try compile("func value() int { panic(\"literal panic\") } func main() { value() }", allocator);
    panic_program.files = &.{"Main.sx"};
    const panicked = try runCapture(allocator, panic_program);
    try std.testing.expectEqual(@as(u8, 1), panicked.exit_code);
    try std.testing.expectEqualStrings("Main.sx:1:20: runtime error: literal panic\n", panicked.stderr);
}
