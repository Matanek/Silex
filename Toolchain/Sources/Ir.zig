const std = @import("std");
const Types = @import("Types.zig");
const Source = @import("Source.zig");
const Strings = @import("Strings.zig");

const Allocator = std.mem.Allocator;

pub const Type = Types.Type;
pub const FunctionId = usize;
pub const ValueId = usize;
pub const LocalId = usize;
pub const BlockId = usize;
pub const Error = Allocator.Error || error{InvalidProgram};

pub const Ownership = enum { root, edge };

pub const UnaryOperator = enum {
    negate,

    fn name(self: UnaryOperator) []const u8 {
        return switch (self) {
            .negate => "neg",
        };
    }
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

    fn name(self: BinaryOperator) []const u8 {
        return switch (self) {
            .add => "add",
            .subtract => "sub",
            .multiply => "mul",
            .divide => "div",
            .remainder => "rem",
            .less => "lt",
            .less_equal => "le",
            .greater => "gt",
            .greater_equal => "ge",
            .equal => "eq",
            .not_equal => "ne",
            .bit_and => "and",
            .bit_xor => "xor",
            .shift_left => "shl",
            .shift_right => "shr",
        };
    }
};

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
    deep_copy: Copy,
    class_cast: Copy,
    class_retain: ClassRetain,
    class_drop: ClassDrop,
    list_retain: ListResource,
    list_drop: ListResource,
    string_retain: ListResource,
    string_drop: ListResource,
    global_load: GlobalLoad,
    global_store: GlobalStore,
    structure_init: StructureInit,
    protocol_init: ProtocolInit,
    protocol_test: ProtocolTest,
    protocol_extract: ProtocolExtract,
    list_init: ListInit,
    enum_init: EnumInit,
    enum_test: EnumTest,
    enum_payload: EnumPayload,
    enum_raw: EnumRaw,
    field_load: FieldLoad,
    field_store: FieldStore,
    collection_load: CollectionLoad,
    collection_reference: CollectionReference,
    collection_replace: CollectionReplace,
    collection_count: CollectionCount,
    list_edit: ListEdit,
    collection_slice: CollectionSlice,
    collection_view: CollectionSlice,
    string_address: StringProjection,
    string_byte_count: StringProjection,
    string_byte_at: StringByteAt,
    string_from_bytes: StringFromBytes,
    function_reference: FunctionReference,
    local_load: LocalLoad,
    local_store: LocalStore,
    local_address: LocalAddress,
    reference_load: ReferenceLoad,
    address_load: AddressLoad,
    address_store: AddressStore,
    reference_store: ReferenceStore,
    reference_field: ReferenceField,
    reference_optional: ReferenceOptional,
    convert: Convert,
    format_value: FormatValue,
    string_concat: StringConcat,
    string_count: StringCount,
    unary: Unary,
    binary: Binary,
    call: Call,
    indirect_call: IndirectCall,
    boundary_call: BoundaryCall,
    dynamic_call: DynamicCall,
    print: Print,
    assert: Assert,
    mutex_lock,
    mutex_unlock,

    pub const ConstantInt = struct {
        result: ValueId,
        bits: u64,
    };

    pub const ConstantBool = struct {
        result: ValueId,
        value: bool,
    };

    pub const ConstantStr = struct {
        result: ValueId,
        value: []const u8,
    };

    pub const ConstantBytes = struct {
        result: ValueId,
        value: []const u8,
    };

    pub const ConstantFloat32 = struct {
        result: ValueId,
        bits: u32,
    };

    pub const ConstantFloat64 = struct {
        result: ValueId,
        bits: u64,
    };

    pub const OptionalNull = struct {
        result: ValueId,
    };

    pub const OptionalSome = struct {
        result: ValueId,
        operand: ValueId,
    };

    pub const OptionalUnwrap = struct {
        result: ValueId,
        operand: ValueId,
    };

    pub const Copy = struct {
        result: ValueId,
        operand: ValueId,
    };

    pub const ClassRetain = struct {
        operand: ValueId,
        ownership: Ownership = .root,
    };
    pub const ListResource = struct {
        operand: ValueId,
        ownership: Ownership = .root,
        deallocate: bool = false,
    };

    pub const ClassDrop = struct {
        operand: ValueId,
        ownership: Ownership = .root,
        static_type: usize,
        plans: []const Plan,

        pub const Plan = struct {
            structure: usize,
            functions: []const Finalizer,
        };

        pub const Finalizer = struct {
            structure: usize,
            function: FunctionId,
        };
    };

    pub const GlobalLoad = struct { result: ValueId, global: usize };
    pub const GlobalStore = struct { global: usize, operand: ValueId };

    pub const StructureInit = struct {
        result: ValueId,
        structure: usize,
        fields: []const ValueId,
    };

    pub const ProtocolInit = struct {
        result: ValueId,
        operand: ValueId,
        structure: usize,
    };

    pub const ProtocolTest = struct {
        result: ValueId,
        operand: ValueId,
        structure: usize,
    };

    pub const ProtocolExtract = struct {
        result: ValueId,
        operand: ValueId,
        structure: usize,
    };

    pub const ListInit = struct {
        result: ValueId,
        values: []const ValueId,
    };

    pub const EnumInit = struct {
        result: ValueId,
        enumeration: usize,
        variant: usize,
        values: []const ValueId,
    };

    pub const EnumTest = struct {
        result: ValueId,
        operand: ValueId,
        enumeration: usize,
        variant: usize,
    };

    pub const EnumPayload = struct {
        result: ValueId,
        operand: ValueId,
        enumeration: usize,
        variant: usize,
        index: usize,
    };

    pub const EnumRaw = struct {
        result: ValueId,
        operand: ValueId,
        enumeration: usize,
    };

    pub const FieldLoad = struct {
        result: ValueId,
        base: ValueId,
        field: usize,
    };

    pub const FieldStore = struct {
        result: ValueId,
        base: ValueId,
        field: usize,
        replacement: ValueId,
    };

    pub const CollectionLoad = struct {
        result: ValueId,
        collection: ValueId,
        index: ValueId,
        checked: bool = true,
        position: Source.Position,
    };

    pub const CollectionReference = struct {
        result: ValueId,
        collection: ValueId,
        reference: ?ValueId,
        index: ValueId,
        position: Source.Position,
    };

    pub const CollectionReplace = struct {
        result: ValueId,
        collection: ValueId,
        index: ValueId,
        replacement: ValueId,
        ownership: Ownership = .root,
        position: Source.Position,
    };

    pub const CollectionCount = struct {
        result: ValueId,
        collection: ValueId,
    };

    pub const ListEditKind = enum { append, append_sequence, prepend, insert, take, take_first, take_last, clear, reverse };
    pub const ListEdit = struct {
        result: ValueId,
        collection: ValueId,
        ownership: Ownership = .root,
        kind: ListEditKind,
        index: ?ValueId = null,
        argument: ?ValueId = null,
        argument_transferred: bool = false,
        removed: ?ValueId = null,
        position: Source.Position,
    };

    pub const CollectionSlice = struct {
        result: ValueId,
        collection: ValueId,
        start: ValueId,
        end: ValueId,
        reference: ?ValueId = null,
    };

    pub const StringProjection = struct {
        result: ValueId,
        operand: ValueId,
    };

    pub const StringByteAt = struct {
        result: ValueId,
        operand: ValueId,
        index: ValueId,
    };

    pub const StringFromBytes = struct {
        result: ValueId,
        bytes: ValueId,
    };

    pub const FunctionReference = struct {
        result: ValueId,
        function: FunctionId,
        captures: []const ValueId = &.{},
    };

    pub const LocalLoad = struct {
        result: ValueId,
        local: LocalId,
    };

    pub const LocalStore = struct {
        local: LocalId,
        operand: ValueId,
    };

    pub const LocalAddress = struct {
        result: ValueId,
        local: LocalId,
    };

    pub const ReferenceLoad = struct {
        result: ValueId,
        reference: ValueId,
    };

    pub const AddressLoad = struct {
        result: ValueId,
        address: ValueId,
        byte_offset: ValueId,
        type: Type,
    };

    pub const AddressStore = struct {
        address: ValueId,
        byte_offset: ValueId,
        operand: ValueId,
        type: Type,
    };

    pub const ReferenceStore = struct {
        reference: ValueId,
        operand: ValueId,
    };

    pub const ReferenceField = struct {
        result: ValueId,
        reference: ValueId,
        structure: usize,
        field: usize,
    };

    pub const ReferenceOptional = struct {
        result: ValueId,
        reference: ValueId,
    };

    pub const Convert = struct {
        result: ValueId,
        operand: ValueId,
        source: Type,
        target: Type,
        position: Source.Position,
        checked: bool,
    };

    pub const FormatValue = struct {
        result: ValueId,
        operand: ValueId,
    };

    pub const StringConcat = struct {
        result: ValueId,
        left: ValueId,
        right: ValueId,
    };

    pub const StringCount = struct {
        result: ValueId,
        operand: ValueId,
    };

    pub const Unary = struct {
        result: ValueId,
        operator: UnaryOperator,
        operand: ValueId,
    };

    pub const Binary = struct {
        result: ValueId,
        operator: BinaryOperator,
        left: ValueId,
        right: ValueId,
        checked: bool = true,
    };

    pub const Call = struct {
        result: ?ValueId,
        function: FunctionId,
        arguments: []const ValueId,
    };

    pub const IndirectCall = struct {
        result: ?ValueId,
        callee: ValueId,
        arguments: []const ValueId,
    };

    pub const BoundaryCall = struct {
        result: ?ValueId,
        function: usize,
        arguments: []const ValueId,
    };

    pub const DynamicCall = struct {
        result: ?ValueId,
        function: FunctionId,
        receiver: ValueId,
        arguments: []const ValueId,
        implementations: []const Implementation,

        pub const Implementation = struct {
            structure: usize,
            function: FunctionId,
        };
    };

    pub const Assert = struct {
        condition: ValueId,
        message: ValueId,
        position: Source.Position,
    };

    pub const Print = struct {
        value: ValueId,
        newline: bool,
    };

    pub const Panic = struct {
        message: ValueId,
        position: Source.Position,
    };
};

