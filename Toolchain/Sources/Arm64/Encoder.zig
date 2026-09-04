const std = @import("std");
const Machine = @import("Machine.zig");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const A64 = @import("Instructions.zig");
const Fixups = @import("Fixups.zig");
const StringRuntime = @import("StringRuntime.zig");
const ListRuntime = @import("ListRuntime.zig");
const ClassRuntime = @import("ClassRuntime.zig");
const ProtocolRuntime = @import("ProtocolRuntime.zig");
const TextRuntime = @import("TextRuntime.zig");
const FloatRuntime = @import("FloatRuntime.zig");
const DeepCopyRuntime = @import("DeepCopyRuntime.zig");
const CycleRuntime = @import("CycleRuntime.zig");
const ExternalCalls = @import("ExternalCalls.zig");
const MemoryResidence = @import("MemoryResidence.zig");
const Allocation = @import("Allocation.zig");
const Pairing = @import("Pairing.zig");
const LoopCursor = @import("LoopCursor.zig");
const Register = A64.Register;
const Condition = A64.Condition;
const enable_cycle_collector = true;
const saveFrame = A64.saveFrame;
const moveFramePointer = A64.moveFramePointer;
const restoreFrame = A64.restoreFrame;
const returnInstruction = A64.returnInstruction;
const moveRegister = A64.moveRegister;
const moveWideZero32 = A64.moveWideZero32;
const moveWideZero64 = A64.moveWideZero64;
const moveWideKeep64 = A64.moveWideKeep64;
const addSubtractImmediate = A64.addSubtractImmediate;
const storeStack = A64.storeStack;
const loadStack = A64.loadStack;
const storeByte = A64.storeByte;
const store64 = A64.store64;
const load64 = A64.load64;
const serviceCall = A64.serviceCall;
const addSetFlags = A64.addSetFlags;
const subtractSetFlags = A64.subtractSetFlags;
const multiply = A64.multiply;
const signedMultiplyHigh = A64.signedMultiplyHigh;
const unsignedMultiplyHigh = A64.unsignedMultiplyHigh;
const arithmeticShiftRight63 = A64.arithmeticShiftRight63;
const signedDivide = A64.signedDivide;
const unsignedDivide = A64.unsignedDivide;
const andRegisters = A64.andRegisters;
const exclusiveOrRegisters = A64.exclusiveOrRegisters;
const logicalShiftLeftVariable = A64.logicalShiftLeftVariable;
const logicalShiftRightVariable = A64.logicalShiftRightVariable;
const signExtendRegister = A64.signExtendRegister;
const moveGeneralToFloat = A64.moveGeneralToFloat;
const moveFloatToGeneral = A64.moveFloatToGeneral;
const moveFloat = A64.moveFloat;
const floatNegate = A64.floatNegate;
const floatZero = A64.floatZero;
const floatArithmetic = A64.floatArithmetic;
const floatArithmetic2 = A64.floatArithmetic2;
const floatMultiplyAdd = A64.floatMultiplyAdd;
const floatMaxNumber = A64.floatMaxNumber;
const floatCompare = A64.floatCompare;
const floatCompareZero = A64.floatCompareZero;
const floatConditionalCompare = A64.floatConditionalCompare;
const integerToFloat = A64.integerToFloat;
const floatToInteger = A64.floatToInteger;
const floatConvert = A64.floatConvert;
const multiplySubtract = A64.multiplySubtract;
const compareRegisters = A64.compareRegisters;
const conditionalBranch = A64.conditionalBranch;
const compareBranchZero = A64.compareBranchZero;
const compareBranchZero64 = A64.compareBranchZero64;
const compareBranchNonZero = A64.compareBranchNonZero;
const compareBranchNonZero64 = A64.compareBranchNonZero64;
const branch = A64.branch;
const branchLink = A64.branchLink;
const addRegisters = A64.addRegisters;
const addSubtractImmediateSetFlags = A64.addSubtractImmediateSetFlags;

const Allocator = std.mem.Allocator;

pub const Error = Machine.Error || Allocator.Error || Fixups.Error || FloatRuntime.Error || DeepCopyRuntime.Error || CycleRuntime.Error || error{UnsupportedInstruction};

pub const Entry = union(enum) {
    none,
    test_function: Machine.FunctionId,
    executable_main: Machine.FunctionId,
};

pub const Platform = enum { darwin, windows };

pub const Image = struct {
    code: []u8,
    function_offsets: []const u32,
    debug_locations: []const DebugLocation = &.{},
    entry_offset: ?u32,
    data_offset: ?u32 = null,
    external_call_sites: []const ExternalCalls.Site = &.{},
    address_sites: []const AddressSite = &.{},

    pub fn deinit(self: Image, allocator: Allocator) void {
        allocator.free(self.code);
        allocator.free(self.function_offsets);
        allocator.free(self.debug_locations);
        allocator.free(self.external_call_sites);
        allocator.free(self.address_sites);
    }
};

pub const DebugLocation = struct {
    instruction_offset: u32,
    position: @import("../Source.zig").Position,
};

pub const AddressSite = struct {
    instruction_offset: u32,
    target_offset: u32,
};

const CallFixup = Fixups.Call;
const DataFixup = Fixups.Data;
const FixupWidth = Fixups.Width;
const LocalFixup = Fixups.Local;
const ControlFixup = Fixups.Control;

const FunctionFixups = struct {
    overflow: std.ArrayList(LocalFixup) = .empty,
    division_by_zero: std.ArrayList(LocalFixup) = .empty,
    epilogue: std.ArrayList(LocalFixup) = .empty,
};

const DeepCopyFixup = struct { call_at: usize, data_at: usize };
const CycleFixup = struct { call_at: usize, data_at: ?usize = null };
const FunctionAddressFixup = struct { at: usize, function: Machine.FunctionId };

pub fn encode(allocator: Allocator, program: Machine.Program, entry: Entry) Error!Image {
    return encodeForPlatform(allocator, program, entry, .darwin);
}

pub fn encodeWindows(allocator: Allocator, program: Machine.Program, entry: Entry) Error!Image {
    return encodeForPlatform(allocator, program, entry, .windows);
}

fn encodeForPlatform(allocator: Allocator, program: Machine.Program, entry: Entry, platform: Platform) Error!Image {
    _ = FloatRuntime.object_bytes;
    _ = DeepCopyRuntime.object_bytes;
    _ = CycleRuntime.object_bytes;
    try Machine.validate(program);
    var words: std.ArrayList(u32) = .empty;
    const offsets = try allocator.alloc(u32, program.functions.len);
    var calls: std.ArrayList(CallFixup) = .empty;
    var float_calls: std.ArrayList(usize) = .empty;
    var deep_copy_calls: std.ArrayList(DeepCopyFixup) = .empty;
    var cycle_calls: std.ArrayList(CycleFixup) = .empty;
    var data_fixups: std.ArrayList(DataFixup) = .empty;
    var snapshot_data_fixups: std.ArrayList(usize) = .empty;
    var external_call_sites: std.ArrayList(ExternalCalls.Site) = .empty;
    var function_addresses: std.ArrayList(FunctionAddressFixup) = .empty;
    var address_sites: std.ArrayList(AddressSite) = .empty;
    var debug_locations: std.ArrayList(DebugLocation) = .empty;

    for (program.functions, 0..) |function, function_id| {
        offsets[function_id] = @intCast(words.items.len * 4);
        try encodeFunction(allocator, &words, &calls, &function_addresses, &float_calls, &deep_copy_calls, &cycle_calls, &data_fixups, &external_call_sites, &debug_locations, platform, program, function);
    }

    const entry_offset: ?u32 = switch (entry) {
        .none => null,
        .test_function => |function| entry: {
            if (function >= program.functions.len) return error.InvalidMachineProgram;
            const offset: u32 = @intCast(words.items.len * 4);
            try words.append(allocator, saveFrame());
            try words.append(allocator, moveFramePointer());
            try emitSnapshotAcquire(allocator, &words, &snapshot_data_fixups);
            try calls.append(allocator, .{ .at = words.items.len, .function = function });
            try words.append(allocator, branchLink());
            try emitSnapshotRelease(allocator, &words, &snapshot_data_fixups);
            try words.append(allocator, moveRegister(.x1, .x8));
            try words.append(allocator, restoreFrame());
            try words.append(allocator, returnInstruction());
            break :entry offset;
        },
        .executable_main => |function| entry: {
            if (function >= program.functions.len) return error.InvalidMachineProgram;
            const main = program.functions[function];
            if (main.parameter_count != 0 or (main.return_type != .void and !main.recoverable_entry_result)) {
                return error.InvalidMachineProgram;
            }
            const offset: u32 = @intCast(words.items.len * 4);
            try words.append(allocator, saveFrame());
            try words.append(allocator, moveFramePointer());
            if (platform == .windows) if (program.mutex_global) |global| {
                try emitWindowsMutexCall(
                    allocator,
                    &words,
                    &data_fixups,
                    &external_call_sites,
                    global,
                    .initialize_critical_section,
                );
            };
            if (main.recoverable_entry_result) {
                try emitStackAdjustment(allocator, &words, 16, false);
                try words.append(allocator, addSubtractImmediate(.x15, .zero_or_sp, 0, true));
            }
            try emitSnapshotAcquire(allocator, &words, &snapshot_data_fixups);
            try calls.append(allocator, .{ .at = words.items.len, .function = function });
            try words.append(allocator, branchLink());
            try emitSnapshotRelease(allocator, &words, &snapshot_data_fixups);
            const runtime_success = words.items.len;
            try words.append(allocator, compareBranchZero(.x8));
            if (main.recoverable_entry_result) try emitStackAdjustment(allocator, &words, 16, true);
            try words.append(allocator, moveWideZero32(.x0, 1));
            try words.append(allocator, restoreFrame());
            try words.append(allocator, returnInstruction());
            try patch19(words.items, runtime_success, words.items.len);
            if (main.recoverable_entry_result) {
                try words.append(allocator, loadStack(.x9, 0));
                const result_success = words.items.len;
                try words.append(allocator, compareBranchZero(.x9));
                const prefix = findString(program, "error: ") orelse return error.InvalidMachineProgram;
                try StringRuntime.emitWriteStatic(allocator, &words, &data_fixups, program, prefix, 2);
                try StringRuntime.emitPrint(allocator, &words, &data_fixups, program, 1, 2, true);
                try words.append(allocator, moveWideZero32(.x0, 1));
                try emitStackAdjustment(allocator, &words, 16, true);
                try words.append(allocator, restoreFrame());
                try words.append(allocator, returnInstruction());
                try patch19(words.items, result_success, words.items.len);
                try emitStackAdjustment(allocator, &words, 16, true);
            }
            try words.append(allocator, moveWideZero32(.x0, 0));
            try words.append(allocator, restoreFrame());
            try words.append(allocator, returnInstruction());
            break :entry offset;
        },
    };
    var runtime_bytes: std.ArrayList(u8) = .empty;
    if (float_calls.items.len != 0) {
        const runtime = try FloatRuntime.payload();
        try appendRuntimePadding(allocator, words.items.len, &runtime_bytes, runtime.page_offset);
        const runtime_start = words.items.len * 4 + runtime_bytes.items.len;
        const formatter_target = (runtime_start + runtime.entry_offset) / 4;
        for (float_calls.items) |at| try patch26(words.items, at, formatter_target);
        try appendRuntimeAddressSites(allocator, runtime_start, runtime, &address_sites);
        try runtime_bytes.appendSlice(allocator, runtime.bytes);
    }
    if (deep_copy_calls.items.len != 0) {
        const runtime = try DeepCopyRuntime.payload();
        try appendRuntimePadding(allocator, words.items.len, &runtime_bytes, runtime.page_offset);
        const runtime_start = words.items.len * 4 + runtime_bytes.items.len;
        const target = (runtime_start + runtime.entry_offset) / 4;
        for (deep_copy_calls.items) |fixup| try patch26(words.items, fixup.call_at, target);
        try appendRuntimeAddressSites(allocator, runtime_start, runtime, &address_sites);
        try runtime_bytes.appendSlice(allocator, runtime.bytes);
    }
    if (cycle_calls.items.len != 0) {
        const runtime = try CycleRuntime.payload();
        try appendRuntimePadding(allocator, words.items.len, &runtime_bytes, runtime.page_offset);
        const runtime_start = words.items.len * 4 + runtime_bytes.items.len;
        const target = (runtime_start + runtime.entry_offset) / 4;
        for (cycle_calls.items) |fixup| try patch26(words.items, fixup.call_at, target);
        try appendRuntimeAddressSites(allocator, runtime_start, runtime, &address_sites);
        try runtime_bytes.appendSlice(allocator, runtime.bytes);
    }

    for (calls.items) |call| {
        if (call.function >= offsets.len) return error.InvalidMachineProgram;
        try patch26(words.items, call.at, offsets[call.function] / 4);
    }
    for (function_addresses.items) |fixup| {
        if (fixup.function >= offsets.len) {
            std.debug.print("invalid address fixup function={d} offsets={d}\n", .{ fixup.function, offsets.len });
            return error.InvalidMachineProgram;
        }
        try patchPageAddress(words.items, fixup.at, offsets[fixup.function]);
        try address_sites.append(allocator, .{
            .instruction_offset = @intCast(fixup.at * @sizeOf(u32)),
            .target_offset = offsets[fixup.function],
        });
    }

    const machine_code_size = words.items.len * 4;
    const code_size = std.mem.alignForward(usize, machine_code_size + runtime_bytes.items.len, 4);
    const string_offsets = try allocator.alloc(usize, program.strings.len);
    defer allocator.free(string_offsets);
    var image_size = code_size;
    for (program.strings, 0..) |string, index| {
        image_size = std.mem.alignForward(usize, image_size, 8);
        string_offsets[index] = image_size;
        image_size += 8 + string.len + 1;
    }
    const copy_model_offset: ?usize = if (program.copy_model.len == 0) null else std.mem.alignForward(usize, image_size, 8);
    if (copy_model_offset) |offset| image_size = offset + program.copy_model.len * @sizeOf(u64);
    const has_snapshot_lock = switch (entry) {
        .none => false,
        else => true,
    };
    const data_offset: ?u32 = if (program.globals.len == 0 and !has_snapshot_lock) null else @intCast(std.mem.alignForward(usize, image_size, 0x4000));
    if (data_offset) |offset| image_size = offset;
    const snapshot_lock_offset: ?usize = if (has_snapshot_lock) image_size else null;
    if (has_snapshot_lock) image_size += @sizeOf(u64);
    const global_offsets = try allocator.alloc(usize, program.globals.len);
    defer allocator.free(global_offsets);
    for (program.globals, 0..) |global, index| {
        image_size = std.mem.alignForward(usize, image_size, 8);
        global_offsets[index] = image_size;
        image_size += @as(usize, global.width) * Machine.slot_size;
    }
    for (data_fixups.items) |fixup| {
        const target = if (fixup.global) |global|
            if (global < global_offsets.len) global_offsets[global] else return error.InvalidMachineProgram
        else if (fixup.string < string_offsets.len)
            string_offsets[fixup.string]
        else
            return error.InvalidMachineProgram;
        const target_offset = target + fixup.byte_offset;
        try patchPageAddress(words.items, fixup.at, target_offset);
        try address_sites.append(allocator, .{
            .instruction_offset = @intCast(fixup.at * @sizeOf(u32)),
            .target_offset = @intCast(target_offset),
        });
    }
    if (deep_copy_calls.items.len != 0) {
        const target = copy_model_offset orelse return error.InvalidMachineProgram;
        for (deep_copy_calls.items) |fixup| {
            try patchPageAddress(words.items, fixup.data_at, target);
            try address_sites.append(allocator, .{
                .instruction_offset = @intCast(fixup.data_at * @sizeOf(u32)),
                .target_offset = @intCast(target),
            });
        }
    }
    if (cycle_calls.items.len != 0) {
        const target = copy_model_offset orelse return error.InvalidMachineProgram;
        for (cycle_calls.items) |fixup| if (fixup.data_at) |at| {
            try patchPageAddress(words.items, at, target);
            try address_sites.append(allocator, .{
                .instruction_offset = @intCast(at * @sizeOf(u32)),
                .target_offset = @intCast(target),
            });
        };
    }
    if (snapshot_data_fixups.items.len != 0) {
        const target = snapshot_lock_offset orelse return error.InvalidMachineProgram;
        for (snapshot_data_fixups.items) |at| {
            try patchPageAddress(words.items, at, target);
            try address_sites.append(allocator, .{
                .instruction_offset = @intCast(at * @sizeOf(u32)),
                .target_offset = @intCast(target),
            });
        }
    }

    const code = try allocator.alloc(u8, image_size);
    for (words.items, 0..) |word, index| std.mem.writeInt(u32, code[index * 4 ..][0..4], word, .little);
    @memcpy(code[machine_code_size..][0..runtime_bytes.items.len], runtime_bytes.items);
    @memset(code[machine_code_size + runtime_bytes.items.len ..], 0);
    for (program.strings, 0..) |string, index| {
        const descriptor = string_offsets[index];
        std.mem.writeInt(u64, code[descriptor..][0..8], string.len, .little);
        @memcpy(code[descriptor + 8 ..][0..string.len], string);
    }
    if (copy_model_offset) |offset| for (program.copy_model, 0..) |word, index| {
        std.mem.writeInt(u64, code[offset + index * 8 ..][0..8], word, .little);
    };
    if (snapshot_lock_offset) |offset| std.mem.writeInt(u64, code[offset..][0..8], 0, .little);
    for (program.globals, 0..) |global, index| {
        std.mem.writeInt(u64, code[global_offsets[index]..][0..8], global.bits, .little);
        if (global.extra_bits.len + 1 > global.width) return error.InvalidMachineProgram;
        for (global.extra_bits, 1..) |bits, leaf| {
            const offset = global_offsets[index] + leaf * Machine.slot_size;
            std.mem.writeInt(u64, code[offset..][0..8], bits, .little);
        }
    }
    return .{
        .code = code,
        .function_offsets = offsets,
        .debug_locations = try debug_locations.toOwnedSlice(allocator),
        .entry_offset = entry_offset,
        .data_offset = data_offset,
        .external_call_sites = try external_call_sites.toOwnedSlice(allocator),
        .address_sites = try address_sites.toOwnedSlice(allocator),
    };
}

fn appendRuntimePadding(
    allocator: Allocator,
    word_count: usize,
    runtime_bytes: *std.ArrayList(u8),
    page_offset: u12,
) Allocator.Error!void {
    const page_size = 4096;
    const current = (word_count * 4 + runtime_bytes.items.len) % page_size;
    const padding = (@as(usize, page_offset) + page_size - current) % page_size;
    try runtime_bytes.appendNTimes(allocator, 0, padding);
}

fn appendRuntimeAddressSites(
    allocator: Allocator,
    runtime_start: usize,
    runtime: anytype,
    sites: *std.ArrayList(AddressSite),
) Error!void {
    var offset: usize = 0;
    while (offset + 8 <= runtime.text_size) : (offset += 4) {
        const page = std.mem.readInt(u32, runtime.bytes[offset..][0..4], .little);
        if (page & 0x9f000000 != 0x90000000) continue;
        const page_offset = try runtimePageTarget(runtime, offset, page);
        try sites.append(allocator, .{
            .instruction_offset = @intCast(runtime_start + offset),
            .target_offset = @intCast(runtime_start + page_offset),
        });
    }
}

fn runtimePageTarget(runtime: anytype, offset: usize, page: u32) Error!usize {
    const low_instruction = std.mem.readInt(u32, runtime.bytes[offset + 4 ..][0..4], .little);
    const immediate = (low_instruction >> 10) & 0xfff;
    const target_low: usize = if (low_instruction & 0x1f000000 == 0x11000000)
        @as(usize, immediate) << @as(u6, if (low_instruction & (1 << 22) != 0) 12 else 0)
    else if (low_instruction & 0x3b000000 == 0x39000000)
        @as(usize, immediate) * runtimeLoadScale(low_instruction)
    else
        return error.InvalidRuntimeImage;

    const encoded = ((page >> 5) & 0x7ffff) << 2 | ((page >> 29) & 0x3);
    var page_delta: i64 = encoded;
    if (encoded & (1 << 20) != 0) page_delta -= 1 << 21;
    const source_virtual = @as(i64, runtime.page_offset) + @as(i64, @intCast(offset));
    const source_page = source_virtual & ~@as(i64, 0xfff);
    const target_virtual = source_page + page_delta * 0x1000 + @as(i64, @intCast(target_low));
    const relative = target_virtual - @as(i64, runtime.page_offset);
    if (relative < 0 or relative >= runtime.bytes.len) return error.InvalidRuntimeImage;
    return @intCast(relative);
}

fn runtimeLoadScale(instruction: u32) usize {
    if (instruction & 0x04000000 != 0 and instruction & 0x00c00000 == 0x00c00000) return 16;
    return @as(usize, 1) << @intCast((instruction >> 30) & 0x3);
}

fn emitSnapshotAcquire(allocator: Allocator, words: *std.ArrayList(u32), data_fixups: *std.ArrayList(usize)) Error!void {
    try data_fixups.append(allocator, words.items.len);
    try appendRelocatableAddress(allocator, words, .x14);
    const retry = words.items.len;
    try words.append(allocator, A64.loadAcquireExclusive64(.x9, .x14));
    const occupied = words.items.len;
    try words.append(allocator, compareBranchNonZero64(.x9));
    try words.append(allocator, moveWideZero64(.x9, 1, 0));
    try words.append(allocator, A64.storeReleaseExclusive64(.x10, .x9, .x14));
    const conflicted = words.items.len;
    try words.append(allocator, compareBranchNonZero(.x10));
    try patch19(words.items, occupied, retry);
    try patch19(words.items, conflicted, retry);
}

fn emitSnapshotRelease(allocator: Allocator, words: *std.ArrayList(u32), data_fixups: *std.ArrayList(usize)) Error!void {
    try data_fixups.append(allocator, words.items.len);
    try appendRelocatableAddress(allocator, words, .x14);
    try words.append(allocator, A64.storeRelease64(.zero_or_sp, .x14));
}

fn emitClassRetain(allocator: Allocator, words: *std.ArrayList(u32), ownership: Ir.Ownership) Error!void {
    if (ownership == .edge) try emitMarkCycleDirty(allocator, words);
    const offset: u12 = switch (ownership) {
        .root => Machine.slot_size,
        .edge => 2 * Machine.slot_size,
    };
    try words.append(allocator, addSubtractImmediate(.x14, .x10, offset, true));
    const retry = words.items.len;
    try words.append(allocator, A64.loadAcquireExclusive64(.x9, .x14));
    try words.append(allocator, addSubtractImmediate(.x9, .x9, 1, true));
    try words.append(allocator, A64.storeReleaseExclusive64(.x11, .x9, .x14));
    const conflicted = words.items.len;
    try words.append(allocator, compareBranchNonZero(.x11));
    try Fixups.patch19(words.items, conflicted, retry);
}

