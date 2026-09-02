# Native code generation

Native lowering begins only after composition has produced portable typed IR.
Each backend owns its machine convention, executable format, system boundary,
and target-specific proof.

## Close the native program

Native compilation computes one transitive function closure before Release
optimization or Debug lowering. An executable starts from its semantic `main`
entry; a native test compilation starts from all selected test entries. Static
initialization is already attached to those entries as typed calls.

The closure follows direct calls, function references, every declared dynamic
dispatch implementation, and class finalizers. An indirect call therefore
retains the callback declarations whose function references can reach it. When
semantic dispatch exposes several valid implementations, the closure keeps
all of them rather than selecting a target speculatively.

Retained functions preserve their original order. Their numeric identities and
all embedded call, callback, dispatch, and finalizer identities are remapped as
one deterministic operation. ARM64 and X64 consequently receive the same
closed portable program; a backend cannot independently discard a different
semantic slice. The complete typed IR remains available to diagnostics, the
reference interpreter, and `--emit-ir`.

## Recognize targets

Package composition recognizes `macos-arm64`, `linux-x64`, `windows-x64`,
and `windows-arm64`. It combines common modules with an OS-level
`Platform/<OS>/Module/` root and an optional exact `Target/<target>/Module/`
root. Recognizing and analyzing a target does not claim that its native
backend is implemented.

| Target | Current status |
| --- | --- |
| `macos-arm64` | verified and distributed |
| `linux-x64` | verified and distributed |
| `windows-x64` | verified and distributed |
| `windows-arm64` | emitted and structurally tested, but not verified or distributed |

## Emit macOS ARM64 programs

The macOS ARM64 backend uses an internal register-and-stack ABI and reports
checked arithmetic failures through an internal status register. Ordinary
functions give every IR value a deterministic stack home. When that cumulative
layout would exceed the machine slot namespace, CFG-wide liveness lets values
whose lifetimes do not overlap reuse physical homes; address-derived storage,
locals, closure environments, and the hidden aggregate return destination stay
pinned. A recycled function remains stack-resident so register allocation never
confuses a physical home with one virtual value identity.
The first eight scalar arguments use target registers and additional scalar
or aggregate arguments use aligned outgoing stack slots; source arity is not
capped by the register count.

Native structure lowering flattens fundamental leaves into private stack-slot
spans. Aggregate arguments use internal addresses and aggregate returns use
an internal hidden destination; neither convention, nor the flattened layout,
is observable or stable outside the backend.

For programs retaining at least 256 functions, ARM64 lowering divides the
function sequence into at most four fixed ranges. Each worker writes only its
own destination range, so the final machine program keeps the canonical
function order. String collection and machine-function cache reads happen
before this parallel region; cache publication and whole-program validation
happen after it. Those barriers keep shared cache mutation and global table
construction deterministic. Smaller programs use the direct path to avoid
thread startup overhead.

Without a package-native provider, Release writes the Mach-O headers, load
commands, `__text`, entry wrapper, and ad-hoc SHA-256 code signature itself.
Debug emits the same machine code through the relocatable-object path so the
bootstrap linker can preserve its Silex source symbols. Neither path invokes
an assembler or `codesign`.

## Link native package boundaries

For a referenced package-private provider, the compiler writes a relocatable
object for the selected target: ARM64 Mach-O, x64 ELF, or x64/ARM64 COFF. It
then invokes the bootstrap linker with only the resolved package archives,
declared Apple frameworks, and named system libraries. This path does not
compile foreign sources and does not define a stable Silex object format or
ABI.

Package platform adapters may call a raw function-table entry through
`C.call<func(...) T>`. Semantic analysis records its checked C signature in
portable IR, and each native backend lowers the indirect call with the same
target ABI rules as a named boundary function.

## Emit Linux X64 programs

The Linux X64 backend owns a distinct Silex call convention, encodes X64
instructions directly and writes an ELF64 container without section headers
or an external linker when no package boundary is referenced. Boundary calls
instead use a relocatable ELF object and the bootstrap linker. Its integer,
control-flow, class, aggregate, dynamic-list mutation,
string/boolean/integer output, scalar floating-point arithmetic, baseline SSE
`float32` pairs, and `getrandom` vertical slice executes under Alpine. Calls
use the same eight-register-plus-stack policy for direct, indirect and
dynamic dispatch. Other machine operations remain explicit encoder errors
until the differential corpus covers them.

Mutable globals are currently appended to the bootstrap image, so its single
load segment is temporarily executable and writable. A dedicated writable
data segment is required before the X64 container is hardened.

## Emit Windows programs

The Windows emitters write PE32+ for X64 and ARM64, including deterministic
import descriptors, lookup tables and IAT entries for `VirtualAlloc` and
`ProcessPrng`. X64 uses the Win64 boundary registers and ARM64 shares the
instruction encoder while substituting the Windows allocation boundary. The
Windows X64 path shares the Linux X64 list, output, stack-argument and
baseline SSE pair instruction coverage while adapting system calls to
imported Win32/UCRT functions.

Package-boundary builds use COFF objects, Win64 or Windows ARM64 C ABI calls,
and the bootstrap linker with the selected archives and system libraries.
The X64 bootstrap image likewise keeps its combined code/global section
writable until PE emission gains a distinct data section. Windows X64 is
verified by the native portability workflow; Windows ARM64 remains limited to
structural emission tests.

## Lower the built-in macOS boundary

The `macos-arm64` target can lower one verified C ABI contract declared in
Silex as `MacOS.lib_system.write`. After portable composition, the target maps
it to its internal Darwin provider and emits the `libSystem` load command,
`_write` symbol, binding stream and GOT directly. Only the typed `Interop`
declaration is exposed to binding authors; the target mechanism does not
change the language's internal calling convention.
