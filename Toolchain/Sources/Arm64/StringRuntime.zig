const std = @import("std");
const Machine = @import("Machine.zig");
const A64 = @import("Instructions.zig");
const Fixups = @import("Fixups.zig");

const Allocator = std.mem.Allocator;
const Register = A64.Register;

pub const Error = Machine.Error || Allocator.Error || Fixups.Error;

const descriptor_header_size = 8;
const concat_scratch_size = 48;
const macos_write = 4;
const macos_mmap = 197;
const protection_read_write = 3;
const map_private_anonymous = 0x1002;

pub fn emitLiteral(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(Fixups.Data),
    string_id: usize,
    result: Machine.Slot,
) Error!void {
    try data_fixups.append(allocator, .{ .at = words.items.len, .string = string_id });
    try words.append(allocator, A64.addressRelative(.x9));
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
    try words.append(allocator, A64.load64(.x11, .x9, 0));
    try words.append(allocator, A64.load64(.x12, .x10, 0));
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
    try words.append(allocator, A64.load64(.x10, .x9, 0));
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

pub fn emitConcat(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    epilogue_fixups: *std.ArrayList(Fixups.Local),
    concat: Machine.Instruction.StringConcat,
) Error!void {
    try words.append(allocator, A64.loadStack(.x9, concat.left));
    try words.append(allocator, A64.loadStack(.x12, concat.right));
    try words.append(allocator, A64.load64(.x10, .x9, 0));
    try words.append(allocator, A64.addSubtractImmediate(.x11, .x9, descriptor_header_size, true));
    try words.append(allocator, A64.load64(.x13, .x12, 0));
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x12, descriptor_header_size, true));
    try words.append(allocator, A64.addSetFlags(.x15, .x10, .x13));
    const length_overflow = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.carry_set));
    try words.append(allocator, A64.moveWideZero32(.x9, descriptor_header_size));
    try words.append(allocator, A64.addSetFlags(.x1, .x15, .x9));
    const allocation_overflow = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.carry_set));

    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, concat_scratch_size, false));
    try words.append(allocator, A64.store64(.x10, .zero_or_sp, 0));
    try words.append(allocator, A64.store64(.x11, .zero_or_sp, 8));
    try words.append(allocator, A64.store64(.x13, .zero_or_sp, 16));
    try words.append(allocator, A64.store64(.x14, .zero_or_sp, 24));
    try words.append(allocator, A64.store64(.x15, .zero_or_sp, 32));
    try words.append(allocator, A64.moveWideZero32(.x0, 0));
    try words.append(allocator, A64.moveWideZero32(.x2, protection_read_write));
    try words.append(allocator, A64.moveWideZero32(.x3, map_private_anonymous));
    try emitImmediate64(allocator, words, .x4, std.math.maxInt(u64));
    try words.append(allocator, A64.moveWideZero32(.x5, 0));
    try words.append(allocator, A64.moveWideZero32(.x16, macos_mmap));
    try words.append(allocator, A64.serviceCall());
    const mmap_failed = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.carry_set));

    try words.append(allocator, A64.moveRegister(.x15, .x0));
    try words.append(allocator, A64.load64(.x10, .zero_or_sp, 32));
    try words.append(allocator, A64.store64(.x10, .x15, 0));
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

pub fn emitPrint(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(Fixups.Data),
    program: Machine.Program,
    slot: Machine.Slot,
    descriptor: u16,
    newline: bool,
) Error!void {
    try words.append(allocator, A64.loadStack(.x9, slot));
    try words.append(allocator, A64.load64(.x2, .x9, 0));
    try words.append(allocator, A64.addSubtractImmediate(.x1, .x9, descriptor_header_size, true));
    try words.append(allocator, A64.moveWideZero32(.x0, descriptor));
    try words.append(allocator, A64.moveWideZero32(.x16, macos_write));
    try words.append(allocator, A64.serviceCall());
    if (newline) try emitWriteStatic(allocator, words, data_fixups, program, 0, descriptor);
}

pub fn emitWriteStatic(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(Fixups.Data),
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
    try words.append(allocator, A64.addressRelative(.x1));
    try emitImmediate64(allocator, words, .x2, program.strings[string_id].len);
    try words.append(allocator, A64.moveWideZero32(.x16, macos_write));
    try words.append(allocator, A64.serviceCall());
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