/// Decrements a class root atomically and claims destruction exactly once.
const ClassDropBranches = struct {
    cycle_candidate: usize,
    rooted: usize,
    already_dropped: usize,
};

/// Returns the branches that skip finalization when another root remains or a
/// concurrent drop has already claimed the instance.
fn emitClassDrop(allocator: Allocator, words: *std.ArrayList(u32), ownership: Ir.Ownership) Error!ClassDropBranches {
    if (ownership == .edge) try emitMarkCycleDirty(allocator, words);
    const offset: u12 = switch (ownership) {
        .root => Machine.slot_size,
        .edge => 2 * Machine.slot_size,
    };
    const other_offset: u12 = switch (ownership) {
        .root => 2 * Machine.slot_size,
        .edge => Machine.slot_size,
    };
    try words.append(allocator, addSubtractImmediate(.x14, .x10, offset, true));
    const release_retry = words.items.len;
    try words.append(allocator, A64.loadAcquireExclusive64(.x9, .x14));
    const unrooted = words.items.len;
    try words.append(allocator, compareBranchZero64(.x9));
    try words.append(allocator, addSubtractImmediate(.x9, .x9, 1, false));
    try words.append(allocator, A64.storeReleaseExclusive64(.x11, .x9, .x14));
    const release_conflicted = words.items.len;
    try words.append(allocator, compareBranchNonZero(.x11));
    try Fixups.patch19(words.items, release_conflicted, release_retry);
    const count_ready = words.items.len;
    try Fixups.patch19(words.items, unrooted, count_ready);
    try words.append(allocator, load64(.x11, .x10, other_offset));
    // Cycle tracing is useful only when no root remains. A live root proves
    // reachability immediately and must not trigger an O(graph) probe.
    const rooted = words.items.len;
    try words.append(allocator, switch (ownership) {
        .root => compareBranchNonZero64(.x9),
        .edge => compareBranchNonZero64(.x11),
    });
    const cycle_candidate = words.items.len;
    try words.append(allocator, switch (ownership) {
        .root => compareBranchNonZero64(.x11),
        .edge => compareBranchNonZero64(.x9),
    });

    try words.append(allocator, addSubtractImmediate(.x14, .x10, 3 * Machine.slot_size, true));
    const claim_retry = words.items.len;
    try words.append(allocator, A64.loadAcquireExclusive64(.x9, .x14));
    // State 2 means that the cycle collector is inspecting the object. Wait
    // for it to either release the claim (0) or commit finalization (1)
    // before deciding who owns destruction.
    try words.append(allocator, moveWideZero64(.x11, 2, 0));
    try words.append(allocator, compareRegisters(.x9, .x11));
    const tracing = words.items.len;
    try words.append(allocator, conditionalBranch(.equal));
    // State 1 is already finalized. State 3 is a committed cycle member and
    // is deliberately allowed to transition to 1 when its cascading edge
    // count reaches zero.
    try words.append(allocator, moveWideZero64(.x11, 1, 0));
    try words.append(allocator, compareRegisters(.x9, .x11));
    const already_dropped = words.items.len;
    try words.append(allocator, conditionalBranch(.equal));
    try words.append(allocator, moveWideZero64(.x9, 1, 0));
    try words.append(allocator, A64.storeReleaseExclusive64(.x11, .x9, .x14));
    const claim_conflicted = words.items.len;
    try words.append(allocator, compareBranchNonZero(.x11));
    try Fixups.patch19(words.items, tracing, claim_retry);
    try Fixups.patch19(words.items, claim_conflicted, claim_retry);

    return .{
        .cycle_candidate = cycle_candidate,
        .rooted = rooted,
        .already_dropped = already_dropped,
    };
}

/// State 4 caches a negative cycle proof for an externally reached object.
/// Changing an incoming edge invalidates that proof before the reference count
/// transition which may make the component collectible.
fn emitMarkCycleDirty(allocator: Allocator, words: *std.ArrayList(u32)) Error!void {
    try words.append(allocator, addSubtractImmediate(.x14, .x10, 3 * Machine.slot_size, true));
    const retry = words.items.len;
    try words.append(allocator, A64.loadAcquireExclusive64(.x9, .x14));
    try words.append(allocator, moveWideZero64(.x11, 4, 0));
    try words.append(allocator, compareRegisters(.x9, .x11));
    const clean = words.items.len;
    try words.append(allocator, conditionalBranch(.not_equal));
    try words.append(allocator, moveWideZero64(.x9, 0, 0));
    try words.append(allocator, A64.storeReleaseExclusive64(.x11, .x9, .x14));
    const conflicted = words.items.len;
    try words.append(allocator, compareBranchNonZero(.x11));
    try Fixups.patch19(words.items, conflicted, retry);
    try Fixups.patch19(words.items, clean, words.items.len);
}

fn findString(program: Machine.Program, value: []const u8) ?usize {
    for (program.strings, 0..) |candidate, index| {
        if (std.mem.eql(u8, candidate, value)) return index;
    }
    return null;
}

