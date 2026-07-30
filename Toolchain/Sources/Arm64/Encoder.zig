const std = @import("std");
const Machine = @import("Machine.zig");
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
const ExternalCalls = @import("ExternalCalls.zig");
const Register = A64.Register;
const Condition = A64.Condition;
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
const addressRelative = A64.addressRelative;
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
const floatNegate = A64.floatNegate;
const floatArithmetic = A64.floatArithmetic;
const floatCompare = A64.floatCompare;
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

const Allocator = std.mem.Allocator;

pub const Error = Machine.Error || Allocator.Error || Fixups.Error || FloatRuntime.Error || DeepCopyRuntime.Error || error{UnsupportedInstruction};

pub const Entry = union(enum) {
    none,
    test_function: Machine.FunctionId,
    executable_main: Machine.FunctionId,
};

pub const Platform = enum { darwin, windows };

pub const Image = struct {
    code: []u8,
    function_offsets: []const u32,
    entry_offset: ?u32,
    data_offset: ?u32 = null,
    external_call_sites: []const ExternalCalls.Site = &.{},
    address_sites: []const AddressSite = &.{},

    pub fn deinit(self: Image, allocator: Allocator) void {
        allocator.free(self.code);
        allocator.free(self.function_offsets);
        allocator.free(self.external_call_sites);
        allocator.free(self.address_sites);
    }
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
    try Machine.validate(program);
    var words: std.ArrayList(u32) = .empty;
    const offsets = try allocator.alloc(u32, program.functions.len);
    var calls: std.ArrayList(CallFixup) = .empty;
    var float_calls: std.ArrayList(usize) = .empty;
    var deep_copy_calls: std.ArrayList(DeepCopyFixup) = .empty;
    var data_fixups: std.ArrayList(DataFixup) = .empty;
    var snapshot_data_fixups: std.ArrayList(usize) = .empty;
    var external_call_sites: std.ArrayList(ExternalCalls.Site) = .empty;
    var function_addresses: std.ArrayList(FunctionAddressFixup) = .empty;
    var address_sites: std.ArrayList(AddressSite) = .empty;

    for (program.functions, 0..) |function, function_id| {
        offsets[function_id] = @intCast(words.items.len * 4);
        try encodeFunction(allocator, &words, &calls, &function_addresses, &float_calls, &deep_copy_calls, &data_fixups, &external_call_sites, platform, program, function);
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
        while ((words.items.len * 4 + runtime_bytes.items.len) % 4096 != runtime.page_offset) try runtime_bytes.appendNTimes(allocator, 0, 4);
        const runtime_start = words.items.len * 4 + runtime_bytes.items.len;
        const formatter_target = (runtime_start + runtime.entry_offset) / 4;
        for (float_calls.items) |at| try patch26(words.items, at, formatter_target);
        try runtime_bytes.appendSlice(allocator, runtime.bytes);
    }
    if (deep_copy_calls.items.len != 0) {
        const runtime = try DeepCopyRuntime.payload();
        while ((words.items.len * 4 + runtime_bytes.items.len) % 4096 != runtime.page_offset) try runtime_bytes.appendNTimes(allocator, 0, 4);
        const runtime_start = words.items.len * 4 + runtime_bytes.items.len;
        const target = (runtime_start + runtime.entry_offset) / 4;
        for (deep_copy_calls.items) |fixup| try patch26(words.items, fixup.call_at, target);
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
        try patchAdr(words.items, fixup.at, offsets[fixup.function]);
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
    for (program.globals, 0..) |global, index| std.mem.writeInt(u64, code[global_offsets[index]..][0..8], global.bits, .little);
    return .{
        .code = code,
        .function_offsets = offsets,
        .entry_offset = entry_offset,
        .data_offset = data_offset,
        .external_call_sites = try external_call_sites.toOwnedSlice(allocator),
        .address_sites = try address_sites.toOwnedSlice(allocator),
    };
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
    data_fixups: *std.ArrayList(DataFixup),
    external_call_sites: *std.ArrayList(ExternalCalls.Site),
    platform: Platform,
    program: Machine.Program,
    function: Machine.Function,
) Error!void {
    var fixups: FunctionFixups = .{};
    var control_fixups: std.ArrayList(ControlFixup) = .empty;
    const instruction_offsets = try allocator.alloc(usize, function.instructions.len);
    defer allocator.free(instruction_offsets);
    try words.append(allocator, saveFrame());
    try words.append(allocator, moveFramePointer());
    try emitStackAdjustment(allocator, words, function.frame_size, false);
    if (function.hidden_return_slot) |slot| try words.append(allocator, storeStack(.x15, slot));
    for (function.parameters, 0..) |parameter, index| {
        const incoming: Register = @enumFromInt(index);
        if (!parameter.aggregate) {
            try storeValue(allocator, words, function, incoming, parameter.start);
        } else for (0..parameter.width) |leaf| {
            try emitLoadAtOffset(allocator, words, .x9, incoming, leaf * Machine.slot_size);
            try words.append(allocator, storeStack(.x9, @intCast(@as(usize, parameter.start) + leaf)));
        }
    }

    for (function.instructions, 0..) |instruction, instruction_index| {
        instruction_offsets[instruction_index] = words.items.len;
        switch (instruction) {
            .constant_int => |constant| {
                const bits = if (constant.type.isSignedInteger())
                    Numeric.signExtend(constant.bits, constant.type.bitWidth())
                else
                    constant.bits;
                try emitImmediate64(allocator, words, .x9, bits);
                try storeValue(allocator, words, function, .x9, constant.result);
            },
            .constant_bool => |constant| {
                try words.append(allocator, moveWideZero32(.x9, @intFromBool(constant.value)));
                try storeValue(allocator, words, function, .x9, constant.result);
            },
            .constant_str => |constant| {
                try StringRuntime.emitLiteral(allocator, words, data_fixups, constant.string, constant.result);
            },
            .constant_float32 => |constant| {
                try emitImmediate64(allocator, words, .x9, constant.bits);
                try storeValue(allocator, words, function, .x9, constant.result);
            },
            .constant_float64 => |constant| {
                try emitImmediate64(allocator, words, .x9, constant.bits);
                try storeValue(allocator, words, function, .x9, constant.result);
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
                try loadValue(allocator, words, function, .x9, copy.operand);
                try storeValue(allocator, words, function, .x9, copy.result);
            },
            .copy_range => |copy| try emitSpanCopy(allocator, words, copy.result, copy.operand),
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
            .reference_load => |load| try emitReferenceCopy(allocator, words, load.result, load.reference, true),
            .address_load => |load| {
                try words.append(allocator, loadStack(.x9, load.address));
                try words.append(allocator, loadStack(.x10, load.byte_offset));
                try words.append(allocator, addRegisters(.x9, .x9, .x10));
                try words.append(allocator, switch (load.type) {
                    .int8, .uint8 => A64.loadByte(.x9, .x9),
                    .int16, .uint16 => A64.load16(.x9, .x9),
                    .int32, .uint32 => A64.load32(.x9, .x9),
                    .int, .uint, .address => A64.load64(.x9, .x9, 0),
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
                    .int32, .uint32 => A64.store32(.x11, .x9),
                    .int, .uint => A64.store64(.x11, .x9, 0),
                    else => return error.InvalidMachineProgram,
                });
            },
            .reference_store => |store| try emitReferenceCopy(allocator, words, store.operand, store.reference, false),
            .reference_offset => |offset| {
                try words.append(allocator, loadStack(.x9, offset.reference));
                if (offset.byte_offset <= std.math.maxInt(u12)) {
                    try words.append(allocator, addSubtractImmediate(.x9, .x9, @intCast(offset.byte_offset), true));
                } else {
                    try emitImmediate64(allocator, words, .x10, offset.byte_offset);
                    try words.append(allocator, addRegisters(.x9, .x9, .x10));
                }
                try words.append(allocator, storeStack(.x9, offset.result));
            },
            .reference_indirect_offset => |offset| {
                try words.append(allocator, loadStack(.x9, offset.reference));
                try words.append(allocator, load64(.x9, .x9, 0));
                if (offset.byte_offset <= std.math.maxInt(u12)) {
                    try words.append(allocator, addSubtractImmediate(.x9, .x9, @intCast(offset.byte_offset), true));
                } else {
                    try emitImmediate64(allocator, words, .x10, offset.byte_offset);
                    try words.append(allocator, addRegisters(.x9, .x9, .x10));
                }
                try words.append(allocator, storeStack(.x9, offset.result));
            },
            .aggregate_init => |initialization| {
                var destination_offset: usize = 0;
                for (initialization.fields) |field| {
                    var destination = initialization.result;
                    destination.start = @intCast(@as(usize, destination.start) + destination_offset);
                    destination.width = field.width;
                    try emitSpanCopy(allocator, words, destination, field);
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
                try words.append(allocator, load64(.x9, .x10, Machine.slot_size));
                try words.append(allocator, addSubtractImmediate(.x9, .x9, 1, true));
                try words.append(allocator, store64(.x9, .x10, Machine.slot_size));
            },
            .class_drop => |drop| {
                try words.append(allocator, loadStack(.x10, drop.operand));
                try words.append(allocator, load64(.x9, .x10, Machine.slot_size));
                const unrooted = words.items.len;
                try words.append(allocator, compareBranchZero(.x9));
                try words.append(allocator, addSubtractImmediate(.x9, .x9, 1, false));
                try words.append(allocator, store64(.x9, .x10, Machine.slot_size));
                const still_referenced = words.items.len;
                try words.append(allocator, compareBranchNonZero64(.x9));
                try Fixups.patch19(words.items, unrooted, words.items.len);
                try words.append(allocator, load64(.x9, .x10, 2 * Machine.slot_size));
                const already_dropped = words.items.len;
                try words.append(allocator, compareBranchNonZero64(.x9));
                try words.append(allocator, moveWideZero64(.x9, 1, 0));
                try words.append(allocator, store64(.x9, .x10, 2 * Machine.slot_size));
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
                    try finalized.append(allocator, words.items.len);
                    try words.append(allocator, branch());
                    try Fixups.patch19(words.items, skip, words.items.len);
                }
                for (finalized.items) |at| try Fixups.patch26(words.items, at, words.items.len);
                try Fixups.patch19(words.items, still_referenced, words.items.len);
                try Fixups.patch19(words.items, already_dropped, words.items.len);
            },
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
            .collection_load => |access| if (access.dynamic)
                try ListRuntime.emitLoad(allocator, words, data_fixups, &fixups.epilogue, program, access)
            else
                try encodeCollectionLoad(allocator, words, data_fixups, &fixups, program, access),
            .collection_reference => |access| if (access.dynamic)
                try ListRuntime.emitReference(allocator, words, data_fixups, &fixups.epilogue, program, access)
            else
                try encodeCollectionReference(allocator, words, data_fixups, &fixups, program, access),
            .collection_replace => |replacement| if (replacement.dynamic)
                try ListRuntime.emitReplace(allocator, words, data_fixups, &fixups.epilogue, external_call_sites, @enumFromInt(@intFromEnum(platform)), program, replacement)
            else
                try encodeCollectionReplace(allocator, words, data_fixups, &fixups, program, replacement),
            .collection_count => |count| try ListRuntime.emitCount(allocator, words, count),
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
                    try loadValue(allocator, words, function, .x9, unary.operand);
                    try words.append(allocator, moveGeneralToFloat(.x9, .x9, unary.type == .float64));
                    try words.append(allocator, floatNegate(.x10, .x9, unary.type == .float64));
                    try words.append(allocator, moveFloatToGeneral(.x10, .x10, unary.type == .float64));
                    try storeValue(allocator, words, function, .x10, unary.result);
                    continue;
                }
                try loadValue(allocator, words, function, .x9, unary.operand);
                if (unary.type.isSignedInteger()) {
                    try emitImmediate64(allocator, words, .x10, @bitCast(Numeric.integerMin(unary.type)));
                    try words.append(allocator, compareRegisters(.x9, .x10));
                    try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.equal), .imm19);
                } else {
                    try appendFixup(allocator, words, &fixups.overflow, compareBranchNonZero64(.x9), .imm19);
                }
                try words.append(allocator, subtractSetFlags(.x11, .zero_or_sp, .x9));
                try storeValue(allocator, words, function, .x11, unary.result);
            },
            .binary => |binary| try encodeBinary(allocator, words, &fixups, function, binary),
            .function_address => |address| {
                try function_addresses.append(allocator, .{ .at = words.items.len, .function = address.function });
                try words.append(allocator, addressRelative(.x9));
                try words.append(allocator, storeStack(.x9, address.result));
            },
            .call => |call| {
                for (call.arguments, 0..) |argument, index| {
                    const outgoing: Register = @enumFromInt(index);
                    if (argument.aggregate) {
                        if (argument.width == 0) {
                            try words.append(allocator, moveWideZero64(outgoing, 0, 0));
                        } else try emitStackAddress(allocator, words, outgoing, argument.start);
                    } else try words.append(allocator, loadStack(outgoing, argument.start));
                }
                if (call.result) |result| if (result.aggregate) {
                    if (result.width == 0) {
                        try words.append(allocator, moveWideZero64(.x15, 0, 0));
                    } else try emitStackAddress(allocator, words, .x15, result.start);
                };
                try calls.append(allocator, .{ .at = words.items.len, .function = call.function });
                try words.append(allocator, branchLink());
                try appendFixup(allocator, words, &fixups.epilogue, compareBranchNonZero(.x8), .imm19);
                if (call.result) |result| if (!result.aggregate) try words.append(allocator, storeStack(.x0, result.start));
            },
            .indirect_call => |call| {
                for (call.arguments, 0..) |argument, index| {
                    const outgoing: Register = @enumFromInt(index);
                    if (argument.aggregate) {
                        if (argument.width == 0) try words.append(allocator, moveWideZero64(outgoing, 0, 0)) else try emitStackAddress(allocator, words, outgoing, argument.start);
                    } else try words.append(allocator, loadStack(outgoing, argument.start));
                }
                if (call.result) |result| if (result.aggregate) {
                    if (result.width == 0) try words.append(allocator, moveWideZero64(.x15, 0, 0)) else try emitStackAddress(allocator, words, .x15, result.start);
                };
                try words.append(allocator, loadStack(.x16, call.callee));
                try words.append(allocator, A64.branchLinkRegister(.x16));
                try appendFixup(allocator, words, &fixups.epilogue, compareBranchNonZero(.x8), .imm19);
                if (call.result) |result| if (!result.aggregate) try words.append(allocator, storeStack(.x0, result.start));
            },
            .external_call => |call| try ExternalCalls.emit(allocator, words, external_call_sites, function, call),
            .mutex_lock => try emitMutexOperation(allocator, words, data_fixups, external_call_sites, platform, program, true),
            .mutex_unlock => try emitMutexOperation(allocator, words, data_fixups, external_call_sites, platform, program, false),
            .dynamic_call => |call| try encodeDynamicCall(allocator, words, calls, &fixups, call),
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
                        try words.append(allocator, loadStack(.x9, @intCast(@as(usize, value.start) + leaf)));
                        try emitStoreAtOffset(allocator, words, .x9, .x14, leaf * Machine.slot_size);
                    }
                    try words.append(allocator, moveWideZero64(.x0, 0, 0));
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
                try control_fixups.append(allocator, .{ .at = words.items.len, .target = target, .width = .imm26 });
                try words.append(allocator, branch());
            },
            .branch => |branch_value| {
                try loadValue(allocator, words, function, .x9, branch_value.condition);
                try control_fixups.append(allocator, .{
                    .at = words.items.len,
                    .target = branch_value.then_instruction,
                    .width = .imm19,
                });
                try words.append(allocator, compareBranchNonZero(.x9));
                try control_fixups.append(allocator, .{
                    .at = words.items.len,
                    .target = branch_value.else_instruction,
                    .width = .imm26,
                });
                try words.append(allocator, branch());
            },
        }
    }

    for (control_fixups.items) |fixup| {
        if (fixup.target >= instruction_offsets.len) return error.InvalidMachineProgram;
        switch (fixup.width) {
            .imm19 => try patch19(words.items, fixup.at, instruction_offsets[fixup.target]),
            .imm26 => try patch26(words.items, fixup.at, instruction_offsets[fixup.target]),
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
    try emitStackAdjustment(allocator, words, function.frame_size, true);
    try words.append(allocator, restoreFrame());
    try words.append(allocator, returnInstruction());

    for (fixups.overflow.items) |fixup| try patchLocal(words.items, fixup, overflow_label);
    for (fixups.division_by_zero.items) |fixup| try patchLocal(words.items, fixup, division_label);
    for (fixups.epilogue.items) |fixup| try patchLocal(words.items, fixup, epilogue_label);
    try patch26(words.items, overflow_to_epilogue, epilogue_label);
    try patch26(words.items, division_to_epilogue, epilogue_label);
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
    call: Machine.Instruction.DynamicCall,
) Error!void {
    try words.append(allocator, loadStack(.x9, call.receiver));
    try words.append(allocator, load64(.x9, .x9, 0));
    for (call.arguments, 0..) |argument, index| {
        const outgoing: Register = @enumFromInt(index);
        if (argument.aggregate) {
            if (argument.width == 0) try words.append(allocator, moveWideZero64(outgoing, 0, 0)) else try emitStackAddress(allocator, words, outgoing, argument.start);
        } else try words.append(allocator, loadStack(outgoing, argument.start));
    }
    if (call.result) |result| if (result.aggregate) {
        if (result.width == 0) try words.append(allocator, moveWideZero64(.x15, 0, 0)) else try emitStackAddress(allocator, words, .x15, result.start);
    };
    var done: std.ArrayList(usize) = .empty;
    for (call.implementations) |implementation| {
        try emitImmediate64(allocator, words, .x10, implementation.structure);
        try words.append(allocator, compareRegisters(.x9, .x10));
        const skip = words.items.len;
        try words.append(allocator, conditionalBranch(.not_equal));
        try calls.append(allocator, .{ .at = words.items.len, .function = implementation.function });
        try words.append(allocator, branchLink());
        try appendFixup(allocator, words, &fixups.epilogue, compareBranchNonZero(.x8), .imm19);
        try done.append(allocator, words.items.len);
        try words.append(allocator, branch());
        try patch19(words.items, skip, words.items.len);
    }
    try calls.append(allocator, .{ .at = words.items.len, .function = call.function });
    try words.append(allocator, branchLink());
    try appendFixup(allocator, words, &fixups.epilogue, compareBranchNonZero(.x8), .imm19);
    for (done.items) |at| try patch26(words.items, at, words.items.len);
    if (call.result) |result| if (!result.aggregate) try words.append(allocator, storeStack(.x0, result.start));
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
    span: Machine.Span,
    reference: Machine.Slot,
    load_reference: bool,
) Allocator.Error!void {
    try words.append(allocator, loadStack(.x9, reference));
    for (0..span.width) |index| {
        const offset = index * Machine.slot_size;
        if (load_reference) {
            try emitLoadAtOffset(allocator, words, .x10, .x9, offset);
            try words.append(allocator, storeStack(.x10, @intCast(@as(usize, span.start) + index)));
        } else {
            try words.append(allocator, loadStack(.x10, @intCast(@as(usize, span.start) + index)));
            try emitStoreAtOffset(allocator, words, .x10, .x9, offset);
        }
    }
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
    try emitImmediate64(allocator, words, .x14, byte_offset);
    try words.append(allocator, addRegisters(.x14, base, .x14));
    try words.append(allocator, load64(destination, .x14, 0));
}

fn emitStoreAtOffset(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    source: Register,
    base: Register,
    byte_offset: usize,
) Allocator.Error!void {
    if (byte_offset <= std.math.maxInt(u12)) return words.append(allocator, store64(source, base, @intCast(byte_offset)));
    try emitImmediate64(allocator, words, .x13, byte_offset);
    try words.append(allocator, addRegisters(.x13, base, .x13));
    try words.append(allocator, store64(source, .x13, 0));
}

fn encodeAggregateEqual(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *FunctionFixups,
    comparison: Machine.Instruction.AggregateEqual,
) Error!void {
    var unequal_branches: std.ArrayList(usize) = .empty;
    for (comparison.leaves) |leaf| {
        var guard_skips: std.ArrayList(usize) = .empty;
        for (leaf.guards) |guard| {
            try words.append(allocator, loadStack(.x9, comparison.left.start + guard.offset));
            try emitImmediate64(allocator, words, .x10, guard.expected);
            try words.append(allocator, compareRegisters(.x9, .x10));
            try guard_skips.append(allocator, words.items.len);
            try words.append(allocator, conditionalBranch(.not_equal));
        }
        try encodeBinary(allocator, words, fixups, null, .{
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
    try words.append(allocator, loadStack(.x9, index));
    try words.append(allocator, compareRegisters(.x9, .zero_or_sp));
    const nonnegative = words.items.len;
    try words.append(allocator, conditionalBranch(.greater_equal));
    try emitImmediate64(allocator, words, .x10, count);
    try words.append(allocator, addRegisters(.x9, .x9, .x10));
    try patch19(words.items, nonnegative, words.items.len);
    try words.append(allocator, compareRegisters(.x9, .zero_or_sp));
    const negative = words.items.len;
    try words.append(allocator, conditionalBranch(.less));
    try emitImmediate64(allocator, words, .x10, count);
    try words.append(allocator, compareRegisters(.x9, .x10));
    const upper = words.items.len;
    try words.append(allocator, conditionalBranch(.greater_equal));
    return .{ .negative = negative, .upper = upper };
}

fn encodeCollectionLoad(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(DataFixup),
    function_fixups: *FunctionFixups,
    program: Machine.Program,
    access: Machine.Instruction.CollectionLoad,
) Error!void {
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
    const bounds = try emitCollectionBounds(allocator, words, access.index, access.count);
    try words.append(allocator, loadStack(.x10, access.reference.?));
    try emitImmediate64(allocator, words, .x11, @as(u64, access.element_width) * Machine.slot_size);
    try words.append(allocator, multiply(.x9, .x9, .x11));
    try words.append(allocator, addRegisters(.x10, .x10, .x9));
    try words.append(allocator, storeStack(.x10, access.result));
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

fn encodeBinary(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *FunctionFixups,
    function: ?Machine.Function,
    binary: Machine.Instruction.Binary,
) Error!void {
    if (binary.type == .str) return StringRuntime.emitComparison(allocator, words, binary);
    try loadOptionalValue(allocator, words, function, .x9, binary.left);
    try loadOptionalValue(allocator, words, function, .x10, binary.right);
    if (binary.type.isFloat()) return encodeFloatBinary(allocator, words, function, binary);
    const signed = binary.type.isSignedInteger();
    switch (binary.operator) {
        .add => {
            try words.append(allocator, addSetFlags(.x11, .x9, .x10));
            try appendFixup(
                allocator,
                words,
                &fixups.overflow,
                conditionalBranch(if (signed) .overflow else .carry_set),
                .imm19,
            );
            try emitIntegerRangeCheck(allocator, words, fixups, binary.type, .x11);
            try storeOptionalValue(allocator, words, function, .x11, binary.result);
        },
        .subtract => {
            try words.append(allocator, subtractSetFlags(.x11, .x9, .x10));
            try appendFixup(
                allocator,
                words,
                &fixups.overflow,
                conditionalBranch(if (signed) .overflow else .carry_clear),
                .imm19,
            );
            try emitIntegerRangeCheck(allocator, words, fixups, binary.type, .x11);
            try storeOptionalValue(allocator, words, function, .x11, binary.result);
        },
        .multiply => {
            try words.append(allocator, multiply(.x11, .x9, .x10));
            if (signed) {
                try words.append(allocator, signedMultiplyHigh(.x12, .x9, .x10));
                try words.append(allocator, arithmeticShiftRight63(.x13, .x11));
                try words.append(allocator, compareRegisters(.x12, .x13));
                try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.not_equal), .imm19);
            } else {
                try words.append(allocator, unsignedMultiplyHigh(.x12, .x9, .x10));
                try appendFixup(allocator, words, &fixups.overflow, compareBranchNonZero64(.x12), .imm19);
            }
            try emitIntegerRangeCheck(allocator, words, fixups, binary.type, .x11);
            try storeOptionalValue(allocator, words, function, .x11, binary.result);
        },
        .divide => {
            try appendFixup(allocator, words, &fixups.division_by_zero, compareBranchZero64(.x10), .imm19);
            if (signed) {
                try emitImmediate64(allocator, words, .x11, @bitCast(Numeric.integerMin(binary.type)));
                try words.append(allocator, compareRegisters(.x9, .x11));
                const not_minimum = words.items.len;
                try words.append(allocator, conditionalBranch(.not_equal));
                try emitImmediate64(allocator, words, .x12, @bitCast(@as(i64, -1)));
                try words.append(allocator, compareRegisters(.x10, .x12));
                try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.equal), .imm19);
                try patch19(words.items, not_minimum, words.items.len);
            }
            try words.append(allocator, if (signed) signedDivide(.x11, .x9, .x10) else unsignedDivide(.x11, .x9, .x10));
            try storeOptionalValue(allocator, words, function, .x11, binary.result);
        },
        .remainder => {
            try appendFixup(allocator, words, &fixups.division_by_zero, compareBranchZero64(.x10), .imm19);
            if (signed) {
                try emitImmediate64(allocator, words, .x11, @bitCast(Numeric.integerMin(binary.type)));
                try words.append(allocator, compareRegisters(.x9, .x11));
                const not_minimum = words.items.len;
                try words.append(allocator, conditionalBranch(.not_equal));
                try emitImmediate64(allocator, words, .x12, @bitCast(@as(i64, -1)));
                try words.append(allocator, compareRegisters(.x10, .x12));
                try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.equal), .imm19);
                try patch19(words.items, not_minimum, words.items.len);
            }
            try words.append(allocator, if (signed) signedDivide(.x11, .x9, .x10) else unsignedDivide(.x11, .x9, .x10));
            try words.append(allocator, multiplySubtract(.x12, .x11, .x10, .x9));
            try storeOptionalValue(allocator, words, function, .x12, binary.result);
        },
        .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => {
            try words.append(allocator, compareRegisters(.x9, .x10));
            try words.append(allocator, moveWideZero32(.x11, 0));
            const skip_true = words.items.len;
            try words.append(allocator, conditionalBranch(inverseComparison(binary.operator, signed)));
            try words.append(allocator, moveWideZero32(.x11, 1));
            try patch19(words.items, skip_true, words.items.len);
            try storeOptionalValue(allocator, words, function, .x11, binary.result);
        },
        .bit_and => {
            try words.append(allocator, andRegisters(.x11, .x9, .x10));
            try storeOptionalValue(allocator, words, function, .x11, binary.result);
        },
        .bit_xor => {
            try words.append(allocator, exclusiveOrRegisters(.x11, .x9, .x10));
            try storeOptionalValue(allocator, words, function, .x11, binary.result);
        },
        .shift_left, .shift_right => {
            try emitImmediate64(allocator, words, .x11, binary.type.bitWidth());
            try words.append(allocator, compareRegisters(.x10, .x11));
            try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.greater_equal), .imm19);
            try words.append(allocator, if (binary.operator == .shift_left)
                logicalShiftLeftVariable(.x11, .x9, .x10)
            else
                logicalShiftRightVariable(.x11, .x9, .x10));
            try emitImmediate64(allocator, words, .x12, Numeric.mask(binary.type.bitWidth()));
            try words.append(allocator, andRegisters(.x11, .x11, .x12));
            try storeOptionalValue(allocator, words, function, .x11, binary.result);
        },
    }
}

