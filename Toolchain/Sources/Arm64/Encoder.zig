const std = @import("std");
const Machine = @import("Machine.zig");

const Allocator = std.mem.Allocator;

pub const Error = Machine.Error || Allocator.Error || error{BranchOutOfRange};

pub const Entry = union(enum) {
    none,
    test_function: Machine.FunctionId,
    executable_main: Machine.FunctionId,
};

pub const Image = struct {
    code: []const u8,
    function_offsets: []const u32,
    entry_offset: ?u32,

    pub fn deinit(self: Image, allocator: Allocator) void {
        allocator.free(self.code);
        allocator.free(self.function_offsets);
    }
};

const Register = enum(u5) {
    x0 = 0,
    x1 = 1,
    x2 = 2,
    x3 = 3,
    x4 = 4,
    x5 = 5,
    x6 = 6,
    x7 = 7,
    x8 = 8,
    x9 = 9,
    x10 = 10,
    x11 = 11,
    x12 = 12,
    x13 = 13,
    x29 = 29,
    x30 = 30,
    zero_or_sp = 31,
};

const CallFixup = struct {
    at: usize,
    function: Machine.FunctionId,
};

const FixupWidth = enum { imm19, imm26 };

const LocalFixup = struct {
    at: usize,
    width: FixupWidth,
};

const FunctionFixups = struct {
    overflow: std.ArrayList(LocalFixup) = .empty,
    division_by_zero: std.ArrayList(LocalFixup) = .empty,
    epilogue: std.ArrayList(LocalFixup) = .empty,
};

pub fn encode(allocator: Allocator, program: Machine.Program, entry: Entry) Error!Image {
    try Machine.validate(program);
    var words: std.ArrayList(u32) = .empty;
    const offsets = try allocator.alloc(u32, program.functions.len);
    var calls: std.ArrayList(CallFixup) = .empty;

    for (program.functions, 0..) |function, function_id| {
        offsets[function_id] = @intCast(words.items.len * 4);
        try encodeFunction(allocator, &words, &calls, function);
    }

    const entry_offset: ?u32 = switch (entry) {
        .none => null,
        .test_function => |function| entry: {
            if (function >= program.functions.len) return error.InvalidMachineProgram;
            const offset: u32 = @intCast(words.items.len * 4);
            try words.append(allocator, saveFrame());
            try words.append(allocator, moveFramePointer());
            try calls.append(allocator, .{ .at = words.items.len, .function = function });
            try words.append(allocator, branchLink());
            try words.append(allocator, moveRegister(.x1, .x8));
            try words.append(allocator, restoreFrame());
            try words.append(allocator, returnInstruction());
            break :entry offset;
        },
        .executable_main => |function| entry: {
            if (function >= program.functions.len) return error.InvalidMachineProgram;
            const offset: u32 = @intCast(words.items.len * 4);
            try words.append(allocator, saveFrame());
            try words.append(allocator, moveFramePointer());
            try calls.append(allocator, .{ .at = words.items.len, .function = function });
            try words.append(allocator, branchLink());
            const success_branch = words.items.len;
            try words.append(allocator, compareBranchZero(.x8));
            try words.append(allocator, moveWideZero32(.x0, 1));
            try words.append(allocator, restoreFrame());
            try words.append(allocator, returnInstruction());
            const success = words.items.len;
            try patch19(words.items, success_branch, success);
            try words.append(allocator, moveWideZero32(.x0, 0));
            try words.append(allocator, restoreFrame());
            try words.append(allocator, returnInstruction());
            break :entry offset;
        },
    };

    for (calls.items) |call| {
        if (call.function >= offsets.len) return error.InvalidMachineProgram;
        try patch26(words.items, call.at, offsets[call.function] / 4);
    }

    const code = try allocator.alloc(u8, words.items.len * 4);
    for (words.items, 0..) |word, index| std.mem.writeInt(u32, code[index * 4 ..][0..4], word, .little);
    return .{ .code = code, .function_offsets = offsets, .entry_offset = entry_offset };
}

