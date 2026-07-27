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

## Change the error type

```sx
func convert(error:ParseError) AppError {
    return AppError.input(error)
}

let config = map_error(parse(text), convert)
```

`map_error` calls the named transformation exactly once on failure and never
on success.
