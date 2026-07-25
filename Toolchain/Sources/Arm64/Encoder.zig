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
    x14 = 14,
    x15 = 15,
    x16 = 16,
    x29 = 29,
    x30 = 30,
    zero_or_sp = 31,
};

const CallFixup = struct {
    at: usize,
    function: Machine.FunctionId,
};

const DataFixup = struct {
    at: usize,
    string: usize,
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
    var data_fixups: std.ArrayList(DataFixup) = .empty;

    for (program.functions, 0..) |function, function_id| {
        offsets[function_id] = @intCast(words.items.len * 4);
        try encodeFunction(allocator, &words, &calls, &data_fixups, program, function);
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

    const code_size = words.items.len * 4;
    const string_offsets = try allocator.alloc(usize, program.strings.len);
    defer allocator.free(string_offsets);
    var image_size = code_size;
    for (program.strings, 0..) |string, index| {
        string_offsets[index] = image_size;
        image_size += string.len;
    }
    for (data_fixups.items) |fixup| {
        if (fixup.string >= string_offsets.len) return error.InvalidMachineProgram;
        try patchAdr(words.items, fixup.at, string_offsets[fixup.string]);
    }

    const code = try allocator.alloc(u8, image_size);
    for (words.items, 0..) |word, index| std.mem.writeInt(u32, code[index * 4 ..][0..4], word, .little);
    var data_offset = code_size;
    for (program.strings) |string| {
        @memcpy(code[data_offset..][0..string.len], string);
        data_offset += string.len;
    }
    return .{ .code = code, .function_offsets = offsets, .entry_offset = entry_offset };
}

fn encodeFunction(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    calls: *std.ArrayList(CallFixup),
    data_fixups: *std.ArrayList(DataFixup),
    program: Machine.Program,
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
        .constant_str => |constant| {
            try emitImmediate64(allocator, words, .x9, constant.string);
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
        .print => |value| switch (value.kind) {
            .integer => try emitPrintInteger(allocator, words, value.value),
            .boolean => try emitPrintBoolean(allocator, words, data_fixups, program, value.value),
            .string => try emitPrintString(allocator, words, data_fixups, program, value.value, 1, true),
        },
        .assert => |assertion| {
            try words.append(allocator, loadStack(.x9, assertion.condition));
            const passed = words.items.len;
            try words.append(allocator, compareBranchNonZero(.x9));
            try emitWriteStatic(allocator, words, data_fixups, program, assertion.header, 2);
            try emitPrintString(allocator, words, data_fixups, program, assertion.message, 2, true);
            try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.runtime_failure)));
            try appendFixup(allocator, words, &fixups.epilogue, branch(), .imm26);
            try patch19(words.items, passed, words.items.len);
        },
        .panic => |panic_value| {
            try emitWriteStatic(allocator, words, data_fixups, program, panic_value.header, 2);
            try emitPrintString(allocator, words, data_fixups, program, panic_value.message, 2, true);
            try words.append(allocator, moveWideZero32(.x8, @intFromEnum(Machine.Status.runtime_failure)));
            try appendFixup(allocator, words, &fixups.epilogue, branch(), .imm26);
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
        .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => {
            try words.append(allocator, compareRegisters(.x9, .x10));
            try words.append(allocator, moveWideZero32(.x11, 0));
            const skip_true = words.items.len;
            try words.append(allocator, conditionalBranch(inverseComparison(binary.operator)));
            try words.append(allocator, moveWideZero32(.x11, 1));
            try patch19(words.items, skip_true, words.items.len);
            try words.append(allocator, storeStack(.x11, binary.result));
        },
    }
}

fn inverseComparison(operator: Machine.BinaryOperator) Condition {
    return switch (operator) {
        .less => .greater_equal,
        .less_equal => .greater,
        .greater => .less_equal,
        .greater_equal => .less,
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
    try emitWriteStatic(allocator, words, data_fixups, program, 0, 1);
}

fn emitPrintString(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(DataFixup),
    program: Machine.Program,
    slot: Machine.Slot,
    descriptor: u16,
    newline: bool,
) Error!void {
    try words.append(allocator, loadStack(.x9, slot));
    var targets: std.ArrayList(usize) = .empty;
    for (program.strings, 0..) |_, string_id| {
        try emitImmediate64(allocator, words, .x10, string_id);
        try words.append(allocator, compareRegisters(.x9, .x10));
        try targets.append(allocator, words.items.len);
        try words.append(allocator, conditionalBranch(.equal));
    }
    const invalid = words.items.len;
    try words.append(allocator, branch());
    var endings: std.ArrayList(usize) = .empty;
    for (program.strings, 0..) |_, string_id| {
        try patch19(words.items, targets.items[string_id], words.items.len);
        try emitWriteStatic(allocator, words, data_fixups, program, string_id, descriptor);
        try endings.append(allocator, words.items.len);
        try words.append(allocator, branch());
    }
    const end = words.items.len;
    try patch26(words.items, invalid, end);
    for (endings.items) |ending| try patch26(words.items, ending, end);
    if (newline) try emitWriteStatic(allocator, words, data_fixups, program, 0, descriptor);
}

fn emitWriteStatic(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(DataFixup),
    program: Machine.Program,
    string_id: usize,
    descriptor: u16,
) Error!void {
    if (string_id >= program.strings.len) return error.InvalidMachineProgram;
    try words.append(allocator, moveWideZero32(.x0, descriptor));
    try data_fixups.append(allocator, .{ .at = words.items.len, .string = string_id });
    try words.append(allocator, addressRelative(.x1));
    try emitImmediate64(allocator, words, .x2, program.strings[string_id].len);
    try words.append(allocator, moveWideZero32(.x16, 4));
    try words.append(allocator, serviceCall());
}

fn emitPrintInteger(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    slot: Machine.Slot,
) Error!void {
    try words.append(allocator, loadStack(.x9, slot));
    try words.append(allocator, addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, false));
    try words.append(allocator, addSubtractImmediate(.x11, .zero_or_sp, 31, true));
    try words.append(allocator, moveWideZero32(.x10, '\n'));
    try words.append(allocator, storeByte(.x10, .x11));
    try words.append(allocator, moveWideZero32(.x12, 1));

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

fn storeByte(source: Register, base: Register) u32 {
    return 0x39000000 | (registerBits(base) << 5) | registerBits(source);
}

fn addressRelative(destination: Register) u32 {
    return 0x10000000 | registerBits(destination);
}

fn serviceCall() u32 {
    return 0xd4001001;
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
    greater_equal = 10,
    less = 11,
    greater = 12,
    less_equal = 13,
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

fn compareBranchNonZero64(register: Register) u32 {
    return 0xb5000000 | registerBits(register);
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
