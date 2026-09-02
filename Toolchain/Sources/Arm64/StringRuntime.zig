const std = @import("std");
const Machine = @import("Machine.zig");
const A64 = @import("Instructions.zig");
const Fixups = @import("Fixups.zig");
const ExternalCalls = @import("ExternalCalls.zig");
const Allocation = @import("Allocation.zig");

const Allocator = std.mem.Allocator;
const Register = A64.Register;

pub const Error = Machine.Error || Allocator.Error || Fixups.Error;

const descriptor_header_size = 8;
const dynamic_prefix_size = 16;
const dynamic_flag: u64 = 1 << 63;
const length_mask: u64 = dynamic_flag - 1;
const concat_scratch_size = 48;
const macos_write = 4;

pub fn emitLiteral(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(Fixups.Data),
    string_id: usize,
    result: Machine.Slot,
) Error!void {
    try data_fixups.append(allocator, .{ .at = words.items.len, .string = string_id });
    try appendRelocatableAddress(allocator, words, .x9);
    try words.append(allocator, A64.storeStack(.x9, result));
}

pub fn emitComparison(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    binary: Machine.Instruction.Binary,
) Error!void {
    if (binary.operator != .equal and binary.operator != .not_equal) return error.InvalidMachineProgram;
    try words.append(allocator, A64.loadStack(.x9, binary.left));
    try words.append(allocator, A64.loadStack(.x10, binary.right));
    try loadLength(allocator, words, .x11, .x9, .x14);
    try loadLength(allocator, words, .x12, .x10, .x14);
    try words.append(allocator, A64.moveWideZero32(.x13, 0));
    try words.append(allocator, A64.compareRegisters(.x11, .x12));
    const unequal_length = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.not_equal));
    try words.append(allocator, A64.addSubtractImmediate(.x9, .x9, descriptor_header_size, true));
    try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, descriptor_header_size, true));
    const empty = words.items.len;
    try words.append(allocator, A64.compareBranchZero64(.x11));

    const loop = words.items.len;
    try words.append(allocator, A64.loadByte(.x14, .x9));
    try words.append(allocator, A64.loadByte(.x15, .x10));
    try words.append(allocator, A64.compareRegisters(.x14, .x15));
    const unequal_byte = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.not_equal));
    try words.append(allocator, A64.addSubtractImmediate(.x9, .x9, 1, true));
    try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, 1, true));
    try words.append(allocator, A64.addSubtractImmediate(.x11, .x11, 1, false));
    const repeat = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero64(.x11));
    try Fixups.patch19(words.items, repeat, loop);

    const equal = words.items.len;
    try words.append(allocator, A64.moveWideZero32(.x13, 1));
    const finished = words.items.len;
    try Fixups.patch19(words.items, empty, equal);
    try Fixups.patch19(words.items, unequal_length, finished);
    try Fixups.patch19(words.items, unequal_byte, finished);
    if (binary.operator == .not_equal) {
        try words.append(allocator, A64.moveWideZero32(.x14, 1));
        try words.append(allocator, A64.exclusiveOrRegisters(.x13, .x13, .x14));
    }
    try words.append(allocator, A64.storeStack(.x13, binary.result));
}

pub fn emitCount(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    count: Machine.Instruction.StringCount,
) Error!void {
    try words.append(allocator, A64.loadStack(.x9, count.operand));
    try loadLength(allocator, words, .x10, .x9, .x14);
    try words.append(allocator, A64.addSubtractImmediate(.x9, .x9, descriptor_header_size, true));
    try words.append(allocator, A64.moveWideZero32(.x11, 0));
    const empty = words.items.len;
    try words.append(allocator, A64.compareBranchZero64(.x10));

    const loop = words.items.len;
    try words.append(allocator, A64.loadByte(.x12, .x9));
    try words.append(allocator, A64.moveWideZero32(.x13, 0xc0));
    try words.append(allocator, A64.andRegisters(.x12, .x12, .x13));
    try words.append(allocator, A64.moveWideZero32(.x13, 0x80));
    try words.append(allocator, A64.compareRegisters(.x12, .x13));
    const continuation = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.equal));
    try words.append(allocator, A64.addSubtractImmediate(.x11, .x11, 1, true));
    try Fixups.patch19(words.items, continuation, words.items.len);
    try words.append(allocator, A64.addSubtractImmediate(.x9, .x9, 1, true));
    try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, 1, false));
    const repeat = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero64(.x10));
    try Fixups.patch19(words.items, repeat, loop);

    try Fixups.patch19(words.items, empty, words.items.len);
    try words.append(allocator, A64.storeStack(.x11, count.result));
}

