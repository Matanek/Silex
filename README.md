# Silex native compiler experiment

This repository explores a native Silex compiler whose internal model does not
depend on generated C or C++.

The current bootstrap accepts the smallest executable Silex program:

```sx
func main() {}
```

It lexes and parses the source, validates the entry point, lowers the program to
a typed textual IR, and executes that IR with a minimal interpreter. Native code
generation deliberately comes later, once this reference path is deterministic.

## Try it

```sh
cd Toolchain
zig build test
zig build run -- ../Examples/Empty/Main.sx --emit-ir
```

The command exits with status `0`. With `--emit-ir`, it also prints:

```text
func @main() -> void {
entry:
    return
}
```

## Repository layout

```text
Docs/           language and architecture contracts
Examples/       executable Silex source files
Toolchain/      autonomous Zig bootstrap project
  Sources/      compiler implementation
```

Zig is the implementation language of the bootstrap compiler. It is not an
intermediate representation, runtime dependency, or ABI for compiled Silex
programs.
