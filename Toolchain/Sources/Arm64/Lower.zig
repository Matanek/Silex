const std = @import("std");
const Boundary = @import("../Boundary.zig");
const Ir = @import("../Ir.zig");
const CompilationCache = @import("../CompilationCache.zig");
const MainBoundary = @import("../MainBoundary.zig");
const Machine = @import("Machine.zig");
const RegisterAllocation = @import("RegisterAllocation.zig");
const Slp = @import("../Optimize/Slp.zig");
const StackLayout = @import("StackLayout.zig");
const TypeLayout = @import("TypeLayout.zig");

const Allocator = std.mem.Allocator;

const Layout = StackLayout.Layout;
const enumByType = TypeLayout.enumByType;
const irConforms = TypeLayout.irConforms;
const isAggregate = TypeLayout.isAggregate;
const leafCount = TypeLayout.leafCount;

pub fn lower(allocator: Allocator, program: Ir.Program) Machine.Error!Machine.Program {
    return lowerWithMode(allocator, program, .debug);
}

pub fn lowerBoundaries(allocator: Allocator, program: Ir.Program, boundaries: []const Boundary.Function) Machine.Error!Machine.Program {
    return lowerWithModeAndBoundaries(allocator, program, boundaries, .debug);
}

pub const Mode = enum { debug, release };

pub fn lowerWithMode(allocator: Allocator, program: Ir.Program, mode: Mode) Machine.Error!Machine.Program {
    return lowerInternal(allocator, null, program, &.{}, mode);
}

pub fn lowerCached(allocator: Allocator, io: std.Io, program: Ir.Program, mode: Mode) Machine.Error!Machine.Program {
    return lowerInternal(allocator, io, program, &.{}, mode);
}

pub fn lowerWithModeAndBoundaries(
    allocator: Allocator,
    program: Ir.Program,
    boundaries: []const Boundary.Function,
    mode: Mode,
) Machine.Error!Machine.Program {
    return lowerInternal(allocator, null, program, boundaries, mode);
}

pub fn lowerCachedWithBoundaries(
    allocator: Allocator,
    io: std.Io,
    program: Ir.Program,
    boundaries: []const Boundary.Function,
    mode: Mode,
) Machine.Error!Machine.Program {
    return lowerInternal(allocator, io, program, boundaries, mode);
}

fn lowerInternal(
    allocator: Allocator,
    io: ?std.Io,
    program: Ir.Program,
    boundaries: []const Boundary.Function,
    mode: Mode,
) Machine.Error!Machine.Program {
    var functions: std.ArrayList(Machine.Function) = .empty;
    var strings: std.ArrayList([]const u8) = .empty;
    try strings.append(allocator, "\n");
    try strings.append(allocator, "true");
    try strings.append(allocator, "false");
    try strings.append(allocator, "error: ");
    for (program.functions) |function| {
        var lowered = cached: {
            if (io) |cache_io| if (cacheSafe(function)) {
                const encoded = std.json.Stringify.valueAlloc(allocator, function, .{}) catch break :cached try lowerFunction(allocator, program, &strings, function);
                const digest = CompilationCache.artifactKey(@tagName(mode), &.{encoded});
                if (CompilationCache.load(allocator, cache_io, digest, "machine-function")) |payload| {
                    if (std.json.parseFromSliceLeaky(Machine.Function, allocator, payload, .{})) |value| {
                        break :cached value;
                    } else |_| {}
                }
                var value = try lowerFunction(allocator, program, &strings, function);
                if (mode == .release) value = try allocateRegisters(allocator, value);
                const payload = std.json.Stringify.valueAlloc(allocator, value, .{}) catch break :cached value;
                CompilationCache.store(allocator, cache_io, digest, "machine-function", payload);
                break :cached value;
            };
            var value = try lowerFunction(allocator, program, &strings, function);
            if (mode == .release) value = try allocateRegisters(allocator, value);
            break :cached value;
        };
        if (mode == .release and lowered.register_slots.len == 0) lowered = try allocateRegisters(allocator, lowered);
        try functions.append(allocator, lowered);
    }
    const has_mutex = programUsesMutex(program);
    const globals = try allocator.alloc(Machine.Global, program.globals.len + @intFromBool(has_mutex));
    for (program.globals, 0..) |global, index| globals[index] = .{
        .bits = global.bits,
        .extra_bits = global.extra_bits,
        .width = @intCast(try leafCount(program, global.type)),
    };
    if (has_mutex) globals[program.globals.len] = .{ .bits = 0, .width = 8 };
    const external_functions = try allocator.alloc(Machine.ExternalFunction, boundaries.len + if (has_mutex) @as(usize, 2) else 0);
    for (boundaries, 0..) |external, index| {
        const arguments = try allocator.alloc(Machine.AbiValue, external.parameters.len);
        for (external.parameters, 0..) |parameter, parameter_index| arguments[parameter_index] = try lowerExternalType(parameter);
        external_functions[index] = .{
            .provider = if (std.mem.eql(u8, external.provider, "MacOS.lib_system")) "Darwin.lib_system" else external.provider,
            .source_name = external.source_name,
            .package_private = external.package_private,
            .signature = .{
                .arguments = arguments,
                .result = if (external.return_type == .void) null else try lowerExternalType(external.return_type),
            },
        };
    }
    if (has_mutex) {
        external_functions[boundaries.len] = .{
            .provider = "Darwin.lib_system",
            .source_name = "os_unfair_recursive_lock_lock_with_options",
            .signature = .{ .arguments = &.{ .read_address, .uint64 }, .result = null },
        };
        external_functions[boundaries.len + 1] = .{
            .provider = "Darwin.lib_system",
            .source_name = "os_unfair_recursive_lock_unlock",
            .signature = .{ .arguments = &.{.read_address}, .result = null },
        };
    }
    const result: Machine.Program = .{
        .functions = try functions.toOwnedSlice(allocator),
        .files = program.files,
        .debug = mode == .debug,
        .external_functions = external_functions,
        .globals = globals,
        .strings = try strings.toOwnedSlice(allocator),
        .copy_model = try buildCopyModel(allocator, program),
        .mutex_global = if (has_mutex) program.globals.len else null,
        .mutex_lock_function = if (has_mutex) boundaries.len else null,
        .mutex_unlock_function = if (has_mutex) boundaries.len + 1 else null,
    };
    try Machine.validate(result);
    return result;
}

fn programUsesMutex(program: Ir.Program) bool {
    for (program.functions) |function| for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .mutex_lock, .mutex_unlock => return true,
        else => {},
    };
    return false;
}

fn lowerExternalType(type_value: Ir.Type) Machine.Error!Machine.AbiValue {
    return switch (type_value) {
        .uint8 => .uint8,
        .int32, .uint32 => .int32,
        .address => .read_address,
        .uint => .uint64,
        .int => .int64,
        .float32 => .float32,
        .float64 => .float64,
        else => error.UnsupportedType,
    };
}

fn allocateRegisters(allocator: Allocator, function: Machine.Function) Machine.Error!Machine.Function {
    var result = function;
    const allocation = try RegisterAllocation.allocate(allocator, result);
    result.register_slots = allocation.residences;
    result.float_register_slots = allocation.float_residences;
    result.float_lane_slots = allocation.float_lane_residences;
    result.frame_size = allocation.frame_size;
    return result;
}

