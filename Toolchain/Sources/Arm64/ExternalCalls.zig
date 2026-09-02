const std = @import("std");
const Instructions = @import("Instructions.zig");
const Machine = @import("Machine.zig");
const MathBoundary = @import("../Math/Boundary.zig");
const System = @import("System.zig");

const Allocator = std.mem.Allocator;
const Register = Instructions.Register;
pub const Error = Machine.Error || error{UnsupportedInstruction};

pub const Site = struct {
    instruction_offset: u32,
    function: usize,
    windows_symbol: ?@import("../Windows/Imports.zig").Symbol = null,
};

pub fn emit(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    sites: *std.ArrayList(Site),
    platform: System.Platform,
    program: Machine.Program,
    function: Machine.Function,
    call: Machine.Instruction.ExternalCall,
) Error!void {
    if (call.function >= program.external_functions.len) return error.InvalidMachineProgram;
    const external = program.external_functions[call.function];
    if (external.signature.arguments.len != call.arguments.len) return error.InvalidMachineProgram;

    if (platform == .linux and !external.package_private and MathBoundary.identify(external.source_name) == null) {
        if (!std.mem.eql(u8, external.provider, "Linux.kernel")) return error.UnsupportedInstruction;
        if (call.arguments.len > 6) return error.TooManyArguments;
        for (call.arguments, 0..) |argument, index| {
            try loadValue(allocator, words, function, @enumFromInt(index), argument);
        }
        const number: u16 = if (std.mem.eql(u8, external.source_name, "read") and call.arguments.len == 3)
            63
        else if (std.mem.eql(u8, external.source_name, "write") and call.arguments.len == 3)
            64
        else if (std.mem.eql(u8, external.source_name, "clock_gettime") and call.arguments.len == 2)
            113
        else if (std.mem.eql(u8, external.source_name, "getpid") and call.arguments.len == 0)
            172
        else if (std.mem.eql(u8, external.source_name, "getrandom") and call.arguments.len == 3)
            278
        else if (std.mem.eql(u8, external.source_name, "exit") and call.arguments.len == 1)
            93
        else
            return error.UnsupportedInstruction;
        try System.emitUnixCall(allocator, words, platform, number);
        if (call.result) |result| try storeValue(allocator, words, function, .x0, result);
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
    // x8 is caller-clobbered by AAPCS64 but carries the private Silex status
    // between generated calls. A successful C Boundary call starts a fresh
    // success status explicitly.
    try words.append(allocator, Instructions.moveWideZero32(.x8, 0));
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
    try words.append(allocator, Instructions.moveWideZero32(.x8, 0));
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
