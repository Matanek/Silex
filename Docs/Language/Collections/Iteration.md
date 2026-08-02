# Iterate values

## Read each element

```sx
for value in values {
    print(value)
}
```

The unmarked form borrows a read-only element for that iteration.

## Copy each element

```sx
for let value in values {
    inspect(value)
}
```

Explicit `let` creates an immutable element copy.

## Change stored elements

```sx
for var value in values {
    value += 1
}
```

`for var` writes the final value back before advancing, `continue`, or
`break`. It requires a mutable named collection.

## Read each element with its index

Arrays and lists expose `indexed()` when the zero-origin position is part of
the operation:

```sx
for index, item in values.indexed() {
    print("{index}: {item}")
}
```

The index is an immutable `int`. It starts at `0` and follows collection order.
The element keeps the ordinary loop modes; write `for index, let item` for an
independent copy or `for index, var item` to update the stored element. The
receiver is evaluated once, and empty collections execute no body.

The two-binding form is specific to `indexed()`; it does not destructure an
arbitrary tuple or another loop source.

## Iterate a range

```sx
for i in 0...3 {
    print(i)
}

for i in range(3, 0) {
    print(i)
}
```

Both forms exclude the end. Bounds are evaluated once from left to right.
Equal bounds produce no iteration.