fn cacheSafe(function: Ir.Function) bool {
    if (!scalarType(function.return_type)) return false;
    for (function.parameter_types) |type_value| if (!scalarType(type_value)) return false;
    for (function.value_types) |type_value| if (!scalarType(type_value)) return false;
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_float32,
        .constant_float64,
        .copy,
        .local_load,
        .local_store,
        .unary,
        .binary,
        .call,
        => {},
        else => return false,
    };
    return true;
}

fn scalarType(type_value: Ir.Type) bool {
    return type_value == .void or type_value == .bool or type_value.isInteger() or type_value.isFloat();
}

fn lowerFunction(
    allocator: Allocator,
    program: Ir.Program,
    strings: *std.ArrayList([]const u8),
    function: Ir.Function,
) Machine.Error!Machine.Function {
    const parameter_count = try Machine.checkedArgumentCount(function.parameter_types.len);
    const layout = try StackLayout.build(allocator, program, function);
    const slp = try Slp.analyze(allocator, function);
    const float_lane_groups = try lowerSlpGroups(allocator, layout, slp);

    var instructions: std.ArrayList(Machine.Instruction) = .empty;
    var instruction_positions: std.ArrayList(?@import("../Source.zig").Position) = .empty;
    const starts = try allocator.alloc(usize, function.blocks.len);
    var next_instruction: usize = 0;
    for (function.blocks, 0..) |block, block_id| {
        starts[block_id] = next_instruction;
        next_instruction += block.instructions.len + 1;
    }
    for (function.blocks) |block| {
        for (block.instructions, 0..) |instruction, instruction_index| {
            try instructions.append(allocator, try lowerInstruction(allocator, program, strings, function, layout, instruction));
            try instruction_positions.append(allocator, if (instruction_index < block.instruction_positions.len) block.instruction_positions[instruction_index] else function.source_position);
        }
        try instructions.append(allocator, try lowerTerminator(allocator, program, strings, layout, block.terminator, starts));
        try instruction_positions.append(allocator, block.terminator_position orelse function.source_position);
    }
    return .{
        .name = function.name,
        .source_position = function.source_position,
        .parameter_count = parameter_count,
        .parameters = layout.parameters,
        .capture_parameters = layout.capture_parameters,
        .return_type = function.return_type,
        .return_width = layout.return_width,
        .return_aggregate = layout.return_aggregate,
        .recoverable_entry_result = MainBoundary.accepts(program.enums, function.return_type),
        .hidden_return_slot = layout.hidden_return_slot,
        .slot_count = layout.slot_count,
        .frame_size = try Machine.frameSize(layout.slot_count),
        .reuses_slots = layout.reuses_slots,
        .float_lane_groups = float_lane_groups,
        .instructions = try instructions.toOwnedSlice(allocator),
        .instruction_positions = try instruction_positions.toOwnedSlice(allocator),
    };
}

fn lowerSlpGroups(allocator: Allocator, layout: Layout, plan: Slp.Plan) Allocator.Error![]const Machine.FloatLaneGroup {
    const groups = try allocator.alloc(Machine.FloatLaneGroup, plan.groups.len);
    var count: usize = 0;
    for (plan.groups) |group| {
        var slots: [4]Machine.Slot = undefined;
        var valid = true;
        for (0..group.width) |lane| {
            const span = switch (group.lanes[lane]) {
                .value => |value| layout.values[value],
                .local => |local| layout.locals[local],
            };
            if (span.width != 1 or span.aggregate) {
                valid = false;
                break;
            }
            slots[lane] = span.start;
        }
        if (!valid) continue;
        groups[count] = .{
            .slots = slots,
            .width = group.width,
            .priority = group.priority,
            .recurrence = group.recurrence,
            .in_loop = group.in_loop,
        };
        count += 1;
    }
    std.mem.sort(Machine.FloatLaneGroup, groups[0..count], {}, struct {
        fn before(_: void, left: Machine.FloatLaneGroup, right: Machine.FloatLaneGroup) bool {
            return left.priority > right.priority;
        }
    }.before);
    return groups[0..count];
}

