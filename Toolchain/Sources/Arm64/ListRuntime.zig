const std = @import("std");
const Machine = @import("Machine.zig");
const A64 = @import("Instructions.zig");
const Fixups = @import("Fixups.zig");
const StringRuntime = @import("StringRuntime.zig");
const ExternalCalls = @import("ExternalCalls.zig");
const Allocation = @import("Allocation.zig");

const Allocator = std.mem.Allocator;
pub const Error = Machine.Error || Allocator.Error || Fixups.Error;
const header_size: u12 = 5 * Machine.slot_size;
const root_count_offset: u12 = Machine.slot_size;
const edge_count_offset: u12 = 2 * Machine.slot_size;
const byte_count_offset: u12 = 3 * Machine.slot_size;
const state_offset: u12 = 4 * Machine.slot_size;
const darwin_page_size: u64 = 0x4000;
const windows_page_size: u64 = 0x1000;

pub fn emitInit(allocator: Allocator, words: *std.ArrayList(u32), epilogue: *std.ArrayList(Fixups.Local), sites: *std.ArrayList(ExternalCalls.Site), platform: Allocation.Platform, value: Machine.Instruction.ListInit) Error!void {
    const required = header_size + @as(u64, value.values.len) * value.element_width * Machine.slot_size;
    const bytes = @max(required, minimumAllocation(platform));
    try allocate(allocator, words, sites, platform, bytes);
    const failed = words.items.len;
    try words.append(allocator, Allocation.failureBranch(platform));
    try words.append(allocator, A64.moveRegister(.x15, .x0));
    try immediate(allocator, words, .x9, value.values.len);
    try words.append(allocator, A64.store64(.x9, .x15, 0));
    try immediate(allocator, words, .x9, 1);
    try words.append(allocator, A64.store64(.x9, .x15, root_count_offset));
    try immediate(allocator, words, .x9, bytes);
    try words.append(allocator, A64.store64(.x9, .x15, byte_count_offset));
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x15, header_size, true));
    for (value.values) |item| for (0..item.width) |leaf| {
        try words.append(allocator, A64.loadStack(.x9, @intCast(@as(usize, item.start) + leaf)));
        try words.append(allocator, A64.store64(.x9, .x14, 0));
        try words.append(allocator, A64.addSubtractImmediate(.x14, .x14, 8, true));
    };
    try words.append(allocator, A64.storeStack(.x15, value.result));
    const done = words.items.len;
    try words.append(allocator, A64.branch());
    try Fixups.patch19(words.items, failed, words.items.len);
    try fail(allocator, words, epilogue);
    try Fixups.patch26(words.items, done, words.items.len);
}

pub fn emitBytesLiteral(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(Fixups.Data),
    epilogue: *std.ArrayList(Fixups.Local),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
    program: Machine.Program,
    value: Machine.Instruction.ConstantBytes,
) Error!void {
    if (value.string >= program.strings.len) return error.InvalidMachineProgram;
    const count = program.strings[value.string].len;
    const bytes = header_size + @as(u64, count) * Machine.slot_size;
    try allocate(allocator, words, sites, platform, bytes);
    const failed = words.items.len;
    try words.append(allocator, Allocation.failureBranch(platform));
    try words.append(allocator, A64.moveRegister(.x15, .x0));
    try immediate(allocator, words, .x11, count);
    try words.append(allocator, A64.store64(.x11, .x15, 0));
    try immediate(allocator, words, .x11, 1);
    try words.append(allocator, A64.store64(.x11, .x15, root_count_offset));
    try immediate(allocator, words, .x11, bytes);
    try words.append(allocator, A64.store64(.x11, .x15, byte_count_offset));
    if (count != 0) {
        try StringRuntime.emitLiteral(allocator, words, data_fixups, value.string, value.result);
        try words.append(allocator, A64.loadStack(.x10, value.result));
        try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, Machine.slot_size, true));
        try words.append(allocator, A64.addSubtractImmediate(.x14, .x15, header_size, true));
        try immediate(allocator, words, .x12, count);
        const loop = words.items.len;
        try words.append(allocator, A64.loadByte(.x9, .x10));
        try words.append(allocator, A64.store64(.x9, .x14, 0));
        try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, 1, true));
        try words.append(allocator, A64.addSubtractImmediate(.x14, .x14, Machine.slot_size, true));
        try words.append(allocator, A64.addSubtractImmediate(.x12, .x12, 1, false));
        const repeat = words.items.len;
        try words.append(allocator, A64.compareBranchNonZero64(.x12));
        try Fixups.patch19(words.items, repeat, loop);
    }
    try words.append(allocator, A64.storeStack(.x15, value.result));
    const done = words.items.len;
    try words.append(allocator, A64.branch());
    try Fixups.patch19(words.items, failed, words.items.len);
    try fail(allocator, words, epilogue);
    try Fixups.patch26(words.items, done, words.items.len);
}

pub fn emitCount(allocator: Allocator, words: *std.ArrayList(u32), value: Machine.Instruction.CollectionCount) Error!void {
    if (value.view) {
        try words.append(allocator, A64.loadStack(.x10, @intCast(@as(usize, value.collection.start) + 1)));
    } else {
        try words.append(allocator, A64.loadStack(.x9, value.collection.start));
        try words.append(allocator, A64.load64(.x10, .x9, 0));
    }
    try words.append(allocator, A64.storeStack(.x10, value.result));
}

pub fn emitRetain(allocator: Allocator, words: *std.ArrayList(u32), value: Machine.Instruction.ListResource) Error!void {
    try words.append(allocator, A64.loadStack(.x10, value.operand));
    const count_offset: u12 = switch (value.ownership) { .root => root_count_offset, .edge => edge_count_offset };
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x10, count_offset, true));
    const retry = words.items.len;
    try words.append(allocator, A64.loadAcquireExclusive64(.x9, .x14));
    try words.append(allocator, A64.addSubtractImmediate(.x9, .x9, 1, true));
    try words.append(allocator, A64.storeReleaseExclusive64(.x11, .x9, .x14));
    const conflicted = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero(.x11));
    try Fixups.patch19(words.items, conflicted, retry);
}

