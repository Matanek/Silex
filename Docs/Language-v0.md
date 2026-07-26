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

## Default parameters and effective signatures

A function, method, or constructor may give its trailing parameters a default
expression. An invocation may omit any final suffix of those parameters:

```sx
func greet(message:str = "Hello", repetitions:int = 1) {
    print(message)
}

greet()
greet("Bonjour")
greet("Salut", 2)
```

Every parameter after the first default must also have a default. Calls remain
positional: defaults neither introduce named function arguments nor permit a
middle argument to be skipped. An omitted default is evaluated anew at the
call site, in parameter order, after overload selection. Supplying an explicit
argument bypasses its default completely. The expression is resolved in the
declaration's module and cannot observe the caller's locals or the callable's
parameters.

Each declaration exposes one effective signature for every arity between its
required and total parameter counts. The effective signature at an arity is
the corresponding prefix of normalized parameter types. Two overloads in the
same family cannot expose the same effective signature:

```sx
init() {}
init(value:float = 0) {} // error: also exposes init()

init(value:float) {}
init(x:float, y:float = 0) {} // error: also exposes init(float)
```

This collision is rejected on the later declaration before any ambiguous call
is written. Parameter names, default expressions and return types do not
distinguish signatures, and aliases such as `int` and `int64` are identical.
Conversions between otherwise distinct effective signatures may still produce
an ambiguity diagnosed at the call site.

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

## Local bindings and mutation

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

`var` uses the same declaration forms and creates a mutable local binding.
Assignment preserves its declared or inferred type:

```sx
var count:int = 1
count = 2
count += 3
count++
```

The arithmetic updates `+=`, `-=`, `*=`, `/=`, `++`, and `--` are statements,
not expressions. They require a numeric `var`, evaluate their operand once,
and use the same checked arithmetic as `+`, `-`, `*`, and `/`. A `let` and a
function parameter cannot be assigned. Pointers, references, storage slots,
and target machine details are not part of this source contract.

The intrinsic value is the correctly typed positive zero for every numeric
type, `false` for `bool`, and the empty string for `str`. Numeric initializers
may use the widening rules. A local name cannot reuse a parameter or another
local name visible in its lexical scope; sibling branches may reuse a name.

## Structure values

`struct` declares a nominal value type in its source module. Every field starts
with `let` or `var` and carries an explicit annotation. A structure without a
custom constructor uses a parenthesized initializer with named fields:

```sx
struct Position {
    var x:int
    var y:int = 10
}

struct Entity {
    let position:Position
    var name:str
}

let origin = Entity()
let player = Entity(name:"Ada", position:Position(x:2, y:3,))
print(player.position.x)
```

Fields may be supplied once each, in any order, and the final comma is
optional. An omitted field uses its explicit default first, then the intrinsic
value of its type; this rule applies recursively to nested structures. Defaults
are restricted to fundamental literals and structure aggregates, so they do
not execute code or depend on file order. Direct or indirect recursive value
layouts are rejected.

Structure names are nominal: two declarations with identical fields remain
incompatible. Structures are ordinary values: local assignment, arguments and
returns copy the complete value without observable shared mutable state.
`==` and `!=` compare same-typed structures recursively when every contained
field is comparable. Structures gain neither ordering nor structural
conversion, and `print` continues to accept their printable fields rather than
the complete aggregate. The reference interpreter and the macOS ARM64 backend
preserve the same value semantics for construction, copy, field reads,
comparison, parameters and returns. A field path is assignable when its root
is a `var` and every field on the path is also declared `var`; an intervening
`let` makes the nested value deeply immutable through that path. Field `=`,
`+=`, `-=`, `*=`, `/=`, `++`, and `--` evaluate the target and operand once,
retain every unaffected field, and behave identically in both execution paths.

`init` declares a positional constructor inside a structure. `self` is
implicit; assigning `self.field` initializes that field, and the completed
value is returned implicitly. Declaring any constructor closes the named
aggregate initializer completely. Constructors may be overloaded by parameter
types. Every `let` field without a default must be initialized exactly once on
each normal path; reading an uninitialized field, initializing it twice, or
passing an incomplete `self` is rejected. A `var` begins with its explicit
default or intrinsic value and may then be reassigned. Constructor calls and
their returned values have matching reference and native behavior.

