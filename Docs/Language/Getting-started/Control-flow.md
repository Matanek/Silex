# Branch and repeat

## Choose a branch

```sx
if value < 0 {
    print("negative")
} elif value == 0 {
    print("zero")
} else {
    print("positive")
}
```

`else if` is also accepted. Conditions must be `bool`.

## Repeat while a condition is true

```sx
var remaining = 3

while remaining > 0 {
    print(remaining)
    remaining--
}
```

## Stop or skip an iteration

```sx
while ready() {
    if finished() {
        break
    }
    if ignored() {
        continue
    }
    work()
}
```

`break` and `continue` target the nearest loop.

## Protect shared state

```sx
mutex {
    pending.append(value)
}
```

`mutex` executes its lexical block while holding Silex's single process-wide
critical-section lock. The lock is recursive, so protected code may call a
helper that also uses `mutex`. It is released on every exit from the block,
including `return`, `break`, `continue`, and recoverable `try` propagation.
There is intentionally no manual `lock` or `unlock` operation.

## Iterate a range

```sx
for i in 0...3 {
    print(i)
}

for i in range(3, 0) {
    print(i)
}
```

Both forms exclude the end. Equal bounds produce no iteration.

Collection loops are covered in
[Iteration](../Collections/Iteration.md).
