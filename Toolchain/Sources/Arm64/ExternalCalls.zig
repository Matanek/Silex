const std = @import("std");
const Instructions = @import("Instructions.zig");
const Machine = @import("Machine.zig");
const MathBoundary = @import("../Math/Boundary.zig");
const System = @import("System.zig");
const CAbi = @import("CAbi.zig");

const Allocator = std.mem.Allocator;
const Register = Instructions.Register;
pub const Error = Machine.Error || error{UnsupportedInstruction};

pub const Site = struct {
    instruction_offset: u32,
    function: usize,
    windows_symbol: ?@import("../Windows/Imports.zig").Symbol = null,
    heap_operation: ?enum { allocate, release } = null,
    heap_preserves_scratch: bool = true,
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
    if (@import("MemoryResidence.zig").squareRootPrecision(external)) |double| if (call.result) |result| {
        const source = if (floatLaneResidence(function, call.arguments[0])) |lane| source: {
            try words.append(allocator, Instructions.duplicateFloat32Lane(.x9, @enumFromInt(lane.register), lane.lane));
            break :source Register.x9;
        } else floatResidence(function, call.arguments[0]) orelse source: {
            try loadValue(allocator, words, function, .x9, call.arguments[0]);
            try words.append(allocator, Instructions.moveGeneralToFloat(.x9, .x9, double));
            break :source .x9;
        };
        const destination = if (floatLaneResidence(function, result) != null) Register.x9 else floatResidence(function, result) orelse .x9;
        try words.append(allocator, Instructions.floatSquareRoot(destination, source, double));
        if (floatLaneResidence(function, result)) |lane| {
            try words.append(allocator, Instructions.insertFloat32Lane(@enumFromInt(lane.register), destination, lane.lane));
        } else if (floatResidence(function, result) == null) {
            try words.append(allocator, Instructions.moveFloatToGeneral(.x9, destination, double));
            try storeValue(allocator, words, function, .x9, result);
        }
        return;
    };
    if (@import("MemoryResidence.zig").copySignPrecision(external)) |double| {
        const result = call.result orelse return;
        // copysign is a bit operation: preserve payloads, infinities, subnormals
        // and signed zeros without a C call or floating-point arithmetic.
        try loadFloatBits(allocator, words, function, .x9, call.arguments[0], double);
        try loadFloatBits(allocator, words, function, .x10, call.arguments[1], double);
        try words.append(allocator, Instructions.exclusiveOrRegisters(.x10, .x10, .x9));
        try words.append(allocator, Instructions.moveWideZero64(.x11, 0x8000, if (double) 3 else 1));
        try words.append(allocator, Instructions.andRegisters(.x10, .x10, .x11));
        try words.append(allocator, Instructions.exclusiveOrRegisters(.x9, .x9, .x10));
        if (!double) try words.append(allocator, Instructions.zeroExtendRegister(.x9, .x9, 32));
        try storeFloatBits(allocator, words, function, .x9, result, double);
        return;
    }

    if (platform == .linux and !external.package_private and
        MathBoundary.identify(external.source_name) == null and
        std.mem.eql(u8, external.provider, "Linux.kernel"))
    {
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
        else if (std.mem.eql(u8, external.source_name, "newfstatat") and call.arguments.len == 4)
            79
        else if (std.mem.eql(u8, external.source_name, "exit") and call.arguments.len == 1)
            93
        else
            return error.UnsupportedInstruction;
        try System.emitUnixCall(allocator, words, platform, number);
        if (call.result) |result| try storeValue(allocator, words, function, .x0, result);
        return;
    }

    const stack_size = try emitCArguments(allocator, words, function, platform, external.signature, call.arguments);
    try sites.append(allocator, .{ .instruction_offset = @intCast(words.items.len * 4), .function = call.function });
    try words.appendSlice(allocator, &.{ Instructions.addressPage(.x16), Instructions.load64(.x16, .x16, 0), Instructions.branchLinkRegister(.x16) });
    try finishC(allocator, words, function, external.signature, call.result, stack_size);
}

pub fn emitIndirect(allocator: Allocator, words: *std.ArrayList(u32), platform: System.Platform, function: Machine.Function, call: Machine.Instruction.ExternalIndirectCall) Machine.Error!void {
    if (call.signature.arguments.len != call.arguments.len or call.arguments.len > Machine.max_external_arguments) return error.InvalidMachineProgram;
    try loadValue(allocator, words, function, .x16, call.callee);
    const stack_size = try emitCArguments(allocator, words, function, platform, call.signature, call.arguments);
    try words.append(allocator, Instructions.branchLinkRegister(.x16));
    try finishC(allocator, words, function, call.signature, call.result, stack_size);
}