pub const Terminator = union(enum) {
    jump: BlockId,
    branch: Branch,
    return_value: ValueId,
    return_void,
    panic: Instruction.Panic,

    pub const Branch = struct {
        condition: ValueId,
        then_block: BlockId,
        else_block: BlockId,
    };
};

pub const Block = struct {
    instructions: []const Instruction,
    terminator: Terminator,
};

pub const Function = struct {
    name: []const u8,
    capture_types: []const Type = &.{},
    parameter_types: []const Type,
    return_type: Type,
    value_types: []const Type,
    local_types: []const Type = &.{},
    blocks: []const Block,
};

pub const StructureField = struct {
    name: []const u8,
    type: Type,
    mutable: bool,
};

pub const Structure = struct {
    name: []const u8,
    fields: []const StructureField,
    is_tuple: bool = false,
    tuple_named: bool = false,
    is_class: bool = false,
    is_static: bool = false,
    is_protocol: bool = false,
    conformances: []const usize = &.{},
    base: ?usize = null,
    collection: ?Types.Collection = null,
};

pub const EnumVariant = struct {
    name: []const u8,
    associated_types: []const Type,
    raw_value: ?EnumRawValue = null,
};

pub const EnumRawValue = union(enum) {
    integer: i64,
    string: []const u8,
};

pub const Enum = struct {
    name: []const u8,
    type_index: usize,
    raw_type: ?Type = null,
    variants: []const EnumVariant,
};

pub const Program = struct {
    globals: []const Global = &.{},
    structures: []const Structure = &.{},
    enums: []const Enum = &.{},
    function_types: []const FunctionType = &.{},
    functions: []const Function,
    files: []const []const u8 = &.{"<source>"},
};

pub const FunctionType = struct {
    parameter_types: []const Type,
    return_type: Type,
};

pub const Global = struct {
    name: []const u8,
    type: Type,
    mutable: bool,
    runtime_initialized: bool = false,
    bits: u64 = 0,
    extra_bits: []const u64 = &.{},
};