fn lowerInstruction(
    allocator: Allocator,
    program: Ir.Program,
    strings: *std.ArrayList([]const u8),
    function: Ir.Function,
    layout: Layout,
    instruction: Ir.Instruction,
) Machine.Error!Machine.Instruction {
    return switch (instruction) {
        .constant_int => |constant| .{ .constant_int = .{
            .result = layout.values[constant.result].start,
            .bits = constant.bits,
            .type = function.value_types[constant.result],
        } },
        .constant_bool => |constant| .{ .constant_bool = .{
            .result = layout.values[constant.result].start,
            .value = constant.value,
        } },
        .constant_str => |constant| .{ .constant_str = .{
            .result = layout.values[constant.result].start,
            .string = try internString(allocator, strings, constant.value),
        } },
        .constant_bytes => |constant| .{ .constant_bytes = .{
            .result = layout.values[constant.result].start,
            .string = try internString(allocator, strings, constant.value),
        } },
        .constant_float32 => |constant| .{ .constant_float32 = .{
            .result = layout.values[constant.result].start,
            .bits = constant.bits,
        } },
        .constant_float64 => |constant| .{ .constant_float64 = .{
            .result = layout.values[constant.result].start,
            .bits = constant.bits,
        } },
        .function_reference => |reference| closure: {
            const captures = try allocator.alloc(Machine.Slot, reference.captures.len);
            for (reference.captures, 0..) |capture, index| captures[index] = layout.values[capture].start;
            break :closure .{ .function_address = .{
                .result = layout.values[reference.result],
                .function = reference.function,
                .captures = captures,
                .environment = layout.environments[reference.result],
            } };
        },
        .optional_null => |optional| .{ .optional_null = .{ .result = layout.values[optional.result] } },
        .optional_some => |optional| .{ .optional_some = .{
            .result = layout.values[optional.result],
            .operand = layout.values[optional.operand],
        } },
        .optional_unwrap => |optional| unwrap: {
            var operand = layout.values[optional.operand];
            operand.start += 1;
            operand.width -= 1;
            operand.aggregate = layout.values[optional.result].aggregate;
            break :unwrap .{ .optional_unwrap = .{
                .result = layout.values[optional.result],
                .operand = operand,
            } };
        },
        .copy => |copy| lowerCopy(layout.values[copy.result], layout.values[copy.operand]),
        .deep_copy => |copy| if (try requiresDeepCopy(program, function.value_types[copy.result]))
            .{ .deep_copy = .{
                .result = layout.values[copy.result],
                .operand = layout.values[copy.operand],
                .type = function.value_types[copy.result],
            } }
        else
            lowerCopy(layout.values[copy.result], layout.values[copy.operand]),
        .class_cast => |cast| lowerCopy(layout.values[cast.result], layout.values[cast.operand]),
        .class_retain => |retain| .{ .class_retain = .{ .operand = layout.values[retain.operand].start, .ownership = retain.ownership } },
        .list_retain => |retain| .{ .list_retain = .{ .operand = layout.values[retain.operand].start, .ownership = retain.ownership } },
        .string_retain => |retain| .{ .string_retain = .{ .operand = layout.values[retain.operand].start, .ownership = retain.ownership } },
        .string_drop => |drop| .{ .string_drop = .{ .operand = layout.values[drop.operand].start, .ownership = drop.ownership } },
        .list_drop => |drop| .{ .list_drop = .{
            .operand = layout.values[drop.operand].start,
            .ownership = drop.ownership,
            .deallocate = drop.deallocate,
        } },
        .class_drop => |drop| finalize: {
            const plans = try allocator.alloc(Machine.Instruction.ClassDrop.Plan, drop.plans.len);
            for (drop.plans, 0..) |plan, plan_index| {
                const functions = try allocator.alloc(usize, plan.functions.len);
                for (plan.functions, 0..) |finalizer, index| functions[index] = finalizer.function;
                plans[plan_index] = .{
                    .structure = plan.structure,
                    .byte_count = (try leafCount(program, .structure(plan.structure)) + 4) * Machine.slot_size,
                    .functions = functions,
                };
            }
            break :finalize .{ .class_drop = .{
                .operand = layout.values[drop.operand].start,
                .ownership = drop.ownership,
                .skip_cycle = drop.skip_cycle,
                .static_type = drop.static_type,
                .plans = plans,
            } };
        },
        .global_load => |load| .{ .global_load = .{ .result = layout.values[load.result], .global = load.global } },
        .global_store => |store| .{ .global_store = .{ .operand = layout.values[store.operand], .global = store.global } },
        .storage_init => |initialization| .{ .storage_init = layout.values[initialization.result] },
        .structure_init => |initialization| aggregate: {
            const fields = try allocator.alloc(Machine.Span, initialization.fields.len);
            for (initialization.fields, 0..) |field, index| fields[index] = layout.values[field];
            if (program.structures[initialization.structure].is_class) break :aggregate .{ .class_init = .{
                .result = layout.values[initialization.result].start,
                .structure = initialization.structure,
                .fields = fields,
            } };
            break :aggregate .{ .aggregate_init = .{
                .result = layout.values[initialization.result],
                .fields = fields,
            } };
        },
        .protocol_init => |initialization| .{ .protocol_init = .{
            .result = layout.values[initialization.result],
            .operand = layout.values[initialization.operand],
            .structure = initialization.structure,
            .class_operand = program.structures[initialization.structure].is_class,
        } },
        .protocol_test => |test_value| .{ .protocol_test = .{
            .result = layout.values[test_value.result].start,
            .operand = layout.values[test_value.operand].start,
            .structure = test_value.structure,
        } },
        .protocol_extract => |extraction| .{ .protocol_extract = .{
            .result = layout.values[extraction.result],
            .operand = layout.values[extraction.operand],
        } },
        .list_init => |initialization| list: {
            const values = try allocator.alloc(Machine.Span, initialization.values.len);
            for (initialization.values, 0..) |value, index| values[index] = layout.values[value];
            const collection = collectionForType(program, function.value_types[initialization.result]) orelse return error.InvalidMachineProgram;
            const element_width: u12 = @intCast(try leafCount(program, collection.element));
            break :list .{ .list_init = .{
                .result = layout.values[initialization.result].start,
                .values = values,
                .element_width = element_width,
                .element_stride = try collectionElementStride(program, collection.element, element_width),
            } };
        },
        .enum_init => |initialization| enumeration: {
            const values = try allocator.alloc(Machine.Span, initialization.values.len);
            for (initialization.values, 0..) |value, index| values[index] = layout.values[value];
            break :enumeration .{ .enum_init = .{
                .result = layout.values[initialization.result],
                .tag = initialization.variant,
                .values = values,
                .raw_value = if (program.enums[initialization.enumeration].variants[initialization.variant].raw_value) |raw_value| switch (raw_value) {
                    .integer => |value| .{ .integer = @bitCast(value) },
                    .string => |value| .{ .string = try internString(allocator, strings, value) },
                } else null,
            } };
        },
        .enum_test => |test_value| .{ .enum_test = .{
            .result = layout.values[test_value.result].start,
            .operand = layout.values[test_value.operand],
            .tag = test_value.variant,
        } },
        .collection_load => |access| collection_load: {
            const collection = collectionForType(program, function.value_types[access.collection]) orelse return error.InvalidMachineProgram;
            const count: u32 = @intCast(collection.length orelse 0);
            break :collection_load .{ .collection_load = .{
                .result = layout.values[access.result],
                .collection = layout.values[access.collection],
                .index = layout.values[access.index].start,
                .count = count,
                .dynamic = collection.length == null,
                .view = collection.view,
                .checked = access.checked,
                .element_stride = try collectionElementStride(
                    program,
                    collection.element,
                    @intCast(try leafCount(program, collection.element)),
                ),
                .header = try internString(allocator, strings, try collectionRuntimeHeader(allocator, program, access.position)),
                .tail = try internString(allocator, strings, if (collection.length == null) " is out of bounds for count " else try std.fmt.allocPrint(allocator, " is out of bounds for count {d}\n", .{count})),
            } };
        },
        .collection_reference => |access| collection_reference: {
            const collection = collectionForType(program, function.value_types[access.collection]) orelse return error.InvalidMachineProgram;
            const element_width: u12 = @intCast(try leafCount(program, collection.element));
            break :collection_reference .{ .collection_reference = .{
                .result = layout.values[access.result].start,
                .collection = layout.values[access.collection],
                .reference = if (access.reference) |reference| layout.values[reference].start else null,
                .index = layout.values[access.index].start,
                .element_width = element_width,
                .element_stride = try collectionElementStride(program, collection.element, element_width),
                .ownership = access.ownership,
                .count = @intCast(collection.length orelse 0),
                .dynamic = collection.length == null,
                .view = collection.view,
                .header = try internString(allocator, strings, try collectionRuntimeHeader(allocator, program, access.position)),
                .tail = try internString(allocator, strings, if (collection.length == null) " is out of bounds for count " else try std.fmt.allocPrint(allocator, " is out of bounds for count {d}\n", .{collection.length.?})),
            } };
        },
        .collection_replace => |replacement| collection_replace: {
            const collection = collectionForType(program, function.value_types[replacement.collection]) orelse return error.InvalidMachineProgram;
            const count: u32 = @intCast(collection.length orelse 0);
            break :collection_replace .{ .collection_replace = .{
                .result = layout.values[replacement.result],
                .collection = layout.values[replacement.collection],
                .index = layout.values[replacement.index].start,
                .replacement = layout.values[replacement.replacement],
                .ownership = replacement.ownership,
                .count = count,
                .dynamic = collection.length == null,
                .view = collection.view,
                .element_stride = try collectionElementStride(
                    program,
                    collection.element,
                    @intCast(try leafCount(program, collection.element)),
                ),
                .header = try internString(allocator, strings, try collectionRuntimeHeader(allocator, program, replacement.position)),
                .tail = try internString(allocator, strings, if (collection.length == null) " is out of bounds for count " else try std.fmt.allocPrint(allocator, " is out of bounds for count {d}\n", .{count})),
            } };
        },
        .collection_count => |count| .{ .collection_count = .{
            .result = layout.values[count.result].start,
            .collection = layout.values[count.collection],
            .view = collectionForType(program, function.value_types[count.collection]).?.view,
        } },
        .list_edit => |edit| edit_value: {
            const collection = collectionForType(program, function.value_types[edit.collection]) orelse return error.InvalidMachineProgram;
            const argument_collection = if (edit.argument) |argument| collectionForType(program, function.value_types[argument]) else null;
            break :edit_value .{ .list_edit = .{
                .result = layout.values[edit.result].start,
                .collection = layout.values[edit.collection].start,
                .ownership = edit.ownership,
                .kind = edit.kind,
                .index = if (edit.index) |index| layout.values[index].start else null,
                .argument = if (edit.argument) |argument| layout.values[argument] else null,
                .argument_dynamic = if (argument_collection) |argument| argument.length == null else false,
                .argument_transferred = edit.argument_transferred,
                .argument_count = if (argument_collection) |argument| @intCast(argument.length orelse 0) else 0,
                .removed = if (edit.removed) |removed| layout.values[removed] else null,
                .element_width = @intCast(try leafCount(program, collection.element)),
                .element_stride = try collectionElementStride(
                    program,
                    collection.element,
                    @intCast(try leafCount(program, collection.element)),
                ),
                .header = try internString(allocator, strings, try collectionRuntimeHeader(allocator, program, edit.position)),
                .tail = try internString(allocator, strings, " is out of bounds for count "),
            } };
        },
        .collection_slice => |slice| slice_value: {
            const collection = collectionForType(program, function.value_types[slice.collection]) orelse return error.InvalidMachineProgram;
            break :slice_value .{ .collection_slice = .{
                .result = layout.values[slice.result].start,
                .collection = layout.values[slice.collection],
                .start = layout.values[slice.start].start,
                .end = layout.values[slice.end].start,
                .count = @intCast(collection.length orelse 0),
                .dynamic = collection.length == null,
                .view = collection.view,
                .element_width = @intCast(try leafCount(program, collection.element)),
                .element_stride = try collectionElementStride(
                    program,
                    collection.element,
                    @intCast(try leafCount(program, collection.element)),
                ),
            } };
        },
        .collection_view => |view| view_value: {
            const source = collectionForType(program, function.value_types[view.collection]) orelse return error.InvalidMachineProgram;
            break :view_value .{ .collection_view = .{
                .result = layout.values[view.result],
                .collection = layout.values[view.collection],
                .reference = if (view.reference) |reference| layout.values[reference].start else null,
                .start = layout.values[view.start].start,
                .end = layout.values[view.end].start,
                .count = @intCast(source.length orelse 0),
                .dynamic = source.length == null,
                .source_view = source.view,
                .element_width = @intCast(try leafCount(program, source.element)),
                .element_stride = try collectionElementStride(
                    program,
                    source.element,
                    @intCast(try leafCount(program, source.element)),
                ),
            } };
        },
        .string_address => |address| .{ .reference_offset = .{
            .result = layout.values[address.result].start,
            .reference = layout.values[address.operand].start,
            .byte_offset = 8,
        } },
        .string_byte_count => |count| .{ .string_byte_count = .{
            .result = layout.values[count.result].start,
            .operand = layout.values[count.operand].start,
        } },
        .string_byte_at => |access| .{ .string_byte_at = .{
            .result = layout.values[access.result].start,
            .operand = layout.values[access.operand].start,
            .index = layout.values[access.index].start,
        } },
        .string_from_bytes => |conversion| .{ .string_from_bytes = .{
            .result = layout.values[conversion.result].start,
            .bytes = layout.values[conversion.bytes],
        } },
        .enum_payload => |payload| enum_payload: {
            if (payload.enumeration >= program.enums.len) return error.InvalidMachineProgram;
            const enumeration = program.enums[payload.enumeration];
            if (payload.variant >= enumeration.variants.len) return error.InvalidMachineProgram;
            const variant = enumeration.variants[payload.variant];
            if (payload.index >= variant.associated_types.len) return error.InvalidMachineProgram;
            var offset: usize = 1;
            for (variant.associated_types[0..payload.index]) |associated_type| offset += try leafCount(program, associated_type);
            var operand = layout.values[payload.operand];
            operand.start = try Machine.checkedSlot(@as(usize, operand.start) + offset);
            operand.width = layout.values[payload.result].width;
            operand.aggregate = layout.values[payload.result].aggregate;
            break :enum_payload lowerCopy(layout.values[payload.result], operand);
        },
        .enum_raw => |raw| enum_raw: {
            if (raw.enumeration >= program.enums.len or program.enums[raw.enumeration].raw_type == null) return error.InvalidMachineProgram;
            var operand = layout.values[raw.operand];
            operand.start = try Machine.checkedSlot(@as(usize, operand.start) + 1);
            operand.width = 1;
            operand.aggregate = false;
            break :enum_raw lowerCopy(layout.values[raw.result], operand);
        },
        .field_load => |load| field: {
            const base_type = function.value_types[load.base];
            const structure_index = base_type.structureIndex() orelse return error.InvalidMachineProgram;
            const offset = try fieldOffset(program, structure_index, load.field);
            if (program.structures[structure_index].is_class) break :field .{ .class_load = .{
                .result = layout.values[load.result],
                .base = layout.values[load.base].start,
                .byte_offset = @intCast(offset * Machine.slot_size),
            } };
            var operand = layout.values[load.base];
            operand.start = try Machine.checkedSlot(@as(usize, operand.start) + offset);
            operand.width = layout.values[load.result].width;
            operand.aggregate = layout.values[load.result].aggregate;
            break :field lowerCopy(layout.values[load.result], operand);
        },
        .field_store => |store| field_store: {
            const structure_index = function.value_types[store.base].structureIndex() orelse return error.InvalidMachineProgram;
            if (!program.structures[structure_index].is_class) return error.InvalidMachineProgram;
            break :field_store .{ .class_store = .{
                .result = layout.values[store.result].start,
                .base = layout.values[store.base].start,
                .byte_offset = @intCast((try fieldOffset(program, structure_index, store.field)) * Machine.slot_size),
                .replacement = layout.values[store.replacement],
            } };
        },
        .local_load => |load| lowerCopy(layout.values[load.result], layout.locals[load.local]),
        .local_store => |store| lowerCopy(layout.locals[store.local], layout.values[store.operand]),
        .local_address => |address| .{ .local_address = .{
            .result = layout.values[address.result].start,
            .local = layout.locals[address.local].start,
        } },
        .reference_load => |load| .{ .reference_load = .{
            .result = layout.values[load.result],
            .reference = layout.values[load.reference].start,
        } },
        .address_load => |load| .{ .address_load = .{
            .result = layout.values[load.result].start,
            .address = layout.values[load.address].start,
            .byte_offset = layout.values[load.byte_offset].start,
            .type = load.type,
        } },
        .address_store => |store| .{ .address_store = .{
            .address = layout.values[store.address].start,
            .byte_offset = layout.values[store.byte_offset].start,
            .operand = layout.values[store.operand].start,
            .type = store.type,
        } },
        .reference_store => |store| .{ .reference_store = .{
            .reference = layout.values[store.reference].start,
            .operand = layout.values[store.operand],
        } },
        .reference_field => |field| reference_field: {
            const is_class = program.structures[field.structure].is_class;
            const value: Machine.Instruction.ReferenceOffset = .{
                .result = layout.values[field.result].start,
                .reference = layout.values[field.reference].start,
                .byte_offset = @intCast((try fieldOffset(program, field.structure, field.field) + @as(usize, if (is_class) 4 else 0)) * Machine.slot_size),
            };
            break :reference_field if (is_class)
                .{ .reference_indirect_offset = value }
            else
                .{ .reference_offset = value };
        },
        .reference_optional => |optional| .{ .reference_offset = .{
            .result = layout.values[optional.result].start,
            .reference = layout.values[optional.reference].start,
            .byte_offset = Machine.slot_size,
        } },
        .convert => |conversion| .{ .convert = .{
            .result = layout.values[conversion.result].start,
            .operand = layout.values[conversion.operand].start,
            .source = conversion.source,
            .target = conversion.target,
            .checked = conversion.checked,
            .header = try internString(
                allocator,
                strings,
                try runtimeConversionHeader(allocator, program, conversion.position),
            ),
        } },
        .format_value => |format| .{ .format_value = .{
            .result = layout.values[format.result].start,
            .operand = layout.values[format.operand].start,
            .kind = try printKind(function.value_types[format.operand]),
        } },
        .string_concat => |concat| .{ .string_concat = .{
            .result = layout.values[concat.result].start,
            .left = layout.values[concat.left].start,
            .right = layout.values[concat.right].start,
        } },
        .string_count => |count| .{ .string_count = .{
            .result = layout.values[count.result].start,
            .operand = layout.values[count.operand].start,
        } },
        .unary => |unary| .{ .unary = .{
            .result = layout.values[unary.result].start,
            .operator = switch (unary.operator) {
                .negate => .negate,
            },
            .operand = layout.values[unary.operand].start,
            .type = function.value_types[unary.result],
        } },
        .binary => |binary| binary_instruction: {
            if (isAggregate(program, function.value_types[binary.left])) {
                if (binary.operator != .equal and binary.operator != .not_equal) return error.UnsupportedType;
                break :binary_instruction .{ .aggregate_equal = .{
                    .result = layout.values[binary.result].start,
                    .left = layout.values[binary.left],
                    .right = layout.values[binary.right],
                    .leaves = try equalityLeaves(allocator, program, function.value_types[binary.left]),
                    .equal = binary.operator == .equal,
                } };
            }
            break :binary_instruction .{ .binary = .{
                .result = layout.values[binary.result].start,
                .operator = switch (binary.operator) {
                    .add => .add,
                    .subtract => .subtract,
                    .multiply => .multiply,
                    .divide => .divide,
                    .remainder => .remainder,
                    .less => .less,
                    .less_equal => .less_equal,
                    .greater => .greater,
                    .greater_equal => .greater_equal,
                    .equal => .equal,
                    .not_equal => .not_equal,
                    .bit_and => .bit_and,
                    .bit_xor => .bit_xor,
                    .shift_left => .shift_left,
                    .shift_right => .shift_right,
                },
                .left = layout.values[binary.left].start,
                .right = layout.values[binary.right].start,
                .type = function.value_types[binary.left],
                .checked = binary.checked,
            } };
        },
        .call => |call| call: {
            _ = try Machine.checkedArgumentCount(call.arguments.len);
            const arguments = try allocator.alloc(Machine.Span, call.arguments.len);
            for (call.arguments, 0..) |argument, index| arguments[index] = layout.values[argument];
            break :call .{ .call = .{
                .result = if (call.result) |result| layout.values[result] else null,
                .function = call.function,
                .arguments = arguments,
            } };
        },
        .indirect_call => |call| indirect: {
            _ = try Machine.checkedArgumentCount(call.arguments.len);
            const arguments = try allocator.alloc(Machine.Span, call.arguments.len);
            for (call.arguments, 0..) |argument, index| arguments[index] = layout.values[argument];
            break :indirect .{ .indirect_call = .{
                .result = if (call.result) |result| layout.values[result] else null,
                .callee = layout.values[call.callee].start,
                .arguments = arguments,
                .return_type = if (call.result) |result| function.value_types[result] else .void,
            } };
        },
        .boundary_call => |call| external_call: {
            if (call.arguments.len > Machine.max_external_arguments) return error.TooManyArguments;
            const arguments = try allocator.alloc(Machine.Slot, call.arguments.len);
            for (call.arguments, 0..) |argument, index| arguments[index] = layout.values[argument].start;
            break :external_call .{ .external_call = .{
                .result = if (call.result) |result| layout.values[result].start else null,
                .function = call.function,
                .arguments = arguments,
            } };
        },
        .boundary_indirect_call => |call| external_call: {
            if (call.signature >= program.function_types.len or call.arguments.len > Machine.max_external_arguments) {
                return error.TooManyArguments;
            }
            const signature = program.function_types[call.signature];
            const arguments = try allocator.alloc(Machine.Slot, call.arguments.len);
            const argument_types = try allocator.alloc(Machine.AbiValue, signature.parameter_types.len);
            for (call.arguments, signature.parameter_types, 0..) |argument, parameter_type, index| {
                arguments[index] = layout.values[argument].start;
                argument_types[index] = try lowerExternalType(parameter_type);
            }
            break :external_call .{ .external_indirect_call = .{
                .result = if (call.result) |result| layout.values[result].start else null,
                .callee = layout.values[call.callee].start,
                .signature = .{
                    .arguments = argument_types,
                    .result = if (signature.return_type == .void) null else try lowerExternalType(signature.return_type),
                },
                .arguments = arguments,
            } };
        },
        .dynamic_call => |call| dispatch: {
            _ = try Machine.checkedArgumentCount(call.arguments.len);
            const arguments = try allocator.alloc(Machine.Span, call.arguments.len);
            for (call.arguments, 0..) |argument, index| arguments[index] = layout.values[argument];
            const implementations = try allocator.alloc(Machine.Instruction.DynamicCall.Implementation, call.implementations.len);
            for (call.implementations, 0..) |implementation, index| implementations[index] = .{
                .structure = implementation.structure,
                .function = implementation.function,
            };
            break :dispatch .{ .dynamic_call = .{
                .result = if (call.result) |result| layout.values[result] else null,
                .function = call.function,
                .receiver = layout.values[call.receiver].start,
                .arguments = arguments,
                .implementations = implementations,
            } };
        },
        .print => |value| .{ .print = .{
            .value = layout.values[value.value].start,
            .kind = try printKind(function.value_types[value.value]),
            .newline = value.newline,
        } },
        .assert => |assertion| .{ .assert = .{
            .condition = layout.values[assertion.condition].start,
            .message = layout.values[assertion.message].start,
            .header = try internString(allocator, strings, try runtimeHeader(allocator, program, assertion.position, true)),
        } },
        .mutex_lock => .mutex_lock,
        .mutex_unlock => .mutex_unlock,
    };
}

