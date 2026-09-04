const std = @import("std");
const Machine = @import("../Arm64/Machine.zig");
const WindowsImports = @import("../Windows/Imports.zig");
const FloatRuntime = @import("FloatRuntime.zig");
const DeepCopyRuntime = @import("DeepCopyRuntime.zig");
const CycleRuntime = @import("CycleRuntime.zig");
const ExternalCalls = @import("ExternalCalls.zig");
const FloatPairs = @import("FloatPairs.zig");
const Reachability = @import("Reachability.zig");
const TextRuntime = @import("TextRuntime.zig");

const Allocator = std.mem.Allocator;
const dynamic_string_flag: u64 = 1 << 63;
const dynamic_string_prefix_size: u8 = 16;
const class_header_size: u32 = 4 * Machine.slot_size;
const list_header_size: u32 = 5 * Machine.slot_size;
const root_count_offset: i32 = Machine.slot_size;
const edge_count_offset: i32 = 2 * Machine.slot_size;
const byte_count_offset: i32 = 3 * Machine.slot_size;
const state_offset: i32 = 4 * Machine.slot_size;
const class_state_offset: i32 = 3 * Machine.slot_size;
const enable_cycle_collector = true;

pub const Error = Machine.Error || Allocator.Error || FloatRuntime.Error || DeepCopyRuntime.Error || CycleRuntime.Error || error{UnsupportedInstruction};

pub const Image = struct {
    code: []u8,
    entry_offset: u32,
    data_offset: u32,
    address_sites: []const AddressSite = &.{},
    windows_import_sites: []const WindowsImports.X64Site = &.{},
    external_call_sites: []const ExternalCalls.Site = &.{},

    pub fn deinit(self: Image, allocator: Allocator) void {
        allocator.free(self.code);
        allocator.free(self.address_sites);
        allocator.free(self.windows_import_sites);
        allocator.free(self.external_call_sites);
    }
};

pub const AddressSite = struct {
    displacement_offset: u32,
    target_offset: u32,
};

const Register = enum(u4) { rax = 0, rcx = 1, rdx = 2, rbx = 3, rsp = 4, rbp = 5, rsi = 6, rdi = 7, r8 = 8, r9 = 9, r10 = 10, r11 = 11, r12 = 12, r13 = 13, r14 = 14, r15 = 15 };
const CallFixup = struct { displacement_at: usize, function: usize };
const FunctionAddressFixup = struct { displacement_at: usize, function: usize };
const BranchFixup = struct { displacement_at: usize, instruction: usize };
const EpilogueFixup = struct { displacement_at: usize };
const DataFixup = struct { displacement_at: usize, string: usize };
const GlobalFixup = struct { displacement_at: usize, global: usize, byte_offset: usize };
const DeepCopyFixup = struct {
    call_at: usize,
    model_at: usize,
    allocate_at: usize,
    release_at: usize,
};
const CycleFixup = struct {
    call_at: usize,
    model_at: ?usize = null,
    allocate_at: ?usize = null,
    release_at: ?usize = null,
};
const Platform = ExternalCalls.Platform;

/// Encodes the reachable scalar/class slice of the portable machine program
/// directly as X64. The internal convention is deliberately Silex-owned:
/// the first eight scalar arguments use RDI, RSI, RDX, RCX, R8, R9, R10, R11
/// and remaining arguments use aligned stack slots; scalar results use RAX;
/// the execution status uses RDX.
pub fn encodeLinux(allocator: Allocator, program: Machine.Program) Error!Image {
    return encode(allocator, program, .linux, false, null);
}

pub fn encodeDarwin(allocator: Allocator, program: Machine.Program) Error!Image {
    return encode(allocator, program, .darwin, false, null);
}

pub fn encodeWindows(allocator: Allocator, program: Machine.Program) Error!Image {
    return encode(allocator, program, .windows, false, null);
}

pub fn encodeLinuxObject(allocator: Allocator, program: Machine.Program) Error!Image {
    return encode(allocator, program, .linux, true, null);
}

pub fn encodeDarwinObject(allocator: Allocator, program: Machine.Program) Error!Image {
    return encode(allocator, program, .darwin, true, null);
}

pub fn encodeWindowsObject(allocator: Allocator, program: Machine.Program) Error!Image {
    return encode(allocator, program, .windows, true, null);
}

pub fn encodeLinuxFunctionObject(allocator: Allocator, program: Machine.Program, function: Machine.FunctionId) Error!Image {
    return encode(allocator, program, .linux, true, function);
}

