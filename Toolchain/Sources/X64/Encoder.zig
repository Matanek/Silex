const std = @import("std");
const Machine = @import("../Arm64/Machine.zig");
const WindowsImports = @import("../Windows/Imports.zig");
const FloatRuntime = @import("FloatRuntime.zig");
const ExternalCalls = @import("ExternalCalls.zig");
const Reachability = @import("Reachability.zig");
const TextRuntime = @import("TextRuntime.zig");

const Allocator = std.mem.Allocator;
const dynamic_string_flag: u64 = 1 << 63;
const dynamic_string_prefix_size: u8 = 16;

pub const Error = Machine.Error || Allocator.Error || FloatRuntime.Error || error{UnsupportedInstruction};

pub const Image = struct {
    code: []u8,
    entry_offset: u32,
    windows_import_sites: []const WindowsImports.X64Site = &.{},
    external_call_sites: []const ExternalCalls.Site = &.{},

    pub fn deinit(self: Image, allocator: Allocator) void {
        allocator.free(self.code);
        allocator.free(self.windows_import_sites);
        allocator.free(self.external_call_sites);
    }
};

const Register = enum(u4) { rax = 0, rcx = 1, rdx = 2, rbx = 3, rsp = 4, rbp = 5, rsi = 6, rdi = 7, r8 = 8, r9 = 9, r10 = 10, r11 = 11, r12 = 12, r13 = 13, r14 = 14, r15 = 15 };
const CallFixup = struct { displacement_at: usize, function: usize };
const FunctionAddressFixup = struct { displacement_at: usize, function: usize };
const BranchFixup = struct { displacement_at: usize, instruction: usize };
const EpilogueFixup = struct { displacement_at: usize };
const DataFixup = struct { displacement_at: usize, string: usize };
const GlobalFixup = struct { displacement_at: usize, global: usize, byte_offset: usize };
const Platform = ExternalCalls.Platform;

/// Encodes the reachable scalar/class slice of the portable machine program
/// directly as X64. The internal convention is deliberately Silex-owned:
/// the first eight scalar arguments use RDI, RSI, RDX, RCX, R8, R9, R10, R11
/// and remaining arguments use aligned stack slots; scalar results use RAX;
/// the execution status uses RDX.
pub fn encodeLinux(allocator: Allocator, program: Machine.Program) Error!Image {
    return encode(allocator, program, .linux, false, null);
}

pub fn encodeWindows(allocator: Allocator, program: Machine.Program) Error!Image {
    return encode(allocator, program, .windows, false, null);
}

pub fn encodeLinuxObject(allocator: Allocator, program: Machine.Program) Error!Image {
    return encode(allocator, program, .linux, true, null);
}

pub fn encodeWindowsObject(allocator: Allocator, program: Machine.Program) Error!Image {
    return encode(allocator, program, .windows, true, null);
}

pub fn encodeLinuxFunctionObject(allocator: Allocator, program: Machine.Program, function: Machine.FunctionId) Error!Image {
    return encode(allocator, program, .linux, true, function);
}

pub fn encodeWindowsFunctionObject(allocator: Allocator, program: Machine.Program, function: Machine.FunctionId) Error!Image {
    return encode(allocator, program, .windows, true, function);
}

fn encode(
    allocator: Allocator,
    program: Machine.Program,
    platform: Platform,
    linked: bool,
    entry: ?Machine.FunctionId,
) Error!Image {
    try Machine.validate(program);
    const main_id = entry orelse findMain(program) orelse return error.InvalidMachineProgram;
    if (main_id >= program.functions.len) return error.InvalidMachineProgram;
    const reachable = try Reachability.find(allocator, program, main_id);
    defer allocator.free(reachable);

    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    const offsets = try allocator.alloc(u32, program.functions.len);
    defer allocator.free(offsets);
    @memset(offsets, std.math.maxInt(u32));
    var calls: std.ArrayList(CallFixup) = .empty;
    defer calls.deinit(allocator);
    var function_addresses: std.ArrayList(FunctionAddressFixup) = .empty;
    defer function_addresses.deinit(allocator);
    var float_calls: std.ArrayList(usize) = .empty;
    defer float_calls.deinit(allocator);
    var data_fixups: std.ArrayList(DataFixup) = .empty;
    defer data_fixups.deinit(allocator);
    var global_fixups: std.ArrayList(GlobalFixup) = .empty;
    defer global_fixups.deinit(allocator);
    var windows_import_sites: std.ArrayList(WindowsImports.X64Site) = .empty;
    defer windows_import_sites.deinit(allocator);
    var external_call_sites: std.ArrayList(ExternalCalls.Site) = .empty;
    defer external_call_sites.deinit(allocator);

    for (program.functions, 0..) |function, function_id| {
        if (!reachable[function_id]) continue;
        offsets[function_id] = @intCast(bytes.items.len);
        try encodeFunction(allocator, &bytes, &calls, &function_addresses, &float_calls, &data_fixups, &global_fixups, &windows_import_sites, &external_call_sites, platform, program, function);
    }

    const entry_offset: u32 = @intCast(bytes.items.len);
    switch (platform) {
        .linux => {
            if (linked) try bytes.appendSlice(allocator, &.{ 0x53, 0x41, 0x54, 0x41, 0x55, 0x41, 0x56, 0x41, 0x57 });
            try appendCall(allocator, &bytes, &calls, main_id);
            if (linked) {
                try emitMoveRegister(allocator, &bytes, .rax, .rdx);
                try bytes.appendSlice(allocator, &.{ 0x41, 0x5f, 0x41, 0x5e, 0x41, 0x5d, 0x41, 0x5c, 0x5b, 0xc3 });
            } else {
                try emitMoveRegister(allocator, &bytes, .rdi, .rdx);
                try emitImmediate(allocator, &bytes, .rax, 60);
                try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });
            }
        },
        .windows => {
            if (linked) {
                try bytes.appendSlice(allocator, &.{ 0x53, 0x56, 0x57, 0x41, 0x54, 0x41, 0x55, 0x41, 0x56, 0x41, 0x57 });
            } else try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xec, 40 });
            if (program.mutex_global) |global| {
                try emitAddressGlobal(allocator, &bytes, &global_fixups, global, 0, .rcx);
                try ExternalCalls.emitWindowsImportCall(allocator, &bytes, &windows_import_sites, .initialize_critical_section);
            }
            try appendCall(allocator, &bytes, &calls, main_id);
            if (linked) {
                try bytes.appendSlice(allocator, &.{ 0x89, 0xd0, 0x41, 0x5f, 0x41, 0x5e, 0x41, 0x5d, 0x41, 0x5c, 0x5f, 0x5e, 0x5b, 0xc3 });
            } else try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc4, 40, 0x89, 0xd0, 0xc3 });
        },
    }

    for (calls.items) |call| {
        if (call.function >= offsets.len or offsets[call.function] == std.math.maxInt(u32)) return error.InvalidMachineProgram;
        try patchRelative(bytes.items, call.displacement_at, offsets[call.function]);
    }
    for (function_addresses.items) |fixup| {
        if (fixup.function >= offsets.len or offsets[fixup.function] == std.math.maxInt(u32)) return error.InvalidMachineProgram;
        try patchRelative(bytes.items, fixup.displacement_at, offsets[fixup.function]);
    }

    if (float_calls.items.len != 0) {
        var runtime = try FloatRuntime.payload(allocator);
        defer runtime.deinit(allocator);
        while (bytes.items.len % 4096 != runtime.page_offset) try bytes.append(allocator, 0);
        const runtime_start = bytes.items.len;
        const formatter = runtime_start + runtime.entry_offset;
        for (float_calls.items) |displacement_at| try patchRelative(bytes.items, displacement_at, formatter);
        try bytes.appendSlice(allocator, runtime.bytes);
    }

    const string_offsets = try allocator.alloc(usize, program.strings.len);
    defer allocator.free(string_offsets);
    for (program.strings, 0..) |string, index| {
        while (bytes.items.len % 8 != 0) try bytes.append(allocator, 0);
        string_offsets[index] = bytes.items.len;
        try appendInt(allocator, &bytes, u64, string.len);
        try bytes.appendSlice(allocator, string);
        try bytes.append(allocator, 0);
    }
    for (data_fixups.items) |fixup| {
        if (fixup.string >= string_offsets.len) return error.InvalidMachineProgram;
        try patchRelative(bytes.items, fixup.displacement_at, string_offsets[fixup.string]);
    }
    const global_offsets = try allocator.alloc(usize, program.globals.len);
    defer allocator.free(global_offsets);
    for (program.globals, 0..) |global, index| {
        while (bytes.items.len % Machine.slot_size != 0) try bytes.append(allocator, 0);
        global_offsets[index] = bytes.items.len;
        try appendInt(allocator, &bytes, u64, global.bits);
        if (global.extra_bits.len + 1 > global.width) return error.InvalidMachineProgram;
        for (global.extra_bits) |bits| try appendInt(allocator, &bytes, u64, bits);
        for (global.extra_bits.len + 1..global.width) |_| try appendInt(allocator, &bytes, u64, 0);
    }
    for (global_fixups.items) |fixup| {
        if (fixup.global >= global_offsets.len or fixup.byte_offset >= @as(usize, program.globals[fixup.global].width) * Machine.slot_size) {
            return error.InvalidMachineProgram;
        }
        try patchRelative(bytes.items, fixup.displacement_at, global_offsets[fixup.global] + fixup.byte_offset);
    }
    return .{
        .code = try bytes.toOwnedSlice(allocator),
        .entry_offset = entry_offset,
        .windows_import_sites = try windows_import_sites.toOwnedSlice(allocator),
        .external_call_sites = try external_call_sites.toOwnedSlice(allocator),
    };
}

