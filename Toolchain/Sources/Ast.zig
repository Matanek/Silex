const Source = @import("Source.zig");

pub const BinaryOperator = enum {
    add,
    subtract,
    multiply,
    divide,
};

pub const TypeName = enum {
    int,
    bool,
    string,
};

pub const Mutability = enum {
    immutable,
    mutable,
};

pub const Expression = struct {
    position: Source.Position,
    value: union(enum) {
        integer: []const u8,
        boolean: bool,
        string: []const u8,
        identifier: []const u8,
        binary: Binary,
    },

    pub const Binary = struct {
        operator: BinaryOperator,
        operator_position: Source.Position,
        left: *Expression,
        right: *Expression,
    };
};

pub const Statement = union(enum) {
    print: Print,
    variable_declaration: VariableDeclaration,
    assignment: Assignment,
    if_statement: If,

    pub const Print = struct {
        position: Source.Position,
        argument: *Expression,
    };

    pub const VariableDeclaration = struct {
        position: Source.Position,
        name: []const u8,
        name_position: Source.Position,
        mutability: Mutability,
        annotation: ?TypeName,
        initializer: *Expression,
    };

    pub const Assignment = struct {
        position: Source.Position,
        name: []const u8,
        value: *Expression,
    };

    pub const If = struct {
        position: Source.Position,
        condition: *Expression,
        body: []const Statement,
    };
};

pub const Program = struct {
    statements: []const Statement,
};