pub fn encodeDarwinFunctionObject(allocator: Allocator, program: Machine.Program, function: Machine.FunctionId) Error!Image {
    return encode(allocator, program, .darwin, true, function);
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
    var deep_copy_calls: std.ArrayList(DeepCopyFixup) = .empty;
    defer deep_copy_calls.deinit(allocator);
    var cycle_calls: std.ArrayList(CycleFixup) = .empty;
    defer cycle_calls.deinit(allocator);
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
        try encodeFunction(allocator, &bytes, &calls, &function_addresses, &float_calls, &deep_copy_calls, &cycle_calls, &data_fixups, &global_fixups, &windows_import_sites, &external_call_sites, platform, program, function);
    }

    const entry_offset: u32 = @intCast(bytes.items.len);
    switch (platform) {
        .darwin => {
            try bytes.appendSlice(allocator, &.{ 0x53, 0x41, 0x54, 0x41, 0x55, 0x41, 0x56, 0x41, 0x57 });
            try appendCall(allocator, &bytes, &calls, main_id);
            try emitMoveRegister(allocator, &bytes, .rax, .rdx);
            try bytes.appendSlice(allocator, &.{ 0x41, 0x5f, 0x41, 0x5e, 0x41, 0x5d, 0x41, 0x5c, 0x5b, 0xc3 });
        },
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

    var thunk_offsets = std.AutoHashMap(usize, usize).init(allocator);
    defer thunk_offsets.deinit();
    for (function_addresses.items) |fixup| {
        if (fixup.function >= offsets.len or offsets[fixup.function] == std.math.maxInt(u32)) return error.InvalidMachineProgram;
        const thunk = try thunk_offsets.getOrPut(fixup.function);
        if (!thunk.found_existing) {
            thunk.value_ptr.* = bytes.items.len;
            switch (platform) {
                .darwin, .linux => try emitLinuxFunctionThunk(allocator, &bytes, &calls, program.functions[fixup.function], fixup.function),
                .windows => try emitWindowsFunctionThunk(allocator, &bytes, &calls, program.functions[fixup.function], fixup.function),
            }
        }
        try patchRelative(bytes.items, fixup.displacement_at, thunk.value_ptr.*);
    }

    for (calls.items) |call| {
        if (call.function >= offsets.len or offsets[call.function] == std.math.maxInt(u32)) return error.InvalidMachineProgram;
        try patchRelative(bytes.items, call.displacement_at, offsets[call.function]);
    }

    if (float_calls.items.len != 0) {
        var runtime = try FloatRuntime.payloadForPlatform(allocator, platform == .darwin);
        defer runtime.deinit(allocator);
        while (bytes.items.len % 4096 != runtime.page_offset) try bytes.append(allocator, 0);
        const runtime_start = bytes.items.len;
        const formatter = runtime_start + runtime.entry_offset;
        for (float_calls.items) |displacement_at| try patchRelative(bytes.items, displacement_at, formatter);
        try bytes.appendSlice(allocator, runtime.bytes);
    }

    var allocate_callback: ?usize = null;
    var release_callback: ?usize = null;
    if (deep_copy_calls.items.len != 0 or cycle_calls.items.len != 0) {
        allocate_callback = bytes.items.len;
        try emitRuntimeAllocateCallback(allocator, &bytes, &windows_import_sites, platform);
        release_callback = bytes.items.len;
        try emitRuntimeReleaseCallback(allocator, &bytes, &windows_import_sites, platform);
    }

    if (deep_copy_calls.items.len != 0) {
        var runtime = try DeepCopyRuntime.payloadForPlatform(allocator, platform == .darwin);
        defer runtime.deinit(allocator);
        while (bytes.items.len % 4096 != runtime.page_offset) try bytes.append(allocator, 0);
        const runtime_start = bytes.items.len;
        const target = runtime_start + runtime.entry_offset;
        for (deep_copy_calls.items) |fixup| {
            try patchRelative(bytes.items, fixup.call_at, target);
            try patchRelative(bytes.items, fixup.allocate_at, allocate_callback.?);
            try patchRelative(bytes.items, fixup.release_at, release_callback.?);
        }
        try bytes.appendSlice(allocator, runtime.bytes);
    }

    if (cycle_calls.items.len != 0) {
        var runtime = try CycleRuntime.payloadForPlatform(allocator, platform == .darwin);
        defer runtime.deinit(allocator);
        while (bytes.items.len % 4096 != runtime.page_offset) try bytes.append(allocator, 0);
        const runtime_start = bytes.items.len;
        const target = runtime_start + runtime.entry_offset;
        for (cycle_calls.items) |fixup| {
            try patchRelative(bytes.items, fixup.call_at, target);
            if (fixup.allocate_at) |at| try patchRelative(bytes.items, at, allocate_callback.?);
            if (fixup.release_at) |at| try patchRelative(bytes.items, at, release_callback.?);
        }
        try bytes.appendSlice(allocator, runtime.bytes);
    }

    if (platform == .darwin) while (bytes.items.len % 4096 != 0) try bytes.append(allocator, 0);
    const data_offset: u32 = @intCast(bytes.items.len);
    var address_sites: std.ArrayList(AddressSite) = .empty;
    defer address_sites.deinit(allocator);
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
        const target_offset = string_offsets[fixup.string];
        try patchRelative(bytes.items, fixup.displacement_at, target_offset);
        try address_sites.append(allocator, .{
            .displacement_offset = @intCast(fixup.displacement_at),
            .target_offset = @intCast(target_offset),
        });
    }
    if (deep_copy_calls.items.len != 0 or cycle_calls.items.len != 0) {
        while (bytes.items.len % Machine.slot_size != 0) try bytes.append(allocator, 0);
        const copy_model_offset = bytes.items.len;
        for (program.copy_model) |word| try appendInt(allocator, &bytes, u64, word);
        for (deep_copy_calls.items) |fixup| {
            try patchRelative(bytes.items, fixup.model_at, copy_model_offset);
            try address_sites.append(allocator, .{
                .displacement_offset = @intCast(fixup.model_at),
                .target_offset = @intCast(copy_model_offset),
            });
        }
        for (cycle_calls.items) |fixup| if (fixup.model_at) |at| {
            try patchRelative(bytes.items, at, copy_model_offset);
            try address_sites.append(allocator, .{
                .displacement_offset = @intCast(at),
                .target_offset = @intCast(copy_model_offset),
            });
        };
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
        const target_offset = global_offsets[fixup.global] + fixup.byte_offset;
        try patchRelative(bytes.items, fixup.displacement_at, target_offset);
        try address_sites.append(allocator, .{
            .displacement_offset = @intCast(fixup.displacement_at),
            .target_offset = @intCast(target_offset),
        });
    }
    return .{
        .code = try bytes.toOwnedSlice(allocator),
        .entry_offset = entry_offset,
        .data_offset = data_offset,
        .address_sites = try address_sites.toOwnedSlice(allocator),
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
    deep_copy_calls: *std.ArrayList(DeepCopyFixup),
    cycle_calls: *std.ArrayList(CycleFixup),
    data_fixups: *std.ArrayList(DataFixup),
    global_fixups: *std.ArrayList(GlobalFixup),
    windows_import_sites: *std.ArrayList(WindowsImports.X64Site),
    external_call_sites: *std.ArrayList(ExternalCalls.Site),
    platform: Platform,
    program: Machine.Program,
    function: Machine.Function,
) Error!void {
    if (function.float_register_slots.len != 0) return unsupported("X64 scalar floating register allocation");
    try FloatPairs.validate(function);
    for (function.register_slots) |residence| if (residence) |register| {
        if (register >= 16 or register == @intFromEnum(Register.rsp) or register == @intFromEnum(Register.rbp)) {
            return error.InvalidMachineProgram;
        }
    };
    try bytes.appendSlice(allocator, &.{ 0x55, 0x48, 0x89, 0xe5 });
    const runtime_frame_size: u32 = if (enable_cycle_collector) 16 else 0;
    const required_frame_size = std.math.add(u32, function.frame_size, runtime_frame_size) catch return error.InvalidMachineProgram;
    const padded_frame_size = std.math.add(u32, required_frame_size, 15) catch return error.InvalidMachineProgram;
    const encoded_frame_size = padded_frame_size & ~@as(u32, 15);
    try emitFrameAllocation(allocator, bytes, platform, encoded_frame_size);
    // Keep addressable scalar spans in the same increasing-memory order as
    // heap aggregates and the other native backends. RBP remains stable while
    // calls temporarily move RSP below this frame base.
    try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0xe5 });
    const cycle_context_slot: Machine.Slot = @intCast(function.frame_size / Machine.slot_size);
    const argument_registers = [_]Register{ .rdi, .rsi, .rdx, .rcx, .r8, .r9, .r10, .r11 };
    if (function.parameters.len != function.parameter_count) return error.InvalidMachineProgram;
    if (function.hidden_return_slot) |slot| try emitStoreStack(allocator, bytes, .r15, slot);
    // Copy arguments backwards so a scalar residence in r8-r11 cannot replace
    // a later incoming argument before that argument reaches its own slot.
    var remaining_parameters = function.parameters.len;
    while (remaining_parameters != 0) {
        remaining_parameters -= 1;
        const index = remaining_parameters;
        const parameter = function.parameters[index];
        if (index >= argument_registers.len) {
            const incoming_displacement = std.math.cast(
                i32,
                @as(u64, encoded_frame_size) + 16 + (index - argument_registers.len) * Machine.slot_size,
            ) orelse return error.InvalidMachineProgram;
            if (parameter.aggregate) {
                try emitLoadMemory(allocator, bytes, .r14, .rbp, incoming_displacement);
                for (0..parameter.width) |leaf| {
                    try emitLoadMemory(allocator, bytes, .rax, .r14, @intCast(leaf * Machine.slot_size));
                    try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, parameter.start) + leaf));
                }
            } else {
                if (parameter.width != 1) return error.InvalidMachineProgram;
                try emitLoadMemory(allocator, bytes, .rax, .rbp, incoming_displacement);
                try emitStoreValue(allocator, bytes, function.register_slots, .rax, parameter.start);
            }
        } else if (parameter.aggregate) {
            for (0..parameter.width) |leaf| {
                try emitLoadMemory(allocator, bytes, .rax, argument_registers[index], @intCast(leaf * Machine.slot_size));
                try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, parameter.start) + leaf));
            }
        } else {
            if (parameter.width != 1) return error.InvalidMachineProgram;
            try emitStoreValue(allocator, bytes, function.register_slots, argument_registers[index], parameter.start);
        }
    }
    for (function.capture_parameters, 0..) |capture, index| {
        if (capture.aggregate or capture.width != 1) return error.InvalidMachineProgram;
        try emitLoadMemory(allocator, bytes, .rax, .r12, @intCast(index * Machine.slot_size));
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
                try emitStoreValue(allocator, bytes, function.register_slots, .rax, value.result);
            },
            .constant_bool => |value| {
                try emitImmediate(allocator, bytes, .rax, @intFromBool(value.value));
                try emitStoreValue(allocator, bytes, function.register_slots, .rax, value.result);
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
                try emitLoadValue(allocator, bytes, function.register_slots, .rax, copy.operand);
                try emitStoreValue(allocator, bytes, function.register_slots, .rax, copy.result);
            },
            .copy_range => |copy| try emitCopyRange(allocator, bytes, copy.result, copy.operand),
            .deep_copy => |copy| {
                if (copy.operand.width != copy.result.width) return error.InvalidMachineProgram;
                const value_byte_count = @as(u32, copy.operand.width) * Machine.slot_size;
                const scratch_byte_count = std.mem.alignForward(u32, value_byte_count * 2, 16);
                try emitStackSubtraction(allocator, bytes, scratch_byte_count);
                for (0..copy.operand.width) |leaf| {
                    try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, copy.operand.start) + leaf));
                    try emitStoreMemory(allocator, bytes, .rsp, @intCast(leaf * Machine.slot_size), .rax);
                }
                try emitMoveRegister(allocator, bytes, .rdi, .rsp);
                try emitMoveRegister(allocator, bytes, .rsi, .rsp);
                try emitAddImmediateRegister(allocator, bytes, .rsi, value_byte_count);
                const model_at = try emitRipAddress(allocator, bytes, .rdx);
                try emitImmediate(allocator, bytes, .rcx, @intFromEnum(copy.type));
                const allocate_at = try emitRipAddress(allocator, bytes, .r8);
                const release_at = try emitRipAddress(allocator, bytes, .r9);
                try bytes.append(allocator, 0xe8);
                const call_at = bytes.items.len;
                try bytes.appendNTimes(allocator, 0, 4);
                try deep_copy_calls.append(allocator, .{
                    .call_at = call_at,
                    .model_at = model_at,
                    .allocate_at = allocate_at,
                    .release_at = release_at,
                });
                try emitMoveRegister(allocator, bytes, .rdx, .rax);
                for (0..copy.result.width) |leaf| {
                    try emitLoadMemory(allocator, bytes, .rax, .rsp, @intCast(value_byte_count + leaf * Machine.slot_size));
                    try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, copy.result.start) + leaf));
                }
                try emitStackAddition(allocator, bytes, scratch_byte_count);
                try emitRegisterBinary(allocator, bytes, 0x85, .rdx, .rdx);
                try appendConditionalEpilogue(allocator, bytes, &epilogue_fixups, 0x85);
            },
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
                try emitAddImmediateRegister(allocator, bytes, .rax, offset.byte_offset);
                try emitStoreStack(allocator, bytes, .rax, offset.result);
            },
            .reference_indirect_offset => |offset| {
                try emitLoadStack(allocator, bytes, .rax, offset.reference);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x8b, 0x00 });
                try bytes.appendSlice(allocator, &.{ 0x48, 0x05 });
                try appendInt(allocator, bytes, u32, offset.byte_offset);
                try emitStoreStack(allocator, bytes, .rax, offset.result);
            },
            .storage_init => |storage| {
                try bytes.appendSlice(allocator, &.{ 0x31, 0xc0 });
                for (0..storage.width) |leaf| try emitStoreStack(
                    allocator,
                    bytes,
                    .rax,
                    @intCast(@as(usize, storage.start) + leaf),
                );
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
            .protocol_init => |value| try emitProtocolInit(allocator, bytes, value),
            .protocol_test => |value| try emitProtocolTest(allocator, bytes, value),
            .protocol_extract => |value| try emitProtocolExtract(allocator, bytes, value),
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
                try emitImmediate(allocator, bytes, .rcx, value.count);
                try emitNormalizeCollectionIndex(allocator, bytes, .rax, .rcx);
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
                try bytes.appendSlice(allocator, &.{ 0x48, 0x01, 0xc1 });
                for (0..value.result.width) |leaf| {
                    try emitLoadMemory(allocator, bytes, .rax, .rcx, @intCast(leaf * Machine.slot_size));
                    try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, value.result.start) + leaf));
                }
            },
            .collection_reference => |value| try emitCollectionReference(
                allocator,
                bytes,
                windows_import_sites,
                platform,
                &epilogue_fixups,
                value,
            ),
            .collection_replace => |value| if (value.view)
                try emitViewReplace(allocator, bytes, &epilogue_fixups, value)
            else if (value.dynamic)
                try emitDynamicReplace(allocator, bytes, windows_import_sites, platform, &epilogue_fixups, value)
            else
                try emitFixedReplace(allocator, bytes, &epilogue_fixups, value),
            .collection_count => |value| try emitCollectionCount(allocator, bytes, value),
            .list_edit => |value| try emitListEdit(allocator, bytes, windows_import_sites, platform, &epilogue_fixups, value),
            .collection_slice => |value| try emitCollectionSlice(allocator, bytes, windows_import_sites, platform, &epilogue_fixups, value),
            .collection_view => |value| try emitCollectionView(allocator, bytes, &epilogue_fixups, value),
            .aggregate_equal => |value| try emitAggregateEqual(allocator, bytes, value),
            .class_init => |value| try emitClassInit(allocator, bytes, windows_import_sites, platform, &epilogue_fixups, value),
            .class_load => |value| {
                try emitClassLoad(allocator, bytes, value);
            },
            .class_store => |value| try emitClassStore(allocator, bytes, value),
            .class_retain => |value| try emitClassRetain(allocator, bytes, value),
            .class_drop => |value| try emitClassDrop(
                allocator,
                bytes,
                calls,
                cycle_calls,
                &epilogue_fixups,
                windows_import_sites,
                platform,
                cycle_context_slot,
                value,
            ),
            .list_retain => |value| try emitListRetain(allocator, bytes, value),
            .list_drop => |value| try emitListDropSlot(allocator, bytes, windows_import_sites, platform, value.operand, value.ownership),
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
                } else if (conversion.source == .float32 and conversion.target == .float64) {
                    try emitLoadFloatStack(allocator, bytes, 0, conversion.operand, false);
                    try bytes.appendSlice(allocator, &.{ 0xf3, 0x0f, 0x5a, 0xc0 });
                    try emitStoreFloatStack(allocator, bytes, 0, conversion.result, true);
                } else if (conversion.source == .float64 and conversion.target == .float32) {
                    try emitLoadFloatStack(allocator, bytes, 0, conversion.operand, true);
                    try bytes.appendSlice(allocator, &.{ 0xf2, 0x0f, 0x5a, 0xc0 });
                    try emitStoreFloatStack(allocator, bytes, 0, conversion.result, false);
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
                try emitLoadValue(allocator, bytes, function.register_slots, .rax, unary.operand);
                if (unary.type == .float32) {
                    try bytes.append(allocator, 0x35);
                    try appendInt(allocator, bytes, u32, 0x8000_0000);
                } else if (unary.type == .float64) {
                    try emitImmediate(allocator, bytes, .rcx, 0x8000_0000_0000_0000);
                    try bytes.appendSlice(allocator, &.{ 0x48, 0x31, 0xc8 });
                } else {
                    try bytes.appendSlice(allocator, &.{ 0x48, 0xf7, 0xd8 });
                }
                try emitStoreValue(allocator, bytes, function.register_slots, .rax, unary.result);
            },
            .binary => |binary| {
                if (try FloatPairs.emit(allocator, bytes, function, binary)) continue;
                try emitBinary(allocator, bytes, function.register_slots, binary);
            },
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
                const outgoing_stack_size = switch (platform) {
                    .darwin, .linux => try emitLinuxCallbackArguments(allocator, bytes, call.arguments),
                    .windows => try emitWindowsCallbackArguments(allocator, bytes, call.arguments),
                };
                try emitLoadStack(allocator, bytes, .r12, call.callee + 1);
                try emitLoadStack(allocator, bytes, .rax, call.callee);
                try bytes.appendSlice(allocator, &.{ 0xff, 0xd0 });
                try emitStackAddition(allocator, bytes, outgoing_stack_size);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xd2 });
                try appendConditionalEpilogue(allocator, bytes, &epilogue_fixups, 0x85);
                if (call.result) |result| if (!result.aggregate) try emitStoreStack(allocator, bytes, .rax, result.start);
            },
            .external_call => |call| try ExternalCalls.emit(allocator, bytes, windows_import_sites, external_call_sites, platform, program, function, call),
            .external_indirect_call => |call| try ExternalCalls.emitIndirect(allocator, bytes, platform, call),
            .mutex_lock => try emitMutexOperation(allocator, bytes, global_fixups, windows_import_sites, platform, program, true),
            .mutex_unlock => try emitMutexOperation(allocator, bytes, global_fixups, windows_import_sites, platform, program, false),
            .dynamic_call => |call| try emitDynamicCall(
                allocator,
                bytes,
                calls,
                &epilogue_fixups,
                call,
                &argument_registers,
            ),
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
                try emitWriteStatic(allocator, bytes, data_fixups, windows_import_sites, platform, assertion.header);
                try emitWriteStringSlot(allocator, bytes, windows_import_sites, platform, assertion.message);
                try emitRuntimeFailure(allocator, bytes, &epilogue_fixups);
                try patchRelative(bytes.items, passed, bytes.items.len);
            },
            .panic => |panic_value| {
                try emitWriteStatic(allocator, bytes, data_fixups, windows_import_sites, platform, panic_value.header);
                try emitWriteStringSlot(allocator, bytes, windows_import_sites, platform, panic_value.message);
                try emitRuntimeFailure(allocator, bytes, &epilogue_fixups);
            },
            .return_value => |value| {
                if (value.aggregate) {
                    const hidden = function.hidden_return_slot orelse return error.InvalidMachineProgram;
                    try emitLoadStack(allocator, bytes, .r15, hidden);
                    for (0..value.width) |leaf| {
                        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.start) + leaf));
                        try emitStoreMemory(allocator, bytes, .r15, @intCast(leaf * Machine.slot_size), .rax);
                    }
                    try emitImmediate(allocator, bytes, .rax, 0);
                } else {
                    if (value.width != 1) return error.InvalidMachineProgram;
                    try emitLoadValue(allocator, bytes, function.register_slots, .rax, value.start);
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
                try emitLoadValue(allocator, bytes, function.register_slots, .rax, branch.condition);
                try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0, 0x0f, 0x85 });
                const then_at = bytes.items.len;
                try bytes.appendNTimes(allocator, 0, 4);
                try branches.append(allocator, .{ .displacement_at = then_at, .instruction = branch.then_instruction });
                try appendBranch(allocator, bytes, &branches, branch.else_instruction);
            },
        }
    }
    instruction_offsets[function.instructions.len] = bytes.items.len;
    const epilogue = bytes.items.len;
    try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0xec });
    try emitStackAddition(allocator, bytes, encoded_frame_size);
    try bytes.appendSlice(allocator, &.{ 0x5d, 0xc3 });
    for (branches.items) |branch| {
        if (branch.instruction > function.instructions.len) return error.InvalidMachineProgram;
        try patchRelative(bytes.items, branch.displacement_at, instruction_offsets[branch.instruction]);
    }
    for (epilogue_fixups.items) |fixup| try patchRelative(bytes.items, fixup.displacement_at, epilogue);
}

