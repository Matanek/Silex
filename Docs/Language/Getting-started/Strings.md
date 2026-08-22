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

## Write a block string

A quote followed immediately by a line break starts a block string:

```sx
let paragraph = "
    First line.
    Second line.
    "
```

The value is `First line.\nSecond line.`. The opening and closing structural
line breaks are omitted, and the indentation before the closing quote is
removed from every non-empty content line. Additional indentation remains part
of the value. Source line endings inside a block string are normalized to
`\n`.

The closing quote must begin its line after optional indentation. A content
quote elsewhere on a line is written as `\"`. A non-empty ordinary string
still has to close before its first line break, so an accidentally unterminated
`"text` remains an error on that line.

Block strings support the same escapes and `$(...)` interpolation as ordinary
strings.

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