fn printKind(type_value: Ir.Type) Machine.Error!Machine.PrintKind {
    return switch (type_value) {
        .int8, .int16, .int32, .int => .signed_integer,
        .uint8, .uint16, .uint32, .uint => .unsigned_integer,
        .float32 => .float32,
        .float64 => .float64,
        .bool => .boolean,
        .str => .string,
        else => error.UnsupportedType,
    };
}

fn lowerTerminator(
    allocator: Allocator,
    program: Ir.Program,
    strings: *std.ArrayList([]const u8),
    layout: Layout,
    terminator: Ir.Terminator,
    starts: []const usize,
) Machine.Error!Machine.Instruction {
    return switch (terminator) {
        .jump => |target| .{ .jump = starts[target] },
        .branch => |branch| .{ .branch = .{
            .condition = layout.values[branch.condition].start,
            .then_instruction = starts[branch.then_block],
            .else_instruction = starts[branch.else_block],
        } },
        .return_value => |value| .{ .return_value = layout.values[value] },
        .return_void => .return_void,
        .panic => |panic_value| .{ .panic = .{
            .message = layout.values[panic_value.message].start,
            .header = try internString(allocator, strings, try runtimeHeader(allocator, program, panic_value.position, false)),
        } },
    };
}

fn lowerCopy(result: Machine.Span, operand: Machine.Span) Machine.Instruction {
    if (!result.aggregate and result.width == 1) return .{ .copy = .{ .result = result.start, .operand = operand.start } };
    return .{ .copy_range = .{ .result = result, .operand = operand } };
}

