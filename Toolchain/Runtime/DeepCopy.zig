const std = @import("std");
const builtin = @import("builtin");

const TestState = if (builtin.is_test) struct {
    var allocation_budget: ?usize = null;
    var live_allocations: usize = 0;
} else struct {};

const optional_flag: u64 = 0x80000000;
const structure_base: u64 = 0x100;
const function_base: u64 = 0x10000000;
const function_end: u64 = 0x20000000;
const scalar_limit: u64 = 13;
const string_type: u64 = 12;
const dynamic_string_flag: u64 = 1 << 63;
const dynamic_string_prefix_words: usize = 2;
const entry_words: usize = 4;
const class_header_words: usize = 4;
const list_header_words: usize = 5;

const Kind = enum(u64) {
    value,
    class,
    protocol,
    list,
    array,
    enumeration,
};

const Context = struct {
    model: [*]const u64,

    fn entry(self: Context, type_value: u64) [*]const u64 {
        return self.model + 1 + @as(usize, @intCast(type_value - structure_base)) * entry_words;
    }

    fn width(self: Context, type_value: u64) usize {
        if (type_value & optional_flag != 0) return 1 + self.width(type_value & ~optional_flag);
        if (type_value <= scalar_limit) return if (type_value == 0) 0 else 1;
        if (type_value >= function_base and type_value < function_end) return 2;
        return @intCast(self.entry(type_value)[1]);
    }

    fn data(self: Context, entry_value: [*]const u64) [*]const u64 {
        return self.model + @as(usize, @intCast(entry_value[2]));
    }
};

pub fn main() void {}

export fn silex_deep_copy(source: [*]const u64, destination: [*]u64, model: [*]const u64, type_value: u64) callconv(.c) u64 {
    const context: Context = .{ .model = model };
    clear(destination, context.width(type_value));
    if (!cloneValue(context, source, destination, type_value, false)) {
        rollbackValue(context, source, destination, type_value);
        clear(destination, context.width(type_value));
        return 1;
    }
    cleanupValue(context, destination, type_value);
    return 0;
}

fn cloneValue(context: Context, source: [*]const u64, destination: [*]u64, type_value: u64, edge: bool) bool {
    if (type_value & optional_flag != 0) {
        destination[0] = source[0];
        const child = type_value & ~optional_flag;
        if (source[0] != 0) return cloneValue(context, source + 1, destination + 1, child, edge);
        clear(destination + 1, context.width(child));
        return true;
    }
    if (type_value <= scalar_limit) {
        if (type_value != 0) destination[0] = source[0];
        if (type_value == string_type and !retainString(source[0])) return false;
        return true;
    }
    if (type_value >= function_base and type_value < function_end) {
        destination[0] = source[0];
        destination[1] = source[1];
        return true;
    }
    if (type_value < structure_base or type_value >= function_base) return false;

    const entry_value = context.entry(type_value);
    const data = context.data(entry_value);
    return switch (@as(Kind, @enumFromInt(entry_value[0]))) {
        .value => cloneFields(context, source, destination, data, @intCast(entry_value[3]), edge),
        .class => cloneClass(context, source, destination, data, edge),
        .protocol => cloneProtocol(context, source, destination, data, @intCast(entry_value[1]), edge),
        .list => cloneList(context, source, destination, data[0], edge),
        .array => cloneArray(context, source, destination, data[0], @intCast(data[1]), edge),
        .enumeration => cloneEnumeration(context, source, destination, data, @intCast(entry_value[1]), edge),
    };
}

fn retainString(value: u64) bool {
    const descriptor: [*]const u64 = @ptrFromInt(value);
    if (descriptor[0] & dynamic_string_flag == 0) return true;
    const allocation: *u64 = @ptrFromInt(value - dynamic_string_prefix_words * @sizeOf(u64));
    var current = @atomicLoad(u64, allocation, .acquire);
    while (current != 0 and current != std.math.maxInt(u64)) {
        if (@cmpxchgWeak(u64, allocation, current, current + 1, .acq_rel, .acquire)) |observed| {
            current = observed;
        } else return true;
    }
    return false;
}