fn emitProtocolInit(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    value: Machine.Instruction.ProtocolInit,
) Error!void {
    if (value.class_operand) {
        try emitLoadStack(allocator, bytes, .rax, value.operand.start);
        try emitLoadMemory(allocator, bytes, .rax, .rax, 0);
    } else try emitImmediate(allocator, bytes, .rax, value.structure);
    try emitStoreStack(allocator, bytes, .rax, value.result.start);
    for (0..value.operand.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.operand.start) + leaf));
        try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, value.result.start) + 1 + leaf));
    }
    if (value.operand.width + 1 < value.result.width) {
        try emitImmediate(allocator, bytes, .rax, 0);
        for (value.operand.width + 1..value.result.width) |leaf| {
            try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, value.result.start) + leaf));
        }
    }
}

fn emitProtocolTest(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    value: Machine.Instruction.ProtocolTest,
) Error!void {
    try emitLoadStack(allocator, bytes, .rax, value.operand);
    try emitImmediate(allocator, bytes, .rcx, value.structure);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xc8, 0x0f, 0x94, 0xc0, 0x48, 0x0f, 0xb6, 0xc0 });
    try emitStoreStack(allocator, bytes, .rax, value.result);
}

fn emitProtocolExtract(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    value: Machine.Instruction.ProtocolExtract,
) Error!void {
    for (0..value.result.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.operand.start) + 1 + leaf));
        try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, value.result.start) + leaf));
    }
}

fn emitDynamicCall(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    calls: *std.ArrayList(CallFixup),
    epilogue_fixups: *std.ArrayList(EpilogueFixup),
    call: Machine.Instruction.DynamicCall,
    argument_registers: []const Register,
) Error!void {
    try emitLoadStack(allocator, bytes, .r13, call.receiver);
    try emitLoadMemory(allocator, bytes, .r13, .r13, 0);
    if (call.result) |result| if (result.aggregate) try emitAddressStack(allocator, bytes, .r15, result.start);
    const outgoing_stack_size = try emitInternalCallArguments(allocator, bytes, call.arguments, argument_registers);

    var done: std.ArrayList(usize) = .empty;
    defer done.deinit(allocator);
    for (call.implementations) |implementation| {
        try emitImmediate(allocator, bytes, .rax, implementation.structure);
        try bytes.appendSlice(allocator, &.{ 0x49, 0x39, 0xc5, 0x0f, 0x85 });
        const skip = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, 4);
        try appendCall(allocator, bytes, calls, implementation.function);
        try emitStackAddition(allocator, bytes, outgoing_stack_size);
        try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xd2 });
        try appendConditionalEpilogue(allocator, bytes, epilogue_fixups, 0x85);
        try bytes.append(allocator, 0xe9);
        try done.append(allocator, bytes.items.len);
        try bytes.appendNTimes(allocator, 0, 4);
        try patchRelative(bytes.items, skip, bytes.items.len);
    }
    try appendCall(allocator, bytes, calls, call.function);
    try emitStackAddition(allocator, bytes, outgoing_stack_size);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xd2 });
    try appendConditionalEpilogue(allocator, bytes, epilogue_fixups, 0x85);
    for (done.items) |site| try patchRelative(bytes.items, site, bytes.items.len);
    if (call.result) |result| if (!result.aggregate) try emitStoreStack(allocator, bytes, .rax, result.start);
}

fn emitBinary(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    residences: []const ?u5,
    binary: Machine.Instruction.Binary,
) Error!void {
    if (binary.type.isFloat()) return emitFloatBinary(allocator, bytes, binary);
    if (binary.type == .str) return emitStringBinary(allocator, bytes, binary);
    try emitLoadValue(allocator, bytes, residences, .rax, binary.left);
    try emitLoadValue(allocator, bytes, residences, .rcx, binary.right);
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
    try emitStoreValue(allocator, bytes, residences, .rax, binary.result);
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
        try emitBinary(allocator, bytes, &.{}, .{
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
    try emitImmediate(allocator, bytes, .rsi, (width * Machine.slot_size) + class_header_size);
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .rbx, .rax);
    try emitImmediate(allocator, bytes, .rcx, value.structure);
    try emitStoreMemory(allocator, bytes, .rbx, 0, .rcx);
    try emitImmediate(allocator, bytes, .rax, 0);
    try emitStoreMemory(allocator, bytes, .rbx, root_count_offset, .rax);
    try emitStoreMemory(allocator, bytes, .rbx, edge_count_offset, .rax);
    try emitStoreMemory(allocator, bytes, .rbx, class_state_offset, .rax);
    var offset: u32 = class_header_size;
    for (value.fields) |field| for (0..field.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, field.start) + leaf));
        try emitStoreMemory(allocator, bytes, .rbx, @intCast(offset), .rax);
        offset += Machine.slot_size;
    };
    try emitStoreStack(allocator, bytes, .rbx, value.result);
}

fn emitClassLoad(allocator: Allocator, bytes: *std.ArrayList(u8), value: Machine.Instruction.ClassLoad) Error!void {
    try emitLoadStack(allocator, bytes, .rbx, value.base);
    for (0..value.result.width) |leaf| {
        try emitLoadMemory(allocator, bytes, .rax, .rbx, @intCast(class_header_size + value.byte_offset + leaf * Machine.slot_size));
        try emitStoreStack(allocator, bytes, .rax, @intCast(@as(usize, value.result.start) + leaf));
    }
}

fn emitClassStore(allocator: Allocator, bytes: *std.ArrayList(u8), value: Machine.Instruction.ClassStore) Error!void {
    try emitLoadStack(allocator, bytes, .rbx, value.base);
    try emitStoreStack(allocator, bytes, .rbx, value.result);
    for (0..value.replacement.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.replacement.start) + leaf));
        try emitStoreMemory(allocator, bytes, .rbx, @intCast(class_header_size + value.byte_offset + leaf * Machine.slot_size), .rax);
    }
}

fn emitClassRetain(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    value: Machine.Instruction.ClassRetain,
) Error!void {
    try emitLoadStack(allocator, bytes, .r10, value.operand);
    if (value.ownership == .edge) try emitMarkCycleDirty(allocator, bytes);
    try emitAtomicIncrement(allocator, bytes, .r10, switch (value.ownership) {
        .root => root_count_offset,
        .edge => edge_count_offset,
    });
}

/// State 4 caches a negative cycle proof. Changing an incoming class edge
/// invalidates that proof before its reference count changes.
fn emitMarkCycleDirty(allocator: Allocator, bytes: *std.ArrayList(u8)) Error!void {
    const retry = bytes.items.len;
    try emitLoadMemory(allocator, bytes, .rax, .r10, class_state_offset);
    try emitImmediate(allocator, bytes, .rcx, 4);
    try emitRegisterBinary(allocator, bytes, 0x39, .rax, .rcx);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
    const clean = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitImmediate(allocator, bytes, .r11, 0);
    try bytes.appendSlice(allocator, &.{ 0xf0, 0x4d, 0x0f, 0xb1, 0x5a, @intCast(class_state_offset) });
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
    const conflicted = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, conflicted, retry);
    try patchRelative(bytes.items, clean, bytes.items.len);
}