pub fn emitByteCount(allocator: Allocator, words: *std.ArrayList(u32), count: Machine.Instruction.StringCount) Error!void {
    try words.append(allocator, A64.loadStack(.x9, count.operand));
    try loadLength(allocator, words, .x10, .x9, .x11);
    try words.append(allocator, A64.storeStack(.x10, count.result));
}

pub fn emitRetain(allocator: Allocator, words: *std.ArrayList(u32), value: Machine.Instruction.ListResource) Error!void {
    try words.append(allocator, A64.loadStack(.x10, value.operand));
    try words.append(allocator, A64.load64(.x9, .x10, 0));
    try emitImmediate64(allocator, words, .x11, dynamic_flag);
    try words.append(allocator, A64.andRegisters(.x9, .x9, .x11));
    const literal = words.items.len;
    try words.append(allocator, A64.compareBranchZero64(.x9));
    try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, dynamic_prefix_size, false));
    const retry = words.items.len;
    try words.append(allocator, A64.loadAcquireExclusive64(.x9, .x10));
    try words.append(allocator, A64.addSubtractImmediate(.x9, .x9, 1, true));
    try words.append(allocator, A64.storeReleaseExclusive64(.x11, .x9, .x10));
    const conflicted = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero(.x11));
    try Fixups.patch19(words.items, conflicted, retry);
    try Fixups.patch19(words.items, literal, words.items.len);
}

pub fn emitDrop(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
    value: Machine.Instruction.ListResource,
) Error!void {
    try words.append(allocator, A64.loadStack(.x10, value.operand));
    try words.append(allocator, A64.load64(.x9, .x10, 0));
    try emitImmediate64(allocator, words, .x11, dynamic_flag);
    try words.append(allocator, A64.andRegisters(.x9, .x9, .x11));
    const literal = words.items.len;
    try words.append(allocator, A64.compareBranchZero64(.x9));
    try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, dynamic_prefix_size, false));
    const retry = words.items.len;
    try words.append(allocator, A64.loadAcquireExclusive64(.x9, .x10));
    const already_released = words.items.len;
    try words.append(allocator, A64.compareBranchZero64(.x9));
    try words.append(allocator, A64.addSubtractImmediate(.x9, .x9, 1, false));
    try words.append(allocator, A64.storeReleaseExclusive64(.x11, .x9, .x10));
    const conflicted = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero(.x11));
    try Fixups.patch19(words.items, conflicted, retry);
    const retained = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero64(.x9));
    try words.append(allocator, A64.load64(.x1, .x10, 8));
    try words.append(allocator, A64.moveRegister(.x0, .x10));
    try Allocation.emitFree(allocator, words, sites, platform);
    const done = words.items.len;
    try Fixups.patch19(words.items, literal, done);
    try Fixups.patch19(words.items, already_released, done);
    try Fixups.patch19(words.items, retained, done);
}