fn requiresDeepCopy(program: Ir.Program, type_value: Ir.Type) Machine.Error!bool {
    if (type_value.functionIndex() != null) return false;
    if (type_value.optionalChild()) |child| return requiresDeepCopy(program, child);
    if (enumByType(program, type_value)) |enumeration| {
        for (enumeration.variants) |variant| {
            for (variant.associated_types) |associated| if (try requiresDeepCopy(program, associated)) return true;
        }
        return false;
    }
    const structure_index = type_value.structureIndex() orelse return false;
    if (structure_index >= program.structures.len) return error.InvalidMachineProgram;
    const structure = program.structures[structure_index];
    if (structure.is_class or structure.is_protocol) return true;
    if (structure.collection) |collection| {
        if (collection.length == null) return !collection.view;
        return requiresDeepCopy(program, collection.element);
    }
    for (structure.fields) |field| if (try requiresDeepCopy(program, field.type)) return true;
    return false;
}

fn fieldOffset(program: Ir.Program, structure_index: usize, field_index: usize) Machine.Error!usize {
    if (structure_index >= program.structures.len or field_index >= program.structures[structure_index].fields.len) {
        return error.InvalidMachineProgram;
    }
    var result: usize = 0;
    for (program.structures[structure_index].fields[0..field_index]) |field| result += try leafCount(program, field.type);
    return result;
}

