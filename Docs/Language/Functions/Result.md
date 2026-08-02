# Return recoverable failures with Result

`Result<T,E>` has two variants: `success(T)` and `failure(E)`.

```sx
enum ParseError {
    invalid(str)
}

func parse(text:str) Result<int,ParseError> {
    if text.count() == 0 {
        return Result<int,ParseError>.failure(
            ParseError.invalid("empty")
        )
    }

    return Result<int,ParseError>.success(42)
}
```

Handle both variants with `match`:

```sx
let message = match parse("42") {
    success(value) => "value: $(value)"
    failure(error) => "invalid"
}
```

## Propagate with try

```sx
func load(text:str) Result<int,ParseError> {
    let value = try parse(text)
    return Result<int,ParseError>.success(value)
}
```

On success, `try` produces `T`. On failure, it immediately returns the same
error type from the enclosing function. This is ordinary control flow, not an
exception.

For `Result<void,E>`, use `success()` and write `try operation()` as a
statement.

## Handle a failure locally

Add an `else` block when the failure must leave the current flow in another
way. Bind `error` only when the branch needs the original value:

```sx
func load(text:str) Result<int,AppError> {
    let value = try parse(text) else error {
        return Result<int,AppError>.failure(AppError.input(error))
    }
    return Result<int,AppError>.success(value)
}
```

Write `else { ... }` to ignore the error intentionally. Every path through a
local `else` block must exit with `return`, `break`, `continue`, or another
guaranteed control-flow exit; the block does not provide a fallback value.

For command-line boundaries, the short form replaces any error type with a
`str` failure and returns it immediately:

```sx
func load_for_cli(text:str) Result<int,str> {
    let value = try parse(text) else error "cannot parse: $(text)"
    return Result<int,str>.success(value)
}
```

The message is evaluated once on failure and never on success. The original
error is intentionally not available in this short form.

## Change the error type

```sx
func convert(error:ParseError) AppError {
    return AppError.input(error)
}

let config = map_error(parse(text), convert)
```

`map_error` calls the named transformation exactly once on failure and never
on success.