fn encodeFunction(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    calls: *std.ArrayList(CallFixup),
    function_addresses: *std.ArrayList(FunctionAddressFixup),
    float_calls: *std.ArrayList(usize),
    deep_copy_calls: *std.ArrayList(DeepCopyFixup),
    cycle_calls: *std.ArrayList(CycleFixup),
    data_fixups: *std.ArrayList(DataFixup),
    external_call_sites: *std.ArrayList(ExternalCalls.Site),
    debug_locations: *std.ArrayList(DebugLocation),
    platform: Platform,
    program: Machine.Program,
    function: Machine.Function,
) Error!void {
    var fixups: FunctionFixups = .{};
    var control_fixups: std.ArrayList(ControlFixup) = .empty;
    var scalar_cache = ScalarCache{ .enabled = function.register_slots.len == 0 and function.float_register_slots.len == 0 };
    const instruction_offsets = try allocator.alloc(usize, function.instructions.len);
    defer allocator.free(instruction_offsets);
    var collection_cursor = try LoopCursor.find(allocator, function);
    if (collection_cursor) |cursor| {
        const load = function.instructions[cursor.load_index].collection_load;
        if (eagerCollectionWidth(function, cursor.load_index, load) != 2) collection_cursor = null;
    }
    const runtime_frame_size: u32 = if (enable_cycle_collector) 16 else 0;
    const extended_frame = function.slot_count >= Machine.direct_stack_slots;
    const saved_register_count = calleeSavedRegisterCount(function, extended_frame);
    const saved_register_size: u32 = @intCast(std.mem.alignForward(usize, saved_register_count * Machine.slot_size, 16));
    const local_frame_size = std.math.add(u32, function.frame_size, runtime_frame_size) catch return error.InvalidMachineProgram;
    const encoded_frame_size = std.math.add(u32, local_frame_size, saved_register_size) catch return error.InvalidMachineProgram;
    const cycle_context_slot: Machine.Slot = @intCast(function.frame_size / Machine.slot_size);
    try words.append(allocator, saveFrame());
    try words.append(allocator, moveFramePointer());
    try emitStackAdjustment(allocator, words, encoded_frame_size, false);
    var saved_register_index: usize = 0;
    for (callee_saved_registers) |register| if (shouldSaveRegister(function, register, extended_frame)) {
        try emitStoreAtOffset(
            allocator,
            words,
            register,
            .zero_or_sp,
            @as(usize, local_frame_size) + saved_register_index * Machine.slot_size,
        );
        saved_register_index += 1;
    };
    for (callee_saved_float_registers) |register| if (functionUsesFloatRegister(function, register)) {
        try words.append(allocator, moveFloatToGeneral(.x9, register, true));
        try emitStoreAtOffset(
            allocator,
            words,
            .x9,
            .zero_or_sp,
            @as(usize, local_frame_size) + saved_register_index * Machine.slot_size,
        );
        saved_register_index += 1;
    };
    if (extended_frame) try emitBaseAddress(
        allocator,
        words,
        .x28,
        .zero_or_sp,
        Machine.direct_stack_slots * Machine.slot_size,
    );
    if (function.hidden_return_slot) |slot| try words.append(allocator, storeStack(.x15, slot));
    for (function.parameters, 0..) |parameter, index| {
        const incoming: Register = if (index < Machine.max_register_arguments) @enumFromInt(index) else .x10;
        if (index >= Machine.max_register_arguments) {
            const incoming_offset = 2 * Machine.slot_size +
                (index - Machine.max_register_arguments) * Machine.slot_size;
            try emitLoadAtOffset(allocator, words, incoming, .x29, incoming_offset);
        }
        if (!parameter.aggregate) {
            if (floatResidence(function, parameter.start) != null or
                floatLaneResidence(function, parameter.start) != null)
            {
                try words.append(allocator, moveGeneralToFloat(.x9, incoming, true));
                try storeFloatValue(allocator, words, function, .x9, parameter.start, true);
            } else try storeValue(allocator, words, function, incoming, parameter.start);
        } else {
            var leaf: usize = 0;
            while (leaf < parameter.width) {
                const slot: Machine.Slot = @intCast(@as(usize, parameter.start) + leaf);
                if (pairAggregateParameterLeaves(function, parameter, leaf)) {
                    const stack_slot = if (slot >= Machine.direct_stack_slots)
                        slot - Machine.direct_stack_slots
                    else
                        slot;
                    const stack_base: Register = if (slot >= Machine.direct_stack_slots) .x28 else .zero_or_sp;
                    try words.append(allocator, A64.load64Pair(.x9, .x10, incoming, @intCast(leaf * Machine.slot_size)));
                    try words.append(allocator, A64.store64Pair(.x9, .x10, stack_base, @intCast(@as(usize, stack_slot) * Machine.slot_size)));
                    leaf += 2;
                    continue;
                }
                try emitLoadAtOffset(allocator, words, .x9, incoming, leaf * Machine.slot_size);
                if (floatResidence(function, slot) != null or floatLaneResidence(function, slot) != null) {
                    try words.append(allocator, moveGeneralToFloat(.x10, .x9, true));
                    try storeFloatValue(allocator, words, function, .x10, slot, true);
                } else try storeValue(allocator, words, function, .x9, slot);
                leaf += 1;
            }
        }
    }
    for (function.capture_parameters, 0..) |capture, index| {
        if (capture.aggregate or capture.width != 1) return error.InvalidMachineProgram;
        try emitLoadAtOffset(allocator, words, .x9, .x14, index * Machine.slot_size);
        try words.append(allocator, storeStack(.x9, capture.start));
    }
    for (cachedFloatLiterals(function)) |candidate| if (candidate) |literal| {
        try emitImmediate64(allocator, words, .x9, literal.bits);
        try words.append(allocator, moveGeneralToFloat(literal.register, .x9, literal.double));
    };

    for (function.instructions, 0..) |instruction, instruction_index| {
        instruction_offsets[instruction_index] = words.items.len;
        try emitDeferredCollectionLoads(allocator, words, function, instruction_index, collection_cursor);
        if (!scalarCacheInstruction(instruction)) scalar_cache.clear();
        if (collection_cursor) |cursor| if (cursor.termination) |termination| {
            if (termination.elides(instruction_index)) continue;
        };
        switch (instruction) {
            .constant_int => |constant| {
                if (constant.bits == 0 and zeroConstantFeedsNextComparison(function, instruction_index, constant.result)) continue;
                if (integerConstantFeedsNextArithmetic(function, instruction_index, constant)) continue;
                const bits = if (constant.type.isSignedInteger())
                    Numeric.signExtend(constant.bits, constant.type.bitWidth())
                else
                    constant.bits;
                const destination = valueResultRegister(function, constant.result) orelse .x9;
                try emitImmediate64(allocator, words, destination, bits);
                if (valueResultRegister(function, constant.result) == null) {
                    try storeCachedValue(allocator, words, function, &scalar_cache, destination, constant.result);
                }
            },
            .constant_bool => |constant| {
                const destination = valueResultRegister(function, constant.result) orelse .x9;
                try words.append(allocator, moveWideZero32(destination, @intFromBool(constant.value)));
                if (valueResultRegister(function, constant.result) == null) {
                    try storeCachedValue(allocator, words, function, &scalar_cache, destination, constant.result);
                }
            },
            .constant_str => |constant| {
                try StringRuntime.emitLiteral(allocator, words, data_fixups, constant.string, constant.result);
            },
            .constant_bytes => |constant| try ListRuntime.emitBytesLiteral(
                allocator,
                words,
                data_fixups,
                &fixups.epilogue,
                external_call_sites,
                @enumFromInt(@intFromEnum(platform)),
                program,
                constant,
            ),
            .constant_float32 => |constant| {
                if (floatPairLeader(function, constant.result) != null) continue;
                if (floatLaneResidence(function, constant.result)) |pair| {
                    if (pair.lane != 1) return error.InvalidMachineProgram;
                    const destination: Register = @enumFromInt(pair.register);
                    if (constant.bits == 0) {
                        try words.append(allocator, floatZero(destination));
                    } else {
                        try emitImmediate64(allocator, words, .x9, constant.bits);
                        try words.append(allocator, moveGeneralToFloat(destination, .x9, false));
                        try words.append(allocator, A64.duplicateFloat32Lane(destination, destination, 0));
                    }
                    continue;
                }
                if (floatMaxDiamond(function, instruction_index, constant.result, constant.bits, false)) |diamond| {
                    const left = try prepareFloatOperand(allocator, words, function, .x9, diamond.left, false);
                    const destination = floatResultRegister(function, diamond.destination) orelse .x10;
                    try words.append(allocator, floatMaxNumber(destination, left, diamond.right, false));
                    if (floatResultRegister(function, diamond.destination) == null) {
                        try storeFloatValue(allocator, words, function, destination, diamond.destination, false);
                    }
                    try control_fixups.append(allocator, .{
                        .at = words.items.len,
                        .target = diamond.join,
                        .width = .imm26,
                    });
                    try words.append(allocator, branch());
                    continue;
                }
                if (constant.bits == 0 and zeroConstantFeedsNextComparison(function, instruction_index, constant.result)) continue;
                if (constantFeedsNextComparison(function, instruction_index, constant.result) and
                    cachedFloatLiteralRegister(function, constant.bits, false) != null) continue;
                if (constant.bits == 0) {
                    const destination = floatResultRegister(function, constant.result) orelse .x9;
                    try words.append(allocator, floatZero(destination));
                    if (floatResultRegister(function, constant.result) == null) {
                        try storeFloatValue(allocator, words, function, destination, constant.result, false);
                    }
                    continue;
                }
                const destination = floatResultRegister(function, constant.result) orelse .x9;
                if (floatImmediateEncoding(constant.bits, false)) |immediate| {
                    try words.append(allocator, A64.floatImmediate(destination, immediate, false));
                    if (floatResultRegister(function, constant.result) == null) {
                        try storeFloatValue(allocator, words, function, destination, constant.result, false);
                    }
                    continue;
                }
                try emitImmediate64(allocator, words, .x9, constant.bits);
                try words.append(allocator, moveGeneralToFloat(destination, .x9, false));
                if (floatResultRegister(function, constant.result) == null) {
                    try storeFloatValue(allocator, words, function, destination, constant.result, false);
                }
            },
            .constant_float64 => |constant| {
                if (floatMaxDiamond(function, instruction_index, constant.result, constant.bits, true)) |diamond| {
                    const left = try prepareFloatOperand(allocator, words, function, .x9, diamond.left, true);
                    const destination = floatResultRegister(function, diamond.destination) orelse .x10;
                    try words.append(allocator, floatMaxNumber(destination, left, diamond.right, true));
                    if (floatResultRegister(function, diamond.destination) == null) {
                        try storeFloatValue(allocator, words, function, destination, diamond.destination, true);
                    }
                    try control_fixups.append(allocator, .{
                        .at = words.items.len,
                        .target = diamond.join,
                        .width = .imm26,
                    });
                    try words.append(allocator, branch());
                    continue;
                }
                if (constant.bits == 0 and zeroConstantFeedsNextComparison(function, instruction_index, constant.result)) continue;
                if (constantFeedsNextComparison(function, instruction_index, constant.result) and
                    cachedFloatLiteralRegister(function, constant.bits, true) != null) continue;
                if (constant.bits == 0) {
                    const destination = floatResultRegister(function, constant.result) orelse .x9;
                    try words.append(allocator, floatZero(destination));
                    if (floatResultRegister(function, constant.result) == null) {
                        try storeFloatValue(allocator, words, function, destination, constant.result, true);
                    }
                    continue;
                }
                const destination = floatResultRegister(function, constant.result) orelse .x9;
                if (floatImmediateEncoding(constant.bits, true)) |immediate| {
                    try words.append(allocator, A64.floatImmediate(destination, immediate, true));
                    if (floatResultRegister(function, constant.result) == null) {
                        try storeFloatValue(allocator, words, function, destination, constant.result, true);
                    }
                    continue;
                }
                try emitImmediate64(allocator, words, .x9, constant.bits);
                try words.append(allocator, moveGeneralToFloat(destination, .x9, true));
                if (floatResultRegister(function, constant.result) == null) {
                    try storeFloatValue(allocator, words, function, destination, constant.result, true);
                }
            },
            .optional_null => |optional| {
                try words.append(allocator, moveWideZero32(.x9, 0));
                for (0..optional.result.width) |index| {
                    try words.append(allocator, storeStack(.x9, @intCast(@as(usize, optional.result.start) + index)));
                }
            },
            .optional_some => |optional| {
                try words.append(allocator, moveWideZero32(.x9, 1));
                try words.append(allocator, storeStack(.x9, optional.result.start));
                var payload = optional.result;
                payload.start += 1;
                payload.width -= 1;
                try emitSpanCopy(allocator, words, payload, optional.operand);
            },
            .optional_unwrap => |optional| try emitSpanCopy(allocator, words, optional.result, optional.operand),
            .copy => |copy| {
                if (floatLaneResidence(function, copy.result)) |pair| {
                    // Scalar sources may reuse their register before the
                    // partner copy. Capture them at the original use, not
                    // when a later instruction finishes the packed transfer.
                    if (floatLaneResidence(function, copy.operand) == null) {
                        try emitRegisteredCopy(allocator, words, function, copy.result, copy.operand);
                        continue;
                    }
                    if (definingTransferOperandAfter(function.instructions, instruction_index, pair.partner) != null) continue;
                    const partner_operand = definingTransferOperandBefore(
                        function.instructions,
                        instruction_index,
                        pair.partner,
                    ) orelse return error.InvalidMachineProgram;
                    const source = try prepareFloatPairOperand(
                        allocator,
                        words,
                        function,
                        if (pair.lane == 0) copy.operand else partner_operand,
                        if (pair.lane == 0) partner_operand else copy.operand,
                        .x9,
                        .x10,
                    );
                    const destination: Register = @enumFromInt(pair.register);
                    if (source != destination) try words.append(allocator, moveFloat(destination, source, true));
                    continue;
                }
                if (copyBelongsToFusedComparison(function, instruction_index)) continue;
                if (floatResidence(function, copy.operand) != null or floatResidence(function, copy.result) != null or
                    floatLaneResidence(function, copy.operand) != null or floatLaneResidence(function, copy.result) != null)
                {
                    try emitScalarFloatCopy(allocator, words, function, copy.result, copy.operand);
                } else {
                    const source = valueResultRegister(function, copy.operand);
                    const destination = valueResultRegister(function, copy.result);
                    if (source != null and destination != null) {
                        if (source.? != destination.?) try words.append(allocator, moveRegister(destination.?, source.?));
                    } else {
                        try loadCachedValue(allocator, words, function, &scalar_cache, .x9, copy.operand);
                        try storeCachedValue(allocator, words, function, &scalar_cache, .x9, copy.result);
                    }
                }
            },
            .copy_range => |copy| for (0..copy.result.width) |leaf| {
                const result: Machine.Slot = @intCast(@as(usize, copy.result.start) + leaf);
                const operand: Machine.Slot = @intCast(@as(usize, copy.operand.start) + leaf);
                // The allocator may assign a dead leaf the register of a
                // live sibling defined by this same aggregate transfer.
                if ((valueResultRegister(function, result) != null or floatResidence(function, result) != null or floatLaneResidence(function, result) != null) and
                    !slotHasUse(function.instructions, result)) continue;
                if (floatLaneResidence(function, operand)) |source| if (floatLaneResidence(function, result)) |destination| {
                    if (source.register == destination.register and source.lane == destination.lane) continue;
                };
                if (floatLaneResidence(function, result)) |pair| {
                    if (floatLaneResidence(function, operand) == null) {
                        try emitRegisteredCopy(allocator, words, function, result, operand);
                        continue;
                    }
                    if (pair.lane == 0) {
                        if (definingTransferOperandAfter(
                            function.instructions,
                            instruction_index,
                            pair.partner,
                        ) != null) continue;
                    } else if (definingTransferOperandBefore(
                        function.instructions,
                        instruction_index,
                        pair.partner,
                    )) |first_operand| {
                        const source = try prepareFloatPairOperand(
                            allocator,
                            words,
                            function,
                            first_operand,
                            operand,
                            .x9,
                            .x10,
                        );
                        const destination: Register = @enumFromInt(pair.register);
                        if (source != destination) try words.append(allocator, moveFloat(destination, source, true));
                        continue;
                    }
                }
                try emitRegisteredCopy(allocator, words, function, result, operand);
            },
            .deep_copy => |copy| {
                try emitStackAddress(allocator, words, .x0, copy.operand.start);
                try emitStackAddress(allocator, words, .x1, copy.result.start);
                const data_at = words.items.len;
                try appendRelocatableAddress(allocator, words, .x2);
                try emitImmediate64(allocator, words, .x3, @intFromEnum(copy.type));
                const call_at = words.items.len;
                try words.append(allocator, branchLink());
                try deep_copy_calls.append(allocator, .{ .call_at = call_at, .data_at = data_at });
                try words.append(allocator, moveRegister(.x8, .x0));
                try appendFixup(allocator, words, &fixups.epilogue, compareBranchNonZero(.x8), .imm19);
            },
            .global_load => |global| {
                try data_fixups.append(allocator, .{ .at = words.items.len, .global = global.global });
                try appendRelocatableAddress(allocator, words, .x10);
                for (0..global.result.width) |leaf| {
                    try words.append(allocator, load64(.x9, .x10, @intCast(leaf * Machine.slot_size)));
                    try words.append(allocator, storeStack(.x9, @intCast(@as(usize, global.result.start) + leaf)));
                }
            },
            .global_store => |global| {
                try data_fixups.append(allocator, .{ .at = words.items.len, .global = global.global });
                try appendRelocatableAddress(allocator, words, .x10);
                for (0..global.operand.width) |leaf| {
                    try words.append(allocator, loadStack(.x9, @intCast(@as(usize, global.operand.start) + leaf)));
                    try words.append(allocator, store64(.x9, .x10, @intCast(leaf * Machine.slot_size)));
                }
            },
            .local_address => |address| {
                try emitStackAddress(allocator, words, .x9, address.local);
                try words.append(allocator, storeStack(.x9, address.result));
            },
            .reference_load => |load| {
                if (fusedReferenceOffset(function, instruction_index, load.reference)) |offset| {
                    try emitOffsetReferenceCopy(
                        allocator,
                        words,
                        function,
                        load.result,
                        offset.reference,
                        offset.byte_offset,
                        true,
                    );
                } else try emitReferenceCopy(allocator, words, function, load.result, load.reference, true);
            },
            .address_load => |load| {
                try words.append(allocator, loadStack(.x9, load.address));
                try words.append(allocator, loadStack(.x10, load.byte_offset));
                try words.append(allocator, addRegisters(.x9, .x9, .x10));
                try words.append(allocator, switch (load.type) {
                    .int8, .uint8 => A64.loadByte(.x9, .x9),
                    .int16, .uint16 => A64.load16(.x9, .x9),
                    .int32, .uint32, .float32 => A64.load32(.x9, .x9),
                    .int, .uint, .address, .float64 => A64.load64(.x9, .x9, 0),
                    else => return error.InvalidMachineProgram,
                });
                if (load.type == .int8 or load.type == .int16 or load.type == .int32) {
                    try words.append(allocator, signExtendRegister(.x9, .x9, load.type.bitWidth()));
                }
                try words.append(allocator, storeStack(.x9, load.result));
            },
            .address_store => |store| {
                try words.append(allocator, loadStack(.x9, store.address));
                try words.append(allocator, loadStack(.x10, store.byte_offset));
                try words.append(allocator, addRegisters(.x9, .x9, .x10));
                try words.append(allocator, loadStack(.x11, store.operand));
                try words.append(allocator, switch (store.type) {
                    .int8, .uint8 => A64.storeByte(.x11, .x9),
                    .int16, .uint16 => A64.store16(.x11, .x9),
                    .int32, .uint32, .float32 => A64.store32(.x11, .x9),
                    .int, .uint, .float64 => A64.store64(.x11, .x9, 0),
                    else => return error.InvalidMachineProgram,
                });
            },
            .reference_store => |store| {
                if (fusedReferenceOffset(function, instruction_index, store.reference)) |offset| {
                    try emitOffsetReferenceCopy(
                        allocator,
                        words,
                        function,
                        store.operand,
                        offset.reference,
                        offset.byte_offset,
                        false,
                    );
                } else try emitReferenceCopy(allocator, words, function, store.operand, store.reference, false);
            },
            .reference_offset => |offset| {
                if (referenceOffsetFeedsNextCopy(function, instruction_index, offset)) continue;
                try loadValue(allocator, words, function, .x9, offset.reference);
                if (offset.byte_offset <= std.math.maxInt(u12)) {
                    try words.append(allocator, addSubtractImmediate(.x9, .x9, @intCast(offset.byte_offset), true));
                } else {
                    try emitImmediate64(allocator, words, .x10, offset.byte_offset);
                    try words.append(allocator, addRegisters(.x9, .x9, .x10));
                }
                try storeValue(allocator, words, function, .x9, offset.result);
            },
            .reference_indirect_offset => |offset| {
                try loadValue(allocator, words, function, .x9, offset.reference);
                try words.append(allocator, load64(.x9, .x9, 0));
                if (offset.byte_offset <= std.math.maxInt(u12)) {
                    try words.append(allocator, addSubtractImmediate(.x9, .x9, @intCast(offset.byte_offset), true));
                } else {
                    try emitImmediate64(allocator, words, .x10, offset.byte_offset);
                    try words.append(allocator, addRegisters(.x9, .x9, .x10));
                }
                try storeValue(allocator, words, function, .x9, offset.result);
            },
            .storage_init => |storage| for (0..storage.width) |leaf| {
                try words.append(allocator, storeStack(
                    .zero_or_sp,
                    @intCast(@as(usize, storage.start) + leaf),
                ));
            },
            .aggregate_init => |initialization| {
                var destination_offset: usize = 0;
                for (initialization.fields) |field| {
                    for (0..field.width) |leaf| {
                        const destination: Machine.Slot = @intCast(@as(usize, initialization.result.start) + destination_offset + leaf);
                        // Dead aggregate leaves may share the register of a
                        // live sibling defined by this same instruction.
                        // Materializing them would overwrite that sibling.
                        if (((function.register_slots.len != 0 and function.register_slots[destination] != null) or floatResidence(function, destination) != null) and
                            !slotHasUse(function.instructions, destination)) continue;
                        try emitRegisteredCopy(
                            allocator,
                            words,
                            function,
                            destination,
                            @intCast(@as(usize, field.start) + leaf),
                        );
                    }
                    destination_offset += field.width;
                }
            },
            .protocol_init => |value| try ProtocolRuntime.emitInit(allocator, words, value),
            .protocol_test => |value| try ProtocolRuntime.emitTest(allocator, words, value),
            .protocol_extract => |value| try ProtocolRuntime.emitExtract(allocator, words, value),
            .class_init => |initialization| try ClassRuntime.emitInit(
                allocator,
                words,
                &fixups.epilogue,
                external_call_sites,
                switch (platform) {
                    .darwin => .darwin,
                    .windows => .windows,
                },
                initialization,
            ),
            .class_load => |load| try ClassRuntime.emitLoad(allocator, words, load),
            .class_store => |store| try ClassRuntime.emitStore(allocator, words, store),
            .class_retain => |retain| {
                try words.append(allocator, loadStack(.x10, retain.operand));
                try emitClassRetain(allocator, words, retain.ownership);
            },
            .class_drop => |drop| {
                if (enable_cycle_collector) {
                    try words.append(allocator, storeStack(.zero_or_sp, cycle_context_slot));
                }
                try words.append(allocator, loadStack(.x10, drop.operand));
                const skip_finalization = try emitClassDrop(allocator, words, drop.ownership);
                const finalize_without_cycle = words.items.len;
                try words.append(allocator, branch());

                const cycle_prepare = words.items.len;
                var cycle_unavailable: ?usize = null;
                var cycle_claimed: ?usize = null;
                if (platform == .darwin and enable_cycle_collector) {
                    try words.append(allocator, loadStack(.x10, drop.operand));
                    try words.append(allocator, load64(.x9, .x10, 3 * Machine.slot_size));
                    cycle_claimed = words.items.len;
                    try words.append(allocator, compareBranchNonZero(.x9));
                    try words.append(allocator, moveWideZero32(.x0, 0));
                    try words.append(allocator, loadStack(.x1, drop.operand));
                    const data_at = words.items.len;
                    try appendRelocatableAddress(allocator, words, .x2);
                    try emitImmediate64(allocator, words, .x3, 0x100 + drop.static_type);
                    const call_at = words.items.len;
                    try words.append(allocator, branchLink());
                    try cycle_calls.append(allocator, .{ .call_at = call_at, .data_at = data_at });
                    cycle_unavailable = words.items.len;
                    try words.append(allocator, compareBranchZero64(.x0));
                    try words.append(allocator, storeStack(.x0, cycle_context_slot));
                }
                const finalize_cycle = words.items.len;
                try words.append(allocator, branch());

                const finalize = words.items.len;
                try Fixups.patch26(words.items, finalize_without_cycle, finalize);
                try Fixups.patch26(words.items, finalize_cycle, finalize);
                try words.append(allocator, loadStack(.x10, drop.operand));
                try words.append(allocator, load64(.x9, .x10, 0));
                var finalized: std.ArrayList(usize) = .empty;
                for (drop.plans) |plan| {
                    try emitImmediate64(allocator, words, .x11, plan.structure);
                    try words.append(allocator, compareRegisters(.x9, .x11));
                    const skip = words.items.len;
                    try words.append(allocator, conditionalBranch(.not_equal));
                    for (plan.functions) |finalizer| {
                        try words.append(allocator, loadStack(.x0, drop.operand));
                        try calls.append(allocator, .{ .at = words.items.len, .function = finalizer });
                        try words.append(allocator, branchLink());
                        try appendFixup(allocator, words, &fixups.epilogue, compareBranchNonZero(.x8), .imm19);
                    }
                    try words.append(allocator, loadStack(.x0, drop.operand));
                    try emitImmediate64(allocator, words, .x1, plan.byte_count);
                    try Allocation.emitFree(allocator, words, external_call_sites, @enumFromInt(@intFromEnum(platform)));
                    try finalized.append(allocator, words.items.len);
                    try words.append(allocator, branch());
                    try Fixups.patch19(words.items, skip, words.items.len);
                }
                const finalization_complete = words.items.len;
                for (finalized.items) |at| try Fixups.patch26(words.items, at, finalization_complete);
                if (platform == .darwin and enable_cycle_collector) {
                    try words.append(allocator, loadStack(.x1, cycle_context_slot));
                    const no_context = words.items.len;
                    try words.append(allocator, compareBranchZero64(.x1));
                    try words.append(allocator, moveWideZero64(.x0, 1, 0));
                    try words.append(allocator, moveWideZero32(.x2, 0));
                    try words.append(allocator, moveWideZero32(.x3, 0));
                    const finish_call = words.items.len;
                    try words.append(allocator, branchLink());
                    try cycle_calls.append(allocator, .{ .call_at = finish_call });
                    try Fixups.patch19(words.items, no_context, words.items.len);
                }
                const done = words.items.len;
                try Fixups.patch19(
                    words.items,
                    skip_finalization.cycle_candidate,
                    if (drop.skip_cycle) done else cycle_prepare,
                );
                try Fixups.patch19(words.items, skip_finalization.rooted, done);
                try Fixups.patch19(words.items, skip_finalization.already_dropped, done);
                if (cycle_unavailable) |at| try Fixups.patch19(words.items, at, done);
                if (cycle_claimed) |at| try Fixups.patch19(words.items, at, done);
            },
            .list_retain => |retain| try ListRuntime.emitRetain(allocator, words, retain),
            .list_drop => |drop| try ListRuntime.emitDrop(
                allocator,
                words,
                external_call_sites,
                switch (platform) {
                    .darwin => .darwin,
                    .windows => .windows,
                },
                drop,
            ),
            .string_retain => |retain| try StringRuntime.emitRetain(allocator, words, retain),
            .string_drop => |drop| try StringRuntime.emitDrop(
                allocator,
                words,
                external_call_sites,
                @enumFromInt(@intFromEnum(platform)),
                drop,
            ),
            .list_init => |initialization| try ListRuntime.emitInit(allocator, words, &fixups.epilogue, external_call_sites, @enumFromInt(@intFromEnum(platform)), initialization),
            .enum_init => |initialization| {
                try emitImmediate64(allocator, words, .x9, initialization.tag);
                for (0..initialization.result.width) |index| {
                    if (index != 0) try words.append(allocator, moveWideZero32(.x9, 0));
                    try words.append(allocator, storeStack(.x9, @intCast(@as(usize, initialization.result.start) + index)));
                }
                if (initialization.raw_value) |raw_value| switch (raw_value) {
                    .integer => |value| {
                        try emitImmediate64(allocator, words, .x9, value);
                        try words.append(allocator, storeStack(.x9, initialization.result.start + 1));
                    },
                    .string => |string| try StringRuntime.emitLiteral(
                        allocator,
                        words,
                        data_fixups,
                        string,
                        initialization.result.start + 1,
                    ),
                };
                var destination_offset: usize = 1;
                for (initialization.values) |value| {
                    var destination = initialization.result;
                    destination.start = @intCast(@as(usize, destination.start) + destination_offset);
                    destination.width = value.width;
                    destination.aggregate = value.aggregate;
                    try emitSpanCopy(allocator, words, destination, value);
                    destination_offset += value.width;
                }
            },
            .enum_test => |test_value| {
                try words.append(allocator, loadStack(.x9, test_value.operand.start));
                try emitImmediate64(allocator, words, .x10, test_value.tag);
                try words.append(allocator, compareRegisters(.x9, .x10));
                try words.append(allocator, moveWideZero32(.x11, 0));
                const skip_true = words.items.len;
                try words.append(allocator, conditionalBranch(.not_equal));
                try words.append(allocator, moveWideZero32(.x11, 1));
                try patch19(words.items, skip_true, words.items.len);
                try words.append(allocator, storeStack(.x11, test_value.result));
            },
            .collection_load => |access| if (collection_cursor) |cursor|
                if (cursor.load_index == instruction_index)
                    try ListRuntime.emitCursorLoad(
                        allocator,
                        words,
                        function,
                        access,
                        eagerCollectionWidth(function, instruction_index, access),
                        @enumFromInt(cursor.register),
                    )
                else if (access.dynamic)
                    try ListRuntime.emitLoad(
                        allocator,
                        words,
                        data_fixups,
                        &fixups.epilogue,
                        program,
                        function,
                        access,
                        eagerCollectionWidth(function, instruction_index, access),
                    )
                else
                    try encodeCollectionLoad(allocator, words, data_fixups, &fixups, program, access)
            else if (access.dynamic)
                try ListRuntime.emitLoad(
                    allocator,
                    words,
                    data_fixups,
                    &fixups.epilogue,
                    program,
                    function,
                    access,
                    eagerCollectionWidth(function, instruction_index, access),
                )
            else
                try encodeCollectionLoad(allocator, words, data_fixups, &fixups, program, access),
            .collection_reference => |access| if (access.dynamic)
                try ListRuntime.emitReference(
                    allocator,
                    words,
                    data_fixups,
                    &fixups.epilogue,
                    external_call_sites,
                    @enumFromInt(@intFromEnum(platform)),
                    program,
                    access,
                )
            else
                try encodeCollectionReference(allocator, words, data_fixups, &fixups, program, access),
            .collection_replace => |replacement| if (replacement.dynamic)
                try ListRuntime.emitReplace(allocator, words, data_fixups, &fixups.epilogue, external_call_sites, @enumFromInt(@intFromEnum(platform)), program, replacement)
            else
                try encodeCollectionReplace(allocator, words, data_fixups, &fixups, program, replacement),
            .collection_count => |count| if (!viewCountFeedsNextComparison(function, instruction_index, count))
                try ListRuntime.emitCount(allocator, words, function, count),
            .list_edit => |edit| try ListRuntime.emitEdit(allocator, words, data_fixups, &fixups.epilogue, external_call_sites, @enumFromInt(@intFromEnum(platform)), program, edit),
            .collection_slice => |slice| try ListRuntime.emitSlice(allocator, words, &fixups.epilogue, external_call_sites, @enumFromInt(@intFromEnum(platform)), slice),
            .collection_view => |view| try ListRuntime.emitView(allocator, words, &fixups.epilogue, external_call_sites, @enumFromInt(@intFromEnum(platform)), view),
            .aggregate_equal => |comparison| try encodeAggregateEqual(allocator, words, &fixups, comparison),
            .convert => |conversion| try encodeConversion(
                allocator,
                words,
                &fixups,
                data_fixups,
                program,
                function,
                conversion,
            ),
            .format_value => |format| try TextRuntime.emitFormat(
                allocator,
                words,
                float_calls,
                data_fixups,
                &fixups.epilogue,
                format,
            ),
            .string_concat => |concat| try StringRuntime.emitConcat(allocator, words, &fixups.epilogue, external_call_sites, @enumFromInt(@intFromEnum(platform)), concat),
            .string_count => |count| try StringRuntime.emitCount(allocator, words, count),
            .string_byte_count => |count| try StringRuntime.emitByteCount(allocator, words, count),
            .string_byte_at => |access| {
                try words.append(allocator, loadStack(.x9, access.operand));
                try words.append(allocator, addSubtractImmediate(.x9, .x9, 8, true));
                try words.append(allocator, loadStack(.x10, access.index));
                try words.append(allocator, addRegisters(.x9, .x9, .x10));
                try words.append(allocator, A64.loadByte(.x11, .x9));
                try words.append(allocator, storeStack(.x11, access.result));
            },
            .string_from_bytes => |conversion| try StringRuntime.emitFromBytes(
                allocator,
                words,
                &fixups.epilogue,
                external_call_sites,
                @enumFromInt(@intFromEnum(platform)),
                conversion,
            ),
            .unary => |unary| {
                if (unary.type.isFloat()) {
                    try loadFloatValue(allocator, words, function, .x9, unary.operand, unary.type == .float64);
                    try words.append(allocator, floatNegate(.x10, .x9, unary.type == .float64));
                    try storeFloatValue(allocator, words, function, .x10, unary.result, unary.type == .float64);
                    continue;
                }
                try loadCachedValue(allocator, words, function, &scalar_cache, .x9, unary.operand);
                if (unary.type.isSignedInteger()) {
                    try emitImmediate64(allocator, words, .x10, @bitCast(Numeric.integerMin(unary.type)));
                    try words.append(allocator, compareRegisters(.x9, .x10));
                    try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.equal), .imm19);
                } else {
                    try appendFixup(allocator, words, &fixups.overflow, compareBranchNonZero64(.x9), .imm19);
                }
                try words.append(allocator, subtractSetFlags(.x11, .zero_or_sp, .x9));
                try storeCachedValue(allocator, words, function, &scalar_cache, .x11, unary.result);
            },
            .binary => |binary| {
                if (Pairing.floatDivisionFollower(function, instruction_index, binary)) |pair| {
                    const numerator: Register = @enumFromInt(pair.numerator);
                    const destination = floatResultRegister(function, binary.result) orelse .x11;
                    try words.append(allocator, A64.duplicateFloat32Lane(destination, numerator, 1));
                    if (floatResultRegister(function, binary.result) == null) {
                        try storeFloatValue(allocator, words, function, destination, binary.result, false);
                    }
                    continue;
                }
                if (Pairing.floatDivisionLeader(function, instruction_index, binary)) |pair| {
                    const numerator: Register = @enumFromInt(pair.numerator);
                    const scratch: Register = if (numerator == .x9) .x10 else .x9;
                    try loadFloatValue(allocator, words, function, scratch, binary.right, false);
                    try words.append(allocator, A64.duplicateFloat32Lane(scratch, scratch, 0));
                    try words.append(allocator, floatArithmetic2(
                        numerator,
                        numerator,
                        scratch,
                        .divide,
                    ));
                    const destination = floatResultRegister(function, binary.result) orelse .x11;
                    if (destination != numerator) {
                        try words.append(allocator, moveFloat(destination, numerator, false));
                    }
                    if (floatResultRegister(function, binary.result) == null) {
                        try storeFloatValue(allocator, words, function, destination, binary.result, false);
                    }
                    continue;
                }
                if (horizontalFloatPairAdd(function, binary)) |source| {
                    const destination = floatResultRegister(function, binary.result) orelse .x11;
                    try words.append(allocator, A64.horizontalAddFloat32Pair(destination, source));
                    if (floatResultRegister(function, binary.result) == null) {
                        try storeFloatValue(allocator, words, function, destination, binary.result, false);
                    }
                    continue;
                }
                if (floatPairLeader(function, binary.result) != null) continue;
                if (floatLaneResidence(function, binary.result) != null and binary.type == .float32 and
                    switch (binary.operator) {
                        .add, .subtract, .multiply, .divide => true,
                        else => false,
                    })
                {
                    const residence = floatLaneResidence(function, binary.result).?;
                    if (residence.lane != 1) return error.InvalidMachineProgram;
                    const first = definingBinary(function.instructions, residence.partner) orelse return error.InvalidMachineProgram;
                    try encodeFloatPairBinary(allocator, words, function, first);
                    continue;
                }
                if (multiplyFeedsNextAdd(function, instruction_index, binary)) continue;
                if (immediateArithmeticConstant(function, instruction_index, binary)) |constant| {
                    try encodeImmediateArithmetic(allocator, words, &fixups, function, &scalar_cache, binary, constant);
                } else if (comparisonBranchIndex(function, instruction_index, binary) != null) {
                    try encodeComparisonFlags(allocator, words, function, instruction_index, binary);
                } else if (fusedMultiplyForAdd(function, instruction_index)) |multiply_value| {
                    try encodeFloatMultiplyAdd(allocator, words, function, binary, multiply_value);
                } else try encodeBinary(allocator, words, &fixups, function, &scalar_cache, binary);
            },
            .function_address => |address| {
                try function_addresses.append(allocator, .{ .at = words.items.len, .function = address.function });
                try appendRelocatableAddress(allocator, words, .x9);
                try words.append(allocator, storeStack(.x9, address.result.start));
                if (address.environment) |environment| {
                    for (address.captures, 0..) |capture, index| {
                        try loadValue(allocator, words, function, .x9, capture);
                        try words.append(allocator, storeStack(.x9, @intCast(@as(usize, environment.start) + index)));
                    }
                    try emitStackAddress(allocator, words, .x9, environment.start);
                } else try words.append(allocator, moveWideZero64(.x9, 0, 0));
                try words.append(allocator, storeStack(.x9, address.result.start + 1));
            },
            .call => |call| {
                if (call.arguments.len > Machine.max_register_arguments) if (call.result) |result| if (result.aggregate) {
                    if (result.width == 0) {
                        try words.append(allocator, moveWideZero64(.x15, 0, 0));
                    } else try emitStackAddress(allocator, words, .x15, result.start);
                };
                const outgoing_stack_size = try emitCallArguments(allocator, words, function, call.arguments, true);
                if (call.arguments.len <= Machine.max_register_arguments) if (call.result) |result| if (result.aggregate) {
                    if (result.width == 0) {
                        try words.append(allocator, moveWideZero64(.x15, 0, 0));
                    } else try emitStackAddress(allocator, words, .x15, result.start);
                };
                try calls.append(allocator, .{ .at = words.items.len, .function = call.function });
                try words.append(allocator, branchLink());
                try emitStackAdjustment(allocator, words, outgoing_stack_size, true);
                try appendFixup(allocator, words, &fixups.epilogue, compareBranchNonZero(.x8), .imm19);
                if (call.result) |result| if (!result.aggregate) {
                    if (floatResidence(function, result.start) != null) {
                        try words.append(allocator, moveGeneralToFloat(.x9, .x0, false));
                        try storeFloatValue(allocator, words, function, .x9, result.start, false);
                    } else try storeValue(allocator, words, function, .x0, result.start);
                };
            },
            .indirect_call => |call| {
                if (call.arguments.len > Machine.max_register_arguments) if (call.result) |result| if (result.aggregate) {
                    if (result.width == 0) try words.append(allocator, moveWideZero64(.x15, 0, 0)) else try emitStackAddress(allocator, words, .x15, result.start);
                };
                const outgoing_stack_size = try emitCallArguments(allocator, words, function, call.arguments, false);
                if (call.arguments.len <= Machine.max_register_arguments) if (call.result) |result| if (result.aggregate) {
                    if (result.width == 0) try words.append(allocator, moveWideZero64(.x15, 0, 0)) else try emitStackAddress(allocator, words, .x15, result.start);
                };
                if (outgoing_stack_size == 0) {
                    try words.append(allocator, loadStack(.x14, call.callee + 1));
                    try words.append(allocator, loadStack(.x16, call.callee));
                } else {
                    try emitLoadAtOffset(
                        allocator,
                        words,
                        .x16,
                        .x13,
                        Machine.slotOffset(call.callee),
                    );
                    try emitLoadAtOffset(
                        allocator,
                        words,
                        .x14,
                        .x13,
                        Machine.slotOffset(call.callee + 1),
                    );
                }
                try words.append(allocator, A64.branchLinkRegister(.x16));
                try emitStackAdjustment(allocator, words, outgoing_stack_size, true);
                try appendFixup(allocator, words, &fixups.epilogue, compareBranchNonZero(.x8), .imm19);
                if (call.result) |result| if (!result.aggregate) try words.append(allocator, storeStack(.x0, result.start));
            },
            .external_call => |call| try ExternalCalls.emit(allocator, words, external_call_sites, program, function, call),
            .external_indirect_call => |call| try ExternalCalls.emitIndirect(allocator, words, function, call),
            .mutex_lock => try emitMutexOperation(allocator, words, data_fixups, external_call_sites, platform, program, true),
            .mutex_unlock => try emitMutexOperation(allocator, words, data_fixups, external_call_sites, platform, program, false),
            .dynamic_call => |call| try encodeDynamicCall(allocator, words, calls, &fixups, function, call),
            .print => |value| switch (value.kind) {
                .signed_integer => try emitPrintInteger(allocator, words, value.value, 1, value.newline),
                .unsigned_integer => try emitPrintUnsigned(allocator, words, value.value, value.newline),
                .float32, .float64 => try emitPrintFloat(
                    allocator,
                    words,
                    float_calls,
                    data_fixups,
                    program,
                    value.value,
                    value.kind == .float64,
                    value.newline,
                ),
                .boolean => try emitPrintBoolean(allocator, words, data_fixups, program, value.value, value.newline),
                .string => try StringRuntime.emitPrint(allocator, words, data_fixups, program, value.value, 1, value.newline),
            },
            .assert => |assertion| {
                try words.append(allocator, loadStack(.x9, assertion.condition));
                const passed = words.items.len;
                try words.append(allocator, compareBranchNonZero(.x9));
                try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, assertion.header, 2);
                try StringRuntime.emitPrint(allocator, words, data_fixups, program, assertion.message, 2, true);
                try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.runtime_failure)));
                try appendFixup(allocator, words, &fixups.epilogue, branch(), .imm26);
                try patch19(words.items, passed, words.items.len);
            },
            .panic => |panic_value| {
                try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, panic_value.header, 2);
                try StringRuntime.emitPrint(allocator, words, data_fixups, program, panic_value.message, 2, true);
                try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.runtime_failure)));
                try appendFixup(allocator, words, &fixups.epilogue, branch(), .imm26);
            },
            .return_value => |value| {
                if (value.aggregate) {
                    const hidden_slot = function.hidden_return_slot orelse return error.InvalidMachineProgram;
                    try words.append(allocator, loadStack(.x14, hidden_slot));
                    for (0..value.width) |leaf| {
                        const slot: Machine.Slot = @intCast(@as(usize, value.start) + leaf);
                        if (floatLaneResidence(function, slot) != null) {
                            try loadFloatValue(allocator, words, function, .x9, slot, false);
                            try words.append(allocator, moveFloatToGeneral(.x9, .x9, false));
                        } else try words.append(allocator, loadStack(.x9, slot));
                        try emitStoreAtOffset(allocator, words, .x9, .x14, leaf * Machine.slot_size);
                    }
                    try words.append(allocator, moveWideZero64(.x0, 0, 0));
                } else if (function.return_type.isFloat()) {
                    try loadFloatValue(allocator, words, function, .x9, value.start, function.return_type == .float64);
                    try words.append(allocator, moveFloatToGeneral(.x0, .x9, function.return_type == .float64));
                } else try loadValue(allocator, words, function, .x0, value.start);
                try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.success)));
                try appendFixup(allocator, words, &fixups.epilogue, branch(), .imm26);
            },
            .return_void => {
                try words.append(allocator, moveWideZero32(.x0, 0));
                try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.success)));
                try appendFixup(allocator, words, &fixups.epilogue, branch(), .imm26);
            },
            .jump => |target| {
                if (collection_cursor) |cursor| if (cursor.entry_jump == instruction_index) {
                    try ListRuntime.emitCursorAddress(
                        allocator,
                        words,
                        function,
                        cursor.collection,
                        cursor.initial_index,
                        cursor.stride,
                        @enumFromInt(cursor.register),
                        if (cursor.termination) |termination|
                            @enumFromInt(termination.register)
                        else
                            null,
                    );
                };
                if (collection_cursor) |cursor| if (cursor.termination) |termination| {
                    if (termination.backedge == instruction_index) {
                        try words.append(allocator, compareRegisters(
                            @enumFromInt(cursor.register),
                            @enumFromInt(termination.register),
                        ));
                        try control_fixups.append(allocator, .{
                            .at = words.items.len,
                            .target = termination.body,
                            .width = .imm19,
                        });
                        try words.append(allocator, conditionalBranch(.carry_clear));
                        continue;
                    }
                };
                if (loopBackedgeComparison(function, instruction_index, target)) |backedge| {
                    const header = resolveJumpTarget(function.instructions, target);
                    if (instruction_offsets[header] == instruction_offsets[backedge.comparison_index]) {
                        try encodeComparisonFlags(
                            allocator,
                            words,
                            function,
                            backedge.comparison_index,
                            backedge.comparison,
                        );
                        try control_fixups.append(allocator, .{
                            .at = words.items.len,
                            .target = backedge.body,
                            .width = .imm19,
                        });
                        const false_condition = comparisonFalseCondition(backedge.comparison);
                        try words.append(allocator, conditionalBranch(
                            if (backedge.body_on_true) invertCondition(false_condition) else false_condition,
                        ));
                        continue;
                    }
                }
                try control_fixups.append(allocator, .{ .at = words.items.len, .target = target, .width = .imm26 });
                try words.append(allocator, branch());
            },
            .branch => |branch_value| {
                const then_instruction = resolveJumpTarget(function.instructions, branch_value.then_instruction);
                const else_instruction = resolveJumpTarget(function.instructions, branch_value.else_instruction);
                if (fusedFloatConjunction(function, instruction_index)) |conjunction| {
                    const double = conjunction.second.type == .float64;
                    const left = try prepareFloatOperand(
                        allocator,
                        words,
                        function,
                        .x9,
                        conjunction.second.left,
                        double,
                    );
                    const right = switch (conjunction.right) {
                        .register => |register| register,
                        .slot => |slot| try prepareFloatOperand(
                            allocator,
                            words,
                            function,
                            .x10,
                            slot,
                            double,
                        ),
                    };
                    try words.append(allocator, floatConditionalCompare(
                        left,
                        right,
                        invertCondition(comparisonFalseCondition(conjunction.first)),
                        falseFlagsForCondition(comparisonFalseCondition(conjunction.second)),
                        double,
                    ));
                    const second_then = resolveJumpTarget(
                        function.instructions,
                        conjunction.branch.then_instruction,
                    );
                    const second_else = resolveJumpTarget(
                        function.instructions,
                        conjunction.branch.else_instruction,
                    );
                    const false_condition = comparisonFalseCondition(conjunction.second);
                    if (second_then == instruction_index + 1) {
                        try control_fixups.append(allocator, .{
                            .at = words.items.len,
                            .target = second_else,
                            .width = .imm19,
                        });
                        try words.append(allocator, conditionalBranch(false_condition));
                    } else if (second_else == instruction_index + 1) {
                        try control_fixups.append(allocator, .{
                            .at = words.items.len,
                            .target = second_then,
                            .width = .imm19,
                        });
                        try words.append(allocator, conditionalBranch(invertCondition(false_condition)));
                    } else {
                        try control_fixups.append(allocator, .{
                            .at = words.items.len,
                            .target = second_else,
                            .width = .imm19,
                        });
                        try words.append(allocator, conditionalBranch(false_condition));
                        try control_fixups.append(allocator, .{
                            .at = words.items.len,
                            .target = second_then,
                            .width = .imm26,
                        });
                        try words.append(allocator, branch());
                    }
                    continue;
                }
                if (comparisonForBranch(function, instruction_index)) |binary| {
                    const false_condition = comparisonFalseCondition(binary);
                    if (then_instruction == instruction_index + 1) {
                        try control_fixups.append(allocator, .{
                            .at = words.items.len,
                            .target = else_instruction,
                            .width = .imm19,
                        });
                        try words.append(allocator, conditionalBranch(false_condition));
                    } else if (else_instruction == instruction_index + 1) {
                        try control_fixups.append(allocator, .{
                            .at = words.items.len,
                            .target = then_instruction,
                            .width = .imm19,
                        });
                        try words.append(allocator, conditionalBranch(invertCondition(false_condition)));
                    } else {
                        try control_fixups.append(allocator, .{
                            .at = words.items.len,
                            .target = else_instruction,
                            .width = .imm19,
                        });
                        try words.append(allocator, conditionalBranch(false_condition));
                        try control_fixups.append(allocator, .{
                            .at = words.items.len,
                            .target = then_instruction,
                            .width = .imm26,
                        });
                        try words.append(allocator, branch());
                    }
                    continue;
                }
                const condition = try prepareValueOperand(allocator, words, function, .x9, branch_value.condition);
                if (then_instruction == instruction_index + 1) {
                    try control_fixups.append(allocator, .{
                        .at = words.items.len,
                        .target = else_instruction,
                        .width = .imm19,
                    });
                    try words.append(allocator, compareBranchZero(condition));
                } else if (else_instruction == instruction_index + 1) {
                    try control_fixups.append(allocator, .{
                        .at = words.items.len,
                        .target = then_instruction,
                        .width = .imm19,
                    });
                    try words.append(allocator, compareBranchNonZero(condition));
                } else {
                    try words.append(allocator, compareBranchZero(condition) | (2 << 5));
                    try control_fixups.append(allocator, .{
                        .at = words.items.len,
                        .target = then_instruction,
                        .width = .imm26,
                    });
                    try words.append(allocator, branch());
                    try control_fixups.append(allocator, .{
                        .at = words.items.len,
                        .target = else_instruction,
                        .width = .imm26,
                    });
                    try words.append(allocator, branch());
                }
            },
        }
    }

    for (control_fixups.items) |fixup| {
        if (fixup.target >= instruction_offsets.len) return error.InvalidMachineProgram;
        const target = resolveEncodedTarget(function, fixup.target);
        switch (fixup.width) {
            .imm19 => try patch19(words.items, fixup.at, instruction_offsets[target]),
            .imm26 => try patch26(words.items, fixup.at, instruction_offsets[target]),
        }
    }

    const overflow_label = words.items.len;
    try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.integer_overflow)));
    const overflow_to_epilogue = words.items.len;
    try words.append(allocator, branch());

    const division_label = words.items.len;
    try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.division_by_zero)));
    const division_to_epilogue = words.items.len;
    try words.append(allocator, branch());

    const epilogue_label = words.items.len;
    saved_register_index = 0;
    for (callee_saved_registers) |register| if (shouldSaveRegister(function, register, extended_frame)) {
        try emitLoadAtOffset(
            allocator,
            words,
            register,
            .zero_or_sp,
            @as(usize, local_frame_size) + saved_register_index * Machine.slot_size,
        );
        saved_register_index += 1;
    };
    for (callee_saved_float_registers) |register| if (functionUsesFloatRegister(function, register)) {
        try emitLoadAtOffset(
            allocator,
            words,
            .x9,
            .zero_or_sp,
            @as(usize, local_frame_size) + saved_register_index * Machine.slot_size,
        );
        try words.append(allocator, moveGeneralToFloat(register, .x9, true));
        saved_register_index += 1;
    };
    try emitStackAdjustment(allocator, words, encoded_frame_size, true);
    try words.append(allocator, restoreFrame());
    try words.append(allocator, returnInstruction());

    for (fixups.overflow.items) |fixup| try patchLocal(words.items, fixup, overflow_label);
    for (fixups.division_by_zero.items) |fixup| try patchLocal(words.items, fixup, division_label);
    for (fixups.epilogue.items) |fixup| try patchLocal(words.items, fixup, epilogue_label);
    try patch26(words.items, overflow_to_epilogue, epilogue_label);
    try patch26(words.items, division_to_epilogue, epilogue_label);
    var previous_debug_position: ?@import("../Source.zig").Position = null;
    if (program.debug) for (function.instruction_positions, 0..) |maybe_position, instruction_index| {
        const position = maybe_position orelse continue;
        if (instruction_index >= instruction_offsets.len) break;
        if (previous_debug_position) |previous| {
            if (previous.file == position.file and previous.line == position.line and previous.column == position.column) continue;
        }
        previous_debug_position = position;
        const instruction_offset = std.math.mul(usize, instruction_offsets[instruction_index], @sizeOf(u32)) catch return error.InvalidMachineProgram;
        try debug_locations.append(allocator, .{
            .instruction_offset = @intCast(instruction_offset),
            .position = position,
        });
    };
}