fn encodeFunction(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    calls: *std.ArrayList(CallFixup),
    function_addresses: *std.ArrayList(FunctionAddressFixup),
    float_calls: *std.ArrayList(usize),
    data_fixups: *std.ArrayList(DataFixup),
    global_fixups: *std.ArrayList(GlobalFixup),
    windows_import_sites: *std.ArrayList(WindowsImports.X64Site),
    external_call_sites: *std.ArrayList(ExternalCalls.Site),
    platform: Platform,
    program: Machine.Program,
    function: Machine.Function,
) Error!void {
    if (function.register_slots.len != 0 or function.float_register_slots.len != 0) return unsupported("release register allocation");
    try bytes.appendSlice(allocator, &.{ 0x55, 0x48, 0x89, 0xe5 });
    try emitFrameAllocation(allocator, bytes, platform, function.frame_size);
    const argument_registers = [_]Register{ .rdi, .rsi, .rdx, .rcx, .r8, .r9, .r10, .r11 };
    if (function.parameters.len != function.parameter_count) return error.InvalidMachineProgram;
    if (function.hidden_return_slot) |slot| try emitStoreStack(allocator, bytes, .r15, slot);
    for (function.parameters, 0..) |parameter, index| {
        if (index >= argument_registers.len) {
            const incoming_displacement: i32 = @intCast(16 + (index - argument_registers.len) * Machine.slot_size);
            if (parameter.aggregate) {
                try emitLoadMemory(allocator, bytes, .r14, .rbp, incoming_displacement);
                for (0..parameter.width) |leaf| {
                    try emitLoadMemory(allocator, bytes, .rax, .r14, -@as(i32, @intCast(leaf * Machine.slot_size)));
                    try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, parameter.start) + leaf));
                }
            } else {
                if (parameter.width != 1) return error.InvalidMachineProgram;
                try emitLoadMemory(allocator, bytes, .rax, .rbp, incoming_displacement);
                try emitStoreStack(allocator, bytes, .rax, parameter.start);
            }
        } else if (parameter.aggregate) {
            for (0..parameter.width) |leaf| {
                try emitLoadMemory(allocator, bytes, .rax, argument_registers[index], -@as(i32, @intCast(leaf * Machine.slot_size)));
                try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, parameter.start) + leaf));
            }
        } else {
            if (parameter.width != 1) return error.InvalidMachineProgram;
            try emitStoreStack(allocator, bytes, argument_registers[index], parameter.start);
        }
    }
    for (function.capture_parameters, 0..) |capture, index| {
        if (capture.aggregate or capture.width != 1) return error.InvalidMachineProgram;
        try emitLoadMemory(allocator, bytes, .rax, .r12, -@as(i32, @intCast(index * Machine.slot_size)));
        try emitStoreStack(allocator, bytes, .rax, capture.start);
    }

    const instruction_offsets = try allocator.alloc(usize, function.instructions.len + 1);
    defer allocator.free(instruction_offsets);
    var branches: std.ArrayList(BranchFixup) = .empty;
    defer branches.deinit(allocator);
    var epilogue_fixups: std.ArrayList(EpilogueFixup) = .empty;
    defer epilogue_fixups.deinit(allocator);

    for (function.instructions, 0..) |instruction, instruction_index| {
        instruction_offsets[instruction_index] = bytes.items.len;
        switch (instruction) {
            .constant_int => |value| {
                try emitImmediate(allocator, bytes, .rax, value.bits);
                try emitStoreStack(allocator, bytes, .rax, value.result);
            },
            .constant_bool => |value| {
                try emitImmediate(allocator, bytes, .rax, @intFromBool(value.value));
                try emitStoreStack(allocator, bytes, .rax, value.result);
            },
            .constant_float32 => |value| {
                try emitImmediate(allocator, bytes, .rax, value.bits);
                try emitStoreStack(allocator, bytes, .rax, value.result);
            },
            .constant_float64 => |value| {
                try emitImmediate(allocator, bytes, .rax, value.bits);
                try emitStoreStack(allocator, bytes, .rax, value.result);
            },
            .global_load => |global| {
                for (0..global.result.width) |leaf| {
                    try emitLoadGlobal(allocator, bytes, global_fixups, global.global, leaf * Machine.slot_size, .rax);
                    try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, global.result.start) + leaf));
                }
            },
            .global_store => |global| {
                for (0..global.operand.width) |leaf| {
                    try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, global.operand.start) + leaf));
                    try emitStoreGlobal(allocator, bytes, global_fixups, global.global, leaf * Machine.slot_size, .rax);
                }
            },
            .optional_null => |optional| {
                try emitImmediate(allocator, bytes, .rax, 0);
                for (0..optional.result.width) |index| {
                    try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, optional.result.start) + index));
                }
            },
            .optional_some => |optional| {
                try emitImmediate(allocator, bytes, .rax, 1);
                try emitStoreStack(allocator, bytes, .rax, optional.result.start);
                var payload = optional.result;
                payload.start += 1;
                payload.width -= 1;
                try emitCopyRange(allocator, bytes, payload, optional.operand);
            },
            .optional_unwrap => |optional| try emitCopyRange(allocator, bytes, optional.result, optional.operand),
            .constant_str => |value| try emitStringAddress(allocator, bytes, data_fixups, value.string, value.result),
            .constant_bytes => |value| try emitBytesLiteral(
                allocator,
                bytes,
                data_fixups,
                windows_import_sites,
                platform,
                &epilogue_fixups,
                program,
                value,
            ),
            .copy => |copy| {
                try emitLoadStack(allocator, bytes, .rax, copy.operand);
                try emitStoreStack(allocator, bytes, .rax, copy.result);
            },
            .copy_range => |copy| try emitCopyRange(allocator, bytes, copy.result, copy.operand),
            .local_address => |address| {
                try emitRex(allocator, bytes, true, .rax);
                try bytes.appendSlice(allocator, &.{ 0x8d, 0x85 });
                try appendInt(allocator, bytes, i32, slotDisplacement(address.local));
                try emitStoreStack(allocator, bytes, .rax, address.result);
            },
            .reference_load => |load| {
                if (load.result.width == 0) return error.InvalidMachineProgram;
                try emitLoadStack(allocator, bytes, .rcx, load.reference);
                for (0..load.result.width) |leaf| {
                    try emitLoadMemory(allocator, bytes, .rax, .rcx, @intCast(leaf * Machine.slot_size));
                    try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, load.result.start) + leaf));
                }
            },
            .address_load => |load| {
                try emitLoadStack(allocator, bytes, .rax, load.address);
                try emitLoadStack(allocator, bytes, .rcx, load.byte_offset);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x01, 0xc8 });
                try bytes.appendSlice(allocator, switch (load.type) {
                    .uint8 => &.{ 0x48, 0x0f, 0xb6, 0x00 },
                    .uint16 => &.{ 0x48, 0x0f, 0xb7, 0x00 },
                    .uint32, .float32 => &.{ 0x8b, 0x00 },
                    .int8 => &.{ 0x48, 0x0f, 0xbe, 0x00 },
                    .int16 => &.{ 0x48, 0x0f, 0xbf, 0x00 },
                    .int32 => &.{ 0x48, 0x63, 0x00 },
                    .int, .uint, .address, .float64 => &.{ 0x48, 0x8b, 0x00 },
                    else => return error.InvalidMachineProgram,
                });
                try emitStoreStack(allocator, bytes, .rax, load.result);
            },
            .address_store => |store| {
                try emitLoadStack(allocator, bytes, .rax, store.address);
                try emitLoadStack(allocator, bytes, .rcx, store.byte_offset);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x01, 0xc8 });
                try emitLoadStack(allocator, bytes, .rdx, store.operand);
                try bytes.appendSlice(allocator, switch (store.type) {
                    .int8, .uint8 => &.{ 0x88, 0x10 },
                    .int16, .uint16 => &.{ 0x66, 0x89, 0x10 },
                    .int32, .uint32, .float32 => &.{ 0x89, 0x10 },
                    .int, .uint, .float64 => &.{ 0x48, 0x89, 0x10 },
                    else => return error.InvalidMachineProgram,
                });
            },
            .reference_store => |store| {
                if (store.operand.width == 0) return error.InvalidMachineProgram;
                try emitLoadStack(allocator, bytes, .rcx, store.reference);
                for (0..store.operand.width) |leaf| {
                    try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, store.operand.start) + leaf));
                    try emitStoreMemory(allocator, bytes, .rcx, @intCast(leaf * Machine.slot_size), .rax);
                }
            },
            .reference_offset => |offset| {
                try emitLoadStack(allocator, bytes, .rax, offset.reference);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x05 });
                try appendInt(allocator, bytes, u32, offset.byte_offset);
                try emitStoreStack(allocator, bytes, .rax, offset.result);
            },
            .reference_indirect_offset => |offset| {
                try emitLoadStack(allocator, bytes, .rax, offset.reference);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x8b, 0x00 });
                try bytes.appendSlice(allocator, &.{ 0x48, 0x05 });
                try appendInt(allocator, bytes, u32, offset.byte_offset);
                try emitStoreStack(allocator, bytes, .rax, offset.result);
            },
            .aggregate_init => |initialization| {
                var destination_offset: usize = 0;
                for (initialization.fields) |field| {
                    var destination = initialization.result;
                    destination.start = @intCast(@as(usize, destination.start) + destination_offset);
                    destination.width = field.width;
                    try emitCopyRange(allocator, bytes, destination, field);
                    destination_offset += field.width;
                }
            },
            .list_init => |value| try emitListInit(allocator, bytes, windows_import_sites, platform, &epilogue_fixups, value),
            .collection_load => |value| {
                if (value.dynamic or value.view) {
                    try emitDynamicCollectionLoad(allocator, bytes, &epilogue_fixups, value);
                    continue;
                }
                if (!value.collection.aggregate or value.result.width == 0 or
                    value.collection.width != value.result.width * value.count)
                {
                    return error.InvalidMachineProgram;
                }
                try emitLoadStack(allocator, bytes, .rax, value.index);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x3d });
                try appendInt(allocator, bytes, u32, value.count);
                try bytes.appendSlice(allocator, &.{ 0x0f, 0x82 });
                const in_bounds = bytes.items.len;
                try bytes.appendNTimes(allocator, 0, 4);
                try emitImmediate(allocator, bytes, .rdx, @intFromEnum(Machine.Status.runtime_failure));
                try appendEpilogueJump(allocator, bytes, &epilogue_fixups);
                try patchRelative(bytes.items, in_bounds, bytes.items.len);
                try emitImmediate(allocator, bytes, .rcx, @as(u64, value.result.width) * Machine.slot_size);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xaf, 0xc1 });
                try emitAddressStack(allocator, bytes, .rcx, value.collection.start);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x29, 0xc1 });
                for (0..value.result.width) |leaf| {
                    try emitLoadMemory(allocator, bytes, .rax, .rcx, -@as(i32, @intCast(leaf * Machine.slot_size)));
                    try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, value.result.start) + leaf));
                }
            },
            .collection_reference => |value| try emitCollectionReference(allocator, bytes, &epilogue_fixups, value),
            .collection_replace => |value| if (value.view)
                try emitViewReplace(allocator, bytes, &epilogue_fixups, value)
            else if (value.dynamic)
                try emitDynamicReplace(allocator, bytes, windows_import_sites, platform, &epilogue_fixups, value)
            else
                try emitFixedReplace(allocator, bytes, &epilogue_fixups, value),
            .collection_count => |value| try emitCollectionCount(allocator, bytes, value),
            .list_edit => |value| try emitListEdit(allocator, bytes, windows_import_sites, platform, &epilogue_fixups, value),
            .collection_view => |value| try emitCollectionView(allocator, bytes, &epilogue_fixups, value),
            .aggregate_equal => |value| try emitAggregateEqual(allocator, bytes, value),
            .class_init => |value| try emitClassInit(allocator, bytes, windows_import_sites, platform, &epilogue_fixups, value),
            .class_load => |value| {
                try emitClassLoad(allocator, bytes, value);
            },
            .class_store => |value| try emitClassStore(allocator, bytes, value),
            .class_retain, .class_drop, .list_retain, .list_drop => {},
            .string_retain => |value| try emitStringRetain(allocator, bytes, value),
            .string_drop => |value| try emitStringDrop(allocator, bytes, windows_import_sites, platform, value),
            .enum_init => |initialization| {
                try emitImmediate(allocator, bytes, .rax, initialization.tag);
                for (0..initialization.result.width) |index| {
                    if (index != 0) try emitImmediate(allocator, bytes, .rax, 0);
                    try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, initialization.result.start) + index));
                }
                if (initialization.raw_value) |raw_value| switch (raw_value) {
                    .integer => |value| {
                        try emitImmediate(allocator, bytes, .rax, value);
                        try emitStoreStack(allocator, bytes, .rax, initialization.result.start + 1);
                    },
                    .string => |string| try emitStringAddress(allocator, bytes, data_fixups, string, initialization.result.start + 1),
                };
                var destination_offset: usize = 1;
                for (initialization.values) |value| {
                    for (0..value.width) |leaf| {
                        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.start) + leaf));
                        try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, initialization.result.start) + destination_offset + leaf));
                    }
                    destination_offset += value.width;
                }
            },
            .enum_test => |value| {
                try emitLoadStack(allocator, bytes, .rax, value.operand.start);
                try emitImmediate(allocator, bytes, .rcx, value.tag);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xc8, 0x0f, 0x94, 0xc0, 0x48, 0x0f, 0xb6, 0xc0 });
                try emitStoreStack(allocator, bytes, .rax, value.result);
            },
            .convert => |conversion| {
                if (!conversion.source.isFloat() and conversion.target.isFloat()) {
                    try emitLoadStack(allocator, bytes, .rax, conversion.operand);
                    try bytes.appendSlice(allocator, if (conversion.target == .float32)
                        &.{ 0xf3, 0x48, 0x0f, 0x2a, 0xc0 }
                    else
                        &.{ 0xf2, 0x48, 0x0f, 0x2a, 0xc0 });
                    try emitStoreFloatStack(allocator, bytes, 0, conversion.result, conversion.target == .float64);
                } else if (conversion.source.isFloat() and !conversion.target.isFloat()) {
                    try emitLoadFloatStack(allocator, bytes, 0, conversion.operand, conversion.source == .float64);
                    try bytes.appendSlice(allocator, if (conversion.source == .float32)
                        &.{ 0xf3, 0x48, 0x0f, 0x2c, 0xc0 }
                    else
                        &.{ 0xf2, 0x48, 0x0f, 0x2c, 0xc0 });
                    try emitStoreStack(allocator, bytes, .rax, conversion.result);
                } else {
                    try emitLoadStack(allocator, bytes, .rax, conversion.operand);
                    try emitStoreStack(allocator, bytes, .rax, conversion.result);
                }
            },
            .format_value => |format| try TextRuntime.emit(
                allocator,
                bytes,
                float_calls,
                data_fixups,
                windows_import_sites,
                platform,
                &epilogue_fixups,
                format,
            ),
            .unary => |unary| {
                try emitLoadStack(allocator, bytes, .rax, unary.operand);
                if (unary.type == .float32) {
                    try bytes.append(allocator, 0x35);
                    try appendInt(allocator, bytes, u32, 0x8000_0000);
                } else if (unary.type == .float64) {
                    try emitImmediate(allocator, bytes, .rcx, 0x8000_0000_0000_0000);
                    try bytes.appendSlice(allocator, &.{ 0x48, 0x31, 0xc8 });
                } else {
                    try bytes.appendSlice(allocator, &.{ 0x48, 0xf7, 0xd8 });
                }
                try emitStoreStack(allocator, bytes, .rax, unary.result);
            },
            .binary => |binary| try emitBinary(allocator, bytes, binary),
            .string_byte_at => |access| {
                try emitLoadStack(allocator, bytes, .rax, access.operand);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc0, 8 });
                try emitLoadStack(allocator, bytes, .rcx, access.index);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x01, 0xc8, 0x48, 0x0f, 0xb6, 0x00 });
                try emitStoreStack(allocator, bytes, .rax, access.result);
            },
            .string_byte_count => |value| {
                try emitLoadStack(allocator, bytes, .rax, value.operand);
                try emitLoadMemory(allocator, bytes, .rax, .rax, 0);
                try emitMaskDynamicStringLength(allocator, bytes, .rax);
                try emitStoreStack(allocator, bytes, .rax, value.result);
            },
            .string_from_bytes => |value| try emitStringFromBytes(allocator, bytes, windows_import_sites, platform, &epilogue_fixups, value),
            .string_concat => |value| try emitStringConcat(allocator, bytes, windows_import_sites, platform, &epilogue_fixups, value),
            .string_count => |value| try emitStringCount(allocator, bytes, value),
            .function_address => |address| {
                try bytes.appendSlice(allocator, &.{ 0x48, 0x8d, 0x05 });
                const displacement_at = bytes.items.len;
                try bytes.appendNTimes(allocator, 0, 4);
                try function_addresses.append(allocator, .{ .displacement_at = displacement_at, .function = address.function });
                try emitStoreStack(allocator, bytes, .rax, address.result.start);
                if (address.environment) |environment| {
                    for (address.captures, 0..) |capture, index| {
                        try emitLoadStack(allocator, bytes, .rax, capture);
                        try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, environment.start) + index));
                    }
                    try emitAddressStack(allocator, bytes, .rax, environment.start);
                } else try emitImmediate(allocator, bytes, .rax, 0);
                try emitStoreStack(allocator, bytes, .rax, address.result.start + 1);
            },
            .call => |call| {
                if (call.result) |result| if (result.aggregate) try emitAddressStack(allocator, bytes, .r15, result.start);
                const outgoing_stack_size = try emitInternalCallArguments(allocator, bytes, call.arguments, &argument_registers);
                try appendCall(allocator, bytes, calls, call.function);
                try emitStackAddition(allocator, bytes, outgoing_stack_size);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xd2 });
                try appendConditionalEpilogue(allocator, bytes, &epilogue_fixups, 0x85);
                if (call.result) |result| {
                    if (!result.aggregate) {
                        if (result.width != 1) return error.InvalidMachineProgram;
                        try emitStoreStack(allocator, bytes, .rax, result.start);
                    }
                }
            },
            .indirect_call => |call| {
                if (call.result) |result| if (result.aggregate) try emitAddressStack(allocator, bytes, .r15, result.start);
                const outgoing_stack_size = try emitInternalCallArguments(allocator, bytes, call.arguments, &argument_registers);
                try emitLoadStack(allocator, bytes, .r12, call.callee + 1);
                try emitLoadStack(allocator, bytes, .rax, call.callee);
                try bytes.appendSlice(allocator, &.{ 0xff, 0xd0 });
                try emitStackAddition(allocator, bytes, outgoing_stack_size);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xd2 });
                try appendConditionalEpilogue(allocator, bytes, &epilogue_fixups, 0x85);
                if (call.result) |result| if (!result.aggregate) try emitStoreStack(allocator, bytes, .rax, result.start);
            },
            .external_call => |call| try ExternalCalls.emit(allocator, bytes, windows_import_sites, external_call_sites, platform, program, function, call),
            .mutex_lock => try emitMutexOperation(allocator, bytes, global_fixups, windows_import_sites, platform, program, true),
            .mutex_unlock => try emitMutexOperation(allocator, bytes, global_fixups, windows_import_sites, platform, program, false),
            .print => |value| switch (value.kind) {
                .signed_integer, .unsigned_integer => try emitPrintInteger(allocator, bytes, windows_import_sites, platform, value.value, value.newline, value.kind == .signed_integer),
                .boolean => try emitPrintBoolean(allocator, bytes, data_fixups, windows_import_sites, platform, value.value, value.newline),
                .string => try emitPrintString(allocator, bytes, data_fixups, windows_import_sites, platform, value.value, value.newline),
                .float32, .float64 => return unsupported("floating-point print"),
            },
            .assert => |assertion| {
                try emitLoadStack(allocator, bytes, .rax, assertion.condition);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0, 0x0f, 0x85 });
                const passed = bytes.items.len;
                try bytes.appendNTimes(allocator, 0, 4);
                try emitWriteStatic(allocator, bytes, data_fixups, assertion.header);
                try emitWriteStringSlot(allocator, bytes, assertion.message);
                try emitRuntimeFailure(allocator, bytes, &epilogue_fixups);
                try patchRelative(bytes.items, passed, bytes.items.len);
            },
            .panic => |panic_value| {
                try emitWriteStatic(allocator, bytes, data_fixups, panic_value.header);
                try emitWriteStringSlot(allocator, bytes, panic_value.message);
                try emitRuntimeFailure(allocator, bytes, &epilogue_fixups);
            },
            .return_value => |value| {
                if (value.aggregate) {
                    const hidden = function.hidden_return_slot orelse return error.InvalidMachineProgram;
                    try emitLoadStack(allocator, bytes, .r15, hidden);
                    for (0..value.width) |leaf| {
                        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.start) + leaf));
                        try emitStoreMemory(allocator, bytes, .r15, -@as(i32, @intCast(leaf * Machine.slot_size)), .rax);
                    }
                    try emitImmediate(allocator, bytes, .rax, 0);
                } else {
                    if (value.width != 1) return error.InvalidMachineProgram;
                    try emitLoadStack(allocator, bytes, .rax, value.start);
                }
                try bytes.appendSlice(allocator, &.{ 0x31, 0xd2 });
                try appendEpilogueJump(allocator, bytes, &epilogue_fixups);
            },
            .return_void => {
                try bytes.appendSlice(allocator, &.{ 0x31, 0xc0, 0x31, 0xd2 });
                try appendEpilogueJump(allocator, bytes, &epilogue_fixups);
            },
            .jump => |target| try appendBranch(allocator, bytes, &branches, target),
            .branch => |branch| {
                try emitLoadStack(allocator, bytes, .rax, branch.condition);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0, 0x0f, 0x85 });
                const then_at = bytes.items.len;
                try bytes.appendNTimes(allocator, 0, 4);
                try branches.append(allocator, .{ .displacement_at = then_at, .instruction = branch.then_instruction });
                try appendBranch(allocator, bytes, &branches, branch.else_instruction);
            },
            else => {
                std.debug.print("x64 unsupported machine instruction: {s}\n", .{@tagName(instruction)});
                return error.UnsupportedInstruction;
            },
        }
    }
    instruction_offsets[function.instructions.len] = bytes.items.len;
    const epilogue = bytes.items.len;
    try bytes.appendSlice(allocator, &.{ 0xc9, 0xc3 });
    for (branches.items) |branch| {
        if (branch.instruction > function.instructions.len) return error.InvalidMachineProgram;
        try patchRelative(bytes.items, branch.displacement_at, instruction_offsets[branch.instruction]);
    }
    for (epilogue_fixups.items) |fixup| try patchRelative(bytes.items, fixup.displacement_at, epilogue);
}

