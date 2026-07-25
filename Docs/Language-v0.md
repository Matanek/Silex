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

The executable value types are currently `int` and `bool`. `int` is a signed
64-bit integer. The parser also preserves `float`, its equivalent spelling
`float32`, and `str` in signatures, but values of those types are not executable
yet.

Functions may share a name when their parameter types differ. Calls resolve to
an exact parameter list; the return type alone never distinguishes an overload.
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
let ready:bool
```

The intrinsic value is `0` for `int` and `false` for `bool`. An explicit
annotation must exactly match the initializer. A local name cannot reuse a
parameter or another local name visible in the same function.

Integer literals accept decimal, binary, octal, and hexadecimal notation with
`_` separators. Boolean literals are `true` and `false`.

## Expressions, calls, and returns

The arithmetic operators are unary `-`, multiplicative `*`, `/`, `%`, then
additive `+`, `-`, in decreasing precedence. Binary operators associate to the
left and require `int` operands.

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
`void` function. With the current linear bodies, a non-`void` function must end
with a value return. A `void` function receives an implicit return at the end.

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
type            = "void" | "int" | "bool" | "float" | "float32" | "str" ;
block           = "{" statement* "}" ;
statement       = let_statement | return_statement | call_expression ;
let_statement   = "let" identifier (":" type)? ("=" expression)? ;
return_statement = "return" expression? ;
expression      = additive ;
additive        = multiplicative (("+" | "-") multiplicative)* ;
multiplicative  = unary (("*" | "/" | "%") unary)* ;
unary           = "-" unary | primary ;
primary         = integer | "true" | "false" | identifier
                | call_expression | "(" expression ")" ;
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

There are no mutable variables, assignments, comparisons, logical operators,
conditions, loops, strings or floating-point expressions, collections,
methods, downloaded packages, package lockfiles, or visible native interop in
this subset.