fn pairAggregateParameterLeaves(function: Machine.Function, parameter: Machine.Span, leaf: usize) bool {
    // Two-slot aggregates include collection-view ABI descriptors. Preserve
    // their individually captured pointer/count path until they carry an
    // explicit machine type distinct from ordinary value aggregates.
    if (parameter.width == 2 or leaf + 1 >= parameter.width or leaf * Machine.slot_size > 504) return false;
    const first: Machine.Slot = @intCast(@as(usize, parameter.start) + leaf);
    const second: Machine.Slot = first + 1;
    if ((first >= Machine.direct_stack_slots) != (second >= Machine.direct_stack_slots)) return false;
    const stack_slot = if (first >= Machine.direct_stack_slots)
        first - Machine.direct_stack_slots
    else
        first;
    if (@as(usize, stack_slot) * Machine.slot_size > 504) return false;
    return floatResidence(function, first) == null and floatLaneResidence(function, first) == null and
        floatResidence(function, second) == null and floatLaneResidence(function, second) == null;
}

fn resolveEncodedTarget(function: Machine.Function, initial: usize) usize {
    var target = initial;
    var remaining = function.instructions.len;
    while (remaining != 0 and target < function.instructions.len) : (remaining -= 1) {
        target = switch (function.instructions[target]) {
            .jump => |next| next,
            .copy => |copy| if (copyEmitsNoCode(function, copy)) target + 1 else return target,
            else => return target,
        };
    }
    return initial;
}

fn copyEmitsNoCode(function: Machine.Function, copy: Machine.Instruction.Copy) bool {
    if (floatLaneResidence(function, copy.result) != null or floatLaneResidence(function, copy.operand) != null) return false;
    const float_source = floatResultRegister(function, copy.operand);
    const float_destination = floatResultRegister(function, copy.result);
    if (float_source != null or float_destination != null) {
        return float_source != null and float_destination != null and float_source.? == float_destination.?;
    }
    const source = valueResultRegister(function, copy.operand);
    const destination = valueResultRegister(function, copy.result);
    return source != null and destination != null and source.? == destination.?;
}

fn resolveJumpTarget(instructions: []const Machine.Instruction, initial: usize) usize {
    var target = initial;
    var remaining = instructions.len;
    while (remaining != 0) : (remaining -= 1) {
        target = switch (instructions[target]) {
            .jump => |next| next,
            else => return target,
        };
        if (target >= instructions.len) return initial;
    }
    return initial;
}

const callee_saved_registers = [_]Register{
    .x19, .x20, .x21, .x22, .x23, .x24, .x25, .x26, .x27, .x28,
};
const callee_saved_float_registers = [_]Register{ .x8, .x13, .x14, .x15 };

fn calleeSavedRegisterCount(function: Machine.Function, extended_frame: bool) usize {
    var count: usize = 0;
    for (callee_saved_registers) |register| {
        count += @intFromBool(shouldSaveRegister(function, register, extended_frame));
    }
    for (callee_saved_float_registers) |register| count += @intFromBool(functionUsesFloatRegister(function, register));
    return count;
}

fn shouldSaveRegister(function: Machine.Function, register: Register, extended_frame: bool) bool {
    return functionUsesRegister(function, register) or
        (extended_frame and register == .x28);
}

fn functionUsesFloatRegister(function: Machine.Function, register: Register) bool {
    for (function.float_register_slots) |residence| {
        if (residence != null and residence.? == @intFromEnum(register)) return true;
    }
    return false;
}

fn functionUsesRegister(function: Machine.Function, register: Register) bool {
    for (function.register_slots) |residence| {
        if (residence != null and residence.? == @intFromEnum(register)) return true;
    }
    return false;
}

fn emitMutexOperation(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(DataFixup),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Platform,
    program: Machine.Program,
    lock: bool,
) Error!void {
    const global = program.mutex_global orelse return error.InvalidMachineProgram;
    if (platform == .windows) {
        return emitWindowsMutexCall(
            allocator,
            words,
            data_fixups,
            sites,
            global,
            if (lock) .enter_critical_section else .leave_critical_section,
        );
    }
    const function_id = if (lock)
        program.mutex_lock_function orelse return error.InvalidMachineProgram
    else
        program.mutex_unlock_function orelse return error.InvalidMachineProgram;
    try data_fixups.append(allocator, .{ .at = words.items.len, .global = global });
    try appendRelocatableAddress(allocator, words, .x0);
    if (lock) try words.append(allocator, moveWideZero64(.x1, 0, 0));
    try sites.append(allocator, .{
        .instruction_offset = @intCast(words.items.len * @sizeOf(u32)),
        .function = function_id,
    });
    try words.append(allocator, A64.addressPage(.x16));
    try words.append(allocator, load64(.x16, .x16, 0));
    try words.append(allocator, A64.branchLinkRegister(.x16));
}

fn emitWindowsMutexCall(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(DataFixup),
    sites: *std.ArrayList(ExternalCalls.Site),
    global: usize,
    symbol: @import("../Windows/Imports.zig").Symbol,
) Error!void {
    try data_fixups.append(allocator, .{ .at = words.items.len, .global = global });
    try appendRelocatableAddress(allocator, words, .x0);
    try sites.append(allocator, .{
        .instruction_offset = @intCast(words.items.len * @sizeOf(u32)),
        .function = 0,
        .windows_symbol = symbol,
    });
    try words.append(allocator, A64.addressPage(.x16));
    try words.append(allocator, load64(.x16, .x16, 0));
    try words.append(allocator, A64.branchLinkRegister(.x16));
}

fn encodeDynamicCall(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    calls: *std.ArrayList(CallFixup),
    fixups: *FunctionFixups,
    function: Machine.Function,
    call: Machine.Instruction.DynamicCall,
) Error!void {
    const discriminator: Register = if (call.arguments.len <= Machine.max_register_arguments) .x9 else .x12;
    try words.append(allocator, loadStack(discriminator, call.receiver));
    try words.append(allocator, load64(discriminator, discriminator, 0));
    if (call.arguments.len > Machine.max_register_arguments) if (call.result) |result| if (result.aggregate) {
        if (result.width == 0) try words.append(allocator, moveWideZero64(.x15, 0, 0)) else try emitStackAddress(allocator, words, .x15, result.start);
    };
    const outgoing_stack_size = try emitCallArguments(allocator, words, function, call.arguments, false);
    if (call.arguments.len <= Machine.max_register_arguments) if (call.result) |result| if (result.aggregate) {
        if (result.width == 0) try words.append(allocator, moveWideZero64(.x15, 0, 0)) else try emitStackAddress(allocator, words, .x15, result.start);
    };
    var done: std.ArrayList(usize) = .empty;
    for (call.implementations) |implementation| {
        try emitImmediate64(allocator, words, .x10, implementation.structure);
        try words.append(allocator, compareRegisters(discriminator, .x10));
        const skip = words.items.len;
        try words.append(allocator, conditionalBranch(.not_equal));
        try calls.append(allocator, .{ .at = words.items.len, .function = implementation.function });
        try words.append(allocator, branchLink());
        try emitStackAdjustment(allocator, words, outgoing_stack_size, true);
        try appendFixup(allocator, words, &fixups.epilogue, compareBranchNonZero(.x8), .imm19);
        try done.append(allocator, words.items.len);
        try words.append(allocator, branch());
        try patch19(words.items, skip, words.items.len);
    }
    try calls.append(allocator, .{ .at = words.items.len, .function = call.function });
    try words.append(allocator, branchLink());
    try emitStackAdjustment(allocator, words, outgoing_stack_size, true);
    try appendFixup(allocator, words, &fixups.epilogue, compareBranchNonZero(.x8), .imm19);
    for (done.items) |at| try patch26(words.items, at, words.items.len);
    if (call.result) |result| if (!result.aggregate) try words.append(allocator, storeStack(.x0, result.start));
}

fn emitCallArguments(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    arguments: []const Machine.Span,
    use_residences: bool,
) Error!u16 {
    const register_count = @min(arguments.len, Machine.max_register_arguments);
    for (arguments[0..register_count], 0..) |argument, index| {
        const outgoing: Register = @enumFromInt(index);
        if (argument.aggregate) {
            if (argument.width == 0) {
                try words.append(allocator, moveWideZero64(outgoing, 0, 0));
            } else try emitStackAddress(allocator, words, outgoing, argument.start);
        } else if (use_residences and floatResidence(function, argument.start) != null) {
            try loadFloatValue(allocator, words, function, .x9, argument.start, false);
            try words.append(allocator, moveFloatToGeneral(outgoing, .x9, false));
        } else if (use_residences) {
            try loadValue(allocator, words, function, outgoing, argument.start);
        } else try words.append(allocator, loadStack(outgoing, argument.start));
    }
    if (arguments.len <= Machine.max_register_arguments) return 0;

    const raw_size = (arguments.len - Machine.max_register_arguments) * Machine.slot_size;
    const stack_size: u16 = @intCast(std.mem.alignForward(usize, raw_size, 16));
    try emitStackAdjustment(allocator, words, stack_size, false);
    // ORR's register 31 denotes XZR, not SP. Materialize the caller frame base
    // with ADD so stack arguments keep addressing the original local frame.
    try words.append(allocator, addSubtractImmediate(.x13, .zero_or_sp, 0, true));
    try emitRegisterAdjustment(allocator, words, .x13, stack_size, true);
    for (arguments[Machine.max_register_arguments..], 0..) |argument, index| {
        if (argument.aggregate) {
            if (argument.width == 0) {
                try words.append(allocator, moveWideZero64(.x9, 0, 0));
            } else try emitBaseAddress(allocator, words, .x9, .x13, Machine.slotOffset(argument.start));
        } else if (floatLaneResidence(function, argument.start)) |residence| {
            const source: Register = @enumFromInt(residence.register);
            if (residence.lane == 0) {
                try words.append(allocator, moveFloatToGeneral(.x9, source, false));
            } else {
                try words.append(allocator, A64.duplicateFloat32Lane(.x9, source, 1));
                try words.append(allocator, moveFloatToGeneral(.x9, .x9, false));
            }
        } else if (floatResidence(function, argument.start)) |number| {
            try words.append(allocator, moveFloatToGeneral(.x9, @enumFromInt(number), false));
        } else if (valueResultRegister(function, argument.start)) |source| {
            if (source != .x9) try words.append(allocator, moveRegister(.x9, source));
        } else try emitLoadAtOffset(
            allocator,
            words,
            .x9,
            .x13,
            Machine.slotOffset(argument.start),
        );
        try emitStoreAtOffset(allocator, words, .x9, .zero_or_sp, index * Machine.slot_size);
    }
    return stack_size;
}

