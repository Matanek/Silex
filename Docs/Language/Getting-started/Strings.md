# Build strings

Strings are immutable UTF-8 values:

```sx
let name = "Ada"
let greeting = "Hello, " + name
```

Equality compares exact UTF-8 bytes. `count()` returns the number of Unicode
scalar values.

## Escape characters

```sx
let lines = "line one\nline two"
let quoted = "\"Silex\""
let scalar = "\u{1F642}"
```

Supported escapes include `\\`, `\"`, `\n`, `\r`, `\t`, `\0`, and
`\u{H...}`.

## Interpolate a value

```sx
let answer = 42
let message = "The answer is $(answer)"
```

Only `$(` starts interpolation. The expression is evaluated once.

Use `$$` for one literal dollar:

```sx
let source = "$$(answer)" // "$(answer)"
```
