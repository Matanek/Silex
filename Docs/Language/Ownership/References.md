# Borrow values with references

Reference modes belong to parameters and returns. Calls keep ordinary syntax.

## Borrow for reading

```sx
func inspect(box:@Box) int {
    return box.get()
}

print(inspect(box))
```

`@T` expresses read intent for the borrowed path. The function may read it or
forward it to another `@T`; it cannot mutate, move, store, or return that
capability directly.

For a class, fields and methods reached through the borrowed path remain
read-only. An independent alias may still change the same instance: `@` is not
a global freeze.

## Borrow for mutation

```sx
func increment(value:&int) {
    value += 1
}

var count = 1
increment(count)
print(count) // 2
```

`&T` aliases the caller's mutable place. Writes are visible in the supplied
`var`, field, or indexed element.

For a class, an ordinary `Class` parameter may mutate the shared instance but
cannot replace the caller's reference. `&Class` may do both.

## Return a borrow

The return expression does not repeat `@` or `&`:

```sx
func inspect(owner:@Owner) @State {
    return owner.state
}

func edit(owner:&Owner) &State {
    return owner.state
}
```

With one compatible parameter, provenance is implicit. When several could be
the source, name it in the return type:

```sx
func choose(first:@State, second:@State) @first:State {
    return first
}
```

Borrowed results may live in lexical locals but cannot outlive their root or be
stored in aggregates.

`T`, `@T`, and `&T` are not separate overload signatures.