pub fn writeText(allocator: Allocator, program: Program) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    for (program.structures) |structure| {
        if (structure.is_tuple) continue;
        if (output.items.len != 0) try output.append(allocator, '\n');
        try output.appendSlice(allocator, if (structure.is_protocol) "protocol @" else "struct @");
        try output.appendSlice(allocator, structure.name);
        try output.appendSlice(allocator, " {\n");
        for (structure.fields) |field| {
            try output.appendSlice(allocator, if (field.mutable) "    var ." else "    let .");
            try output.appendSlice(allocator, field.name);
            try output.append(allocator, ':');
            try appendType(&output, allocator, program, field.type);
            try output.append(allocator, '\n');
        }
        try output.appendSlice(allocator, "}\n");
    }
    for (program.enums) |enumeration| {
        if (output.items.len != 0) try output.append(allocator, '\n');
        try output.appendSlice(allocator, "enum @");
        try output.appendSlice(allocator, enumeration.name);
        if (enumeration.raw_type) |raw_type| {
            try output.append(allocator, ':');
            try appendType(&output, allocator, program, raw_type);
        }
        try output.appendSlice(allocator, " {\n");
        for (enumeration.variants) |variant| {
            try output.appendSlice(allocator, "    .");
            try output.appendSlice(allocator, variant.name);
            if (variant.raw_value) |raw_value| {
                try output.appendSlice(allocator, " = ");
                switch (raw_value) {
                    .integer => |value| try output.appendSlice(allocator, try std.fmt.allocPrint(allocator, "{d}", .{value})),
                    .string => |value| try Strings.appendQuoted(&output, allocator, value),
                }
            } else {
                try output.append(allocator, '(');
                for (variant.associated_types, 0..) |type_value, index| {
                    if (index != 0) try output.appendSlice(allocator, ", ");
                    try appendType(&output, allocator, program, type_value);
                }
                try output.append(allocator, ')');
            }
            try output.append(allocator, '\n');
        }
        try output.appendSlice(allocator, "}\n");
    }
    for (program.functions, 0..) |function, function_index| {
        _ = function_index;
        if (output.items.len != 0) try output.append(allocator, '\n');
        try output.appendSlice(allocator, "func @");
        try output.appendSlice(allocator, function.name);
        try output.append(allocator, '(');
        for (function.parameter_types, 0..) |parameter_type, index| {
            if (index != 0) try output.appendSlice(allocator, ", ");
            try appendValue(&output, allocator, index);
            try output.append(allocator, ':');
            try appendType(&output, allocator, program, parameter_type);
        }
        try output.appendSlice(allocator, ") -> ");
        try appendType(&output, allocator, program, function.return_type);
        try output.appendSlice(allocator, " {\n");
        for (function.blocks, 0..) |block, block_id| {
            try appendBlockName(&output, allocator, block_id);
            try output.appendSlice(allocator, ":\n");
            for (block.instructions) |instruction| {
                try output.appendSlice(allocator, "    ");
                try writeInstruction(&output, allocator, program, function, instruction);
                try output.append(allocator, '\n');
            }
            try output.appendSlice(allocator, "    ");
            try writeTerminator(&output, allocator, function, block.terminator, function.blocks.len);
            try output.append(allocator, '\n');
        }
        try output.appendSlice(allocator, "}\n");
    }
    return output.toOwnedSlice(allocator);
}