fn emitBinary(allocator: Allocator, bytes: *std.ArrayList(u8), binary: Machine.Instruction.Binary) Error!void {
    if (binary.type.isFloat()) return emitFloatBinary(allocator, bytes, binary);
    if (binary.type == .str) return emitStringBinary(allocator, bytes, binary);
    try emitLoadStack(allocator, bytes, .rax, binary.left);
    try emitLoadStack(allocator, bytes, .rcx, binary.right);
    switch (binary.operator) {
        .add => try bytes.appendSlice(allocator, &.{ 0x48, 0x01, 0xc8 }),
        .subtract => try bytes.appendSlice(allocator, &.{ 0x48, 0x29, 0xc8 }),
        .multiply => try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xaf, 0xc1 }),
        .bit_and => try bytes.appendSlice(allocator, &.{ 0x48, 0x21, 0xc8 }),
        .bit_xor => try bytes.appendSlice(allocator, &.{ 0x48, 0x31, 0xc8 }),
        .shift_left => try bytes.appendSlice(allocator, &.{ 0x48, 0xd3, 0xe0 }),
        .shift_right => try bytes.appendSlice(allocator, if (binary.type.isSignedInteger()) &.{ 0x48, 0xd3, 0xf8 } else &.{ 0x48, 0xd3, 0xe8 }),
        .divide, .remainder => {
            if (binary.type.isSignedInteger()) {
                try bytes.appendSlice(allocator, &.{ 0x48, 0x99, 0x48, 0xf7, 0xf9 });
            } else {
                try bytes.appendSlice(allocator, &.{ 0x31, 0xd2, 0x48, 0xf7, 0xf1 });
            }
            if (binary.operator == .remainder) try emitMoveRegister(allocator, bytes, .rax, .rdx);
        },
        .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => {
            try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xc8, 0x0f });
            const signed = binary.type.isSignedInteger();
            const condition: u8 = switch (binary.operator) {
                .less => if (signed) 0x9c else 0x92,
                .less_equal => if (signed) 0x9e else 0x96,
                .greater => if (signed) 0x9f else 0x97,
                .greater_equal => if (signed) 0x9d else 0x93,
                .equal => 0x94,
                .not_equal => 0x95,
                else => unreachable,
            };
            try bytes.appendSlice(allocator, &.{ condition, 0xc0, 0x48, 0x0f, 0xb6, 0xc0 });
        },
    }
    try emitStoreStack(allocator, bytes, .rax, binary.result);
}

fn emitStringBinary(allocator: Allocator, bytes: *std.ArrayList(u8), binary: Machine.Instruction.Binary) Error!void {
    if (binary.operator != .equal and binary.operator != .not_equal) return unsupported("ordered string binary");
    try emitLoadStack(allocator, bytes, .rbx, binary.left);
    try emitLoadStack(allocator, bytes, .r12, binary.right);
    try emitLoadMemory(allocator, bytes, .rcx, .rbx, 0);
    try emitLoadMemory(allocator, bytes, .rdx, .r12, 0);
    try emitMaskDynamicStringLength(allocator, bytes, .rcx);
    try emitMaskDynamicStringLength(allocator, bytes, .rdx);
    try emitImmediate(allocator, bytes, .r13, @intFromBool(binary.operator == .not_equal));
    try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xd1, 0x0f, 0x85 });
    const unequal_length = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitImmediate(allocator, bytes, .r13, @intFromBool(binary.operator == .equal));
    try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc9, 0x0f, 0x84 });
    const finished_empty = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 8, 0x49, 0x83, 0xc4, 8 });
    const loop = bytes.items.len;
    try emitLoadMemory(allocator, bytes, .rax, .rbx, 0);
    try emitLoadMemory(allocator, bytes, .r8, .r12, 0);
    try bytes.appendSlice(allocator, &.{ 0x4c, 0x31, 0xc0, 0x48, 0x25, 0xff, 0, 0, 0, 0x0f, 0x85 });
    const unequal_byte = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 1, 0x49, 0x83, 0xc4, 1, 0x48, 0x83, 0xe9, 1, 0x0f, 0x85 });
    const repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, repeat, loop);
    try bytes.append(allocator, 0xe9);
    const finished_equal = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    const unequal = bytes.items.len;
    try emitImmediate(allocator, bytes, .r13, @intFromBool(binary.operator == .not_equal));
    const finished = bytes.items.len;
    try patchRelative(bytes.items, unequal_length, unequal);
    try patchRelative(bytes.items, unequal_byte, unequal);
    try patchRelative(bytes.items, finished_empty, finished);
    try patchRelative(bytes.items, finished_equal, finished);
    try emitStoreStack(allocator, bytes, .r13, binary.result);
}

fn emitAggregateEqual(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    value: Machine.Instruction.AggregateEqual,
) Error!void {
    if (value.left.width != value.right.width) return error.InvalidMachineProgram;
    try emitImmediate(allocator, bytes, .r13, @intFromBool(value.equal));
    var mismatches: std.ArrayList(usize) = .empty;
    defer mismatches.deinit(allocator);
    for (value.leaves) |leaf| {
        var guard_skips: std.ArrayList(usize) = .empty;
        defer guard_skips.deinit(allocator);
        for (leaf.guards) |guard| {
            try emitLoadStack(allocator, bytes, .rax, value.left.start + guard.offset);
            try emitImmediate(allocator, bytes, .rcx, guard.expected);
            try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xc8, 0x0f, 0x85 });
            try guard_skips.append(allocator, bytes.items.len);
            try bytes.appendNTimes(allocator, 0, 4);
        }
        try emitBinary(allocator, bytes, .{
            .result = value.result,
            .operator = .equal,
            .left = value.left.start + leaf.offset,
            .right = value.right.start + leaf.offset,
            .type = leaf.type,
        });
        try emitLoadStack(allocator, bytes, .rax, value.result);
        try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0, 0x0f, 0x84 });
        try mismatches.append(allocator, bytes.items.len);
        try bytes.appendNTimes(allocator, 0, 4);
        for (guard_skips.items) |site| try patchRelative(bytes.items, site, bytes.items.len);
    }
    try bytes.append(allocator, 0xe9);
    const finished_equal = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    const mismatch = bytes.items.len;
    try emitImmediate(allocator, bytes, .r13, @intFromBool(!value.equal));
    const finished = bytes.items.len;
    for (mismatches.items) |site| try patchRelative(bytes.items, site, mismatch);
    try patchRelative(bytes.items, finished_equal, finished);
    try emitStoreStack(allocator, bytes, .r13, value.result);
}