fn emitClassDrop(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    calls: *std.ArrayList(CallFixup),
    cycle_calls: *std.ArrayList(CycleFixup),
    epilogue_fixups: *std.ArrayList(EpilogueFixup),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    cycle_context_slot: Machine.Slot,
    value: Machine.Instruction.ClassDrop,
) Error!void {
    try emitImmediate(allocator, bytes, .rax, 0);
    try emitStoreStack(allocator, bytes, .rax, cycle_context_slot);
    const count_offset: i32 = switch (value.ownership) {
        .root => root_count_offset,
        .edge => edge_count_offset,
    };
    try emitLoadStack(allocator, bytes, .r10, value.operand);
    if (value.ownership == .edge) try emitMarkCycleDirty(allocator, bytes);
    const retry = bytes.items.len;
    try emitLoadMemory(allocator, bytes, .rax, .r10, count_offset);
    try emitRegisterBinary(allocator, bytes, 0x85, .rax, .rax);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x84 });
    const already_released = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitMoveRegister(allocator, bytes, .r11, .rax);
    try emitSubtractImmediateRegister(allocator, bytes, .r11, 1);
    try bytes.appendSlice(allocator, &.{ 0xf0, 0x4d, 0x0f, 0xb1, 0x5a, @intCast(count_offset) });
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
    const conflicted = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, conflicted, retry);

    // A live root proves reachability. With no roots but remaining edges, the
    // object is a cycle candidate; with no references it finalizes directly.
    try emitLoadMemory(allocator, bytes, .rax, .r10, root_count_offset);
    try emitRegisterBinary(allocator, bytes, 0x85, .rax, .rax);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
    const rooted = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitLoadMemory(allocator, bytes, .r11, .r10, edge_count_offset);
    try emitRegisterBinary(allocator, bytes, 0x85, .r11, .r11);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
    const cycle_candidate = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);

    const claim_retry = bytes.items.len;
    try emitLoadMemory(allocator, bytes, .rax, .r10, class_state_offset);
    try emitImmediate(allocator, bytes, .rcx, 2);
    try emitRegisterBinary(allocator, bytes, 0x39, .rax, .rcx);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x84 });
    const tracing = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitImmediate(allocator, bytes, .rcx, 1);
    try emitRegisterBinary(allocator, bytes, 0x39, .rax, .rcx);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x84 });
    const already_claimed = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitImmediate(allocator, bytes, .r11, 1);
    try bytes.appendSlice(allocator, &.{ 0xf0, 0x4d, 0x0f, 0xb1, 0x5a, @intCast(class_state_offset) });
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
    const claim_conflicted = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, tracing, claim_retry);
    try patchRelative(bytes.items, claim_conflicted, claim_retry);
    try bytes.append(allocator, 0xe9);
    const finalize_without_cycle = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);

    const cycle_prepare = bytes.items.len;
    try emitLoadStack(allocator, bytes, .r10, value.operand);
    try emitLoadMemory(allocator, bytes, .rax, .r10, class_state_offset);
    try emitRegisterBinary(allocator, bytes, 0x85, .rax, .rax);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
    const cycle_claimed = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitImmediate(allocator, bytes, .rdi, 0);
    try emitLoadStack(allocator, bytes, .rsi, value.operand);
    const model_at = try emitRipAddress(allocator, bytes, .rdx);
    try emitImmediate(allocator, bytes, .rcx, 0x100 + value.static_type);
    const allocate_at = try emitRipAddress(allocator, bytes, .r8);
    const release_at = try emitRipAddress(allocator, bytes, .r9);
    try bytes.append(allocator, 0xe8);
    const prepare_call = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try cycle_calls.append(allocator, .{
        .call_at = prepare_call,
        .model_at = model_at,
        .allocate_at = allocate_at,
        .release_at = release_at,
    });
    try emitRegisterBinary(allocator, bytes, 0x85, .rax, .rax);
    try emitImmediate(allocator, bytes, .rdx, 0);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x84 });
    const cycle_unavailable = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitStoreStack(allocator, bytes, .rax, cycle_context_slot);
    try bytes.append(allocator, 0xe9);
    const finalize_cycle = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);

    const finalize = bytes.items.len;
    try patchRelative(bytes.items, finalize_without_cycle, finalize);
    try patchRelative(bytes.items, finalize_cycle, finalize);

    try emitLoadStack(allocator, bytes, .r10, value.operand);
    try emitLoadMemory(allocator, bytes, .r12, .r10, 0);
    var finalized: std.ArrayList(usize) = .empty;
    defer finalized.deinit(allocator);
    for (value.plans) |plan| {
        try emitImmediate(allocator, bytes, .rax, plan.structure);
        try emitRegisterBinary(allocator, bytes, 0x39, .r12, .rax);
        try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
        const next_plan = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, 4);
        for (plan.functions) |finalizer| {
            try emitLoadStack(allocator, bytes, .rdi, value.operand);
            try appendCall(allocator, bytes, calls, finalizer);
            try emitRegisterBinary(allocator, bytes, 0x85, .rdx, .rdx);
            try appendConditionalEpilogue(allocator, bytes, epilogue_fixups, 0x85);
        }
        try emitLoadStack(allocator, bytes, .r10, value.operand);
        try emitImmediate(allocator, bytes, .rsi, plan.byte_count);
        try emitDeallocation(allocator, bytes, import_sites, platform, .r10, .rsi);
        try bytes.append(allocator, 0xe9);
        try finalized.append(allocator, bytes.items.len);
        try bytes.appendNTimes(allocator, 0, 4);
        try patchRelative(bytes.items, next_plan, bytes.items.len);
    }
    const finalization_complete = bytes.items.len;
    try emitLoadStack(allocator, bytes, .rsi, cycle_context_slot);
    try emitRegisterBinary(allocator, bytes, 0x85, .rsi, .rsi);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x84 });
    const no_context = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitImmediate(allocator, bytes, .rdi, 1);
    try emitImmediate(allocator, bytes, .rdx, 0);
    try emitImmediate(allocator, bytes, .rcx, 0);
    try emitImmediate(allocator, bytes, .r8, 0);
    try emitImmediate(allocator, bytes, .r9, 0);
    try bytes.append(allocator, 0xe8);
    const finish_call = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try cycle_calls.append(allocator, .{ .call_at = finish_call });
    try emitImmediate(allocator, bytes, .rdx, 0);
    const done = bytes.items.len;
    for (finalized.items) |site| try patchRelative(bytes.items, site, finalization_complete);
    try patchRelative(bytes.items, already_released, done);
    try patchRelative(bytes.items, rooted, done);
    try patchRelative(bytes.items, cycle_candidate, if (value.skip_cycle) done else cycle_prepare);
    try patchRelative(bytes.items, already_claimed, done);
    try patchRelative(bytes.items, cycle_claimed, done);
    try patchRelative(bytes.items, cycle_unavailable, done);
    try patchRelative(bytes.items, no_context, done);
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
        .darwin => {
            if (address != .rsi) try emitMoveRegister(allocator, bytes, .rsi, address);
            if (count != .rdx) try emitMoveRegister(allocator, bytes, .rdx, count);
            try emitImmediate(allocator, bytes, .rax, 0x2000004);
            try emitImmediate(allocator, bytes, .rdi, descriptor);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });
        },
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

fn emitWriteStatic(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    fixups: *std.ArrayList(DataFixup),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    string: usize,
) Error!void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0x8d, 0x35 });
    const displacement_at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try fixups.append(allocator, .{ .displacement_at = displacement_at, .string = string });
    try emitLoadMemory(allocator, bytes, .r8, .rsi, 0);
    try emitAddImmediateRegister(allocator, bytes, .rsi, 8);
    try emitWriteBuffer(allocator, bytes, import_sites, platform, 2, .rsi, .r8);
}

fn emitWriteStringSlot(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    slot: Machine.Slot,
) Error!void {
    try emitLoadStack(allocator, bytes, .rsi, slot);
    try emitLoadMemory(allocator, bytes, .r8, .rsi, 0);
    try emitMaskDynamicStringLength(allocator, bytes, .r8);
    try emitAddImmediateRegister(allocator, bytes, .rsi, 8);
    try emitWriteBuffer(allocator, bytes, import_sites, platform, 2, .rsi, .r8);
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
        .darwin => {
            try emitImmediate(allocator, bytes, .rdi, 0);
            try emitImmediate(allocator, bytes, .rdx, 3);
            try emitImmediate(allocator, bytes, .r10, 0x1002);
            try emitImmediate(allocator, bytes, .r8, std.math.maxInt(u64));
            try emitImmediate(allocator, bytes, .r9, 0);
            try emitImmediate(allocator, bytes, .rax, 0x20000c5);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05, 0x0f, 0x83 });
        },
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

fn emitListHeader(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    pointer: Register,
    count: Register,
    byte_count: Register,
    ownership: @import("../Ir.zig").Ownership,
) Error!void {
    try emitStoreMemory(allocator, bytes, pointer, 0, count);
    try emitImmediate(allocator, bytes, .rax, 0);
    try emitStoreMemory(allocator, bytes, pointer, root_count_offset, .rax);
    try emitStoreMemory(allocator, bytes, pointer, edge_count_offset, .rax);
    try emitStoreMemory(allocator, bytes, pointer, state_offset, .rax);
    try emitImmediate(allocator, bytes, .rax, 1);
    try emitStoreMemory(allocator, bytes, pointer, switch (ownership) {
        .root => root_count_offset,
        .edge => edge_count_offset,
    }, .rax);
    try emitStoreMemory(allocator, bytes, pointer, byte_count_offset, byte_count);
}

fn emitListRetain(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    value: Machine.Instruction.ListResource,
) Error!void {
    try emitLoadStack(allocator, bytes, .r10, value.operand);
    try emitAtomicIncrement(allocator, bytes, .r10, switch (value.ownership) {
        .root => root_count_offset,
        .edge => edge_count_offset,
    });
}

fn emitListDropSlot(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    slot: Machine.Slot,
    ownership: @import("../Ir.zig").Ownership,
) Error!void {
    try emitLoadStack(allocator, bytes, .r10, slot);
    try emitResourceDropPointer(allocator, bytes, import_sites, platform, .r10, ownership);
}