fn emitSpanCopy(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    result: Machine.Span,
    operand: Machine.Span,
) Allocator.Error!void {
    for (0..result.width) |index| {
        try words.append(allocator, loadStack(.x9, @intCast(@as(usize, operand.start) + index)));
        try words.append(allocator, storeStack(.x9, @intCast(@as(usize, result.start) + index)));
    }
}

fn emitReferenceCopy(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    span: Machine.Span,
    reference: Machine.Slot,
    load_reference: bool,
) Allocator.Error!void {
    return emitOffsetReferenceCopy(allocator, words, function, span, reference, 0, load_reference);
}

fn emitOffsetReferenceCopy(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    span: Machine.Span,
    reference: Machine.Slot,
    byte_offset: u32,
    load_reference: bool,
) Allocator.Error!void {
    const base = valueResultRegister(function, reference) orelse .x9;
    if (base == .x9) try words.append(allocator, loadStack(.x9, reference));
    for (0..span.width) |index| {
        const offset = @as(usize, byte_offset) + index * Machine.slot_size;
        const slot: Machine.Slot = @intCast(@as(usize, span.start) + index);
        if (load_reference) {
            // A projected borrowed aggregate need not materialize unused
            // fields. Keep live fields at this read, before any aliasing
            // write; Debug and unsupported functions retain the full copy.
            if (span.width > 1 and function.register_slots.len != 0 and
                !slotHasUse(function.instructions, slot)) continue;
            if (floatResidence(function, slot)) |register| {
                if (offset <= std.math.maxInt(u15)) {
                    try words.append(allocator, A64.loadVector64(@enumFromInt(register), base, @intCast(offset)));
                } else {
                    try emitLoadAtOffset(allocator, words, .x10, base, offset);
                    try storeFloatValue(allocator, words, function, .x10, slot, true);
                }
            } else {
                try emitLoadAtOffset(allocator, words, .x10, base, offset);
                try storeValue(allocator, words, function, .x10, slot);
            }
        } else {
            if (floatResidence(function, slot)) |register| {
                if (offset <= std.math.maxInt(u15)) {
                    try words.append(allocator, A64.storeVector64(@enumFromInt(register), base, @intCast(offset)));
                } else {
                    try loadFloatValue(allocator, words, function, .x10, slot, true);
                    try emitStoreAtOffset(allocator, words, .x10, base, offset);
                }
            } else {
                try loadValue(allocator, words, function, .x10, slot);
                try emitStoreAtOffset(allocator, words, .x10, base, offset);
            }
        }
    }
}

fn fusedReferenceOffset(
    function: Machine.Function,
    copy_index: usize,
    reference: Machine.Slot,
) ?Machine.Instruction.ReferenceOffset {
    if (copy_index == 0) return null;
    const offset = switch (function.instructions[copy_index - 1]) {
        .reference_offset => |value| value,
        else => return null,
    };
    if (offset.result != reference or
        !referenceOffsetFeedsNextCopy(function, copy_index - 1, offset)) return null;
    return offset;
}

fn referenceOffsetFeedsNextCopy(
    function: Machine.Function,
    offset_index: usize,
    offset: Machine.Instruction.ReferenceOffset,
) bool {
    const copy_index = offset_index + 1;
    if (copy_index >= function.instructions.len or instructionIsControlTarget(function.instructions, copy_index) or
        !slotUsedOnlyAt(function.instructions, offset.result, copy_index)) return false;
    return switch (function.instructions[copy_index]) {
        .reference_load => |load| load.reference == offset.result,
        .reference_store => |store| store.reference == offset.result and
            !spanContainsSlot(store.operand, offset.result),
        else => false,
    };
}

fn instructionIsControlTarget(instructions: []const Machine.Instruction, target: usize) bool {
    for (instructions) |instruction| switch (instruction) {
        .jump => |destination| if (destination == target) return true,
        .branch => |branch_value| if (branch_value.then_instruction == target or branch_value.else_instruction == target) return true,
        else => {},
    };
    return false;
}

fn emitStackAddress(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    destination: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    const byte_offset = @as(usize, slot) * Machine.slot_size;
    if (byte_offset <= std.math.maxInt(u12)) {
        return words.append(allocator, addSubtractImmediate(destination, .zero_or_sp, @intCast(byte_offset), true));
    }
    try emitImmediate64(allocator, words, .x14, byte_offset);
    try words.append(allocator, addSubtractImmediate(destination, .zero_or_sp, 0, true));
    try words.append(allocator, addRegisters(destination, destination, .x14));
}

fn emitLoadAtOffset(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    destination: Register,
    base: Register,
    byte_offset: usize,
) Allocator.Error!void {
    if (byte_offset <= std.math.maxInt(u12)) return words.append(allocator, load64(destination, base, @intCast(byte_offset)));
    const scratch: Register = if (base == .x14) .x13 else .x14;
    if (base == .zero_or_sp) {
        try words.append(allocator, addSubtractImmediate(scratch, base, 0, true));
        try emitRegisterAdjustment(allocator, words, scratch, byte_offset, true);
    } else {
        try emitImmediate64(allocator, words, scratch, byte_offset);
        try words.append(allocator, addRegisters(scratch, base, scratch));
    }
    try words.append(allocator, load64(destination, scratch, 0));
}

fn emitStoreAtOffset(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    source: Register,
    base: Register,
    byte_offset: usize,
) Allocator.Error!void {
    if (byte_offset <= std.math.maxInt(u12)) return words.append(allocator, store64(source, base, @intCast(byte_offset)));
    var scratch: Register = .x13;
    if (source == scratch or base == scratch) {
        scratch = .x14;
    }
    if (source == scratch or base == scratch) {
        scratch = .x12;
    }
    if (base == .zero_or_sp) {
        try words.append(allocator, addSubtractImmediate(scratch, base, 0, true));
        try emitRegisterAdjustment(allocator, words, scratch, byte_offset, true);
    } else {
        try emitImmediate64(allocator, words, scratch, byte_offset);
        try words.append(allocator, addRegisters(scratch, base, scratch));
    }
    try words.append(allocator, store64(source, scratch, 0));
}

fn encodeAggregateEqual(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *FunctionFixups,
    comparison: Machine.Instruction.AggregateEqual,
) Error!void {
    var unequal_branches: std.ArrayList(usize) = .empty;
    var scalar_cache = ScalarCache{ .enabled = false };
    for (comparison.leaves) |leaf| {
        var guard_skips: std.ArrayList(usize) = .empty;
        for (leaf.guards) |guard| {
            try words.append(allocator, loadStack(.x9, comparison.left.start + guard.offset));
            try emitImmediate64(allocator, words, .x10, guard.expected);
            try words.append(allocator, compareRegisters(.x9, .x10));
            try guard_skips.append(allocator, words.items.len);
            try words.append(allocator, conditionalBranch(.not_equal));
        }
        try encodeBinary(allocator, words, fixups, null, &scalar_cache, .{
            .result = comparison.result,
            .operator = .equal,
            .left = comparison.left.start + leaf.offset,
            .right = comparison.right.start + leaf.offset,
            .type = leaf.type,
        });
        try words.append(allocator, loadStack(.x9, comparison.result));
        try unequal_branches.append(allocator, words.items.len);
        try words.append(allocator, compareBranchZero(.x9));
        for (guard_skips.items) |skip| try patch19(words.items, skip, words.items.len);
    }
    try words.append(allocator, moveWideZero32(.x9, @intFromBool(comparison.equal)));
    try words.append(allocator, storeStack(.x9, comparison.result));
    const done_branch = words.items.len;
    try words.append(allocator, branch());
    const unequal = words.items.len;
    try words.append(allocator, moveWideZero32(.x9, @intFromBool(!comparison.equal)));
    try words.append(allocator, storeStack(.x9, comparison.result));
    const done = words.items.len;
    for (unequal_branches.items) |at| try patch19(words.items, at, unequal);
    try patch26(words.items, done_branch, done);
}

const CollectionBounds = struct { negative: usize, upper: usize };

fn emitCollectionBounds(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    index: Machine.Slot,
    count: u32,
) Error!CollectionBounds {
    try emitNormalizedCollectionIndex(allocator, words, index, count);
    try words.append(allocator, compareRegisters(.x9, .zero_or_sp));
    const negative = words.items.len;
    try words.append(allocator, conditionalBranch(.less));
    try emitImmediate64(allocator, words, .x10, count);
    try words.append(allocator, compareRegisters(.x9, .x10));
    const upper = words.items.len;
    try words.append(allocator, conditionalBranch(.greater_equal));
    return .{ .negative = negative, .upper = upper };
}

fn emitNormalizedCollectionIndex(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    index: Machine.Slot,
    count: u32,
) Error!void {
    try words.append(allocator, loadStack(.x9, index));
    try words.append(allocator, compareRegisters(.x9, .zero_or_sp));
    const nonnegative = words.items.len;
    try words.append(allocator, conditionalBranch(.greater_equal));
    try emitImmediate64(allocator, words, .x10, count);
    try words.append(allocator, addRegisters(.x9, .x9, .x10));
    try patch19(words.items, nonnegative, words.items.len);
}

fn encodeCollectionLoad(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(DataFixup),
    function_fixups: *FunctionFixups,
    program: Machine.Program,
    access: Machine.Instruction.CollectionLoad,
) Error!void {
    if (!access.checked) {
        try words.append(allocator, loadStack(.x9, access.index));
        try emitStackAddress(allocator, words, .x10, access.collection.start);
        try emitImmediate64(allocator, words, .x11, @as(u64, access.result.width) * Machine.slot_size);
        try words.append(allocator, multiply(.x9, .x9, .x11));
        try words.append(allocator, addRegisters(.x10, .x10, .x9));
        for (0..access.result.width) |leaf| {
            try emitLoadAtOffset(allocator, words, .x12, .x10, leaf * Machine.slot_size);
            try words.append(allocator, storeStack(.x12, @intCast(@as(usize, access.result.start) + leaf)));
        }
        return;
    }
    const bounds = try emitCollectionBounds(allocator, words, access.index, access.count);
    try emitStackAddress(allocator, words, .x10, access.collection.start);
    try emitImmediate64(allocator, words, .x11, @as(u64, access.result.width) * Machine.slot_size);
    try words.append(allocator, multiply(.x9, .x9, .x11));
    try words.append(allocator, addRegisters(.x10, .x10, .x9));
    for (0..access.result.width) |leaf| {
        try emitLoadAtOffset(allocator, words, .x12, .x10, leaf * Machine.slot_size);
        try words.append(allocator, storeStack(.x12, @intCast(@as(usize, access.result.start) + leaf)));
    }
    const complete = words.items.len;
    try words.append(allocator, branch());
    const failure = words.items.len;
    try patch19(words.items, bounds.negative, failure);
    try patch19(words.items, bounds.upper, failure);
    try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, access.header, 2);
    try emitPrintInteger(allocator, words, access.index, 2, false);
    try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, access.tail, 2);
    try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.runtime_failure)));
    try appendFixup(allocator, words, &function_fixups.epilogue, branch(), .imm26);
    try patch26(words.items, complete, words.items.len);
}

fn encodeCollectionReference(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(DataFixup),
    function_fixups: *FunctionFixups,
    program: Machine.Program,
    access: Machine.Instruction.CollectionReference,
) Error!void {
    const bounds: ?CollectionBounds = if (access.checked)
        try emitCollectionBounds(allocator, words, access.index, access.count)
    else unchecked: {
        try emitNormalizedCollectionIndex(allocator, words, access.index, access.count);
        break :unchecked null;
    };
    try words.append(allocator, loadStack(.x10, access.reference.?));
    try emitImmediate64(allocator, words, .x11, @as(u64, access.element_width) * Machine.slot_size);
    try words.append(allocator, multiply(.x9, .x9, .x11));
    try words.append(allocator, addRegisters(.x10, .x10, .x9));
    try words.append(allocator, storeStack(.x10, access.result));
    if (bounds == null) return;
    const complete = words.items.len;
    try words.append(allocator, branch());
    const failure = words.items.len;
    try patch19(words.items, bounds.?.negative, failure);
    try patch19(words.items, bounds.?.upper, failure);
    try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, access.header, 2);
    try emitPrintInteger(allocator, words, access.index, 2, false);
    try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, access.tail, 2);
    try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.runtime_failure)));
    try appendFixup(allocator, words, &function_fixups.epilogue, branch(), .imm26);
    try patch26(words.items, complete, words.items.len);
}

fn encodeCollectionReplace(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(DataFixup),
    function_fixups: *FunctionFixups,
    program: Machine.Program,
    replacement: Machine.Instruction.CollectionReplace,
) Error!void {
    const bounds = try emitCollectionBounds(allocator, words, replacement.index, replacement.count);
    try words.append(allocator, moveRegister(.x13, .x9));
    try emitSpanCopy(allocator, words, replacement.result, replacement.collection);
    try emitStackAddress(allocator, words, .x10, replacement.result.start);
    try emitImmediate64(allocator, words, .x11, @as(u64, replacement.replacement.width) * Machine.slot_size);
    try words.append(allocator, multiply(.x9, .x13, .x11));
    try words.append(allocator, addRegisters(.x10, .x10, .x9));
    for (0..replacement.replacement.width) |leaf| {
        try words.append(allocator, loadStack(.x12, @intCast(@as(usize, replacement.replacement.start) + leaf)));
        try emitStoreAtOffset(allocator, words, .x12, .x10, leaf * Machine.slot_size);
    }
    const complete = words.items.len;
    try words.append(allocator, branch());
    const failure = words.items.len;
    try patch19(words.items, bounds.negative, failure);
    try patch19(words.items, bounds.upper, failure);
    try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, replacement.header, 2);
    try emitPrintInteger(allocator, words, replacement.index, 2, false);
    try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, replacement.tail, 2);
    try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.runtime_failure)));
    try appendFixup(allocator, words, &function_fixups.epilogue, branch(), .imm26);
    try patch26(words.items, complete, words.items.len);
}

fn integerConstantFeedsNextArithmetic(
    function: Machine.Function,
    index: usize,
    constant: Machine.Instruction.ConstantInt,
) bool {
    if (constant.bits > std.math.maxInt(u12) or index + 1 >= function.instructions.len or
        controlTargetsInstruction(function.instructions, index + 1)) return false;
    const binary = switch (function.instructions[index + 1]) {
        .binary => |value| value,
        else => return false,
    };
    return binary.type == constant.type and
        (binary.operator == .add or binary.operator == .subtract) and
        binary.right == constant.result and
        slotUsedOnlyAt(function.instructions, constant.result, index + 1);
}

fn immediateArithmeticConstant(
    function: Machine.Function,
    index: usize,
    binary: Machine.Instruction.Binary,
) ?Machine.Instruction.ConstantInt {
    if (index == 0) return null;
    const constant = switch (function.instructions[index - 1]) {
        .constant_int => |value| value,
        else => return null,
    };
    return if (integerConstantFeedsNextArithmetic(function, index - 1, constant) and
        binary.right == constant.result) constant else null;
}

fn encodeImmediateArithmetic(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *FunctionFixups,
    function: Machine.Function,
    scalar_cache: *ScalarCache,
    binary: Machine.Instruction.Binary,
    constant: Machine.Instruction.ConstantInt,
) Error!void {
    const left = try prepareValueOperand(allocator, words, function, .x9, binary.left);
    const destination = valueResultRegister(function, binary.result) orelse .x11;
    const add = binary.operator == .add;
    if (binary.checked) {
        try words.append(allocator, addSubtractImmediateSetFlags(
            destination,
            left,
            @intCast(constant.bits),
            add,
        ));
        try appendFixup(
            allocator,
            words,
            &fixups.overflow,
            conditionalBranch(if (binary.type.isSignedInteger())
                .overflow
            else if (add)
                .carry_set
            else
                .carry_clear),
            .imm19,
        );
        try emitIntegerRangeCheck(allocator, words, fixups, binary.type, destination);
    } else try words.append(allocator, A64.addSubtractImmediate(
        destination,
        left,
        @intCast(constant.bits),
        add,
    ));
    try finishValueResult(allocator, words, function, scalar_cache, destination, binary.result);
}

fn encodeBinary(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *FunctionFixups,
    function: ?Machine.Function,
    scalar_cache: *ScalarCache,
    binary: Machine.Instruction.Binary,
) Error!void {
    if (binary.type == .str) return StringRuntime.emitComparison(allocator, words, binary);
    if (binary.type.isFloat()) return encodeFloatBinary(allocator, words, function, binary);
    const left = try prepareOptionalValueOperand(allocator, words, function, .x9, binary.left);
    const right = try prepareOptionalValueOperand(allocator, words, function, .x10, binary.right);
    const destination = valueOptionalResultRegister(function, binary.result) orelse .x11;
    const signed = binary.type.isSignedInteger();
    switch (binary.operator) {
        .add => {
            try words.append(allocator, addSetFlags(destination, left, right));
            if (binary.checked) {
                try appendFixup(
                    allocator,
                    words,
                    &fixups.overflow,
                    conditionalBranch(if (signed) .overflow else .carry_set),
                    .imm19,
                );
                try emitIntegerRangeCheck(allocator, words, fixups, binary.type, destination);
            }
            try finishValueResult(allocator, words, function, scalar_cache, destination, binary.result);
        },
        .subtract => {
            try words.append(allocator, subtractSetFlags(destination, left, right));
            if (binary.checked) {
                try appendFixup(
                    allocator,
                    words,
                    &fixups.overflow,
                    conditionalBranch(if (signed) .overflow else .carry_clear),
                    .imm19,
                );
                try emitIntegerRangeCheck(allocator, words, fixups, binary.type, destination);
            }
            try finishValueResult(allocator, words, function, scalar_cache, destination, binary.result);
        },
        .multiply => {
            try words.append(allocator, multiply(destination, left, right));
            if (signed) {
                try words.append(allocator, signedMultiplyHigh(.x12, left, right));
                try words.append(allocator, arithmeticShiftRight63(.x13, destination));
                try words.append(allocator, compareRegisters(.x12, .x13));
                try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.not_equal), .imm19);
            } else {
                try words.append(allocator, unsignedMultiplyHigh(.x12, left, right));
                try appendFixup(allocator, words, &fixups.overflow, compareBranchNonZero64(.x12), .imm19);
            }
            try emitIntegerRangeCheck(allocator, words, fixups, binary.type, destination);
            try finishValueResult(allocator, words, function, scalar_cache, destination, binary.result);
        },
        .divide => {
            try appendFixup(allocator, words, &fixups.division_by_zero, compareBranchZero64(right), .imm19);
            if (signed) {
                try emitImmediate64(allocator, words, .x11, @bitCast(Numeric.integerMin(binary.type)));
                try words.append(allocator, compareRegisters(left, .x11));
                const not_minimum = words.items.len;
                try words.append(allocator, conditionalBranch(.not_equal));
                try emitImmediate64(allocator, words, .x12, @bitCast(@as(i64, -1)));
                try words.append(allocator, compareRegisters(right, .x12));
                try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.equal), .imm19);
                try patch19(words.items, not_minimum, words.items.len);
            }
            try words.append(allocator, if (signed) signedDivide(destination, left, right) else unsignedDivide(destination, left, right));
            try finishValueResult(allocator, words, function, scalar_cache, destination, binary.result);
        },
        .remainder => {
            try appendFixup(allocator, words, &fixups.division_by_zero, compareBranchZero64(right), .imm19);
            if (signed) {
                try emitImmediate64(allocator, words, .x11, @bitCast(Numeric.integerMin(binary.type)));
                try words.append(allocator, compareRegisters(left, .x11));
                const not_minimum = words.items.len;
                try words.append(allocator, conditionalBranch(.not_equal));
                try emitImmediate64(allocator, words, .x12, @bitCast(@as(i64, -1)));
                try words.append(allocator, compareRegisters(right, .x12));
                try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.equal), .imm19);
                try patch19(words.items, not_minimum, words.items.len);
            }
            try words.append(allocator, if (signed) signedDivide(.x11, left, right) else unsignedDivide(.x11, left, right));
            try words.append(allocator, multiplySubtract(destination, .x11, right, left));
            try finishValueResult(allocator, words, function, scalar_cache, destination, binary.result);
        },
        .minimum, .maximum => return error.InvalidMachineProgram,
        .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => {
            try words.append(allocator, compareRegisters(left, right));
            try words.append(allocator, moveWideZero32(destination, 0));
            const skip_true = words.items.len;
            try words.append(allocator, conditionalBranch(inverseComparison(binary.operator, signed)));
            try words.append(allocator, moveWideZero32(destination, 1));
            try patch19(words.items, skip_true, words.items.len);
            try finishValueResult(allocator, words, function, scalar_cache, destination, binary.result);
        },
        .bit_and => {
            try words.append(allocator, andRegisters(destination, left, right));
            try finishValueResult(allocator, words, function, scalar_cache, destination, binary.result);
        },
        .bit_xor => {
            try words.append(allocator, exclusiveOrRegisters(destination, left, right));
            try finishValueResult(allocator, words, function, scalar_cache, destination, binary.result);
        },
        .shift_left, .shift_right => {
            try emitImmediate64(allocator, words, .x11, binary.type.bitWidth());
            try words.append(allocator, compareRegisters(right, .x11));
            try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.greater_equal), .imm19);
            try words.append(allocator, if (binary.operator == .shift_left)
                logicalShiftLeftVariable(destination, left, right)
            else
                logicalShiftRightVariable(destination, left, right));
            try emitImmediate64(allocator, words, .x12, Numeric.mask(binary.type.bitWidth()));
            try words.append(allocator, andRegisters(destination, destination, .x12));
            try finishValueResult(allocator, words, function, scalar_cache, destination, binary.result);
        },
    }
}

