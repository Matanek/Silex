# Silex language v0

This document defines only the source forms implemented by the native compiler
experiment. The established Silex project remains the reference for the wider
language.

## Functions

A function starts with `func`, has a user-chosen name, a typed parameter list,
an optional return type, and a body.

```sx
func main() {}
func pow(value:float) float {}
func get_name() str {}
```

Omitting the return type means `void`. `float` is the canonical spelling of
`float32`; `str` denotes a UTF-8 string. Function names such as `pow` and
`get_name` have no intrinsic meaning to the language.

The name `main` is special only when an executable is built. In language v0 it
must have no parameters and return `void`:

```sx
func main() {}
```

## Grammar

```ebnf
program        = function* EOF ;
function       = "func" identifier "(" parameters? ")" return_type? block ;
parameters     = parameter ("," parameter)* ;
parameter      = identifier ":" type ;
return_type    = type ;
type           = "void" | "float" | "float32" | "str" ;
block          = "{" "}" ;
identifier     = (letter | "_") (letter | digit | "_")* ;
```

Whitespace and `//` line comments are ignored.

## Implemented semantic subset

The parser records ordinary parameter and return types, but the first
interpreter intentionally accepts only empty `void` function bodies. Statements,
expressions, returned values, calls, storage, strings, and floating-point
operations are not implemented yet.

This means the illustrative declarations returning `float` or `str` are valid
signatures but incomplete programs until return statements and expressions are
added.