pub fn emitDrop(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
    value: Machine.Instruction.ListResource,
) Error!void {
    _ = value.deallocate;
    return emitDropSlot(allocator, words, sites, platform, value.operand, value.ownership);
}

fn emitDropSlot(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
    slot: Machine.Slot,
    ownership: @import("../Ir.zig").Ownership,
) Error!void {
    try words.append(allocator, A64.loadStack(.x10, slot));
    try emitDropPointer(allocator, words, sites, platform, ownership);
}

fn emitDropPointer(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
    ownership: @import("../Ir.zig").Ownership,
) Error!void {
    const count_offset: u12 = switch (ownership) { .root => root_count_offset, .edge => edge_count_offset };
    const other_offset: u12 = switch (ownership) { .root => edge_count_offset, .edge => root_count_offset };
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x10, count_offset, true));
    const retry = words.items.len;
    try words.append(allocator, A64.loadAcquireExclusive64(.x9, .x14));
    const already_released = words.items.len;
    try words.append(allocator, A64.compareBranchZero64(.x9));
    try words.append(allocator, A64.addSubtractImmediate(.x9, .x9, 1, false));
    try words.append(allocator, A64.storeReleaseExclusive64(.x11, .x9, .x14));
    const conflicted = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero(.x11));
    try Fixups.patch19(words.items, conflicted, retry);
    try words.append(allocator, A64.load64(.x11, .x10, other_offset));
    try words.append(allocator, A64.addRegisters(.x9, .x9, .x11));
    const still_referenced = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero64(.x9));
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x10, state_offset, true));
    const claim_retry = words.items.len;
    try words.append(allocator, A64.loadAcquireExclusive64(.x9, .x14));
    try words.append(allocator, A64.moveWideZero64(.x11, 2, 0));
    try words.append(allocator, A64.compareRegisters(.x9, .x11));
    const tracing = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.equal));
    try words.append(allocator, A64.moveWideZero64(.x11, 1, 0));
    try words.append(allocator, A64.compareRegisters(.x9, .x11));
    const already_claimed = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.equal));
    try words.append(allocator, A64.moveWideZero64(.x9, 1, 0));
    try words.append(allocator, A64.storeReleaseExclusive64(.x11, .x9, .x14));
    const claim_conflicted = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero(.x11));
    try Fixups.patch19(words.items, tracing, claim_retry);
    try Fixups.patch19(words.items, claim_conflicted, claim_retry);
    try words.append(allocator, A64.load64(.x1, .x10, byte_count_offset));
    try words.append(allocator, A64.moveRegister(.x0, .x10));
    try Allocation.emitFree(allocator, words, sites, platform);
    const done = words.items.len;
    try Fixups.patch19(words.items, already_released, done);
    try Fixups.patch19(words.items, still_referenced, done);
    try Fixups.patch19(words.items, already_claimed, done);
}