const copy_kind_value = 0;
const copy_kind_class = 1;
const copy_kind_protocol = 2;
const copy_kind_list = 3;
const copy_kind_array = 4;
const copy_kind_enumeration = 5;
const copy_entry_words = 4;

fn buildCopyModel(allocator: Allocator, program: Ir.Program) Machine.Error![]const u64 {
    var model: std.ArrayList(u64) = .empty;
    try model.append(allocator, program.structures.len);
    try model.appendNTimes(allocator, 0, program.structures.len * copy_entry_words);

    for (program.structures, 0..) |structure, structure_index| {
        const entry = 1 + structure_index * copy_entry_words;
        const data_offset = model.items.len;
        var kind: u64 = copy_kind_value;

        if (enumByType(program, .structure(structure_index))) |enumeration| {
            kind = copy_kind_enumeration;
            try model.append(allocator, enumeration.variants.len);
            for (enumeration.variants) |variant| {
                const raw_count: usize = @intFromBool(enumeration.raw_type != null);
                try model.append(allocator, raw_count + variant.associated_types.len);
                if (enumeration.raw_type) |raw_type| try model.append(allocator, @intFromEnum(raw_type));
                for (variant.associated_types) |associated| try model.append(allocator, @intFromEnum(associated));
            }
        } else if (structure.is_protocol) {
            kind = copy_kind_protocol;
            var case_count: usize = 0;
            for (program.structures, 0..) |candidate, candidate_index| {
                if (!candidate.is_protocol and irConforms(program, candidate_index, structure_index)) case_count += 1;
            }
            try model.append(allocator, case_count);
            for (program.structures, 0..) |candidate, candidate_index| {
                if (candidate.is_protocol or !irConforms(program, candidate_index, structure_index)) continue;
                try model.append(allocator, candidate_index);
                try model.append(allocator, @intFromEnum(Ir.Type.structure(candidate_index)));
            }
        } else if (structure.is_class) {
            kind = copy_kind_class;
            var case_count: usize = 0;
            for (program.structures, 0..) |candidate, candidate_index| {
                if (candidate.is_class and classSubtype(program, candidate_index, structure_index)) case_count += 1;
            }
            try model.append(allocator, case_count);
            for (program.structures, 0..) |candidate, candidate_index| {
                if (!candidate.is_class or !classSubtype(program, candidate_index, structure_index)) continue;
                var object_width: usize = 0;
                for (candidate.fields) |field| object_width += try leafCount(program, field.type);
                try model.append(allocator, candidate_index);
                try model.append(allocator, object_width);
                try model.append(allocator, candidate.fields.len);
                for (candidate.fields) |field| try model.append(allocator, @intFromEnum(field.type));
            }
        } else if (structure.collection) |collection| {
            if (collection.length) |length| {
                kind = copy_kind_array;
                try model.append(allocator, @intFromEnum(collection.element));
                try model.append(allocator, length);
            } else if (collection.view) {
                kind = copy_kind_value;
            } else {
                kind = copy_kind_list;
                try model.append(allocator, @intFromEnum(collection.element));
            }
        } else {
            for (structure.fields) |field| try model.append(allocator, @intFromEnum(field.type));
        }

        model.items[entry] = kind;
        model.items[entry + 1] = try leafCount(program, .structure(structure_index));
        model.items[entry + 2] = data_offset;
        model.items[entry + 3] = model.items.len - data_offset;
    }
    return model.toOwnedSlice(allocator);
}

fn classSubtype(program: Ir.Program, candidate: usize, expected: usize) bool {
    var current: ?usize = candidate;
    while (current) |index| : (current = program.structures[index].base) {
        if (index == expected) return true;
    }
    return false;
}

fn flattenedTypes(allocator: Allocator, program: Ir.Program, type_value: Ir.Type) Machine.Error![]const Ir.Type {
    var result: std.ArrayList(Ir.Type) = .empty;
    try appendFlattenedTypes(allocator, program, type_value, &result);
    return result.toOwnedSlice(allocator);
}

fn equalityLeaves(
    allocator: Allocator,
    program: Ir.Program,
    type_value: Ir.Type,
) Machine.Error![]const Machine.Instruction.EqualityLeaf {
    var result: std.ArrayList(Machine.Instruction.EqualityLeaf) = .empty;
    var offset: usize = 0;
    try appendEqualityLeaves(allocator, program, type_value, &.{}, &offset, &result);
    if (offset != try leafCount(program, type_value)) return error.InvalidMachineProgram;
    return result.toOwnedSlice(allocator);
}

