const Source = @import("Source.zig");
const Types = @import("Types.zig");

pub const Type = Types.Type;

pub const UnaryOperator = enum {
    negate,
    logical_not,
    propagate,
    move,
    copy,
    borrow_read,
    borrow_mutable,
    force_optional,
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
    logical_and,
    logical_or,
    bit_and,
    bit_xor,
    shift_left,
    shift_right,
    coalesce,
};

pub const Expression = struct {
    position: Source.Position,
    value: Value,

    pub const Value = union(enum) {
        integer: []const u8,
        floating: []const u8,
        boolean: bool,
        null_value,
        string: []const u8,
        interpolated_string: InterpolatedString,
        identifier: []const u8,
        generic_reference: GenericReference,
        call: Call,
        cascade: Cascade,
        field_access: FieldAccess,
        unary: Unary,
        binary: Binary,
        conversion: Conversion,
        string_count: *Expression,
        sequence_literal: SequenceLiteral,
        tuple_literal: TupleLiteral,
        index_access: IndexAccess,
        slice_access: SliceAccess,
        match_expression: Match,
    };

    pub const Call = struct {
        name: []const u8,
        name_position: Source.Position,
        receiver: ?*Expression = null,
        /// Set only by compiler rewrites that deliberately target an internal
        /// runtime hook. Source calls never receive this privilege.
        compiler_generated: bool = false,
        /// Restrict compiler-generated iterator lookup to `next()` overloads
        /// whose result exposes one optional layer.
        iterator_next: bool = false,
        safe: bool = false,
        arguments: []const *Expression,
        named_arguments: []const NamedArgument = &.{},
        type_arguments: []const Type = &.{},
        result_type: ?Type = null,
        owner: usize = 0,
        module: []const u8 = "",
        entry_module: bool = false,
    };

    pub const Cascade = struct {
        receiver: *Expression,
        operations: []const Operation,

        pub const Operation = union(enum) {
            method_call: MethodCall,
            field_assignment: FieldAssignment,
        };

        pub const MethodCall = struct {
            name: []const u8,
            name_position: Source.Position,
            compiler_generated: bool = false,
            arguments: []const *Expression,
            named_arguments: []const NamedArgument = &.{},
            type_arguments: []const Type = &.{},
        };

        pub const FieldAssignment = struct {
            name: []const u8,
            name_position: Source.Position,
            value: *Expression,
        };
    };

    pub const NamedArgument = struct {
        position: Source.Position,
        name: []const u8,
        value: *Expression,
    };

    pub const GenericReference = struct {
        name: []const u8,
        type_arguments: []const Type,
    };

    pub const FieldAccess = struct {
        base: *Expression,
        name_position: Source.Position,
        name: []const u8,
        safe: bool = false,
    };

    pub const MatchBinding = struct {
        position: Source.Position,
        name: []const u8,
        mutable: bool = false,
        ignored: bool = false,
    };

    pub const MatchBranch = struct {
        position: Source.Position,
        variant: []const u8 = "",
        is_else: bool = false,
        bindings: []const MatchBinding = &.{},
        guard: ?*Expression = null,
        value: ?*Expression = null,
        statements: ?[]const Statement = null,
    };

    pub const Match = struct {
        subject: *Expression,
        branches: []const MatchBranch,
        imperative: bool = false,
    };

    pub const Unary = struct {
        operator: UnaryOperator,
        operator_position: Source.Position,
        operand: *Expression,
        try_alternative: ?TryAlternative = null,
    };

    pub const TryAlternative = struct {
        position: Source.Position,
        error_position: ?Source.Position = null,
        statements: ?[]const Statement = null,
        message: ?*Expression = null,
    };

    pub const Binary = struct {
        left: *Expression,
        operator: BinaryOperator,
        operator_position: Source.Position,
        right: *Expression,
    };

    pub const Conversion = struct {
        operand: *Expression,
        target: Type,
        operator_position: Source.Position,
    };

    pub const IndexAccess = struct {
        base: *Expression,
        index: *Expression,
        bracket_position: Source.Position,
    };

    pub const SequenceLiteral = struct {
        values: []const *Expression,
        inferred_type: ?Type = null,
    };

    pub const TupleLiteral = struct {
        elements: []const Element,
        placeholder_type: Type,
        named: bool,

        pub const Element = struct {
            position: Source.Position,
            name: ?[]const u8 = null,
            value: *Expression,
        };
    };

    pub const SliceAccess = struct {
        base: *Expression,
        start: *Expression,
        end: *Expression,
        bracket_position: Source.Position,
    };

    pub const StringPart = union(enum) {
        text: []const u8,
        expression: *Expression,
    };

    pub const InterpolatedString = struct {
        parts: []const StringPart,
    };
};

