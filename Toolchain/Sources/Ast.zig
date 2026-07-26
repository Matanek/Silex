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
        string: []const u8,
        interpolated_string: InterpolatedString,
        identifier: []const u8,
        call: Call,
        unary: Unary,
        binary: Binary,
        conversion: Conversion,
        string_count: *Expression,
    };

    pub const Call = struct {
        name: []const u8,
        name_position: Source.Position,
        arguments: []const *Expression,
        owner: usize = 0,
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
    annotation: ?Type,
    initializer: ?*Expression,
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
    condition: *Expression,
    statements: []const Statement,
};

pub const IfStatement = struct {
    position: Source.Position,
    branches: []const ConditionalBranch,
    else_statements: ?[]const Statement,
};

pub const Statement = union(enum) {
    variable_declaration: VariableDeclaration,
    return_statement: ReturnStatement,
    expression_statement: *Expression,
    print_statement: PrintStatement,
    assert_statement: AssertStatement,
    panic_statement: EffectStatement,
    if_statement: IfStatement,

    pub fn position(self: Statement) Source.Position {
        return switch (self) {
            .variable_declaration => |declaration| declaration.position,
            .return_statement => |statement| statement.position,
            .expression_statement => |expression| expression.position,
            .print_statement => |statement| statement.position,
            .assert_statement => |statement| statement.position,
            .panic_statement => |statement| statement.position,
            .if_statement => |statement| statement.position,
        };
    }
};

pub const Parameter = struct {
    position: Source.Position,
    name: []const u8,
    type: Type,
};

pub const Use = struct {
    position: Source.Position,
    path: []const u8,
    alias: ?[]const u8,
    alias_position: ?Source.Position,
    is_public: bool = false,
};

pub const Function = struct {
    is_public: bool = false,
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
    functions: []const Function,
};
