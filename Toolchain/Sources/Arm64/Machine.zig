const std = @import("std");
const MathBoundary = @import("../Math/Boundary.zig");
const Types = @import("../Types.zig");

const Allocator = std.mem.Allocator;

pub const max_register_arguments = 8;
pub const max_external_arguments = 10;
pub const max_slots = 4095;
pub const slot_size = 8;

pub const FunctionId = usize;
pub const Slot = u12;
pub const Span = struct {
    start: Slot,
    width: u12,
    aggregate: bool = false,
};
pub const Error = Allocator.Error || error{
    InvalidMachineProgram,
    TooManyArguments,
    FrameTooLarge,
    UnsupportedType,
};

pub const Status = enum(u8) {
    success = 0,
    integer_overflow = 1,
    division_by_zero = 2,
    runtime_failure = 3,
};

pub const UnaryOperator = enum {
    negate,
};

pub const BinaryOperator = enum {
    add,
    subtract,
    multiply,
    divide,
    remainder,
    less,
    less_equal,
    greater,
    greater_equal,
    equal,
    not_equal,
    bit_and,
    bit_xor,
    shift_left,
    shift_right,
};

pub const PrintKind = enum { signed_integer, unsigned_integer, float32, float64, boolean, string };

pub const Instruction = union(enum) {
    constant_int: ConstantInt,
    constant_bool: ConstantBool,
    constant_str: ConstantStr,
    constant_bytes: ConstantBytes,
    constant_float32: ConstantFloat32,
    constant_float64: ConstantFloat64,
    optional_null: OptionalNull,
    optional_some: OptionalSome,
    optional_unwrap: OptionalUnwrap,
    copy: Copy,
    copy_range: CopyRange,
    deep_copy: DeepCopy,
    global_load: GlobalLoad,
    global_store: GlobalStore,
    local_address: LocalAddress,
    reference_load: ReferenceLoad,
    address_load: AddressLoad,
    address_store: AddressStore,
    reference_store: ReferenceStore,
    reference_offset: ReferenceOffset,
    reference_indirect_offset: ReferenceOffset,
    aggregate_init: AggregateInit,
    protocol_init: ProtocolInit,
    protocol_test: ProtocolTest,
    protocol_extract: ProtocolExtract,
    class_init: ClassInit,
    class_load: ClassLoad,
    class_store: ClassStore,
    class_retain: ClassRetain,
    class_drop: ClassDrop,
    list_retain: ListResource,
    list_drop: ListResource,
    list_init: ListInit,
    enum_init: EnumInit,
    enum_test: EnumTest,
    collection_load: CollectionLoad,
    collection_reference: CollectionReference,
    collection_replace: CollectionReplace,
    collection_count: CollectionCount,
    list_edit: ListEdit,
    collection_slice: CollectionSlice,
    collection_view: CollectionView,
    aggregate_equal: AggregateEqual,
    convert: Convert,
    format_value: FormatValue,
    string_concat: StringConcat,
    string_count: StringCount,
    string_byte_at: StringByteAt,
    string_from_bytes: StringFromBytes,
    unary: Unary,
    binary: Binary,
    function_address: FunctionAddress,
    call: Call,
    indirect_call: IndirectCall,
    external_call: ExternalCall,
    dynamic_call: DynamicCall,
    print: Print,
    assert: Assert,
    mutex_lock,
    mutex_unlock,
    panic: Panic,
    return_value: Span,
    return_void,
    jump: usize,
    branch: Branch,

    pub const ConstantInt = struct {
        result: Slot,
        bits: u64,
        type: Types.Type = .int,
    };

    pub const ConstantBool = struct {
        result: Slot,
        value: bool,
    };

    pub const ConstantStr = struct {
        result: Slot,
        string: usize,
    };

    pub const ConstantBytes = struct {
        result: Slot,
        string: usize,
    };

    pub const ConstantFloat32 = struct {
        result: Slot,
        bits: u32,
    };

    pub const ConstantFloat64 = struct {
        result: Slot,
        bits: u64,
    };

    pub const OptionalNull = struct {
        result: Span,
    };

    pub const OptionalSome = struct {
        result: Span,
        operand: Span,
    };

    pub const OptionalUnwrap = struct {
        result: Span,
        operand: Span,
    };

    pub const Copy = struct {
        result: Slot,
        operand: Slot,
    };

    pub const CopyRange = struct {
        result: Span,
        operand: Span,
    };

    pub const DeepCopy = struct {
        result: Span,
        operand: Span,
        type: Types.Type,
    };

    pub const LocalAddress = struct {
        result: Slot,
        local: Slot,
    };

    pub const ReferenceLoad = struct {
        result: Span,
        reference: Slot,
    };

    pub const AddressLoad = struct {
        result: Slot,
        address: Slot,
        byte_offset: Slot,
        type: Types.Type,
    };

    pub const AddressStore = struct {
        address: Slot,
        byte_offset: Slot,
        operand: Slot,
        type: Types.Type,
    };

    pub const ReferenceStore = struct {
        reference: Slot,
        operand: Span,
    };

    pub const ReferenceOffset = struct {
        result: Slot,
        reference: Slot,
        byte_offset: u32,
    };

    pub const GlobalLoad = struct { result: Span, global: usize };
    pub const GlobalStore = struct { operand: Span, global: usize };

    pub const AggregateInit = struct {
        result: Span,
        fields: []const Span,
    };

    pub const ProtocolInit = struct {
        result: Span,
        operand: Span,
        structure: u64,
        class_operand: bool,
    };

    pub const ProtocolTest = struct {
        result: Slot,
        operand: Slot,
        structure: u64,
    };

    pub const ProtocolExtract = struct {
        result: Span,
        operand: Span,
    };

    pub const ClassInit = struct {
        result: Slot,
        structure: u64,
        fields: []const Span,
    };

    pub const ClassLoad = struct {
        result: Span,
        base: Slot,
        byte_offset: u32,
    };

    pub const ClassStore = struct {
        result: Slot,
        base: Slot,
        byte_offset: u32,
        replacement: Span,
    };

    pub const ClassRetain = struct { operand: Slot };
    pub const ListResource = struct {
        operand: Slot,
        deallocate: bool = false,
    };

    pub const ClassDrop = struct {
        operand: Slot,
        plans: []const Plan,

        pub const Plan = struct {
            structure: usize,
            functions: []const usize,
        };
    };

    pub const ListInit = struct {
        result: Slot,
        values: []const Span,
        element_width: u12,
    };

    pub const EnumInit = struct {
        result: Span,
        tag: u64,
        values: []const Span,
        raw_value: ?EnumRawValue = null,
    };

    pub const EnumRawValue = union(enum) { integer: u64, string: usize };

    pub const EnumTest = struct {
        result: Slot,
        operand: Span,
        tag: u64,
    };

    pub const CollectionLoad = struct {
        result: Span,
        collection: Span,
        index: Slot,
        count: u32,
        dynamic: bool = false,
        view: bool = false,
        header: usize,
        tail: usize,
    };

    pub const CollectionReference = struct {
        result: Slot,
        collection: Span,
        reference: ?Slot,
        index: Slot,
        element_width: u12,
        count: u32,
        dynamic: bool = false,
        view: bool = false,
        header: usize,
        tail: usize,
    };

    pub const CollectionReplace = struct {
        result: Span,
        collection: Span,
        index: Slot,
        replacement: Span,
        count: u32,
        dynamic: bool = false,
        view: bool = false,
        header: usize,
        tail: usize,
    };

    pub const CollectionCount = struct {
        result: Slot,
        collection: Span,
        view: bool = false,
    };

    pub const ListEdit = struct {
        result: Slot,
        collection: Slot,
        kind: @import("../Ir.zig").Instruction.ListEditKind,
        index: ?Slot,
        argument: ?Span,
        argument_dynamic: bool = false,
        argument_transferred: bool = false,
        argument_count: u32 = 0,
        removed: ?Span,
        element_width: u12,
        header: usize,
        tail: usize,
    };

    pub const CollectionSlice = struct {
        result: Slot,
        collection: Span,
        start: Slot,
        end: Slot,
        count: u32,
        dynamic: bool,
        view: bool = false,
        element_width: u12,
    };

    pub const CollectionView = struct {
        result: Span,
        collection: Span,
        reference: ?Slot,
        start: Slot,
        end: Slot,
        count: u32,
        dynamic: bool,
        source_view: bool,
        element_width: u12,
    };

    pub const AggregateEqual = struct {
        result: Slot,
        left: Span,
        right: Span,
        leaves: []const EqualityLeaf,
        equal: bool,
    };

    pub const EqualityLeaf = struct {
        offset: u12,
        type: Types.Type,
        guards: []const EqualityGuard = &.{},
    };

    pub const EqualityGuard = struct {
        offset: u12,
        expected: u64,
    };

    pub const Convert = struct {
        result: Slot,
        operand: Slot,
        source: Types.Type,
        target: Types.Type,
        header: usize,
        checked: bool,
    };

    pub const FormatValue = struct {
        result: Slot,
        operand: Slot,
        kind: PrintKind,
    };

    pub const StringConcat = struct {
        result: Slot,
        left: Slot,
        right: Slot,
    };

    pub const StringCount = struct {
        result: Slot,
        operand: Slot,
    };

    pub const Unary = struct {
        result: Slot,
        operator: UnaryOperator,
        operand: Slot,
        type: Types.Type = .int,
    };

    pub const Binary = struct {
        result: Slot,
        operator: BinaryOperator,
        left: Slot,
        right: Slot,
        type: Types.Type = .int,
    };

    pub const StringByteAt = struct {
        result: Slot,
        operand: Slot,
        index: Slot,
    };

    pub const StringFromBytes = struct {
        result: Slot,
        bytes: Span,
    };

    pub const Call = struct {
        result: ?Span,
        function: FunctionId,
        arguments: []const Span,
    };

    pub const FunctionAddress = struct {
        result: Span,
        function: FunctionId,
        captures: []const Slot = &.{},
        environment: ?Span = null,
    };

    pub const IndirectCall = struct {
        result: ?Span,
        callee: Slot,
        arguments: []const Span,
        return_type: Types.Type,
    };

    pub const ExternalCall = struct {
        result: ?Slot,
        function: usize,
        arguments: []const Slot,
    };

    pub const DynamicCall = struct {
        result: ?Span,
        function: FunctionId,
        receiver: Slot,
        arguments: []const Span,
        implementations: []const Implementation,

        pub const Implementation = struct {
            structure: u64,
            function: FunctionId,
        };
    };

    pub const Print = struct {
        value: Slot,
        kind: PrintKind,
        newline: bool,
    };

    pub const Assert = struct {
        condition: Slot,
        message: Slot,
        header: usize,
    };

    pub const Panic = struct {
        message: Slot,
        header: usize,
    };

    pub const Branch = struct {
        condition: Slot,
        then_instruction: usize,
        else_instruction: usize,
    };
};