pub const VariableDeclaration = struct {
    position: Source.Position,
    name_position: Source.Position,
    name: []const u8,
    mutable: bool = false,
    annotation: ?Type,
    annotation_mode: Parameter.Mode = .value,
    initializer: ?*Expression,
    destructuring: []const DestructuredBinding = &.{},

    pub const DestructuredBinding = struct {
        position: Source.Position,
        name: []const u8,
    };
};

pub const AssignmentOperator = enum {
    assign,
    add,
    subtract,
    multiply,
    divide,
    remainder,
    increment,
    decrement,
};

pub const AssignmentStatement = struct {
    position: Source.Position,
    target: AssignmentTarget,
    operator: AssignmentOperator,
    value: ?*Expression,
};

pub const AssignmentTarget = struct {
    name_position: Source.Position,
    name: []const u8,
    type_arguments: []const Type = &.{},
    fields: []const Field = &.{},
    indices: []const Index = &.{},
    indexed_fields: []const Field = &.{},

    pub const Field = struct {
        name_position: Source.Position,
        name: []const u8,
        safe: bool = false,
    };

    pub const Index = struct {
        position: Source.Position,
        value: *Expression,
    };
};

pub const ReturnStatement = struct {
    position: Source.Position,
    value: ?*Expression,
};

pub const EffectStatement = struct {
    position: Source.Position,
    value: *Expression,
};

pub const PrintStatement = struct {
    position: Source.Position,
    values: []const *Expression,
};

pub const AssertStatement = struct {
    position: Source.Position,
    condition: *Expression,
    message: *Expression,
};

pub const ConditionalBranch = struct {
    position: Source.Position,
    condition: Condition,
    statements: []const Statement,
};

pub const Condition = union(enum) {
    expression: *Expression,
    binding: ConditionalBinding,

    pub fn source(self: Condition) *Expression {
        return switch (self) {
            .expression => |expression| expression,
            .binding => |binding| binding.source,
        };
    }

    pub fn position(self: Condition) Source.Position {
        return switch (self) {
            .expression => |expression| expression.position,
            .binding => |binding| binding.position,
        };
    }
};

pub const ConditionalBinding = struct {
    position: Source.Position,
    name_position: Source.Position,
    name: []const u8,
    mutable: bool,
    source: *Expression,
};

pub const IfStatement = struct {
    position: Source.Position,
    branches: []const ConditionalBranch,
    else_statements: ?[]const Statement,
};

pub const WhileStatement = struct {
    position: Source.Position,
    condition: Condition,
    statements: []const Statement,
};

pub const ForStatement = struct {
    position: Source.Position,
    name_position: Source.Position,
    name: []const u8,
    index_position: ?Source.Position = null,
    index_name: ?[]const u8 = null,
    bindings: []const VariableDeclaration.DestructuredBinding = &.{},
    mode: Mode,
    source: SourceValue,
    statements: []const Statement,

    pub const Mode = enum { read, copy, mutable };
    pub const SourceValue = union(enum) {
        collection: *Expression,
        range: Range,
    };
    pub const Range = struct { start: *Expression, end: *Expression };
};

pub const MutexStatement = struct {
    position: Source.Position,
    statements: []const Statement,
    synchronized: bool = true,
};

