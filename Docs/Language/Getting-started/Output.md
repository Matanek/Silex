# Print and stop a program

## Print values

```sx
print("x=", position.x, ", y=", position.y)
```

`print` evaluates arguments from left to right, adds no separator, and writes
one final line break. It accepts strings, numbers, and booleans.

## Assert a condition

```sx
assert(count > 0, "count must be positive")
```

A failed assertion writes a source-located diagnostic to standard error and
terminates with status `1`.

## Stop with a message

```sx
panic("unreachable state")
```

`panic` always writes a source-located diagnostic and terminates with status
`1`.