fn writeInstruction(
    output: *std.ArrayList(u8),
    allocator: Allocator,
    program: Program,
    function: Function,
    instruction: Instruction,
) Error!void {
    switch (instruction) {
        .constant_int => |constant| {
            try appendResult(output, allocator, program, function, constant.result);
            try output.appendSlice(allocator, "const ");
            try appendInteger(output, allocator, constant.bits, function.value_types[constant.result]);
        },
        .constant_bool => |constant| {
            try appendResult(output, allocator, program, function, constant.result);
            try output.appendSlice(allocator, if (constant.value) "const true" else "const false");
        },
        .constant_str => |constant| {
            try appendResult(output, allocator, program, function, constant.result);
            try output.appendSlice(allocator, "const ");
            try Strings.appendQuoted(output, allocator, constant.value);
        },
        .constant_bytes => |constant| {
            const type_value = if (constant.result < function.value_types.len)
                function.value_types[constant.result]
            else
                return error.InvalidProgram;
            const structure = type_value.structureIndex() orelse return error.InvalidProgram;
            if (structure >= program.structures.len) return error.InvalidProgram;
            const collection = program.structures[structure].collection orelse return error.InvalidProgram;
            if (collection.element != .uint8 or collection.length != null or collection.view) return error.InvalidProgram;
            try appendResult(output, allocator, program, function, constant.result);
            try output.appendSlice(allocator, "const.bytes 0x");
            const digits = "0123456789abcdef";
            for (constant.value) |byte| {
                try output.append(allocator, digits[byte >> 4]);
                try output.append(allocator, digits[byte & 0x0f]);
            }
        },
        .constant_float32 => |constant| {
            try appendResult(output, allocator, program, function, constant.result);
            try output.appendSlice(allocator, "const ");
            try appendFloat(output, allocator, @as(f64, @floatCast(@as(f32, @bitCast(constant.bits)))));
        },
        .constant_float64 => |constant| {
            try appendResult(output, allocator, program, function, constant.result);
            try output.appendSlice(allocator, "const ");
            try appendFloat(output, allocator, @as(f64, @bitCast(constant.bits)));
        },
        .optional_null => |optional| {
            if (optional.result >= function.value_types.len or function.value_types[optional.result].optionalChild() == null) {
                return error.InvalidProgram;
            }
            try appendResult(output, allocator, program, function, optional.result);
            try output.appendSlice(allocator, "optional.null");
        },
        .optional_some => |optional| {
            if (optional.result >= function.value_types.len or optional.operand >= function.value_types.len or
                function.value_types[optional.result].optionalChild() != function.value_types[optional.operand])
            {
                return error.InvalidProgram;
            }
            try appendResult(output, allocator, program, function, optional.result);
            try output.appendSlice(allocator, "optional.some ");
            try appendValueChecked(output, allocator, function, optional.operand);
        },
        .optional_unwrap => |optional| {
            if (optional.result >= function.value_types.len or optional.operand >= function.value_types.len or
                function.value_types[optional.operand].optionalChild() != function.value_types[optional.result])
            {
                return error.InvalidProgram;
            }
            try appendResult(output, allocator, program, function, optional.result);
            try output.appendSlice(allocator, "optional.unwrap ");
            try appendValueChecked(output, allocator, function, optional.operand);
        },
        .copy, .class_cast => |copy| {
            try appendResult(output, allocator, program, function, copy.result);
            try output.appendSlice(allocator, "copy ");
            try appendValueChecked(output, allocator, function, copy.operand);
        },
        .deep_copy => |copy| {
            try appendResult(output, allocator, program, function, copy.result);
            try output.appendSlice(allocator, "deep_copy ");
            try appendValueChecked(output, allocator, function, copy.operand);
        },
        .class_retain => |retain| {
            try output.appendSlice(allocator, "class.retain ");
            try appendValueChecked(output, allocator, function, retain.operand);
            if (retain.ownership == .edge) try output.appendSlice(allocator, " edge");
        },
        .class_drop => |drop| {
            try output.appendSlice(allocator, "class.drop ");
            try appendValueChecked(output, allocator, function, drop.operand);
            if (drop.ownership == .edge) try output.appendSlice(allocator, " edge");
            for (drop.plans) |plan| {
                if (plan.structure >= program.structures.len) return error.InvalidProgram;
                try output.appendSlice(allocator, ", ");
                try output.appendSlice(allocator, program.structures[plan.structure].name);
                try output.appendSlice(allocator, " => [");
                for (plan.functions, 0..) |finalizer, index| {
                    if (index != 0) try output.appendSlice(allocator, ", ");
                    try output.append(allocator, '@');
                    if (finalizer.function >= program.functions.len) return error.InvalidProgram;
                    try output.appendSlice(allocator, program.functions[finalizer.function].name);
                }
                try output.append(allocator, ']');
            }
        },
        .list_retain => |retain| {
            try output.appendSlice(allocator, "list.retain ");
            try appendValueChecked(output, allocator, function, retain.operand);
            if (retain.ownership == .edge) try output.appendSlice(allocator, " edge");
        },
        .list_drop => |drop| {
            try output.appendSlice(allocator, "list.drop ");
            try appendValueChecked(output, allocator, function, drop.operand);
            if (drop.ownership == .edge) try output.appendSlice(allocator, " edge");
        },
        .string_retain => |retain| {
            try output.appendSlice(allocator, "str.retain ");
            try appendValueChecked(output, allocator, function, retain.operand);
        },
        .string_drop => |drop| {
            try output.appendSlice(allocator, "str.drop ");
            try appendValueChecked(output, allocator, function, drop.operand);
        },
        .global_load => |load| {
            try appendResult(output, allocator, program, function, load.result);
            try output.appendSlice(allocator, "global.load @");
            try output.appendSlice(allocator, program.globals[load.global].name);
        },
        .global_store => |store| {
            try output.appendSlice(allocator, "global.store @");
            try output.appendSlice(allocator, program.globals[store.global].name);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, store.operand);
        },
        .structure_init => |initialization| {
            if (initialization.structure >= program.structures.len or
                initialization.fields.len != program.structures[initialization.structure].fields.len or
                initialization.result >= function.value_types.len or
                function.value_types[initialization.result] != Type.structure(initialization.structure))
            {
                return error.InvalidProgram;
            }
            try appendResult(output, allocator, program, function, initialization.result);
            try output.appendSlice(allocator, "struct.init @");
            try output.appendSlice(allocator, program.structures[initialization.structure].name);
            try output.append(allocator, '(');
            for (initialization.fields, 0..) |field, index| {
                if (field >= function.value_types.len or
                    function.value_types[field] != program.structures[initialization.structure].fields[index].type)
                {
                    return error.InvalidProgram;
                }
                if (index != 0) try output.appendSlice(allocator, ", ");
                try output.appendSlice(allocator, ".");
                try output.appendSlice(allocator, program.structures[initialization.structure].fields[index].name);
                try output.appendSlice(allocator, "=");
                try appendValueChecked(output, allocator, function, field);
            }
            try output.append(allocator, ')');
        },
        .protocol_init => |initialization| {
            if (initialization.result >= function.value_types.len or initialization.operand >= function.value_types.len or
                initialization.structure >= program.structures.len)
            {
                return error.InvalidProgram;
            }
            const protocol_index = function.value_types[initialization.result].structureIndex() orelse return error.InvalidProgram;
            if (protocol_index >= program.structures.len or !program.structures[protocol_index].is_protocol or
                function.value_types[initialization.operand] != Type.structure(initialization.structure)) return error.InvalidProgram;
            try appendResult(output, allocator, program, function, initialization.result);
            try output.appendSlice(allocator, "protocol.init @");
            try output.appendSlice(allocator, program.structures[protocol_index].name);
            try output.appendSlice(allocator, " from ");
            try appendValueChecked(output, allocator, function, initialization.operand);
        },
        .protocol_test => |test_value| {
            if (test_value.result >= function.value_types.len or function.value_types[test_value.result] != .bool or
                test_value.structure >= program.structures.len) return error.InvalidProgram;
            try appendResult(output, allocator, program, function, test_value.result);
            try output.appendSlice(allocator, "protocol.test ");
            try appendValueChecked(output, allocator, function, test_value.operand);
            try output.appendSlice(allocator, ", @");
            try output.appendSlice(allocator, program.structures[test_value.structure].name);
        },
        .protocol_extract => |extraction| {
            if (extraction.result >= function.value_types.len or extraction.operand >= function.value_types.len or
                extraction.structure >= program.structures.len or
                function.value_types[extraction.result] != Type.structure(extraction.structure)) return error.InvalidProgram;
            try appendResult(output, allocator, program, function, extraction.result);
            try output.appendSlice(allocator, "protocol.extract ");
            try appendValueChecked(output, allocator, function, extraction.operand);
            try output.appendSlice(allocator, " as @");
            try output.appendSlice(allocator, program.structures[extraction.structure].name);
        },
        .list_init => |initialization| {
            try appendResult(output, allocator, program, function, initialization.result);
            try output.appendSlice(allocator, "list.init [");
            for (initialization.values, 0..) |value, index| {
                if (index != 0) try output.appendSlice(allocator, ", ");
                try appendValueChecked(output, allocator, function, value);
            }
            try output.append(allocator, ']');
        },
        .enum_init => |initialization| {
            if (initialization.enumeration >= program.enums.len) return error.InvalidProgram;
            const enumeration = program.enums[initialization.enumeration];
            if (initialization.variant >= enumeration.variants.len) return error.InvalidProgram;
            const variant = enumeration.variants[initialization.variant];
            if (initialization.values.len != variant.associated_types.len) return error.InvalidProgram;
            try appendResult(output, allocator, program, function, initialization.result);
            try output.appendSlice(allocator, "enum.init @");
            try output.appendSlice(allocator, enumeration.name);
            try output.appendSlice(allocator, ".");
            try output.appendSlice(allocator, variant.name);
            try output.append(allocator, '(');
            for (initialization.values, 0..) |value, index| {
                if (index != 0) try output.appendSlice(allocator, ", ");
                try appendValueChecked(output, allocator, function, value);
            }
            try output.append(allocator, ')');
        },
        .enum_test => |test_value| {
            if (test_value.enumeration >= program.enums.len) return error.InvalidProgram;
            const enumeration = program.enums[test_value.enumeration];
            if (test_value.variant >= enumeration.variants.len or test_value.result >= function.value_types.len or
                function.value_types[test_value.result] != .bool or test_value.operand >= function.value_types.len or
                function.value_types[test_value.operand] != Type.structure(enumeration.type_index)) return error.InvalidProgram;
            try appendResult(output, allocator, program, function, test_value.result);
            try output.appendSlice(allocator, "enum.test ");
            try appendValueChecked(output, allocator, function, test_value.operand);
            try output.appendSlice(allocator, ", @");
            try output.appendSlice(allocator, enumeration.name);
            try output.appendSlice(allocator, ".");
            try output.appendSlice(allocator, enumeration.variants[test_value.variant].name);
        },
        .enum_payload => |payload| {
            if (payload.enumeration >= program.enums.len) return error.InvalidProgram;
            const enumeration = program.enums[payload.enumeration];
            if (payload.variant >= enumeration.variants.len) return error.InvalidProgram;
            const variant = enumeration.variants[payload.variant];
            if (payload.index >= variant.associated_types.len or payload.result >= function.value_types.len or
                function.value_types[payload.result] != variant.associated_types[payload.index] or
                payload.operand >= function.value_types.len or
                function.value_types[payload.operand] != Type.structure(enumeration.type_index)) return error.InvalidProgram;
            try appendResult(output, allocator, program, function, payload.result);
            try output.appendSlice(allocator, "enum.payload ");
            try appendValueChecked(output, allocator, function, payload.operand);
            try output.appendSlice(allocator, ", @");
            try output.appendSlice(allocator, enumeration.name);
            try output.appendSlice(allocator, ".");
            try output.appendSlice(allocator, variant.name);
            try output.appendSlice(allocator, "[");
            try output.appendSlice(allocator, try std.fmt.allocPrint(allocator, "{d}", .{payload.index}));
            try output.append(allocator, ']');
        },
        .enum_raw => |raw| {
            if (raw.enumeration >= program.enums.len) return error.InvalidProgram;
            const enumeration = program.enums[raw.enumeration];
            const raw_type = enumeration.raw_type orelse return error.InvalidProgram;
            if (raw.result >= function.value_types.len or function.value_types[raw.result] != raw_type or
                raw.operand >= function.value_types.len or
                function.value_types[raw.operand] != Type.structure(enumeration.type_index)) return error.InvalidProgram;
            try appendResult(output, allocator, program, function, raw.result);
            try output.appendSlice(allocator, "enum.raw ");
            try appendValueChecked(output, allocator, function, raw.operand);
        },
        .field_load => |load| {
            if (load.base >= function.value_types.len) return error.InvalidProgram;
            const structure_index = function.value_types[load.base].structureIndex() orelse return error.InvalidProgram;
            if (structure_index >= program.structures.len or load.field >= program.structures[structure_index].fields.len) {
                return error.InvalidProgram;
            }
            if (load.result >= function.value_types.len or
                function.value_types[load.result] != program.structures[structure_index].fields[load.field].type)
            {
                return error.InvalidProgram;
            }
            try appendResult(output, allocator, program, function, load.result);
            try output.appendSlice(allocator, "field ");
            try appendValueChecked(output, allocator, function, load.base);
            try output.appendSlice(allocator, ", .");
            try output.appendSlice(allocator, program.structures[structure_index].fields[load.field].name);
        },
        .field_store => |store| {
            if (store.base >= function.value_types.len) return error.InvalidProgram;
            const structure_index = function.value_types[store.base].structureIndex() orelse return error.InvalidProgram;
            if (structure_index >= program.structures.len or !program.structures[structure_index].is_class or
                store.field >= program.structures[structure_index].fields.len or store.result >= function.value_types.len or
                function.value_types[store.result] != function.value_types[store.base] or store.replacement >= function.value_types.len or
                function.value_types[store.replacement] != program.structures[structure_index].fields[store.field].type)
            {
                return error.InvalidProgram;
            }
            try appendResult(output, allocator, program, function, store.result);
            try output.appendSlice(allocator, "class.store ");
            try appendValueChecked(output, allocator, function, store.base);
            try output.appendSlice(allocator, ", .");
            try output.appendSlice(allocator, program.structures[structure_index].fields[store.field].name);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, store.replacement);
        },
        .collection_load => |load| {
            try appendResult(output, allocator, program, function, load.result);
            try output.appendSlice(allocator, "collection.load ");
            try appendValueChecked(output, allocator, function, load.collection);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, load.index);
            if (!load.checked) try output.appendSlice(allocator, " bounded");
        },
        .collection_reference => |reference| {
            try appendResult(output, allocator, program, function, reference.result);
            try output.appendSlice(allocator, "collection.reference ");
            try appendValueChecked(output, allocator, function, reference.collection);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, reference.index);
            if (reference.reference) |source| {
                try output.appendSlice(allocator, ", through ");
                try appendValueChecked(output, allocator, function, source);
                if (function.value_types[source] != .address) return error.InvalidProgram;
            }
            if (function.value_types[reference.result] != .address or function.value_types[reference.index] != .int) return error.InvalidProgram;
        },
        .collection_replace => |replacement| {
            try appendResult(output, allocator, program, function, replacement.result);
            try output.appendSlice(allocator, "collection.replace ");
            try appendValueChecked(output, allocator, function, replacement.collection);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, replacement.index);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, replacement.replacement);
            if (replacement.ownership == .edge) try output.appendSlice(allocator, ", edge");
        },
        .collection_count => |count| {
            try appendResult(output, allocator, program, function, count.result);
            try output.appendSlice(allocator, "collection.count ");
            try appendValueChecked(output, allocator, function, count.collection);
        },
        .list_edit => |edit| {
            try appendResult(output, allocator, program, function, edit.result);
            try output.appendSlice(allocator, "list.");
            try output.appendSlice(allocator, @tagName(edit.kind));
            try output.append(allocator, ' ');
            try appendValueChecked(output, allocator, function, edit.collection);
            if (edit.index) |index| {
                try output.appendSlice(allocator, ", ");
                try appendValueChecked(output, allocator, function, index);
            }
            if (edit.argument) |argument| {
                try output.appendSlice(allocator, ", ");
                try appendValueChecked(output, allocator, function, argument);
            }
        },
        .collection_slice => |slice| {
            try appendResult(output, allocator, program, function, slice.result);
            try output.appendSlice(allocator, "collection.slice ");
            try appendValueChecked(output, allocator, function, slice.collection);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, slice.start);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, slice.end);
        },
        .collection_view => |view| {
            try appendResult(output, allocator, program, function, view.result);
            try output.appendSlice(allocator, "collection.view ");
            try appendValueChecked(output, allocator, function, view.collection);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, view.start);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, view.end);
            if (view.reference) |reference| {
                try output.appendSlice(allocator, ", through ");
                try appendValueChecked(output, allocator, function, reference);
            }
        },
        .string_address => |address| {
            try appendResult(output, allocator, program, function, address.result);
            try output.appendSlice(allocator, "boundary.address ");
            try appendValueChecked(output, allocator, function, address.operand);
            if (function.value_types[address.result] != .address) return error.InvalidProgram;
        },
        .string_byte_count => |count| {
            try appendResult(output, allocator, program, function, count.result);
            try output.appendSlice(allocator, "str.byte_count ");
            try appendValueChecked(output, allocator, function, count.operand);
            if (function.value_types[count.result] != .uint) return error.InvalidProgram;
        },
        .string_byte_at => |access| {
            try appendResult(output, allocator, program, function, access.result);
            try output.appendSlice(allocator, "str.byte_at ");
            try appendValueChecked(output, allocator, function, access.operand);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, access.index);
            if (function.value_types[access.result] != .uint8 or function.value_types[access.operand] != .str or
                function.value_types[access.index] != .uint) return error.InvalidProgram;
        },
        .string_from_bytes => |conversion| {
            try appendResult(output, allocator, program, function, conversion.result);
            try output.appendSlice(allocator, "str.from_bytes ");
            try appendValueChecked(output, allocator, function, conversion.bytes);
            if (function.value_types[conversion.result] != .str) return error.InvalidProgram;
            const type_value = function.value_types[conversion.bytes];
            const structure = type_value.structureIndex() orelse return error.InvalidProgram;
            if (structure >= program.structures.len) return error.InvalidProgram;
            const collection = program.structures[structure].collection orelse return error.InvalidProgram;
            if (!collection.view or collection.element != .uint8) return error.InvalidProgram;
        },
        .function_reference => |reference| {
            if (reference.function >= program.functions.len or reference.result >= function.value_types.len or
                function.value_types[reference.result].functionIndex() == null)
            {
                return error.InvalidProgram;
            }
            if (reference.captures.len != program.functions[reference.function].capture_types.len) return error.InvalidProgram;
            try appendResult(output, allocator, program, function, reference.result);
            try output.appendSlice(allocator, "function @");
            try output.appendSlice(allocator, program.functions[reference.function].name);
            if (reference.captures.len != 0) {
                try output.appendSlice(allocator, " captures (");
                for (reference.captures, 0..) |capture, index| {
                    if (index != 0) try output.appendSlice(allocator, ", ");
                    try appendValueChecked(output, allocator, function, capture);
                    if (function.value_types[capture] != .address) return error.InvalidProgram;
                }
                try output.append(allocator, ')');
            }
        },
        .local_load => |load| {
            try appendResult(output, allocator, program, function, load.result);
            try output.appendSlice(allocator, "load ");
            try appendLocalChecked(output, allocator, function, load.local);
            if (function.local_types[load.local] != function.value_types[load.result]) return error.InvalidProgram;
        },
        .local_store => |store| {
            try output.appendSlice(allocator, "store ");
            try appendLocalChecked(output, allocator, function, store.local);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, store.operand);
            if (function.local_types[store.local] != function.value_types[store.operand]) return error.InvalidProgram;
        },
        .local_address => |address| {
            try appendResult(output, allocator, program, function, address.result);
            try output.appendSlice(allocator, "address ");
            try appendLocalChecked(output, allocator, function, address.local);
            if (function.value_types[address.result] != .address) return error.InvalidProgram;
        },
        .reference_load => |load| {
            try appendResult(output, allocator, program, function, load.result);
            try output.appendSlice(allocator, "reference.load ");
            try appendValueChecked(output, allocator, function, load.reference);
            if (function.value_types[load.reference] != .address) return error.InvalidProgram;
        },
        .address_load => |load| {
            try appendResult(output, allocator, program, function, load.result);
            try output.appendSlice(allocator, "boundary.load ");
            try appendValueChecked(output, allocator, function, load.address);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, load.byte_offset);
            if ((function.value_types[load.address] != .address and function.value_types[load.address] != .uint) or function.value_types[load.byte_offset] != .uint or
                function.value_types[load.result] != load.type or (!load.type.isInteger() and !load.type.isFloat() and load.type != .address)) return error.InvalidProgram;
        },
        .address_store => |store| {
            try output.appendSlice(allocator, "boundary.store ");
            try appendValueChecked(output, allocator, function, store.address);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, store.byte_offset);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, store.operand);
            if ((function.value_types[store.address] != .address and function.value_types[store.address] != .uint) or
                function.value_types[store.byte_offset] != .uint or function.value_types[store.operand] != store.type or
                (!store.type.isInteger() and !store.type.isFloat())) return error.InvalidProgram;
        },
        .reference_store => |store| {
            try output.appendSlice(allocator, "reference.store ");
            try appendValueChecked(output, allocator, function, store.reference);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, store.operand);
            if (function.value_types[store.reference] != .address) return error.InvalidProgram;
        },
        .reference_field => |field| {
            if (field.structure >= program.structures.len or field.field >= program.structures[field.structure].fields.len) return error.InvalidProgram;
            try appendResult(output, allocator, program, function, field.result);
            try output.appendSlice(allocator, "reference.field ");
            try appendValueChecked(output, allocator, function, field.reference);
            try output.appendSlice(allocator, ", ");
            try output.appendSlice(allocator, program.structures[field.structure].fields[field.field].name);
            if (function.value_types[field.result] != .address or function.value_types[field.reference] != .address) return error.InvalidProgram;
        },
        .reference_optional => |optional| {
            try appendResult(output, allocator, program, function, optional.result);
            try output.appendSlice(allocator, "reference.optional ");
            try appendValueChecked(output, allocator, function, optional.reference);
            if (function.value_types[optional.result] != .address or function.value_types[optional.reference] != .address) return error.InvalidProgram;
        },
        .convert => |conversion| {
            try appendResult(output, allocator, program, function, conversion.result);
            try output.appendSlice(allocator, "convert ");
            try appendValueChecked(output, allocator, function, conversion.operand);
            try output.appendSlice(allocator, " to ");
            try output.appendSlice(allocator, conversion.target.name());
        },
        .format_value => |format| {
            try appendResult(output, allocator, program, function, format.result);
            try output.appendSlice(allocator, "format ");
            try appendValueChecked(output, allocator, function, format.operand);
        },
        .string_concat => |concat| {
            try appendResult(output, allocator, program, function, concat.result);
            try output.appendSlice(allocator, "str.concat ");
            try appendValueChecked(output, allocator, function, concat.left);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, concat.right);
        },
        .string_count => |count| {
            try appendResult(output, allocator, program, function, count.result);
            try output.appendSlice(allocator, "str.count ");
            try appendValueChecked(output, allocator, function, count.operand);
        },
        .unary => |unary| {
            try appendResult(output, allocator, program, function, unary.result);
            try output.appendSlice(allocator, unary.operator.name());
            try output.append(allocator, ' ');
            try appendValueChecked(output, allocator, function, unary.operand);
        },
        .binary => |binary| {
            try appendResult(output, allocator, program, function, binary.result);
            try output.appendSlice(allocator, binary.operator.name());
            try output.append(allocator, ' ');
            try appendValueChecked(output, allocator, function, binary.left);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, binary.right);
        },
        .call => |call| {
            if (call.function >= program.functions.len) return error.InvalidProgram;
            if (call.result) |result| try appendResult(output, allocator, program, function, result);
            try output.appendSlice(allocator, "call @");
            try output.appendSlice(allocator, program.functions[call.function].name);
            try output.append(allocator, '(');
            for (call.arguments, 0..) |argument, index| {
                if (index != 0) try output.appendSlice(allocator, ", ");
                try appendValueChecked(output, allocator, function, argument);
            }
            try output.append(allocator, ')');
        },
        .indirect_call => |call| {
            if (call.result) |result| try appendResult(output, allocator, program, function, result);
            try output.appendSlice(allocator, "call.indirect ");
            try appendValueChecked(output, allocator, function, call.callee);
            try output.append(allocator, '(');
            for (call.arguments, 0..) |argument, index| {
                if (index != 0) try output.appendSlice(allocator, ", ");
                try appendValueChecked(output, allocator, function, argument);
            }
            try output.append(allocator, ')');
        },
        .boundary_call => |call| {
            if (call.result) |result| try appendResult(output, allocator, program, function, result);
            try output.appendSlice(allocator, "boundary.call #");
            try output.appendSlice(allocator, try std.fmt.allocPrint(allocator, "{d}", .{call.function}));
            try output.append(allocator, '(');
            for (call.arguments, 0..) |argument, index| {
                if (index != 0) try output.appendSlice(allocator, ", ");
                try appendValueChecked(output, allocator, function, argument);
            }
            try output.append(allocator, ')');
        },
        .dynamic_call => |call| {
            if (call.result) |result| try appendResult(output, allocator, program, function, result);
            try output.appendSlice(allocator, try std.fmt.allocPrint(allocator, "dispatch @{s} via ", .{program.functions[call.function].name}));
            try appendValueChecked(output, allocator, function, call.receiver);
            try output.appendSlice(allocator, try std.fmt.allocPrint(allocator, " [{d} implementations]", .{call.implementations.len}));
        },
        .print => |print_value| {
            try output.appendSlice(allocator, "print ");
            try appendValueChecked(output, allocator, function, print_value.value);
            if (!print_value.newline) try output.appendSlice(allocator, " without-newline");
        },
        .assert => |assertion| {
            try output.appendSlice(allocator, "assert ");
            try appendValueChecked(output, allocator, function, assertion.condition);
            try output.appendSlice(allocator, ", ");
            try appendValueChecked(output, allocator, function, assertion.message);
        },
        .mutex_lock => try output.appendSlice(allocator, "mutex.lock"),
        .mutex_unlock => try output.appendSlice(allocator, "mutex.unlock"),
    }
}

