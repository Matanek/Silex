const Source = @import("Source.zig");
const Types = @import("Types.zig");

pub const Type = Types.Type;

pub const UnaryOperator = enum {
    negate,
};

pub const BinaryOperator = enum {
    add,
    subtract,
    multiply,
    divide,
    remainder,
};

pub const Expression = struct {
    position: Source.Position,
    value: Value,

    pub const Value = union(enum) {
        integer: []const u8,
        boolean: bool,
        identifier: []const u8,
        call: Call,
        unary: Unary,
        binary: Binary,
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

pub const Statement = union(enum) {
    variable_declaration: VariableDeclaration,
    return_statement: ReturnStatement,
    expression_statement: *Expression,

    pub fn position(self: Statement) Source.Position {
        return switch (self) {
            .variable_declaration => |declaration| declaration.position,
            .return_statement => |statement| statement.position,
            .expression_statement => |expression| expression.position,
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