pub const Function = struct {
    name: []const u8,
    parameter_count: u4,
    parameters: []const Span = &.{},
    capture_parameters: []const Span = &.{},
    return_type: Types.Type,
    return_width: u12 = 0,
    return_aggregate: bool = false,
    recoverable_entry_result: bool = false,
    hidden_return_slot: ?Slot = null,
    slot_count: u12,
    frame_size: u16,
    /// Release-only residence map indexed by virtual slot. Null keeps the
    /// value in its deterministic stack slot.
    register_slots: []const ?u5 = &.{},
    instructions: []const Instruction,
};

pub const Program = struct {
    functions: []const Function,
    external_functions: []const ExternalFunction = &.{},
    globals: []const Global = &.{},
    strings: []const []const u8 = &.{},
    copy_model: []const u64 = &.{},
    mutex_global: ?usize = null,
    mutex_lock_function: ?usize = null,
    mutex_unlock_function: ?usize = null,
};

pub const AbiValue = enum { int32, read_address, uint64, int64, float32, float64 };

pub const ExternalFunction = struct {
    provider: []const u8,
    source_name: []const u8,
    signature: Signature,
    package_private: bool = false,

    pub const Signature = struct {
        arguments: []const AbiValue,
        result: ?AbiValue,
    };
};

pub const Global = struct { bits: u64, width: u12 = 1 };