pub const Statement = union(enum) {
    variable_declaration: VariableDeclaration,
    assignment_statement: AssignmentStatement,
    return_statement: ReturnStatement,
    expression_statement: *Expression,
    print_statement: PrintStatement,
    assert_statement: AssertStatement,
    panic_statement: EffectStatement,
    if_statement: IfStatement,
    while_statement: WhileStatement,
    for_statement: ForStatement,
    mutex_statement: MutexStatement,
    break_statement: Source.Position,
    continue_statement: Source.Position,

    pub fn position(self: Statement) Source.Position {
        return switch (self) {
            .variable_declaration => |declaration| declaration.position,
            .assignment_statement => |assignment| assignment.position,
            .return_statement => |statement| statement.position,
            .expression_statement => |expression| expression.position,
            .print_statement => |statement| statement.position,
            .assert_statement => |statement| statement.position,
            .panic_statement => |statement| statement.position,
            .if_statement => |statement| statement.position,
            .while_statement => |statement| statement.position,
            .for_statement => |statement| statement.position,
            .mutex_statement => |statement| statement.position,
            .break_statement, .continue_statement => |source_position| source_position,
        };
    }
};

pub const Parameter = struct {
    position: Source.Position,
    name: []const u8,
    type: Type,
    mode: Mode = .value,
    default: ?*Expression = null,

    pub const Mode = enum { value, read, mutable };
};

pub const TypeParameter = struct {
    position: Source.Position,
    name: []const u8,
    constraint: ?Type = null,
};

pub const GenericType = struct {
    position: Source.Position,
    base: Type,
    arguments: []const Type,
};

pub const FunctionType = struct {
    parameters: []const ParameterType,
    return_type: Type,
    return_mode: Parameter.Mode = .value,

    pub const ParameterType = struct {
        type: Type,
        mode: Parameter.Mode = .value,
    };
};

pub const StructureField = struct {
    is_static: bool = false,
    is_public: bool = true,
    is_internal: bool = false,
    is_local: bool = false,
    is_private: bool = false,
    is_protected: bool = false,
    visibility_explicit: bool = false,
    position: Source.Position,
    name_position: Source.Position,
    name: []const u8,
    mutable: bool,
    /// Access intent carried by non-runtime structural patterns such as an
    /// ECS query tuple. Ordinary structure and tuple fields remain values.
    access_mode: Parameter.Mode = .value,
    type: Type,
    default: ?*Expression,
};

pub const Constructor = struct {
    is_public: bool = true,
    is_internal: bool = false,
    is_local: bool = false,
    is_private: bool = false,
    is_protected: bool = false,
    visibility_explicit: bool = false,
    specialization_file: ?usize = null,
    position: Source.Position,
    parameters: []const Parameter,
    super_arguments: []const *Expression = &.{},
    statements: []const Statement,
};

pub const Structure = struct {
    is_test: bool = false,
    is_public: bool = false,
    is_internal: bool = false,
    is_local: bool = false,
    is_private: bool = false,
    is_protected: bool = false,
    is_class: bool = false,
    /// The class contract is declared by source while its storage and member
    /// implementations are supplied by a compiler-recognized intrinsic.
    is_intrinsic: bool = false,
    is_static: bool = false,
    is_protocol: bool = false,
    is_tuple: bool = false,
    tuple_named: bool = false,
    tuple_placeholder: bool = false,
    /// Compiler-derived ECS query access pattern. This is metadata only and
    /// never contributes to the runtime layout of the specialized structure.
    query_pattern: ?Type = null,
    enclosing: ?[]const u8 = null,
    owner: usize = 0,
    position: Source.Position,
    name_position: Source.Position,
    name: []const u8,
    base: ?Type = null,
    base_position: Source.Position = .{ .offset = 0, .line = 1, .column = 1 },
    conformances: []const Type = &.{},
    extension_conformances: []const ExtensionConformance = &.{},
    type_parameters: []const TypeParameter = &.{},
    fields: []const StructureField,
    static_fields: []const StructureField = &.{},
    constructors: []const Constructor = &.{},
    methods: []const Function = &.{},
    drop: ?Drop = null,
    collection: ?Collection = null,
};

pub const Drop = struct {
    position: Source.Position,
    statements: []const Statement,
};

pub const Collection = Types.Collection;

pub const EnumVariant = struct {
    position: Source.Position,
    name: []const u8,
    associated_types: []const Type = &.{},
    raw_value: ?EnumRawValue = null,
};

pub const EnumRawValue = union(enum) {
    integer: i64,
    string: []const u8,
};