fn emitResourceDropPointer(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    pointer: Register,
    ownership: @import("../Ir.zig").Ownership,
) Error!void {
    if (pointer != .r10) try emitMoveRegister(allocator, bytes, .r10, pointer);
    const count_offset: i32 = switch (ownership) {
        .root => root_count_offset,
        .edge => edge_count_offset,
    };
    const retry = bytes.items.len;
    try emitLoadMemory(allocator, bytes, .rax, .r10, count_offset);
    try emitRegisterBinary(allocator, bytes, 0x85, .rax, .rax);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x84 });
    const already_released = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitMoveRegister(allocator, bytes, .r11, .rax);
    try emitSubtractImmediateRegister(allocator, bytes, .r11, 1);
    try bytes.appendSlice(allocator, &.{ 0xf0, 0x4d, 0x0f, 0xb1, 0x5a, @intCast(count_offset) });
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
    const conflicted = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, conflicted, retry);

    try emitLoadMemory(allocator, bytes, .rax, .r10, root_count_offset);
    try emitLoadMemory(allocator, bytes, .r11, .r10, edge_count_offset);
    try emitRegisterBinary(allocator, bytes, 0x01, .rax, .r11);
    try emitRegisterBinary(allocator, bytes, 0x85, .rax, .rax);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
    const still_referenced = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);

    const claim_retry = bytes.items.len;
    try emitLoadMemory(allocator, bytes, .rax, .r10, state_offset);
    try emitImmediate(allocator, bytes, .rcx, 2);
    try emitRegisterBinary(allocator, bytes, 0x39, .rax, .rcx);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x84 });
    const tracing = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitImmediate(allocator, bytes, .rcx, 1);
    try emitRegisterBinary(allocator, bytes, 0x39, .rax, .rcx);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x84 });
    const already_claimed = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitImmediate(allocator, bytes, .r11, 1);
    try bytes.appendSlice(allocator, &.{ 0xf0, 0x4d, 0x0f, 0xb1, 0x5a, @intCast(state_offset) });
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
    const claim_conflicted = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, tracing, claim_retry);
    try patchRelative(bytes.items, claim_conflicted, claim_retry);
    try emitLoadMemory(allocator, bytes, .rsi, .r10, byte_count_offset);
    try emitDeallocation(allocator, bytes, import_sites, platform, .r10, .rsi);

    const done = bytes.items.len;
    try patchRelative(bytes.items, already_released, done);
    try patchRelative(bytes.items, still_referenced, done);
    try patchRelative(bytes.items, already_claimed, done);
}

fn emitAtomicIncrement(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    pointer: Register,
    offset: i32,
) Allocator.Error!void {
    if (pointer == .r10) {
        try bytes.appendSlice(allocator, &.{ 0xf0, 0x49, 0xff, 0x42, @intCast(offset) });
        return;
    }
    try emitMoveRegister(allocator, bytes, .r10, pointer);
    try bytes.appendSlice(allocator, &.{ 0xf0, 0x49, 0xff, 0x42, @intCast(offset) });
}

fn emitDeallocation(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    pointer: Register,
    byte_count: Register,
) Error!void {
    switch (platform) {
        .darwin => {
            if (pointer != .rdi) try emitMoveRegister(allocator, bytes, .rdi, pointer);
            if (byte_count != .rsi) try emitMoveRegister(allocator, bytes, .rsi, byte_count);
            try emitImmediate(allocator, bytes, .rax, 0x2000049);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });
        },
        .linux => {
            if (pointer != .rdi) try emitMoveRegister(allocator, bytes, .rdi, pointer);
            if (byte_count != .rsi) try emitMoveRegister(allocator, bytes, .rsi, byte_count);
            try emitImmediate(allocator, bytes, .rax, 11);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });
        },
        .windows => {
            if (pointer != .rcx) try emitMoveRegister(allocator, bytes, .rcx, pointer);
            try emitImmediate(allocator, bytes, .rdx, 0);
            try emitImmediate(allocator, bytes, .r8, 0x8000);
            try ExternalCalls.emitWindowsImportCall(allocator, bytes, import_sites, .virtual_free);
        },
    }
}

fn emitRuntimeAllocateCallback(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
) Error!void {
    switch (platform) {
        .darwin => {
            try emitMoveRegister(allocator, bytes, .rsi, .rdi);
            try emitImmediate(allocator, bytes, .rdi, 0);
            try emitImmediate(allocator, bytes, .rdx, 3);
            try emitImmediate(allocator, bytes, .r10, 0x1002);
            try emitImmediate(allocator, bytes, .r8, std.math.maxInt(u64));
            try emitImmediate(allocator, bytes, .r9, 0);
            try emitImmediate(allocator, bytes, .rax, 0x20000c5);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05, 0x0f, 0x83 });
            const succeeded = bytes.items.len;
            try bytes.appendNTimes(allocator, 0, 4);
            try bytes.appendSlice(allocator, &.{ 0x31, 0xc0, 0xc3 });
            try patchRelative(bytes.items, succeeded, bytes.items.len);
            try bytes.append(allocator, 0xc3);
        },
        .linux => {
            try emitMoveRegister(allocator, bytes, .rsi, .rdi);
            try emitImmediate(allocator, bytes, .rdi, 0);
            try emitImmediate(allocator, bytes, .rdx, 3);
            try emitImmediate(allocator, bytes, .r10, 0x22);
            try emitImmediate(allocator, bytes, .r8, std.math.maxInt(u64));
            try emitImmediate(allocator, bytes, .r9, 0);
            try emitImmediate(allocator, bytes, .rax, 9);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05, 0x48, 0x3d });
            try appendInt(allocator, bytes, i32, -4095);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x82 });
            const succeeded = bytes.items.len;
            try bytes.appendNTimes(allocator, 0, 4);
            try bytes.appendSlice(allocator, &.{ 0x31, 0xc0, 0xc3 });
            try patchRelative(bytes.items, succeeded, bytes.items.len);
            try bytes.append(allocator, 0xc3);
        },
        .windows => {
            try bytes.append(allocator, 0x55);
            try emitMoveRegister(allocator, bytes, .rdx, .rdi);
            try emitImmediate(allocator, bytes, .rcx, 0);
            try emitImmediate(allocator, bytes, .r8, 0x3000);
            try emitImmediate(allocator, bytes, .r9, 4);
            try ExternalCalls.emitWindowsImportCall(allocator, bytes, import_sites, .virtual_alloc);
            try bytes.appendSlice(allocator, &.{ 0x5d, 0xc3 });
        },
    }
}

fn emitRuntimeReleaseCallback(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
) Error!void {
    switch (platform) {
        .darwin => {
            try emitImmediate(allocator, bytes, .rax, 0x2000049);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05, 0xc3 });
        },
        .linux => {
            try emitImmediate(allocator, bytes, .rax, 11);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05, 0xc3 });
        },
        .windows => {
            try bytes.append(allocator, 0x55);
            try emitMoveRegister(allocator, bytes, .rcx, .rdi);
            try emitImmediate(allocator, bytes, .rdx, 0);
            try emitImmediate(allocator, bytes, .r8, 0x8000);
            try ExternalCalls.emitWindowsImportCall(allocator, bytes, import_sites, .virtual_free);
            try bytes.appendSlice(allocator, &.{ 0x5d, 0xc3 });
        },
    }
}

fn emitListInit(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.ListInit,
) Error!void {
    const allocation_size = list_header_size + @as(u64, value.values.len) * value.element_width * Machine.slot_size;
    try emitImmediate(allocator, bytes, .rsi, allocation_size);
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r10, .rax);
    try emitImmediate(allocator, bytes, .r12, value.values.len);
    try emitListHeader(allocator, bytes, .r10, .r12, .rsi, .root);
    var offset: i32 = list_header_size;
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
    try emitImmediate(allocator, bytes, .rsi, list_header_size + @as(u64, count) * Machine.slot_size);
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r15, .rax);
    try emitImmediate(allocator, bytes, .r12, count);
    try emitListHeader(allocator, bytes, .r15, .r12, .rsi, .root);
    if (count != 0) {
        try emitStringAddress(allocator, bytes, data_fixups, value.string, value.result);
        try emitLoadStack(allocator, bytes, .rbx, value.result);
        try emitAddImmediateRegister(allocator, bytes, .rbx, Machine.slot_size);
        try emitMoveRegister(allocator, bytes, .r14, .r15);
        try emitAddImmediateRegister(allocator, bytes, .r14, list_header_size);
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
        try emitAddImmediateRegister(allocator, bytes, .rbx, list_header_size);
    }
    try emitLoadStack(allocator, bytes, .rax, value.index);
    try emitNormalizeCollectionIndex(allocator, bytes, .rax, .rcx);
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

fn emitDetachDynamicReference(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.CollectionReference,
) Error!void {
    const reference = value.reference orelse return error.InvalidMachineProgram;
    const stride = if (value.element_stride != 0)
        value.element_stride
    else
        @as(u32, value.element_width) * Machine.slot_size;
    const compact_float32 = stride == @as(u32, value.element_width) * 4;

    const restart = bytes.items.len;
    try emitLoadStack(allocator, bytes, .r15, reference);
    try emitLoadMemory(allocator, bytes, .r14, .r15, 0);
    try emitLoadMemory(allocator, bytes, .rax, .r14, root_count_offset);
    try emitLoadMemory(allocator, bytes, .r11, .r14, edge_count_offset);
    try emitRegisterBinary(allocator, bytes, 0x01, .rax, .r11);
    try emitImmediate(allocator, bytes, .rcx, 1);
    try emitRegisterBinary(allocator, bytes, 0x39, .rax, .rcx);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x84 });
    const unique = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);

    try emitLoadMemory(allocator, bytes, .r12, .r14, 0);
    try emitMoveRegister(allocator, bytes, .rsi, .r12);
    try emitImmediate(allocator, bytes, .rcx, stride);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xaf, 0xf1 });
    try emitAddImmediateRegister(allocator, bytes, .rsi, list_header_size);
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r13, .rax);
    try emitListHeader(allocator, bytes, .r13, .r12, .rsi, value.ownership);

    try emitMoveRegister(allocator, bytes, .rbx, .r14);
    try emitAddImmediateRegister(allocator, bytes, .rbx, list_header_size);
    try emitMoveRegister(allocator, bytes, .r10, .r13);
    try emitAddImmediateRegister(allocator, bytes, .r10, list_header_size);
    try emitMoveRegister(allocator, bytes, .rsi, .r12);
    try emitImmediate(allocator, bytes, .rcx, value.element_width);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xaf, 0xf1, 0x48, 0x85, 0xf6, 0x0f, 0x84 });
    const copied = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    const copy_loop = bytes.items.len;
    if (compact_float32) {
        try emitLoadMemory32(allocator, bytes, .rax, .rbx, 0);
        try emitStoreMemory32(allocator, bytes, .r10, 0, .rax);
    } else {
        try emitLoadMemory(allocator, bytes, .rax, .rbx, 0);
        try emitStoreMemory(allocator, bytes, .r10, 0, .rax);
    }
    const unit_size: u32 = if (compact_float32) 4 else Machine.slot_size;
    try emitAddImmediateRegister(allocator, bytes, .rbx, unit_size);
    try emitAddImmediateRegister(allocator, bytes, .r10, unit_size);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xee, 1, 0x0f, 0x85 });
    const copy_repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, copy_repeat, copy_loop);
    try patchRelative(bytes.items, copied, bytes.items.len);

    try emitMoveRegister(allocator, bytes, .rax, .r14);
    try emitAtomicCompareExchangeMemory(allocator, bytes, .r15, 0, .r13);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
    const publish_lost = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitResourceDropPointer(allocator, bytes, import_sites, platform, .r14, value.ownership);
    try bytes.append(allocator, 0xe9);
    const complete = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);

    try patchRelative(bytes.items, publish_lost, bytes.items.len);
    try emitResourceDropPointer(allocator, bytes, import_sites, platform, .r13, value.ownership);
    try bytes.append(allocator, 0xe9);
    const retry_detach = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, retry_detach, restart);

    try patchRelative(bytes.items, complete, bytes.items.len);
    try patchRelative(bytes.items, unique, bytes.items.len);
}