fn emitFloatBinary(allocator: Allocator, bytes: *std.ArrayList(u8), binary: Machine.Instruction.Binary) Error!void {
    const double = binary.type == .float64;
    try emitLoadFloatStack(allocator, bytes, 0, binary.left, double);
    try emitLoadFloatStack(allocator, bytes, 1, binary.right, double);
    switch (binary.operator) {
        .add, .subtract, .multiply, .divide => {
            try bytes.append(allocator, if (double) 0xf2 else 0xf3);
            try bytes.appendSlice(allocator, &.{ 0x0f, switch (binary.operator) {
                .add => 0x58,
                .subtract => 0x5c,
                .multiply => 0x59,
                .divide => 0x5e,
                else => unreachable,
            }, 0xc1 });
            try emitStoreFloatStack(allocator, bytes, 0, binary.result, double);
        },
        .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => {
            if (double) try bytes.append(allocator, 0x66);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x2e, 0xc1 });
            const condition: u8 = switch (binary.operator) {
                .less => 0x92,
                .less_equal => 0x96,
                .greater => 0x97,
                .greater_equal => 0x93,
                .equal => 0x94,
                .not_equal => 0x95,
                else => unreachable,
            };
            try bytes.appendSlice(allocator, &.{ 0x0f, condition, 0xc0, 0x48, 0x0f, 0xb6, 0xc0 });
            try emitStoreStack(allocator, bytes, .rax, binary.result);
        },
        else => return error.UnsupportedInstruction,
    }
}

fn emitClassInit(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.ClassInit,
) Error!void {
    var width: usize = 0;
    for (value.fields) |field| width += field.width;
    switch (platform) {
        .linux => {
            try emitImmediate(allocator, bytes, .rax, 9);
            try emitImmediate(allocator, bytes, .rdi, 0);
            try emitImmediate(allocator, bytes, .rsi, (width + 3) * Machine.slot_size);
            try emitImmediate(allocator, bytes, .rdx, 3);
            try emitImmediate(allocator, bytes, .r10, 0x22);
            try emitImmediate(allocator, bytes, .r8, std.math.maxInt(u64));
            try emitImmediate(allocator, bytes, .r9, 0);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });
        },
        .windows => {
            try emitImmediate(allocator, bytes, .rcx, 0);
            try emitImmediate(allocator, bytes, .rdx, (width + 3) * Machine.slot_size);
            try emitImmediate(allocator, bytes, .r8, 0x3000);
            try emitImmediate(allocator, bytes, .r9, 4);
            try ExternalCalls.emitWindowsImportCall(allocator, bytes, import_sites, .virtual_alloc);
        },
    }
    try emitMoveRegister(allocator, bytes, .rbx, .rax);
    try emitImmediate(allocator, bytes, .rcx, value.structure);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0x0b, 0x48, 0xc7, 0x43, 0x08, 0, 0, 0, 0, 0x48, 0xc7, 0x43, 0x10, 0, 0, 0, 0 });
    var offset: u32 = 24;
    for (value.fields) |field| for (0..field.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, field.start) + leaf));
        try emitStoreMemory(allocator, bytes, .rbx, @intCast(offset), .rax);
        offset += Machine.slot_size;
    };
    try emitStoreStack(allocator, bytes, .rbx, value.result);
    _ = epilogue;
}

fn emitClassLoad(allocator: Allocator, bytes: *std.ArrayList(u8), value: Machine.Instruction.ClassLoad) Error!void {
    try emitLoadStack(allocator, bytes, .rbx, value.base);
    for (0..value.result.width) |leaf| {
        try emitLoadMemory(allocator, bytes, .rax, .rbx, @intCast(24 + value.byte_offset + leaf * Machine.slot_size));
        try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, value.result.start) + leaf));
    }
}

fn emitClassStore(allocator: Allocator, bytes: *std.ArrayList(u8), value: Machine.Instruction.ClassStore) Error!void {
    try emitLoadStack(allocator, bytes, .rbx, value.base);
    try emitStoreStack(allocator, bytes, .rbx, value.result);
    for (0..value.replacement.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.replacement.start) + leaf));
        try emitStoreMemory(allocator, bytes, .rbx, @intCast(24 + value.byte_offset + leaf * Machine.slot_size), .rax);
    }
}

fn emitRuntimeFailure(allocator: Allocator, bytes: *std.ArrayList(u8), epilogue: *std.ArrayList(EpilogueFixup)) Allocator.Error!void {
    try emitImmediate(allocator, bytes, .rdx, @intFromEnum(Machine.Status.runtime_failure));
    try appendEpilogueJump(allocator, bytes, epilogue);
}

fn emitPrintInteger(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    slot: Machine.Slot,
    newline: bool,
    signed: bool,
) Error!void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xec, 40 });
    try bytes.appendSlice(allocator, &.{ 0x48, 0x8d, 0x74, 0x24, 39 });
    if (newline) {
        try bytes.appendSlice(allocator, &.{ 0xc6, 0x06, '\n' });
        try emitImmediate(allocator, bytes, .r8, 1);
    } else try emitImmediate(allocator, bytes, .r8, 0);
    try emitLoadStack(allocator, bytes, .rax, slot);
    try emitImmediate(allocator, bytes, .r9, 0);
    if (signed) {
        try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0, 0x0f, 0x89 });
        const nonnegative = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, 4);
        try emitImmediate(allocator, bytes, .r9, 1);
        try bytes.appendSlice(allocator, &.{ 0x48, 0xf7, 0xd8 });
        try patchRelative(bytes.items, nonnegative, bytes.items.len);
    }
    try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0, 0x0f, 0x85 });
    const nonzero = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try bytes.appendSlice(allocator, &.{ 0x48, 0xff, 0xce, 0xc6, 0x06, '0', 0x49, 0xff, 0xc0, 0xe9 });
    const finished = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    const loop = bytes.items.len;
    try emitImmediate(allocator, bytes, .rcx, 10);
    try bytes.appendSlice(allocator, &.{ 0x31, 0xd2, 0x48, 0xf7, 0xf1, 0x80, 0xc2, '0', 0x48, 0xff, 0xce, 0x88, 0x16, 0x49, 0xff, 0xc0, 0x48, 0x85, 0xc0, 0x0f, 0x85 });
    const repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, nonzero, loop);
    try patchRelative(bytes.items, repeat, loop);
    try patchRelative(bytes.items, finished, bytes.items.len);
    if (signed) {
        try bytes.appendSlice(allocator, &.{ 0x4d, 0x85, 0xc9, 0x0f, 0x84 });
        const unsigned = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, 4);
        try bytes.appendSlice(allocator, &.{ 0x48, 0xff, 0xce, 0xc6, 0x06, '-', 0x49, 0xff, 0xc0 });
        try patchRelative(bytes.items, unsigned, bytes.items.len);
    }
    try emitWriteBuffer(allocator, bytes, import_sites, platform, 1, .rsi, .r8);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc4, 40 });
}

fn emitPrintBoolean(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    data_fixups: *std.ArrayList(DataFixup),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    slot: Machine.Slot,
    newline: bool,
) Error!void {
    try emitLoadStack(allocator, bytes, .rax, slot);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0, 0x0f, 0x84 });
    const use_false = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitPrintStatic(allocator, bytes, data_fixups, import_sites, platform, 1);
    try bytes.append(allocator, 0xe9);
    const finished = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, use_false, bytes.items.len);
    try emitPrintStatic(allocator, bytes, data_fixups, import_sites, platform, 2);
    try patchRelative(bytes.items, finished, bytes.items.len);
    if (newline) try emitPrintStatic(allocator, bytes, data_fixups, import_sites, platform, 0);
}

fn emitPrintString(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    data_fixups: *std.ArrayList(DataFixup),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    slot: Machine.Slot,
    newline: bool,
) Error!void {
    try emitLoadStack(allocator, bytes, .rsi, slot);
    try emitLoadMemory(allocator, bytes, .r8, .rsi, 0);
    try emitMaskDynamicStringLength(allocator, bytes, .r8);
    try emitAddImmediateRegister(allocator, bytes, .rsi, 8);
    try emitWriteBuffer(allocator, bytes, import_sites, platform, 1, .rsi, .r8);
    if (newline) try emitPrintStatic(allocator, bytes, data_fixups, import_sites, platform, 0);
}

fn emitPrintStatic(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    data_fixups: *std.ArrayList(DataFixup),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    string: usize,
) Error!void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0x8d, 0x35 });
    const displacement_at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try data_fixups.append(allocator, .{ .displacement_at = displacement_at, .string = string });
    try emitLoadMemory(allocator, bytes, .r8, .rsi, 0);
    try emitAddImmediateRegister(allocator, bytes, .rsi, 8);
    try emitWriteBuffer(allocator, bytes, import_sites, platform, 1, .rsi, .r8);
}

fn emitWriteBuffer(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    descriptor: u64,
    address: Register,
    count: Register,
) Error!void {
    switch (platform) {
        .linux => {
            if (address != .rsi) try emitMoveRegister(allocator, bytes, .rsi, address);
            if (count != .rdx) try emitMoveRegister(allocator, bytes, .rdx, count);
            try emitImmediate(allocator, bytes, .rax, 1);
            try emitImmediate(allocator, bytes, .rdi, descriptor);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });
        },
        .windows => {
            if (address != .rdx) try emitMoveRegister(allocator, bytes, .rdx, address);
            if (count != .r8) try emitMoveRegister(allocator, bytes, .r8, count);
            try emitImmediate(allocator, bytes, .rcx, descriptor);
            try ExternalCalls.emitWindowsImportCall(allocator, bytes, import_sites, .crt_write);
        },
    }
}

fn emitWriteStatic(allocator: Allocator, bytes: *std.ArrayList(u8), fixups: *std.ArrayList(DataFixup), string: usize) Allocator.Error!void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0x8d, 0x35 });
    const displacement_at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try fixups.append(allocator, .{ .displacement_at = displacement_at, .string = string });
    try bytes.appendSlice(allocator, &.{ 0x48, 0x8b, 0x16, 0x48, 0x83, 0xc6, 0x08 });
    try emitImmediate(allocator, bytes, .rax, 1);
    try emitImmediate(allocator, bytes, .rdi, 2);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });
}

fn emitWriteStringSlot(allocator: Allocator, bytes: *std.ArrayList(u8), slot: Machine.Slot) Allocator.Error!void {
    try emitLoadStack(allocator, bytes, .rsi, slot);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x8b, 0x16, 0x48, 0x83, 0xc6, 0x08 });
    try emitMaskDynamicStringLength(allocator, bytes, .rdx);
    try emitImmediate(allocator, bytes, .rax, 1);
    try emitImmediate(allocator, bytes, .rdi, 2);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });
}

fn emitStringAddress(allocator: Allocator, bytes: *std.ArrayList(u8), fixups: *std.ArrayList(DataFixup), string: usize, result: Machine.Slot) Allocator.Error!void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0x8d, 0x05 });
    const displacement_at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try fixups.append(allocator, .{ .displacement_at = displacement_at, .string = string });
    try emitStoreStack(allocator, bytes, .rax, result);
}

fn emitCopyRange(allocator: Allocator, bytes: *std.ArrayList(u8), destination: Machine.Span, source: Machine.Span) Error!void {
    if (destination.width != source.width) return error.InvalidMachineProgram;
    for (0..destination.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, source.start) + leaf));
        try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, destination.start) + leaf));
    }
}

fn emitAllocation(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
) Error!void {
    switch (platform) {
        .linux => {
            try emitImmediate(allocator, bytes, .rdi, 0);
            try emitImmediate(allocator, bytes, .rdx, 3);
            try emitImmediate(allocator, bytes, .r10, 0x22);
            try emitImmediate(allocator, bytes, .r8, std.math.maxInt(u64));
            try emitImmediate(allocator, bytes, .r9, 0);
            try emitImmediate(allocator, bytes, .rax, 9);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05, 0x48, 0x3d });
            try appendInt(allocator, bytes, i32, -4095);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x82 });
        },
        .windows => {
            try emitImmediate(allocator, bytes, .rcx, 0);
            try emitMoveRegister(allocator, bytes, .rdx, .rsi);
            try emitImmediate(allocator, bytes, .r8, 0x3000);
            try emitImmediate(allocator, bytes, .r9, 4);
            try ExternalCalls.emitWindowsImportCall(allocator, bytes, import_sites, .virtual_alloc);
            try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0, 0x0f, 0x85 });
        },
    }
    const succeeded = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitRuntimeFailure(allocator, bytes, epilogue);
    try patchRelative(bytes.items, succeeded, bytes.items.len);
}

fn emitListInit(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.ListInit,
) Error!void {
    const allocation_size = 8 + @as(u64, value.values.len) * value.element_width * Machine.slot_size;
    try emitImmediate(allocator, bytes, .rsi, allocation_size);
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r10, .rax);
    try emitImmediate(allocator, bytes, .rax, value.values.len);
    try emitStoreMemory(allocator, bytes, .r10, 0, .rax);
    var offset: i32 = 8;
    for (value.values) |item| for (0..item.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, item.start) + leaf));
        try emitStoreMemory(allocator, bytes, .r10, offset, .rax);
        offset += Machine.slot_size;
    };
    try emitStoreStack(allocator, bytes, .r10, value.result);
}