fn cloneFields(context: Context, source: [*]const u64, destination: [*]u64, fields: [*]const u64, count: usize, edge: bool) bool {
    var offset: usize = 0;
    for (0..count) |index| {
        const field_type = fields[index];
        if (!cloneValue(context, source + offset, destination + offset, field_type, edge)) return false;
        offset += context.width(field_type);
    }
    return true;
}

fn cloneClass(context: Context, source: [*]const u64, destination: [*]u64, data: [*]const u64, edge: bool) bool {
    const original: [*]u64 = @ptrFromInt(source[0]);
    if (original[3] != 0) {
        destination[0] = original[3];
        const clone: [*]u64 = @ptrFromInt(destination[0]);
        clone[if (edge) 2 else 1] += 1;
        return true;
    }
    const dynamic_type = original[0];
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const structure = data[cursor];
        const object_width: usize = @intCast(data[cursor + 1]);
        const field_count: usize = @intCast(data[cursor + 2]);
        cursor += 3;
        if (structure != dynamic_type) {
            cursor += field_count;
            continue;
        }
        const clone = allocate((object_width + class_header_words) * @sizeOf(u64)) orelse return false;
        clear(clone, object_width + class_header_words);
        clone[0] = dynamic_type;
        clone[3] = @intFromPtr(original);
        original[3] = @intFromPtr(clone);
        destination[0] = @intFromPtr(clone);
        clone[if (edge) 2 else 1] = 1;
        return cloneFields(context, original + class_header_words, clone + class_header_words, data + cursor, field_count, true);
    }
    return false;
}

fn cloneProtocol(context: Context, source: [*]const u64, destination: [*]u64, data: [*]const u64, width: usize, edge: bool) bool {
    clear(destination, width);
    destination[0] = source[0];
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const structure = data[cursor];
        const concrete_type = data[cursor + 1];
        cursor += 2;
        if (structure == source[0]) return cloneValue(context, source + 1, destination + 1, concrete_type, edge);
    }
    return false;
}

fn cloneList(context: Context, source: [*]const u64, destination: [*]u64, element_type: u64, edge: bool) bool {
    const original: [*]const u64 = @ptrFromInt(source[0]);
    const count: usize = @intCast(original[0]);
    const element_width = context.width(element_type);
    const byte_count = (list_header_words + count * element_width) * @sizeOf(u64);
    const clone = allocate(byte_count) orelse return false;
    clear(clone, list_header_words + count * element_width);
    clone[0] = count;
    clone[if (edge) 2 else 1] = 1;
    clone[3] = byte_count;
    destination[0] = @intFromPtr(clone);
    for (0..count) |index| {
        const offset = list_header_words + index * element_width;
        if (!cloneValue(context, original + offset, clone + offset, element_type, edge)) return false;
    }
    return true;
}

fn cloneArray(context: Context, source: [*]const u64, destination: [*]u64, element_type: u64, count: usize, edge: bool) bool {
    const width = context.width(element_type);
    for (0..count) |index| {
        const offset = index * width;
        if (!cloneValue(context, source + offset, destination + offset, element_type, edge)) return false;
    }
    return true;
}

fn cloneEnumeration(context: Context, source: [*]const u64, destination: [*]u64, data: [*]const u64, width: usize, edge: bool) bool {
    clear(destination, width);
    destination[0] = source[0];
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |variant| {
        const count: usize = @intCast(data[cursor]);
        cursor += 1;
        if (variant == source[0]) return cloneFields(context, source + 1, destination + 1, data + cursor, count, edge);
        cursor += count;
    }
    return false;
}

