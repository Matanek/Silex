const std = @import("std");
const Instructions = @import("Instructions.zig");
const Machine = @import("Machine.zig");

const Allocator = std.mem.Allocator;
const Register = Instructions.Register;

pub const Site = struct {
    instruction_offset: u32,
    function: usize,
    windows_symbol: ?@import("../Windows/Imports.zig").Symbol = null,
};

pub fn emit(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    sites: *std.ArrayList(Site),
    program: Machine.Program,
    function: Machine.Function,
    call: Machine.Instruction.ExternalCall,
) Machine.Error!void {
    if (call.function >= program.external_functions.len) return error.InvalidMachineProgram;
    const external = program.external_functions[call.function];
    if (external.signature.arguments.len != call.arguments.len) return error.InvalidMachineProgram;
    if (@import("MemoryResidence.zig").copySignPrecision(external)) |double| {
        const result = call.result orelse return;
        // copysign is a bit operation: preserve payloads, infinities, subnormals
        // and signed zeros without a C call or floating-point arithmetic.
        try loadValue(allocator, words, function, .x9, call.arguments[0]);
        try loadValue(allocator, words, function, .x10, call.arguments[1]);
        try words.append(allocator, Instructions.exclusiveOrRegisters(.x10, .x10, .x9));
        try words.append(allocator, Instructions.moveWideZero64(.x11, 0x8000, if (double) 3 else 1));
        try words.append(allocator, Instructions.andRegisters(.x10, .x10, .x11));
        try words.append(allocator, Instructions.exclusiveOrRegisters(.x9, .x9, .x10));
        if (!double) try words.append(allocator, Instructions.zeroExtendRegister(.x9, .x9, 32));
        try storeValue(allocator, words, function, .x9, result);
        return;
    }

    var has_float = false;
    for (external.signature.arguments) |kind| if (kind == .float32 or kind == .float64) {
        has_float = true;
        break;
    };
    if (!has_float) {
        for (call.arguments[0..@min(call.arguments.len, Machine.max_register_arguments)], 0..) |argument, index| {
            try loadValue(allocator, words, function, @enumFromInt(index), argument);
        }
    } else {
        var integer_index: usize = 0;
        var float_index: usize = 0;
        for (call.arguments, external.signature.arguments) |argument, kind| {
            if (kind == .float32 or kind == .float64) {
                if (float_index >= 8) return error.TooManyArguments;
                try loadValue(allocator, words, function, .x9, argument);
                try words.append(allocator, Instructions.moveGeneralToFloat(@enumFromInt(float_index), .x9, kind == .float64));
                float_index += 1;
            } else {
                if (integer_index >= 8) return error.TooManyArguments;
                try loadValue(allocator, words, function, @enumFromInt(integer_index), argument);
                integer_index += 1;
            }
        }
    }
    if (!has_float and call.arguments.len > 8) try loadValue(allocator, words, function, .x14, call.arguments[8]);
    if (!has_float and call.arguments.len > 9) try loadValue(allocator, words, function, .x15, call.arguments[9]);
    if (!has_float and call.arguments.len > 8) {
        try words.append(allocator, Instructions.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 16, false));
        try words.append(allocator, Instructions.store64(.x14, .zero_or_sp, 0));
        if (call.arguments.len > 9) try words.append(allocator, Instructions.store64(.x15, .zero_or_sp, 8));
    }
    try sites.append(allocator, .{
        .instruction_offset = @intCast(words.items.len * @sizeOf(u32)),
        .function = call.function,
    });
    try words.append(allocator, Instructions.addressPage(.x16));
    try words.append(allocator, Instructions.load64(.x16, .x16, 0));
    try words.append(allocator, Instructions.branchLinkRegister(.x16));
    if (!has_float and call.arguments.len > 8) try words.append(allocator, Instructions.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 16, true));
    if (call.result) |result| {
        if (external.signature.result == .float32 or external.signature.result == .float64) {
            try words.append(allocator, Instructions.moveFloatToGeneral(.x9, .x0, external.signature.result == .float64));
            try storeValue(allocator, words, function, .x9, result);
        } else {
            if (external.signature.result == .uint8) try words.append(allocator, Instructions.zeroExtendRegister(.x0, .x0, 8));
            try storeValue(allocator, words, function, .x0, result);
        }
    }
}

