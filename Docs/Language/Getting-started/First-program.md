# Run a first program

Create `Main.sx`:

```sx
func main() {
    print("Hello, Silex!")
}
```

Run it:

```sh
silex run Main.sx
```

Compile it on Apple Silicon macOS:

```sh
silex compile Main.sx -o hello
./hello
```

## Return a recoverable failure

`main` may return `Result<void,str>`:

```sx
func main() Result<void,str> {
    if !ready() {
        return Result<void,str>.failure("not ready")
    }

    print("ready")
    return Result<void,str>.success
}
```

Success exits with status `0`. Failure writes `error: not ready` to standard
error and exits with status `1`.

`main` is unique, non-generic, and takes no parameters.

## Test one source locally

Any `.sx` source may contain a local `main` beside its reusable declarations:

```sx
public func parse(value:str) int {
    return 42
}

func main() {
    print(parse("example"))
}
```

When this exact file is passed to `run`, `interpret`, or `compile`, its `main`
is the program entry point. When another source loads the file as a module,
that `main` is ignored: it is not part of the module interface and is not
compiled. The rest of the source remains available normally.

Because `main` is always local to its source, `public func main()` is invalid.
Use project tests instead when a scenario needs fixtures or a durable test
suite.