A function declared inside a structure is an instance method. Its implicit
`self` receiver can read fields and call other methods. A method is inferred
mutating when it writes through `self` or reaches another mutating method,
including through recursive call cycles. Mutating calls require a `var`
receiver and write the returned value state back to that receiver; nonmutating
calls accept `let`, `var`, and temporary receivers. Receiver and arguments are
evaluated once in source order, and calls may chain through returned values.
Methods are public by default with their public structure; explicit `public`
is accepted.

`public struct` exposes one nominal identity through `use`, including its
public-by-default fields, constructors, and methods. Module qualification and
aliases select that same identity rather than creating new types. A private
structure cannot be constructed outside its module or leak through a public
typed contract. No public declaration exposes native layout.

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

## Control flow

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

`while` checks a `bool` condition before every iteration and opens a lexical
scope for its body. `break` exits the nearest enclosing loop; `continue`
rechecks the condition of that loop. Both are rejected outside a loop.

```sx
var remaining = 3
while remaining > 0 {
    remaining--
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
program         = (use | structure | function)* EOF ;
use             = "use" qualified_identifier ("as" identifier)? ;
structure       = "public"? "struct" identifier "{" (structure_field | constructor | method)* "}" ;
structure_field = "public"? ("let" | "var") identifier ":" type ("=" field_default)? ;
constructor     = "init" "(" parameters? ")" block ;
method          = "public"? "func" identifier "(" parameters? ")" return_type? block ;
field_default   = fundamental_literal | structure_initializer ;
function        = "public"? "func" identifier "(" parameters? ")" return_type? block ;
parameters      = parameter ("," parameter)* ;
parameter       = identifier ":" type ("=" expression)? ;
return_type     = type ;
type            = "void" | "int8" | "int16" | "int32" | "int64" | "int"
                | "uint8" | "uint16" | "uint32" | "uint64" | "uint"
                | "float" | "float32" | "float64" | "bool" | "str"
                | identifier ;
block           = "{" statement* "}" ;
statement       = binding_statement | assignment_statement | return_statement
                | call_expression | break_statement | continue_statement
                | print_statement | assert_statement | panic_statement
                | if_statement | while_statement ;
if_statement    = "if" expression block
                  (("elif" | "else" "if") expression block)*
                  ("else" block)? ;
while_statement = "while" expression block ;
binding_statement = ("let" | "var") identifier (":" type)? ("=" expression)? ;
assignment_statement = field_path ("=" | "+=" | "-=" | "*=" | "/=") expression
                     | field_path ("++" | "--") ;
field_path      = identifier ("." identifier)* ;
break_statement = "break" ;
continue_statement = "continue" ;
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
conversion      = postfix ("as" type)* ;
postfix         = primary (("(" arguments? ")")
                | ("." identifier ("(" arguments? ")")?))* ;
primary         = integer | floating | string | "true" | "false" | identifier
                | "self" | "(" expression ")" ;
string          = '"' string_part* '"' ;
string_part     = string_text | string_escape | "$$"
                | "$(" expression ")" ;
call_expression = postfix ;
arguments       = expression ("," expression)* ;
structure_initializer = identifier "(" field_initializers? ")" ;
field_initializers = field_initializer ("," field_initializer)* ","? ;
field_initializer = identifier ":" expression ;
member_expression = identifier ("." identifier)+ ;
identifier      = (letter | "_") (letter | digit | "_")* ;
qualified_identifier = identifier ("." identifier)* ;
```

The grammar states the structural forms. Semantic requirements such as a local
binding having a type or initializer, trailing parameter defaults, effective
callable signatures, mutability, loop context, and statement termination are
enforced separately.

Whitespace and `//` line comments are ignored except that line breaks terminate
statements as described above.

## Current limits

There are no collections, method extraction, static methods, generic methods,
package lockfiles, or visible native interop in this subset. Fundamental and
structure values, constructors, instance methods, string operations and
observable effects have matching reference and macOS ARM64 behavior.