fn encodeComparisonFlags(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    instruction_index: usize,
    binary: Machine.Instruction.Binary,
) Error!void {
    const zero_right = comparisonHasElidedZeroRight(function, instruction_index, binary);
    if (binary.type.isFloat()) {
        const double = binary.type == .float64;
        const left = try prepareFloatOperand(allocator, words, function, .x9, binary.left, double);
        if (zero_right) {
            try words.append(allocator, floatCompareZero(left, double));
            return;
        }
        if (comparisonHasElidedCachedRight(function, instruction_index, binary)) |right| {
            try words.append(allocator, floatCompare(left, right, double));
            return;
        }
        const right = try prepareFloatOperand(allocator, words, function, .x10, binary.right, double);
        try words.append(allocator, floatCompare(left, right, double));
        return;
    }
    if (comparisonHasElidedViewCount(function, instruction_index, binary)) |count| {
        const count_slot = count.collection.start + 1;
        const count_register = try prepareValueOperand(allocator, words, function, .x10, count_slot);
        const other_slot = if (binary.left == count.result) binary.right else binary.left;
        const other_register = try prepareValueOperand(allocator, words, function, .x9, other_slot);
        try words.append(allocator, if (binary.left == count.result)
            compareRegisters(count_register, other_register)
        else
            compareRegisters(other_register, count_register));
        return;
    }
    const left = try prepareValueOperand(allocator, words, function, .x9, binary.left);
    if (zero_right) {
        try words.append(allocator, compareRegisters(left, .zero_or_sp));
        return;
    }
    const right = try prepareValueOperand(allocator, words, function, .x10, binary.right);
    try words.append(allocator, compareRegisters(left, right));
}

fn zeroConstantFeedsNextComparison(
    function: Machine.Function,
    index: usize,
    result: Machine.Slot,
) bool {
    return constantFeedsNextComparison(function, index, result);
}

fn constantFeedsNextComparison(
    function: Machine.Function,
    index: usize,
    result: Machine.Slot,
) bool {
    if (index + 1 >= function.instructions.len or controlTargetsInstruction(function.instructions, index + 1)) return false;
    const binary = switch (function.instructions[index + 1]) {
        .binary => |value| value,
        else => return false,
    };
    return binary.right == result and
        comparisonBranchIndex(function, index + 1, binary) != null and
        slotUsedOnlyAt(function.instructions, result, index + 1);
}

fn viewCountFeedsNextComparison(
    function: Machine.Function,
    index: usize,
    count: Machine.Instruction.CollectionCount,
) bool {
    if (!count.view or index + 1 >= function.instructions.len or
        controlTargetsInstruction(function.instructions, index + 1)) return false;
    const binary = switch (function.instructions[index + 1]) {
        .binary => |value| value,
        else => return false,
    };
    return (binary.left == count.result or binary.right == count.result) and
        comparisonBranchIndex(function, index + 1, binary) != null and
        slotUsedOnlyAt(function.instructions, count.result, index + 1);
}

fn comparisonHasElidedViewCount(
    function: Machine.Function,
    index: usize,
    binary: Machine.Instruction.Binary,
) ?Machine.Instruction.CollectionCount {
    if (index == 0) return null;
    const count = switch (function.instructions[index - 1]) {
        .collection_count => |value| value,
        else => return null,
    };
    return if (viewCountFeedsNextComparison(function, index - 1, count) and
        (binary.left == count.result or binary.right == count.result)) count else null;
}

const CachedFloatLiteral = struct {
    bits: u64,
    double: bool,
    register: Register,
};

const float_literal_cache_registers = [_]Register{ .x5, .x6, .x7 };

fn cachedFloatLiterals(function: Machine.Function) [float_literal_cache_registers.len]?CachedFloatLiteral {
    var result: [float_literal_cache_registers.len]?CachedFloatLiteral = @splat(null);
    if (function.float_register_slots.len == 0) return result;
    var count: usize = 0;
    for (function.instructions, 0..) |instruction, index| {
        const candidate: CachedFloatLiteral = switch (instruction) {
            .constant_float32 => |constant| .{ .bits = constant.bits, .double = false, .register = undefined },
            .constant_float64 => |constant| .{ .bits = constant.bits, .double = true, .register = undefined },
            else => continue,
        };
        const result_slot = switch (instruction) {
            .constant_float32 => |constant| constant.result,
            .constant_float64 => |constant| constant.result,
            else => unreachable,
        };
        if (candidate.bits == 0 or
            !constantFeedsNextComparison(function, index, result_slot) or
            !instructionIsInsideLoop(function.instructions, index)) continue;
        var duplicate = false;
        for (result[0..count]) |existing| if (existing.?.bits == candidate.bits and
            existing.?.double == candidate.double)
        {
            duplicate = true;
            break;
        };
        if (duplicate) continue;
        result[count] = .{
            .bits = candidate.bits,
            .double = candidate.double,
            .register = float_literal_cache_registers[count],
        };
        count += 1;
        if (count == result.len) break;
    }
    return result;
}

fn cachedFloatLiteralRegister(function: Machine.Function, bits: u64, double: bool) ?Register {
    for (cachedFloatLiterals(function)) |candidate| if (candidate) |literal| {
        if (literal.bits == bits and literal.double == double) return literal.register;
    };
    return null;
}

const FloatMaxDiamond = struct {
    destination: Machine.Slot,
    left: Machine.Slot,
    right: Register,
    join: usize,
};

fn floatMaxDiamond(
    function: Machine.Function,
    index: usize,
    constant_result: Machine.Slot,
    bits: u64,
    double: bool,
) ?FloatMaxDiamond {
    if (index + 4 >= function.instructions.len) return null;
    const initialization = switch (function.instructions[index + 1]) {
        .copy => |value| value,
        else => return null,
    };
    if (initialization.operand != constant_result) return null;
    const comparison_constant = switch (function.instructions[index + 2]) {
        .constant_float32 => |value| if (!double and value.bits == bits) value.result else return null,
        .constant_float64 => |value| if (double and value.bits == bits) value.result else return null,
        else => return null,
    };
    const comparison = switch (function.instructions[index + 3]) {
        .binary => |value| value,
        else => return null,
    };
    const expected_type: @TypeOf(comparison.type) = if (double) .float64 else .float32;
    if (comparison.operator != .greater or comparison.right != comparison_constant or
        comparison.type != expected_type) return null;
    const branch_index = comparisonBranchIndex(function, index + 3, comparison) orelse return null;
    if (branch_index != index + 4) return null;
    const branch_value = function.instructions[branch_index].branch;
    const then_instruction = resolveJumpTarget(function.instructions, branch_value.then_instruction);
    const replacement = switch (function.instructions[then_instruction]) {
        .copy => |value| value,
        else => return null,
    };
    if (replacement.result != initialization.result or replacement.operand != comparison.left or
        then_instruction + 1 >= function.instructions.len) return null;
    const join = switch (function.instructions[then_instruction + 1]) {
        .jump => |target| resolveJumpTarget(function.instructions, target),
        else => return null,
    };
    if (resolveJumpTarget(function.instructions, branch_value.else_instruction) != join) return null;
    const right = cachedFloatLiteralRegister(function, bits, double) orelse return null;
    return .{
        .destination = initialization.result,
        .left = comparison.left,
        .right = right,
        .join = join,
    };
}

fn instructionIsInsideLoop(instructions: []const Machine.Instruction, index: usize) bool {
    for (instructions, 0..) |instruction, source| switch (instruction) {
        .jump => |target| if (target <= index and index <= source) return true,
        .branch => |branch_value| {
            if ((branch_value.then_instruction <= index and index <= source) or
                (branch_value.else_instruction <= index and index <= source)) return true;
        },
        else => {},
    };
    return false;
}

fn comparisonHasElidedCachedRight(
    function: Machine.Function,
    index: usize,
    binary: Machine.Instruction.Binary,
) ?Register {
    if (index == 0) return null;
    return switch (function.instructions[index - 1]) {
        .constant_float32 => |constant| if (constant.result == binary.right and
            constantFeedsNextComparison(function, index - 1, constant.result))
            cachedFloatLiteralRegister(function, constant.bits, false)
        else
            null,
        .constant_float64 => |constant| if (constant.result == binary.right and
            constantFeedsNextComparison(function, index - 1, constant.result))
            cachedFloatLiteralRegister(function, constant.bits, true)
        else
            null,
        else => null,
    };
}

fn comparisonHasElidedZeroRight(
    function: Machine.Function,
    index: usize,
    binary: Machine.Instruction.Binary,
) bool {
    if (index == 0) return false;
    return switch (function.instructions[index - 1]) {
        .constant_int => |constant| constant.result == binary.right and constant.bits == 0 and
            zeroConstantFeedsNextComparison(function, index - 1, constant.result),
        .constant_float32 => |constant| constant.result == binary.right and constant.bits == 0 and
            zeroConstantFeedsNextComparison(function, index - 1, constant.result),
        .constant_float64 => |constant| constant.result == binary.right and constant.bits == 0 and
            zeroConstantFeedsNextComparison(function, index - 1, constant.result),
        else => false,
    };
}

fn comparisonFalseCondition(binary: Machine.Instruction.Binary) Condition {
    if (binary.type.isFloat()) return inverseFloatComparison(binary.operator);
    return inverseComparison(binary.operator, binary.type.isSignedInteger());
}

fn comparisonBranchIndex(
    function: Machine.Function,
    index: usize,
    binary: Machine.Instruction.Binary,
) ?usize {
    if (function.register_slots.len == 0 and function.float_register_slots.len == 0) return null;
    if (!isComparison(binary.operator) or binary.type == .str or index + 1 >= function.instructions.len) return null;
    var branch_index = index + 1;
    var branch_condition = binary.result;
    if (function.instructions[index + 1] == .copy) {
        const copy = function.instructions[index + 1].copy;
        if (copy.operand != binary.result or index + 2 >= function.instructions.len) return null;
        branch_index = index + 2;
        branch_condition = copy.result;
        if (!slotUsedOnlyAt(function.instructions, binary.result, index + 1)) return null;
    }
    const branch_value = switch (function.instructions[branch_index]) {
        .branch => |value| value,
        else => return null,
    };
    if (branch_value.condition != branch_condition or
        !slotUsedOnlyAt(function.instructions, branch_condition, branch_index)) return null;
    for (function.instructions, 0..) |instruction, other_index| {
        if (other_index > index and other_index <= branch_index) continue;
        switch (instruction) {
            .jump => |target| if (target > index and target <= branch_index) return null,
            .branch => |value| if ((value.then_instruction > index and value.then_instruction <= branch_index) or
                (value.else_instruction > index and value.else_instruction <= branch_index)) return null,
            else => {},
        }
    }
    return branch_index;
}

fn slotUsedOnlyAt(instructions: []const Machine.Instruction, slot: Machine.Slot, allowed: usize) bool {
    for (instructions, 0..) |instruction, index| {
        if (index != allowed and instructionUsesSlot(instruction, slot)) return false;
    }
    return instructionUsesSlot(instructions[allowed], slot);
}

fn copyBelongsToFusedComparison(function: Machine.Function, index: usize) bool {
    if (index == 0) return false;
    const binary = switch (function.instructions[index - 1]) {
        .binary => |value| value,
        else => return false,
    };
    return comparisonBranchIndex(function, index - 1, binary) == index + 1;
}

fn comparisonForBranch(function: Machine.Function, branch_index: usize) ?Machine.Instruction.Binary {
    if (branch_index != 0) switch (function.instructions[branch_index - 1]) {
        .binary => |binary| if (comparisonBranchIndex(function, branch_index - 1, binary) == branch_index) return binary,
        else => {},
    };
    if (branch_index >= 2) switch (function.instructions[branch_index - 2]) {
        .binary => |binary| if (comparisonBranchIndex(function, branch_index - 2, binary) == branch_index) return binary,
        else => {},
    };
    return null;
}

const LoopBackedgeComparison = struct {
    comparison_index: usize,
    branch_index: usize,
    comparison: Machine.Instruction.Binary,
    body: usize,
    body_on_true: bool,
};

fn loopBackedgeComparison(
    function: Machine.Function,
    jump_index: usize,
    initial_target: usize,
) ?LoopBackedgeComparison {
    const header = resolveJumpTarget(function.instructions, initial_target);
    if (header >= jump_index or jump_index + 1 >= function.instructions.len) return null;
    for (function.instructions[header..jump_index], header..) |instruction, branch_index| {
        const branch_value = switch (instruction) {
            .branch => |value| value,
            else => continue,
        };
        const comparison_index = if (branch_index != 0 and
            function.instructions[branch_index - 1] == .binary and
            comparisonBranchIndex(
                function,
                branch_index - 1,
                function.instructions[branch_index - 1].binary,
            ) == branch_index)
            branch_index - 1
        else if (branch_index >= 2 and
            function.instructions[branch_index - 2] == .binary and
            comparisonBranchIndex(
                function,
                branch_index - 2,
                function.instructions[branch_index - 2].binary,
            ) == branch_index)
            branch_index - 2
        else
            continue;
        const comparison = function.instructions[comparison_index].binary;
        const then_instruction = resolveJumpTarget(function.instructions, branch_value.then_instruction);
        const else_instruction = resolveJumpTarget(function.instructions, branch_value.else_instruction);
        if (else_instruction == jump_index + 1 and then_instruction > branch_index and
            then_instruction <= jump_index)
        {
            return .{
                .comparison_index = comparison_index,
                .branch_index = branch_index,
                .comparison = comparison,
                .body = then_instruction,
                .body_on_true = true,
            };
        }
        if (then_instruction == jump_index + 1 and else_instruction > branch_index and
            else_instruction <= jump_index)
        {
            return .{
                .comparison_index = comparison_index,
                .branch_index = branch_index,
                .comparison = comparison,
                .body = else_instruction,
                .body_on_true = false,
            };
        }
    }
    return null;
}

const FusedFloatRight = union(enum) {
    register: Register,
    slot: Machine.Slot,
};

const FusedFloatConjunction = struct {
    first: Machine.Instruction.Binary,
    second: Machine.Instruction.Binary,
    branch: Machine.Instruction.Branch,
    right: FusedFloatRight,
};

fn fusedFloatConjunction(function: Machine.Function, first_branch_index: usize) ?FusedFloatConjunction {
    const first = comparisonForBranch(function, first_branch_index) orelse return null;
    if (!first.type.isFloat()) return null;
    const first_branch = switch (function.instructions[first_branch_index]) {
        .branch => |value| value,
        else => return null,
    };
    const second_start = resolveJumpTarget(function.instructions, first_branch.then_instruction);
    const short_circuit = resolveJumpTarget(function.instructions, first_branch.else_instruction);
    if (second_start + 1 >= function.instructions.len) return null;
    const second_index = switch (function.instructions[second_start]) {
        .constant_float32, .constant_float64 => second_start + 1,
        .binary => second_start,
        else => return null,
    };
    const second = switch (function.instructions[second_index]) {
        .binary => |value| value,
        else => return null,
    };
    if (second.type != first.type or !isComparison(second.operator)) return null;
    const second_branch_index = comparisonBranchIndex(function, second_index, second) orelse return null;
    const second_branch = switch (function.instructions[second_branch_index]) {
        .branch => |value| value,
        else => return null,
    };
    if (resolveJumpTarget(function.instructions, second_branch.else_instruction) != short_circuit) return null;
    const right: FusedFloatRight = switch (function.instructions[second_start]) {
        .constant_float32, .constant_float64 => .{ .register = comparisonHasElidedCachedRight(function, second_index, second) orelse return null },
        .binary => .{ .slot = second.right },
        else => unreachable,
    };
    return .{
        .first = first,
        .second = second,
        .branch = second_branch,
        .right = right,
    };
}

fn falseFlagsForCondition(condition: Condition) u4 {
    return switch (condition) {
        .equal, .less_equal => 0b0100,
        .not_equal, .carry_clear, .plus => 0,
        .carry_set, .higher => 0b0010,
        .minus, .less => 0b1000,
        .overflow => 0b0001,
        .lower_or_same, .greater_equal, .greater => 0b0100,
    };
}

fn isComparison(operator: Machine.BinaryOperator) bool {
    return switch (operator) {
        .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => true,
        else => false,
    };
}

fn instructionUsesSlot(instruction: Machine.Instruction, slot: Machine.Slot) bool {
    return switch (instruction) {
        .copy => |value| value.operand == slot,
        .copy_range => |value| spanContainsSlot(value.operand, slot),
        .aggregate_init => |value| for (value.fields) |field| {
            if (spanContainsSlot(field, slot)) break true;
        } else false,
        .unary => |value| value.operand == slot,
        .binary => |value| value.left == slot or value.right == slot,
        .convert => |value| value.operand == slot,
        .collection_load => |value| value.index == slot or spanContainsSlot(value.collection, slot),
        .collection_count => |value| spanContainsSlot(value.collection, slot),
        .return_value => |value| spanContainsSlot(value, slot),
        .branch => |value| value.condition == slot,
        else => MemoryResidence.uses(instruction, slot),
    };
}

fn eagerCollectionWidth(
    function: Machine.Function,
    load_index: usize,
    load: Machine.Instruction.CollectionLoad,
) u12 {
    // An unused checked aggregate still validates its index, but its payload
    // need not be copied. Only ordinary Release slots have stable identities.
    if (load.checked and load.dynamic and load.result.width > 1 and function.register_slots.len != 0) {
        var used = false;
        for (0..load.result.width) |leaf| {
            const slot: Machine.Slot = @intCast(@as(usize, load.result.start) + leaf);
            if (slotHasUse(function.instructions, slot)) {
                used = true;
                break;
            }
        }
        if (!used) return 0;
    }
    if (load.checked or !load.dynamic or load.result.width < 2 or
        function.float_register_slots.len == 0) return load.result.width;
    for (0..load.result.width) |leaf| {
        const slot: Machine.Slot = @intCast(@as(usize, load.result.start) + leaf);
        if (floatResidence(function, slot) == null and floatLaneResidence(function, slot) == null) return load.result.width;
    }
    for (0..load.result.width) |leaf| {
        const slot: Machine.Slot = @intCast(@as(usize, load.result.start) + leaf);
        const first_use = firstSlotUseAfter(function.instructions, load_index, slot) orelse continue;
        for (function.instructions[load_index + 1 .. first_use]) |instruction| switch (instruction) {
            .branch => return if (leaf == 0) load.result.width else @intCast(leaf),
            else => {},
        };
    }
    return load.result.width;
}

fn firstSlotUseAfter(
    instructions: []const Machine.Instruction,
    start: usize,
    slot: Machine.Slot,
) ?usize {
    for (instructions[start + 1 ..], start + 1..) |instruction, index| {
        if (instructionUsesSlot(instruction, slot)) return index;
    }
    return null;
}

fn slotHasUse(instructions: []const Machine.Instruction, slot: Machine.Slot) bool {
    for (instructions) |instruction| if (instructionUsesSlot(instruction, slot)) return true;
    return false;
}

fn emitDeferredCollectionLoads(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    instruction_index: usize,
    collection_cursor: ?LoopCursor.Cursor,
) Error!void {
    for (function.instructions[0..instruction_index], 0..) |instruction, load_index| {
        const load = switch (instruction) {
            .collection_load => |value| value,
            else => continue,
        };
        if (load.checked) continue;
        const eager_width = eagerCollectionWidth(function, load_index, load);
        if (eager_width >= load.result.width) continue;
        const first_slot: Machine.Slot = @intCast(@as(usize, load.result.start) + eager_width);
        if (firstSlotUseAfter(function.instructions, load_index, first_slot) == instruction_index) {
            if (collection_cursor) |cursor| {
                if (cursor.load_index == load_index) {
                    try ListRuntime.emitCursorDeferredLoad(
                        allocator,
                        words,
                        function,
                        load,
                        eager_width,
                        @enumFromInt(cursor.register),
                    );
                    continue;
                }
            }
            try ListRuntime.emitDeferredLoad(allocator, words, function, load, eager_width);
        }
    }
}

fn spanContainsSlot(span: Machine.Span, slot: Machine.Slot) bool {
    return slot >= span.start and @as(usize, slot) < @as(usize, span.start) + span.width;
}

fn encodeFloatBinary(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: ?Machine.Function,
    binary: Machine.Instruction.Binary,
) Error!void {
    const double = binary.type == .float64;
    const left = try prepareFloatOperand(allocator, words, function, .x9, binary.left, double);
    const right = try prepareFloatOperand(allocator, words, function, .x10, binary.right, double);
    switch (binary.operator) {
        .add, .subtract, .multiply, .divide => {
            const destination = floatResultRegister(function, binary.result) orelse .x11;
            try words.append(allocator, floatArithmetic(destination, left, right, binary.operator, double));
            if (floatResultRegister(function, binary.result) == null) {
                try storeOptionalFloatValue(allocator, words, function, destination, binary.result, double);
            }
        },
        .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => {
            try words.append(allocator, floatCompare(left, right, double));
            try words.append(allocator, moveWideZero32(.x11, 0));
            const skip_true = words.items.len;
            try words.append(allocator, conditionalBranch(inverseFloatComparison(binary.operator)));
            try words.append(allocator, moveWideZero32(.x11, 1));
            try patch19(words.items, skip_true, words.items.len);
            try storeOptionalValue(allocator, words, function, .x11, binary.result);
        },
        .minimum, .maximum => try encodeFloatMinimumMaximum(
            allocator,
            words,
            function,
            binary,
            left,
            right,
            double,
        ),
        else => return error.InvalidMachineProgram,
    }
}