fn emitBytesLiteral(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    data_fixups: *std.ArrayList(DataFixup),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
    program: Machine.Program,
    value: Machine.Instruction.ConstantBytes,
) Error!void {
    if (value.string >= program.strings.len) return error.InvalidMachineProgram;
    const count = program.strings[value.string].len;
    try emitImmediate(allocator, bytes, .rsi, 8 + @as(u64, count) * Machine.slot_size);
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r15, .rax);
    try emitImmediate(allocator, bytes, .rax, count);
    try emitStoreMemory(allocator, bytes, .r15, 0, .rax);
    if (count != 0) {
        try emitStringAddress(allocator, bytes, data_fixups, value.string, value.result);
        try emitLoadStack(allocator, bytes, .rbx, value.result);
        try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 8 });
        try emitMoveRegister(allocator, bytes, .r14, .r15);
        try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xc6, 8 });
        try emitImmediate(allocator, bytes, .rsi, count);
        const loop = bytes.items.len;
        try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xb6, 0x03 });
        try emitStoreMemory(allocator, bytes, .r14, 0, .rax);
        try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 1, 0x49, 0x83, 0xc6, 8, 0x48, 0x83, 0xee, 1, 0x0f, 0x85 });
        const repeat = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, 4);
        try patchRelative(bytes.items, repeat, loop);
    }
    try emitStoreStack(allocator, bytes, .r15, value.result);
}

fn emitCollectionCount(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    value: Machine.Instruction.CollectionCount,
) Error!void {
    if (value.view) {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.collection.start) + 1));
    } else {
        try emitLoadStack(allocator, bytes, .rcx, value.collection.start);
        try emitLoadMemory(allocator, bytes, .rax, .rcx, 0);
    }
    try emitStoreStack(allocator, bytes, .rax, value.result);
}

fn emitDynamicCollectionLoad(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.CollectionLoad,
) Error!void {
    if (value.view) {
        try emitLoadStack(allocator, bytes, .rbx, value.collection.start);
        try emitLoadStack(allocator, bytes, .rcx, @intCast(@as(usize, value.collection.start) + 1));
    } else {
        try emitLoadStack(allocator, bytes, .rbx, value.collection.start);
        try emitLoadMemory(allocator, bytes, .rcx, .rbx, 0);
        try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 8 });
    }
    try emitLoadStack(allocator, bytes, .rax, value.index);
    if (value.checked) {
        try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xc8, 0x0f, 0x82 });
        const in_bounds = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, 4);
        try emitRuntimeFailure(allocator, bytes, epilogue);
        try patchRelative(bytes.items, in_bounds, bytes.items.len);
    }
    try bytes.appendSlice(allocator, &.{ 0x48, 0x69, 0xc0 });
    try appendInt(allocator, bytes, u32, @as(u32, value.result.width) * Machine.slot_size);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x01, 0xc3 });
    for (0..value.result.width) |leaf| {
        try emitLoadMemory(allocator, bytes, .rax, .rbx, @intCast(leaf * Machine.slot_size));
        try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, value.result.start) + leaf));
    }
}

fn emitCollectionReference(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.CollectionReference,
) Error!void {
    if (value.dynamic) {
        try emitLoadStack(allocator, bytes, .rbx, value.collection.start);
        if (value.view) {
            try emitLoadStack(allocator, bytes, .rcx, @intCast(@as(usize, value.collection.start) + 1));
        } else {
            try emitLoadMemory(allocator, bytes, .rcx, .rbx, 0);
            try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 8 });
        }
    } else {
        try emitLoadStack(allocator, bytes, .rbx, value.reference orelse return error.InvalidMachineProgram);
        try emitImmediate(allocator, bytes, .rcx, value.count);
    }
    try emitLoadStack(allocator, bytes, .rax, value.index);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xc8, 0x0f, 0x82 });
    const in_bounds = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitRuntimeFailure(allocator, bytes, epilogue);
    try patchRelative(bytes.items, in_bounds, bytes.items.len);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x69, 0xc0 });
    try appendInt(allocator, bytes, u32, @as(u32, value.element_width) * Machine.slot_size);
    if (value.dynamic) {
        try bytes.appendSlice(allocator, &.{ 0x48, 0x01, 0xd8 });
        try emitStoreStack(allocator, bytes, .rax, value.result);
    } else {
        try bytes.appendSlice(allocator, &.{ 0x48, 0x29, 0xc3 });
        try emitStoreStack(allocator, bytes, .rbx, value.result);
    }
}

fn emitViewReplace(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.CollectionReplace,
) Error!void {
    try emitLoadStack(allocator, bytes, .rbx, value.collection.start);
    try emitLoadStack(allocator, bytes, .rcx, @intCast(@as(usize, value.collection.start) + 1));
    try emitLoadStack(allocator, bytes, .rax, value.index);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xc8, 0x0f, 0x82 });
    const in_bounds = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitRuntimeFailure(allocator, bytes, epilogue);
    try patchRelative(bytes.items, in_bounds, bytes.items.len);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x69, 0xc0 });
    try appendInt(allocator, bytes, u32, @as(u32, value.replacement.width) * Machine.slot_size);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x01, 0xc3 });
    for (0..value.replacement.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.replacement.start) + leaf));
        try emitStoreMemory(allocator, bytes, .rbx, @intCast(leaf * Machine.slot_size), .rax);
    }
    try emitCopyRange(allocator, bytes, value.result, value.collection);
}

fn emitDynamicReplace(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.CollectionReplace,
) Error!void {
    try emitLoadStack(allocator, bytes, .rbx, value.collection.start);
    try emitLoadMemory(allocator, bytes, .r12, .rbx, 0);
    try emitLoadStack(allocator, bytes, .r13, value.index);
    try bytes.appendSlice(allocator, &.{ 0x4d, 0x39, 0xe5, 0x0f, 0x82 });
    const in_bounds = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitRuntimeFailure(allocator, bytes, epilogue);
    try patchRelative(bytes.items, in_bounds, bytes.items.len);

    try emitMoveRegister(allocator, bytes, .rsi, .r12);
    try emitImmediate(allocator, bytes, .rcx, @as(u64, value.replacement.width) * Machine.slot_size);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xaf, 0xf1, 0x48, 0x83, 0xc6, 8 });
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r15, .rax);
    try emitStoreMemory(allocator, bytes, .r15, 0, .r12);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 8 });
    try emitMoveRegister(allocator, bytes, .r14, .r15);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xc6, 8 });
    try emitMoveRegister(allocator, bytes, .rsi, .r12);
    try emitImmediate(allocator, bytes, .rcx, value.replacement.width);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xaf, 0xf1, 0x48, 0x85, 0xf6, 0x0f, 0x84 });
    const copied = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    const copy_loop = bytes.items.len;
    try emitLoadMemory(allocator, bytes, .rax, .rbx, 0);
    try emitStoreMemory(allocator, bytes, .r14, 0, .rax);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 8, 0x49, 0x83, 0xc6, 8, 0x48, 0x83, 0xee, 1, 0x0f, 0x85 });
    const copy_repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, copy_repeat, copy_loop);
    try patchRelative(bytes.items, copied, bytes.items.len);

    try emitMoveRegister(allocator, bytes, .r14, .r15);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xc6, 8 });
    try emitMoveRegister(allocator, bytes, .rax, .r13);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x69, 0xc0 });
    try appendInt(allocator, bytes, u32, @as(u32, value.replacement.width) * Machine.slot_size);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x01, 0xc6 });
    for (0..value.replacement.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.replacement.start) + leaf));
        try emitStoreMemory(allocator, bytes, .r14, @intCast(leaf * Machine.slot_size), .rax);
    }
    try emitStoreStack(allocator, bytes, .r15, value.result.start);
}

fn emitFixedReplace(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.CollectionReplace,
) Error!void {
    try emitLoadStack(allocator, bytes, .r13, value.index);
    try emitImmediate(allocator, bytes, .r12, value.count);
    try bytes.appendSlice(allocator, &.{ 0x4d, 0x39, 0xe5, 0x0f, 0x82 });
    const in_bounds = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitRuntimeFailure(allocator, bytes, epilogue);
    try patchRelative(bytes.items, in_bounds, bytes.items.len);
    try emitCopyRange(allocator, bytes, value.result, value.collection);
    try emitAddressStack(allocator, bytes, .r14, value.result.start);
    try emitMoveRegister(allocator, bytes, .rax, .r13);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x69, 0xc0 });
    try appendInt(allocator, bytes, u32, @as(u32, value.replacement.width) * Machine.slot_size);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x29, 0xc6 });
    for (0..value.replacement.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.replacement.start) + leaf));
        try emitStoreMemory(allocator, bytes, .r14, -@as(i32, @intCast(leaf * Machine.slot_size)), .rax);
    }
}

fn emitListEdit(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.ListEdit,
) Error!void {
    if (value.kind == .take_last) {
        return emitListTakeLast(allocator, bytes, import_sites, platform, epilogue, value);
    }
    if (value.kind == .clear) {
        try emitImmediate(allocator, bytes, .rsi, 8);
        try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
        try emitMoveRegister(allocator, bytes, .r10, .rax);
        try emitImmediate(allocator, bytes, .rax, 0);
        try emitStoreMemory(allocator, bytes, .r10, 0, .rax);
        try emitStoreStack(allocator, bytes, .r10, value.result);
        return;
    }
    if (value.kind != .append) {
        return emitGeneralListEdit(allocator, bytes, import_sites, platform, epilogue, value);
    }
    if (value.argument == null) return error.InvalidMachineProgram;
    try emitLoadStack(allocator, bytes, .rbx, value.collection);
    try emitLoadMemory(allocator, bytes, .r12, .rbx, 0);
    try emitMoveRegister(allocator, bytes, .r13, .r12);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xc5, 1 });
    try emitMoveRegister(allocator, bytes, .rsi, .r13);
    try emitImmediate(allocator, bytes, .rcx, @as(u64, value.element_width) * Machine.slot_size);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xaf, 0xf1, 0x48, 0x83, 0xc6, 8 });
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r15, .rax);
    try emitStoreMemory(allocator, bytes, .r15, 0, .r13);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 8 });
    try emitMoveRegister(allocator, bytes, .r14, .r15);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xc6, 8 });
    try emitMoveRegister(allocator, bytes, .r13, .r12);
    try emitImmediate(allocator, bytes, .rcx, value.element_width);
    try bytes.appendSlice(allocator, &.{ 0x4c, 0x0f, 0xaf, 0xe9, 0x4d, 0x85, 0xed, 0x0f, 0x84 });
    const copied = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    const loop = bytes.items.len;
    try emitLoadMemory(allocator, bytes, .rax, .rbx, 0);
    try emitStoreMemory(allocator, bytes, .r14, 0, .rax);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 8, 0x49, 0x83, 0xc6, 8, 0x49, 0x83, 0xed, 1, 0x0f, 0x85 });
    const repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, repeat, loop);
    try patchRelative(bytes.items, copied, bytes.items.len);
    for (0..value.argument.?.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.argument.?.start) + leaf));
        try emitStoreMemory(allocator, bytes, .r14, @intCast(leaf * Machine.slot_size), .rax);
    }
    try emitStoreStack(allocator, bytes, .r15, value.result);
}

