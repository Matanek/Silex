# Silex language v0

This document defines only the source forms implemented by the native compiler
experiment. The established Silex project remains the reference for the wider
language.

## Functions and types

A function starts with `func`, has a user-chosen name, a typed parameter list,
an optional return type, and a body. Omitting the return type means `void`.
Functions are private by default. `public func` exposes a function through a
package interface; `public` does not create a machine symbol or ABI.

```sx
func add(left:int, right:int) int {
    return left + right
}

func enabled() bool {
    return true
}
```

The integer types are `int8`, `int16`, `int32`, `int64`, `uint8`, `uint16`,
`uint32`, and `uint64`. `int` is exactly `int64`; `uint` is exactly `uint64`.
The floating types are IEEE-754 `float32` and `float64`; `float` is exactly
`float32`. `bool` and immutable UTF-8 `str` complete the current value types.
An embedded zero in a string remains ordinary data.

Functions may share a name when their parameter types differ. Resolution
prefers exact arguments, then same-family widening, then integer-to-float
conversion; incomparable candidates are ambiguous. Aliases do not create
distinct signatures. The return type alone never distinguishes an overload.
All signatures are collected before bodies, so a call may target a function
declared later in the source.

The name `main` is special only as the executable entry point. It must be unique,
have no parameters, and return `void`.

## Modules and `use`

Each `.sx` file provides one module derived from its path. `Foo/Bar.sx`
provides `Foo.Bar`; a dotted filename is equivalent, so
`Foo/Bar.sx` and `Foo.Bar.sx` would be conflicting providers.

`use` explicitly activates a module dependency. Its last segment is the local
alias unless `as` supplies another one:

```sx
use Math.Operations
use Math.Integer.Checked as Checked
use Math.Operations.add as add
```

The first declaration enables `Operations.add(...)`; the third selects one
declaration directly. A grouping namespace may be bound, but does not load all
its descendants. Only the entry module and the transitive closure selected by
actual `use` declarations are parsed and composed.

## Source packages

A local package is a sibling directory whose exact name matches the `name` in
its `Package.json`. Its sources are under `Module/`; for example
`Math/Module/Operations.sx` provides `Math.Operations` when the manifest is:

```json
{
  "name": "Math",
  "version": "1.4.1"
}
```

Package identities may be qualified (`Silex.Bootstrap`, `Silex.Rendering`).
The point remains part of the physical directory name. Independent packages
may extend the same logical namespace, but two packages cannot provide the
same complete module.

An application manifest declares version constraints without paths:

```json
{
  "dependencies": {
    "Math": "^1.4.0",
    "Silex.Bootstrap": "=0.1.0"
  }
}
```

The resolver prefers a compatible local sibling, then the newest compatible
installation under `~/.silex/packages/Name@MAJOR.MINOR.PATCH/`. A free project
without a manifest may use local sibling packages, but never consults the
global store implicitly. Package dependencies are direct: a transitive
dependency is not visible unless it is also declared directly.

## Constants and local names

`let` declares an immutable local value. Its type can be inferred, stated
explicitly, or initialized from the intrinsic value of an explicit type:

```sx
let inferred = 20
let explicit:int = 22
let byte:uint8 = 255
let precise:float64 = 2.5
let ready:bool
let text:str
```

The intrinsic value is the correctly typed positive zero for every numeric
type, `false` for `bool`, and the empty string for `str`. Numeric initializers
may use the widening rules. A local name cannot reuse a parameter or another
local name visible in its lexical scope; sibling branches may reuse a name.

Integer literals accept decimal, binary, octal, and hexadecimal notation with
`_` separators. They default to `int` but receive an expected integer type
directly when context supplies one. Decimal floating literals default to
`float` and accept exponents. Boolean literals are `true` and `false`. String
literals accept UTF-8 text and the escapes `\\`, `\"`, `\n`, `\r`, `\t`, `\0`, and
`\u{H...}`. Escapes are decoded once when the source is compiled. `\(` is not
an escape.

## Expressions, calls, and returns

The operators, in decreasing precedence, are postfix `as`; unary `-` and `!`;
multiplicative `*`, `/`, `%`; additive `+`, `-`; unsigned shifts `<<`, `>>`;
unsigned `&`; unsigned `^`; ordering `<`, `<=`, `>`, `>=`; equality `==`,
`!=`; logical `&&`; then logical `||`. Binary operators associate to the left.
Compatible integers widen within one signedness family. A floating operand
selects `float32` or `float64` as the common type. Numeric arithmetic is typed;
`%` remains integer-only. `&&` and `||` evaluate their right operand only when
needed.

`expression as type` performs a checked numeric conversion and fails at runtime
if the current value is outside the target domain or would lose information.
Unsigned `&`, `^`, `<<`, and `>>` preserve unsigned semantics; shift counts
must be within the left operand's width.

Strings compare by exact UTF-8 bytes. `+` concatenates immutable strings and
`count()` returns the number of Unicode scalar values.

