const std = @import("std");
const Instructions = @import("Instructions.zig");
const Machine = @import("Machine.zig");

const Allocator = std.mem.Allocator;
const Register = Instructions.Register;

pub const Site = struct {
    instruction_offset: u32,
    function: usize,
};

pub fn emit(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    sites: *std.ArrayList(Site),
    function: Machine.Function,
    call: Machine.Instruction.ExternalCall,
) Allocator.Error!void {
    for (call.arguments, 0..) |argument, index| {
        try loadValue(allocator, words, function, @enumFromInt(index), argument);
    }
    try sites.append(allocator, .{
        .instruction_offset = @intCast(words.items.len * @sizeOf(u32)),
        .function = call.function,
    });
    try words.append(allocator, Instructions.addressPage(.x16));
    try words.append(allocator, Instructions.load64(.x16, .x16, 0));
    try words.append(allocator, Instructions.branchLinkRegister(.x16));
    if (call.result) |result| try storeValue(allocator, words, function, .x0, result);
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