pub const Enum = struct {
    is_public: bool = false,
    is_internal: bool = false,
    is_local: bool = false,
    owner: usize = 0,
    position: Source.Position,
    name_position: Source.Position,
    name: []const u8,
    type_parameters: []const TypeParameter = &.{},
    raw_type: ?Type = null,
    variants: []const EnumVariant,
};

pub const Use = struct {
    position: Source.Position,
    path: []const u8,
    type_target: ?Type = null,
    alias: ?[]const u8,
    alias_position: ?Source.Position,
    is_public: bool = false,
};

pub const Function = struct {
    is_anonymous: bool = false,
    is_test: bool = false,
    is_test_entry: bool = false,
    test_name: ?[]const u8 = null,
    test_owner: ?[]const u8 = null,
    test_source_name: ?[]const u8 = null,
    is_static: bool = false,
    is_override: bool = false,
    is_public: bool = false,
    is_internal: bool = false,
    is_local: bool = false,
    is_private: bool = false,
    is_protected: bool = false,
    visibility_explicit: bool = false,
    extension: ?ExtensionMethod = null,
    specialization_file: ?usize = null,
    owner: usize = 0,
    position: Source.Position,
    name_position: Source.Position,
    name: []const u8,
    type_parameters: []const TypeParameter = &.{},
    parameters: []const Parameter,
    return_type: Type,
    return_mode: Parameter.Mode = .value,
    return_provenance: ?[]const u8 = null,
    intrinsic: ?FunctionIntrinsic = null,
    /// True for a signature-only member of an intrinsic class.
    is_intrinsic_declaration: bool = false,
    statements: []const Statement,
};

pub const FunctionIntrinsic = union(enum) {
    resource_insert: usize,
    resource_discard,
    resource_has: usize,
    resource_get: usize,
    resource_get_mut: usize,
    resource_try_get: usize,
    resource_try_get_mut: usize,
    resource_remove: usize,
    resource_clear,
    component_get_mut,
    world_component_get_mut,
    system_adapter: SystemAdapter,
};

pub const SystemAdapter = struct {
    target: []const u8,
    target_position: Source.Position,
    receiver: ?SystemDependency = null,
    receiver_type: ?Type = null,
    dependencies: []const SystemDependency,
    mode: Mode = .direct,

    pub const Mode = union(enum) {
        direct,
        query_dispatch: QueryDispatch,
        query_range: QueryRange,
    };

    pub const QueryDispatch = struct {
        dependency: usize,
        worker: []const u8,
    };

    pub const QueryRange = struct {
        dependency: usize,
    };
};

pub const SystemDependency = struct {
    kind: enum { resource, query } = .resource,
    type: Type,
    source_type: Type,
    mode: Parameter.Mode,
    has_method: []const u8,
    get_method: []const u8,
};

pub const ExternalType = union(enum) {
    void,
    int32,
    int64,
    uint32,
    uint64,
    float32,
    float64,
    size,
    signed_size,
    read_pointer: Type,
    mutable_pointer: Type,
};

pub const ExternalFunction = struct {
    position: Source.Position,
    name_position: Source.Position,
    name: []const u8,
    parameters: []const ExternalType,
    return_type: ExternalType,
    library: []const u8,
    source_name: []const u8,
    owner: usize = 0,
};

pub const ExtensionMethod = struct {
    provider: []const u8,
    visible_files: []const usize,
};

pub const ExtensionConformance = struct {
    protocol: Type,
    position: Source.Position,
    provider: []const u8,
    visible_files: []const usize,
};

pub const Extension = struct {
    position: Source.Position,
    target_position: Source.Position,
    target: Type,
    conformances: []const Type = &.{},
    methods: []const Function,
    provider: []const u8 = "<source>",
    visible_files: []const usize = &.{},
};

pub const Program = struct {
    uses: []const Use = &.{},
    type_names: []const []const u8 = &.{},
    test_only_type_names: []const bool = &.{},
    generic_types: []const GenericType = &.{},
    function_types: []const FunctionType = &.{},
    structures: []const Structure = &.{},
    enums: []const Enum = &.{},
    extensions: []const Extension = &.{},
    external_functions: []const ExternalFunction = &.{},
    functions: []const Function,
};
