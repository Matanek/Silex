const std = @import("std");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");

const Allocator = std.mem.Allocator;
pub const Error = Allocator.Error || error{InvalidProgram};

pub const Value = union(enum) {
    void,
    integer: i64,
    typed_integer: Numeric.Integer,
    float32: f32,
    float64: f64,
    boolean: bool,
    string: []const u8,
    structure: Structure,
    class: Class,
    protocol: Protocol,
    view: View,
    enumeration: *const Enumeration,
    optional: Optional,
    reference: Reference,
    function: Function,
    storage: Ir.Type,

    pub const Function = struct {
        type: Ir.Type,
        id: Ir.FunctionId,
        captures: []const Value = &.{},
    };

    pub const Reference = union(enum) {
        optional: *?Value,
        value: *Value,

        pub fn load(self: Reference) Error!Value {
            return switch (self) {
                .optional => |pointer| pointer.* orelse error.InvalidProgram,
                .value => |pointer| pointer.*,
            };
        }

        pub fn store(self: Reference, value: Value) void {
            switch (self) {
                .optional => |pointer| pointer.* = value,
                .value => |pointer| pointer.* = value,
            }
        }
    };

    pub const Structure = struct {
        type: Ir.Type,
        fields: []Value,
    };

    pub const Class = struct {
        static_type: Ir.Type,
        instance: *Structure,
    };

    pub const Protocol = struct {
        type: Ir.Type,
        concrete: *const Value,
    };

    pub const View = struct {
        type: Ir.Type,
        fields: []Value,
    };

    pub const Optional = struct {
        type: Ir.Type,
        value: ?*const Value,
    };

    pub const Enumeration = struct {
        type: Ir.Type,
        enumeration: usize,
        variant: usize,
        values: []const Value,
    };

    pub fn typeOf(self: Value) Ir.Type {
        return switch (self) {
            .void => .void,
            .integer => .int,
            .typed_integer => |value| value.type,
            .float32 => .float32,
            .float64 => .float64,
            .boolean => .bool,
            .string => .str,
            .structure => |value| value.type,
            .class => |value| value.static_type,
            .protocol => |value| value.type,
            .view => |value| value.type,
            .enumeration => |value| value.type,
            .optional => |value| value.type,
            .reference => .address,
            .function => |value| value.type,
            .storage => |type_value| type_value,
        };
    }
};

pub fn clone(allocator: Allocator, value: Value) Error!Value {
    return switch (value) {
        .structure => |aggregate| cloned: {
            const fields = try allocator.alloc(Value, aggregate.fields.len);
            for (aggregate.fields, 0..) |field, index| fields[index] = try clone(allocator, field);
            break :cloned .{ .structure = .{ .type = aggregate.type, .fields = fields } };
        },
        .class, .view => value,
        .protocol => |protocol| cloned: {
            const concrete = try allocator.create(Value);
            concrete.* = try clone(allocator, protocol.concrete.*);
            break :cloned .{ .protocol = .{ .type = protocol.type, .concrete = concrete } };
        },
        .enumeration => |enumeration| cloned: {
            const values = try allocator.alloc(Value, enumeration.values.len);
            for (enumeration.values, 0..) |item, index| values[index] = try clone(allocator, item);
            const copy = try allocator.create(Value.Enumeration);
            copy.* = .{
                .type = enumeration.type,
                .enumeration = enumeration.enumeration,
                .variant = enumeration.variant,
                .values = values,
            };
            break :cloned .{ .enumeration = copy };
        },
        .optional => |optional| cloned: {
            const payload = if (optional.value) |present| payload: {
                const copy = try allocator.create(Value);
                copy.* = try clone(allocator, present.*);
                break :payload copy;
            } else null;
            break :cloned .{ .optional = .{ .type = optional.type, .value = payload } };
        },
        else => value,
    };
}

pub fn equal(left: Value, right: Value) Error!bool {
    if (left.typeOf() != right.typeOf()) return error.InvalidProgram;
    return switch (left) {
        .integer => |value| value == right.integer,
        .typed_integer => |value| value.bits == right.typed_integer.bits and value.type == right.typed_integer.type,
        .float32 => |value| value == right.float32,
        .float64 => |value| value == right.float64,
        .string => |value| std.mem.eql(u8, value, right.string),
        .boolean => |value| value == right.boolean,
        .structure => |aggregate| structure: {
            if (aggregate.fields.len != right.structure.fields.len) return error.InvalidProgram;
            for (aggregate.fields, right.structure.fields) |left_field, right_field| {
                if (!try equal(left_field, right_field)) break :structure false;
            }
            break :structure true;
        },
        .class => |instance| instance.instance == right.class.instance,
        .protocol => error.InvalidProgram,
        .optional => |optional| optional_value: {
            if ((optional.value == null) != (right.optional.value == null)) break :optional_value false;
            if (optional.value) |payload| break :optional_value try equal(payload.*, right.optional.value.?.*);
            break :optional_value true;
        },
        .enumeration => |enumeration| enum_value: {
            if (enumeration.enumeration != right.enumeration.enumeration or
                enumeration.variant != right.enumeration.variant)
            {
                break :enum_value false;
            }
            if (enumeration.values.len != right.enumeration.values.len) return error.InvalidProgram;
            for (enumeration.values, right.enumeration.values) |left_value, right_value| {
                if (!try equal(left_value, right_value)) break :enum_value false;
            }
            break :enum_value true;
        },
        .function => |function| function.id == right.function.id and function.captures.len == right.function.captures.len,
        .view, .reference, .storage, .void => error.InvalidProgram,
    };
}
