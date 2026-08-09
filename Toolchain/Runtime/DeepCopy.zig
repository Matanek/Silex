const optional_flag: u64 = 0x80000000;
const structure_base: u64 = 0x100;
const scalar_limit: u64 = 13;
const entry_words: usize = 4;
const list_header_words: usize = 3;

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
        return @intCast(self.entry(type_value)[1]);
    }

    fn data(self: Context, entry_value: [*]const u64) [*]const u64 {
        return self.model + @as(usize, @intCast(entry_value[2]));
    }
};

pub fn main() void {}

export fn silex_deep_copy(source: [*]const u64, destination: [*]u64, model: [*]const u64, type_value: u64) callconv(.c) u64 {
    const context: Context = .{ .model = model };
    if (!cloneValue(context, source, destination, type_value)) return 1;
    cleanupValue(context, destination, type_value);
    return 0;
}

fn cloneValue(context: Context, source: [*]const u64, destination: [*]u64, type_value: u64) bool {
    if (type_value & optional_flag != 0) {
        destination[0] = source[0];
        const child = type_value & ~optional_flag;
        if (source[0] != 0) return cloneValue(context, source + 1, destination + 1, child);
        clear(destination + 1, context.width(child));
        return true;
    }
    if (type_value <= scalar_limit) {
        if (type_value != 0) destination[0] = source[0];
        return true;
    }

    const entry_value = context.entry(type_value);
    const data = context.data(entry_value);
    return switch (@as(Kind, @enumFromInt(entry_value[0]))) {
        .value => cloneFields(context, source, destination, data, @intCast(entry_value[3])),
        .class => cloneClass(context, source, destination, data),
        .protocol => cloneProtocol(context, source, destination, data, @intCast(entry_value[1])),
        .list => cloneList(context, source, destination, data[0]),
        .array => cloneArray(context, source, destination, data[0], @intCast(data[1])),
        .enumeration => cloneEnumeration(context, source, destination, data, @intCast(entry_value[1])),
    };
}

fn cloneFields(context: Context, source: [*]const u64, destination: [*]u64, fields: [*]const u64, count: usize) bool {
    var offset: usize = 0;
    for (0..count) |index| {
        const field_type = fields[index];
        if (!cloneValue(context, source + offset, destination + offset, field_type)) return false;
        offset += context.width(field_type);
    }
    return true;
}

fn cloneClass(context: Context, source: [*]const u64, destination: [*]u64, data: [*]const u64) bool {
    const original: [*]u64 = @ptrFromInt(source[0]);
    if (original[2] != 0) {
        destination[0] = original[2];
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
        const clone = allocate((object_width + 3) * @sizeOf(u64)) orelse return false;
        clone[0] = dynamic_type;
        clone[1] = 0;
        clone[2] = @intFromPtr(original);
        original[2] = @intFromPtr(clone);
        destination[0] = @intFromPtr(clone);
        return cloneFields(context, original + 3, clone + 3, data + cursor, field_count);
    }
    return false;
}

fn cloneProtocol(context: Context, source: [*]const u64, destination: [*]u64, data: [*]const u64, width: usize) bool {
    clear(destination, width);
    destination[0] = source[0];
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const structure = data[cursor];
        const concrete_type = data[cursor + 1];
        cursor += 2;
        if (structure == source[0]) return cloneValue(context, source + 1, destination + 1, concrete_type);
    }
    return false;
}

fn cloneList(context: Context, source: [*]const u64, destination: [*]u64, element_type: u64) bool {
    const original: [*]const u64 = @ptrFromInt(source[0]);
    const count: usize = @intCast(original[0]);
    const element_width = context.width(element_type);
    const byte_count = (list_header_words + count * element_width) * @sizeOf(u64);
    const clone = allocate(byte_count) orelse return false;
    clone[0] = count;
    clone[1] = 1;
    clone[2] = byte_count;
    destination[0] = @intFromPtr(clone);
    for (0..count) |index| {
        const offset = list_header_words + index * element_width;
        if (!cloneValue(context, original + offset, clone + offset, element_type)) return false;
    }
    return true;
}

fn cloneArray(context: Context, source: [*]const u64, destination: [*]u64, element_type: u64, count: usize) bool {
    const width = context.width(element_type);
    for (0..count) |index| {
        const offset = index * width;
        if (!cloneValue(context, source + offset, destination + offset, element_type)) return false;
    }
    return true;
}

fn cloneEnumeration(context: Context, source: [*]const u64, destination: [*]u64, data: [*]const u64, width: usize) bool {
    clear(destination, width);
    destination[0] = source[0];
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |variant| {
        const count: usize = @intCast(data[cursor]);
        cursor += 1;
        if (variant == source[0]) return cloneFields(context, source + 1, destination + 1, data + cursor, count);
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
    if (clone[2] == 0) return;
    const original: [*]u64 = @ptrFromInt(clone[2]);
    clone[2] = 0;
    original[2] = 0;
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const structure = data[cursor];
        const field_count: usize = @intCast(data[cursor + 2]);
        cursor += 3;
        if (structure == clone[0]) {
            cleanupFields(context, clone + 3, data + cursor, field_count);
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

fn clear(destination: [*]u64, count: usize) void {
    for (0..count) |index| destination[index] = 0;
}

fn allocate(byte_count: usize) ?[*]u64 {
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
    return @ptrFromInt(result);
}
