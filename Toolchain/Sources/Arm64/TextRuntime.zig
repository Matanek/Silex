const std = @import("std");
const Machine = @import("Machine.zig");
const A64 = @import("Instructions.zig");
const Fixups = @import("Fixups.zig");
const StringRuntime = @import("StringRuntime.zig");

const Allocator = std.mem.Allocator;
const Register = A64.Register;

pub const Error = Machine.Error || Allocator.Error || Fixups.Error;

const descriptor_header_size = 8;
const integer_scratch_size = 64;
const float_scratch_size = 384;
const float_output_offset = 16;
const macos_mmap = 197;
const protection_read_write = 3;
const map_private_anonymous = 0x1002;

pub fn emitFormat(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    float_calls: *std.ArrayList(usize),
    data_fixups: *std.ArrayList(Fixups.Data),
    epilogue_fixups: *std.ArrayList(Fixups.Local),
    format: Machine.Instruction.FormatValue,
) Error!void {
    switch (format.kind) {
        .signed_integer => try emitInteger(allocator, words, epilogue_fixups, format.operand, format.result, true),
        .unsigned_integer => try emitInteger(allocator, words, epilogue_fixups, format.operand, format.result, false),
        .float32, .float64 => try emitFloat(
            allocator,
            words,
            float_calls,
            epilogue_fixups,
            format.operand,
            format.result,
            format.kind == .float64,
        ),
        .boolean => try emitBoolean(allocator, words, data_fixups, format.operand, format.result),
        .string => {
            try words.append(allocator, A64.loadStack(.x9, format.operand));
            try words.append(allocator, A64.storeStack(.x9, format.result));
        },
    }
}

fn emitBoolean(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(Fixups.Data),
    operand: Machine.Slot,
    result: Machine.Slot,
) Error!void {
    try words.append(allocator, A64.loadStack(.x9, operand));
    const use_false = words.items.len;
    try words.append(allocator, A64.compareBranchZero(.x9));
    try StringRuntime.emitLiteral(allocator, words, data_fixups, 1, result);
    const finished = words.items.len;
    try words.append(allocator, A64.branch());
    try Fixups.patch19(words.items, use_false, words.items.len);
    try StringRuntime.emitLiteral(allocator, words, data_fixups, 2, result);
    try Fixups.patch26(words.items, finished, words.items.len);
}

fn emitInteger(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    epilogue_fixups: *std.ArrayList(Fixups.Local),
    operand: Machine.Slot,
    result: Machine.Slot,
    signed: bool,
) Error!void {
    try words.append(allocator, A64.loadStack(.x9, operand));
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, integer_scratch_size, false));
    try words.append(allocator, A64.addSubtractImmediate(.x11, .zero_or_sp, integer_scratch_size, true));
    try words.append(allocator, A64.moveWideZero32(.x12, 0));

    const nonzero = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero64(.x9));
    try prependByte(allocator, words, '0');
    const zero_finished = words.items.len;
    try words.append(allocator, A64.branch());

    try Fixups.patch19(words.items, nonzero, words.items.len);
    if (signed) {
        try words.append(allocator, A64.moveWideZero32(.x3, 0));
        try words.append(allocator, A64.compareRegisters(.x9, .zero_or_sp));
        const negative = words.items.len;
        try words.append(allocator, A64.conditionalBranch(.less));
        try words.append(allocator, A64.subtractSetFlags(.x9, .zero_or_sp, .x9));
        const sign_ready = words.items.len;
        try words.append(allocator, A64.branch());
        try Fixups.patch19(words.items, negative, words.items.len);
        try words.append(allocator, A64.moveWideZero32(.x3, 1));
        try Fixups.patch26(words.items, sign_ready, words.items.len);
    }

    const digit_loop = words.items.len;
    try words.append(allocator, A64.moveWideZero32(.x10, 10));
    try words.append(allocator, if (signed) A64.signedDivide(.x4, .x9, .x10) else A64.unsignedDivide(.x4, .x9, .x10));
    try words.append(allocator, A64.multiplySubtract(.x5, .x4, .x10, .x9));
    if (signed) {
        try words.append(allocator, A64.moveWideZero32(.x6, '0'));
        try words.append(allocator, A64.subtractSetFlags(.x6, .x6, .x5));
    } else {
        try words.append(allocator, A64.addSubtractImmediate(.x6, .x5, '0', true));
    }
    try words.append(allocator, A64.addSubtractImmediate(.x11, .x11, 1, false));
    try words.append(allocator, A64.storeByte(.x6, .x11));
    try words.append(allocator, A64.addSubtractImmediate(.x12, .x12, 1, true));
    try words.append(allocator, A64.moveRegister(.x9, .x4));
    const repeat = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero64(.x9));
    try Fixups.patch19(words.items, repeat, digit_loop);

    if (signed) {
        const unsigned = words.items.len;
        try words.append(allocator, A64.compareBranchZero(.x3));
        try prependByte(allocator, words, '-');
        try Fixups.patch19(words.items, unsigned, words.items.len);
    }
    try Fixups.patch26(words.items, zero_finished, words.items.len);
    try allocateDescriptor(allocator, words, epilogue_fixups, result, integer_scratch_size);
}