pub fn emitEdit(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(Fixups.Data),
    epilogue: *std.ArrayList(Fixups.Local),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
    program: Machine.Program,
    value: Machine.Instruction.ListEdit,
) Error!void {
    try words.append(allocator, A64.loadStack(.x10, value.collection));
    try words.append(allocator, A64.load64(.x13, .x10, 0));
    var invalid: ?Bounds = null;
    switch (value.kind) {
        .take => invalid = try boundsDynamic(allocator, words, value.collection, value.index.?),
        .insert => invalid = try insertionBounds(allocator, words, value.index.?),
        .take_first => {
            try words.append(allocator, A64.moveWideZero32(.x9, 0));
            const empty = words.items.len;
            try words.append(allocator, A64.compareBranchZero64(.x13));
            invalid = .{ .negative = empty, .upper = empty };
        },
        .take_last => {
            try words.append(allocator, A64.moveWideZero64(.x9, 1, 0));
            try words.append(allocator, A64.subtractSetFlags(.x9, .x13, .x9));
            const empty = words.items.len;
            try words.append(allocator, A64.conditionalBranch(.less));
            invalid = .{ .negative = empty, .upper = empty };
        },
        else => try words.append(allocator, A64.moveWideZero32(.x9, 0)),
    }
    try words.append(allocator, A64.moveRegister(.x12, .x13));
    switch (value.kind) {
        .append, .prepend, .insert => try words.append(allocator, A64.addSubtractImmediate(.x12, .x12, 1, true)),
        .take, .take_first, .take_last => try words.append(allocator, A64.addSubtractImmediate(.x12, .x12, 1, false)),
        .clear => try words.append(allocator, A64.moveWideZero32(.x12, 0)),
        .reverse => {},
        .append_sequence => {
            if (value.argument_dynamic) {
                try words.append(allocator, A64.loadStack(.x7, value.argument.?.start));
                try words.append(allocator, A64.load64(.x6, .x7, 0));
            } else {
                try words.append(allocator, A64.moveWideZero32(.x7, 0));
                try immediate(allocator, words, .x6, value.argument_count);
            }
            try words.append(allocator, A64.addRegisters(.x12, .x12, .x6));
        },
    }

    var reused: ?usize = null;
    var shared_or_full: [2]usize = undefined;
    if (value.kind == .append or value.kind == .clear) {
        try words.append(allocator, A64.load64(.x11, .x10, root_count_offset));
        try words.append(allocator, A64.load64(.x5, .x10, edge_count_offset));
        try words.append(allocator, A64.addRegisters(.x11, .x11, .x5));
        try immediate(allocator, words, .x5, 1);
        try words.append(allocator, A64.compareRegisters(.x11, .x5));
        shared_or_full[0] = words.items.len;
        try words.append(allocator, A64.conditionalBranch(.not_equal));
        try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
        try words.append(allocator, A64.multiply(.x5, .x12, .x11));
        try words.append(allocator, A64.addSubtractImmediate(.x5, .x5, header_size, true));
        try words.append(allocator, A64.load64(.x11, .x10, byte_count_offset));
        try words.append(allocator, A64.compareRegisters(.x5, .x11));
        shared_or_full[1] = words.items.len;
        try words.append(allocator, A64.conditionalBranch(.higher));
        if (value.kind == .append) {
            try words.append(allocator, A64.addSubtractImmediate(.x14, .x10, header_size, true));
            try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
            try words.append(allocator, A64.multiply(.x5, .x13, .x11));
            try words.append(allocator, A64.addRegisters(.x14, .x14, .x5));
            for (0..value.argument.?.width) |leaf| {
                try words.append(allocator, A64.loadStack(.x5, @intCast(@as(usize, value.argument.?.start) + leaf)));
                try words.append(allocator, A64.store64(.x5, .x14, @intCast(leaf * Machine.slot_size)));
            }
        }
        try words.append(allocator, A64.store64(.x12, .x10, 0));
        try words.append(allocator, A64.storeStack(.x10, value.result));
        reused = words.items.len;
        try words.append(allocator, A64.branch());
        for (shared_or_full) |at| try Fixups.patch19(words.items, at, words.items.len);
    }

    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 48, false));
    for ([_]struct { register: A64.Register, offset: u12 }{
        .{ .register = .x10, .offset = 0 }, .{ .register = .x13, .offset = 8 },
        .{ .register = .x9, .offset = 16 }, .{ .register = .x12, .offset = 24 },
        .{ .register = .x7, .offset = 32 }, .{ .register = .x6, .offset = 40 },
    }) |saved| try words.append(allocator, A64.store64(saved.register, .zero_or_sp, saved.offset));
    try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x1, .x12, .x11));
    try words.append(allocator, A64.addSubtractImmediate(.x1, .x1, header_size, true));
    try ensureMinimumAllocation(allocator, words, platform, .x1);
    // Keep spare capacity so append-heavy lists grow geometrically instead of
    // issuing one virtual-memory allocation for every element past a page.
    try words.append(allocator, A64.addRegisters(.x1, .x1, .x1));
    try allocateWithSize(allocator, words, sites, platform);
    const mmap_failed = words.items.len;
    try words.append(allocator, Allocation.failureBranch(platform));
    try words.append(allocator, A64.moveRegister(.x15, .x0));
    for ([_]struct { register: A64.Register, offset: u12 }{
        .{ .register = .x10, .offset = 0 }, .{ .register = .x13, .offset = 8 },
        .{ .register = .x9, .offset = 16 }, .{ .register = .x12, .offset = 24 },
        .{ .register = .x7, .offset = 32 }, .{ .register = .x6, .offset = 40 },
    }) |saved| try words.append(allocator, A64.load64(saved.register, .zero_or_sp, saved.offset));
    try words.append(allocator, A64.store64(.x12, .x15, 0));
    try immediate(allocator, words, .x5, 1);
    try words.append(allocator, A64.store64(.x5, .x15, switch (value.ownership) { .root => root_count_offset, .edge => edge_count_offset }));
    try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x11, .x12, .x11));
    try words.append(allocator, A64.addSubtractImmediate(.x11, .x11, header_size, true));
    try ensureMinimumAllocation(allocator, words, platform, .x11);
    try words.append(allocator, A64.addRegisters(.x11, .x11, .x11));
    try words.append(allocator, A64.store64(.x11, .x15, byte_count_offset));
    try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, header_size, true));
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x15, header_size, true));

    switch (value.kind) {
        .clear => {},
        .append => {
            try copyElements(allocator, words, .x13, value.element_width);
        },
        .prepend => {
            try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
            try words.append(allocator, A64.addRegisters(.x14, .x14, .x11));
            try copyElements(allocator, words, .x13, value.element_width);
        },
        .append_sequence => {
            try copyElements(allocator, words, .x13, value.element_width);
            if (value.argument_dynamic) {
                try words.append(allocator, A64.addSubtractImmediate(.x7, .x7, header_size, true));
                try words.append(allocator, A64.moveRegister(.x10, .x7));
                try copyElements(allocator, words, .x6, value.element_width);
            }
        },
        .insert => {
            try copyElements(allocator, words, .x9, value.element_width);
            try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
            try words.append(allocator, A64.addRegisters(.x14, .x14, .x11));
            try words.append(allocator, A64.subtractSetFlags(.x13, .x13, .x9));
            try copyElements(allocator, words, .x13, value.element_width);
        },
        .take, .take_first, .take_last => {
            try copyElements(allocator, words, .x9, value.element_width);
            try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
            try words.append(allocator, A64.addRegisters(.x10, .x10, .x11));
            try words.append(allocator, A64.subtractSetFlags(.x13, .x13, .x9));
            try words.append(allocator, A64.addSubtractImmediate(.x13, .x13, 1, false));
            try copyElements(allocator, words, .x13, value.element_width);
        },
        .reverse => try reverseElements(allocator, words, value.element_width),
    }
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 48, true));

    if (value.kind == .append or value.kind == .prepend or value.kind == .insert) {
        if (value.kind == .prepend) try immediate(allocator, words, .x9, 0);
        if (value.kind == .append) try words.append(allocator, A64.moveRegister(.x9, .x13));
        try words.append(allocator, A64.addSubtractImmediate(.x14, .x15, header_size, true));
        try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
        try words.append(allocator, A64.multiply(.x9, .x9, .x11));
        try words.append(allocator, A64.addRegisters(.x14, .x14, .x9));
        for (0..value.argument.?.width) |leaf| {
            try words.append(allocator, A64.loadStack(.x12, @intCast(@as(usize, value.argument.?.start) + leaf)));
            try words.append(allocator, A64.store64(.x12, .x14, @intCast(leaf * Machine.slot_size)));
        }
    }
    if (value.kind == .append_sequence and !value.argument_dynamic) {
        try words.append(allocator, A64.addSubtractImmediate(.x14, .x15, header_size, true));
        try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
        try words.append(allocator, A64.multiply(.x9, .x13, .x11));
        try words.append(allocator, A64.addRegisters(.x14, .x14, .x9));
        for (0..value.argument.?.width) |leaf| {
            try words.append(allocator, A64.loadStack(.x12, @intCast(@as(usize, value.argument.?.start) + leaf)));
            try words.append(allocator, A64.store64(.x12, .x14, @intCast(leaf * Machine.slot_size)));
        }
    }
    if (value.removed) |removed| {
        try words.append(allocator, A64.loadStack(.x10, value.collection));
        try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, header_size, true));
        try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
        try words.append(allocator, A64.multiply(.x9, .x9, .x11));
        try words.append(allocator, A64.addRegisters(.x10, .x10, .x9));
        for (0..removed.width) |leaf| {
            try words.append(allocator, A64.load64(.x12, .x10, @intCast(leaf * Machine.slot_size)));
            try words.append(allocator, A64.storeStack(.x12, @intCast(@as(usize, removed.start) + leaf)));
        }
    }
    try words.append(allocator, A64.storeStack(.x15, value.result));
    if (value.kind == .append or value.kind == .clear) {
        try words.append(allocator, A64.loadStack(.x10, value.collection));
        try emitDropPointer(allocator, words, sites, platform, value.ownership);
    }
    if (value.argument_dynamic and value.argument_transferred) {
        try emitDropSlot(allocator, words, sites, platform, value.argument.?.start, .root);
    }
    const complete = words.items.len;
    if (reused) |at| try Fixups.patch26(words.items, at, complete);
    try words.append(allocator, A64.branch());

    const scratch_failure = words.items.len;
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 48, true));
    try fail(allocator, words, epilogue);
    try Fixups.patch19(words.items, mmap_failed, scratch_failure);
    if (invalid) |bounds| {
        const bounds_failure = words.items.len;
        try Fixups.patch19(words.items, bounds.negative, bounds_failure);
        if (bounds.upper != bounds.negative) try Fixups.patch19(words.items, bounds.upper, bounds_failure);
        try words.append(allocator, A64.storeStack(.x13, value.result));
        try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, value.header, 2);
        try emitPrintInteger(allocator, words, value.index orelse value.result, 2, false);
        try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, value.tail, 2);
        try emitPrintInteger(allocator, words, value.result, 2, true);
        try fail(allocator, words, epilogue);
    }
    try Fixups.patch26(words.items, complete, words.items.len);
}

