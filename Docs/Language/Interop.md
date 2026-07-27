# Call a macOS system function

`Interop` is the low-level boundary used to build Silex bindings. Application
code should normally depend on a portable package such as `STD` instead.

The current compiler supports one complete contract on `macos-arm64`:
`write` from the system `libSystem` library.

```sx
use Interop.C
use Interop.MacOS

let write = C.function<
    func(int32, C.Pointer<uint8>, C.Size) C.SignedSize
>(
    library:MacOS.lib_system,
    name:"write"
)
```

The module-level `let` is a compile-time foreign binding. It does not create
mutable global state or run an initializer. `C.function` implies the C calling
convention for the selected target. Write the documented source name `write`;
the compiler produces the platform symbol, dynamic import, and executable
without invoking an external linker.

Call the binding like an ordinary function:

```sx
func write_text(text:str) C.SignedSize {
    return write(
        1,
        C.pointer(text),
        C.byte_count(text)
    )
}
```

`C.pointer(text)` exposes the read-only address of the string's UTF-8 bytes for
that foreign call. The pointer cannot be stored. `C.byte_count(text)` returns
the UTF-8 byte count as `C.Size`; `text.count()` instead counts Unicode scalar
values.

The raw result follows the C library contract. A binding is responsible for
partial writes, system errors, and conversion to its public Silex error type.

## Current boundary

The implemented surface is deliberately narrow:

- target: `macos-arm64`;
- provider: `MacOS.lib_system`;
- function: `write`;
- signature: `func(int32, C.Pointer<uint8>, C.Size) C.SignedSize`;
- pointer source: the UTF-8 bytes of a `str`, valid only for the direct call.

Other functions, binary buffers, retained pointers, callbacks, structures,
variadic calls, Linux, Windows, and arbitrary library paths are not implemented
yet.
