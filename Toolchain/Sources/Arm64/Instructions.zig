const Machine = @import("Machine.zig");

pub const Register = enum(u5) {
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

pub fn registerBits(register: Register) u32 {
    return @intFromEnum(register);
}

pub fn saveFrame() u32 {
    return 0xa9bf7bfd;
}

pub fn moveFramePointer() u32 {
    return 0x910003fd;
}

pub fn restoreFrame() u32 {
    return 0xa8c17bfd;
}

pub fn returnInstruction() u32 {
    return 0xd65f03c0;
}

pub fn moveRegister(destination: Register, source: Register) u32 {
    return 0xaa0003e0 | (registerBits(source) << 16) | registerBits(destination);
}

pub fn moveWideZero32(destination: Register, immediate: u16) u32 {
    return 0x52800000 | (@as(u32, immediate) << 5) | registerBits(destination);
}

pub fn moveWideZero64(destination: Register, immediate: u16, shift: u2) u32 {
    return 0xd2800000 | (@as(u32, shift) << 21) | (@as(u32, immediate) << 5) | registerBits(destination);
}

pub fn moveWideKeep64(destination: Register, immediate: u16, shift: u2) u32 {
    return 0xf2800000 | (@as(u32, shift) << 21) | (@as(u32, immediate) << 5) | registerBits(destination);
}

pub fn addSubtractImmediate(destination: Register, source: Register, immediate: u12, add: bool) u32 {
    return (if (add) @as(u32, 0x91000000) else 0xd1000000) |
        (@as(u32, immediate) << 10) |
        (registerBits(source) << 5) |
        registerBits(destination);
}

pub fn storeStack(source: Register, slot: Machine.Slot) u32 {
    return 0xf9000000 | (@as(u32, slot) << 10) | (registerBits(.zero_or_sp) << 5) | registerBits(source);
}

pub fn loadStack(destination: Register, slot: Machine.Slot) u32 {
    return 0xf9400000 | (@as(u32, slot) << 10) | (registerBits(.zero_or_sp) << 5) | registerBits(destination);
}

pub fn storeByte(source: Register, base: Register) u32 {
    return 0x39000000 | (registerBits(base) << 5) | registerBits(source);
}

pub fn store64(source: Register, base: Register, byte_offset: u12) u32 {
    return 0xf9000000 |
        ((@as(u32, byte_offset) / 8) << 10) |
        (registerBits(base) << 5) |
        registerBits(source);
}

pub fn load64(destination: Register, base: Register, byte_offset: u12) u32 {
    return 0xf9400000 |
        ((@as(u32, byte_offset) / 8) << 10) |
        (registerBits(base) << 5) |
        registerBits(destination);
}

pub fn loadByte(destination: Register, base: Register) u32 {
    return 0x39400000 | (registerBits(base) << 5) | registerBits(destination);
}

pub fn addRegisters(destination: Register, left: Register, right: Register) u32 {
    return 0x8b000000 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

pub fn addressRelative(destination: Register) u32 {
    return 0x10000000 | registerBits(destination);
}

pub fn serviceCall() u32 {
    return 0xd4001001;
}

pub fn addSetFlags(destination: Register, left: Register, right: Register) u32 {
    return 0xab000000 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

pub fn subtractSetFlags(destination: Register, left: Register, right: Register) u32 {
    return 0xeb000000 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

pub fn multiply(destination: Register, left: Register, right: Register) u32 {
    return 0x9b007c00 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

pub fn signedMultiplyHigh(destination: Register, left: Register, right: Register) u32 {
    return 0x9b407c00 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

pub fn unsignedMultiplyHigh(destination: Register, left: Register, right: Register) u32 {
    return 0x9bc07c00 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

pub fn arithmeticShiftRight63(destination: Register, source: Register) u32 {
    return 0x9340fc00 | (63 << 16) | (registerBits(source) << 5) | registerBits(destination);
}

pub fn signedDivide(destination: Register, left: Register, right: Register) u32 {
    return 0x9ac00c00 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

pub fn unsignedDivide(destination: Register, left: Register, right: Register) u32 {
    return 0x9ac00800 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

pub fn andRegisters(destination: Register, left: Register, right: Register) u32 {
    return 0x8a000000 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

pub fn exclusiveOrRegisters(destination: Register, left: Register, right: Register) u32 {
    return 0xca000000 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

pub fn logicalShiftLeftVariable(destination: Register, left: Register, right: Register) u32 {
    return 0x9ac02000 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

pub fn logicalShiftRightVariable(destination: Register, left: Register, right: Register) u32 {
    return 0x9ac02400 | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

pub fn signExtendRegister(destination: Register, source: Register, width: u7) u32 {
    const immr: u32 = 0;
    const imms: u32 = width - 1;
    return 0x93400000 | (immr << 16) | (imms << 10) | (registerBits(source) << 5) | registerBits(destination);
}

pub fn moveGeneralToFloat(destination: Register, source: Register, double: bool) u32 {
    const base: u32 = if (double) 0x9e670000 else 0x1e270000;
    return base | (registerBits(source) << 5) | registerBits(destination);
}

pub fn moveFloatToGeneral(destination: Register, source: Register, double: bool) u32 {
    const base: u32 = if (double) 0x9e660000 else 0x1e260000;
    return base | (registerBits(source) << 5) | registerBits(destination);
}

pub fn floatNegate(destination: Register, source: Register, double: bool) u32 {
    const base: u32 = if (double) 0x1e614000 else 0x1e214000;
    return base | (registerBits(source) << 5) | registerBits(destination);
}

pub fn floatArithmetic(
    destination: Register,
    left: Register,
    right: Register,
    operator: Machine.BinaryOperator,
    double: bool,
) u32 {
    const base: u32 = switch (operator) {
        .add => if (double) 0x1e602800 else 0x1e202800,
        .subtract => if (double) 0x1e603800 else 0x1e203800,
        .multiply => if (double) 0x1e600800 else 0x1e200800,
        .divide => if (double) 0x1e601800 else 0x1e201800,
        else => unreachable,
    };
    return base | (registerBits(right) << 16) | (registerBits(left) << 5) | registerBits(destination);
}

pub fn floatCompare(left: Register, right: Register, double: bool) u32 {
    const base: u32 = if (double) 0x1e602000 else 0x1e202000;
    return base | (registerBits(right) << 16) | (registerBits(left) << 5);
}

pub fn integerToFloat(destination: Register, source: Register, signed: bool, double: bool) u32 {
    const base: u32 = if (signed)
        (if (double) 0x9e620000 else 0x9e220000)
    else
        (if (double) 0x9e630000 else 0x9e230000);
    return base | (registerBits(source) << 5) | registerBits(destination);
}

pub fn floatToInteger(destination: Register, source: Register, signed: bool, double: bool) u32 {
    const base: u32 = if (signed)
        (if (double) 0x9e780000 else 0x9e380000)
    else
        (if (double) 0x9e790000 else 0x9e390000);
    return base | (registerBits(source) << 5) | registerBits(destination);
}

pub fn floatConvert(destination: Register, source: Register, to_double: bool) u32 {
    const base: u32 = if (to_double) 0x1e22c000 else 0x1e624000;
    return base | (registerBits(source) << 5) | registerBits(destination);
}

pub fn multiplySubtract(destination: Register, left: Register, right: Register, accumulator: Register) u32 {
    return 0x9b008000 |
        (registerBits(right) << 16) |
        (registerBits(accumulator) << 10) |
        (registerBits(left) << 5) |
        registerBits(destination);
}

pub fn compareRegisters(left: Register, right: Register) u32 {
    return 0xeb00001f | (registerBits(right) << 16) | (registerBits(left) << 5);
}

pub const Condition = enum(u4) {
    equal = 0,
    not_equal = 1,
    carry_set = 2,
    carry_clear = 3,
    minus = 4,
    plus = 5,
    overflow = 6,
    higher = 8,
    lower_or_same = 9,
    greater_equal = 10,
    less = 11,
    greater = 12,
    less_equal = 13,
};

pub fn conditionalBranch(condition: Condition) u32 {
    return 0x54000000 | @as(u32, @intFromEnum(condition));
}

pub fn compareBranchZero(register: Register) u32 {
    return 0x34000000 | registerBits(register);
}

pub fn compareBranchZero64(register: Register) u32 {
    return 0xb4000000 | registerBits(register);
}

pub fn compareBranchNonZero(register: Register) u32 {
    return 0x35000000 | registerBits(register);
}

pub fn compareBranchNonZero64(register: Register) u32 {
    return 0xb5000000 | registerBits(register);
}

pub fn branch() u32 {
    return 0x14000000;
}

pub fn branchLink() u32 {
    return 0x94000000;
}