fn emitGeneralListEdit(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.ListEdit,
) Error!void {
    try emitLoadStack(allocator, bytes, .rbx, value.collection);
    try emitLoadMemory(allocator, bytes, .r12, .rbx, 0);

    switch (value.kind) {
        .take, .insert => {
            const index = value.index orelse return error.InvalidMachineProgram;
            try emitLoadStack(allocator, bytes, .r13, index);
            try bytes.appendSlice(allocator, &.{ 0x4d, 0x39, 0xe5, 0x0f, if (value.kind == .insert) 0x86 else 0x82 });
            const valid = bytes.items.len;
            try bytes.appendNTimes(allocator, 0, 4);
            try emitRuntimeFailure(allocator, bytes, epilogue);
            try patchRelative(bytes.items, valid, bytes.items.len);
        },
        .take_first => {
            try emitImmediate(allocator, bytes, .r13, 0);
            try bytes.appendSlice(allocator, &.{ 0x4d, 0x85, 0xe4, 0x0f, 0x85 });
            const nonempty = bytes.items.len;
            try bytes.appendNTimes(allocator, 0, 4);
            try emitRuntimeFailure(allocator, bytes, epilogue);
            try patchRelative(bytes.items, nonempty, bytes.items.len);
        },
        .prepend, .append_sequence, .reverse => try emitImmediate(allocator, bytes, .r13, 0),
        .append, .take_last, .clear => return error.InvalidMachineProgram,
    }

    try emitMoveRegister(allocator, bytes, .rsi, .r12);
    switch (value.kind) {
        .prepend, .insert => try emitAddImmediateRegister(allocator, bytes, .rsi, 1),
        .take, .take_first => try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xee, 1 }),
        .append_sequence => {
            const argument = value.argument orelse return error.InvalidMachineProgram;
            if (value.argument_dynamic) {
                try emitLoadStack(allocator, bytes, .rcx, argument.start);
                try emitLoadMemory(allocator, bytes, .rcx, .rcx, 0);
                try emitRegisterBinary(allocator, bytes, 0x01, .rsi, .rcx);
            } else try emitAddImmediateRegister(allocator, bytes, .rsi, value.argument_count);
        },
        .reverse => {},
        .append, .take_last, .clear => unreachable,
    }
    try emitImmediate(allocator, bytes, .rcx, @as(u64, value.element_width) * Machine.slot_size);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xaf, 0xf1 });
    try emitAddImmediateRegister(allocator, bytes, .rsi, 8);
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r15, .rax);

    try emitMoveRegister(allocator, bytes, .rax, .r12);
    switch (value.kind) {
        .prepend, .insert => try emitAddImmediateRegister(allocator, bytes, .rax, 1),
        .take, .take_first => try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xe8, 1 }),
        .append_sequence => {
            if (value.argument_dynamic) {
                try emitLoadStack(allocator, bytes, .rcx, value.argument.?.start);
                try emitLoadMemory(allocator, bytes, .rcx, .rcx, 0);
                try emitRegisterBinary(allocator, bytes, 0x01, .rax, .rcx);
            } else try emitAddImmediateRegister(allocator, bytes, .rax, value.argument_count);
        },
        .reverse => {},
        .append, .take_last, .clear => unreachable,
    }
    try emitStoreMemory(allocator, bytes, .r15, 0, .rax);

    if (value.removed) |removed| {
        try emitLoadStack(allocator, bytes, .r10, value.collection);
        try emitAddImmediateRegister(allocator, bytes, .r10, 8);
        try emitMoveRegister(allocator, bytes, .rax, .r13);
        try bytes.appendSlice(allocator, &.{ 0x48, 0x69, 0xc0 });
        try appendInt(allocator, bytes, u32, @as(u32, value.element_width) * Machine.slot_size);
        try emitRegisterBinary(allocator, bytes, 0x01, .r10, .rax);
        for (0..removed.width) |leaf| {
            try emitLoadMemory(allocator, bytes, .rax, .r10, @intCast(leaf * Machine.slot_size));
            try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, removed.start) + leaf));
        }
    }

    try emitLoadStack(allocator, bytes, .rbx, value.collection);
    try emitAddImmediateRegister(allocator, bytes, .rbx, 8);
    try emitMoveRegister(allocator, bytes, .r14, .r15);
    try emitAddImmediateRegister(allocator, bytes, .r14, 8);
    switch (value.kind) {
        .prepend => {
            try emitListArgument(allocator, bytes, value.argument orelse return error.InvalidMachineProgram);
            try emitMoveRegister(allocator, bytes, .rsi, .r12);
            try emitListCopyElements(allocator, bytes, value.element_width);
        },
        .insert => {
            try emitMoveRegister(allocator, bytes, .rsi, .r13);
            try emitListCopyElements(allocator, bytes, value.element_width);
            try emitListArgument(allocator, bytes, value.argument orelse return error.InvalidMachineProgram);
            try emitMoveRegister(allocator, bytes, .rsi, .r12);
            try bytes.appendSlice(allocator, &.{ 0x4c, 0x29, 0xee });
            try emitListCopyElements(allocator, bytes, value.element_width);
        },
        .take, .take_first => {
            try emitMoveRegister(allocator, bytes, .rsi, .r13);
            try emitListCopyElements(allocator, bytes, value.element_width);
            try emitAddImmediateRegister(allocator, bytes, .rbx, @as(u32, value.element_width) * Machine.slot_size);
            try emitMoveRegister(allocator, bytes, .rsi, .r12);
            try bytes.appendSlice(allocator, &.{ 0x4c, 0x29, 0xee, 0x48, 0x83, 0xee, 1 });
            try emitListCopyElements(allocator, bytes, value.element_width);
        },
        .append_sequence => {
            try emitMoveRegister(allocator, bytes, .rsi, .r12);
            try emitListCopyElements(allocator, bytes, value.element_width);
            if (value.argument_dynamic) {
                try emitLoadStack(allocator, bytes, .rbx, value.argument.?.start);
                try emitLoadMemory(allocator, bytes, .rsi, .rbx, 0);
                try emitAddImmediateRegister(allocator, bytes, .rbx, 8);
                try emitListCopyElements(allocator, bytes, value.element_width);
            } else {
                const argument = value.argument orelse return error.InvalidMachineProgram;
                for (0..argument.width) |leaf| {
                    try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, argument.start) + leaf));
                    try emitStoreMemory(allocator, bytes, .r14, 0, .rax);
                    try emitAddImmediateRegister(allocator, bytes, .r14, Machine.slot_size);
                }
            }
        },
        .reverse => try emitListCopyElementsReversed(allocator, bytes, value.element_width),
        .append, .take_last, .clear => unreachable,
    }
    try emitStoreStack(allocator, bytes, .r15, value.result);
}

fn emitListArgument(allocator: Allocator, bytes: *std.ArrayList(u8), argument: Machine.Span) Error!void {
    for (0..argument.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, argument.start) + leaf));
        try emitStoreMemory(allocator, bytes, .r14, @intCast(leaf * Machine.slot_size), .rax);
    }
    try emitAddImmediateRegister(allocator, bytes, .r14, @as(u32, argument.width) * Machine.slot_size);
}

fn emitListCopyElements(allocator: Allocator, bytes: *std.ArrayList(u8), element_width: u12) Error!void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xf6, 0x0f, 0x84 });
    const copied = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    const loop = bytes.items.len;
    for (0..element_width) |leaf| {
        try emitLoadMemory(allocator, bytes, .rax, .rbx, @intCast(leaf * Machine.slot_size));
        try emitStoreMemory(allocator, bytes, .r14, @intCast(leaf * Machine.slot_size), .rax);
    }
    const stride = @as(u32, element_width) * Machine.slot_size;
    try emitAddImmediateRegister(allocator, bytes, .rbx, stride);
    try emitAddImmediateRegister(allocator, bytes, .r14, stride);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xee, 1, 0x0f, 0x85 });
    const repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, repeat, loop);
    try patchRelative(bytes.items, copied, bytes.items.len);
}

fn emitListCopyElementsReversed(allocator: Allocator, bytes: *std.ArrayList(u8), element_width: u12) Error!void {
    try emitMoveRegister(allocator, bytes, .rsi, .r12);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xf6, 0x0f, 0x84 });
    const copied = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitMoveRegister(allocator, bytes, .rax, .r12);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xe8, 1, 0x48, 0x69, 0xc0 });
    const stride = @as(u32, element_width) * Machine.slot_size;
    try appendInt(allocator, bytes, u32, stride);
    try emitRegisterBinary(allocator, bytes, 0x01, .rbx, .rax);
    const loop = bytes.items.len;
    for (0..element_width) |leaf| {
        try emitLoadMemory(allocator, bytes, .rax, .rbx, @intCast(leaf * Machine.slot_size));
        try emitStoreMemory(allocator, bytes, .r14, @intCast(leaf * Machine.slot_size), .rax);
    }
    try emitSubtractImmediateRegister(allocator, bytes, .rbx, stride);
    try emitAddImmediateRegister(allocator, bytes, .r14, stride);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xee, 1, 0x0f, 0x85 });
    const repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, repeat, loop);
    try patchRelative(bytes.items, copied, bytes.items.len);
}

fn emitAddImmediateRegister(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register, value: u32) Allocator.Error!void {
    const rex: u8 = 0x48 | @as(u8, @intFromBool(@intFromEnum(register) >= 8));
    try bytes.appendSlice(allocator, &.{ rex, 0x81, 0xc0 | (@as(u8, @intFromEnum(register)) & 7) });
    try appendInt(allocator, bytes, u32, value);
}

fn emitSubtractImmediateRegister(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register, value: u32) Allocator.Error!void {
    const rex: u8 = 0x48 | @as(u8, @intFromBool(@intFromEnum(register) >= 8));
    try bytes.appendSlice(allocator, &.{ rex, 0x81, 0xe8 | (@as(u8, @intFromEnum(register)) & 7) });
    try appendInt(allocator, bytes, u32, value);
}

fn emitListTakeLast(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.ListEdit,
) Error!void {
    try emitLoadStack(allocator, bytes, .rbx, value.collection);
    try emitLoadMemory(allocator, bytes, .r12, .rbx, 0);
    try bytes.appendSlice(allocator, &.{ 0x4d, 0x85, 0xe4, 0x0f, 0x85 });
    const nonempty = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitRuntimeFailure(allocator, bytes, epilogue);
    try patchRelative(bytes.items, nonempty, bytes.items.len);
    try emitMoveRegister(allocator, bytes, .r13, .r12);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xed, 1 });

    if (value.removed) |removed| {
        try emitMoveRegister(allocator, bytes, .r14, .rbx);
        try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xc6, 8 });
        try emitMoveRegister(allocator, bytes, .rax, .r13);
        try bytes.appendSlice(allocator, &.{ 0x48, 0x69, 0xc0 });
        try appendInt(allocator, bytes, u32, @as(u32, value.element_width) * Machine.slot_size);
        try bytes.appendSlice(allocator, &.{ 0x49, 0x01, 0xc6 });
        for (0..removed.width) |leaf| {
            try emitLoadMemory(allocator, bytes, .rax, .r14, @intCast(leaf * Machine.slot_size));
            try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, removed.start) + leaf));
        }
    }

    try emitMoveRegister(allocator, bytes, .rsi, .r13);
    try emitImmediate(allocator, bytes, .rcx, @as(u64, value.element_width) * Machine.slot_size);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xaf, 0xf1, 0x48, 0x83, 0xc6, 8 });
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r15, .rax);
    try emitStoreMemory(allocator, bytes, .r15, 0, .r13);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 8 });
    try emitMoveRegister(allocator, bytes, .r14, .r15);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xc6, 8 });
    try emitMoveRegister(allocator, bytes, .rsi, .r13);
    try emitImmediate(allocator, bytes, .rcx, value.element_width);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xaf, 0xf1, 0x48, 0x85, 0xf6, 0x0f, 0x84 });
    const copied = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    const loop = bytes.items.len;
    try emitLoadMemory(allocator, bytes, .rax, .rbx, 0);
    try emitStoreMemory(allocator, bytes, .r14, 0, .rax);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 8, 0x49, 0x83, 0xc6, 8, 0x48, 0x83, 0xee, 1, 0x0f, 0x85 });
    const repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, repeat, loop);
    try patchRelative(bytes.items, copied, bytes.items.len);
    try emitStoreStack(allocator, bytes, .r15, value.result);
}

fn emitCollectionView(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.CollectionView,
) Error!void {
    if (value.source_view) {
        try emitLoadStack(allocator, bytes, .rbx, value.collection.start);
        try emitLoadStack(allocator, bytes, .rcx, @intCast(@as(usize, value.collection.start) + 1));
    } else if (value.dynamic) {
        try emitLoadStack(allocator, bytes, .rbx, value.collection.start);
        try emitLoadMemory(allocator, bytes, .rcx, .rbx, 0);
        try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 8 });
    } else {
        try emitAddressStack(allocator, bytes, .rbx, value.collection.start);
        try emitImmediate(allocator, bytes, .rcx, value.count);
    }
    try emitLoadStack(allocator, bytes, .rax, value.start);
    try emitLoadStack(allocator, bytes, .rdx, value.end);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xd0, 0x0f, 0x86 });
    const ordered = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitRuntimeFailure(allocator, bytes, epilogue);
    try patchRelative(bytes.items, ordered, bytes.items.len);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xca, 0x0f, 0x86 });
    const bounded = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitRuntimeFailure(allocator, bytes, epilogue);
    try patchRelative(bytes.items, bounded, bytes.items.len);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x29, 0xc2, 0x48, 0x69, 0xc0 });
    try appendInt(allocator, bytes, u32, @as(u32, value.element_width) * Machine.slot_size);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x01, 0xc3 });
    try emitStoreStack(allocator, bytes, .rbx, value.result.start);
    try emitStoreStack(allocator, bytes, .rdx, @intCast(@as(usize, value.result.start) + 1));
}

fn emitStringFromBytes(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.StringFromBytes,
) Error!void {
    try emitLoadStack(allocator, bytes, .rbx, value.bytes.start);
    try emitLoadStack(allocator, bytes, .r12, @intCast(@as(usize, value.bytes.start) + 1));
    try emitMoveRegister(allocator, bytes, .rsi, .r12);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc6, 25 });
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r15, .rax);
    try emitImmediate(allocator, bytes, .r11, 1);
    try emitStoreMemory(allocator, bytes, .r15, 0, .r11);
    try emitStoreMemory(allocator, bytes, .r15, 8, .rsi);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xc7, dynamic_string_prefix_size });
    try emitMoveRegister(allocator, bytes, .r11, .r12);
    try emitImmediate(allocator, bytes, .r13, dynamic_string_flag);
    try emitOrRegister(allocator, bytes, .r11, .r13);
    try emitStoreMemory(allocator, bytes, .r15, 0, .r11);
    try emitMoveRegister(allocator, bytes, .r14, .r15);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xc6, 8, 0x4d, 0x85, 0xe4, 0x0f, 0x84 });
    const copied = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    const loop = bytes.items.len;
    try emitLoadMemory(allocator, bytes, .rax, .rbx, 0);
    try bytes.appendSlice(allocator, &.{ 0x41, 0x88, 0x06, 0x48, 0x83, 0xc3, 8, 0x49, 0x83, 0xc6, 1, 0x49, 0x83, 0xec, 1, 0x0f, 0x85 });
    const repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, repeat, loop);
    try patchRelative(bytes.items, copied, bytes.items.len);
    try bytes.appendSlice(allocator, &.{ 0x41, 0xc6, 0x06, 0 });
    try emitStoreStack(allocator, bytes, .r15, value.result);
}

