# Calculate and compare values

## Arithmetic

```sx
let total = left + right
let difference = left - right
let product = left * right
let quotient = left / right
let remainder = left % right
```

`%` accepts integers only. Arithmetic checks overflow, division by zero, and
non-representable negation.

Compatible integers widen within the same signedness family. A floating-point
operand selects the common `float32` or `float64` type.

## Compare values

```sx
let same = left == right
let different = left != right
let ordered = left < right
```

Numbers support `==`, `!=`, `<`, `<=`, `>`, and `>=`. Strings compare exact
UTF-8 bytes. Structures compare recursively when all fields are comparable.
Enums compare their active variant and its associated values recursively.
Classes compare identity.

## Combine conditions

```sx
if ready && count > 0 {
    work()
}

if missing || expired {
    refresh()
}
```

`&&` and `||` short-circuit: the right side runs only when needed. `!` negates
a boolean.

## Work with unsigned bits

```sx
let masked = flags & mask
let toggled = flags ^ mask
let shifted = value << 2
let reduced = value >> 1
```

Bitwise operators accept unsigned integers. A shift count must fit the width
of its left operand.

## Concatenate strings

```sx
let full_name = first + " " + last
```

## Apply several operations to one value

The cascade operator `..` applies every segment to the same receiver. The
receiver is evaluated once, method results between segments are ignored, and
the complete expression produces the receiver after its mutations.

```sx
var values:int[] = []
    ..append(10)
    ..append(20)
    ..reverse()
```

A segment is either a method call or a direct field assignment. The ordinary
mutability, visibility, ownership, and borrowing rules still apply. An
existing value must therefore be mutable when a segment writes to it, while a
newly owned temporary can be configured directly:

```sx
let point = Point(x:0, y:0)
    ..x = 10
    ..move(2, 3)
```

A single `.` after a method segment ends the cascade and resumes ordinary
member access on its resulting receiver:

```sx
let count = values..append(30).count()
```

`..` is a single token. It is distinct from `...`, which forms an integer
range in a `for` loop.

For precedence, see the [syntax quick reference](../Reference/Syntax.md).