pub fn emitSlice(allocator: Allocator, words: *std.ArrayList(u32), epilogue: *std.ArrayList(Fixups.Local), sites: *std.ArrayList(ExternalCalls.Site), platform: Allocation.Platform, value: Machine.Instruction.CollectionSlice) Error!void {
    if (value.view) {
        try words.append(allocator, A64.loadStack(.x10, value.collection.start));
        try words.append(allocator, A64.loadStack(.x13, @intCast(@as(usize, value.collection.start) + 1)));
    } else if (value.dynamic) {
        try words.append(allocator, A64.loadStack(.x10, value.collection.start));
        try words.append(allocator, A64.load64(.x13, .x10, 0));
        try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, header_size, true));
    } else {
        try stackAddress(allocator, words, .x10, value.collection.start);
        try immediate(allocator, words, .x13, value.count);
    }
    try words.append(allocator, A64.loadStack(.x9, value.start));
    try normalizeBound(allocator, words, .x9);
    try words.append(allocator, A64.loadStack(.x8, value.end));
    try normalizeBound(allocator, words, .x8);
    try words.append(allocator, A64.moveWideZero32(.x12, 0));
    try words.append(allocator, A64.compareRegisters(.x9, .x8));
    const empty = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.greater_equal));
    try words.append(allocator, A64.subtractSetFlags(.x12, .x8, .x9));
    try Fixups.patch19(words.items, empty, words.items.len);
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, false));
    try words.append(allocator, A64.store64(.x10, .zero_or_sp, 0));
    try words.append(allocator, A64.store64(.x9, .zero_or_sp, 8));
    try words.append(allocator, A64.store64(.x12, .zero_or_sp, 16));
    try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x1, .x12, .x11));
    try words.append(allocator, A64.addSubtractImmediate(.x1, .x1, header_size, true));
    try allocateWithSize(allocator, words, sites, platform);
    const mmap_failed = words.items.len;
    try words.append(allocator, Allocation.failureBranch(platform));
    try words.append(allocator, A64.moveRegister(.x15, .x0));
    try words.append(allocator, A64.load64(.x10, .zero_or_sp, 0));
    try words.append(allocator, A64.load64(.x9, .zero_or_sp, 8));
    try words.append(allocator, A64.load64(.x13, .zero_or_sp, 16));
    try words.append(allocator, A64.store64(.x13, .x15, 0));
    try immediate(allocator, words, .x11, 1);
    try words.append(allocator, A64.store64(.x11, .x15, root_count_offset));
    try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x11, .x13, .x11));
    try words.append(allocator, A64.addSubtractImmediate(.x11, .x11, header_size, true));
    try words.append(allocator, A64.store64(.x11, .x15, byte_count_offset));
    try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x9, .x9, .x11));
    try words.append(allocator, A64.addRegisters(.x10, .x10, .x9));
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x15, header_size, true));
    try copyElements(allocator, words, .x13, value.element_width);
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, true));
    try words.append(allocator, A64.storeStack(.x15, value.result));
    const complete = words.items.len;
    try words.append(allocator, A64.branch());
    const failure = words.items.len;
    try Fixups.patch19(words.items, mmap_failed, failure);
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, true));
    try fail(allocator, words, epilogue);
    try Fixups.patch26(words.items, complete, words.items.len);
}