fn emitCollectionReference(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.CollectionReference,
) Error!void {
    if (value.dynamic and !value.view and value.reference != null) {
        try emitDetachDynamicReference(allocator, bytes, import_sites, platform, epilogue, value);
    }
    if (value.dynamic) {
        if (!value.view and value.reference != null) {
            try emitLoadStack(allocator, bytes, .rbx, value.reference.?);
            try emitLoadMemory(allocator, bytes, .rbx, .rbx, 0);
        } else try emitLoadStack(allocator, bytes, .rbx, value.collection.start);
        if (value.view) {
            try emitLoadStack(allocator, bytes, .rcx, @intCast(@as(usize, value.collection.start) + 1));
        } else {
            try emitLoadMemory(allocator, bytes, .rcx, .rbx, 0);
            try emitAddImmediateRegister(allocator, bytes, .rbx, list_header_size);
        }
    } else {
        try emitLoadStack(allocator, bytes, .rbx, value.reference orelse return error.InvalidMachineProgram);
        try emitImmediate(allocator, bytes, .rcx, value.count);
    }
    try emitLoadStack(allocator, bytes, .rax, value.index);
    try emitNormalizeCollectionIndex(allocator, bytes, .rax, .rcx);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xc8, 0x0f, 0x82 });
    const in_bounds = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitRuntimeFailure(allocator, bytes, epilogue);
    try patchRelative(bytes.items, in_bounds, bytes.items.len);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x69, 0xc0 });
    try appendInt(allocator, bytes, u32, if (value.element_stride != 0) value.element_stride else @as(u32, value.element_width) * Machine.slot_size);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x01, 0xd8 });
    try emitStoreStack(allocator, bytes, .rax, value.result);
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
    try emitNormalizeCollectionIndex(allocator, bytes, .rax, .rcx);
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
    try emitNormalizeCollectionIndex(allocator, bytes, .r13, .r12);
    try bytes.appendSlice(allocator, &.{ 0x4d, 0x39, 0xe5, 0x0f, 0x82 });
    const in_bounds = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitRuntimeFailure(allocator, bytes, epilogue);
    try patchRelative(bytes.items, in_bounds, bytes.items.len);

    // A unique list can be updated directly. Shared storage still takes the
    // allocation path below so aliases keep copy-on-write value semantics.
    try emitLoadMemory(allocator, bytes, .rax, .rbx, root_count_offset);
    try emitLoadMemory(allocator, bytes, .r11, .rbx, edge_count_offset);
    try emitRegisterBinary(allocator, bytes, 0x01, .rax, .r11);
    try emitImmediate(allocator, bytes, .rcx, 1);
    try emitRegisterBinary(allocator, bytes, 0x39, .rax, .rcx);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x85 });
    const shared = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);

    try emitMoveRegister(allocator, bytes, .r14, .rbx);
    try emitAddImmediateRegister(allocator, bytes, .r14, list_header_size);
    try emitMoveRegister(allocator, bytes, .rax, .r13);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x69, 0xc0 });
    try appendInt(allocator, bytes, u32, @as(u32, value.replacement.width) * Machine.slot_size);
    try emitRegisterBinary(allocator, bytes, 0x01, .r14, .rax);
    for (0..value.replacement.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.replacement.start) + leaf));
        try emitStoreMemory(allocator, bytes, .r14, @intCast(leaf * Machine.slot_size), .rax);
    }
    try emitStoreStack(allocator, bytes, .rbx, value.result.start);
    try bytes.append(allocator, 0xe9);
    const reused = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, shared, bytes.items.len);

    try emitMoveRegister(allocator, bytes, .rsi, .r12);
    try emitImmediate(allocator, bytes, .rcx, @as(u64, value.replacement.width) * Machine.slot_size);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xaf, 0xf1 });
    try emitAddImmediateRegister(allocator, bytes, .rsi, list_header_size);
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r15, .rax);
    try emitListHeader(allocator, bytes, .r15, .r12, .rsi, value.ownership);
    try emitAddImmediateRegister(allocator, bytes, .rbx, list_header_size);
    try emitMoveRegister(allocator, bytes, .r14, .r15);
    try emitAddImmediateRegister(allocator, bytes, .r14, list_header_size);
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
    try emitAddImmediateRegister(allocator, bytes, .r14, list_header_size);
    try emitMoveRegister(allocator, bytes, .rax, .r13);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x69, 0xc0 });
    try appendInt(allocator, bytes, u32, @as(u32, value.replacement.width) * Machine.slot_size);
    try bytes.appendSlice(allocator, &.{ 0x49, 0x01, 0xc6 });
    for (0..value.replacement.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.replacement.start) + leaf));
        try emitStoreMemory(allocator, bytes, .r14, @intCast(leaf * Machine.slot_size), .rax);
    }
    try emitStoreStack(allocator, bytes, .r15, value.result.start);
    try emitListDropSlot(allocator, bytes, import_sites, platform, value.collection.start, value.ownership);
    try patchRelative(bytes.items, reused, bytes.items.len);
}

fn emitFixedReplace(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.CollectionReplace,
) Error!void {
    try emitLoadStack(allocator, bytes, .r13, value.index);
    try emitImmediate(allocator, bytes, .r12, value.count);
    try emitNormalizeCollectionIndex(allocator, bytes, .r13, .r12);
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
    try bytes.appendSlice(allocator, &.{ 0x49, 0x01, 0xc6 });
    for (0..value.replacement.width) |leaf| {
        try emitLoadStack(allocator, bytes, .rax, @intCast(@as(usize, value.replacement.start) + leaf));
        try emitStoreMemory(allocator, bytes, .r14, @intCast(leaf * Machine.slot_size), .rax);
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
        try emitImmediate(allocator, bytes, .rsi, list_header_size);
        try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
        try emitMoveRegister(allocator, bytes, .r10, .rax);
        try emitImmediate(allocator, bytes, .r12, 0);
        try emitListHeader(allocator, bytes, .r10, .r12, .rsi, value.ownership);
        try emitStoreStack(allocator, bytes, .r10, value.result);
        try emitListDropSlot(allocator, bytes, import_sites, platform, value.collection, value.ownership);
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
    try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xaf, 0xf1 });
    try emitAddImmediateRegister(allocator, bytes, .rsi, list_header_size);
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r15, .rax);
    try emitListHeader(allocator, bytes, .r15, .r13, .rsi, value.ownership);
    try emitAddImmediateRegister(allocator, bytes, .rbx, list_header_size);
    try emitMoveRegister(allocator, bytes, .r14, .r15);
    try emitAddImmediateRegister(allocator, bytes, .r14, list_header_size);
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
    try emitListDropSlot(allocator, bytes, import_sites, platform, value.collection, value.ownership);
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
            try emitNormalizeCollectionIndex(allocator, bytes, .r13, .r12);
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
    try emitAddImmediateRegister(allocator, bytes, .rsi, list_header_size);
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
    try emitListHeader(allocator, bytes, .r15, .rax, .rsi, value.ownership);

    if (value.removed) |removed| {
        try emitLoadStack(allocator, bytes, .r10, value.collection);
        try emitAddImmediateRegister(allocator, bytes, .r10, list_header_size);
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
    try emitAddImmediateRegister(allocator, bytes, .rbx, list_header_size);
    try emitMoveRegister(allocator, bytes, .r14, .r15);
    try emitAddImmediateRegister(allocator, bytes, .r14, list_header_size);
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
                try emitAddImmediateRegister(allocator, bytes, .rbx, list_header_size);
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
    if (value.argument_dynamic and value.argument_transferred) {
        try emitListDropSlot(allocator, bytes, import_sites, platform, value.argument.?.start, .root);
    }
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
        try emitAddImmediateRegister(allocator, bytes, .r14, list_header_size);
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
    try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, 0xaf, 0xf1 });
    try emitAddImmediateRegister(allocator, bytes, .rsi, list_header_size);
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r15, .rax);
    try emitListHeader(allocator, bytes, .r15, .r13, .rsi, value.ownership);
    try emitAddImmediateRegister(allocator, bytes, .rbx, list_header_size);
    try emitMoveRegister(allocator, bytes, .r14, .r15);
    try emitAddImmediateRegister(allocator, bytes, .r14, list_header_size);
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
        try emitAddImmediateRegister(allocator, bytes, .rbx, list_header_size);
    } else {
        try emitAddressStack(allocator, bytes, .rbx, value.collection.start);
        try emitImmediate(allocator, bytes, .rcx, value.count);
    }
    try emitLoadStack(allocator, bytes, .rax, value.start);
    try emitNormalizeBound(allocator, bytes, .rax, .rcx);
    try emitLoadStack(allocator, bytes, .rdx, value.end);
    try emitNormalizeBound(allocator, bytes, .rdx, .rcx);
    try emitImmediate(allocator, bytes, .r11, 0);
    try emitRegisterBinary(allocator, bytes, 0x39, .rax, .rdx);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x8d });
    const empty = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitMoveRegister(allocator, bytes, .r11, .rdx);
    try emitRegisterBinary(allocator, bytes, 0x29, .r11, .rax);
    try patchRelative(bytes.items, empty, bytes.items.len);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x69, 0xc0 });
    try appendInt(allocator, bytes, u32, @as(u32, value.element_width) * Machine.slot_size);
    try emitRegisterBinary(allocator, bytes, 0x01, .rbx, .rax);
    try emitStoreStack(allocator, bytes, .rbx, value.result.start);
    try emitStoreStack(allocator, bytes, .r11, @intCast(@as(usize, value.result.start) + 1));
    _ = epilogue;
}

fn emitCollectionSlice(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: *std.ArrayList(EpilogueFixup),
    value: Machine.Instruction.CollectionSlice,
) Error!void {
    if (value.view) {
        try emitLoadStack(allocator, bytes, .r12, value.collection.start);
        try emitLoadStack(allocator, bytes, .rcx, @intCast(@as(usize, value.collection.start) + 1));
    } else if (value.dynamic) {
        try emitLoadStack(allocator, bytes, .r12, value.collection.start);
        try emitLoadMemory(allocator, bytes, .rcx, .r12, 0);
        try emitAddImmediateRegister(allocator, bytes, .r12, list_header_size);
    } else {
        try emitAddressStack(allocator, bytes, .r12, value.collection.start);
        try emitImmediate(allocator, bytes, .rcx, value.count);
    }
    try emitLoadStack(allocator, bytes, .rax, value.start);
    try emitNormalizeBound(allocator, bytes, .rax, .rcx);
    try emitLoadStack(allocator, bytes, .rdx, value.end);
    try emitNormalizeBound(allocator, bytes, .rdx, .rcx);

    try emitImmediate(allocator, bytes, .r14, 0);
    try emitRegisterBinary(allocator, bytes, 0x39, .rax, .rdx);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x8d });
    const empty = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitMoveRegister(allocator, bytes, .r14, .rdx);
    try emitRegisterBinary(allocator, bytes, 0x29, .r14, .rax);
    try patchRelative(bytes.items, empty, bytes.items.len);
    try emitMoveRegister(allocator, bytes, .r13, .rax);

    const stride = @as(u32, value.element_width) * Machine.slot_size;
    try emitMoveRegister(allocator, bytes, .rsi, .r14);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x69, 0xf6 });
    try appendInt(allocator, bytes, u32, stride);
    try emitAddImmediateRegister(allocator, bytes, .rsi, list_header_size);
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r15, .rax);
    try emitListHeader(allocator, bytes, .r15, .r14, .rsi, .root);

    try emitMoveRegister(allocator, bytes, .rax, .r13);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x69, 0xc0 });
    try appendInt(allocator, bytes, u32, stride);
    try emitRegisterBinary(allocator, bytes, 0x01, .r12, .rax);
    try emitMoveRegister(allocator, bytes, .r10, .r15);
    try emitAddImmediateRegister(allocator, bytes, .r10, list_header_size);
    try emitMoveRegister(allocator, bytes, .rsi, .r14);
    try emitRegisterBinary(allocator, bytes, 0x85, .rsi, .rsi);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x84 });
    const copied = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    const loop = bytes.items.len;
    for (0..value.element_width) |leaf| {
        const source_offset: i32 = @intCast(leaf * Machine.slot_size);
        try emitLoadMemory(allocator, bytes, .rax, .r12, source_offset);
        try emitStoreMemory(allocator, bytes, .r10, @intCast(leaf * Machine.slot_size), .rax);
    }
    try emitAddImmediateRegister(allocator, bytes, .r12, stride);
    try emitAddImmediateRegister(allocator, bytes, .r10, stride);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xee, 1, 0x0f, 0x85 });
    const repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, repeat, loop);
    try patchRelative(bytes.items, copied, bytes.items.len);
    try emitStoreStack(allocator, bytes, .r15, value.result);
}