fn encodeFunction(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    calls: *std.ArrayList(CallFixup),
    function: Machine.Function,
) Error!void {
    var fixups: FunctionFixups = .{};
    try words.append(allocator, saveFrame());
    try words.append(allocator, moveFramePointer());
    try emitStackAdjustment(allocator, words, function.frame_size, false);
    for (0..function.parameter_count) |index| {
        try words.append(allocator, storeStack(@enumFromInt(index), @intCast(index)));
    }

    for (function.instructions) |instruction| switch (instruction) {
        .constant_int => |constant| {
            try emitImmediate64(allocator, words, .x9, @bitCast(constant.value));
            try words.append(allocator, storeStack(.x9, constant.result));
        },
        .constant_bool => |constant| {
            try words.append(allocator, moveWideZero32(.x9, @intFromBool(constant.value)));
            try words.append(allocator, storeStack(.x9, constant.result));
        },
        .unary => |unary| {
            try words.append(allocator, loadStack(.x9, unary.operand));
            try emitImmediate64(allocator, words, .x10, @bitCast(@as(i64, std.math.minInt(i64))));
            try words.append(allocator, compareRegisters(.x9, .x10));
            try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.equal), .imm19);
            try words.append(allocator, subtractSetFlags(.x11, .zero_or_sp, .x9));
            try words.append(allocator, storeStack(.x11, unary.result));
        },
        .binary => |binary| try encodeBinary(allocator, words, &fixups, binary),
        .call => |call| {
            for (call.arguments, 0..) |argument, index| {
                try words.append(allocator, loadStack(@enumFromInt(index), argument));
            }
            try calls.append(allocator, .{ .at = words.items.len, .function = call.function });
            try words.append(allocator, branchLink());
            try appendFixup(allocator, words, &fixups.epilogue, compareBranchNonZero(.x8), .imm19);
            if (call.result) |result| try words.append(allocator, storeStack(.x0, result));
        },
        .return_value => |value| {
            try words.append(allocator, loadStack(.x0, value));
            try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.success)));
            try appendFixup(allocator, words, &fixups.epilogue, branch(), .imm26);
        },
        .return_void => {
            try words.append(allocator, moveWideZero32(.x0, 0));
            try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.success)));
            try appendFixup(allocator, words, &fixups.epilogue, branch(), .imm26);
        },
    };

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

fn encodeBinary(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    fixups: *FunctionFixups,
    binary: Machine.Instruction.Binary,
) Error!void {
    try words.append(allocator, loadStack(.x9, binary.left));
    try words.append(allocator, loadStack(.x10, binary.right));
    switch (binary.operator) {
        .add => {
            try words.append(allocator, addSetFlags(.x11, .x9, .x10));
            try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.overflow), .imm19);
            try words.append(allocator, storeStack(.x11, binary.result));
        },
        .subtract => {
            try words.append(allocator, subtractSetFlags(.x11, .x9, .x10));
            try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.overflow), .imm19);
            try words.append(allocator, storeStack(.x11, binary.result));
        },
        .multiply => {
            try words.append(allocator, multiply(.x11, .x9, .x10));
            try words.append(allocator, signedMultiplyHigh(.x12, .x9, .x10));
            try words.append(allocator, arithmeticShiftRight63(.x13, .x11));
            try words.append(allocator, compareRegisters(.x12, .x13));
            try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.not_equal), .imm19);
            try words.append(allocator, storeStack(.x11, binary.result));
        },
        .divide => {
            try appendFixup(allocator, words, &fixups.division_by_zero, compareBranchZero(.x10), .imm19);
            try emitImmediate64(allocator, words, .x11, @bitCast(@as(i64, std.math.minInt(i64))));
            try words.append(allocator, compareRegisters(.x9, .x11));
            const not_minimum = words.items.len;
            try words.append(allocator, conditionalBranch(.not_equal));
            try emitImmediate64(allocator, words, .x12, @bitCast(@as(i64, -1)));
            try words.append(allocator, compareRegisters(.x10, .x12));
            try appendFixup(allocator, words, &fixups.overflow, conditionalBranch(.equal), .imm19);
            try patch19(words.items, not_minimum, words.items.len);
            try words.append(allocator, signedDivide(.x11, .x9, .x10));
            try words.append(allocator, storeStack(.x11, binary.result));
        },
        .remainder => {
            try appendFixup(allocator, words, &fixups.division_by_zero, compareBranchZero(.x10), .imm19);
            try words.append(allocator, signedDivide(.x11, .x9, .x10));
            try words.append(allocator, multiplySubtract(.x12, .x11, .x10, .x9));
            try words.append(allocator, storeStack(.x12, binary.result));
        },
    }
}

