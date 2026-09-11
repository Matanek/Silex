const std = @import("std");
const Machine = @import("../Arm64/Machine.zig");
const Numeric = @import("../Numeric.zig");

const Allocator = std.mem.Allocator;
pub const Error = Allocator.Error || error{UnsupportedInstruction};

// RAX/RCX hold the operands, RAX receives the result; RDX is scratch/status.
// No resident or callee-saved register is touched. Error branches return through
// the owning function's existing epilogue, rather than a hardware exception.
pub fn binary(allocator: Allocator, bytes: *std.ArrayList(u8), value: Machine.Instruction.Binary, epilogue: anytype) Error!void {
    const signed = value.type.isSignedInteger();
    const width: u7 = if (value.type.isInteger()) value.type.bitWidth() else 64;
    if (value.operator == .shift_left or value.operator == .shift_right) {
        if (value.checked) {
            try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xf9, @intCast(width) }); // cmp rcx, width
            try guard(allocator, bytes, epilogue, 3, .integer_overflow); // unsigned >= catches negative counts too
        }
        try normalize(allocator, bytes, 0, width, false);
        try bytes.appendSlice(allocator, if (value.operator == .shift_left) &.{ 0x48, 0xd3, 0xe0 } else &.{ 0x48, 0xd3, 0xe8 });
        return normalize(allocator, bytes, 0, width, signed);
    }
    try normalize(allocator, bytes, 0, width, signed);
    try normalize(allocator, bytes, 1, width, signed);
    switch (value.operator) {
        .add, .subtract, .multiply => {
            switch (value.operator) {
                .add => try bytes.appendSlice(allocator, &.{ 0x48, 0x01, 0xc8 }),
                .subtract => try bytes.appendSlice(allocator, &.{ 0x48, 0x29, 0xc8 }),
                .multiply => try bytes.appendSlice(allocator, if (!signed and value.checked)
                    &.{ 0x48, 0xf7, 0xe1 } // mul rcx, with high product in rdx
                else
                    &.{ 0x48, 0x0f, 0xaf, 0xc1 }),
                else => unreachable,
            }
            if (value.checked) {
                try guard(allocator, bytes, epilogue, if (signed) 0 else 2, .integer_overflow);
                if (width < 64) {
                    try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0xc2 }); // mov rdx, rax
                    try normalize(allocator, bytes, 2, width, signed);
                    try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xd0 }); // cmp rax, rdx
                    try guard(allocator, bytes, epilogue, 5, .integer_overflow);
                }
            }
            try normalize(allocator, bytes, 0, width, signed);
        },
        .divide, .remainder => {
            if (value.checked) {
                try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc9 });
                try guard(allocator, bytes, epilogue, 4, .division_by_zero);
                if (signed) {
                    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xf9, 0xff, 0x75, 0 });
                    const skip_minimum = bytes.items.len - 1;
                    try immediateRdx(allocator, bytes, @bitCast(Numeric.integerMin(value.type)));
                    try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xd0 });
                    try guard(allocator, bytes, epilogue, 4, .integer_overflow);
                    bytes.items[skip_minimum] = @intCast(bytes.items.len - skip_minimum - 1);
                }
            }
            try bytes.appendSlice(allocator, if (signed)
                &.{ 0x48, 0x99, 0x48, 0xf7, 0xf9 }
            else
                &.{ 0x31, 0xd2, 0x48, 0xf7, 0xf1 });
            if (value.operator == .remainder) try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0xd0 });
            try normalize(allocator, bytes, 0, width, signed);
        },
        .bit_and, .bit_xor => {
            try bytes.appendSlice(allocator, if (value.operator == .bit_and) &.{ 0x48, 0x21, 0xc8 } else &.{ 0x48, 0x31, 0xc8 });
            try normalize(allocator, bytes, 0, width, signed);
        },
        .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => {
            const condition: u8 = switch (value.operator) {
                .less => if (signed) 0x9c else 0x92,
                .less_equal => if (signed) 0x9e else 0x96,
                .greater => if (signed) 0x9f else 0x97,
                .greater_equal => if (signed) 0x9d else 0x93,
                .equal => 0x94,
                .not_equal => 0x95,
                else => unreachable,
            };
            try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xc8, 0x0f, condition, 0xc0, 0x48, 0x0f, 0xb6, 0xc0 });
        },
        else => return error.UnsupportedInstruction,
    }
}

pub fn negate(allocator: Allocator, bytes: *std.ArrayList(u8), value_type: Numeric.Type, epilogue: anytype) Allocator.Error!void {
    const signed = value_type.isSignedInteger();
    const width = value_type.bitWidth();
    try normalize(allocator, bytes, 0, width, signed);
    if (!signed) {
        try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0 });
        try guard(allocator, bytes, epilogue, 5, .integer_overflow);
    }
    try bytes.appendSlice(allocator, &.{ 0x48, 0xf7, 0xd8 });
    if (signed) {
        try guard(allocator, bytes, epilogue, 0, .integer_overflow);
        if (width < 64) {
            try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0xc2 });
            try normalize(allocator, bytes, 2, width, true);
            try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xd0 });
            try guard(allocator, bytes, epilogue, 5, .integer_overflow);
        }
    }
    try normalize(allocator, bytes, 0, width, signed);
}

pub fn normalize(allocator: Allocator, bytes: *std.ArrayList(u8), register: u2, width: u7, signed: bool) Allocator.Error!void {
    if (width == 64) return;
    const modrm: u8 = 0xc0 | (@as(u8, register) * 9);
    switch (width) {
        8, 16 => try bytes.appendSlice(allocator, &.{ 0x48, 0x0f, if (signed) (if (width == 8) @as(u8, 0xbe) else 0xbf) else (if (width == 8) @as(u8, 0xb6) else 0xb7), modrm }),
        32 => try bytes.appendSlice(allocator, if (signed) &.{ 0x48, 0x63, modrm } else &.{ 0x89, modrm }),
        else => unreachable,
    }
}

fn immediateRdx(allocator: Allocator, bytes: *std.ArrayList(u8), bits: u64) Allocator.Error!void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0xba });
    var encoded: [8]u8 = undefined;
    std.mem.writeInt(u64, &encoded, bits, .little);
    try bytes.appendSlice(allocator, &encoded);
}

fn guard(allocator: Allocator, bytes: *std.ArrayList(u8), epilogue: anytype, failure_condition: u4, status: Machine.Status) Allocator.Error!void {
    // Invert the condition to skip mov edx,status + jmp epilogue on success.
    try bytes.appendSlice(allocator, &.{ 0x70 | @as(u8, failure_condition ^ 1), 10, 0xba });
    var encoded: [4]u8 = undefined;
    std.mem.writeInt(u32, &encoded, @intFromEnum(status), .little);
    try bytes.appendSlice(allocator, &encoded);
    try bytes.append(allocator, 0xe9);
    try epilogue.append(allocator, .{ .displacement_at = bytes.items.len });
    try bytes.appendNTimes(allocator, 0, 4);
}
