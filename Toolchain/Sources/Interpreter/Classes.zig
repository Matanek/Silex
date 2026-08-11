const std = @import("std");
const Ir = @import("../Ir.zig");
const Value = @import("Value.zig").Value;
const TraceError = std.mem.Allocator.Error || error{InvalidProgram};

pub const Entry = struct {
    instance: *Value.Structure,
    roots: usize = 0,
    edges: usize = 0,
    dropped: bool = false,
};

pub fn register(allocator: std.mem.Allocator, heap: *std.ArrayList(Entry), instance: *Value.Structure) !void {
    try heap.append(allocator, .{ .instance = instance });
}

pub fn retain(heap: []Entry, instance: *Value.Structure, ownership: Ir.Ownership) !void {
    const entry = find(heap, instance) orelse return error.InvalidProgram;
    if (entry.dropped) return error.InvalidProgram;
    switch (ownership) {
        .root => entry.roots += 1,
        .edge => entry.edges += 1,
    }
}

pub fn release(allocator: std.mem.Allocator, heap: []Entry, instance: *Value.Structure, ownership: Ir.Ownership) !bool {
    const entry = find(heap, instance) orelse return error.InvalidProgram;
    if (entry.dropped) return false;
    switch (ownership) {
        .root => {
            if (entry.roots != 0) entry.roots -= 1;
        },
        .edge => {
            if (entry.edges != 0) entry.edges -= 1;
        },
    }
    if (entry.roots != 0 or entry.edges != 0) {
        if (ownership == .root and entry.roots == 0 and try collectCycle(allocator, heap, entry)) return true;
        return false;
    }
    entry.dropped = true;
    return true;
}

const Candidate = struct {
    entry: *Entry,
    incoming: usize,
};

fn collectCycle(allocator: std.mem.Allocator, heap: []Entry, root: *Entry) TraceError!bool {
    var candidates: std.ArrayList(Candidate) = .empty;
    defer candidates.deinit(allocator);
    try candidates.append(allocator, .{ .entry = root, .incoming = 0 });
    try traceStructure(allocator, heap, &candidates, root.instance);
    for (candidates.items) |candidate| {
        if (candidate.entry.roots != 0 or candidate.entry.edges > candidate.incoming) return false;
    }
    for (candidates.items) |candidate| {
        candidate.entry.roots = 0;
        candidate.entry.edges = 0;
    }
    root.dropped = true;
    return true;
}

fn traceStructure(allocator: std.mem.Allocator, heap: []Entry, candidates: *std.ArrayList(Candidate), structure: *const Value.Structure) TraceError!void {
    for (structure.fields) |*field| try traceValue(allocator, heap, candidates, field);
}

fn traceValue(allocator: std.mem.Allocator, heap: []Entry, candidates: *std.ArrayList(Candidate), value: *const Value) TraceError!void {
    switch (value.*) {
        .class => |class| {
            const entry = find(heap, class.instance) orelse return error.InvalidProgram;
            for (candidates.items) |*candidate| if (candidate.entry == entry) {
                candidate.incoming += 1;
                return;
            };
            try candidates.append(allocator, .{ .entry = entry, .incoming = 1 });
            try traceStructure(allocator, heap, candidates, entry.instance);
        },
        .structure => |structure| for (structure.fields) |*field| try traceValue(allocator, heap, candidates, field),
        .view => |view| for (view.fields) |*field| try traceValue(allocator, heap, candidates, field),
        .protocol => |protocol| try traceValue(allocator, heap, candidates, protocol.concrete),
        .enumeration => |enumeration| for (enumeration.values) |*field| try traceValue(allocator, heap, candidates, field),
        .optional => |optional| if (optional.value) |present| try traceValue(allocator, heap, candidates, present),
        .function => |function| for (function.captures) |*capture| try traceValue(allocator, heap, candidates, capture),
        else => {},
    }
}

fn find(heap: []Entry, instance: *Value.Structure) ?*Entry {
    for (heap) |*entry| if (entry.instance == instance) return entry;
    return null;
}