fn emitImmediate64(allocator: Allocator, words: *std.ArrayList(u32), register: Register, value: u64) Allocator.Error!void {
    try words.append(allocator, moveWideZero64(register, @truncate(value), 0));
    try words.append(allocator, moveWideKeep64(register, @truncate(value >> 16), 1));
    try words.append(allocator, moveWideKeep64(register, @truncate(value >> 32), 2));
    try words.append(allocator, moveWideKeep64(register, @truncate(value >> 48), 3));
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

fn registerBits(register: Register) u32 {
    return @intFromEnum(register);
}

fn saveFrame() u32 {
    return 0xa9bf7bfd;
}

fn moveFramePointer() u32 {
    return 0x910003fd;
}

fn restoreFrame() u32 {
    return 0xa8c17bfd;
}

fn returnInstruction() u32 {
    return 0xd65f03c0;
}

fn moveRegister(destination: Register, source: Register) u32 {
    return 0xaa0003e0 | (registerBits(source) << 16) | registerBits(destination);
}

fn moveWideZero32(destination: Register, immediate: u16) u32 {
    return 0x52800000 | (@as(u32, immediate) << 5) | registerBits(destination);
}

fn moveWideZero64(destination: Register, immediate: u16, shift: u2) u32 {
    return 0xd2800000 | (@as(u32, shift) << 21) | (@as(u32, immediate) << 5) | registerBits(destination);
}

fn moveWideKeep64(destination: Register, immediate: u16, shift: u2) u32 {
    return 0xf2800000 | (@as(u32, shift) << 21) | (@as(u32, immediate) << 5) | registerBits(destination);
}

fn addSubtractImmediate(destination: Register, source: Register, immediate: u12, add: bool) u32 {
    return (if (add) @as(u32, 0x91000000) else 0xd1000000) |
        (@as(u32, immediate) << 10) |
        (registerBits(source) << 5) |
        registerBits(destination);
}

fn storeStack(source: Register, slot: Machine.Slot) u32 {
    return 0xf9000000 | (@as(u32, slot) << 10) | (registerBits(.zero_or_sp) << 5) | registerBits(source);
}

fn loadStack(destination: Register, slot: Machine.Slot) u32 {
    return 0xf9400000 | (@as(u32, slot) << 10) | (registerBits(.zero_or_sp) << 5) | registerBits(destination);
}

fn addSetFlags(destination: Register, left: Register, right: Register) u32 {
    return 0xab000000 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

fn subtractSetFlags(destination: Register, left: Register, right: Register) u32 {
    return 0xeb000000 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

fn multiply(destination: Register, left: Register, right: Register) u32 {
    return 0x9b007c00 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

fn signedMultiplyHigh(destination: Register, left: Register, right: Register) u32 {
    return 0x9b407c00 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

fn arithmeticShiftRight63(destination: Register, source: Register) u32 {
    return 0x9340fc00 | (63 << 16) | (registerBits(source) << 5) | registerBits(destination);
}

fn signedDivide(destination: Register, left: Register, right: Register) u32 {
    return 0x9ac00c00 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

fn multiplySubtract(destination: Register, left: Register, right: Register, accumulator: Register) u32 {
    return 0x9b008000 |
        (registerBits(right) << 16) |
        (registerBits(accumulator) << 10) |
        (registerBits(left) << 5) |
        registerBits(destination);
}

fn compareRegisters(left: Register, right: Register) u32 {
    return 0xeb00001f | (registerBits(right) << 16) | (registerBits(left) << 5);
}

const Condition = enum(u4) {
    equal = 0,
    not_equal = 1,
    overflow = 6,
};

fn conditionalBranch(condition: Condition) u32 {
    return 0x54000000 | @as(u32, @intFromEnum(condition));
}

fn compareBranchZero(register: Register) u32 {
    return 0x34000000 | registerBits(register);
}

fn compareBranchNonZero(register: Register) u32 {
    return 0x35000000 | registerBits(register);
}

fn branch() u32 {
    return 0x14000000;
}

fn branchLink() u32 {
    return 0x94000000;
}

test "encode known AArch64 instruction words" {
    try std.testing.expectEqual(@as(u32, 0xa9bf7bfd), saveFrame());
    try std.testing.expectEqual(@as(u32, 0x910003fd), moveFramePointer());
    try std.testing.expectEqual(@as(u32, 0xd2800540), moveWideZero64(.x0, 42, 0));
    try std.testing.expectEqual(@as(u32, 0xf90003e9), storeStack(.x9, 0));
    try std.testing.expectEqual(@as(u32, 0xf94003e9), loadStack(.x9, 0));
    try std.testing.expectEqual(@as(u32, 0xd65f03c0), returnInstruction());
}

test "resolve calls and append a native test entry" {
    const answer_instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .value = 42 } },
        .{ .return_value = 0 },
    };
    const functions = [_]Machine.Function{.{
        .name = "answer",
        .parameter_count = 0,
        .return_type = .int,
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
    const call_word = image.entry_offset.? / 4 + 2;
    const delta: i32 = -@as(i32, @intCast(call_word));
    const expected = @as(u32, 0x94000000) | (@as(u32, @bitCast(delta)) & 0x03ffffff);
    const encoded_call = std.mem.readInt(u32, image.code[call_word * 4 ..][0..4], .little);
    try std.testing.expectEqual(@as(u32, 0xa9bf7bfd), entry_word);
    try std.testing.expectEqual(expected, encoded_call);
}
