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

For precedence, see the [syntax quick reference](../Reference/Syntax.md).