pub fn checkedSlot(value: usize) Error!Slot {
    if (value > max_slots) return error.FrameTooLarge;
    return @intCast(value);
}

pub fn checkedArgumentCount(value: usize) Error!u4 {
    if (value > max_register_arguments) return error.TooManyArguments;
    return @intCast(value);
}

pub fn frameSize(slots: usize) Error!u16 {
    if (slots > max_slots) return error.FrameTooLarge;
    const bytes = slots * slot_size;
    return @intCast(std.mem.alignForward(usize, bytes, 16));
}

pub fn slotOffset(slot: Slot) u16 {
    return @as(u16, slot) * slot_size;
}

pub fn validate(program: Program) Error!void {
    for (program.functions) |function| {
        if (function.parameter_count > max_register_arguments) return error.TooManyArguments;
        if (function.register_slots.len == 0) {
            if (function.frame_size != try frameSize(function.slot_count)) return error.InvalidMachineProgram;
        } else if (function.frame_size > try frameSize(function.slot_count) or function.frame_size % 16 != 0) {
            return error.InvalidMachineProgram;
        }
        if (function.register_slots.len != 0 and function.register_slots.len != function.slot_count) {
            return error.InvalidMachineProgram;
        }
        for (function.instructions) |instruction| {
            switch (instruction) {
                .constant_int => |value| try requireSlot(function, value.result),
                .constant_bool => |value| try requireSlot(function, value.result),
                .constant_str => |value| {
                    try requireSlot(function, value.result);
                    if (value.string >= program.strings.len) return error.InvalidMachineProgram;
                },
                .constant_bytes => |value| {
                    try requireSlot(function, value.result);
                    if (value.string >= program.strings.len) return error.InvalidMachineProgram;
                },
                .constant_float32 => |value| try requireSlot(function, value.result),
                .constant_float64 => |value| try requireSlot(function, value.result),
                .optional_null => |value| {
                    try requireSpan(function, value.result);
                    if (!value.result.aggregate or value.result.width < 2) return error.InvalidMachineProgram;
                },
                .optional_some => |value| {
                    try requireSpan(function, value.result);
                    try requireSpan(function, value.operand);
                    if (!value.result.aggregate or value.result.width != value.operand.width + 1) return error.InvalidMachineProgram;
                },
                .optional_unwrap => |value| {
                    try requireSpan(function, value.result);
                    try requireSpan(function, value.operand);
                    if (value.operand.width != value.result.width or value.operand.aggregate != value.result.aggregate) {
                        return error.InvalidMachineProgram;
                    }
                },
                .copy => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.operand);
                },
                .copy_range => |value| {
                    try requireSpan(function, value.result);
                    try requireSpan(function, value.operand);
                    if (value.result.width != value.operand.width) return error.InvalidMachineProgram;
                },
                .deep_copy => |value| {
                    try requireSpan(function, value.result);
                    try requireSpan(function, value.operand);
                    if (value.result.width != value.operand.width or program.copy_model.len == 0) return error.InvalidMachineProgram;
                },
                .global_load => |value| {
                    try requireSpan(function, value.result);
                    if (value.global >= program.globals.len) return error.InvalidMachineProgram;
                },
                .global_store => |value| {
                    try requireSpan(function, value.operand);
                    if (value.global >= program.globals.len) return error.InvalidMachineProgram;
                },
                .local_address => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.local);
                },
                .reference_load => |value| {
                    try requireSpan(function, value.result);
                    try requireSlot(function, value.reference);
                },
                .address_load => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.address);
                    try requireSlot(function, value.byte_offset);
                    if (!value.type.isInteger() and !value.type.isFloat() and value.type != .address) return error.InvalidMachineProgram;
                },
                .address_store => |value| {
                    try requireSlot(function, value.address);
                    try requireSlot(function, value.byte_offset);
                    try requireSlot(function, value.operand);
                    if (!value.type.isInteger() and !value.type.isFloat()) return error.InvalidMachineProgram;
                },
                .reference_store => |value| {
                    try requireSlot(function, value.reference);
                    try requireSpan(function, value.operand);
                },
                .reference_offset => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.reference);
                },
                .reference_indirect_offset => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.reference);
                },
                .aggregate_init => |value| {
                    try requireSpan(function, value.result);
                    var width: usize = 0;
                    for (value.fields) |field| {
                        try requireSpan(function, field);
                        width += field.width;
                    }
                    if (width != value.result.width or !value.result.aggregate) return error.InvalidMachineProgram;
                },
                .protocol_init => |value| {
                    try requireSpan(function, value.result);
                    try requireSpan(function, value.operand);
                    if (!value.result.aggregate or value.result.width == 0 or value.operand.width + 1 > value.result.width) {
                        return error.InvalidMachineProgram;
                    }
                },
                .protocol_test => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.operand);
                },
                .protocol_extract => |value| {
                    try requireSpan(function, value.result);
                    try requireSpan(function, value.operand);
                    if (!value.operand.aggregate or value.operand.width == 0 or value.result.width + 1 > value.operand.width) {
                        return error.InvalidMachineProgram;
                    }
                },
                .class_init => |value| {
                    try requireSlot(function, value.result);
                    for (value.fields) |field| try requireSpan(function, field);
                },
                .class_load => |value| {
                    try requireSpan(function, value.result);
                    try requireSlot(function, value.base);
                },
                .class_store => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.base);
                    try requireSpan(function, value.replacement);
                },
                .class_retain => |value| try requireSlot(function, value.operand),
                .list_retain, .list_drop => |value| try requireSlot(function, value.operand),
                .class_drop => |value| {
                    try requireSlot(function, value.operand);
                    for (value.plans) |plan| {
                        for (plan.functions) |finalizer| if (finalizer >= program.functions.len) return error.InvalidMachineProgram;
                    }
                },
                .list_init => |value| {
                    try requireSlot(function, value.result);
                    if (value.element_width == 0) return error.InvalidMachineProgram;
                    for (value.values) |item| {
                        try requireSpan(function, item);
                        if (item.width != value.element_width) return error.InvalidMachineProgram;
                    }
                },
                .enum_init => |value| {
                    try requireSpan(function, value.result);
                    if (!value.result.aggregate or value.result.width == 0) return error.InvalidMachineProgram;
                    var width: usize = 1;
                    for (value.values) |field| {
                        try requireSpan(function, field);
                        width += field.width;
                    }
                    if (value.raw_value) |raw_value| {
                        width += 1;
                        if (raw_value == .string and raw_value.string >= program.strings.len) return error.InvalidMachineProgram;
                    }
                    if (width > value.result.width) return error.InvalidMachineProgram;
                },
                .enum_test => |value| {
                    try requireSlot(function, value.result);
                    try requireSpan(function, value.operand);
                    if (!value.operand.aggregate or value.operand.width == 0) return error.InvalidMachineProgram;
                },
                .collection_load => |value| {
                    try requireSpan(function, value.result);
                    try requireSpan(function, value.collection);
                    try requireSlot(function, value.index);
                    if ((!value.dynamic and (!value.collection.aggregate or value.collection.width != value.result.width * value.count)) or
                        (value.dynamic and ((value.collection.aggregate != value.view) or value.collection.width != @as(u12, if (value.view) 2 else 1))) or
                        value.header >= program.strings.len or value.tail >= program.strings.len) return error.InvalidMachineProgram;
                },
                .collection_reference => |value| {
                    try requireSlot(function, value.result);
                    try requireSpan(function, value.collection);
                    if (value.reference) |reference| try requireSlot(function, reference);
                    try requireSlot(function, value.index);
                    if (value.element_width == 0 or
                        (!value.dynamic and (value.reference == null or value.collection.width != value.element_width * value.count)) or
                        (value.dynamic and ((value.collection.aggregate != value.view) or value.collection.width != @as(u12, if (value.view) 2 else 1))) or
                        value.header >= program.strings.len or value.tail >= program.strings.len) return error.InvalidMachineProgram;
                },
                .collection_replace => |value| {
                    try requireSpan(function, value.result);
                    try requireSpan(function, value.collection);
                    try requireSlot(function, value.index);
                    try requireSpan(function, value.replacement);
                    if ((!value.dynamic and (!value.result.aggregate or value.result.width != value.collection.width or
                        value.collection.width != value.replacement.width * value.count)) or
                        (value.dynamic and ((value.result.aggregate != value.view) or (value.collection.aggregate != value.view) or value.result.width != @as(u12, if (value.view) 2 else 1) or value.collection.width != @as(u12, if (value.view) 2 else 1))) or
                        value.header >= program.strings.len or value.tail >= program.strings.len) return error.InvalidMachineProgram;
                },
                .collection_count => |value| {
                    try requireSlot(function, value.result);
                    try requireSpan(function, value.collection);
                    if (value.collection.width != @as(u12, if (value.view) 2 else 1)) return error.InvalidMachineProgram;
                },
                .list_edit => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.collection);
                    if (value.index) |slot| try requireSlot(function, slot);
                    if (value.argument) |span| try requireSpan(function, span);
                    if (value.removed) |span| try requireSpan(function, span);
                    if (value.element_width == 0 or value.header >= program.strings.len or value.tail >= program.strings.len) return error.InvalidMachineProgram;
                },
                .collection_slice => |value| {
                    try requireSlot(function, value.result);
                    try requireSpan(function, value.collection);
                    try requireSlot(function, value.start);
                    try requireSlot(function, value.end);
                    if (value.element_width == 0) return error.InvalidMachineProgram;
                },
                .collection_view => |value| {
                    try requireSpan(function, value.result);
                    try requireSpan(function, value.collection);
                    if (value.reference) |reference| try requireSlot(function, reference);
                    try requireSlot(function, value.start);
                    try requireSlot(function, value.end);
                    if (!value.result.aggregate or value.result.width != 2 or value.element_width == 0) return error.InvalidMachineProgram;
                },
                .aggregate_equal => |value| {
                    try requireSlot(function, value.result);
                    try requireSpan(function, value.left);
                    try requireSpan(function, value.right);
                    if (!value.left.aggregate or !value.right.aggregate or value.left.width != value.right.width)
                        return error.InvalidMachineProgram;
                    for (value.leaves) |leaf| {
                        if (leaf.offset >= value.left.width) return error.InvalidMachineProgram;
                        for (leaf.guards) |guard| if (guard.offset >= value.left.width) return error.InvalidMachineProgram;
                    }
                },
                .convert => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.operand);
                    if (value.header >= program.strings.len) return error.InvalidMachineProgram;
                },
                .format_value => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.operand);
                },
                .string_concat => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.left);
                    try requireSlot(function, value.right);
                },
                .string_count => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.operand);
                },
                .string_byte_at => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.operand);
                    try requireSlot(function, value.index);
                },
                .string_from_bytes => |value| {
                    try requireSlot(function, value.result);
                    try requireSpan(function, value.bytes);
                    if (!value.bytes.aggregate or value.bytes.width != 2) return error.InvalidMachineProgram;
                },
                .unary => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.operand);
                },
                .binary => |value| {
                    try requireSlot(function, value.result);
                    try requireSlot(function, value.left);
                    try requireSlot(function, value.right);
                },
                .function_address => |value| {
                    try requireSpan(function, value.result);
                    if (!value.result.aggregate or value.result.width != 2) return error.InvalidMachineProgram;
                    if (value.function >= program.functions.len) return error.InvalidMachineProgram;
                    for (value.captures) |capture| try requireSlot(function, capture);
                    if (value.environment) |environment| {
                        try requireSpan(function, environment);
                        if (!environment.aggregate or environment.width != value.captures.len) return error.InvalidMachineProgram;
                    } else if (value.captures.len != 0) return error.InvalidMachineProgram;
                },
                .call => |call| {
                    if (call.function >= program.functions.len) return error.InvalidMachineProgram;
                    if (call.arguments.len > max_register_arguments) return error.TooManyArguments;
                    if (call.arguments.len != program.functions[call.function].parameter_count) return error.InvalidMachineProgram;
                    if (call.result) |result| try requireSpan(function, result);
                    for (call.arguments, program.functions[call.function].parameters) |argument, parameter| {
                        try requireSpan(function, argument);
                        if (argument.width != parameter.width or argument.aggregate != parameter.aggregate) {
                            return error.InvalidMachineProgram;
                        }
                    }
                    const callee = program.functions[call.function];
                    if (call.result) |result| {
                        if (result.width != callee.return_width or result.aggregate != callee.return_aggregate) {
                            return error.InvalidMachineProgram;
                        }
                    } else if (callee.return_type != .void) return error.InvalidMachineProgram;
                },
                .indirect_call => |call| {
                    try requireSlot(function, call.callee);
                    if (call.arguments.len > max_register_arguments) return error.TooManyArguments;
                    for (call.arguments) |argument| try requireSpan(function, argument);
                    if (call.result) |result| try requireSpan(function, result) else if (call.return_type != .void) return error.InvalidMachineProgram;
                },
                .external_call => |call| {
                    if (call.function >= program.external_functions.len or call.arguments.len > max_external_arguments) {
                        return error.InvalidMachineProgram;
                    }
                    const external = program.external_functions[call.function];
                    if (!supportedExternal(external) or call.arguments.len != external.signature.arguments.len) {
                        return error.InvalidMachineProgram;
                    }
                    for (call.arguments) |argument| try requireSlot(function, argument);
                    if (external.signature.result == null) {
                        if (call.result != null) return error.InvalidMachineProgram;
                    } else {
                        try requireSlot(function, call.result orelse return error.InvalidMachineProgram);
                    }
                },
                .dynamic_call => |call| {
                    if (call.function >= program.functions.len or call.arguments.len > max_register_arguments) return error.InvalidMachineProgram;
                    try requireSlot(function, call.receiver);
                    const fallback = program.functions[call.function];
                    if (call.arguments.len != fallback.parameter_count) return error.InvalidMachineProgram;
                    if (call.result) |result| try requireSpan(function, result);
                    for (call.implementations) |implementation| if (implementation.function >= program.functions.len) return error.InvalidMachineProgram;
                },
                .print => |value| try requireSlot(function, value.value),
                .assert => |value| {
                    try requireSlot(function, value.condition);
                    try requireSlot(function, value.message);
                    if (value.header >= program.strings.len) return error.InvalidMachineProgram;
                },
                .mutex_lock, .mutex_unlock => {},
                .panic => |value| {
                    try requireSlot(function, value.message);
                    if (value.header >= program.strings.len) return error.InvalidMachineProgram;
                },
                .return_value => |value| {
                    try requireSpan(function, value);
                    if (value.width != function.return_width or value.aggregate != function.return_aggregate) return error.InvalidMachineProgram;
                },
                .return_void => {},
                .jump => |target| if (target >= function.instructions.len) return error.InvalidMachineProgram,
                .branch => |branch_value| {
                    try requireSlot(function, branch_value.condition);
                    if (branch_value.then_instruction >= function.instructions.len or
                        branch_value.else_instruction >= function.instructions.len) return error.InvalidMachineProgram;
                },
            }
        }
        if (function.parameters.len != function.parameter_count) return error.InvalidMachineProgram;
        for (function.parameters) |parameter| try requireSpan(function, parameter);
        if (function.return_type == .void) {
            if (function.return_width != 0 or function.return_aggregate or function.recoverable_entry_result or function.hidden_return_slot != null) {
                return error.InvalidMachineProgram;
            }
        } else if (function.return_aggregate != (function.hidden_return_slot != null)) return error.InvalidMachineProgram;
        if (function.recoverable_entry_result and (!function.return_aggregate or function.return_width != 2)) return error.InvalidMachineProgram;
        if (function.hidden_return_slot) |slot| try requireSlot(function, slot);
    }
}