pub fn emitView(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    epilogue: *std.ArrayList(Fixups.Local),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
    value: Machine.Instruction.CollectionView,
) Error!void {
    if (value.reference != null and value.dynamic and !value.source_view) {
        try detachDynamicRoot(allocator, words, epilogue, sites, platform, value.reference.?, value.element_width);
    }
    if (value.reference) |reference| {
        try words.append(allocator, A64.loadStack(.x10, reference));
        if (value.source_view) {
            try words.append(allocator, A64.load64(.x13, .x10, 8));
            try words.append(allocator, A64.load64(.x10, .x10, 0));
        } else if (value.dynamic) {
            try words.append(allocator, A64.load64(.x10, .x10, 0));
            try words.append(allocator, A64.load64(.x13, .x10, 0));
            try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, header_size, true));
        } else {
            try immediate(allocator, words, .x13, value.count);
        }
    } else if (value.source_view) {
        try words.append(allocator, A64.loadStack(.x10, value.collection.start));
        try words.append(allocator, A64.loadStack(.x13, @intCast(@as(usize, value.collection.start) + 1)));
    } else if (value.dynamic) {
        try words.append(allocator, A64.loadStack(.x10, value.collection.start));
        try words.append(allocator, A64.load64(.x13, .x10, 0));
        try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, header_size, true));
    } else {
        try stackAddress(allocator, words, .x10, value.collection.start);
        try immediate(allocator, words, .x13, value.count);
    }
    try words.append(allocator, A64.loadStack(.x9, value.start));
    try normalizeBound(allocator, words, .x9);
    try words.append(allocator, A64.loadStack(.x8, value.end));
    try normalizeBound(allocator, words, .x8);
    try words.append(allocator, A64.moveWideZero32(.x12, 0));
    try words.append(allocator, A64.compareRegisters(.x9, .x8));
    const empty = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.greater_equal));
    try words.append(allocator, A64.subtractSetFlags(.x12, .x8, .x9));
    try Fixups.patch19(words.items, empty, words.items.len);
    try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x9, .x9, .x11));
    try words.append(allocator, A64.addRegisters(.x10, .x10, .x9));
    try words.append(allocator, A64.storeStack(.x10, value.result.start));
    try words.append(allocator, A64.storeStack(.x12, @intCast(@as(usize, value.result.start) + 1)));
}

fn detachDynamicRoot(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    epilogue: *std.ArrayList(Fixups.Local),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
    reference: Machine.Slot,
    element_width: u12,
) Error!void {
    try words.append(allocator, A64.loadStack(.x10, reference));
    try words.append(allocator, A64.load64(.x14, .x10, 0));
    try words.append(allocator, A64.load64(.x13, .x14, 0));
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, false));
    try words.append(allocator, A64.store64(.x10, .zero_or_sp, 0));
    try words.append(allocator, A64.store64(.x14, .zero_or_sp, 8));
    try words.append(allocator, A64.store64(.x13, .zero_or_sp, 16));
    try immediate(allocator, words, .x11, @as(u64, element_width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x1, .x13, .x11));
    try words.append(allocator, A64.addSubtractImmediate(.x1, .x1, header_size, true));
    try allocateWithSize(allocator, words, sites, platform);
    const mmap_failed = words.items.len;
    try words.append(allocator, Allocation.failureBranch(platform));
    try words.append(allocator, A64.moveRegister(.x15, .x0));
    try words.append(allocator, A64.load64(.x10, .zero_or_sp, 0));
    try words.append(allocator, A64.load64(.x14, .zero_or_sp, 8));
    try words.append(allocator, A64.load64(.x13, .zero_or_sp, 16));
    try words.append(allocator, A64.store64(.x13, .x15, 0));
    try immediate(allocator, words, .x11, 1);
    try words.append(allocator, A64.store64(.x11, .x15, root_count_offset));
    try immediate(allocator, words, .x11, @as(u64, element_width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x11, .x13, .x11));
    try words.append(allocator, A64.addSubtractImmediate(.x11, .x11, header_size, true));
    try words.append(allocator, A64.store64(.x11, .x15, byte_count_offset));
    try words.append(allocator, A64.addSubtractImmediate(.x10, .x14, header_size, true));
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x15, header_size, true));
    try copyElements(allocator, words, .x13, element_width);
    try words.append(allocator, A64.load64(.x10, .zero_or_sp, 0));
    try words.append(allocator, A64.store64(.x15, .x10, 0));
    try words.append(allocator, A64.load64(.x10, .zero_or_sp, 8));
    try emitDropPointer(allocator, words, sites, platform, .root);
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, true));
    const complete = words.items.len;
    try words.append(allocator, A64.branch());
    const failure = words.items.len;
    try Fixups.patch19(words.items, mmap_failed, failure);
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, true));
    try fail(allocator, words, epilogue);
    try Fixups.patch26(words.items, complete, words.items.len);
}

fn normalizeBound(allocator: Allocator, words: *std.ArrayList(u32), register: A64.Register) Error!void {
    try words.append(allocator, A64.compareRegisters(register, .zero_or_sp));
    const nonnegative = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.greater_equal));
    try words.append(allocator, A64.addRegisters(register, register, .x13));
    try Fixups.patch19(words.items, nonnegative, words.items.len);
    try words.append(allocator, A64.compareRegisters(register, .zero_or_sp));
    const not_below = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.greater_equal));
    try words.append(allocator, A64.moveWideZero32(register, 0));
    try Fixups.patch19(words.items, not_below, words.items.len);
    try words.append(allocator, A64.compareRegisters(register, .x13));
    const not_above = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.less_equal));
    try words.append(allocator, A64.moveRegister(register, .x13));
    try Fixups.patch19(words.items, not_above, words.items.len);
}

fn stackAddress(allocator: Allocator, words: *std.ArrayList(u32), destination: A64.Register, slot: Machine.Slot) Error!void {
    const offset = @as(u64, slot) * Machine.slot_size;
    if (offset <= std.math.maxInt(u12)) return words.append(allocator, A64.addSubtractImmediate(destination, .zero_or_sp, @intCast(offset), true));
    try immediate(allocator, words, .x11, offset);
    try words.append(allocator, A64.addRegisters(destination, .zero_or_sp, .x11));
}