pub fn emitIndirect(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    call: Machine.Instruction.ExternalIndirectCall,
) Machine.Error!void {
    if (call.signature.arguments.len != call.arguments.len or
        call.arguments.len > Machine.max_external_arguments)
    {
        return error.InvalidMachineProgram;
    }
    try loadValue(allocator, words, function, .x16, call.callee);
    var has_float = false;
    for (call.signature.arguments) |kind| if (kind == .float32 or kind == .float64) {
        has_float = true;
        break;
    };
    if (!has_float) {
        for (call.arguments[0..@min(call.arguments.len, Machine.max_register_arguments)], 0..) |argument, index| {
            try loadValue(allocator, words, function, @enumFromInt(index), argument);
        }
    } else {
        var integer_index: usize = 0;
        var float_index: usize = 0;
        for (call.arguments, call.signature.arguments) |argument, kind| {
            if (kind == .float32 or kind == .float64) {
                if (float_index >= 8) return error.TooManyArguments;
                try loadValue(allocator, words, function, .x9, argument);
                try words.append(allocator, Instructions.moveGeneralToFloat(@enumFromInt(float_index), .x9, kind == .float64));
                float_index += 1;
            } else {
                if (integer_index >= 8) return error.TooManyArguments;
                try loadValue(allocator, words, function, @enumFromInt(integer_index), argument);
                integer_index += 1;
            }
        }
    }
    if (!has_float and call.arguments.len > 8) try loadValue(allocator, words, function, .x14, call.arguments[8]);
    if (!has_float and call.arguments.len > 9) try loadValue(allocator, words, function, .x15, call.arguments[9]);
    if (!has_float and call.arguments.len > 8) {
        try words.append(allocator, Instructions.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 16, false));
        try words.append(allocator, Instructions.store64(.x14, .zero_or_sp, 0));
        if (call.arguments.len > 9) try words.append(allocator, Instructions.store64(.x15, .zero_or_sp, 8));
    }
    try words.append(allocator, Instructions.branchLinkRegister(.x16));
    if (!has_float and call.arguments.len > 8) try words.append(allocator, Instructions.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 16, true));
    if (call.result) |result| {
        if (call.signature.result == .float32 or call.signature.result == .float64) {
            try words.append(allocator, Instructions.moveFloatToGeneral(.x9, .x0, call.signature.result == .float64));
            try storeValue(allocator, words, function, .x9, result);
        } else {
            if (call.signature.result == .uint8) try words.append(allocator, Instructions.zeroExtendRegister(.x0, .x0, 8));
            try storeValue(allocator, words, function, .x0, result);
        }
    }
}

fn loadValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    destination: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    if (function.register_slots.len != 0) if (function.register_slots[slot]) |number| {
        const source: Register = @enumFromInt(number);
        if (source != destination) try words.append(allocator, Instructions.moveRegister(destination, source));
        return;
    };
    try words.append(allocator, Instructions.loadStack(destination, slot));
}

fn storeValue(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    source: Register,
    slot: Machine.Slot,
) Allocator.Error!void {
    if (function.register_slots.len != 0) if (function.register_slots[slot]) |number| {
        const destination: Register = @enumFromInt(number);
        if (source != destination) try words.append(allocator, Instructions.moveRegister(destination, source));
        return;
    };
    try words.append(allocator, Instructions.storeStack(source, slot));
}

test "inline copysign preserves every IEEE payload bit except the sign" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    const Runner = @import("Runner.zig");
    const RegisterAllocation = @import("RegisterAllocation.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_]bool{ false, true }) |double| {
        const kind: Machine.AbiValue = if (double) .float64 else .float32;
        const external: Machine.ExternalFunction = .{
            .provider = "Darwin.lib_system",
            .source_name = if (double) "copysign" else "copysignf",
            .signature = .{ .arguments = &.{ kind, kind }, .result = kind },
        };
        const call: Machine.Instruction.ExternalCall = .{ .result = 2, .function = 0, .arguments = &.{ 0, 1 } };
        const instructions = [_]Machine.Instruction{
            .{ .external_call = call },
            .{ .return_value = .{ .start = 2, .width = 1 } },
        };
        var function: Machine.Function = .{
            .name = "copy_sign_bits",
            .parameter_count = 2,
            .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
            .return_type = .uint,
            .return_width = 1,
            .slot_count = 3,
            .frame_size = try Machine.frameSize(3),
            .instructions = &instructions,
        };
        const allocation = try RegisterAllocation.allocateWithExternals(allocator, function, &.{external});
        function.register_slots = allocation.residences;
        function.float_register_slots = allocation.float_residences;
        function.float_lane_slots = allocation.float_lane_residences;
        const program: Machine.Program = .{ .functions = &.{function}, .external_functions = &.{external} };
        var words: std.ArrayList(u32) = .empty;
        var sites: std.ArrayList(Site) = .empty;
        try emit(allocator, &words, &sites, program, function, call);
        try std.testing.expectEqual(@as(usize, 0), sites.items.len);
        const before_ignored = words.items.len;
        try emit(allocator, &words, &sites, program, function, .{ .result = null, .function = 0, .arguments = &.{ 0, 1 } });
        try std.testing.expectEqual(before_ignored, words.items.len);
        const sign: u64 = if (double) 0x8000000000000000 else 0x80000000;
        const infinity: u64 = if (double) 0x7ff0000000000000 else 0x7f800000;
        const quiet: u64 = if (double) 0x0008000000000000 else 0x00400000;
        // Both NaN classes, infinities, subnormals, zeros and ordinary values.
        for ([_]u64{ 0, 1, infinity, infinity | 1, infinity | quiet | 0xabcde, 0x12345678 }) |payload| {
            for ([_]u64{ payload, payload | sign }) |magnitude| {
                for ([_]u64{ 0, sign }) |direction| {
                    const result = try Runner.invoke(allocator, program, 0, &.{ @bitCast(magnitude), @bitCast(direction) });
                    try std.testing.expectEqual(Machine.Status.success, result.status);
                    try std.testing.expectEqual(payload | direction, @as(u64, @bitCast(result.value)));
                }
            }
        }
    }
}