fn cleanupValue(context: Context, value: [*]u64, type_value: u64) void {
    if (type_value & optional_flag != 0) {
        if (value[0] != 0) cleanupValue(context, value + 1, type_value & ~optional_flag);
        return;
    }
    if (type_value <= scalar_limit) return;
    if (type_value >= function_base and type_value < function_end) return;
    if (type_value < structure_base or type_value >= function_base) return;
    const entry_value = context.entry(type_value);
    const data = context.data(entry_value);
    switch (@as(Kind, @enumFromInt(entry_value[0]))) {
        .value => cleanupFields(context, value, data, @intCast(entry_value[3])),
        .class => cleanupClass(context, value, data),
        .protocol => cleanupProtocol(context, value, data),
        .list => cleanupList(context, value, data[0]),
        .array => cleanupArray(context, value, data[0], @intCast(data[1])),
        .enumeration => cleanupEnumeration(context, value, data),
    }
}

fn cleanupFields(context: Context, value: [*]u64, fields: [*]const u64, count: usize) void {
    var offset: usize = 0;
    for (0..count) |index| {
        const field_type = fields[index];
        cleanupValue(context, value + offset, field_type);
        offset += context.width(field_type);
    }
}

fn cleanupClass(context: Context, value: [*]u64, data: [*]const u64) void {
    const clone: [*]u64 = @ptrFromInt(value[0]);
    if (clone[3] == 0) return;
    const original: [*]u64 = @ptrFromInt(clone[3]);
    clone[3] = 0;
    original[3] = 0;
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const structure = data[cursor];
        const field_count: usize = @intCast(data[cursor + 2]);
        cursor += 3;
        if (structure == clone[0]) {
            cleanupFields(context, clone + class_header_words, data + cursor, field_count);
            return;
        }
        cursor += field_count;
    }
}

fn cleanupProtocol(context: Context, value: [*]u64, data: [*]const u64) void {
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const structure = data[cursor];
        const concrete_type = data[cursor + 1];
        cursor += 2;
        if (structure == value[0]) {
            cleanupValue(context, value + 1, concrete_type);
            return;
        }
    }
}

fn cleanupList(context: Context, value: [*]u64, element_type: u64) void {
    const list: [*]u64 = @ptrFromInt(value[0]);
    const width = context.width(element_type);
    for (0..@as(usize, @intCast(list[0]))) |index| cleanupValue(context, list + list_header_words + index * width, element_type);
}

fn cleanupArray(context: Context, value: [*]u64, element_type: u64, count: usize) void {
    const width = context.width(element_type);
    for (0..count) |index| cleanupValue(context, value + index * width, element_type);
}

fn cleanupEnumeration(context: Context, value: [*]u64, data: [*]const u64) void {
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |variant| {
        const count: usize = @intCast(data[cursor]);
        cursor += 1;
        if (variant == value[0]) {
            cleanupFields(context, value + 1, data + cursor, count);
            return;
        }
        cursor += count;
    }
}

/// Reverses every retain and mapping produced by a failed clone. Source and
/// destination are walked together so class cycles are cut through the
/// original object's scratch mapping before any clone allocation is unmapped.
fn rollbackValue(context: Context, source: [*]const u64, destination: [*]u64, type_value: u64) void {
    if (type_value & optional_flag != 0) {
        if (destination[0] != 0) rollbackValue(context, source + 1, destination + 1, type_value & ~optional_flag);
        return;
    }
    if (type_value <= scalar_limit) {
        if (type_value == string_type and destination[0] != 0) releaseString(destination[0]);
        return;
    }
    if (type_value >= function_base and type_value < function_end) return;
    if (type_value < structure_base or type_value >= function_base) return;
    const entry_value = context.entry(type_value);
    const data = context.data(entry_value);
    switch (@as(Kind, @enumFromInt(entry_value[0]))) {
        .value => rollbackFields(context, source, destination, data, @intCast(entry_value[3])),
        .class => rollbackClass(context, source, data),
        .protocol => rollbackProtocol(context, source, destination, data),
        .list => rollbackList(context, source, destination, data[0]),
        .array => rollbackArray(context, source, destination, data[0], @intCast(data[1])),
        .enumeration => rollbackEnumeration(context, source, destination, data),
    }
}