fn insertionBounds(allocator: Allocator, words: *std.ArrayList(u32), index: Machine.Slot) Error!Bounds {
    try words.append(allocator, A64.loadStack(.x9, index));
    try words.append(allocator, A64.compareRegisters(.x9, .zero_or_sp));
    const nonnegative = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.greater_equal));
    try words.append(allocator, A64.addRegisters(.x9, .x9, .x13));
    try Fixups.patch19(words.items, nonnegative, words.items.len);
    try words.append(allocator, A64.compareRegisters(.x9, .zero_or_sp));
    const negative = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.less));
    try words.append(allocator, A64.compareRegisters(.x9, .x13));
    const upper = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.greater));
    return .{ .negative = negative, .upper = upper };
}

fn copyElements(allocator: Allocator, words: *std.ArrayList(u32), count: A64.Register, width: u12) Error!void {
    try immediate(allocator, words, .x11, width);
    try words.append(allocator, A64.multiply(.x12, count, .x11));
    const empty = words.items.len;
    try words.append(allocator, A64.compareBranchZero64(.x12));
    const loop = words.items.len;
    try words.append(allocator, A64.load64(.x11, .x10, 0));
    try words.append(allocator, A64.store64(.x11, .x14, 0));
    try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, 8, true));
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x14, 8, true));
    try words.append(allocator, A64.addSubtractImmediate(.x12, .x12, 1, false));
    const repeat = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero64(.x12));
    try Fixups.patch19(words.items, repeat, loop);
    try Fixups.patch19(words.items, empty, words.items.len);
}

fn reverseElements(allocator: Allocator, words: *std.ArrayList(u32), width: u12) Error!void {
    try immediate(allocator, words, .x11, @as(u64, width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x9, .x13, .x11));
    try words.append(allocator, A64.addRegisters(.x10, .x10, .x9));
    const empty = words.items.len;
    try words.append(allocator, A64.compareBranchZero64(.x13));
    const outer = words.items.len;
    try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, @intCast(@as(usize, width) * Machine.slot_size), false));
    for (0..width) |leaf| {
        try words.append(allocator, A64.load64(.x12, .x10, @intCast(leaf * Machine.slot_size)));
        try words.append(allocator, A64.store64(.x12, .x14, @intCast(leaf * Machine.slot_size)));
    }
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x14, @intCast(@as(usize, width) * Machine.slot_size), true));
    try words.append(allocator, A64.addSubtractImmediate(.x13, .x13, 1, false));
    const repeat = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero64(.x13));
    try Fixups.patch19(words.items, repeat, outer);
    try Fixups.patch19(words.items, empty, words.items.len);
}

pub fn emitLoad(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(Fixups.Data),
    epilogue: *std.ArrayList(Fixups.Local),
    program: Machine.Program,
    value: Machine.Instruction.CollectionLoad,
) Error!void {
    const bounds = if (value.view)
        try boundsView(allocator, words, value.collection, value.index)
    else
        try boundsDynamic(allocator, words, value.collection.start, value.index);
    if (!value.view) try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, header_size, true));
    try immediate(allocator, words, .x11, @as(u64, value.result.width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x9, .x9, .x11));
    try words.append(allocator, A64.addRegisters(.x10, .x10, .x9));
    for (0..value.result.width) |leaf| {
        try words.append(allocator, A64.load64(.x12, .x10, @intCast(leaf * Machine.slot_size)));
        try words.append(allocator, A64.storeStack(.x12, @intCast(@as(usize, value.result.start) + leaf)));
    }
    const complete = words.items.len;
    try words.append(allocator, A64.branch());
    const failure = words.items.len;
    try Fixups.patch19(words.items, bounds.negative, failure);
    try Fixups.patch19(words.items, bounds.upper, failure);
    try words.append(allocator, A64.storeStack(.x13, value.result.start));
    try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, value.header, 2);
    try emitPrintInteger(allocator, words, value.index, 2, false);
    try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, value.tail, 2);
    try emitPrintInteger(allocator, words, value.result.start, 2, true);
    try fail(allocator, words, epilogue);
    try Fixups.patch26(words.items, complete, words.items.len);
}

pub fn emitReference(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(Fixups.Data),
    epilogue: *std.ArrayList(Fixups.Local),
    program: Machine.Program,
    value: Machine.Instruction.CollectionReference,
) Error!void {
    const bounds = if (value.view)
        try boundsView(allocator, words, value.collection, value.index)
    else
        try boundsDynamic(allocator, words, value.collection.start, value.index);
    if (!value.view) try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, header_size, true));
    try immediate(allocator, words, .x11, @as(u64, value.element_width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x9, .x9, .x11));
    try words.append(allocator, A64.addRegisters(.x10, .x10, .x9));
    try words.append(allocator, A64.storeStack(.x10, value.result));
    const complete = words.items.len;
    try words.append(allocator, A64.branch());
    const failure = words.items.len;
    try Fixups.patch19(words.items, bounds.negative, failure);
    try Fixups.patch19(words.items, bounds.upper, failure);
    try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, value.header, 2);
    try emitPrintInteger(allocator, words, value.index, 2, false);
    try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, value.tail, 2);
    try fail(allocator, words, epilogue);
    try Fixups.patch26(words.items, complete, words.items.len);
}

