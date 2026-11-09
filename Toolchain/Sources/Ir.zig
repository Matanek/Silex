const std = @import("std");
const Types = @import("Types.zig");
const Source = @import("Source.zig");

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
    reference_is_edge,
    reference_address,

    pub fn name(self: UnaryOperator) []const u8 {
        return switch (self) {
            .negate => "neg",
            .reference_is_edge => "reference.is_edge",
            .reference_address => "reference.address",
        };
    }
};

pub const BinaryOperator = enum {
    add,
    subtract,
    multiply,
    divide,
    remainder,
    minimum,
    maximum,
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

    pub fn name(self: BinaryOperator) []const u8 {
        return switch (self) {
            .add => "add",
            .subtract => "sub",
            .multiply => "mul",
            .divide => "div",
            .remainder => "rem",
            .minimum => "min",
            .maximum => "max",
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
    class_test: ClassTest,
    class_retain: ClassRetain,
    class_drop: ClassDrop,
    list_retain: ListResource,
    list_drop: ListResource,
    string_retain: ListResource,
    string_drop: ListResource,
    global_load: GlobalLoad,
    global_store: GlobalStore,
    storage_init: StorageInit,
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
    boundary_indirect_call: BoundaryIndirectCall,
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

    pub const ClassTest = struct {
        result: ValueId,
        operand: ValueId,
        structure: usize,
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
        skip_cycle: bool = false,
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

    /// Creates compiler-owned storage for a source field that is not yet
    /// semantically initialized. Source expressions can never observe this
    /// value; constructor definite-initialization checks guarantee that it is
    /// replaced before `self` escapes or returns.
    pub const StorageInit = struct { result: ValueId };

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
        checked: bool = true,
        ownership: Ownership = .root,
        position: Source.Position,
    };

    pub const CollectionReplace = struct {
        result: ValueId,
        collection: ValueId,
        index: ValueId,
        replacement: ValueId,
        checked: bool = true,
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
        c_abi: bool = false,
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
        left_non_negative: bool = false,
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

    pub const BoundaryIndirectCall = struct {
        result: ?ValueId,
        callee: ValueId,
        signature: usize,
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
    instruction_positions: []const ?Source.Position = &.{},
    terminator: Terminator,
    terminator_position: ?Source.Position = null,
};

// Semantic lifetime metadata. It is cached with the typed body and is not
// an instruction or a change to the native ABI.
pub const BorrowOrigin = struct { reference: ValueId, lifetime: usize, type: Type = .void };
pub const LiveBinding = struct { value: ?ValueId = null, local: ?LocalId = null };
pub const BorrowEnd = struct {
    block: BlockId,
    instruction: usize,
    lifetimes: []const usize,
    live: []const LiveBinding,
    position: ?Source.Position = null,
};

pub const Function = struct {
    name: []const u8,
    is_test_entry: bool = false,
    source_position: ?Source.Position = null,
    capture_types: []const Type = &.{},
    parameter_types: []const Type,
    return_type: Type,
    value_types: []const Type,
    local_types: []const Type = &.{},
    borrow_origins: []const BorrowOrigin = &.{},
    borrow_ends: []const BorrowEnd = &.{},
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
    /// Frontend-only tuple shape awaiting contextual inference. A cached
    /// generated function can legitimately leave such a placeholder unused.
    tuple_placeholder: bool = false,
    tuple_named: bool = false,
    is_class: bool = false,
    is_copyable: bool = true,
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
    boundary_effects: []const BoundaryEffect = &.{},
};

pub const BoundaryEffect = enum {
    unknown,
    pure,
};

pub const FunctionType = struct {
    parameter_types: []const Type,
    return_type: Type,
    // Preserve source types for semantic effect selection after @/& inputs
    // have lowered to addresses. These fields do not affect the native ABI.
    logical_parameter_types: []const Type = &.{},
    logical_return_type: Type = .void,
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
    return @import("Ir/Text.zig").writeText(allocator, program);
}

/// Run the same typed IR checks without constructing discarded text.
pub fn validate(allocator: Allocator, program: Program) Error!void {
    return @import("Ir/Text.zig").validate(allocator, program);
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

test "IR validation checks many functions with bounded caller storage" {
    const instructions = [_]Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 42 } },
        .{ .print = .{ .value = 0, .newline = true } },
    };
    const blocks = [_]Block{.{ .instructions = &instructions, .terminator = .return_void }};
    const functions = try std.testing.allocator.alloc(Function, 8192);
    defer std.testing.allocator.free(functions);
    @memset(functions, .{ .name = "value", .parameter_types = &.{}, .return_type = .void, .value_types = &.{.int}, .blocks = &blocks });
    var storage: [32 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    try validate(fixed.allocator(), .{ .functions = functions });
}

test "IR validation keeps writer errors without allocating text" {
    var empty: [0]u8 = .{};
    var fixed = std.heap.FixedBufferAllocator.init(&empty);
    var blocks = [_]Block{.{ .instructions = &.{.{ .constant_int = .{ .result = 0, .bits = 42 } }}, .terminator = .{ .return_value = 0 } }};
    var functions = [_]Function{.{ .name = "sample", .parameter_types = &.{}, .return_type = .int, .value_types = &.{.int}, .local_types = &.{.int}, .blocks = &blocks }};
    const program: Program = .{ .functions = &functions };
    try validate(fixed.allocator(), program);
    try std.testing.expectError(error.OutOfMemory, writeText(fixed.allocator(), program));
    const bad = [_]Instruction{
        .{ .constant_int = .{ .result = 5, .bits = 42 } },
        .{ .local_load = .{ .result = 0, .local = 9 } },
        .{ .copy = .{ .result = 0, .operand = 9 } },
        .{ .global_load = .{ .result = 0, .global = 9 } },
        .{ .global_store = .{ .global = 9, .operand = 0 } },
        .{ .call = .{ .result = null, .function = 9, .arguments = &.{} } },
        .{ .dynamic_call = .{ .result = null, .function = 9, .receiver = 0, .arguments = &.{}, .implementations = &.{} } },
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    for (bad) |instruction| {
        blocks[0].instructions = &.{instruction};
        try std.testing.expectError(error.InvalidProgram, writeText(arena.allocator(), program));
        try std.testing.expectError(error.InvalidProgram, validate(fixed.allocator(), program));
    }
    blocks[0].instructions = &.{};
    blocks[0].terminator = .{ .jump = 2 };
    try std.testing.expectError(error.InvalidProgram, writeText(arena.allocator(), program));
    try std.testing.expectError(error.InvalidProgram, validate(fixed.allocator(), program));
    functions[0].return_type = .structure(999);
    try std.testing.expectError(error.InvalidProgram, writeText(arena.allocator(), program));
    try std.testing.expectError(error.InvalidProgram, validate(fixed.allocator(), program));
}