fn rollbackFields(context: Context, source: [*]const u64, destination: [*]u64, fields: [*]const u64, count: usize) void {
    var offset: usize = 0;
    for (0..count) |index| {
        const field_type = fields[index];
        rollbackValue(context, source + offset, destination + offset, field_type);
        offset += context.width(field_type);
    }
}

fn rollbackClass(context: Context, source: [*]const u64, data: [*]const u64) void {
    if (source[0] == 0) return;
    const original: [*]u64 = @ptrFromInt(source[0]);
    if (original[3] == 0) return;
    const clone: [*]u64 = @ptrFromInt(original[3]);
    original[3] = 0;
    clone[3] = 0;
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const structure = data[cursor];
        const object_width: usize = @intCast(data[cursor + 1]);
        const field_count: usize = @intCast(data[cursor + 2]);
        cursor += 3;
        if (structure == original[0]) {
            rollbackFields(context, original + class_header_words, clone + class_header_words, data + cursor, field_count);
            release(@ptrCast(clone), (object_width + class_header_words) * @sizeOf(u64));
            return;
        }
        cursor += field_count;
    }
}

fn rollbackProtocol(context: Context, source: [*]const u64, destination: [*]u64, data: [*]const u64) void {
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const structure = data[cursor];
        const concrete_type = data[cursor + 1];
        cursor += 2;
        if (structure == destination[0]) {
            rollbackValue(context, source + 1, destination + 1, concrete_type);
            return;
        }
    }
}

fn rollbackList(context: Context, source: [*]const u64, destination: [*]u64, element_type: u64) void {
    if (destination[0] == 0) return;
    const original: [*]const u64 = @ptrFromInt(source[0]);
    const clone: [*]u64 = @ptrFromInt(destination[0]);
    const count: usize = @intCast(clone[0]);
    const width = context.width(element_type);
    for (0..count) |index| {
        const offset = list_header_words + index * width;
        rollbackValue(context, original + offset, clone + offset, element_type);
    }
    release(@ptrCast(clone), @intCast(clone[3]));
}

fn rollbackArray(context: Context, source: [*]const u64, destination: [*]u64, element_type: u64, count: usize) void {
    const width = context.width(element_type);
    for (0..count) |index| rollbackValue(context, source + index * width, destination + index * width, element_type);
}

fn rollbackEnumeration(context: Context, source: [*]const u64, destination: [*]u64, data: [*]const u64) void {
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |variant| {
        const count: usize = @intCast(data[cursor]);
        cursor += 1;
        if (variant == destination[0]) {
            rollbackFields(context, source + 1, destination + 1, data + cursor, count);
            return;
        }
        cursor += count;
    }
}

fn releaseString(value: u64) void {
    const descriptor: [*]const u64 = @ptrFromInt(value);
    if (descriptor[0] & dynamic_string_flag == 0) return;
    const allocation: [*]u64 = @ptrFromInt(value - dynamic_string_prefix_words * @sizeOf(u64));
    const reference_count: *u64 = @ptrCast(allocation);
    var current = @atomicLoad(u64, reference_count, .acquire);
    while (current != 0) {
        if (@cmpxchgWeak(u64, reference_count, current, current - 1, .acq_rel, .acquire)) |observed| {
            current = observed;
        } else {
            if (current == 1) release(@ptrCast(allocation), @intCast(allocation[1]));
            return;
        }
    }
}

fn clear(destination: [*]u64, count: usize) void {
    for (0..count) |index| destination[index] = 0;
}