pub fn emitConcat(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    epilogue_fixups: *std.ArrayList(Fixups.Local),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
    concat: Machine.Instruction.StringConcat,
) Error!void {
    try words.append(allocator, A64.loadStack(.x9, concat.left));
    try words.append(allocator, A64.loadStack(.x12, concat.right));
    try loadLength(allocator, words, .x10, .x9, .x7);
    try words.append(allocator, A64.addSubtractImmediate(.x11, .x9, descriptor_header_size, true));
    try loadLength(allocator, words, .x13, .x12, .x7);
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x12, descriptor_header_size, true));
    try words.append(allocator, A64.addSetFlags(.x15, .x10, .x13));
    const length_overflow = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.carry_set));
    try words.append(allocator, A64.moveWideZero32(.x9, descriptor_header_size + dynamic_prefix_size));
    try words.append(allocator, A64.addSetFlags(.x1, .x15, .x9));
    const allocation_overflow = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.carry_set));

    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, concat_scratch_size, false));
    try words.append(allocator, A64.store64(.x10, .zero_or_sp, 0));
    try words.append(allocator, A64.store64(.x11, .zero_or_sp, 8));
    try words.append(allocator, A64.store64(.x13, .zero_or_sp, 16));
    try words.append(allocator, A64.store64(.x14, .zero_or_sp, 24));
    try words.append(allocator, A64.store64(.x15, .zero_or_sp, 32));
    try Allocation.emit(allocator, words, sites, platform);
    const mmap_failed = words.items.len;
    try words.append(allocator, Allocation.failureBranch(platform));

    try words.append(allocator, A64.moveRegister(.x15, .x0));
    try words.append(allocator, A64.load64(.x10, .zero_or_sp, 32));
    try words.append(allocator, A64.moveWideZero32(.x9, 1));
    try words.append(allocator, A64.store64(.x9, .x15, 0));
    try words.append(allocator, A64.addSubtractImmediate(.x9, .x10, descriptor_header_size + dynamic_prefix_size, true));
    try words.append(allocator, A64.store64(.x9, .x15, 8));
    try words.append(allocator, A64.addSubtractImmediate(.x15, .x15, dynamic_prefix_size, true));
    try emitImmediate64(allocator, words, .x9, dynamic_flag);
    try words.append(allocator, A64.addRegisters(.x9, .x10, .x9));
    try words.append(allocator, A64.store64(.x9, .x15, 0));
    try words.append(allocator, A64.addSubtractImmediate(.x12, .x15, descriptor_header_size, true));
    try words.append(allocator, A64.load64(.x10, .zero_or_sp, 0));
    try words.append(allocator, A64.load64(.x11, .zero_or_sp, 8));
    try emitCopy(allocator, words, .x10, .x11, .x12);
    try words.append(allocator, A64.load64(.x10, .zero_or_sp, 16));
    try words.append(allocator, A64.load64(.x11, .zero_or_sp, 24));
    try emitCopy(allocator, words, .x10, .x11, .x12);
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, concat_scratch_size, true));
    try words.append(allocator, A64.storeStack(.x15, concat.result));
    const normal_finished = words.items.len;
    try words.append(allocator, A64.branch());

    const scratch_failure = words.items.len;
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, concat_scratch_size, true));
    const failure = words.items.len;
    try words.append(allocator, A64.moveWideZero32(.x8, @intFromEnum(Machine.Status.runtime_failure)));
    try Fixups.appendLocal(allocator, words, epilogue_fixups, A64.branch(), .imm26);
    const finished = words.items.len;

    try Fixups.patch19(words.items, length_overflow, failure);
    try Fixups.patch19(words.items, allocation_overflow, failure);
    try Fixups.patch19(words.items, mmap_failed, scratch_failure);
    try Fixups.patch26(words.items, normal_finished, finished);
}

pub fn emitFromBytes(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    epilogue_fixups: *std.ArrayList(Fixups.Local),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
    conversion: Machine.Instruction.StringFromBytes,
) Error!void {
    try words.append(allocator, A64.loadStack(.x10, conversion.bytes.start));
    try words.append(allocator, A64.loadStack(.x11, @intCast(@as(usize, conversion.bytes.start) + 1)));
    try words.append(allocator, A64.moveWideZero32(.x9, descriptor_header_size + dynamic_prefix_size));
    try words.append(allocator, A64.addSetFlags(.x1, .x11, .x9));
    const allocation_overflow = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.carry_set));

    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, false));
    try words.append(allocator, A64.store64(.x10, .zero_or_sp, 0));
    try words.append(allocator, A64.store64(.x11, .zero_or_sp, 8));
    try Allocation.emit(allocator, words, sites, platform);
    const mmap_failed = words.items.len;
    try words.append(allocator, Allocation.failureBranch(platform));

    try words.append(allocator, A64.moveRegister(.x15, .x0));
    try words.append(allocator, A64.load64(.x10, .zero_or_sp, 8));
    try words.append(allocator, A64.moveWideZero32(.x9, 1));
    try words.append(allocator, A64.store64(.x9, .x15, 0));
    try words.append(allocator, A64.addSubtractImmediate(.x9, .x10, descriptor_header_size + dynamic_prefix_size, true));
    try words.append(allocator, A64.store64(.x9, .x15, 8));
    try words.append(allocator, A64.addSubtractImmediate(.x15, .x15, dynamic_prefix_size, true));
    try emitImmediate64(allocator, words, .x9, dynamic_flag);
    try words.append(allocator, A64.addRegisters(.x9, .x10, .x9));
    try words.append(allocator, A64.store64(.x9, .x15, 0));
    try words.append(allocator, A64.load64(.x11, .zero_or_sp, 0));
    try words.append(allocator, A64.addSubtractImmediate(.x12, .x15, descriptor_header_size, true));
    try emitCopyByteSlots(allocator, words, .x10, .x11, .x12);
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, true));
    try words.append(allocator, A64.storeStack(.x15, conversion.result));
    const normal_finished = words.items.len;
    try words.append(allocator, A64.branch());

    const scratch_failure = words.items.len;
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, true));
    const failure = words.items.len;
    try words.append(allocator, A64.moveWideZero32(.x8, @intFromEnum(Machine.Status.runtime_failure)));
    try Fixups.appendLocal(allocator, words, epilogue_fixups, A64.branch(), .imm26);
    const finished = words.items.len;

    try Fixups.patch19(words.items, allocation_overflow, failure);
    try Fixups.patch19(words.items, mmap_failed, scratch_failure);
    try Fixups.patch26(words.items, normal_finished, finished);
}