fn prependByte(allocator: Allocator, words: *std.ArrayList(u32), byte: u8) Allocator.Error!void {
    try words.append(allocator, A64.addSubtractImmediate(.x11, .x11, 1, false));
    try words.append(allocator, A64.moveWideZero32(.x10, byte));
    try words.append(allocator, A64.storeByte(.x10, .x11));
    try words.append(allocator, A64.addSubtractImmediate(.x12, .x12, 1, true));
}

fn emitFloat(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    float_calls: *std.ArrayList(usize),
    epilogue_fixups: *std.ArrayList(Fixups.Local),
    operand: Machine.Slot,
    result: Machine.Slot,
    double: bool,
) Error!void {
    try words.append(allocator, A64.loadStack(.x0, operand));
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, float_scratch_size, false));
    try words.append(allocator, A64.addSubtractImmediate(.x1, .zero_or_sp, float_output_offset, true));
    try words.append(allocator, A64.moveWideZero32(.x2, @intFromBool(double)));
    try float_calls.append(allocator, words.items.len);
    try words.append(allocator, A64.branchLink());
    try words.append(allocator, A64.addSubtractImmediate(.x11, .zero_or_sp, float_output_offset, true));
    try words.append(allocator, A64.moveRegister(.x12, .x0));
    try allocateDescriptor(allocator, words, epilogue_fixups, result, float_scratch_size);
}

fn allocateDescriptor(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    epilogue_fixups: *std.ArrayList(Fixups.Local),
    result: Machine.Slot,
    scratch_size: u12,
) Error!void {
    try words.append(allocator, A64.store64(.x11, .zero_or_sp, 0));
    try words.append(allocator, A64.store64(.x12, .zero_or_sp, 8));
    try words.append(allocator, A64.addSubtractImmediate(.x1, .x12, descriptor_header_size, true));
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
    try words.append(allocator, A64.load64(.x11, .zero_or_sp, 0));
    try words.append(allocator, A64.load64(.x12, .zero_or_sp, 8));
    try words.append(allocator, A64.store64(.x12, .x15, 0));
    try words.append(allocator, A64.addSubtractImmediate(.x13, .x15, descriptor_header_size, true));
    try emitCopy(allocator, words, .x12, .x11, .x13);
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, scratch_size, true));
    try words.append(allocator, A64.storeStack(.x15, result));
    const finished = words.items.len;
    try words.append(allocator, A64.branch());

    const failure = words.items.len;
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, scratch_size, true));
    try words.append(allocator, A64.moveWideZero32(.x8, @intFromEnum(Machine.Status.runtime_failure)));
    try Fixups.appendLocal(allocator, words, epilogue_fixups, A64.branch(), .imm26);
    try Fixups.patch19(words.items, mmap_failed, failure);
    try Fixups.patch26(words.items, finished, words.items.len);
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