fn encodeFloatMinimumMaximum(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: ?Machine.Function,
    binary: Machine.Instruction.Binary,
    left: Register,
    right: Register,
    double: bool,
) Error!void {
    const destination = floatResultRegister(function, binary.result) orelse .x11;
    var choose_left: std.ArrayList(usize) = .empty;
    defer choose_left.deinit(allocator);
    var choose_right: std.ArrayList(usize) = .empty;
    defer choose_right.deinit(allocator);
    try words.append(allocator, floatCompare(left, left, double));
    try choose_right.append(allocator, words.items.len);
    try words.append(allocator, conditionalBranch(.overflow));
    try words.append(allocator, floatCompare(right, right, double));
    try choose_left.append(allocator, words.items.len);
    try words.append(allocator, conditionalBranch(.overflow));
    try words.append(allocator, floatCompare(left, right, double));
    try choose_left.append(allocator, words.items.len);
    try words.append(allocator, conditionalBranch(if (binary.operator == .maximum) .greater else .less));
    try choose_right.append(allocator, words.items.len);
    try words.append(allocator, conditionalBranch(if (binary.operator == .maximum) .less else .greater));
    try words.append(allocator, moveFloatToGeneral(.x13, left, double));
    if (!double) try words.append(allocator, signExtendRegister(.x13, .x13, 32));
    try words.append(allocator, compareRegisters(.x13, .zero_or_sp));
    if (binary.operator == .maximum) {
        try choose_right.append(allocator, words.items.len);
    } else {
        try choose_left.append(allocator, words.items.len);
    }
    try words.append(allocator, conditionalBranch(.minus));
    const equal_fallthrough = if (binary.operator == .maximum) left else right;
    if (destination != equal_fallthrough) try words.append(allocator, moveFloat(destination, equal_fallthrough, double));
    const equal_done = words.items.len;
    try words.append(allocator, branch());
    const right_label = words.items.len;
    if (destination != right) try words.append(allocator, moveFloat(destination, right, double));
    const right_done = words.items.len;
    try words.append(allocator, branch());
    const left_label = words.items.len;
    if (destination != left) try words.append(allocator, moveFloat(destination, left, double));
    const done = words.items.len;
    try patch26(words.items, equal_done, done);
    try patch26(words.items, right_done, done);
    for (choose_left.items) |site| try patch19(words.items, site, left_label);
    for (choose_right.items) |site| try patch19(words.items, site, right_label);
    if (floatResultRegister(function, binary.result) == null)
        try storeOptionalFloatValue(allocator, words, function, destination, binary.result, double);
}

fn encodeFloatPairBinary(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    first: Machine.Instruction.Binary,
) Error!void {
    const residence = floatPairLeader(function, first.result) orelse return error.InvalidMachineProgram;
    const partner = pairedPartner(function, first.result) orelse return error.InvalidMachineProgram;
    const second = definingBinary(function.instructions, partner) orelse return error.InvalidMachineProgram;
    const left = try prepareFloatPairOperand(allocator, words, function, first.left, second.left, .x9, .x10);
    const right = try prepareFloatPairOperand(allocator, words, function, first.right, second.right, .x11, .x12);
    try words.append(allocator, floatArithmetic2(@enumFromInt(residence.register), left, right, first.operator));
}

fn horizontalFloatPairAdd(
    function: Machine.Function,
    binary: Machine.Instruction.Binary,
) ?Register {
    if (binary.type != .float32 or binary.operator != .add) return null;
    const left = floatLaneResidence(function, binary.left) orelse return null;
    const right = floatLaneResidence(function, binary.right) orelse return null;
    if (left.register != right.register or left.lane != 0 or right.lane != 1) return null;
    return @enumFromInt(left.register);
}

fn prepareFloatPairOperand(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    first: Machine.Slot,
    second: Machine.Slot,
    destination: Register,
    scratch: Register,
) Error!Register {
    if (first != second) if (floatLaneResidence(function, first)) |left| if (floatLaneResidence(function, second)) |right| {
        if (left.register == right.register and left.lane == 0 and right.lane == 1) return @enumFromInt(left.register);
    };
    try loadFloatValue(allocator, words, function, destination, first, false);
    if (first == second) {
        try words.append(allocator, A64.duplicateFloat32Lane(destination, destination, 0));
        return destination;
    }
    try loadFloatValue(allocator, words, function, scratch, second, false);
    try words.append(allocator, A64.insertSecondFloat32(destination, scratch));
    return destination;
}

fn definingBinary(instructions: []const Machine.Instruction, slot: Machine.Slot) ?Machine.Instruction.Binary {
    for (instructions) |instruction| switch (instruction) {
        .binary => |binary| if (binary.result == slot) return binary,
        else => {},
    };
    return null;
}

fn definingCopy(instructions: []const Machine.Instruction, slot: Machine.Slot) ?Machine.Instruction.Copy {
    for (instructions) |instruction| switch (instruction) {
        .copy => |copy| if (copy.result == slot) return copy,
        else => {},
    };
    return null;
}

fn definingTransferOperandBefore(
    instructions: []const Machine.Instruction,
    before: usize,
    slot: Machine.Slot,
) ?Machine.Slot {
    var index = before;
    while (index != 0) {
        index -= 1;
        switch (instructions[index]) {
            .copy => |copy| if (copy.result == slot) return copy.operand,
            .copy_range => |copy| if (spanContainsSlot(copy.result, slot)) {
                return copy.operand.start + slot - copy.result.start;
            },
            .jump, .branch, .return_value, .return_void => return null,
            else => {},
        }
    }
    return null;
}

fn definingTransferOperandAfter(
    instructions: []const Machine.Instruction,
    after: usize,
    slot: Machine.Slot,
) ?Machine.Slot {
    for (instructions[after + 1 ..]) |instruction| switch (instruction) {
        .copy => |copy| if (copy.result == slot) return copy.operand,
        .copy_range => |copy| if (spanContainsSlot(copy.result, slot)) {
            return copy.operand.start + slot - copy.result.start;
        },
        .jump, .branch, .return_value, .return_void => return null,
        else => {},
    };
    return null;
}

fn encodeFloatMultiplyAdd(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    add: Machine.Instruction.Binary,
    multiply_value: Machine.Instruction.Binary,
) Error!void {
    const double = add.type == .float64;
    const left = try prepareFloatOperand(allocator, words, function, .x9, multiply_value.left, double);
    const right = try prepareFloatOperand(allocator, words, function, .x10, multiply_value.right, double);
    const accumulator_slot = if (add.left == multiply_value.result) add.right else add.left;
    const accumulator = try prepareFloatOperand(allocator, words, function, .x11, accumulator_slot, double);
    const destination = floatResultRegister(function, add.result) orelse .x12;
    try words.append(allocator, floatMultiplyAdd(destination, left, right, accumulator, double));
    if (floatResultRegister(function, add.result) == null) {
        try storeFloatValue(allocator, words, function, destination, add.result, double);
    }
}

fn multiplyFeedsNextAdd(
    function: Machine.Function,
    index: usize,
    binary: Machine.Instruction.Binary,
) bool {
    if (!binary.type.isFloat() or binary.operator != .multiply or index + 1 >= function.instructions.len) return false;
    const add = switch (function.instructions[index + 1]) {
        .binary => |value| value,
        else => return false,
    };
    if (add.type != binary.type or add.operator != .add or
        (add.left != binary.result and add.right != binary.result)) return false;
    if (!slotUsedOnlyAt(function.instructions, binary.result, index + 1)) return false;
    return !controlTargetsInstruction(function.instructions, index + 1);
}

fn fusedMultiplyForAdd(function: Machine.Function, index: usize) ?Machine.Instruction.Binary {
    if (index == 0) return null;
    const multiply_value = switch (function.instructions[index - 1]) {
        .binary => |value| value,
        else => return null,
    };
    return if (multiplyFeedsNextAdd(function, index - 1, multiply_value)) multiply_value else null;
}

fn controlTargetsInstruction(instructions: []const Machine.Instruction, target: usize) bool {
    for (instructions) |instruction| switch (instruction) {
        .jump => |value| if (value == target) return true,
        .branch => |value| if (value.then_instruction == target or value.else_instruction == target) return true,
        else => {},
    };
    return false;
}

fn prepareFloatOperand(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: ?Machine.Function,
    fallback: Register,
    slot: Machine.Slot,
    double: bool,
) Allocator.Error!Register {
    if (function) |value| if (floatResultRegister(value, slot)) |register| return register;
    try loadOptionalFloatValue(allocator, words, function, fallback, slot, double);
    return fallback;
}

fn floatResultRegister(function: ?Machine.Function, slot: Machine.Slot) ?Register {
    if (function) |value| if (floatResidence(value, slot)) |number| return @enumFromInt(number);
    return null;
}

fn inverseFloatComparison(operator: Machine.BinaryOperator) Condition {
    return switch (operator) {
        .less => .plus,
        .less_equal => .higher,
        .greater => .less_equal,
        .greater_equal => .less,
        .equal => .not_equal,
        .not_equal => .equal,
        else => unreachable,
    };
}

fn invertCondition(condition: Condition) Condition {
    return @enumFromInt(@intFromEnum(condition) ^ 1);
}

fn encodeConversion(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *FunctionFixups,
    data_fixups: *std.ArrayList(DataFixup),
    program: Machine.Program,
    function: Machine.Function,
    conversion: Machine.Instruction.Convert,
) Error!void {
    if (conversion.source.isInteger() and conversion.target.isFloat()) {
        const operand = try prepareValueOperand(allocator, words, function, .x9, conversion.operand);
        const double = conversion.target == .float64;
        const result = floatResultRegister(function, conversion.result) orelse .x10;
        try words.append(allocator, integerToFloat(result, operand, conversion.source.isSignedInteger(), double));
        if (conversion.checked) {
            try words.append(allocator, floatToInteger(.x11, result, conversion.source.isSignedInteger(), double));
            try words.append(allocator, compareRegisters(operand, .x11));
            try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .equal);
        }
        if (floatResultRegister(function, conversion.result) == null) {
            try storeFloatValue(allocator, words, function, result, conversion.result, double);
        }
        return;
    }
    const source_is_float = conversion.source.isFloat();
    if (source_is_float) {
        try loadFloatValue(allocator, words, function, .x9, conversion.operand, conversion.source == .float64);
    } else {
        try loadValue(allocator, words, function, .x9, conversion.operand);
    }
    if (conversion.source.isFloat() and conversion.target.isInteger()) {
        const double = conversion.source == .float64;
        const result = valueResultRegister(function, conversion.result) orelse .x10;
        try emitFloatToIntegerRangeGuards(
            allocator,
            words,
            fixups,
            data_fixups,
            program,
            conversion,
            double,
        );
        try words.append(allocator, floatToInteger(result, .x9, conversion.target.isSignedInteger(), double));
        try words.append(allocator, integerToFloat(.x11, result, conversion.target.isSignedInteger(), double));
        try words.append(allocator, floatCompare(.x9, .x11, double));
        try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .equal);
        try emitConvertedIntegerRangeChecks(
            allocator,
            words,
            fixups,
            data_fixups,
            program,
            conversion,
            result,
        );
        if (valueResultRegister(function, conversion.result) == null) {
            try storeValue(allocator, words, function, result, conversion.result);
        }
        return;
    }
    if (conversion.source.isFloat() and conversion.target.isFloat()) {
        const source_double = conversion.source == .float64;
        const target_double = conversion.target == .float64;
        const result = floatResultRegister(function, conversion.result) orelse .x10;
        try words.append(allocator, floatConvert(result, .x9, target_double));
        if (conversion.checked and source_double and !target_double) {
            try words.append(allocator, floatConvert(.x11, result, true));
            try words.append(allocator, floatCompare(.x9, .x11, true));
            try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .equal);
        }
        if (floatResultRegister(function, conversion.result) == null) {
            try storeFloatValue(allocator, words, function, result, conversion.result, target_double);
        }
        return;
    }
    if (!conversion.source.isInteger() or !conversion.target.isInteger()) return error.UnsupportedType;
    if (conversion.checked) {
        if (conversion.target.isSignedInteger()) {
            if (conversion.source.isSignedInteger()) {
                try emitImmediate64(allocator, words, .x10, @bitCast(Numeric.integerMin(conversion.target)));
                try words.append(allocator, compareRegisters(.x9, .x10));
                try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .greater_equal);
            }
            try emitImmediate64(allocator, words, .x10, Numeric.integerMax(conversion.target));
            try words.append(allocator, compareRegisters(.x9, .x10));
            try emitConversionGuard(
                allocator,
                words,
                fixups,
                data_fixups,
                program,
                conversion.header,
                if (conversion.source.isSignedInteger()) .less_equal else .lower_or_same,
            );
        } else {
            if (conversion.source.isSignedInteger()) {
                try words.append(allocator, compareRegisters(.x9, .zero_or_sp));
                try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .greater_equal);
            }
            try emitImmediate64(allocator, words, .x10, Numeric.integerMax(conversion.target));
            try words.append(allocator, compareRegisters(.x9, .x10));
            try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .lower_or_same);
        }
    }
    if (conversion.target.isSignedInteger() and conversion.target.bitWidth() < 64) {
        try words.append(allocator, signExtendRegister(.x9, .x9, conversion.target.bitWidth()));
    } else if (!conversion.target.isSignedInteger() and conversion.target.bitWidth() < 64) {
        try emitImmediate64(allocator, words, .x10, Numeric.mask(conversion.target.bitWidth()));
        try words.append(allocator, andRegisters(.x9, .x9, .x10));
    }
    try storeValue(allocator, words, function, .x9, conversion.result);
}

fn emitFloatToIntegerRangeGuards(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *FunctionFixups,
    data_fixups: *std.ArrayList(DataFixup),
    program: Machine.Program,
    conversion: Machine.Instruction.Convert,
    double: bool,
) Error!void {
    const lower: f64 = if (conversion.target.isSignedInteger())
        @floatFromInt(Numeric.integerMin(conversion.target))
    else
        0.0;
    const upper: f64 = if (conversion.target.isSignedInteger())
        @floatFromInt(@as(i128, Numeric.integerMax(conversion.target)) + 1)
    else
        @floatFromInt(@as(u128, Numeric.integerMax(conversion.target)) + 1);
    try emitImmediate64(allocator, words, .x12, floatBits(lower, double));
    try words.append(allocator, moveGeneralToFloat(.x12, .x12, double));
    try words.append(allocator, floatCompare(.x9, .x12, double));
    try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .greater_equal);
    try emitImmediate64(allocator, words, .x12, floatBits(upper, double));
    try words.append(allocator, moveGeneralToFloat(.x12, .x12, double));
    try words.append(allocator, floatCompare(.x9, .x12, double));
    try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .minus);
}

fn floatBits(value: f64, double: bool) u64 {
    return if (double) @bitCast(value) else @as(u32, @bitCast(@as(f32, @floatCast(value))));
}

fn emitConvertedIntegerRangeChecks(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *FunctionFixups,
    data_fixups: *std.ArrayList(DataFixup),
    program: Machine.Program,
    conversion: Machine.Instruction.Convert,
    register: Register,
) Error!void {
    if (conversion.target.isSignedInteger()) {
        try emitImmediate64(allocator, words, .x12, @bitCast(Numeric.integerMin(conversion.target)));
        try words.append(allocator, compareRegisters(register, .x12));
        try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .greater_equal);
        try emitImmediate64(allocator, words, .x12, Numeric.integerMax(conversion.target));
        try words.append(allocator, compareRegisters(register, .x12));
        try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .less_equal);
    } else if (conversion.target.bitWidth() < 64) {
        try emitImmediate64(allocator, words, .x12, Numeric.integerMax(conversion.target));
        try words.append(allocator, compareRegisters(register, .x12));
        try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .lower_or_same);
    }
}

fn emitConversionGuard(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *FunctionFixups,
    data_fixups: *std.ArrayList(DataFixup),
    program: Machine.Program,
    header: usize,
    valid: Condition,
) Error!void {
    const passed = words.items.len;
    try words.append(allocator, conditionalBranch(valid));
    try emitWriteStatic(allocator, words, data_fixups, program, header, 2);
    try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.runtime_failure)));
    try appendFixup(allocator, words, &fixups.epilogue, branch(), .imm26);
    try patch19(words.items, passed, words.items.len);
}

fn emitIntegerRangeCheck(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *FunctionFixups,
    type_value: @import("../Types.zig").Type,
    register: Register,
) Error!void {
    if (type_value.bitWidth() == 64) return;
    if (type_value.isSignedInteger()) {
        try emitImmediate64(allocator, words, .x12, @bitCast(Numeric.integerMin(type_value)));
        try words.append(allocator, compareRegisters(register, .x12));
        try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.less), .imm19);
        try emitImmediate64(allocator, words, .x12, Numeric.integerMax(type_value));
        try words.append(allocator, compareRegisters(register, .x12));
        try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.greater), .imm19);
    } else {
        try emitImmediate64(allocator, words, .x12, Numeric.integerMax(type_value));
        try words.append(allocator, compareRegisters(register, .x12));
        try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.higher), .imm19);
    }
}

fn inverseComparison(operator: Machine.BinaryOperator, signed: bool) Condition {
    return switch (operator) {
        .less => if (signed) .greater_equal else .carry_set,
        .less_equal => if (signed) .greater else .higher,
        .greater => if (signed) .less_equal else .lower_or_same,
        .greater_equal => if (signed) .less else .carry_clear,
        .equal => .not_equal,
        .not_equal => .equal,
        else => unreachable,
    };
}

fn emitPrintBoolean(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(DataFixup),
    program: Machine.Program,
    slot: Machine.Slot,
    newline: bool,
) Error!void {
    try words.append(allocator, loadStack(.x9, slot));
    const use_false = words.items.len;
    try words.append(allocator, compareBranchZero(.x9));
    try emitWriteStatic(allocator, words, data_fixups, program, 1, 1);
    const finished = words.items.len;
    try words.append(allocator, branch());
    try patch19(words.items, use_false, words.items.len);
    try emitWriteStatic(allocator, words, data_fixups, program, 2, 1);
    try patch26(words.items, finished, words.items.len);
    if (newline) try emitWriteStatic(allocator, words, data_fixups, program, 0, 1);
}

fn emitWriteStatic(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(DataFixup),
    program: Machine.Program,
    string_id: usize,
    descriptor: u16,
) Error!void {
    try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, string_id, descriptor);
}

fn emitPrintFloat(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    float_calls: *std.ArrayList(usize),
    data_fixups: *std.ArrayList(DataFixup),
    program: Machine.Program,
    slot: Machine.Slot,
    double: bool,
    newline: bool,
) Error!void {
    const buffer_size = 352;
    try words.append(allocator, loadStack(.x0, slot));
    try words.append(allocator, addSubtractImmediate(.zero_or_sp, .zero_or_sp, buffer_size, false));
    try words.append(allocator, addSubtractImmediate(.x1, .zero_or_sp, 0, true));
    try words.append(allocator, moveWideZero32(.x2, @intFromBool(double)));
    try float_calls.append(allocator, words.items.len);
    try words.append(allocator, branchLink());
    try words.append(allocator, moveRegister(.x2, .x0));
    try words.append(allocator, moveWideZero32(.x0, 1));
    try words.append(allocator, addSubtractImmediate(.x1, .zero_or_sp, 0, true));
    try words.append(allocator, moveWideZero32(.x16, 4));
    try words.append(allocator, serviceCall());
    try words.append(allocator, addSubtractImmediate(.zero_or_sp, .zero_or_sp, buffer_size, true));
    if (newline) try emitWriteStatic(allocator, words, data_fixups, program, 0, 1);
}

fn emitPrintInteger(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    slot: Machine.Slot,
    descriptor: u16,
    newline: bool,
) Error!void {
    try words.append(allocator, loadStack(.x9, slot));
    try words.append(allocator, addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, false));
    try words.append(allocator, addSubtractImmediate(.x11, .zero_or_sp, if (newline) 31 else 32, true));
    if (newline) {
        try words.append(allocator, moveWideZero32(.x10, '\n'));
        try words.append(allocator, storeByte(.x10, .x11));
    }
    try words.append(allocator, moveWideZero32(.x12, @intFromBool(newline)));

    const nonzero = words.items.len;
    try words.append(allocator, compareBranchNonZero64(.x9));
    try words.append(allocator, addSubtractImmediate(.x11, .x11, 1, false));
    try words.append(allocator, moveWideZero32(.x10, '0'));
    try words.append(allocator, storeByte(.x10, .x11));
    try words.append(allocator, addSubtractImmediate(.x12, .x12, 1, true));
    const zero_finished = words.items.len;
    try words.append(allocator, branch());

    try patch19(words.items, nonzero, words.items.len);
    try words.append(allocator, moveWideZero32(.x3, 0));
    try words.append(allocator, compareRegisters(.x9, .zero_or_sp));
    const already_negative = words.items.len;
    try words.append(allocator, conditionalBranch(.less));
    try words.append(allocator, subtractSetFlags(.x9, .zero_or_sp, .x9));
    const sign_ready = words.items.len;
    try words.append(allocator, branch());
    try patch19(words.items, already_negative, words.items.len);
    try words.append(allocator, moveWideZero32(.x3, 1));
    try patch26(words.items, sign_ready, words.items.len);

    const digit_loop = words.items.len;
    try words.append(allocator, moveWideZero32(.x10, 10));
    try words.append(allocator, signedDivide(.x4, .x9, .x10));
    try words.append(allocator, multiplySubtract(.x5, .x4, .x10, .x9));
    try words.append(allocator, moveWideZero32(.x6, '0'));
    try words.append(allocator, subtractSetFlags(.x6, .x6, .x5));
    try words.append(allocator, addSubtractImmediate(.x11, .x11, 1, false));
    try words.append(allocator, storeByte(.x6, .x11));
    try words.append(allocator, addSubtractImmediate(.x12, .x12, 1, true));
    try words.append(allocator, moveRegister(.x9, .x4));
    const repeat = words.items.len;
    try words.append(allocator, compareBranchNonZero64(.x9));
    try patch19(words.items, repeat, digit_loop);

    const unsigned = words.items.len;
    try words.append(allocator, compareBranchZero(.x3));
    try words.append(allocator, addSubtractImmediate(.x11, .x11, 1, false));
    try words.append(allocator, moveWideZero32(.x10, '-'));
    try words.append(allocator, storeByte(.x10, .x11));
    try words.append(allocator, addSubtractImmediate(.x12, .x12, 1, true));
    try patch19(words.items, unsigned, words.items.len);

    try patch26(words.items, zero_finished, words.items.len);
    try words.append(allocator, moveWideZero32(.x0, descriptor));
    try words.append(allocator, moveRegister(.x1, .x11));
    try words.append(allocator, moveRegister(.x2, .x12));
    try words.append(allocator, moveWideZero32(.x16, 4));
    try words.append(allocator, serviceCall());
    try words.append(allocator, addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, true));
}