`$(expression)` interpolates an expression and produces a normal `str` value.
The expression is evaluated once in source order and uses the same canonical
text as `print`. Only `$(` starts interpolation: `$value` and `${value}` are
ordinary text. `$$` writes one literal dollar, so `"$$(value)"` evaluates to
`"$(value)"`.

```sx
let value = 21
let message = "Value: $(value * 2)"
```

Calls use positional arguments and can be nested in another call, initializer,
arithmetic expression, or return. A direct call can also be a statement; its
result is then intentionally ignored.

```sx
func answer() int {
    return 40 + 2
}

func main() {
    answer()
}
```

`return` carries exactly one value in a non-`void` function and no value in a
`void` function. A non-`void` function must return or panic on every reachable
path. A `void` function receives an implicit return when its end is reachable.

## Conditional control flow

`if` requires `bool`. `elif` is canonical; `else if` is accepted and may be
mixed with it. Conditions run from top to bottom and stop after the first true
branch. Every branch opens a sibling lexical scope.

```sx
if value < 0 {
    print("negative")
} elif value == 0 {
    print("zero")
} else {
    print("positive")
}
```

## Observable statements

`print(expression, ...)` accepts one or more expressions. It evaluates every
argument exactly once from left to right, concatenates their representations
without an implicit separator, then writes one line to standard output. It
accepts `str`, every numeric type, and `bool`; integers use decimal notation and
booleans use `true` or `false`. Floating values use the shortest deterministic
round-trippable decimal spelling, with `-0.0`, `inf`, `-inf`, and `nan` for the
special forms. String bytes are preserved exactly, including embedded zero
bytes, before the final line break.

`assert(condition, message)` requires `bool` then `str`. A true condition does
nothing. A false condition writes this exact diagnostic to standard error and
terminates with status `1`:

```text
<source>:<line>:<column>: runtime error: assertion failed: <message>
```

`panic(message)` accepts `str`, always terminates with status `1`, and writes:

```text
<source>:<line>:<column>: runtime error: <message>
```

Both operations are always active. They expose no writer, recovery object,
native handle, or platform mechanism to source code.

Statements end at a line break, immediately before `}`, or at an explicit `;`.
Statements on the same line require `;`. An expression continues after an
operator and inside parentheses.

Integer overflow, division by zero, and non-representable negation are checked
by both execution paths and never silently wrap. The interpreter remains the
normative reference for these semantics.

## Grammar

```ebnf
program         = (use | function)* EOF ;
use             = "use" qualified_identifier ("as" identifier)? ;
function        = "public"? "func" identifier "(" parameters? ")" return_type? block ;
parameters      = parameter ("," parameter)* ;
parameter       = identifier ":" type ;
return_type     = type ;
type            = "void" | "int8" | "int16" | "int32" | "int64" | "int"
                | "uint8" | "uint16" | "uint32" | "uint64" | "uint"
                | "float" | "float32" | "float64" | "bool" | "str" ;
block           = "{" statement* "}" ;
statement       = let_statement | return_statement | call_expression
                | print_statement | assert_statement | panic_statement
                | if_statement ;
if_statement    = "if" expression block
                  (("elif" | "else" "if") expression block)*
                  ("else" block)? ;
let_statement   = "let" identifier (":" type)? ("=" expression)? ;
return_statement = "return" expression? ;
print_statement = "print" "(" expression ("," expression)* ")" ;
assert_statement = "assert" "(" expression "," expression ")" ;
panic_statement = "panic" "(" expression ")" ;
expression      = logical_or ;
logical_or      = logical_and ("||" logical_and)* ;
logical_and     = equality ("&&" equality)* ;
equality        = comparison (("==" | "!=") comparison)* ;
comparison      = bit_xor (("<" | "<=" | ">" | ">=") bit_xor)* ;
bit_xor         = bit_and ("^" bit_and)* ;
bit_and         = shift ("&" shift)* ;
shift           = additive (("<<" | ">>") additive)* ;
additive        = multiplicative (("+" | "-") multiplicative)* ;
multiplicative  = unary (("*" | "/" | "%") unary)* ;
unary           = ("-" | "!") unary | conversion ;
conversion      = primary ("as" type | "." "count" "(" ")")* ;
primary         = integer | floating | string | "true" | "false" | identifier
                | call_expression | "(" expression ")" ;
string          = '"' string_part* '"' ;
string_part     = string_text | string_escape | "$$"
                | "$(" expression ")" ;
call_expression = qualified_identifier "(" arguments? ")" ;
arguments       = expression ("," expression)* ;
identifier      = (letter | "_") (letter | digit | "_")* ;
qualified_identifier = identifier ("." identifier)* ;
```

The grammar states the structural forms. Semantic requirements such as a
`let` having a type or initializer, callable overload resolution, and statement
termination are enforced separately.

Whitespace and `//` line comments are ignored except that line breaks terminate
statements as described above.

## Current limits

There are no mutable variables, assignments, loops, collections, general
methods, downloaded packages, package lockfiles, or visible native interop in
this subset. String concatenation, byte equality and Unicode scalar `count()`
have the same observable semantics in the interpreter and native backend, as
does floating-point calculation and decimal `print` formatting.