fn appendType(output: *std.ArrayList(u8), allocator: Allocator, program: Program, type_value: Type) Error!void {
    if (type_value.optionalChild()) |child| {
        try appendType(output, allocator, program, child);
        return output.append(allocator, '?');
    }
    if (type_value.structureIndex()) |index| {
        if (index >= program.structures.len) return error.InvalidProgram;
        if (program.structures[index].is_tuple) return output.appendSlice(allocator, program.structures[index].name);
        try output.append(allocator, '@');
        return output.appendSlice(allocator, program.structures[index].name);
    }
    if (type_value.functionIndex()) |index| {
        if (index >= program.function_types.len) return error.InvalidProgram;
        const function_type = program.function_types[index];
        try output.appendSlice(allocator, "func(");
        for (function_type.parameter_types, 0..) |parameter, parameter_index| {
            if (parameter_index != 0) try output.appendSlice(allocator, ",");
            try appendType(output, allocator, program, parameter);
        }
        try output.appendSlice(allocator, ") ");
        return appendType(output, allocator, program, function_type.return_type);
    }
    try output.appendSlice(allocator, type_value.name());
}

fn writeTerminator(
    output: *std.ArrayList(u8),
    allocator: Allocator,
    function: Function,
    terminator: Terminator,
    block_count: usize,
) Error!void {
    switch (terminator) {
        .jump => |target| {
            if (target >= block_count) return error.InvalidProgram;
            try output.appendSlice(allocator, "jump ");
            try appendBlockName(output, allocator, target);
        },
        .branch => |branch| {
            if (branch.then_block >= block_count or branch.else_block >= block_count) return error.InvalidProgram;
            try output.appendSlice(allocator, "branch ");
            try appendValueChecked(output, allocator, function, branch.condition);
            try output.appendSlice(allocator, ", ");
            try appendBlockName(output, allocator, branch.then_block);
            try output.appendSlice(allocator, ", ");
            try appendBlockName(output, allocator, branch.else_block);
        },
        .return_value => |value| {
            try output.appendSlice(allocator, "return ");
            try appendValueChecked(output, allocator, function, value);
        },
        .return_void => try output.appendSlice(allocator, "return"),
        .panic => |panic_value| {
            try output.appendSlice(allocator, "panic ");
            try appendValueChecked(output, allocator, function, panic_value.message);
        },
    }
}