fn supportedExternal(function: ExternalFunction) bool {
    if (function.package_private) return true;
    if (supportedMacOSWebKitExternal(function)) return true;
    if (supportedMathExternal(function)) return true;
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and
        std.mem.eql(u8, function.source_name, "os_unfair_recursive_lock_lock_with_options"))
    {
        const arguments = [_]AbiValue{ .read_address, .uint64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == null;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and
        std.mem.eql(u8, function.source_name, "os_unfair_recursive_lock_unlock"))
    {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == null;
    }
    const write_arguments = [_]AbiValue{ .int32, .read_address, .uint64 };
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "write")) {
        return std.mem.eql(AbiValue, function.signature.arguments, &write_arguments) and
            function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "arc4random")) {
        return function.signature.arguments.len == 0 and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "clock_gettime_nsec_np")) {
        const arguments = [_]AbiValue{.int32};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .uint64;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "read")) {
        const arguments = [_]AbiValue{ .int32, .read_address, .uint64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "isatty")) {
        const arguments = [_]AbiValue{.int32};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "__ioctl")) {
        const arguments = [_]AbiValue{ .int32, .uint64, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "__open")) {
        const arguments = [_]AbiValue{ .read_address, .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and
        (std.mem.eql(u8, function.source_name, "close") or std.mem.eql(u8, function.source_name, "fsync")))
    {
        const arguments = [_]AbiValue{.int32};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "lseek")) {
        const arguments = [_]AbiValue{ .int32, .int64, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "ftruncate")) {
        const arguments = [_]AbiValue{ .int32, .int64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "poll")) {
        const arguments = [_]AbiValue{ .read_address, .uint64, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "getenv")) {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .read_address;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "setenv")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "unsetenv")) {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "_NSGetEnviron")) {
        return function.signature.arguments.len == 0 and function.signature.result == .read_address;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and
        (std.mem.eql(u8, function.source_name, "_NSGetArgc") or std.mem.eql(u8, function.source_name, "_NSGetArgv")))
    {
        return function.signature.arguments.len == 0 and function.signature.result == .read_address;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "getcwd")) {
        const arguments = [_]AbiValue{ .read_address, .uint64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .read_address;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "chdir")) {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "_NSGetExecutablePath")) {
        const arguments = [_]AbiValue{ .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "getpid")) {
        return function.signature.arguments.len == 0 and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and
        (std.mem.eql(u8, function.source_name, "stat") or std.mem.eql(u8, function.source_name, "lstat")))
    {
        const arguments = [_]AbiValue{ .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and
        (std.mem.eql(u8, function.source_name, "opendir") or std.mem.eql(u8, function.source_name, "readdir")))
    {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .read_address;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and
        (std.mem.eql(u8, function.source_name, "closedir") or std.mem.eql(u8, function.source_name, "unlink") or
            std.mem.eql(u8, function.source_name, "rmdir")))
    {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and
        (std.mem.eql(u8, function.source_name, "mkdir") or std.mem.eql(u8, function.source_name, "chmod")))
    {
        const arguments = [_]AbiValue{ .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "rename")) {
        const arguments = [_]AbiValue{ .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "realpath")) {
        const arguments = [_]AbiValue{ .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .read_address;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "copyfile")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "getaddrinfo")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "freeaddrinfo")) {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == null;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "__error")) {
        return function.signature.arguments.len == 0 and function.signature.result == .read_address;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "socket")) {
        const arguments = [_]AbiValue{ .int32, .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and
        (std.mem.eql(u8, function.source_name, "connect") or std.mem.eql(u8, function.source_name, "bind")))
    {
        const arguments = [_]AbiValue{ .int32, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and
        (std.mem.eql(u8, function.source_name, "listen") or std.mem.eql(u8, function.source_name, "shutdown")))
    {
        const arguments = [_]AbiValue{ .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and
        (std.mem.eql(u8, function.source_name, "accept") or std.mem.eql(u8, function.source_name, "getsockname") or
            std.mem.eql(u8, function.source_name, "getpeername")))
    {
        const arguments = [_]AbiValue{ .int32, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and
        (std.mem.eql(u8, function.source_name, "recv") or std.mem.eql(u8, function.source_name, "send")))
    {
        const arguments = [_]AbiValue{ .int32, .read_address, .uint64, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "setsockopt")) {
        const arguments = [_]AbiValue{ .int32, .int32, .int32, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "sendto")) {
        const arguments = [_]AbiValue{ .int32, .read_address, .uint64, .int32, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "recvfrom")) {
        const arguments = [_]AbiValue{ .int32, .read_address, .uint64, .int32, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "pipe")) {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "fork")) {
        return function.signature.arguments.len == 0 and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "dup2")) {
        const arguments = [_]AbiValue{ .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "execve")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "_exit")) {
        const arguments = [_]AbiValue{.int32};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == null;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "waitpid")) {
        const arguments = [_]AbiValue{ .int32, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "kill")) {
        const arguments = [_]AbiValue{ .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "pthread_create")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "pthread_join")) {
        const arguments = [_]AbiValue{ .uint64, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "pthread_self")) {
        return function.signature.arguments.len == 0 and function.signature.result == .uint64;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "dispatch_semaphore_create")) {
        const arguments = [_]AbiValue{.int64};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .uint64;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "dispatch_semaphore_wait")) {
        const arguments = [_]AbiValue{ .uint64, .uint64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "dispatch_semaphore_signal")) {
        const arguments = [_]AbiValue{.uint64};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "dispatch_release")) {
        const arguments = [_]AbiValue{.uint64};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == null;
    }
    if (std.mem.eql(u8, function.provider, "Darwin.lib_system") and std.mem.eql(u8, function.source_name, "sysconf")) {
        const arguments = [_]AbiValue{.int32};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and
        (std.mem.eql(u8, function.source_name, "read") or std.mem.eql(u8, function.source_name, "write")))
    {
        const arguments = [_]AbiValue{ .int32, .read_address, .uint64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "ioctl")) {
        const arguments = [_]AbiValue{ .int32, .uint64, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "openat")) {
        const arguments = [_]AbiValue{ .int32, .read_address, .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and
        (std.mem.eql(u8, function.source_name, "close") or std.mem.eql(u8, function.source_name, "fsync")))
    {
        const arguments = [_]AbiValue{.int32};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "lseek")) {
        const arguments = [_]AbiValue{ .int32, .int64, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "ftruncate")) {
        const arguments = [_]AbiValue{ .int32, .int64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "poll")) {
        const arguments = [_]AbiValue{ .read_address, .uint64, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "getrandom")) {
        const arguments = [_]AbiValue{ .read_address, .uint64, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "clock_gettime")) {
        const arguments = [_]AbiValue{ .int32, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "getcwd")) {
        const arguments = [_]AbiValue{ .read_address, .uint64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "chdir")) {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "readlink")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .uint64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "newfstatat")) {
        const arguments = [_]AbiValue{ .int32, .read_address, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "getdents64")) {
        const arguments = [_]AbiValue{ .int32, .read_address, .uint64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and
        (std.mem.eql(u8, function.source_name, "mkdir") or std.mem.eql(u8, function.source_name, "chmod")))
    {
        const arguments = [_]AbiValue{ .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and
        (std.mem.eql(u8, function.source_name, "unlink") or std.mem.eql(u8, function.source_name, "rmdir")))
    {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "rename")) {
        const arguments = [_]AbiValue{ .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "thread_spawn")) {
        const arguments = [_]AbiValue{ .uint64, .uint64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .uint64;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "thread_join")) {
        const arguments = [_]AbiValue{.uint64};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "getpid")) {
        return function.signature.arguments.len == 0 and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "socket")) {
        const arguments = [_]AbiValue{ .int32, .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "connect")) {
        const arguments = [_]AbiValue{ .int32, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "bind")) {
        const arguments = [_]AbiValue{ .int32, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and
        (std.mem.eql(u8, function.source_name, "listen") or std.mem.eql(u8, function.source_name, "shutdown")))
    {
        const arguments = [_]AbiValue{ .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and
        (std.mem.eql(u8, function.source_name, "accept") or std.mem.eql(u8, function.source_name, "getsockname") or
            std.mem.eql(u8, function.source_name, "getpeername")))
    {
        const arguments = [_]AbiValue{ .int32, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "setsockopt")) {
        const arguments = [_]AbiValue{ .int32, .int32, .int32, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "sendto")) {
        const arguments = [_]AbiValue{ .int32, .read_address, .uint64, .int32, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "recvfrom")) {
        const arguments = [_]AbiValue{ .int32, .read_address, .uint64, .int32, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "pipe")) {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "fork")) return function.signature.arguments.len == 0 and function.signature.result == .int32;
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "dup2")) {
        const arguments = [_]AbiValue{ .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "execve")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "exit")) {
        const arguments = [_]AbiValue{.int32};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "wait4")) {
        const arguments = [_]AbiValue{ .int32, .read_address, .int32, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Linux.kernel") and std.mem.eql(u8, function.source_name, "kill")) {
        const arguments = [_]AbiValue{ .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.bcrypt_primitives") and std.mem.eql(u8, function.source_name, "ProcessPrng")) {
        const arguments = [_]AbiValue{ .read_address, .uint64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and
        (std.mem.eql(u8, function.source_name, "QueryPerformanceCounter") or
            std.mem.eql(u8, function.source_name, "QueryPerformanceFrequency")))
    {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and
        std.mem.eql(u8, function.source_name, "GetSystemTimeAsFileTime"))
    {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == null;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ucrtbase") and
        (std.mem.eql(u8, function.source_name, "_write") or std.mem.eql(u8, function.source_name, "_read")))
    {
        const arguments = [_]AbiValue{ .int32, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ucrtbase") and std.mem.eql(u8, function.source_name, "_isatty")) {
        const arguments = [_]AbiValue{.int32};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ucrtbase") and std.mem.eql(u8, function.source_name, "_wopen")) {
        const arguments = [_]AbiValue{ .read_address, .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ucrtbase") and
        (std.mem.eql(u8, function.source_name, "_close") or std.mem.eql(u8, function.source_name, "_commit")))
    {
        const arguments = [_]AbiValue{.int32};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ucrtbase") and std.mem.eql(u8, function.source_name, "_lseeki64")) {
        const arguments = [_]AbiValue{ .int32, .int64, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ucrtbase") and std.mem.eql(u8, function.source_name, "_chsize_s")) {
        const arguments = [_]AbiValue{ .int32, .int64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ucrtbase") and
        (std.mem.eql(u8, function.source_name, "__p___argc") or std.mem.eql(u8, function.source_name, "__p___wargv")))
    {
        return function.signature.arguments.len == 0 and function.signature.result == .read_address;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "GetStdHandle")) {
        const arguments = [_]AbiValue{.int32};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .uint64;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "GetConsoleScreenBufferInfo")) {
        const arguments = [_]AbiValue{ .uint64, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "GetConsoleMode")) {
        const arguments = [_]AbiValue{ .uint64, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "SetConsoleMode")) {
        const arguments = [_]AbiValue{ .uint64, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "GetConsoleCP")) {
        return function.signature.arguments.len == 0 and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "SetConsoleCP")) {
        const arguments = [_]AbiValue{.int32};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "WaitForSingleObject")) {
        const arguments = [_]AbiValue{ .uint64, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "GetCurrentDirectoryW")) {
        const arguments = [_]AbiValue{ .int32, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "SetCurrentDirectoryW")) {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "GetModuleFileNameW")) {
        const arguments = [_]AbiValue{ .uint64, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "GetCurrentProcessId")) {
        return function.signature.arguments.len == 0 and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "GetEnvironmentVariableW")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "SetEnvironmentVariableW")) {
        const arguments = [_]AbiValue{ .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "GetEnvironmentStringsW")) {
        return function.signature.arguments.len == 0 and function.signature.result == .read_address;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "FreeEnvironmentStringsW")) {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "GetFileAttributesExW")) {
        const arguments = [_]AbiValue{ .read_address, .int32, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "FindFirstFileW")) {
        const arguments = [_]AbiValue{ .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .uint64;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "FindNextFileW")) {
        const arguments = [_]AbiValue{ .uint64, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "FindClose")) {
        const arguments = [_]AbiValue{.uint64};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "CreateDirectoryW")) {
        const arguments = [_]AbiValue{ .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and
        (std.mem.eql(u8, function.source_name, "DeleteFileW") or std.mem.eql(u8, function.source_name, "RemoveDirectoryW")))
    {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "MoveFileExW")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "CopyFileW")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "SetFileAttributesW")) {
        const arguments = [_]AbiValue{ .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "GetFullPathNameW")) {
        const arguments = [_]AbiValue{ .read_address, .int32, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "CreatePipe")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "SetHandleInformation")) {
        const arguments = [_]AbiValue{ .uint64, .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "CreateProcessW")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .read_address, .read_address, .int32, .int32, .read_address, .read_address, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and
        (std.mem.eql(u8, function.source_name, "ReadFile") or std.mem.eql(u8, function.source_name, "WriteFile")))
    {
        const arguments = [_]AbiValue{ .uint64, .read_address, .int32, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "PeekNamedPipe")) {
        const arguments = [_]AbiValue{ .uint64, .read_address, .int32, .read_address, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "CloseHandle")) {
        const arguments = [_]AbiValue{.uint64};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "TerminateProcess")) {
        const arguments = [_]AbiValue{ .uint64, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "GetExitCodeProcess")) {
        const arguments = [_]AbiValue{ .uint64, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "GetLastError")) return function.signature.arguments.len == 0 and function.signature.result == .int32;
    if (std.mem.eql(u8, function.provider, "Windows.kernel32") and std.mem.eql(u8, function.source_name, "CreateThread")) {
        const arguments = [_]AbiValue{ .read_address, .uint64, .read_address, .read_address, .int32, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .uint64;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and std.mem.eql(u8, function.source_name, "GetAddrInfoW")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and std.mem.eql(u8, function.source_name, "FreeAddrInfoW")) {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == null;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and std.mem.eql(u8, function.source_name, "WSAStartup")) {
        const arguments = [_]AbiValue{ .int32, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and std.mem.eql(u8, function.source_name, "WSACleanup")) {
        return function.signature.arguments.len == 0 and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and std.mem.eql(u8, function.source_name, "socket")) {
        const arguments = [_]AbiValue{ .int32, .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and
        (std.mem.eql(u8, function.source_name, "connect") or std.mem.eql(u8, function.source_name, "bind")))
    {
        const arguments = [_]AbiValue{ .int64, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and
        (std.mem.eql(u8, function.source_name, "listen") or std.mem.eql(u8, function.source_name, "shutdown")))
    {
        const arguments = [_]AbiValue{ .int64, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and std.mem.eql(u8, function.source_name, "accept")) {
        const arguments = [_]AbiValue{ .int64, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int64;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and
        (std.mem.eql(u8, function.source_name, "recv") or std.mem.eql(u8, function.source_name, "send")))
    {
        const arguments = [_]AbiValue{ .int64, .read_address, .int32, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and std.mem.eql(u8, function.source_name, "closesocket")) {
        const arguments = [_]AbiValue{.int64};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and
        (std.mem.eql(u8, function.source_name, "getsockname") or std.mem.eql(u8, function.source_name, "getpeername")))
    {
        const arguments = [_]AbiValue{ .int64, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and std.mem.eql(u8, function.source_name, "setsockopt")) {
        const arguments = [_]AbiValue{ .int64, .int32, .int32, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and std.mem.eql(u8, function.source_name, "sendto")) {
        const arguments = [_]AbiValue{ .int64, .read_address, .int32, .int32, .read_address, .int32 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.provider, "Windows.ws2_32") and std.mem.eql(u8, function.source_name, "recvfrom")) {
        const arguments = [_]AbiValue{ .int64, .read_address, .int32, .int32, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    return false;
}

fn supportedMacOSWebKitExternal(function: ExternalFunction) bool {
    if (!std.mem.eql(u8, function.provider, "MacOS.web_kit")) return false;
    if (std.mem.eql(u8, function.source_name, "objc_getClass") or
        std.mem.eql(u8, function.source_name, "sel_registerName"))
    {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .read_address;
    }
    if (std.mem.eql(u8, function.source_name, "objc_getProtocol")) {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .read_address;
    }
    if (std.mem.eql(u8, function.source_name, "objc_registerClassPair")) {
        const arguments = [_]AbiValue{.read_address};
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == null;
    }
    if (std.mem.eql(u8, function.source_name, "objc_allocateClassPair")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .uint64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .read_address;
    }
    if (std.mem.eql(u8, function.source_name, "class_addProtocol")) {
        const arguments = [_]AbiValue{ .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.source_name, "class_addMethod")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .int32;
    }
    if (std.mem.eql(u8, function.source_name, "objc_setAssociatedObject")) {
        const arguments = [_]AbiValue{ .read_address, .read_address, .read_address, .uint64 };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == null;
    }
    if (std.mem.eql(u8, function.source_name, "objc_getAssociatedObject")) {
        const arguments = [_]AbiValue{ .read_address, .read_address };
        return std.mem.eql(AbiValue, function.signature.arguments, &arguments) and function.signature.result == .read_address;
    }
    if (!std.mem.eql(u8, function.source_name, "objc_msgSend") or function.signature.arguments.len < 2 or
        function.signature.arguments[0] != .read_address or function.signature.arguments[1] != .read_address) return false;
    const arguments = function.signature.arguments;
    if (arguments.len == 2) return function.signature.result == .read_address or function.signature.result == .int32 or function.signature.result == null;
    if (arguments.len == 3 and arguments[2] == .read_address) return function.signature.result == .read_address or function.signature.result == null;
    if (arguments.len == 3 and arguments[2] == .int32) return function.signature.result == null;
    if (arguments.len == 4 and arguments[2] == .read_address and arguments[3] == .read_address) return function.signature.result == .read_address or function.signature.result == null;
    if (arguments.len == 4 and arguments[2] == .read_address and arguments[3] == .uint64) return function.signature.result == .read_address;
    if (std.mem.eql(AbiValue, arguments, &.{ .read_address, .read_address, .read_address, .uint64, .int32 })) {
        return function.signature.result == .read_address;
    }
    if (arguments.len == 6 and function.signature.result == .read_address) {
        for (arguments[2..]) |argument| if (argument != .float64) return false;
        return true;
    }
    return false;
}

fn supportedMathExternal(function: ExternalFunction) bool {
    if (!std.mem.eql(u8, function.provider, "Darwin.lib_system") and
        !std.mem.eql(u8, function.provider, "Linux.kernel") and
        !std.mem.eql(u8, function.provider, "Windows.ucrtbase")) return false;
    const math = MathBoundary.identify(function.source_name) orelse return false;
    const expected: AbiValue = if (math.precision == .float32) .float32 else .float64;
    const count: usize = if (math.arity == .unary) 1 else 2;
    if (function.signature.arguments.len != count or function.signature.result != expected) return false;
    for (function.signature.arguments) |argument| if (argument != expected) return false;
    return true;
}

fn requireSlot(function: Function, slot: Slot) Error!void {
    if (slot >= function.slot_count) return error.InvalidMachineProgram;
}

fn requireSpan(function: Function, span: Span) Error!void {
    if (@as(usize, span.start) + span.width > function.slot_count) return error.InvalidMachineProgram;
}

test "allocate deterministic aligned stack homes" {
    try std.testing.expectEqual(@as(u16, 0), slotOffset(0));
    try std.testing.expectEqual(@as(u16, 16), slotOffset(2));
    try std.testing.expectEqual(@as(u16, 0), try frameSize(0));
    try std.testing.expectEqual(@as(u16, 16), try frameSize(1));
    try std.testing.expectEqual(@as(u16, 16), try frameSize(2));
    try std.testing.expectEqual(@as(u16, 32), try frameSize(3));
}

test "validate function identities calls and slots" {
    const arguments = [_]Span{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } };
    const parameters = [_]Span{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } };
    const add_instructions = [_]Instruction{
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
        .{ .return_value = .{ .start = 2, .width = 1 } },
    };
    const main_instructions = [_]Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 40, .type = .int } },
        .{ .constant_int = .{ .result = 1, .bits = 2, .type = .int } },
        .{ .call = .{ .result = .{ .start = 2, .width = 1 }, .function = 0, .arguments = &arguments } },
        .return_void,
    };
    const functions = [_]Function{
        .{
            .name = "add",
            .parameter_count = 2,
            .parameters = &parameters,
            .return_type = .int,
            .return_width = 1,
            .slot_count = 3,
            .frame_size = try frameSize(3),
            .instructions = &add_instructions,
        },
        .{
            .name = "main",
            .parameter_count = 0,
            .return_type = .void,
            .slot_count = 3,
            .frame_size = try frameSize(3),
            .instructions = &main_instructions,
        },
    };
    try validate(.{ .functions = &functions });
}

test "reject unsupported frame and argument counts" {
    try std.testing.expectError(error.TooManyArguments, checkedArgumentCount(9));
    try std.testing.expectError(error.FrameTooLarge, checkedSlot(max_slots + 1));
}