fn encodeFloatBinary(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: ?Machine.Function,
    binary: Machine.Instruction.Binary,
) Error!void {
    const double = binary.type == .float64;
    try words.append(allocator, moveGeneralToFloat(.x9, .x9, double));
    try words.append(allocator, moveGeneralToFloat(.x10, .x10, double));
    switch (binary.operator) {
        .add, .subtract, .multiply, .divide => {
            try words.append(allocator, floatArithmetic(.x11, .x9, .x10, binary.operator, double));
            try words.append(allocator, moveFloatToGeneral(.x11, .x11, double));
            try storeOptionalValue(allocator, words, function, .x11, binary.result);
        },
        .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => {
            try words.append(allocator, floatCompare(.x9, .x10, double));
            try words.append(allocator, moveWideZero32(.x11, 0));
            const skip_true = words.items.len;
            try words.append(allocator, conditionalBranch(inverseFloatComparison(binary.operator)));
            try words.append(allocator, moveWideZero32(.x11, 1));
            try patch19(words.items, skip_true, words.items.len);
            try storeOptionalValue(allocator, words, function, .x11, binary.result);
        },
        else => return error.InvalidMachineProgram,
    }
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

fn encodeConversion(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *FunctionFixups,
    data_fixups: *std.ArrayList(DataFixup),
    program: Machine.Program,
    conversion: Machine.Instruction.Convert,
) Error!void {
    try words.append(allocator, loadStack(.x9, conversion.operand));
    if (conversion.source.isInteger() and conversion.target.isFloat()) {
        const double = conversion.target == .float64;
        try words.append(allocator, integerToFloat(.x10, .x9, conversion.source.isSignedInteger(), double));
        if (conversion.checked) {
            try words.append(allocator, floatToInteger(.x11, .x10, conversion.source.isSignedInteger(), double));
            try words.append(allocator, compareRegisters(.x9, .x11));
            try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .equal);
        }
        try words.append(allocator, moveFloatToGeneral(.x10, .x10, double));
        try words.append(allocator, storeStack(.x10, conversion.result));
        return;
    }
    if (conversion.source.isFloat() and conversion.target.isInteger()) {
        const double = conversion.source == .float64;
        try words.append(allocator, moveGeneralToFloat(.x9, .x9, double));
        try emitFloatToIntegerRangeGuards(
            allocator,
            words,
            fixups,
            data_fixups,
            program,
            conversion,
            double,
        );
        try words.append(allocator, floatToInteger(.x10, .x9, conversion.target.isSignedInteger(), double));
        try words.append(allocator, integerToFloat(.x11, .x10, conversion.target.isSignedInteger(), double));
        try words.append(allocator, floatCompare(.x9, .x11, double));
        try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .equal);
        try emitConvertedIntegerRangeChecks(
            allocator,
            words,
            fixups,
            data_fixups,
            program,
            conversion,
            .x10,
        );
        try words.append(allocator, storeStack(.x10, conversion.result));
        return;
    }
    if (conversion.source.isFloat() and conversion.target.isFloat()) {
        const source_double = conversion.source == .float64;
        const target_double = conversion.target == .float64;
        try words.append(allocator, moveGeneralToFloat(.x9, .x9, source_double));
        try words.append(allocator, floatConvert(.x10, .x9, target_double));
        if (conversion.checked and source_double and !target_double) {
            try words.append(allocator, floatConvert(.x11, .x10, true));
            try words.append(allocator, floatCompare(.x9, .x11, true));
            try emitConversionGuard(allocator, words, fixups, data_fixups, program, conversion.header, .equal);
        }
        try words.append(allocator, moveFloatToGeneral(.x10, .x10, target_double));
        try words.append(allocator, storeStack(.x10, conversion.result));
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
    try words.append(allocator, storeStack(.x9, conversion.result));
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
    try words.append(allocator, moveWideZero64(register, @truncate(value), 0));
    try words.append(allocator, moveWideKeep64(register, @truncate(value >> 16), 1));
    try words.append(allocator, moveWideKeep64(register, @truncate(value >> 32), 2));
    try words.append(allocator, moveWideKeep64(register, @truncate(value >> 48), 3));
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
    frame_size: u16,
    add: bool,
) Allocator.Error!void {
    var remaining: u16 = frame_size;
    while (remaining != 0) {
        const amount: u16 = @min(remaining, 4080);
        try words.append(allocator, addSubtractImmediate(.zero_or_sp, .zero_or_sp, @intCast(amount), add));
        remaining -= amount;
    }
}

fn appendFixup(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *std.ArrayList(LocalFixup),
    instruction: u32,
    width: FixupWidth,
) Allocator.Error!void {
    try fixups.append(allocator, .{ .at = words.items.len, .width = width });
    try words.append(allocator, instruction);
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
    try std.testing.expectEqual(@as(u32, 0xc85ffdc9), A64.loadAcquireExclusive64(.x9, .x14));
    try std.testing.expectEqual(@as(u32, 0xc80afdc9), A64.storeReleaseExclusive64(.x10, .x9, .x14));
    try std.testing.expectEqual(@as(u32, 0xc89ffddf), A64.storeRelease64(.zero_or_sp, .x14));
    try std.testing.expectEqual(@as(u32, 0xd65f03c0), returnInstruction());
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