fn emitNormalizeBound(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    bound: Register,
    count: Register,
) Error!void {
    try emitRegisterBinary(allocator, bytes, 0x85, bound, bound);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x89 });
    const nonnegative = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitRegisterBinary(allocator, bytes, 0x01, bound, count);
    try patchRelative(bytes.items, nonnegative, bytes.items.len);

    try emitRegisterBinary(allocator, bytes, 0x85, bound, bound);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x89 });
    const not_below = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitImmediate(allocator, bytes, bound, 0);
    try patchRelative(bytes.items, not_below, bytes.items.len);

    try emitRegisterBinary(allocator, bytes, 0x39, bound, count);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x8e });
    const not_above = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitMoveRegister(allocator, bytes, bound, count);
    try patchRelative(bytes.items, not_above, bytes.items.len);
}

fn emitNormalizeCollectionIndex(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    index: Register,
    count: Register,
) Error!void {
    try emitRegisterBinary(allocator, bytes, 0x85, index, index);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x89 });
    const nonnegative = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitRegisterBinary(allocator, bytes, 0x01, index, count);
    try patchRelative(bytes.items, nonnegative, bytes.items.len);
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
        .darwin => {
            try emitMoveRegister(allocator, bytes, .rdi, .r10);
            try emitLoadMemory(allocator, bytes, .rsi, .r10, 8);
            try emitImmediate(allocator, bytes, .rax, 0x2000049);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });
        },
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

fn emitWindowsFunctionThunk(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    calls: *std.ArrayList(CallFixup),
    function: Machine.Function,
    function_id: usize,
) Error!void {
    // Silex uses its portable internal register convention while Win64 enters
    // callbacks through RCX, RDX, R8 and R9. Preserve every Win64 nonvolatile
    // register that a Silex function may use, then bridge the scalar arguments.
    try bytes.appendSlice(allocator, &.{
        0x53, 0x56, 0x57,
        0x41, 0x54, 0x41,
        0x55, 0x41, 0x56,
        0x41, 0x57,
    });
    const outgoing_stack_size: u32 = @intCast(std.mem.alignForward(
        usize,
        (function.parameters.len -| 8) * Machine.slot_size,
        16,
    ));
    try emitStackSubtraction(allocator, bytes, outgoing_stack_size);
    const incoming = [_]Register{ .rcx, .rdx, .r8, .r9 };
    const internal = [_]Register{ .rdi, .rsi, .rdx, .rcx };
    for (incoming[0..@min(function.parameters.len, 4)], internal[0..@min(function.parameters.len, 4)]) |source, destination| {
        try emitMoveRegister(allocator, bytes, destination, source);
    }
    const stacked = [_]Register{ .r8, .r9, .r10, .r11 };
    for (stacked[0..@min(function.parameters.len -| 4, stacked.len)], 0..) |destination, index| {
        try emitLoadMemory(allocator, bytes, destination, .rsp, @intCast(outgoing_stack_size + 96 + index * Machine.slot_size));
    }
    if (function.parameters.len > 8) {
        for (8..function.parameters.len) |index| {
            try emitLoadMemory(allocator, bytes, .rax, .rsp, @intCast(outgoing_stack_size + 96 + (index - 4) * Machine.slot_size));
            try emitStoreMemory(allocator, bytes, .rsp, @intCast((index - 8) * Machine.slot_size), .rax);
        }
    }
    try appendCall(allocator, bytes, calls, function_id);
    try emitStackAddition(allocator, bytes, outgoing_stack_size);
    try bytes.appendSlice(allocator, &.{
        0x41, 0x5f, 0x41, 0x5e, 0x41, 0x5d, 0x41, 0x5c,
        0x5f, 0x5e, 0x5b, 0xc3,
    });
}

fn emitLinuxFunctionThunk(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    calls: *std.ArrayList(CallFixup),
    function: Machine.Function,
    function_id: usize,
) Error!void {
    // System V and Silex share their first six scalar argument registers, but
    // Silex may use RBX and R12-R15 as scratch state and keeps arguments seven
    // and eight in R10/R11. Bridge both differences for every exposed address.
    try bytes.appendSlice(allocator, &.{
        0x53, 0x41, 0x54, 0x41, 0x55, 0x41, 0x56, 0x41, 0x57,
    });
    const outgoing_stack_size: u32 = @intCast(std.mem.alignForward(
        usize,
        (function.parameters.len -| 8) * Machine.slot_size,
        16,
    ));
    try emitStackSubtraction(allocator, bytes, outgoing_stack_size);
    const stacked = [_]Register{ .r10, .r11 };
    for (stacked[0..@min(function.parameters.len -| 6, stacked.len)], 0..) |destination, index| {
        try emitLoadMemory(allocator, bytes, destination, .rsp, @intCast(outgoing_stack_size + 48 + index * Machine.slot_size));
    }
    if (function.parameters.len > 8) {
        for (8..function.parameters.len) |index| {
            try emitLoadMemory(allocator, bytes, .rax, .rsp, @intCast(outgoing_stack_size + 48 + (index - 6) * Machine.slot_size));
            try emitStoreMemory(allocator, bytes, .rsp, @intCast((index - 8) * Machine.slot_size), .rax);
        }
    }
    try appendCall(allocator, bytes, calls, function_id);
    try emitStackAddition(allocator, bytes, outgoing_stack_size);
    try bytes.appendSlice(allocator, &.{
        0x41, 0x5f, 0x41, 0x5e, 0x41, 0x5d, 0x41, 0x5c, 0x5b, 0xc3,
    });
}