fn checkedEqualityOffset(value: usize) Machine.Error!u12 {
    return std.math.cast(u12, value) orelse error.FrameTooLarge;
}

fn appendEqualityLeaves(
    allocator: Allocator,
    program: Ir.Program,
    type_value: Ir.Type,
    guards: []const Machine.Instruction.EqualityGuard,
    offset: *usize,
    result: *std.ArrayList(Machine.Instruction.EqualityLeaf),
) Machine.Error!void {
    if (type_value.functionIndex() != null) {
        for (0..2) |_| {
            try result.append(allocator, .{
                .offset = try checkedEqualityOffset(offset.*),
                .type = .uint,
                .guards = guards,
            });
            offset.* += 1;
        }
        return;
    }
    if (type_value.optionalChild()) |child| {
        const tag_offset = try checkedEqualityOffset(offset.*);
        try result.append(allocator, .{ .offset = tag_offset, .type = .bool, .guards = guards });
        offset.* += 1;
        const present = try appendEqualityGuard(allocator, guards, .{ .offset = tag_offset, .expected = 1 });
        return appendEqualityLeaves(allocator, program, child, present, offset, result);
    }
    if (enumByType(program, type_value)) |enumeration| {
        const start = offset.*;
        const tag_offset = try checkedEqualityOffset(start);
        try result.append(allocator, .{ .offset = tag_offset, .type = .uint, .guards = guards });
        if (enumeration.raw_type == null) {
            for (enumeration.variants, 0..) |variant, variant_index| {
                var payload_offset = start + 1;
                const active = try appendEqualityGuard(allocator, guards, .{
                    .offset = tag_offset,
                    .expected = variant_index,
                });
                for (variant.associated_types) |associated| {
                    try appendEqualityLeaves(allocator, program, associated, active, &payload_offset, result);
                }
            }
        }
        offset.* = start + try leafCount(program, type_value);
        return;
    }
    const structure_index = type_value.structureIndex() orelse {
        try result.append(allocator, .{
            .offset = try checkedEqualityOffset(offset.*),
            .type = type_value,
            .guards = guards,
        });
        offset.* += 1;
        return;
    };
    if (structure_index >= program.structures.len) return error.InvalidMachineProgram;
    const structure = program.structures[structure_index];
    if (structure.is_protocol) {
        const start = offset.*;
        const tag_offset = try checkedEqualityOffset(start);
        try result.append(allocator, .{ .offset = tag_offset, .type = .uint, .guards = guards });
        for (program.structures, 0..) |candidate, candidate_index| {
            if (candidate.is_protocol or !irConforms(program, candidate_index, structure_index)) continue;
            var payload_offset = start + 1;
            const active = try appendEqualityGuard(allocator, guards, .{
                .offset = tag_offset,
                .expected = candidate_index,
            });
            try appendEqualityLeaves(
                allocator,
                program,
                .structure(candidate_index),
                active,
                &payload_offset,
                result,
            );
        }
        offset.* = start + try leafCount(program, type_value);
        return;
    }
    if (structure.is_class) {
        try result.append(allocator, .{
            .offset = try checkedEqualityOffset(offset.*),
            .type = .uint,
            .guards = guards,
        });
        offset.* += 1;
        return;
    }
    if (structure.collection) |collection| {
        if (collection.length) |length| {
            for (0..length) |_| try appendEqualityLeaves(allocator, program, collection.element, guards, offset, result);
        } else {
            try result.append(allocator, .{
                .offset = try checkedEqualityOffset(offset.*),
                .type = .uint,
                .guards = guards,
            });
            offset.* += 1;
            if (collection.view) {
                try result.append(allocator, .{
                    .offset = try checkedEqualityOffset(offset.*),
                    .type = .uint,
                    .guards = guards,
                });
                offset.* += 1;
            }
        }
        return;
    }
    for (structure.fields) |field| {
        try appendEqualityLeaves(allocator, program, field.type, guards, offset, result);
    }
}

fn appendEqualityGuard(
    allocator: Allocator,
    guards: []const Machine.Instruction.EqualityGuard,
    guard: Machine.Instruction.EqualityGuard,
) Allocator.Error![]const Machine.Instruction.EqualityGuard {
    const result = try allocator.alloc(Machine.Instruction.EqualityGuard, guards.len + 1);
    @memcpy(result[0..guards.len], guards);
    result[guards.len] = guard;
    return result;
}

fn appendFlattenedTypes(
    allocator: Allocator,
    program: Ir.Program,
    type_value: Ir.Type,
    result: *std.ArrayList(Ir.Type),
) Machine.Error!void {
    if (type_value.functionIndex() != null) {
        try result.append(allocator, .uint);
        try result.append(allocator, .uint);
        return;
    }
    if (type_value.optionalChild()) |child| {
        try result.append(allocator, .bool);
        return appendFlattenedTypes(allocator, program, child, result);
    }
    if (enumByType(program, type_value)) |enumeration| {
        try result.append(allocator, .uint);
        if (enumeration.raw_type) |raw_type| return result.append(allocator, raw_type);
        var widest: []const Ir.Type = &.{};
        for (enumeration.variants) |variant| {
            const flat = try flattenedTypesForList(allocator, program, variant.associated_types);
            if (flat.len > widest.len) widest = flat;
        }
        return result.appendSlice(allocator, widest);
    }
    const structure_index = type_value.structureIndex() orelse return result.append(allocator, type_value);
    if (structure_index >= program.structures.len) return error.InvalidMachineProgram;
    if (program.structures[structure_index].is_protocol) {
        try result.append(allocator, .uint);
        var widest: []const Ir.Type = &.{};
        for (program.structures, 0..) |structure, candidate| {
            if (structure.is_protocol or !irConforms(program, candidate, structure_index)) continue;
            const flat = try flattenedTypes(allocator, program, .structure(candidate));
            if (flat.len > widest.len) widest = flat;
        }
        return result.appendSlice(allocator, widest);
    }
    if (program.structures[structure_index].is_class) return result.append(allocator, .uint);
    if (program.structures[structure_index].collection) |collection| {
        if (collection.length) |length| {
            for (0..length) |_| try appendFlattenedTypes(allocator, program, collection.element, result);
        } else {
            try result.append(allocator, .uint);
            if (collection.view) try result.append(allocator, .uint);
        }
        return;
    }
    for (program.structures[structure_index].fields) |field| {
        try appendFlattenedTypes(allocator, program, field.type, result);
    }
}

fn collectionForType(program: Ir.Program, type_value: Ir.Type) ?@import("../Types.zig").Collection {
    const index = type_value.structureIndex() orelse return null;
    if (index >= program.structures.len) return null;
    return program.structures[index].collection;
}

fn collectionElementStride(program: Ir.Program, element: Ir.Type, width: u12) Machine.Error!u12 {
    if (try compactFloat32CollectionElement(program, element)) return std.math.mul(u12, width, 4) catch error.FrameTooLarge;
    return std.math.mul(u12, width, Machine.slot_size) catch error.FrameTooLarge;
}

