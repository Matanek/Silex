# Control flow

`if` and `while` conditions must have type `bool`. Each branch and loop body
opens a lexical scope.

```sx
if (enabled) {
    print("enabled")
} else {
    print("disabled")
}

while (count > 0) {
    count -= 1
}
```

`for` iterates through a fixed array, dynamic list, or exclusive integer range.
Every iteration binding starts with `let` or `var`: `let` creates an immutable
binding, while `var` creates a mutable binding.

```sx
for (let value in values) {
    print(value)
}

for (var value in values) {
    value += 1
}
```

For a collection, the source is evaluated once and held for the duration of
each loop body. An immutable loop allows other reads but no mutation of the
collection; a mutable loop binds directly to each element and allows no other
direct access to the collection.

An integer range can use `start...end` or the equivalent intrinsic
`range(start, end)`. `range` is reserved and available without an import. The
first bound is produced and the second bound is never produced:

```sx
for (let i in 0...3) {
    print(i)
}

for (let i in range(3, 0)) {
    print(i)
}
```

These loops print `0`, `1`, `2`, then `3`, `2`, `1`. The direction follows the
order of the bounds; equal bounds produce no value. Both bounds have type
`int` and are evaluated once, from left to right, before iteration. No list or
array is created. In a range loop, `var` creates a mutable local copy; changing
it does not affect either bound or the next value produced.

`break` exits the nearest loop and `continue` starts its next iteration.

Pattern matching and string iteration are not part of the current language.