pub fn emitPrint(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(Fixups.Data),
    external_call_sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
    program: Machine.Program,
    slot: Machine.Slot,
    descriptor: u16,
    newline: bool,
) Error!void {
    try words.append(allocator, A64.loadStack(.x9, slot));
    try loadLength(allocator, words, .x2, .x9, .x10);
    try words.append(allocator, A64.addSubtractImmediate(.x1, .x9, descriptor_header_size, true));
    try words.append(allocator, A64.moveWideZero32(.x0, descriptor));
    try emitWrite(allocator, words, external_call_sites, platform);
    if (newline) try emitWriteStatic(allocator, words, data_fixups, external_call_sites, platform, program, 0, descriptor);
}

pub fn emitWriteStatic(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(Fixups.Data),
    external_call_sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
    program: Machine.Program,
    string_id: usize,
    descriptor: u16,
) Error!void {
    if (string_id >= program.strings.len) return error.InvalidMachineProgram;
    try words.append(allocator, A64.moveWideZero32(.x0, descriptor));
    try data_fixups.append(allocator, .{
        .at = words.items.len,
        .string = string_id,
        .byte_offset = descriptor_header_size,
    });
    try appendRelocatableAddress(allocator, words, .x1);
    try emitImmediate64(allocator, words, .x2, program.strings[string_id].len);
    try emitWrite(allocator, words, external_call_sites, platform);
}

pub fn emitWrite(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    external_call_sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
) Error!void {
    switch (platform) {
        .darwin => {
            try words.append(allocator, A64.moveWideZero32(.x16, macos_write));
            try words.append(allocator, A64.serviceCall());
        },
        .windows => {
            try external_call_sites.append(allocator, .{
                .instruction_offset = @intCast(words.items.len * @sizeOf(u32)),
                .function = 0,
                .windows_symbol = .crt_write,
            });
            try words.append(allocator, A64.addressPage(.x16));
            try words.append(allocator, A64.load64(.x16, .x16, 0));
            try words.append(allocator, A64.branchLinkRegister(.x16));
        },
    }
}

fn appendRelocatableAddress(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    register: Register,
) Allocator.Error!void {
    try words.append(allocator, A64.addressPage(register));
    try words.append(allocator, A64.addSubtractImmediate(register, register, 0, true));
}

fn emitCopy(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    length: Register,
    source: Register,
    destination: Register,
) Error!void {
    const empty = words.items.len;
    try words.append(allocator, A64.compareBranchZero64(length));
    const loop = words.items.len;
    try words.append(allocator, A64.loadByte(.x9, source));
    try words.append(allocator, A64.storeByte(.x9, destination));
    try words.append(allocator, A64.addSubtractImmediate(source, source, 1, true));
    try words.append(allocator, A64.addSubtractImmediate(destination, destination, 1, true));
    try words.append(allocator, A64.addSubtractImmediate(length, length, 1, false));
    const repeat = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero64(length));
    try Fixups.patch19(words.items, repeat, loop);
    try Fixups.patch19(words.items, empty, words.items.len);
}

fn emitCopyByteSlots(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    length: Register,
    source: Register,
    destination: Register,
) Error!void {
    const empty = words.items.len;
    try words.append(allocator, A64.compareBranchZero64(length));
    const loop = words.items.len;
    try words.append(allocator, A64.loadByte(.x9, source));
    try words.append(allocator, A64.storeByte(.x9, destination));
    try words.append(allocator, A64.addSubtractImmediate(source, source, Machine.slot_size, true));
    try words.append(allocator, A64.addSubtractImmediate(destination, destination, 1, true));
    try words.append(allocator, A64.addSubtractImmediate(length, length, 1, false));
    const repeat = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero64(length));
    try Fixups.patch19(words.items, repeat, loop);
    try Fixups.patch19(words.items, empty, words.items.len);
}

fn emitImmediate64(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    register: Register,
    value: u64,
) Allocator.Error!void {
    try words.append(allocator, A64.moveWideZero64(register, @truncate(value), 0));
    try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 16), 1));
    try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 32), 2));
    try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 48), 3));
}

fn loadLength(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    destination: Register,
    pointer: Register,
    scratch: Register,
) Allocator.Error!void {
    try words.append(allocator, A64.load64(destination, pointer, 0));
    try emitImmediate64(allocator, words, scratch, length_mask);
    try words.append(allocator, A64.andRegisters(destination, destination, scratch));
}