fn appendBlockName(output: *std.ArrayList(u8), allocator: Allocator, block: BlockId) Allocator.Error!void {
    if (block == 0) return output.appendSlice(allocator, "entry");
    var buffer: [32]u8 = undefined;
    const name = std.fmt.bufPrint(&buffer, "bb{d}", .{block}) catch unreachable;
    try output.appendSlice(allocator, name);
}

fn appendResult(output: *std.ArrayList(u8), allocator: Allocator, program: Program, function: Function, result: ValueId) Error!void {
    if (result >= function.value_types.len) return error.InvalidProgram;
    try appendValue(output, allocator, result);
    try output.append(allocator, ':');
    try appendType(output, allocator, program, function.value_types[result]);
    try output.appendSlice(allocator, " = ");
}

fn appendValueChecked(output: *std.ArrayList(u8), allocator: Allocator, function: Function, value: ValueId) Error!void {
    if (value >= function.value_types.len) return error.InvalidProgram;
    try appendValue(output, allocator, value);
}

fn appendLocalChecked(output: *std.ArrayList(u8), allocator: Allocator, function: Function, local: LocalId) Error!void {
    if (local >= function.local_types.len) return error.InvalidProgram;
    try output.append(allocator, '$');
    var buffer: [32]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{d}:{s}", .{ local, function.local_types[local].name() }) catch unreachable;
    try output.appendSlice(allocator, text);
}

