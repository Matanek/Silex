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