fn emitPrintUnsigned(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    slot: Machine.Slot,
    newline: bool,
) Error!void {
    try words.append(allocator, loadStack(.x9, slot));
    try words.append(allocator, addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, false));
    try words.append(allocator, addSubtractImmediate(.x11, .zero_or_sp, if (newline) 31 else 32, true));
    if (newline) {
        try words.append(allocator, moveWideZero32(.x10, '\n'));
        try words.append(allocator, storeByte(.x10, .x11));
    }
    try words.append(allocator, moveWideZero32(.x12, @intFromBool(newline)));

    const nonzero = words.items.len;
    try words.append(allocator, compareBranchNonZero64(.x9));
    try words.append(allocator, addSubtractImmediate(.x11, .x11, 1, false));
    try words.append(allocator, moveWideZero32(.x10, '0'));
    try words.append(allocator, storeByte(.x10, .x11));
    try words.append(allocator, addSubtractImmediate(.x12, .x12, 1, true));
    const zero_finished = words.items.len;
    try words.append(allocator, branch());

    try patch19(words.items, nonzero, words.items.len);
    const digit_loop = words.items.len;
    try words.append(allocator, moveWideZero32(.x10, 10));
    try words.append(allocator, unsignedDivide(.x4, .x9, .x10));
    try words.append(allocator, multiplySubtract(.x5, .x4, .x10, .x9));
    try words.append(allocator, addSubtractImmediate(.x6, .x5, '0', true));
    try words.append(allocator, addSubtractImmediate(.x11, .x11, 1, false));
    try words.append(allocator, storeByte(.x6, .x11));
    try words.append(allocator, addSubtractImmediate(.x12, .x12, 1, true));
    try words.append(allocator, moveRegister(.x9, .x4));
    const repeat = words.items.len;
    try words.append(allocator, compareBranchNonZero64(.x9));
    try patch19(words.items, repeat, digit_loop);

    try patch26(words.items, zero_finished, words.items.len);
    try words.append(allocator, moveWideZero32(.x0, 1));
    try words.append(allocator, moveRegister(.x1, .x11));
    try words.append(allocator, moveRegister(.x2, .x12));
    try words.append(allocator, moveWideZero32(.x16, 4));
    try words.append(allocator, serviceCall());
    try words.append(allocator, addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, true));
}

fn emitImmediate64(allocator: Allocator, words: *std.ArrayList(u32), register: Register, value: u64) Allocator.Error!void {
    var first_shift: u2 = 0;
    while (first_shift < 3 and @as(u16, @truncate(value >> (@as(u6, first_shift) * 16))) == 0) {
        first_shift += 1;
    }
    try words.append(allocator, moveWideZero64(
        register,
        @truncate(value >> (@as(u6, first_shift) * 16)),
        first_shift,
    ));
    for (0..4) |shift_value| {
        const shift: u2 = @intCast(shift_value);
        if (shift == first_shift) continue;
        const part: u16 = @truncate(value >> (@as(u6, shift) * 16));
        if (part != 0) try words.append(allocator, moveWideKeep64(register, part, shift));
    }
}

const ScalarCache = struct {
    enabled: bool,
    slots: [2]?Machine.Slot = .{ null, null },
    next: usize = 0,

    fn clear(self: *ScalarCache) void {
        self.slots = .{ null, null };
        self.next = 0;
    }
};

fn scalarCacheInstruction(instruction: Machine.Instruction) bool {
    return switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_float32,
        .constant_float64,
        .copy,
        .unary,
        => true,
        .binary => |binary| binary.type != .str,
        else => false,
    };
}

fn loadCachedValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    cache: *ScalarCache,
    destination: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    return loadCachedOptionalValue(allocator, words, function, cache, destination, slot);
}

fn loadCachedOptionalValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: ?Machine.Function,
    cache: *ScalarCache,
    destination: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    if (cache.enabled) for (cache.slots, [_]Register{ .x16, .x17 }) |cached, register| {
        if (cached != null and cached.? == slot) {
            if (register != destination) try words.append(allocator, moveRegister(destination, register));
            return;
        }
    };
    return loadOptionalValue(allocator, words, function, destination, slot);
}

fn storeCachedValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    cache: *ScalarCache,
    source: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    return storeCachedOptionalValue(allocator, words, function, cache, source, slot);
}

fn storeCachedOptionalValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: ?Machine.Function,
    cache: *ScalarCache,
    source: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    try storeOptionalValue(allocator, words, function, source, slot);
    if (!cache.enabled) return;

    const registers = [_]Register{ .x16, .x17 };
    for (cache.slots, registers, 0..) |cached, register, index| {
        if (cached != null and cached.? == slot) {
            if (source != register) try words.append(allocator, moveRegister(register, source));
            cache.next = (index + 1) % cache.slots.len;
            return;
        }
    }

    const register = registers[cache.next];
    if (source != register) try words.append(allocator, moveRegister(register, source));
    cache.slots[cache.next] = slot;
    cache.next = (cache.next + 1) % cache.slots.len;
}

fn loadValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    destination: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    return loadOptionalValue(allocator, words, function, destination, slot);
}

fn emitRegisteredCopy(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    result: Machine.Slot,
    operand: Machine.Slot,
) Allocator.Error!void {
    if (floatResidence(function, operand) != null or floatResidence(function, result) != null or
        floatLaneResidence(function, operand) != null or floatLaneResidence(function, result) != null)
    {
        try emitScalarFloatCopy(allocator, words, function, result, operand);
        return;
    }
    const source = valueResultRegister(function, operand);
    const destination = valueResultRegister(function, result);
    if (source != null and destination != null) {
        if (source.? != destination.?) try words.append(allocator, moveRegister(destination.?, source.?));
        return;
    }
    try loadValue(allocator, words, function, .x9, operand);
    try storeValue(allocator, words, function, .x9, result);
}

fn emitScalarFloatCopy(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    result: Machine.Slot,
    operand: Machine.Slot,
) Allocator.Error!void {
    if (floatResultRegister(function, result)) |destination| {
        try loadFloatValue(allocator, words, function, destination, operand, true);
        return;
    }
    if (floatResultRegister(function, operand)) |source| {
        try storeFloatValue(allocator, words, function, source, result, true);
        return;
    }
    try loadFloatValue(allocator, words, function, .x9, operand, true);
    try storeFloatValue(allocator, words, function, .x9, result, true);
}

fn valueResultRegister(function: Machine.Function, slot: Machine.Slot) ?Register {
    return valueOptionalResultRegister(function, slot);
}

fn floatImmediateEncoding(bits: u64, double: bool) ?u8 {
    const exponent_bits: u6 = if (double) 11 else 8;
    const fraction_bits: u6 = if (double) 52 else 23;
    const width: u7 = if (double) 64 else 32;
    for (0..256) |candidate| {
        const immediate: u8 = @intCast(candidate);
        const repeated: u64 = if (immediate & 0x40 != 0)
            ((@as(u64, 1) << (exponent_bits - 3)) - 1) << 2
        else
            0;
        const exponent = (@as(u64, @intFromBool(immediate & 0x40 == 0)) << (exponent_bits - 1)) |
            repeated | ((immediate >> 4) & 0x3);
        const expanded = (@as(u64, immediate >> 7) << @as(u6, @intCast(width - 1))) |
            (exponent << fraction_bits) |
            (@as(u64, immediate & 0xf) << (fraction_bits - 4));
        if (expanded == bits) return immediate;
    }
    return null;
}

test "recognize only architectural scalar floating-point immediates" {
    try std.testing.expectEqual(@as(?u8, 0x70), floatImmediateEncoding(@as(u32, @bitCast(@as(f32, 1.0))), false));
    try std.testing.expectEqual(@as(?u8, 0xe0), floatImmediateEncoding(@as(u64, @bitCast(@as(f64, -0.5))), true));
    try std.testing.expectEqual(@as(?u8, null), floatImmediateEncoding(@as(u32, @bitCast(@as(f32, 1.0 / 240.0))), false));
    try std.testing.expectEqual(@as(?u8, null), floatImmediateEncoding(0, true));
}

fn valueOptionalResultRegister(function: ?Machine.Function, slot: Machine.Slot) ?Register {
    if (function) |value| if (value.register_slots.len != 0) if (value.register_slots[slot]) |number| {
        return @enumFromInt(number);
    };
    return null;
}

fn prepareValueOperand(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    fallback: Register,
    slot: Machine.Slot,
) Allocator.Error!Register {
    return prepareOptionalValueOperand(allocator, words, function, fallback, slot);
}

fn prepareOptionalValueOperand(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: ?Machine.Function,
    fallback: Register,
    slot: Machine.Slot,
) Allocator.Error!Register {
    if (valueOptionalResultRegister(function, slot)) |register| return register;
    try loadOptionalValue(allocator, words, function, fallback, slot);
    return fallback;
}

fn finishValueResult(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: ?Machine.Function,
    scalar_cache: *ScalarCache,
    source: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    if (valueOptionalResultRegister(function, slot) != null) return;
    try storeCachedOptionalValue(allocator, words, function, scalar_cache, source, slot);
}

fn floatResidence(function: Machine.Function, slot: Machine.Slot) ?u5 {
    if (function.float_register_slots.len == 0) return null;
    return function.float_register_slots[slot];
}

fn floatLaneResidence(function: Machine.Function, slot: Machine.Slot) ?Machine.FloatLaneResidence {
    if (function.float_lane_slots.len == 0) return null;
    return function.float_lane_slots[slot];
}

fn floatPairLeader(function: Machine.Function, slot: Machine.Slot) ?Machine.FloatLaneResidence {
    const residence = floatLaneResidence(function, slot) orelse return null;
    return if (residence.lane == 0) residence else null;
}

fn floatPairFollower(function: Machine.Function, slot: Machine.Slot) bool {
    const residence = floatLaneResidence(function, slot) orelse return false;
    return residence.lane == 1;
}

fn pairedPartner(function: Machine.Function, slot: Machine.Slot) ?Machine.Slot {
    const residence = floatLaneResidence(function, slot) orelse return null;
    return residence.partner;
}

fn loadFloatValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    destination: Register,
    slot: Machine.Slot,
    double: bool,
) Allocator.Error!void {
    return loadOptionalFloatValue(allocator, words, function, destination, slot, double);
}

fn loadOptionalFloatValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: ?Machine.Function,
    destination: Register,
    slot: Machine.Slot,
    double: bool,
) Allocator.Error!void {
    if (function) |value| if (floatLaneResidence(value, slot)) |residence| {
        const source: Register = @enumFromInt(residence.register);
        if (residence.lane == 0) {
            if (source != destination) try words.append(allocator, moveFloat(destination, source, false));
        } else try words.append(allocator, A64.duplicateFloat32Lane(destination, source, 1));
        return;
    };
    if (function) |value| if (floatResidence(value, slot)) |number| {
        const source: Register = @enumFromInt(number);
        if (source != destination) try words.append(allocator, moveFloat(destination, source, double));
        return;
    };
    if (double) {
        try words.append(allocator, A64.loadFloat64Stack(destination, slot));
        return;
    }
    const byte_offset = @as(usize, slot) * Machine.slot_size;
    if (byte_offset <= std.math.maxInt(u12)) {
        try words.append(allocator, A64.loadFloat32(destination, .zero_or_sp, @intCast(byte_offset)));
        return;
    }
    try words.append(allocator, loadStack(.x14, slot));
    try words.append(allocator, moveGeneralToFloat(destination, .x14, double));
}

fn storeFloatValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    source: Register,
    slot: Machine.Slot,
    double: bool,
) Allocator.Error!void {
    return storeOptionalFloatValue(allocator, words, function, source, slot, double);
}

fn storeOptionalFloatValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: ?Machine.Function,
    source: Register,
    slot: Machine.Slot,
    double: bool,
) Allocator.Error!void {
    if (function) |value| if (floatLaneResidence(value, slot)) |residence| {
        try words.append(allocator, A64.insertFloat32Lane(@enumFromInt(residence.register), source, residence.lane));
        return;
    };
    if (function) |value| if (floatResidence(value, slot)) |number| {
        const destination: Register = @enumFromInt(number);
        if (source != destination) try words.append(allocator, moveFloat(destination, source, double));
        return;
    };
    if (double) {
        try words.append(allocator, A64.storeFloat64Stack(source, slot));
        return;
    }
    const byte_offset = @as(usize, slot) * Machine.slot_size;
    if (byte_offset <= std.math.maxInt(u12)) {
        try words.append(allocator, A64.storeFloat32(source, .zero_or_sp, @intCast(byte_offset)));
        return;
    }
    try words.append(allocator, moveFloatToGeneral(.x14, source, double));
    try words.append(allocator, storeStack(.x14, slot));
}

fn loadOptionalValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: ?Machine.Function,
    destination: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    if (function) |value| if (value.register_slots.len != 0) {
        if (value.register_slots[slot]) |number| {
            const source: Register = @enumFromInt(number);
            if (source != destination) try words.append(allocator, moveRegister(destination, source));
            return;
        }
    };
    try words.append(allocator, loadStack(destination, slot));
}

fn storeValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    source: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    return storeOptionalValue(allocator, words, function, source, slot);
}

fn storeOptionalValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: ?Machine.Function,
    source: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    if (function) |value| if (value.register_slots.len != 0) if (value.register_slots[slot]) |number| {
        const destination: Register = @enumFromInt(number);
        if (source != destination) try words.append(allocator, moveRegister(destination, source));
        return;
    };
    try words.append(allocator, storeStack(source, slot));
}

fn emitStackAdjustment(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    frame_size: u32,
    add: bool,
) Allocator.Error!void {
    var remaining = frame_size;
    while (remaining != 0) {
        const amount: u32 = @min(remaining, 4080);
        try words.append(allocator, addSubtractImmediate(.zero_or_sp, .zero_or_sp, @intCast(amount), add));
        remaining -= amount;
    }
}

fn emitRegisterAdjustment(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    register: Register,
    byte_count: usize,
    add: bool,
) Allocator.Error!void {
    var remaining = byte_count;
    while (remaining != 0) {
        const amount: u16 = @min(remaining, 4080);
        try words.append(allocator, addSubtractImmediate(register, register, @intCast(amount), add));
        remaining -= amount;
    }
}

fn emitBaseAddress(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    destination: Register,
    base: Register,
    byte_offset: usize,
) Allocator.Error!void {
    if (destination != base) {
        if (base == .zero_or_sp) {
            try words.append(allocator, addSubtractImmediate(destination, base, 0, true));
        } else try words.append(allocator, moveRegister(destination, base));
    }
    try emitRegisterAdjustment(allocator, words, destination, byte_offset, true);
}

fn appendFixup(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *std.ArrayList(LocalFixup),
    instruction: u32,
    width: FixupWidth,
) Allocator.Error!void {
    switch (width) {
        .imm19 => {
            try fixups.append(allocator, .{ .at = words.items.len, .width = .imm19 });
            try words.append(allocator, instruction);
        },
        .imm26 => {
            try fixups.append(allocator, .{ .at = words.items.len, .width = .imm26 });
            try words.append(allocator, instruction);
        },
    }
}

fn patchLocal(words: []u32, fixup: LocalFixup, target: usize) Error!void {
    return switch (fixup.width) {
        .imm19 => patch19(words, fixup.at, target),
        .imm26 => patch26(words, fixup.at, target),
    };
}

fn patch19(words: []u32, at: usize, target: usize) Error!void {
    const delta: i64 = @as(i64, @intCast(target)) - @as(i64, @intCast(at));
    if (delta < -(1 << 18) or delta >= (1 << 18)) return error.BranchOutOfRange;
    const immediate: u32 = @bitCast(@as(i32, @intCast(delta)));
    words[at] |= (immediate & 0x7ffff) << 5;
}

fn patch26(words: []u32, at: usize, target: usize) Error!void {
    const delta: i64 = @as(i64, @intCast(target)) - @as(i64, @intCast(at));
    if (delta < -(1 << 25) or delta >= (1 << 25)) return error.BranchOutOfRange;
    const immediate: u32 = @bitCast(@as(i32, @intCast(delta)));
    words[at] |= immediate & 0x03ffffff;
}

fn patchAdr(words: []u32, at: usize, target_byte: usize) Error!void {
    const instruction_byte = at * 4;
    const delta = @as(i64, @intCast(target_byte)) - @as(i64, @intCast(instruction_byte));
    if (delta < -(1 << 20) or delta >= (1 << 20)) return error.BranchOutOfRange;
    const immediate: u32 = @bitCast(@as(i32, @intCast(delta)));
    words[at] |= ((immediate & 0x3) << 29) | (((immediate >> 2) & 0x7ffff) << 5);
}

fn appendRelocatableAddress(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    register: Register,
) Allocator.Error!void {
    try words.append(allocator, A64.addressPage(register));
    try words.append(allocator, A64.addSubtractImmediate(register, register, 0, true));
}

fn patchPageAddress(words: []u32, at: usize, target_byte: usize) Error!void {
    if (at + 1 >= words.len) return error.InvalidMachineProgram;
    const instruction_page = (at * @sizeOf(u32)) & ~@as(usize, 0xfff);
    const target_page = target_byte & ~@as(usize, 0xfff);
    const delta = @as(i64, @intCast(target_page)) - @as(i64, @intCast(instruction_page));
    const pages = @divExact(delta, 0x1000);
    if (pages < -(1 << 20) or pages >= (1 << 20)) return error.BranchOutOfRange;
    const immediate: u21 = @bitCast(@as(i21, @intCast(pages)));
    words[at] |= (@as(u32, immediate & 0x3) << 29) | (@as(u32, immediate >> 2) << 5);
    words[at + 1] |= @as(u32, @intCast(target_byte & 0xfff)) << 10;
}

test "encode known AArch64 instruction words" {
    try std.testing.expectEqual(@as(u32, 0xa9bf7bfd), saveFrame());
    try std.testing.expectEqual(@as(u32, 0x910003fd), moveFramePointer());
    try std.testing.expectEqual(@as(u32, 0xd2800540), moveWideZero64(.x0, 42, 0));
    try std.testing.expectEqual(@as(u32, 0xf90003e9), storeStack(.x9, 0));
    try std.testing.expectEqual(@as(u32, 0xf94003e9), loadStack(.x9, 0));
    try std.testing.expectEqual(
        A64.store64(.x9, .x28, 0),
        storeStack(.x9, Machine.direct_stack_slots),
    );
    try std.testing.expectEqual(
        A64.load64(.x9, .x28, 0),
        loadStack(.x9, Machine.direct_stack_slots),
    );
    try std.testing.expectEqual(@as(u32, 0xc85ffdc9), A64.loadAcquireExclusive64(.x9, .x14));
    try std.testing.expectEqual(@as(u32, 0xc80afdc9), A64.storeReleaseExclusive64(.x10, .x9, .x14));
    try std.testing.expectEqual(@as(u32, 0xc89ffddf), A64.storeRelease64(.zero_or_sp, .x14));
    try std.testing.expectEqual(@as(u32, 0xd65f03c0), returnInstruction());
}

test "runtime padding reaches a page offset after an unaligned payload" {
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.testing.allocator);
    try bytes.appendSlice(std.testing.allocator, "odd");

    try appendRuntimePadding(std.testing.allocator, 0, &bytes, 0);

    try std.testing.expectEqual(@as(usize, 4096), bytes.items.len);
    try std.testing.expectEqual(@as(usize, 0), bytes.items.len % 4096);
}

test "form large stack addresses from sp" {
    var words: std.ArrayList(u32) = .empty;
    defer words.deinit(std.testing.allocator);

    try emitStackAddress(std.testing.allocator, &words, .x10, 512);

    try std.testing.expect(words.items.len >= 2);
    try std.testing.expectEqual(
        addSubtractImmediate(.x10, .zero_or_sp, 0, true),
        words.items[words.items.len - 2],
    );
    try std.testing.expectEqual(
        addRegisters(.x10, .x10, .x14),
        words.items[words.items.len - 1],
    );
}

test "form function addresses beyond the ADR range" {
    var words = [_]u32{
        A64.addressPage(.x9),
        A64.addSubtractImmediate(.x9, .x9, 0, true),
    };

    try patchPageAddress(&words, 0, 2 * 1024 * 1024);

    try std.testing.expect(words[0] != A64.addressPage(.x9));
    try std.testing.expectEqual(
        A64.addSubtractImmediate(.x9, .x9, 0, true),
        words[1],
    );
}

test "resolve calls and append a native test entry" {
    const answer_instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 42 } },
        .{ .return_value = .{ .start = 0, .width = 1 } },
    };
    const functions = [_]Machine.Function{.{
        .name = "answer",
        .parameter_count = 0,
        .return_type = .int,
        .return_width = 1,
        .slot_count = 1,
        .frame_size = try Machine.frameSize(1),
        .instructions = &answer_instructions,
    }};
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const image = try encode(arena.allocator(), .{ .functions = &functions }, .{ .test_function = 0 });
    try std.testing.expectEqual(@as(u32, 0), image.function_offsets[0]);
    try std.testing.expect(image.entry_offset.? > 0);
    try std.testing.expectEqual(@as(usize, 0), image.code.len % 4);
    const entry_word = std.mem.readInt(u32, image.code[image.entry_offset.?..][0..4], .little);
    const call_word = image.entry_offset.? / 4 + 9;
    const delta: i32 = -@as(i32, @intCast(call_word));
    const expected = @as(u32, 0x94000000) | (@as(u32, @bitCast(delta)) & 0x03ffffff);
    const encoded_call = std.mem.readInt(u32, image.code[call_word * 4 ..][0..4], .little);
    try std.testing.expectEqual(@as(u32, 0xa9bf7bfd), entry_word);
    try std.testing.expectEqual(expected, encoded_call);
}

test "copy stack-resident aggregate parameters with paired transfers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const function: Machine.Function = .{
        .name = "aggregate_parameter",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 4, .aggregate = true }},
        .return_type = .void,
        .slot_count = 4,
        .frame_size = try Machine.frameSize(4),
        .register_slots = &([_]?u5{null} ** 4),
        .instructions = &.{.return_void},
    };
    const image = try encode(arena.allocator(), .{ .functions = &.{function} }, .none);
    const expected = [_]u32{
        A64.load64Pair(.x9, .x10, .x0, 0),
        A64.store64Pair(.x9, .x10, .zero_or_sp, 0),
        A64.load64Pair(.x9, .x10, .x0, 16),
        A64.store64Pair(.x9, .x10, .zero_or_sp, 16),
    };
    var found: usize = 0;
    var offset: usize = 0;
    while (offset + 4 <= image.code.len and found < expected.len) : (offset += 4) {
        const word = std.mem.readInt(u32, image.code[offset..][0..4], .little);
        if (word == expected[found]) found += 1;
    }
    try std.testing.expectEqual(expected.len, found);
}

test "recognize a comparison-only while header at its back edge" {
    const instructions = [_]Machine.Instruction{
        .{ .jump = 1 },
        .{ .binary = .{ .result = 2, .operator = .less, .left = 0, .right = 1, .type = .int } },
        .{ .branch = .{ .condition = 2, .then_instruction = 3, .else_instruction = 5 } },
        .{ .copy = .{ .result = 0, .operand = 0 } },
        .{ .jump = 1 },
        .return_void,
    };
    const function: Machine.Function = .{
        .name = "while_loop",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
        .return_type = .void,
        .slot_count = 3,
        .frame_size = try Machine.frameSize(3),
        .register_slots = &.{ 19, 20, 21 },
        .instructions = &instructions,
    };
    const backedge = loopBackedgeComparison(function, 4, 1) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 1), backedge.comparison_index);
    try std.testing.expectEqual(@as(usize, 2), backedge.branch_index);
    try std.testing.expectEqual(@as(usize, 3), backedge.body);
    try std.testing.expect(backedge.body_on_true);
}