fn allocate(byte_count: usize) ?[*]u64 {
    if (builtin.is_test) {
        if (TestState.allocation_budget) |remaining| {
            if (remaining == 0) return null;
            TestState.allocation_budget = remaining - 1;
        }
    }
    var result: usize = 0;
    asm volatile ("svc #0x80"
        : [result] "={x0}" (result),
        : [address] "{x0}" (@as(usize, 0)),
          [size] "{x1}" (byte_count),
          [protection] "{x2}" (@as(usize, 3)),
          [flags] "{x3}" (@as(usize, 0x1002)),
          [descriptor] "{x4}" (~@as(usize, 0)),
          [offset] "{x5}" (@as(usize, 0)),
          [number] "{x16}" (@as(usize, 197)),
        : .{ .memory = true });
    if (@as(isize, @bitCast(result)) < 0) return null;
    if (builtin.is_test) TestState.live_allocations += 1;
    return @ptrFromInt(result);
}

fn release(address: [*]u8, byte_count: usize) void {
    _ = asm volatile ("svc #0x80"
        : [result] "={x0}" (-> usize),
        : [address] "{x0}" (@intFromPtr(address)),
          [size] "{x1}" (byte_count),
          [number] "{x16}" (@as(usize, 73)),
        : .{ .memory = true });
    if (builtin.is_test) TestState.live_allocations -= 1;
}

test "failed nested clone rolls back every allocation and mapping" {
    // Two model entries: list<list<int>> and list<int>.
    const outer_type = structure_base;
    const inner_type = structure_base + 1;
    const model = [_]u64{
        2,
        @intFromEnum(Kind.list),
        1,
        9,
        0,
        @intFromEnum(Kind.list),
        1,
        10,
        0,
        inner_type,
        4,
    };
    var inner = [_]u64{ 1, 1, 0, 0, 0, 73 };
    var outer = [_]u64{ 1, 1, 0, 0, 0, @intFromPtr(&inner) };
    var source = [_]u64{@intFromPtr(&outer)};
    var destination = [_]u64{0};

    TestState.allocation_budget = 1;
    TestState.live_allocations = 0;
    defer TestState.allocation_budget = null;

    try std.testing.expectEqual(@as(u64, 1), silex_deep_copy(&source, &destination, &model, outer_type));
    try std.testing.expectEqual(@as(u64, 0), destination[0]);
    try std.testing.expectEqual(@as(usize, 0), TestState.live_allocations);
}

test "successful root clones own exactly one releasable root" {
    const list_type = structure_base;
    const list_model = [_]u64{
        1,
        @intFromEnum(Kind.list),
        1,
        5,
        0,
        4,
    };
    var original_list = [_]u64{ 1, 1, 0, 0, 0, 73 };
    var list_source = [_]u64{@intFromPtr(&original_list)};
    var list_destination = [_]u64{0};

    TestState.live_allocations = 0;
    try std.testing.expectEqual(@as(u64, 0), silex_deep_copy(&list_source, &list_destination, &list_model, list_type));
    const list_clone: [*]u64 = @ptrFromInt(list_destination[0]);
    try std.testing.expectEqual(@as(u64, 1), list_clone[1]);
    try std.testing.expectEqual(@as(u64, 0), list_clone[2]);
    release(@ptrCast(list_clone), @intCast(list_clone[3]));

    const class_type = structure_base;
    const class_model = [_]u64{
        1,
        @intFromEnum(Kind.class),
        1,
        5,
        0,
        1,
        0,
        0,
        0,
    };
    var original_class = [_]u64{ 0, 1, 0, 0 };
    var class_source = [_]u64{@intFromPtr(&original_class)};
    var class_destination = [_]u64{0};
    try std.testing.expectEqual(@as(u64, 0), silex_deep_copy(&class_source, &class_destination, &class_model, class_type));
    const class_clone: [*]u64 = @ptrFromInt(class_destination[0]);
    try std.testing.expectEqual(@as(u64, 1), class_clone[1]);
    try std.testing.expectEqual(@as(u64, 0), class_clone[2]);
    release(@ptrCast(class_clone), 4 * @sizeOf(u64));
    try std.testing.expectEqual(@as(usize, 0), TestState.live_allocations);
}
