# Run a first program

Create `Main.sx`:

```sx
func main() {
    print("Hello, Silex!")
}
```

Run it from `Toolchain/`:

```sh
zig build run -- run ../Main.sx
```

Compile it on Apple Silicon macOS:

```sh
zig build run -- compile ../Main.sx -o ../hello
../hello
```

## Return a recoverable failure

`main` may return `Result<void,str>`:

```sx
func main() Result<void,str> {
    if !ready() {
        return Result<void,str>.failure("not ready")
    }

    print("ready")
    return Result<void,str>.success()
}
```

Success exits with status `0`. Failure writes `error: not ready` to standard
error and exits with status `1`.

`main` is unique, non-generic, and takes no parameters.