fn appendValue(output: *std.ArrayList(u8), allocator: Allocator, value: ValueId) Allocator.Error!void {
    var buffer: [32]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "%{d}", .{value}) catch unreachable;
    try output.appendSlice(allocator, text);
}

fn appendInteger(output: *std.ArrayList(u8), allocator: Allocator, bits: u64, type_value: Type) Allocator.Error!void {
    var buffer: [32]u8 = undefined;
    const text = if (type_value.isSignedInteger())
        std.fmt.bufPrint(&buffer, "{d}", .{@as(i64, @bitCast(@import("Numeric.zig").signExtend(bits, type_value.bitWidth())))}) catch unreachable
    else
        std.fmt.bufPrint(&buffer, "{d}", .{bits}) catch unreachable;
    try output.appendSlice(allocator, text);
}

fn appendFloat(output: *std.ArrayList(u8), allocator: Allocator, value: f64) Allocator.Error!void {
    const text = try std.fmt.allocPrint(allocator, "{d}", .{value});
    defer allocator.free(text);
    try output.appendSlice(allocator, text);
}

test "write deterministic typed IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const answer_value_types = [_]Type{ .int, .int, .int };
    const answer_instructions = [_]Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 40 } },
        .{ .constant_int = .{ .result = 1, .bits = 2 } },
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
    };
    const main_value_types = [_]Type{.int};
    const main_instructions = [_]Instruction{.{ .call = .{ .result = 0, .function = 0, .arguments = &.{} } }};
    const functions = [_]Function{
        .{
            .name = "answer",
            .parameter_types = &.{},
            .return_type = .int,
            .value_types = &answer_value_types,
            .blocks = &.{.{ .instructions = &answer_instructions, .terminator = .{ .return_value = 2 } }},
        },
        .{
            .name = "main",
            .parameter_types = &.{},
            .return_type = .void,
            .value_types = &main_value_types,
            .blocks = &.{.{ .instructions = &main_instructions, .terminator = .return_void }},
        },
    };
    const text = try writeText(arena.allocator(), .{ .functions = &functions });
    try std.testing.expectEqualStrings(
        \\func @answer() -> int {
        \\entry:
        \\    %0:int = const 40
        \\    %1:int = const 2
        \\    %2:int = add %0, %1
        \\    return %2
        \\}
        \\
        \\func @main() -> void {
        \\entry:
        \\    %0:int = call @answer()
        \\    return
        \\}
        \\
    , text);
}
