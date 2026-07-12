module.exports = grammar({
  name: "silex",

  extras: ($) => [/\s/, $.comment],
  word: ($) => $.identifier,

  rules: {
    source_file: ($) => $.function_definition,

    function_definition: ($) =>
      seq(
        field("return_type", $.void_type),
        field("name", alias("main", $.identifier)),
        $.parameter_list,
        field("body", $.block),
      ),

    void_type: (_) => "void",
    builtin_type: (_) => choice("int", "bool", "string"),
    parameter_list: (_) => seq("(", ")"),

    block: ($) => seq("{", repeat($.statement), "}"),

    statement: ($) =>
      choice(
        $.variable_declaration,
        $.assignment_statement,
        $.print_statement,
        $.if_statement,
      ),

    variable_declaration: ($) =>
      seq(
        field("mutability", choice("let", "var")),
        field("name", $.identifier),
        optional($.type_annotation),
        "=",
        field("initializer", $.expression),
        ";",
      ),

    type_annotation: ($) => seq(":", field("type", $.builtin_type)),

    assignment_statement: ($) =>
      seq(
        field("left", $.identifier),
        "=",
        field("right", $.expression),
        ";",
      ),

    print_statement: ($) =>
      seq(
        field("function", alias("print", $.identifier)),
        "(",
        field("argument", $.expression),
        ")",
        ";",
      ),

    if_statement: ($) =>
      seq("if", "(", field("condition", $.expression), ")", field("body", $.block)),

    expression: ($) =>
      choice(
        $.binary_expression,
        $.parenthesized_expression,
        $.string_literal,
        $.integer_literal,
        $.boolean_literal,
        $.identifier,
      ),

    binary_expression: ($) =>
      choice(
        prec.left(
          1,
          seq(
            field("left", $.expression),
            field("operator", choice("+", "-")),
            field("right", $.expression),
          ),
        ),
        prec.left(
          2,
          seq(
            field("left", $.expression),
            field("operator", choice("*", "/")),
            field("right", $.expression),
          ),
        ),
      ),

    parenthesized_expression: ($) => seq("(", $.expression, ")"),

    string_literal: ($) =>
      seq('"', repeat(choice($.escape_sequence, /[^"\\\n\r]+/)), '"'),

    escape_sequence: (_) => token(seq("\\", /./)),
    integer_literal: (_) => /\d+/,
    boolean_literal: (_) => choice("true", "false"),
    identifier: (_) => /[A-Za-z_][A-Za-z0-9_]*/,
    comment: (_) => token(seq("//", /[^\n]*/)),
  },
});