fn emitStringCount(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    value: Machine.Instruction.StringCount,
) Error!void {
    try emitLoadStack(allocator, bytes, .rbx, value.operand);
    try emitLoadMemory(allocator, bytes, .rcx, .rbx, 0);
    try emitMaskDynamicStringLength(allocator, bytes, .rcx);
    try emitImmediate(allocator, bytes, .r12, 0);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc9, 0x0f, 0x84 });
    const finished_empty = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 8 });
    const loop = bytes.items.len;
    try emitLoadMemory(allocator, bytes, .rax, .rbx, 0);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x25, 0xc0, 0, 0, 0, 0x48, 0x3d, 0x80, 0, 0, 0, 0x0f, 0x84 });
    const continuation = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xc4, 1 });
    try patchRelative(bytes.items, continuation, bytes.items.len);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc3, 1, 0x48, 0x83, 0xe9, 1, 0x0f, 0x85 });
    const repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, repeat, loop);
    try patchRelative(bytes.items, finished_empty, bytes.items.len);
    try emitStoreStack(allocator, bytes, .r12, value.result);
}

fn emitStringConcat(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.StringConcat,
) Error!void {
    try emitLoadStack(allocator, bytes, .rbx, value.left);
    try emitLoadStack(allocator, bytes, .r12, value.right);
    try emitLoadMemory(allocator, bytes, .r13, .rbx, 0);
    try emitLoadMemory(allocator, bytes, .r14, .r12, 0);
    try emitMaskDynamicStringLength(allocator, bytes, .r13);
    try emitMaskDynamicStringLength(allocator, bytes, .r14);
    try emitMoveRegister(allocator, bytes, .r15, .r13);
    try bytes.appendSlice(allocator, &.{ 0x4d, 0x01, 0xf7 });
    try emitMoveRegister(allocator, bytes, .rsi, .r15);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc6, 25 });
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r10, .rax);
    try emitImmediate(allocator, bytes, .r11, 1);
    try emitStoreMemory(allocator, bytes, .r10, 0, .r11);
    try emitStoreMemory(allocator, bytes, .r10, 8, .rsi);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xc2, dynamic_string_prefix_size });
    try emitMoveRegister(allocator, bytes, .r11, .r15);
    try emitImmediate(allocator, bytes, .rax, dynamic_string_flag);
    try emitOrRegister(allocator, bytes, .r11, .rax);
    try emitStoreMemory(allocator, bytes, .r10, 0, .r11);
    try emitStoreStack(allocator, bytes, .r10, value.result);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xc2, 8, 0x48, 0x83, 0xc3, 8, 0x49, 0x83, 0xc4, 8 });

    try bytes.appendSlice(allocator, &.{ 0x4d, 0x85, 0xed, 0x0f, 0x84 });
    const left_finished = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    const left_loop = bytes.items.len;
    try bytes.appendSlice(allocator, &.{ 0x8a, 0x03, 0x41, 0x88, 0x02, 0x48, 0xff, 0xc3, 0x49, 0xff, 0xc2, 0x49, 0xff, 0xcd, 0x0f, 0x85 });
    const left_repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, left_repeat, left_loop);
    try patchRelative(bytes.items, left_finished, bytes.items.len);

    try bytes.appendSlice(allocator, &.{ 0x4d, 0x85, 0xf6, 0x0f, 0x84 });
    const right_finished = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    const right_loop = bytes.items.len;
    try bytes.appendSlice(allocator, &.{ 0x41, 0x8a, 0x04, 0x24, 0x41, 0x88, 0x02, 0x49, 0xff, 0xc4, 0x49, 0xff, 0xc2, 0x49, 0xff, 0xce, 0x0f, 0x85 });
    const right_repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, right_repeat, right_loop);
    try patchRelative(bytes.items, right_finished, bytes.items.len);
    try bytes.appendSlice(allocator, &.{ 0x41, 0xc6, 0x02, 0 });
}

fn emitStringRetain(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    value: Machine.Instruction.ListResource,
) Error!void {
    try emitLoadStack(allocator, bytes, .r10, value.operand);
    try emitLoadMemory(allocator, bytes, .r9, .r10, 0);
    try emitImmediate(allocator, bytes, .r11, dynamic_string_flag);
    try emitAndRegister(allocator, bytes, .r9, .r11);
    try bytes.appendSlice(allocator, &.{ 0x4d, 0x85, 0xc9, 0x0f, 0x84 });
    const literal = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xea, dynamic_string_prefix_size, 0xf0, 0x49, 0xff, 0x02 });
    try patchRelative(bytes.items, literal, bytes.items.len);
}

fn emitStringDrop(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    value: Machine.Instruction.ListResource,
) Error!void {
    try emitLoadStack(allocator, bytes, .r10, value.operand);
    try emitLoadMemory(allocator, bytes, .r9, .r10, 0);
    try emitImmediate(allocator, bytes, .r11, dynamic_string_flag);
    try emitAndRegister(allocator, bytes, .r9, .r11);
    try bytes.appendSlice(allocator, &.{ 0x4d, 0x85, 0xc9, 0x0f, 0x84 });
    const literal = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0xea, dynamic_string_prefix_size });
    try bytes.appendSlice(allocator, &.{ 0xf0, 0x49, 0xff, 0x0a, 0x0f, 0x85 });
    const retained = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    switch (platform) {
        .linux => {
            try emitMoveRegister(allocator, bytes, .rdi, .r10);
            try emitLoadMemory(allocator, bytes, .rsi, .r10, 8);
            try emitImmediate(allocator, bytes, .rax, 11);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });
        },
        .windows => {
            try emitMoveRegister(allocator, bytes, .rcx, .r10);
            try emitImmediate(allocator, bytes, .rdx, 0);
            try emitImmediate(allocator, bytes, .r8, 0x8000);
            try ExternalCalls.emitWindowsImportCall(allocator, bytes, import_sites, .virtual_free);
        },
    }
    try patchRelative(bytes.items, retained, bytes.items.len);
    try patchRelative(bytes.items, literal, bytes.items.len);
}

fn emitMaskDynamicStringLength(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register) Allocator.Error!void {
    try emitImmediate(allocator, bytes, .r11, dynamic_string_flag - 1);
    try emitAndRegister(allocator, bytes, register, .r11);
}

fn appendConditionalEpilogue(allocator: Allocator, bytes: *std.ArrayList(u8), fixups: *std.ArrayList(EpilogueFixup), condition: u8) Allocator.Error!void {
    try bytes.appendSlice(allocator, &.{ 0x0f, condition });
    const displacement_at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try fixups.append(allocator, .{ .displacement_at = displacement_at });
}

fn appendEpilogueJump(allocator: Allocator, bytes: *std.ArrayList(u8), fixups: *std.ArrayList(EpilogueFixup)) Allocator.Error!void {
    try bytes.append(allocator, 0xe9);
    const displacement_at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try fixups.append(allocator, .{ .displacement_at = displacement_at });
}

fn appendBranch(allocator: Allocator, bytes: *std.ArrayList(u8), fixups: *std.ArrayList(BranchFixup), instruction: usize) Allocator.Error!void {
    try bytes.append(allocator, 0xe9);
    const displacement_at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try fixups.append(allocator, .{ .displacement_at = displacement_at, .instruction = instruction });
}

fn appendCall(allocator: Allocator, bytes: *std.ArrayList(u8), calls: *std.ArrayList(CallFixup), function: usize) Allocator.Error!void {
    try bytes.append(allocator, 0xe8);
    try calls.append(allocator, .{ .displacement_at = bytes.items.len, .function = function });
    try bytes.appendNTimes(allocator, 0, 4);
}

fn emitInternalCallArguments(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    arguments: []const Machine.Span,
    argument_registers: []const Register,
) Error!u32 {
    const register_count = @min(arguments.len, argument_registers.len);
    for (arguments[0..register_count], argument_registers[0..register_count]) |argument, register| {
        if (argument.aggregate) {
            try emitAddressStack(allocator, bytes, register, argument.start);
        } else {
            if (argument.width != 1) return error.InvalidMachineProgram;
            try emitLoadStack(allocator, bytes, register, argument.start);
        }
    }
    if (arguments.len <= argument_registers.len) return 0;

    const raw_size = (arguments.len - argument_registers.len) * Machine.slot_size;
    const stack_size: u32 = @intCast(std.mem.alignForward(usize, raw_size, 16));
    try emitStackSubtraction(allocator, bytes, stack_size);
    for (arguments[argument_registers.len..], 0..) |argument, index| {
        if (argument.aggregate) {
            try emitAddressStack(allocator, bytes, .rax, argument.start);
        } else {
            if (argument.width != 1) return error.InvalidMachineProgram;
            try emitLoadStack(allocator, bytes, .rax, argument.start);
        }
        try emitStoreMemory(allocator, bytes, .rsp, @intCast(index * Machine.slot_size), .rax);
    }
    return stack_size;
}

fn emitLoadStack(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register, slot: Machine.Slot) Allocator.Error!void {
    try emitRex(allocator, bytes, true, register);
    try bytes.append(allocator, 0x8b);
    try bytes.append(allocator, 0x85 | (@as(u8, @intFromEnum(register) & 7) << 3));
    try appendInt(allocator, bytes, i32, slotDisplacement(slot));
}

fn emitLoadFloatStack(allocator: Allocator, bytes: *std.ArrayList(u8), xmm: u3, slot: Machine.Slot, double: bool) Allocator.Error!void {
    try bytes.append(allocator, if (double) 0xf2 else 0xf3);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x10, 0x85 | (@as(u8, xmm) << 3) });
    try appendInt(allocator, bytes, i32, slotDisplacement(slot));
}

fn emitStoreFloatStack(allocator: Allocator, bytes: *std.ArrayList(u8), xmm: u3, slot: Machine.Slot, double: bool) Allocator.Error!void {
    try bytes.append(allocator, if (double) 0xf2 else 0xf3);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x11, 0x85 | (@as(u8, xmm) << 3) });
    try appendInt(allocator, bytes, i32, slotDisplacement(slot));
}

fn emitAddressStack(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register, slot: Machine.Slot) Allocator.Error!void {
    try emitRex(allocator, bytes, true, register);
    try bytes.append(allocator, 0x8d);
    try bytes.append(allocator, 0x85 | (@as(u8, @intFromEnum(register) & 7) << 3));
    try appendInt(allocator, bytes, i32, slotDisplacement(slot));
}

fn emitAddressGlobal(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    fixups: *std.ArrayList(GlobalFixup),
    global: usize,
    byte_offset: usize,
    destination: Register,
) Allocator.Error!void {
    const rex: u8 = 0x48 | (@as(u8, @intFromBool(@intFromEnum(destination) >= 8)) << 2);
    try bytes.appendSlice(allocator, &.{ rex, 0x8d, 0x05 | (@as(u8, @intFromEnum(destination) & 7) << 3) });
    const displacement_at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try fixups.append(allocator, .{ .displacement_at = displacement_at, .global = global, .byte_offset = byte_offset });
}

fn emitMutexOperation(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    global_fixups: *std.ArrayList(GlobalFixup),
    windows_import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    program: Machine.Program,
    lock: bool,
) Error!void {
    const global = program.mutex_global orelse return error.InvalidMachineProgram;
    if (platform == .windows) {
        try emitAddressGlobal(allocator, bytes, global_fixups, global, 0, .rcx);
        try ExternalCalls.emitWindowsImportCall(
            allocator,
            bytes,
            windows_import_sites,
            if (lock) .enter_critical_section else .leave_critical_section,
        );
        return;
    }

    try emitImmediate(allocator, bytes, .rax, 186); // gettid
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x05, 0x48, 0x89, 0xc2 }); // syscall; mov rdx, rax
    try emitAddressGlobal(allocator, bytes, global_fixups, global, 0, .r11);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x39, 0x13 }); // cmp [r11], rdx
    if (lock) {
        try bytes.appendSlice(allocator, &.{ 0x0f, 0x84 });
        const recursive = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, 4);
        const retry = bytes.items.len;
        try bytes.appendSlice(allocator, &.{ 0x31, 0xc0, 0xf0, 0x49, 0x0f, 0xb1, 0x13, 0x48, 0x85, 0xc0, 0x0f, 0x85 });
        const repeat = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, 4);
        try bytes.appendSlice(allocator, &.{ 0x49, 0xc7, 0x43, 0x08, 0x01, 0, 0, 0, 0xe9 });
        const finished = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, 4);
        const recursive_target = bytes.items.len;
        try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0x43, 0x08, 0x01 });
        try patchRelative(bytes.items, recursive, recursive_target);
        try patchRelative(bytes.items, repeat, retry);
        try patchRelative(bytes.items, finished, bytes.items.len);
    } else {
        try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
        const not_owner = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, 4);
        try bytes.appendSlice(allocator, &.{ 0x49, 0x83, 0x6b, 0x08, 0x01, 0x0f, 0x85 });
        const still_owned = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, 4);
        try bytes.appendSlice(allocator, &.{ 0x49, 0xc7, 0x03, 0, 0, 0, 0 });
        try patchRelative(bytes.items, not_owner, bytes.items.len);
        try patchRelative(bytes.items, still_owned, bytes.items.len);
    }
}