fn loadCBits(allocator: Allocator, words: *std.ArrayList(u32), function: Machine.Function, kind: Machine.AbiValue, destination: Register, slot: Machine.Slot, stack_base: Register) !void {
    if (CAbi.floating(kind) and (floatResidence(function, slot) != null or floatLaneResidence(function, slot) != null)) {
        try loadFloatBits(allocator, words, function, destination, slot, kind == .float64);
    } else if (function.register_slots.len != 0 and function.register_slots[slot] != null) {
        try loadValue(allocator, words, function, destination, slot);
    } else try words.append(allocator, Instructions.loadStackFrom(destination, slot, stack_base));
}
fn emitCArguments(allocator: Allocator, words: *std.ArrayList(u32), function: Machine.Function, platform: System.Platform, signature: Machine.ExternalFunction.Signature, arguments: []const Machine.Slot) Machine.Error!u12 {
    const native = try CAbi.plan(allocator, .arm64, platform, signature);
    defer native.deinit(allocator);
    const temporary = try allocator.alloc(usize, arguments.len);
    defer allocator.free(temporary);
    var stack_size: usize = native.stack_size;
    for (native.arguments, 0..) |argument, index| {
        temporary[index] = 0;
        if (argument.indirect) {
            stack_size = std.mem.alignForward(usize, stack_size, 16);
            temporary[index] = stack_size;
            stack_size += CAbi.width(signature, index) * 8;
        }
    }
    stack_size = std.mem.alignForward(usize, stack_size, 16);
    if (stack_size > 4080) return error.FrameTooLarge;
    if (stack_size != 0) try words.append(allocator, Instructions.addSubtractImmediate(.zero_or_sp, .zero_or_sp, @intCast(stack_size), false));
    // Slot homes are relative to the caller's original SP. Native stack
    // arguments and indirect record copies live below it, on a separate frame.
    const stack_base: Register = if (stack_size == 0) .zero_or_sp else .x17;
    if (stack_size != 0) try words.append(allocator, Instructions.addSubtractImmediate(.x17, .zero_or_sp, @intCast(stack_size), true));
    for (native.arguments, arguments, 0..) |argument, slot, index| if (argument.indirect) {
        for (CAbi.fields(signature, index), 0..) |kind, leaf| {
            try loadCBits(allocator, words, function, kind, .x9, @intCast(@as(usize, slot) + leaf), stack_base);
            try words.append(allocator, Instructions.store64(.x9, .zero_or_sp, @intCast(temporary[index] + leaf * 8)));
        }
    };
    for (native.arguments, arguments, signature.arguments, 0..) |argument, slot, kind, index| {
        const leaves = CAbi.fields(signature, index);
        for (argument.locations, 0..) |location, leaf| {
            const leaf_kind = if (argument.indirect) Machine.AbiValue.read_address else if (kind == .record) leaves[leaf] else kind;
            if (argument.indirect) try words.append(allocator, Instructions.addSubtractImmediate(.x9, .zero_or_sp, @intCast(temporary[index]), true)) else try loadCBits(allocator, words, function, leaf_kind, .x9, @intCast(@as(usize, slot) + leaf), stack_base);
            switch (location) {
                .general => |lane| try words.append(allocator, Instructions.moveRegister(@enumFromInt(lane), .x9)),
                .floating => |lane| try words.append(allocator, Instructions.moveGeneralToFloat(@enumFromInt(lane), .x9, leaf_kind == .float64)),
                .stack => |offset| {
                    try words.append(allocator, Instructions.addSubtractImmediate(.x10, .zero_or_sp, @intCast(offset), true));
                    const size = if (platform == .darwin) CAbi.scalarSize(leaf_kind) else 8;
                    try words.append(allocator, switch (size) {
                        1 => Instructions.storeByte(.x9, .x10),
                        2 => Instructions.store16(.x9, .x10),
                        4 => Instructions.store32(.x9, .x10),
                        else => Instructions.store64(.x9, .x10, 0),
                    });
                },
            }
        }
    }
    return @intCast(stack_size);
}
fn finishC(allocator: Allocator, words: *std.ArrayList(u32), function: Machine.Function, signature: Machine.ExternalFunction.Signature, result: ?Machine.Slot, stack_size: u12) !void {
    if (stack_size != 0) try words.append(allocator, Instructions.addSubtractImmediate(.zero_or_sp, .zero_or_sp, stack_size, true));
    try words.append(allocator, Instructions.moveWideZero32(.x8, 0));
    if (result) |slot| {
        if (CAbi.floating(signature.result.?)) {
            try words.append(allocator, Instructions.moveFloatToGeneral(.x9, .x0, signature.result == .float64));
            try storeValue(allocator, words, function, .x9, slot);
        } else {
            if (signature.result == .uint8) try words.append(allocator, Instructions.zeroExtendRegister(.x0, .x0, 8));
            if (signature.result == .uint16) try words.append(allocator, Instructions.zeroExtendRegister(.x0, .x0, 16));
            if (signature.result == .uint32) try words.append(allocator, Instructions.zeroExtendRegister(.x0, .x0, 32));
            if (signature.result_signed_32) try words.append(allocator, Instructions.signExtendRegister(.x0, .x0, 32));
            try storeValue(allocator, words, function, .x0, slot);
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

fn floatResidence(function: Machine.Function, slot: Machine.Slot) ?Register {
    if (function.float_register_slots.len != 0) if (function.float_register_slots[slot]) |number| {
        return @enumFromInt(number);
    };
    return null;
}

fn floatLaneResidence(function: Machine.Function, slot: Machine.Slot) ?Machine.FloatLaneResidence {
    if (function.float_lane_slots.len == 0) return null;
    return function.float_lane_slots[slot];
}

fn loadFloatBits(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    destination: Register,
    slot: Machine.Slot,
    double: bool,
) Allocator.Error!void {
    if (floatLaneResidence(function, slot)) |lane| {
        const source: Register = @enumFromInt(lane.register);
        if (lane.lane == 0) {
            try words.append(allocator, Instructions.moveFloatToGeneral(destination, source, false));
        } else {
            try words.append(allocator, Instructions.duplicateFloat32Lane(.x9, source, lane.lane));
            try words.append(allocator, Instructions.moveFloatToGeneral(destination, .x9, false));
        }
    } else if (floatResidence(function, slot)) |source| {
        try words.append(allocator, Instructions.moveFloatToGeneral(destination, source, double));
    } else try loadValue(allocator, words, function, destination, slot);
}

fn storeFloatBits(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    function: Machine.Function,
    source: Register,
    slot: Machine.Slot,
    double: bool,
) Allocator.Error!void {
    if (floatLaneResidence(function, slot)) |lane| {
        // A scalar FMOV clears the sibling lane. Insert only the result lane.
        try words.append(allocator, Instructions.moveGeneralToFloat(.x9, source, false));
        try words.append(allocator, Instructions.insertFloat32Lane(@enumFromInt(lane.register), .x9, lane.lane));
    } else if (floatResidence(function, slot)) |destination| {
        try words.append(allocator, Instructions.moveGeneralToFloat(destination, source, double));
    } else try storeValue(allocator, words, function, source, slot);
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
            .return_type = if (double) .float64 else .float32,
            .return_width = 1,
            .slot_count = 3,
            .frame_size = try Machine.frameSize(3),
            .instructions = &instructions,
        };
        const allocation = try RegisterAllocation.allocateWithExternals(allocator, function, &.{external});
        function.register_slots = allocation.residences;
        function.float_register_slots = allocation.float_residences;
        function.float_lane_slots = allocation.float_lane_residences;
        try std.testing.expect(function.float_register_slots[0] != null);
        try std.testing.expect(function.float_register_slots[1] != null);
        try std.testing.expect(function.float_register_slots[2] != null);
        const program: Machine.Program = .{ .functions = &.{function}, .external_functions = &.{external} };
        var words: std.ArrayList(u32) = .empty;
        var sites: std.ArrayList(Site) = .empty;
        try emit(allocator, &words, &sites, .darwin, program, function, call);
        try std.testing.expectEqual(@as(usize, 0), sites.items.len);
        const before_ignored = words.items.len;
        try emit(allocator, &words, &sites, .darwin, program, function, .{ .result = null, .function = 0, .arguments = &.{ 0, 1 } });
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

test "inline system square root uses scalar float residences and exact IEEE results" {
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
            .source_name = if (double) "sqrt" else "sqrtf",
            .signature = .{ .arguments = &.{kind}, .result = kind },
        };
        const call: Machine.Instruction.ExternalCall = .{ .result = 1, .function = 0, .arguments = &.{0} };
        var function: Machine.Function = .{
            .name = "resident_square_root",
            .parameter_count = 1,
            .parameters = &.{.{ .start = 0, .width = 1 }},
            .return_type = if (double) .float64 else .float32,
            .return_width = 1,
            .slot_count = 2,
            .frame_size = try Machine.frameSize(2),
            .instructions = &.{ .{ .external_call = call }, .{ .return_value = .{ .start = 1, .width = 1 } } },
        };
        const allocation = try RegisterAllocation.allocateWithExternals(allocator, function, &.{external});
        function.register_slots = allocation.residences;
        function.float_register_slots = allocation.float_residences;
        function.float_lane_slots = allocation.float_lane_residences;
        try std.testing.expect(function.float_register_slots[0] != null);
        try std.testing.expect(function.float_register_slots[1] != null);
        const program: Machine.Program = .{ .functions = &.{function}, .external_functions = &.{external} };
        const image = try @import("Encoder.zig").encode(allocator, program, .{ .test_function = 0 });
        try std.testing.expectEqual(@as(usize, 0), image.external_call_sites.len);
        const sign: u64 = if (double) 0x8000000000000000 else 0x80000000;
        const infinity: u64 = if (double) 0x7ff0000000000000 else 0x7f800000;
        const quiet_nan: u64 = infinity | (if (double) @as(u64, 0x0008000000001234) else 0x00401234);
        for ([_]u64{ 0, sign, 0x40800000, 0x4010000000000000, infinity, quiet_nan }) |bits| {
            if ((!double and bits > std.math.maxInt(u32)) or (double and bits != 0 and bits != sign and bits <= std.math.maxInt(u32))) continue;
            const result = try Runner.invoke(allocator, program, 0, &.{@bitCast(bits)});
            try std.testing.expectEqual(Machine.Status.success, result.status);
            if (double) {
                const value: f64 = @bitCast(bits);
                try std.testing.expectEqual(@as(u64, @bitCast(@sqrt(value))), @as(u64, @bitCast(result.value)));
            } else {
                const value: f32 = @bitCast(@as(u32, @truncate(bits)));
                try std.testing.expectEqual(@as(u32, @bitCast(@sqrt(value))), @as(u32, @truncate(@as(u64, @bitCast(result.value)))));
            }
        }
        var lookalike = external;
        lookalike.provider = "unrelated_library";
        const fallback = try RegisterAllocation.allocateWithExternals(allocator, function, &.{lookalike});
        try std.testing.expectEqual(@as(usize, 0), fallback.residences.len);
    }
}

test "Linux ARM64 links public system boundaries and normalizes int32 results" {
    const external_functions = [_]Machine.ExternalFunction{.{
        .provider = "Boundary.System",
        .source_name = "pthread_join",
        .signature = .{ .arguments = &.{ .uint64, .read_address }, .result = .int32, .result_signed_32 = true },
    }};
    const function: Machine.Function = .{
        .name = "test",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 3,
        .frame_size = try Machine.frameSize(3),
        .instructions = &.{},
    };
    var words: std.ArrayList(u32) = .empty;
    defer words.deinit(std.testing.allocator);
    var sites: std.ArrayList(Site) = .empty;
    defer sites.deinit(std.testing.allocator);

    try emit(
        std.testing.allocator,
        &words,
        &sites,
        .linux,
        .{ .functions = &.{function}, .external_functions = &external_functions },
        function,
        .{ .result = 2, .function = 0, .arguments = &.{ 0, 1 } },
    );

    try std.testing.expectEqual(@as(usize, 1), sites.items.len);
    try std.testing.expectEqual(
        Instructions.signExtendRegister(.x0, .x0, 32),
        words.items[words.items.len - 2],
    );
}

test "Linux ARM64 lowers the public newfstatat boundary to its native syscall" {
    const arguments = [_]Machine.AbiValue{ .int32, .read_address, .read_address, .int32 };
    const external_functions = [_]Machine.ExternalFunction{.{
        .provider = "Linux.kernel",
        .source_name = "newfstatat",
        .signature = .{ .arguments = &arguments, .result = .int32 },
    }};
    const function: Machine.Function = .{
        .name = "test",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 5,
        .frame_size = try Machine.frameSize(5),
        .instructions = &.{},
    };
    var words: std.ArrayList(u32) = .empty;
    defer words.deinit(std.testing.allocator);
    var sites: std.ArrayList(Site) = .empty;
    defer sites.deinit(std.testing.allocator);

    try emit(
        std.testing.allocator,
        &words,
        &sites,
        .linux,
        .{ .functions = &.{function}, .external_functions = &external_functions },
        function,
        .{ .result = 4, .function = 0, .arguments = &.{ 0, 1, 2, 3 } },
    );

    try std.testing.expectEqual(@as(usize, 0), sites.items.len);
    try std.testing.expectEqual(Instructions.moveWideZero32(.x8, 79), words.items[4]);
    try std.testing.expectEqual(Instructions.linuxServiceCall(), words.items[5]);
}

test "scalar math intrinsics read and preserve paired float32 lanes" {
    const builtin = @import("builtin");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_]bool{ false, true }) |square_root| {
        const external: Machine.ExternalFunction = .{
            .provider = "Darwin.lib_system",
            .source_name = if (square_root) "sqrtf" else "copysignf",
            .signature = .{
                .arguments = if (square_root) &.{.float32} else &.{ .float32, .float32 },
                .result = .float32,
            },
        };
        for ([_]u1{ 0, 1 }) |source_lane| {
            for ([_]u1{ 0, 1 }) |result_lane| {
                for ([_]Machine.Slot{ 2, 5 }) |returned| {
                    const call: Machine.Instruction.ExternalCall = .{
                        .result = 2,
                        .function = 0,
                        .arguments = if (square_root) &.{0} else &.{ 0, 1 },
                    };
                    var registers: [11]?u5 = @splat(null);
                    var lanes = [_]?Machine.FloatLaneResidence{
                        .{ .register = 16, .lane = source_lane, .partner = 3 },
                        .{ .register = 17, .lane = 1, .partner = 4 },
                        .{ .register = 18, .lane = result_lane, .partner = 5 },
                        .{ .register = 16, .lane = 1 - source_lane, .partner = 0 },
                        .{ .register = 17, .lane = 0, .partner = 1 },
                        .{ .register = 18, .lane = 1 - result_lane, .partner = 2 },
                        null,
                        null,
                        null,
                        null,
                        null,
                    };
                    var instructions = [_]Machine.Instruction{
                        .{ .constant_float32 = .{ .result = 6, .bits = @bitCast(@as(f32, 4.0)) } },
                        .{ .constant_float32 = .{ .result = 7, .bits = @bitCast(@as(f32, -1.0)) } },
                        .{ .constant_float32 = .{ .result = 8, .bits = @bitCast(@as(f32, 10.0)) } },
                        .{ .constant_float32 = .{ .result = 9, .bits = @bitCast(@as(f32, 12.0)) } },
                        .{ .constant_float32 = .{ .result = 10, .bits = @bitCast(@as(f32, 7.0)) } },
                        .{ .copy = .{ .result = 0, .operand = 6 } },
                        .{ .copy = .{ .result = 1, .operand = 7 } },
                        .{ .copy = .{ .result = 3, .operand = 8 } },
                        .{ .copy = .{ .result = 4, .operand = 9 } },
                        .{ .copy = .{ .result = 5, .operand = 10 } },
                        .{ .external_call = call },
                        .{ .return_value = .{ .start = returned, .width = 1 } },
                    };
                    const function: Machine.Function = .{
                        .name = "paired_scalar_intrinsic",
                        .parameter_count = 0,
                        .return_type = .float32,
                        .return_width = 1,
                        .slot_count = 11,
                        .frame_size = try Machine.frameSize(11),
                        .instructions = &instructions,
                        .float_register_slots = &registers,
                        .float_lane_slots = &lanes,
                    };
                    const program: Machine.Program = .{ .functions = &.{function}, .external_functions = &.{external} };
                    // All ARM64 system routes use the same lane operations.
                    for ([_]System.Platform{ .darwin, .linux, .windows }) |platform| {
                        var words: std.ArrayList(u32) = .empty;
                        var sites: std.ArrayList(Site) = .empty;
                        try emit(allocator, &words, &sites, platform, program, function, call);
                        try std.testing.expectEqual(@as(usize, 0), sites.items.len);
                        var inserts: usize = 0;
                        for (words.items) |word| {
                            if (word == Instructions.insertFloat32Lane(.x18, .x9, result_lane)) inserts += 1;
                        }
                        try std.testing.expectEqual(@as(usize, 1), inserts);
                    }
                    if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
                        const result = try @import("Runner.zig").invoke(allocator, program, 0, &.{});
                        try std.testing.expectEqual(Machine.Status.success, result.status);
                        const expected: f32 = if (returned == 5) 7.0 else if (square_root) 2.0 else -4.0;
                        try std.testing.expectEqual(@as(u32, @bitCast(expected)), @as(u32, @truncate(@as(u64, @bitCast(result.value)))));
                    }
                }
            }
        }
    }
}
