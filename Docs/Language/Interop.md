# Bind a platform system function

`Interop` is the low-level boundary used to build Silex bindings. Application
code should normally depend on a portable package such as `STD` instead.

The current native backends expose a closed set of typed system contracts used
by the platform parts of `STD`: entropy, monotonic time, console and terminal
I/O, files, processes, filesystem operations, and name resolution. macOS calls
fixed libSystem symbols, Linux X64 uses kernel syscalls, and Windows PE32+
imports the selected system DLL functions. A named package may additionally
own a private `macos-arm64` static provider declared in its manifest; that
provider is unavailable to application code and to other packages.

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
values. `C.byte_at(text, index)` returns one `uint8` from that UTF-8 sequence;
the index must be below `C.byte_count(text)`. These byte operations also let a
portable package implement byte-defined algorithms without binding a system
library.

System APIs that consume a null-terminated UTF-8 string use
`C.terminated_pointer(text)`. It has the same direct-call lifetime as
`C.pointer`, but additionally guarantees one zero byte after the string. The
terminator is not included in `C.byte_count(text)`.

The raw result follows the C library contract. A binding is responsible for
partial writes, system errors, and conversion to its public Silex error type.
A system function with no result uses `void`; calling it as an instruction does
not allocate a hidden Silex value.

Platform bindings that let the system fill a scalar use a mutable pointer that
is likewise valid only as a direct foreign argument:

```sx
var seed:uint32 = 0
let written = getrandom(C.mutable_pointer(seed), 4 as C.Size, 0)
```

`C.mutable_pointer` accepts stable `var int32`, `var uint32`, `var int`,
`var uint`, and fixed arrays of those scalar types. The storage is valid only
for the direct foreign call; the address cannot be retained or returned.

Byte-oriented system calls cannot consume a `uint8[..]` view directly because
Silex collection elements follow the private slot layout of the language, not
a C array layout. A platform binding first compacts the view with `C.string`,
then may expose that private `var str` through
`C.mutable_string_pointer(buffer)` for one direct call. If the call writes into
it, the binding reads the resulting bytes with `C.byte_at` and copies them back
to the public mutable view. This operation is reserved for freshly allocated,
unaliased platform buffers; it does not make ordinary Silex strings mutable.

Platform code can inspect and populate fields inside that direct-call storage
with `C.load<T>(address, byte_offset)` and
`C.store<T>(address, byte_offset, value)`. Both operations are restricted to
integer scalar types and explicit byte offsets. `C.store` evaluates to the
stored value. These primitives are intended for private platform layouts such
as `sockaddr`; they do not make those layouts part of a package's public API.

System callbacks use named Silex functions. `C.function_address(callback)`
returns the entry address of a concrete callback; a generic callback is
specialized explicitly with `C.function_address<T...>(callback)`. Likewise,
`C.object_address(value)` and `C.object_from_address<T>(address)` carry a class
identity through an opaque system callback context. These operations are for
private platform adapters: the object must remain alive until the system has
finished using the context.

## Current boundary

The implemented surface is deliberately narrow:

- composed targets: `macos-arm64`, `linux-x64`, `windows-x64`, and
  `windows-arm64` for the implemented STD slices;
- validated providers: `MacOS.lib_system`, `Linux.kernel`,
  `Windows.kernel32`, `Windows.bcrypt_primitives`, `Windows.ucrtbase`, and
`Windows.ws2_32`, plus target-selected package-private static providers named
as `Boundary.<Provider>` and authorized by the owning manifest for
`macos-arm64`;
- implemented capabilities: random seeding, monotonic clocks, byte console
  I/O, terminal sessions, files, process metadata, subprocesses, filesystem
  operations, sockets, name resolution, and operating-system threads;
- Windows console bindings cover UCRT byte I/O, console modes, UTF-8 input code
  pages, handle waits and screen-buffer dimensions. Their PE imports are
  verified on X64 and ARM64 but execution still awaits the Windows CI matrix;
- macOS uses the fixed `__open` and `__ioctl` syscall veneers where the public C
  functions are variadic under the Apple ARM64 ABI;
- execution: `silex run` builds and executes the native host target, so platform
  boundaries work without a separate manual compile step; the explicit
  `silex interpret` reference path emulates `arc4random` only and rejects the
  other boundaries;
- pointer sources: UTF-8 bytes of a `str` for `C.Pointer<uint8>`, a private
  mutable string buffer for byte-oriented system output, or stable
  scalar/fixed-array storage for `C.MutablePointer<T>`.

General retained pointers, captured callbacks, C structure types, variadic
calls, arbitrary library paths, and public foreign providers are not
implemented. Named callbacks with
an opaque class context are supported for the platform threading adapters.
Raw C structures are represented
only inside platform modules by fixed, contiguous scalar storage with an
explicit documented layout. The Linux X64 backend still rejects portable
operations outside its implemented vertical slices; Windows execution remains
unverified until the target matrix runs it.

A provider bundled by the current package is independent of the system
namespace used to implement the target. Import `Interop.Boundary` and name the
provider selected from the active manifest branch:

```sx
use Interop.C
use Interop.Boundary

let initialize = C.function<func(uint32) int32>(
    library:Boundary.SDL3,
    name:"SDL_Init"
)
```

Only source owned by the declaring package can use this provider. A target
without a matching `SDL3` declaration reports the missing package boundary;
the source does not switch to `MacOS`, `Linux`, or `Windows`.

A package can keep a platform binding private behind a common Silex API. For
example, `STD.Randomizer` keeps its algorithm in `Module/Randomizer.sx` and
receives its system seeding fragment from
`Platform/MacOS/Module/Randomizer.sx`. Both files compose the logical module
`STD.Randomizer`; the platform helper is private and callers manipulate
`Randomizer`, not `arc4random`:

```sx
self.state = Platform.system_seed()
```

The qualifier identifies the physical origin without introducing a public
`Platform` module or an import.

```sx
let system_random = C.function<func() uint32>(
    library:MacOS.lib_system,
    name:"arc4random"
)

func system_seed() int {
    return system_random() as int
}
```

The Linux variant calls the kernel `getrandom` capability through
`Linux.kernel`; the Windows variant calls
`ProcessPrng` from `Windows.bcrypt_primitives`. Both fill a private `uint32`
owned by the platform module. Linux X64 has executed this path under Alpine;
the Windows emitters produce typed imports for both architectures but remain
provisional until execution on Windows.
