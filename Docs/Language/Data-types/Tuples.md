# Group structural values with tuples

Use a named tuple when a small result has several stable roles but does not
need a nominal structure:

```sx
func size() (width:int, height:int) {
    return (width:1280, height:720)
}

let value = size()
print(value.width)
print(value.height)
```

The declared names are part of the tuple type. Construction repeats every name
in declaration order, which keeps two values of the same type from being
silently inverted. Named members are offered by editor completion.

Use a positional tuple when its elements are naturally consumed together and
their order is sufficient:

```sx
func bounds() (int, int) {
    return (0, 100)
}

let (minimum, maximum) = bounds()
```

A named tuple can be destructured in the same declaration order:

```sx
let (width, height) = size()
```

Destructuring must bind exactly one name per element. Positional tuples do not
have named member access.

## Compose tuple types

A tuple contains at least two elements, may mix types, and can be nested,
stored, passed, returned, or used as the element of a collection:

```sx
let samples:(int, bool)[2] = [(1, true), (2, false)]
let nested:((x:int, y:int), bool) = ((x:10, y:20), true)
```

One parenthesized expression remains an ordinary grouped expression; it is not
a one-element tuple.

Tuple elements are immutable. Copy, move, lifetime, and destruction rules are
applied recursively to their values, just as they are for other composed Silex
values. A function still returns exactly one value: that value may be a tuple,
but tuples do not introduce a separate multiple-return mechanism.

Tuple layout, alignment, and return convention are compiler details. They are
not a stable ABI and are unavailable in C interop declarations.