pub fn emitReplace(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    data_fixups: *std.ArrayList(Fixups.Data),
    epilogue: *std.ArrayList(Fixups.Local),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Allocation.Platform,
    program: Machine.Program,
    value: Machine.Instruction.CollectionReplace,
) Error!void {
    const bounds = if (value.view)
        try boundsView(allocator, words, value.collection, value.index)
    else
        try boundsDynamic(allocator, words, value.collection.start, value.index);
    if (value.view) {
        try immediate(allocator, words, .x11, @as(u64, value.replacement.width) * Machine.slot_size);
        try words.append(allocator, A64.multiply(.x9, .x9, .x11));
        try words.append(allocator, A64.addRegisters(.x10, .x10, .x9));
        for (0..value.replacement.width) |leaf| {
            try words.append(allocator, A64.loadStack(.x12, @intCast(@as(usize, value.replacement.start) + leaf)));
            try words.append(allocator, A64.store64(.x12, .x10, @intCast(leaf * Machine.slot_size)));
        }
        for (0..2) |slot| {
            try words.append(allocator, A64.loadStack(.x12, @intCast(@as(usize, value.collection.start) + slot)));
            try words.append(allocator, A64.storeStack(.x12, @intCast(@as(usize, value.result.start) + slot)));
        }
        const complete = words.items.len;
        try words.append(allocator, A64.branch());
        const failure = words.items.len;
        try Fixups.patch19(words.items, bounds.negative, failure);
        try Fixups.patch19(words.items, bounds.upper, failure);
        try words.append(allocator, A64.storeStack(.x13, value.result.start));
        try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, value.header, 2);
        try emitPrintInteger(allocator, words, value.index, 2, false);
        try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, value.tail, 2);
        try emitPrintInteger(allocator, words, value.result.start, 2, true);
        try fail(allocator, words, epilogue);
        try Fixups.patch26(words.items, complete, words.items.len);
        return;
    }
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, false));
    try words.append(allocator, A64.store64(.x10, .zero_or_sp, 0));
    try words.append(allocator, A64.store64(.x13, .zero_or_sp, 8));
    try words.append(allocator, A64.store64(.x9, .zero_or_sp, 16));
    try immediate(allocator, words, .x11, @as(u64, value.replacement.width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x1, .x13, .x11));
    try words.append(allocator, A64.addSubtractImmediate(.x1, .x1, header_size, true));
    try allocateWithSize(allocator, words, sites, platform);
    const mmap_failed = words.items.len;
    try words.append(allocator, Allocation.failureBranch(platform));
    try words.append(allocator, A64.moveRegister(.x15, .x0));
    try words.append(allocator, A64.load64(.x10, .zero_or_sp, 0));
    try words.append(allocator, A64.load64(.x13, .zero_or_sp, 8));
    try words.append(allocator, A64.load64(.x9, .zero_or_sp, 16));
    try words.append(allocator, A64.store64(.x13, .x15, 0));
    try immediate(allocator, words, .x11, 1);
    try words.append(allocator, A64.store64(.x11, .x15, switch (value.ownership) { .root => root_count_offset, .edge => edge_count_offset }));
    try immediate(allocator, words, .x11, @as(u64, value.replacement.width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x11, .x13, .x11));
    try words.append(allocator, A64.addSubtractImmediate(.x11, .x11, header_size, true));
    try words.append(allocator, A64.store64(.x11, .x15, byte_count_offset));
    try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, header_size, true));
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x15, header_size, true));
    try immediate(allocator, words, .x11, value.replacement.width);
    try words.append(allocator, A64.multiply(.x12, .x13, .x11));
    const copy_done = words.items.len;
    try words.append(allocator, A64.compareBranchZero64(.x12));
    const copy_loop = words.items.len;
    try words.append(allocator, A64.load64(.x11, .x10, 0));
    try words.append(allocator, A64.store64(.x11, .x14, 0));
    try words.append(allocator, A64.addSubtractImmediate(.x10, .x10, 8, true));
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x14, 8, true));
    try words.append(allocator, A64.addSubtractImmediate(.x12, .x12, 1, false));
    const repeat = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero64(.x12));
    try Fixups.patch19(words.items, repeat, copy_loop);
    try Fixups.patch19(words.items, copy_done, words.items.len);
    try words.append(allocator, A64.addSubtractImmediate(.x14, .x15, header_size, true));
    try immediate(allocator, words, .x11, @as(u64, value.replacement.width) * Machine.slot_size);
    try words.append(allocator, A64.multiply(.x9, .x9, .x11));
    try words.append(allocator, A64.addRegisters(.x14, .x14, .x9));
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, true));
    for (0..value.replacement.width) |leaf| {
        try words.append(allocator, A64.loadStack(.x12, @intCast(@as(usize, value.replacement.start) + leaf)));
        try words.append(allocator, A64.store64(.x12, .x14, @intCast(leaf * Machine.slot_size)));
    }
    try words.append(allocator, A64.storeStack(.x15, value.result.start));
    try emitDropSlot(allocator, words, sites, platform, value.collection.start, value.ownership);
    const complete = words.items.len;
    try words.append(allocator, A64.branch());

    const scratch_failure = words.items.len;
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, true));
    try fail(allocator, words, epilogue);
    try Fixups.patch19(words.items, mmap_failed, scratch_failure);

    const bounds_failure = words.items.len;
    try Fixups.patch19(words.items, bounds.negative, bounds_failure);
    try Fixups.patch19(words.items, bounds.upper, bounds_failure);
    try words.append(allocator, A64.storeStack(.x13, value.result.start));
    try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, value.header, 2);
    try emitPrintInteger(allocator, words, value.index, 2, false);
    try StringRuntime.emitWriteStatic(allocator, words, data_fixups, program, value.tail, 2);
    try emitPrintInteger(allocator, words, value.result.start, 2, true);
    try fail(allocator, words, epilogue);
    try Fixups.patch26(words.items, complete, words.items.len);
}

const Bounds = struct { negative: usize, upper: usize };
fn boundsView(allocator: Allocator, words: *std.ArrayList(u32), collection: Machine.Span, index: Machine.Slot) Error!Bounds {
    try words.append(allocator, A64.loadStack(.x10, collection.start));
    try words.append(allocator, A64.loadStack(.x13, @intCast(@as(usize, collection.start) + 1)));
    return boundsWithLoadedCollection(allocator, words, index);
}

fn boundsDynamic(allocator: Allocator, words: *std.ArrayList(u32), collection: Machine.Slot, index: Machine.Slot) Error!Bounds {
    try words.append(allocator, A64.loadStack(.x10, collection));
    try words.append(allocator, A64.load64(.x13, .x10, 0));
    return boundsWithLoadedCollection(allocator, words, index);
}