fn compactFloat32CollectionElement(program: Ir.Program, element: Ir.Type) Machine.Error!bool {
    if (!try containsOnlyFloat32Leaves(program, element)) return false;
    for (program.functions) |function| for (function.blocks) |block| for (block.instructions) |instruction| {
        const collection_value = switch (instruction) {
            .collection_reference => |value| value.collection,
            .collection_view => |value| if (value.reference != null) value.collection else continue,
            else => continue,
        };
        const collection = collectionForType(program, function.value_types[collection_value]) orelse continue;
        if (collection.element == element) return false;
    };
    return true;
}

fn containsOnlyFloat32Leaves(program: Ir.Program, type_value: Ir.Type) Machine.Error!bool {
    if (type_value == .float32) return true;
    if (type_value.functionIndex() != null or type_value.optionalChild() != null or enumByType(program, type_value) != null) return false;
    const structure_index = type_value.structureIndex() orelse return false;
    if (structure_index >= program.structures.len) return error.InvalidMachineProgram;
    const structure = program.structures[structure_index];
    if (structure.is_class or structure.is_protocol or structure.collection != null or structure.fields.len == 0) return false;
    for (structure.fields) |field| if (!try containsOnlyFloat32Leaves(program, field.type)) return false;
    return true;
}

fn flattenedTypesForList(allocator: Allocator, program: Ir.Program, types: []const Ir.Type) Machine.Error![]const Ir.Type {
    var result: std.ArrayList(Ir.Type) = .empty;
    for (types) |type_value| try appendFlattenedTypes(allocator, program, type_value, &result);
    return result.toOwnedSlice(allocator);
}

fn internString(
    allocator: Allocator,
    strings: *std.ArrayList([]const u8),
    value: []const u8,
) Allocator.Error!usize {
    for (strings.items, 0..) |existing, index| {
        if (std.mem.eql(u8, existing, value)) return index;
    }
    const index = strings.items.len;
    try strings.append(allocator, value);
    return index;
}

fn runtimeHeader(
    allocator: Allocator,
    program: Ir.Program,
    position: @import("../Source.zig").Position,
    assertion: bool,
) Allocator.Error![]const u8 {
    const path = if (position.file < program.files.len) program.files[position.file] else "<source>";
    return if (assertion)
        std.fmt.allocPrint(
            allocator,
            "{s}:{d}:{d}: runtime error: assertion failed: ",
            .{ path, position.line, position.column },
        )
    else
        std.fmt.allocPrint(
            allocator,
            "{s}:{d}:{d}: runtime error: ",
            .{ path, position.line, position.column },
        );
}

fn collectionRuntimeHeader(
    allocator: Allocator,
    program: Ir.Program,
    position: @import("../Source.zig").Position,
) Allocator.Error![]const u8 {
    const path = if (position.file < program.files.len) program.files[position.file] else "<source>";
    return std.fmt.allocPrint(allocator, "{s}:{d}:{d}: runtime error: collection index ", .{ path, position.line, position.column });
}

fn runtimeConversionHeader(
    allocator: Allocator,
    program: Ir.Program,
    position: @import("../Source.zig").Position,
) Allocator.Error![]const u8 {
    const path = if (position.file < program.files.len) program.files[position.file] else "<source>";
    return std.fmt.allocPrint(
        allocator,
        "{s}:{d}:{d}: runtime error: invalid numeric conversion\n",
        .{ path, position.line, position.column },
    );
}

fn compile(allocator: Allocator, source: []const u8) !Machine.Program {
    var frontend = @import("../Frontend.zig").Frontend.init(allocator);
    return lower(allocator, (try frontend.compile(source)).ir);
}

test "lower answer and nested calls to deterministic machine slots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const program = try compile(arena.allocator(),
        \\func add(left:int, right:int) int { return left + right }
        \\func answer() int { return add(40, 2) }
        \\func main() { answer() }
    );
    try std.testing.expectEqual(@as(usize, 3), program.functions.len);
    try std.testing.expectEqual(@as(u12, 2), program.functions[0].parameter_count);
    try std.testing.expectEqual(@as(u12, 3), program.functions[0].slot_count);
    try std.testing.expectEqual(@as(u32, 32), program.functions[0].frame_size);
    try std.testing.expectEqual(Machine.BinaryOperator.add, program.functions[0].instructions[0].binary.operator);
    try std.testing.expectEqual(@as(Machine.Slot, 0), program.functions[0].instructions[0].binary.left);
    try std.testing.expectEqual(@as(Machine.FunctionId, 0), program.functions[1].instructions[2].call.function);
    try std.testing.expectEqual(@as(Machine.Slot, 2), program.functions[1].instructions[2].call.result.?.start);
    try std.testing.expectEqual(@as(Machine.FunctionId, 1), program.functions[2].instructions[0].call.function);
    try std.testing.expect(program.debug);
    try std.testing.expectEqual(@as(usize, 1), program.functions[0].source_position.?.line);
    try std.testing.expectEqual(@as(usize, 1), program.functions[0].instruction_positions[0].?.line);
    try std.testing.expectEqual(@as(usize, 3), program.functions[2].instruction_positions[0].?.line);
}

test "lower internal stack arguments before encoding" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("../Frontend.zig").Frontend.init(allocator);
    const compilation = try frontend.compile(
        "func many(a:int,b:int,c:int,d:int,e:int,f:int,g:int,h:int,i:int) int { return i } func main() { many(1,2,3,4,5,6,7,8,9) }",
    );
    const lowered = try lower(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u12, 9), lowered.functions[0].parameter_count);
    try std.testing.expectEqual(@as(usize, 9), lowered.functions[1].instructions[9].call.arguments.len);

    const functions = [_]Ir.Function{.{
        .name = "floating",
        .parameter_types = &.{.float32},
        .return_type = .void,
        .value_types = &.{.float32},
        .blocks = &.{.{ .instructions = &.{}, .terminator = .return_void }},
    }};
    _ = try lower(allocator, .{ .functions = &functions });
}

test "lower abstract mutable locals after value slots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const program = try compile(arena.allocator(),
        \\func main() {
        \\    var value:int = 1
        \\    value = 42
        \\    print(value)
        \\}
    );
    const function = program.functions[0];
    try std.testing.expectEqual(@as(Machine.Slot, 4), function.slot_count);
    try std.testing.expectEqual(@as(Machine.Slot, 3), function.instructions[1].copy.result);
    try std.testing.expectEqual(@as(Machine.Slot, 3), function.instructions[3].copy.result);
    try std.testing.expectEqual(@as(Machine.Slot, 3), function.instructions[4].copy.operand);
}

test "lower trivial aggregate copies without the deep-copy runtime" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const program = try compile(arena.allocator(),
        \\struct Quaternion { let x:float; let y:float; let z:float; let w:float }
        \\class State { var value:int }
        \\func main() {
        \\    let rotation = Quaternion(x:0.0, y:0.0, z:0.0, w:1.0)
        \\    let rotation_copy = copy rotation
        \\    var state = State(value:1)
        \\    var state_copy = copy state
        \\}
    );
    var found_range = false;
    var found_deep = false;
    for (program.functions[0].instructions) |instruction| switch (instruction) {
        .copy_range => found_range = true,
        .deep_copy => found_deep = true,
        else => {},
    };
    try std.testing.expect(found_range);
    try std.testing.expect(found_deep);
}