fn emitStoreStack(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register, slot: Machine.Slot) Allocator.Error!void {
    try emitRex(allocator, bytes, true, register);
    try bytes.append(allocator, 0x89);
    try bytes.append(allocator, 0x85 | (@as(u8, @intFromEnum(register) & 7) << 3));
    try appendInt(allocator, bytes, i32, slotDisplacement(slot));
}

fn emitFrameAllocation(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    platform: Platform,
    frame_size: u16,
) Allocator.Error!void {
    var remaining: u32 = frame_size;
    if (platform == .windows) {
        while (remaining > 4096) {
            try emitStackSubtraction(allocator, bytes, 4096);
            // Windows grows committed stack memory one guarded page at a time.
            // Touch every crossed page before moving RSP farther down.
            try bytes.appendSlice(allocator, &.{ 0xf6, 0x04, 0x24, 0x00 });
            remaining -= 4096;
        }
    }
    if (remaining != 0) try emitStackSubtraction(allocator, bytes, remaining);
}

fn emitStackSubtraction(allocator: Allocator, bytes: *std.ArrayList(u8), amount: u32) Allocator.Error!void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0x81, 0xec });
    try appendInt(allocator, bytes, u32, amount);
}

fn emitStackAddition(allocator: Allocator, bytes: *std.ArrayList(u8), amount: u32) Allocator.Error!void {
    if (amount == 0) return;
    try bytes.appendSlice(allocator, &.{ 0x48, 0x81, 0xc4 });
    try appendInt(allocator, bytes, u32, amount);
}

fn emitLoadGlobal(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    fixups: *std.ArrayList(GlobalFixup),
    global: usize,
    byte_offset: usize,
    destination: Register,
) Allocator.Error!void {
    const rex: u8 = 0x48 | (@as(u8, @intFromBool(@intFromEnum(destination) >= 8)) << 2);
    try bytes.appendSlice(allocator, &.{ rex, 0x8b, 0x05 | (@as(u8, @intFromEnum(destination) & 7) << 3) });
    const displacement_at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try fixups.append(allocator, .{ .displacement_at = displacement_at, .global = global, .byte_offset = byte_offset });
}

fn emitStoreGlobal(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    fixups: *std.ArrayList(GlobalFixup),
    global: usize,
    byte_offset: usize,
    source: Register,
) Allocator.Error!void {
    const rex: u8 = 0x48 | (@as(u8, @intFromBool(@intFromEnum(source) >= 8)) << 2);
    try bytes.appendSlice(allocator, &.{ rex, 0x89, 0x05 | (@as(u8, @intFromEnum(source) & 7) << 3) });
    const displacement_at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try fixups.append(allocator, .{ .displacement_at = displacement_at, .global = global, .byte_offset = byte_offset });
}

fn emitLoadMemory(allocator: Allocator, bytes: *std.ArrayList(u8), destination: Register, base: Register, displacement: i32) Allocator.Error!void {
    const rex: u8 = 0x48 | (@as(u8, @intFromBool(@intFromEnum(destination) >= 8)) << 2) | @intFromBool(@intFromEnum(base) >= 8);
    const base_bits: u8 = @as(u8, @intFromEnum(base) & 7);
    try bytes.append(allocator, rex);
    try bytes.append(allocator, 0x8b);
    try bytes.append(allocator, 0x80 | (@as(u8, @intFromEnum(destination) & 7) << 3) | base_bits);
    if (base_bits == 4) try bytes.append(allocator, 0x24);
    try appendInt(allocator, bytes, i32, displacement);
}

fn emitStoreMemory(allocator: Allocator, bytes: *std.ArrayList(u8), base: Register, displacement: i32, source: Register) Allocator.Error!void {
    const rex: u8 = 0x48 | (@as(u8, @intFromBool(@intFromEnum(source) >= 8)) << 2) | @intFromBool(@intFromEnum(base) >= 8);
    const base_bits: u8 = @as(u8, @intFromEnum(base) & 7);
    try bytes.append(allocator, rex);
    try bytes.append(allocator, 0x89);
    try bytes.append(allocator, 0x80 | (@as(u8, @intFromEnum(source) & 7) << 3) | base_bits);
    if (base_bits == 4) try bytes.append(allocator, 0x24);
    try appendInt(allocator, bytes, i32, displacement);
}

fn emitImmediate(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register, value: u64) Allocator.Error!void {
    const rex: u8 = 0x48 | @as(u8, @intFromBool(@intFromEnum(register) >= 8));
    try bytes.append(allocator, rex);
    try bytes.append(allocator, 0xb8 + @as(u8, @intFromEnum(register) & 7));
    try appendInt(allocator, bytes, u64, value);
}

fn emitMoveRegister(allocator: Allocator, bytes: *std.ArrayList(u8), destination: Register, source: Register) Allocator.Error!void {
    const rex: u8 = 0x48 | (@as(u8, @intFromBool(@intFromEnum(source) >= 8)) << 2) | @intFromBool(@intFromEnum(destination) >= 8);
    try bytes.append(allocator, rex);
    try bytes.append(allocator, 0x89);
    try bytes.append(allocator, 0xc0 | (@as(u8, @intFromEnum(source) & 7) << 3) | @as(u8, @intFromEnum(destination) & 7));
}

fn emitAndRegister(allocator: Allocator, bytes: *std.ArrayList(u8), destination: Register, source: Register) Allocator.Error!void {
    try emitRegisterBinary(allocator, bytes, 0x21, destination, source);
}

fn emitOrRegister(allocator: Allocator, bytes: *std.ArrayList(u8), destination: Register, source: Register) Allocator.Error!void {
    try emitRegisterBinary(allocator, bytes, 0x09, destination, source);
}

fn emitRegisterBinary(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    opcode: u8,
    destination: Register,
    source: Register,
) Allocator.Error!void {
    const rex: u8 = 0x48 |
        (@as(u8, @intFromBool(@intFromEnum(source) >= 8)) << 2) |
        @as(u8, @intFromBool(@intFromEnum(destination) >= 8));
    try bytes.appendSlice(allocator, &.{
        rex,
        opcode,
        0xc0 | (@as(u8, @intFromEnum(source) & 7) << 3) | @as(u8, @intFromEnum(destination) & 7),
    });
}

fn emitRex(allocator: Allocator, bytes: *std.ArrayList(u8), wide: bool, register: Register) Allocator.Error!void {
    try bytes.append(allocator, 0x40 | (@as(u8, @intFromBool(wide)) << 3) | (@as(u8, @intFromBool(@intFromEnum(register) >= 8)) << 2));
}

fn slotDisplacement(slot: Machine.Slot) i32 {
    return -@as(i32, (@as(i32, slot) + 1) * Machine.slot_size);
}

fn patchRelative(bytes: []u8, displacement_at: usize, target: anytype) error{InvalidMachineProgram}!void {
    const next: i64 = @intCast(displacement_at + 4);
    const destination: i64 = @intCast(target);
    const displacement = std.math.cast(i32, destination - next) orelse return error.InvalidMachineProgram;
    std.mem.writeInt(i32, bytes[displacement_at..][0..4], displacement, .little);
}

fn appendInt(allocator: Allocator, bytes: *std.ArrayList(u8), comptime T: type, value: anytype) Allocator.Error!void {
    var encoded: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &encoded, @intCast(value), .little);
    try bytes.appendSlice(allocator, &encoded);
}

fn findMain(program: Machine.Program) ?usize {
    for (program.functions, 0..) |function, index| if (std.mem.eql(u8, function.name, "main")) return index;
    return null;
}

fn unsupported(reason: []const u8) error{UnsupportedInstruction} {
    std.debug.print("x64 unsupported: {s}\n", .{reason});
    return error.UnsupportedInstruction;
}

test "encode a no-op Silex main for the Linux X64 process contract" {
    const instructions = [_]Machine.Instruction{.return_void};
    const functions = [_]Machine.Function{.{
        .name = "main",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 0,
        .frame_size = 0,
        .instructions = &instructions,
    }};
    const image = try encodeLinux(std.testing.allocator, .{ .functions = &functions });
    defer image.deinit(std.testing.allocator);
    try std.testing.expect(image.entry_offset > 0);
    try std.testing.expect(std.mem.indexOf(u8, image.code, &.{ 0x0f, 0x05 }) != null);

    const windows = try encodeWindows(std.testing.allocator, .{ .functions = &functions });
    defer windows.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), windows.windows_import_sites.len);
    try std.testing.expectEqual(@as(u8, 0xc3), windows.code[windows.code.len - 1]);
}

test "encode internal X64 arguments beyond the register window" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("../Frontend.zig").Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func total(a:int,b:int,c:int,d:int,e:int,f:int,g:int,h:int,i:int,j:int) int {
        \\    return a+b+c+d+e+f+g+h+i+j
        \\}
        \\func main() { total(1,2,3,4,5,6,7,8,9,10) }
    );
    const machine = try @import("../Arm64/Lower.zig").lower(allocator, compilation.ir);

    const linux = try encodeLinux(allocator, machine);
    defer linux.deinit(allocator);
    const windows = try encodeWindows(allocator, machine);
    defer windows.deinit(allocator);
    try std.testing.expect(linux.code.len > 0);
    try std.testing.expect(windows.code.len > 0);
}

test "X64 keeps the scalar fallback when portable SLP groups are present" {
    const instructions = [_]Machine.Instruction{.return_void};
    const groups = [_]Machine.FloatLaneGroup{.{
        .slots = .{ 0, 1, 2, 0 },
        .width = 3,
        .priority = 8,
        .recurrence = false,
        .in_loop = false,
    }};
    const functions = [_]Machine.Function{.{
        .name = "main",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 3,
        .frame_size = 32,
        .float_lane_groups = &groups,
        .instructions = &instructions,
    }};
    const linux = try encodeLinux(std.testing.allocator, .{ .functions = &functions });
    defer linux.deinit(std.testing.allocator);
    const windows = try encodeWindows(std.testing.allocator, .{ .functions = &functions });
    defer windows.deinit(std.testing.allocator);
    try std.testing.expect(linux.entry_offset > 0);
    try std.testing.expect(windows.entry_offset > 0);
}

test "encode owned strings with allocation retain and release on both X64 hosts" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_str = .{ .result = 0, .string = 0 } },
        .{ .constant_str = .{ .result = 1, .string = 1 } },
        .{ .string_concat = .{ .result = 2, .left = 0, .right = 1 } },
        .{ .string_retain = .{ .operand = 2 } },
        .{ .string_drop = .{ .operand = 2 } },
        .{ .string_drop = .{ .operand = 2 } },
        .return_void,
    };
    const functions = [_]Machine.Function{.{
        .name = "main",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 3,
        .frame_size = 32,
        .instructions = &instructions,
    }};
    const program: Machine.Program = .{ .functions = &functions, .strings = &.{ "left", "right" } };

    const linux = try encodeLinuxObject(std.testing.allocator, program);
    defer linux.deinit(std.testing.allocator);
    try std.testing.expect(linux.code.len > 0);

    const windows = try encodeWindowsObject(std.testing.allocator, program);
    defer windows.deinit(std.testing.allocator);
    var alloc = false;
    var free = false;
    for (windows.windows_import_sites) |site| switch (site.symbol) {
        .virtual_alloc => alloc = true,
        .virtual_free => free = true,
        else => {},
    };
    try std.testing.expect(alloc);
    try std.testing.expect(free);
}

test "encode memory operands based on R12 with the required SIB byte" {
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.testing.allocator);
    try emitLoadMemory(std.testing.allocator, &bytes, .r14, .r12, 0);
    try std.testing.expectEqualSlices(u8, &.{ 0x4d, 0x8b, 0xb4, 0x24, 0, 0, 0, 0 }, bytes.items);
    bytes.clearRetainingCapacity();
    try emitStoreMemory(std.testing.allocator, &bytes, .r12, 8, .r14);
    try std.testing.expectEqualSlices(u8, &.{ 0x4d, 0x89, 0xb4, 0x24, 8, 0, 0, 0 }, bytes.items);
}

test "probe every Windows stack page in large X64 frames" {
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.testing.allocator);
    try emitFrameAllocation(std.testing.allocator, &bytes, .windows, 8192);
    try std.testing.expectEqualSlices(u8, &.{
        0x48, 0x81, 0xec, 0x00, 0x10, 0x00, 0x00,
        0xf6, 0x04, 0x24, 0x00, 0x48, 0x81, 0xec,
        0x00, 0x10, 0x00, 0x00,
    }, bytes.items);

    bytes.clearRetainingCapacity();
    try emitFrameAllocation(std.testing.allocator, &bytes, .linux, 8192);
    try std.testing.expectEqualSlices(u8, &.{
        0x48, 0x81, 0xec, 0x00, 0x20, 0x00, 0x00,
    }, bytes.items);
}