fn boundsWithLoadedCollection(allocator: Allocator, words: *std.ArrayList(u32), index: Machine.Slot) Error!Bounds {
    try words.append(allocator, A64.loadStack(.x9, index));
    try words.append(allocator, A64.compareRegisters(.x9, .zero_or_sp));
    const nonnegative = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.greater_equal));
    try words.append(allocator, A64.addRegisters(.x9, .x9, .x13));
    try Fixups.patch19(words.items, nonnegative, words.items.len);
    try words.append(allocator, A64.compareRegisters(.x9, .zero_or_sp));
    const negative = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.less));
    try words.append(allocator, A64.compareRegisters(.x9, .x13));
    const upper = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.greater_equal));
    return .{ .negative = negative, .upper = upper };
}

fn allocate(allocator: Allocator, words: *std.ArrayList(u32), sites: *std.ArrayList(ExternalCalls.Site), platform: Allocation.Platform, bytes: u64) Error!void {
    try immediate(allocator, words, .x1, bytes);
    return allocateWithSize(allocator, words, sites, platform);
}

fn allocateWithSize(allocator: Allocator, words: *std.ArrayList(u32), sites: *std.ArrayList(ExternalCalls.Site), platform: Allocation.Platform) Error!void {
    try Allocation.emit(allocator, words, sites, platform);
}

fn fail(allocator: Allocator, words: *std.ArrayList(u32), epilogue: *std.ArrayList(Fixups.Local)) Error!void {
    try words.append(allocator, A64.moveWideZero32(.x8, @intFromEnum(Machine.Status.runtime_failure)));
    try Fixups.appendLocal(allocator, words, epilogue, A64.branch(), .imm26);
}

fn immediate(allocator: Allocator, words: *std.ArrayList(u32), register: A64.Register, value: u64) Error!void {
    try words.append(allocator, A64.moveWideZero64(register, @truncate(value), 0));
    if (value >> 16 != 0) try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 16), 1));
    if (value >> 32 != 0) try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 32), 2));
    if (value >> 48 != 0) try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 48), 3));
}

fn minimumAllocation(platform: Allocation.Platform) u64 {
    return switch (platform) {
        .darwin => darwin_page_size,
        .windows => windows_page_size,
    };
}

fn ensureMinimumAllocation(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    platform: Allocation.Platform,
    register: A64.Register,
) Error!void {
    try immediate(allocator, words, .x5, minimumAllocation(platform));
    try words.append(allocator, A64.compareRegisters(register, .x5));
    const sufficient = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.carry_set));
    try words.append(allocator, A64.moveRegister(register, .x5));
    try Fixups.patch19(words.items, sufficient, words.items.len);
}

fn emitPrintInteger(allocator: Allocator, words: *std.ArrayList(u32), slot: Machine.Slot, descriptor: u16, newline: bool) Error!void {
    try words.append(allocator, A64.loadStack(.x9, slot));
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, false));
    try words.append(allocator, A64.addSubtractImmediate(.x11, .zero_or_sp, if (newline) 31 else 32, true));
    if (newline) {
        try words.append(allocator, A64.moveWideZero32(.x10, '\n'));
        try words.append(allocator, A64.storeByte(.x10, .x11));
    }
    try words.append(allocator, A64.moveWideZero32(.x12, @intFromBool(newline)));
    const nonzero = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero64(.x9));
    try words.append(allocator, A64.addSubtractImmediate(.x11, .x11, 1, false));
    try words.append(allocator, A64.moveWideZero32(.x10, '0'));
    try words.append(allocator, A64.storeByte(.x10, .x11));
    try words.append(allocator, A64.addSubtractImmediate(.x12, .x12, 1, true));
    const zero_finished = words.items.len;
    try words.append(allocator, A64.branch());
    try Fixups.patch19(words.items, nonzero, words.items.len);
    try words.append(allocator, A64.moveWideZero32(.x3, 0));
    try words.append(allocator, A64.compareRegisters(.x9, .zero_or_sp));
    const already_negative = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.less));
    try words.append(allocator, A64.subtractSetFlags(.x9, .zero_or_sp, .x9));
    const sign_ready = words.items.len;
    try words.append(allocator, A64.branch());
    try Fixups.patch19(words.items, already_negative, words.items.len);
    try words.append(allocator, A64.moveWideZero32(.x3, 1));
    try Fixups.patch26(words.items, sign_ready, words.items.len);
    const loop = words.items.len;
    try words.append(allocator, A64.moveWideZero32(.x10, 10));
    try words.append(allocator, A64.signedDivide(.x4, .x9, .x10));
    try words.append(allocator, A64.multiplySubtract(.x5, .x4, .x10, .x9));
    try words.append(allocator, A64.moveWideZero32(.x6, '0'));
    try words.append(allocator, A64.subtractSetFlags(.x6, .x6, .x5));
    try words.append(allocator, A64.addSubtractImmediate(.x11, .x11, 1, false));
    try words.append(allocator, A64.storeByte(.x6, .x11));
    try words.append(allocator, A64.addSubtractImmediate(.x12, .x12, 1, true));
    try words.append(allocator, A64.moveRegister(.x9, .x4));
    const repeat = words.items.len;
    try words.append(allocator, A64.compareBranchNonZero64(.x9));
    try Fixups.patch19(words.items, repeat, loop);
    const unsigned = words.items.len;
    try words.append(allocator, A64.compareBranchZero(.x3));
    try words.append(allocator, A64.addSubtractImmediate(.x11, .x11, 1, false));
    try words.append(allocator, A64.moveWideZero32(.x10, '-'));
    try words.append(allocator, A64.storeByte(.x10, .x11));
    try words.append(allocator, A64.addSubtractImmediate(.x12, .x12, 1, true));
    try Fixups.patch19(words.items, unsigned, words.items.len);
    try Fixups.patch26(words.items, zero_finished, words.items.len);
    try words.append(allocator, A64.moveWideZero32(.x0, descriptor));
    try words.append(allocator, A64.moveRegister(.x1, .x11));
    try words.append(allocator, A64.moveRegister(.x2, .x12));
    try words.append(allocator, A64.moveWideZero32(.x16, 4));
    try words.append(allocator, A64.serviceCall());
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, 32, true));
}