fn emitLinuxCallbackArguments(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    arguments: []const Machine.Span,
) Error!u32 {
    const stack_size: u32 = @intCast(std.mem.alignForward(usize, (arguments.len -| 6) * Machine.slot_size, 16));
    try emitStackSubtraction(allocator, bytes, stack_size);
    const registers = [_]Register{ .rdi, .rsi, .rdx, .rcx, .r8, .r9 };
    for (arguments[0..@min(arguments.len, registers.len)], registers[0..@min(arguments.len, registers.len)]) |argument, register| {
        if (argument.aggregate) {
            try emitAddressStack(allocator, bytes, register, argument.start);
        } else {
            if (argument.width != 1) return error.InvalidMachineProgram;
            try emitLoadStack(allocator, bytes, register, argument.start);
        }
    }
    for (arguments[@min(arguments.len, registers.len)..], 0..) |argument, index| {
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

fn emitWindowsCallbackArguments(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    arguments: []const Machine.Span,
) Error!u32 {
    const stack_size: u32 = @intCast(std.mem.alignForward(usize, 32 + (arguments.len -| 4) * Machine.slot_size, 16));
    try emitStackSubtraction(allocator, bytes, stack_size);
    const registers = [_]Register{ .rcx, .rdx, .r8, .r9 };
    for (arguments[0..@min(arguments.len, 4)], registers[0..@min(arguments.len, 4)]) |argument, register| {
        if (argument.aggregate) {
            try emitAddressStack(allocator, bytes, register, argument.start);
        } else {
            if (argument.width != 1) return error.InvalidMachineProgram;
            try emitLoadStack(allocator, bytes, register, argument.start);
        }
    }
    for (arguments[@min(arguments.len, 4)..], 0..) |argument, index| {
        if (argument.aggregate) {
            try emitAddressStack(allocator, bytes, .rax, argument.start);
        } else {
            if (argument.width != 1) return error.InvalidMachineProgram;
            try emitLoadStack(allocator, bytes, .rax, argument.start);
        }
        try emitStoreMemory(allocator, bytes, .rsp, @intCast(32 + index * Machine.slot_size), .rax);
    }
    return stack_size;
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

fn emitLoadValue(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    residences: []const ?u5,
    register: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    if (residences.len != 0) if (residences[slot]) |residence| {
        const source: Register = @enumFromInt(residence);
        if (source != register) try emitMoveRegister(allocator, bytes, register, source);
        return;
    };
    try emitLoadStack(allocator, bytes, register, slot);
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

fn emitRipAddress(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register) Allocator.Error!usize {
    const rex: u8 = 0x48 | (@as(u8, @intFromBool(@intFromEnum(register) >= 8)) << 2);
    try bytes.appendSlice(allocator, &.{
        rex,
        0x8d,
        0x05 | ((@as(u8, @intFromEnum(register)) & 7) << 3),
    });
    const displacement_at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    return displacement_at;
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

    // Linux exposes gettid(2); Darwin exposes thread_selfid(2). Both return
    // a stable non-zero identifier suitable for the private reentrant owner.
    try emitImmediate(allocator, bytes, .rax, if (platform == .darwin) 0x2000174 else 186);
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

fn emitStoreValue(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    residences: []const ?u5,
    register: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    if (residences.len != 0) if (residences[slot]) |residence| {
        const destination: Register = @enumFromInt(residence);
        if (destination != register) try emitMoveRegister(allocator, bytes, destination, register);
        return;
    };
    try emitStoreStack(allocator, bytes, register, slot);
}

fn emitFrameAllocation(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    platform: Platform,
    frame_size: u32,
) Allocator.Error!void {
    var remaining = frame_size;
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
    if (amount == 0) return;
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

fn emitLoadMemory32(allocator: Allocator, bytes: *std.ArrayList(u8), destination: Register, base: Register, displacement: i32) Allocator.Error!void {
    const rex: u8 = 0x40 | (@as(u8, @intFromBool(@intFromEnum(destination) >= 8)) << 2) | @intFromBool(@intFromEnum(base) >= 8);
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

fn emitStoreMemory32(allocator: Allocator, bytes: *std.ArrayList(u8), base: Register, displacement: i32, source: Register) Allocator.Error!void {
    const rex: u8 = 0x40 | (@as(u8, @intFromBool(@intFromEnum(source) >= 8)) << 2) | @intFromBool(@intFromEnum(base) >= 8);
    const base_bits: u8 = @as(u8, @intFromEnum(base) & 7);
    try bytes.append(allocator, rex);
    try bytes.append(allocator, 0x89);
    try bytes.append(allocator, 0x80 | (@as(u8, @intFromEnum(source) & 7) << 3) | base_bits);
    if (base_bits == 4) try bytes.append(allocator, 0x24);
    try appendInt(allocator, bytes, i32, displacement);
}

fn emitAtomicCompareExchangeMemory(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    base: Register,
    displacement: i32,
    replacement: Register,
) Allocator.Error!void {
    const rex: u8 = 0x48 | (@as(u8, @intFromBool(@intFromEnum(replacement) >= 8)) << 2) | @intFromBool(@intFromEnum(base) >= 8);
    const base_bits: u8 = @as(u8, @intFromEnum(base) & 7);
    try bytes.appendSlice(allocator, &.{ 0xf0, rex, 0x0f, 0xb1 });
    try bytes.append(allocator, 0x80 | (@as(u8, @intFromEnum(replacement) & 7) << 3) | base_bits);
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
    return @as(i32, slot) * Machine.slot_size;
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

test "encode a no-op Silex main for the X64 process and Mach-O entry contracts" {
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

    const darwin = try encodeDarwin(std.testing.allocator, .{ .functions = &functions });
    defer darwin.deinit(std.testing.allocator);
    const darwin_entry = darwin.code[darwin.entry_offset..][0..27];
    try std.testing.expectEqualSlices(u8, &.{ 0x53, 0x41, 0x54, 0x41, 0x55, 0x41, 0x56, 0x41, 0x57 }, darwin_entry[0..9]);
    try std.testing.expectEqualSlices(u8, &.{ 0x41, 0x5f, 0x41, 0x5e, 0x41, 0x5d, 0x41, 0x5c, 0x5b, 0xc3 }, darwin_entry[17..27]);
    try std.testing.expect(std.mem.indexOf(u8, darwin_entry, &.{ 0x0f, 0x05 }) == null);

    const windows = try encodeWindows(std.testing.allocator, .{ .functions = &functions });
    defer windows.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), windows.windows_import_sites.len);
    try std.testing.expectEqual(@as(u8, 0xc3), windows.code[windows.code.len - 1]);
}

test "encode X64 panic diagnostics for both process contracts" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("../Frontend.zig").Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func main() { panic("checkpoint") }
    );
    const machine = try @import("../Arm64/Lower.zig").lower(allocator, compilation.ir);

    const linux = try encodeLinux(allocator, machine);
    defer linux.deinit(allocator);
    try std.testing.expect(std.mem.indexOf(u8, linux.code, &.{ 0x0f, 0x05 }) != null);

    const windows = try encodeWindows(allocator, machine);
    defer windows.deinit(allocator);
    var writes: usize = 0;
    for (windows.windows_import_sites) |site| {
        if (site.symbol == .crt_write) writes += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), writes);
}

test "encode ABI callback thunks for Silex function addresses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("../Frontend.zig").Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func worker(a:int,b:int,c:int,d:int,e:int,f:int,g:int,h:int,i:int,j:int) int {
        \\    return a+b+c+d+e+f+g+h+i+j
        \\}
        \\func increment(value:int) int { return value + 1 }
        \\func main() {
        \\    let callback:func(int,int,int,int,int,int,int,int,int,int) int = worker
        \\    assert(callback(1,2,3,4,5,6,7,8,9,10) == 55)
        \\    let incrementer:func(int) int = increment
        \\    assert(incrementer(41) == 42)
        \\}
    );
    const machine = try @import("../Arm64/Lower.zig").lower(allocator, compilation.ir);
    const linux = try encodeLinux(allocator, machine);
    defer linux.deinit(allocator);
    const linux_address = std.mem.indexOf(u8, linux.code, &.{ 0x48, 0x8d, 0x05 }) orelse return error.InvalidMachineProgram;
    const linux_displacement_at = linux_address + 3;
    const linux_displacement = std.mem.readInt(i32, linux.code[linux_displacement_at..][0..4], .little);
    const linux_thunk_start: usize = @intCast(@as(i64, @intCast(linux_displacement_at + 4)) + linux_displacement);
    try std.testing.expectEqualSlices(u8, &.{
        0x53, 0x41, 0x54, 0x41, 0x55, 0x41, 0x56, 0x41, 0x57,
        0x48, 0x81, 0xec, 0x10, 0x00, 0x00, 0x00,
    }, linux.code[linux_thunk_start..][0..16]);

    const image = try encodeWindows(allocator, machine);
    defer image.deinit(allocator);
    const address_instruction = std.mem.indexOf(u8, image.code, &.{ 0x48, 0x8d, 0x05 }) orelse return error.InvalidMachineProgram;
    const displacement_at = address_instruction + 3;
    const displacement = std.mem.readInt(i32, image.code[displacement_at..][0..4], .little);
    const thunk_start: usize = @intCast(@as(i64, @intCast(displacement_at + 4)) + displacement);
    const expected = [_]u8{
        0x53, 0x56, 0x57,
        0x41, 0x54, 0x41,
        0x55, 0x41, 0x56,
        0x41, 0x57, 0x48,
        0x81, 0xec, 0x10,
        0x00, 0x00, 0x00,
        0x48, 0x89, 0xcf,
    };
    try std.testing.expectEqualSlices(u8, &expected, image.code[thunk_start..][0..expected.len]);
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

test "encode float32 to float64 widening on X64" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_float32 = .{ .result = 0, .bits = @bitCast(@as(f32, 1.5)) } },
        .{ .convert = .{
            .result = 1,
            .operand = 0,
            .source = .float32,
            .target = .float64,
            .header = 0,
            .checked = true,
        } },
        .return_void,
    };
    const functions = [_]Machine.Function{.{
        .name = "main",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 2,
        .frame_size = 16,
        .instructions = &instructions,
    }};
    const program: Machine.Program = .{ .functions = &functions, .strings = &.{"conversion"} };
    try Machine.validate(program);

    const image = try encodeLinux(std.testing.allocator, program);
    defer image.deinit(std.testing.allocator);
    try std.testing.expect(std.mem.indexOf(u8, image.code, &.{ 0xf3, 0x0f, 0x5a, 0xc0 }) != null);
}

test "encode float64 to float32 narrowing on X64" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_float64 = .{ .result = 0, .bits = @bitCast(@as(f64, 100.0)) } },
        .{ .convert = .{
            .result = 1,
            .operand = 0,
            .source = .float64,
            .target = .float32,
            .header = 0,
            .checked = true,
        } },
        .return_void,
    };
    const functions = [_]Machine.Function{.{
        .name = "main",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 2,
        .frame_size = 16,
        .instructions = &instructions,
    }};
    const program: Machine.Program = .{ .functions = &functions, .strings = &.{"conversion"} };
    try Machine.validate(program);

    const image = try encodeLinux(std.testing.allocator, program);
    defer image.deinit(std.testing.allocator);
    try std.testing.expect(std.mem.indexOf(u8, image.code, &.{ 0xf2, 0x0f, 0x5a, 0xc0 }) != null);
}

test "encode indirect C ABI calls on Linux and Windows X64" {
    const arguments = [_]Machine.Slot{ 1, 2 };
    const argument_types = [_]Machine.AbiValue{ .int32, .int32 };
    const instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 4096, .type = .uint } },
        .{ .constant_int = .{ .result = 1, .bits = 19, .type = .int32 } },
        .{ .constant_int = .{ .result = 2, .bits = 23, .type = .int32 } },
        .{ .external_indirect_call = .{
            .result = 3,
            .callee = 0,
            .signature = .{ .arguments = &argument_types, .result = .int32 },
            .arguments = &arguments,
        } },
        .return_void,
    };
    const functions = [_]Machine.Function{.{
        .name = "main",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 4,
        .frame_size = 32,
        .instructions = &instructions,
    }};
    const machine: Machine.Program = .{ .functions = &functions };
    try Machine.validate(machine);
    const linux = try encodeLinux(std.testing.allocator, machine);
    defer linux.deinit(std.testing.allocator);
    const windows = try encodeWindows(std.testing.allocator, machine);
    defer windows.deinit(std.testing.allocator);
    try std.testing.expect(linux.code.len > 0);
    try std.testing.expect(windows.code.len > 0);
}

test "encode X64 dynamic protocol calls beyond the register window" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("../Frontend.zig").Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\protocol Total {
        \\    func total(a:int,b:int,c:int,d:int,e:int,f:int,g:int,h:int) int
        \\}
        \\struct Offset : Total {
        \\    let value:int
        \\    func total(a:int,b:int,c:int,d:int,e:int,f:int,g:int,h:int) int {
        \\        return self.value+a+b+c+d+e+f+g+h
        \\    }
        \\}
        \\class ClassOffset : Total {
        \\    let value:int
        \\    init(value:int) { self.value = value }
        \\    func total(a:int,b:int,c:int,d:int,e:int,f:int,g:int,h:int) int {
        \\        return self.value+a+b+c+d+e+f+g+h
        \\    }
        \\}
        \\func main() {
        \\    var value:Total = Offset(value:6)
        \\    assert(value.total(1,2,3,4,5,6,7,8) == 42)
        \\    value = ClassOffset(6)
        \\    assert(value.total(1,2,3,4,5,6,7,8) == 42)
        \\}
    );
    const machine = try @import("../Arm64/Lower.zig").lower(allocator, compilation.ir);

    const linux = try encodeLinux(allocator, machine);
    defer linux.deinit(allocator);
    const windows = try encodeWindows(allocator, machine);
    defer windows.deinit(allocator);
    try std.testing.expect(linux.code.len > 0);
    try std.testing.expect(windows.code.len > 0);
}

test "encode X64 ownership and deep-copy runtime callbacks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("../Frontend.zig").Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\class State { var value:int; drop { print("drop state") } }
        \\struct Graph { var first:State; var again:State; var values:State[] }
        \\func main() {
        \\    var state = State(value:5)
        \\    var source = Graph(first:state, again:state, values:[state, state])
        \\    var detached = copy source
        \\    assert(detached.first == detached.again)
        \\    assert(detached.first != source.first)
        \\}
    );
    const machine = try @import("../Arm64/Lower.zig").lower(allocator, compilation.ir);

    const linux = try encodeLinux(allocator, machine);
    defer linux.deinit(allocator);
    const windows = try encodeWindows(allocator, machine);
    defer windows.deinit(allocator);
    try std.testing.expect(linux.code.len > 4096);
    try std.testing.expect(windows.code.len > 4096);
    try std.testing.expect(windows.windows_import_sites.len >= 2);
}

test "X64 scalar allocation reduces leaf arithmetic code" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("../Frontend.zig").Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func total(a:int, b:int, c:int, d:int) int {
        \\    let first = a + b
        \\    let second = c + d
        \\    return first * second
        \\}
        \\func main() { assert(total(1, 2, 3, 4) == 21) }
    );
    const stack_program = try @import("../Arm64/Lower.zig").lower(allocator, compilation.ir);
    const register_program = try @import("RegisterAllocation.zig").allocateProgram(allocator, stack_program);
    const stack_image = try encodeLinux(allocator, stack_program);
    defer stack_image.deinit(allocator);
    const register_image = try encodeLinux(allocator, register_program);
    defer register_image.deinit(allocator);
    try std.testing.expect(register_image.code.len < stack_image.code.len);
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
