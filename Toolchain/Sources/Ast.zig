const Source = @import("Source.zig");
const Types = @import("Types.zig");

pub const Type = Types.Type;

pub const UnaryOperator = enum {
    negate,
    logical_not,
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
        call: Call,
        field_access: FieldAccess,
        unary: Unary,
        binary: Binary,
        conversion: Conversion,
        string_count: *Expression,
        match_expression: Match,
    };

    pub const Call = struct {
        name: []const u8,
        name_position: Source.Position,
        receiver: ?*Expression = null,
        safe: bool = false,
        arguments: []const *Expression,
        named_arguments: []const NamedArgument = &.{},
        owner: usize = 0,
    };

    pub const NamedArgument = struct {
        position: Source.Position,
        name: []const u8,
        value: *Expression,
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
    };

    pub const MatchBranch = struct {
        position: Source.Position,
        variant: []const u8,
        bindings: []const MatchBinding = &.{},
        value: *Expression,
    };

    pub const Match = struct {
        subject: *Expression,
        branches: []const MatchBranch,
    };

    pub const Unary = struct {
        operator: UnaryOperator,
        operator_position: Source.Position,
        operand: *Expression,
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
    initializer: ?*Expression,
};

pub const AssignmentOperator = enum {
    assign,
    add,
    subtract,
    multiply,
    divide,
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
    fields: []const Field = &.{},

    pub const Field = struct {
        name_position: Source.Position,
        name: []const u8,
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
            .break_statement, .continue_statement => |source_position| source_position,
        };
    }
};

pub const Parameter = struct {
    position: Source.Position,
    name: []const u8,
    type: Type,
    default: ?*Expression = null,
};

pub const StructureField = struct {
    is_public: bool = true,
    is_internal: bool = false,
    position: Source.Position,
    name_position: Source.Position,
    name: []const u8,
    mutable: bool,
    type: Type,
    default: ?*Expression,
};

pub const Constructor = struct {
    is_public: bool = true,
    is_internal: bool = false,
    position: Source.Position,
    parameters: []const Parameter,
    statements: []const Statement,
};

pub const Structure = struct {
    is_public: bool = false,
    is_internal: bool = false,
    owner: usize = 0,
    position: Source.Position,
    name_position: Source.Position,
    name: []const u8,
    fields: []const StructureField,
    constructors: []const Constructor = &.{},
    methods: []const Function = &.{},
};

pub const EnumVariant = struct {
    position: Source.Position,
    name: []const u8,
    associated_types: []const Type = &.{},
};

pub const Enum = struct {
    is_public: bool = false,
    is_internal: bool = false,
    owner: usize = 0,
    position: Source.Position,
    name_position: Source.Position,
    name: []const u8,
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
    is_public: bool = false,
    is_internal: bool = false,
    owner: usize = 0,
    position: Source.Position,
    name_position: Source.Position,
    name: []const u8,
    parameters: []const Parameter,
    return_type: Type,
    statements: []const Statement,
};

pub const Program = struct {
    uses: []const Use = &.{},
    type_names: []const []const u8 = &.{},
    structures: []const Structure = &.{},
    enums: []const Enum = &.{},
    functions: []const Function,
};
