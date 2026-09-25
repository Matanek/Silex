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

The shared lowering resolves a fixed array's `collection_count` to its static
element count. Optimizations may introduce this IR operation while normalizing
negative indices, even when source-level `count()` calls already folded to
constants. Dynamic lists and views retain their runtime count access; a fixed
array's inline elements must never be interpreted as a list header.

## Preserve floating-point rounding

Separate floating-point operations in typed and machine IR retain their
intermediate rounding in native code. ARM64 emits a multiplication followed by
addition or subtraction as separate instructions, even when the product has a
single use. An implicit fused multiply-add changes exact comparisons and is not
a valid peephole transformation without a distinct semantic permission in the IR.
The native regression corpus covers cancellation-sensitive float32/float64
expressions; encoder tests cover stack and register operands on all ARM64 formats.

## Recognize targets

Package composition recognizes `macos-arm64`, `macos-x64`, `linux-arm64`,
`linux-x64`, `windows-arm64`, and `windows-x64`. It combines common modules
with an OS-level `Platform/<OS>/Module/` root and an optional exact
`Target/<target>/Module/` root. Recognizing and analyzing a target does not
claim that its native backend is implemented.

| Target | Machine backend | Native status |
| --- | --- | --- |
| `macos-arm64` | ARM64 | verified and distributed |
| `macos-x64` | X64 | verified and distributed by the native Intel release job |
| `linux-arm64` | ARM64 | verified and distributed by the native ARM64 release job |
| `linux-x64` | X64 | verified and distributed |
| `windows-arm64` | ARM64 | verified and distributed by the native Windows ARM64 release job |
| `windows-x64` | X64 | verified and distributed |

The target model records machine, system ABI, object, executable, runtime, and
boundary-linking capabilities separately. Sharing an ARM64 or X64 instruction
encoder therefore never makes another OS/architecture pair executable by
implication. `silex targets` lists recognized composition targets; native
commands still reject a target whose executable capability is incomplete.

## Allocation scope and remaining qualification

The allocation audit below describes native Silex 0.47.0
(`65cce7f30a9f727b08706b57fc08d91cd4bbd313`). It concerns generated programs,
not the Zig allocator used by the compiler process. The source contract stays
common; the mechanism and performance evidence do not.

| Target | Dynamic allocation mechanism | Small-allocation heap change in 0.47.0 |
| --- | --- | --- |
| `macos-arm64` | libSystem `calloc` / `free` | implemented; bounded local CCD diagnostic |
| `macos-x64` | Darwin `mmap` / `munmap` | not implemented; benefit not measured |
| `linux-arm64` | Linux `mmap` / `munmap` | not implemented; benefit not measured |
| `linux-x64` | Linux `mmap` / `munmap` | not implemented; benefit not measured |
| `windows-arm64` | `VirtualAlloc` / `VirtualFree` | not implemented; benefit not measured |
| `windows-x64` | `VirtualAlloc` / `VirtualFree` | not implemented; benefit not measured |

The owning paths are [ARM64 allocation](../Toolchain/Sources/Arm64/Allocation.zig),
its [system heap adapters](../Toolchain/Sources/Arm64/SystemHeap.zig), and
[X64 emission](../Toolchain/Sources/X64/Encoder.zig) (`emitAllocation`,
`emitRuntimeAllocateCallback`, and `emitRuntimeReleaseCallback`). The other
five paths still request virtual-memory regions for dynamic allocations. The
same kind of cost is therefore a relevant hypothesis there, not an established
speedup and not a justified non-applicable case.

The pending Windows implementation routes both architectures through UCRT
`calloc`/`free`. ARM64 shares its preserving adapters with Darwin; X64 uses
[Windows system heap adapters](../Toolchain/Sources/X64/SystemHeap.zig) that
preserve scratch GPRs and all 128-bit SSE lanes around the platform call.
Classes, strings, collections, deep-copy and cycle callbacks use the same
allocation/free pair. This is not part of the pinned 0.47.0 table: native
Windows qualification and paired measurements gate its publication. Linux and
macOS X64 still use their existing mapping paths.

The next allocator slice must compare equivalent fixed work against a pinned
baseline on each affected target, preserving zero initialization, alignment,
allocation-failure behavior, ownership headers, copy/cycle callbacks, and ABI
register preservation. Select the appropriate system adapter or shared policy
from that evidence; do not assume that importing Darwin's mechanism is portable.
Keep semantic regression tests separate from timings and resource measurements.

[HeapAllocation.sx](../Tests/Native/HeapAllocation.sx) checks repeated string and
collection allocations and detached snapshots. The release scripts now invoke
[QualifyHeap.mjs](../Toolchain/Tools/QualifyHeap.mjs) on every native target in
addition to [DistributionSmoke.sx](../Tests/Native/DistributionSmoke.sx). The
allocation gate executes the fixture's test, the shared native portability
tests (including class, deep-copy and cycle paths), and the fixed-work entry
point in Debug and Release. Its twelve Release samples retain the observable
checksum, compiler/executable/source hashes and host identity in a JSON report.
Timing does not decide correctness or claim parity.

From the common workspace root, a paired diagnostic accepts an optional pinned
baseline compiler as its final argument:

```sh
node Silex/Toolchain/Tools/QualifyHeap.mjs \
  Silex/Toolchain/zig-out/bin/silex /private/tmp/heap-candidate macos-arm64 \
  /absolute/path/to/pinned-baseline/silex
```

Both compilers execute the same current fixture, without compilation during
sampling, in alternating order. Compare only the same target and host; process
startup is included and min/median/max are descriptive, not a statistical
non-regression proof. The manual `heap-qualification.yml` workflow records the
same proof for an immutable published compiler on any of the six native hosts.
With `candidate=true`, it first cross-builds the exact workflow commit, then
executes that candidate and the pinned public baseline on the selected native
host. Cross-building is not the execution proof: both correctness and timing
come from the subsequent native job.
Neither wiring the gate nor recording the 0.47.0 baseline closes the five
unimplemented heap paths listed above.

This limitation does not narrow unrelated shared transformations. For example,
[aggregate-load optimization](../Toolchain/Sources/Optimize/AggregateLoads.zig)
runs in the shared Release pipeline before target code generation; its scope
is not determined by the host used to measure it.

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
an assembler or `codesign`. A process entry executes exactly once in its own
address space, so it does not allocate the snapshot lock used to serialize
repeated in-memory runner invocations. Programs without mutable globals can
therefore omit the writable data segment entirely.

Dynamic storage on macOS ARM64 uses libSystem `calloc` and `free`, including
strings, collections, classes, and the allocation callbacks passed to the
embedded copy and cycle runtimes. Zero initialization and the existing ownership
headers are preserved. Two private adapters preserve the generated code's
scratch registers, Silex status register (`x8`), and full SIMD values across the C calls;
the platform-reserved `x18` is left untouched. This avoids mapping and unmapping
a virtual-memory region for each small allocation.

These runtime imports belong to the encoded image, not portable IR. Both the
direct Mach-O writer and the relocatable-object writer include them, and the
in-memory native test runner resolves the same allocator. Images without
allocation retain their original imports. Other OS and architecture allocation
paths are unchanged.

## Emit macOS X64 programs

The macOS X64 backend shares the X64 instruction encoder with Linux and
Windows while selecting a Darwin runtime and the System V register and stack
rules required by the Apple C ABI. Internal Silex calls remain private to the
backend; named and indirect package boundaries are lowered separately to C
calls, including integer and floating-point arguments beyond the available
registers.

Release programs without a native package boundary are written directly as
x86_64 Mach-O executables with `LC_MAIN`, a macOS 13 minimum version, separate
text and data segments, and an ad-hoc SHA-256 code signature. Debug programs
and builds that reference a package archive use x86_64 Mach-O objects,
PC-relative data and branch relocations, and the bootstrap Zig linker. The
embedded float formatting, deep-copy, and cycle-collection helpers are built
as x86_64 Mach-O runtime inputs rather than reusing their ELF images.

The `macos-15-intel` native-portability job builds the compiler with the
official x86_64 Zig archive, installs the private linker and universal
Shadercross asset into a clean home, verifies the asset's x86_64 slice, and
executes `setup`, `compile`, `run`, `test`, direct emission, linked emission,
and a package boundary on an Intel host. Rosetta executions are useful local
diagnostics but are not the target's native verification gate.

## Link native package boundaries

For a referenced package-private provider, the compiler writes a relocatable
object for the selected target: ARM64 or X64 Mach-O, x64 or AArch64 ELF, or
x64/ARM64 COFF. On macOS, the managed Zig linker runs without its automatic
standard libraries; Silex supplies `libSystem` and Apple's granular target
runtime explicitly. Platform availability helpers are therefore resolved
without pulling Zig's monolithic compiler-rt math implementations. Other
systems keep the regular managed Zig bootstrap link. Both paths receive only
the resolved package archives, declared Apple frameworks, and named system
libraries. Provider archives are production artifacts and must not retain
sanitizer-runtime dependencies. These paths do not compile foreign sources and
do not define a stable Silex object format or ABI.

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

## Emit Linux ARM64 programs

The Linux ARM64 backend shares the private ARM64 machine convention while
owning a distinct AArch64 system boundary. Direct builds write an `EM_AARCH64`
ELF64 executable; package Boundary builds write an AArch64 relocatable ELF
object with `CALL26`, page, and low-page relocations before invoking the native
Zig linker. Linux service calls use `x8` and `svc #0`, including output,
mapping, unmapping, time, random seed, process identity, exit, and the internal
recursive mutex.

The float formatting, deep-copy, and cycle-collection runtimes are embedded as
linked AArch64 ELF payloads. Deep-copy receives AAPCS64 allocation and release
callbacks emitted by the Linux backend, so its memory boundary uses the same
checked system-call stubs as generated Silex code. The payloads' complete
relative load-segment layout and page congruence are preserved inside the
generated image, so their internal PC-relative references do not leak into the
Silex machine IR or enclosing object format.

`silex setup` installs the native AArch64 Zig linker on this host. Shadercross
has no upstream native Linux ARM64 archive yet and is deliberately not replaced
with an emulated X64 tool; full GFX support remains outside this backend slice.
The `ubuntu-24.04-arm` portability job verifies the real host architecture,
Debug and Release against the interpreter, the common native corpus, package
Boundary calls and the clean-home setup path.

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
writable until PE emission gains a distinct data section. Windows X64 and
Windows ARM64 are verified by the native portability workflow. A Linux X64
support job cross-builds the ARM64 compiler and Boundary provider as an
ephemeral workflow artifact. The `windows-11-arm` job checks their PE/COFF
machine `0xaa64`, executes the compiler and every Debug and Release program
natively, and verifies the declared Windows X64 setup tools under the system
compatibility layer. The Boundary callback crosses the Windows ARM64 C ABI.
The release workflow also distributes and installs the Windows ARM64 archive;
its distribution smoke is distinct from the broader portability corpus above.

## Lower the built-in macOS boundary

The `macos-arm64` target can lower one verified C ABI contract declared in
Silex as `MacOS.lib_system.write`. After portable composition, the target maps
it to its internal Darwin provider and emits the `libSystem` load command,
`_write` symbol, binding stream and GOT directly. Only the typed `Interop`
declaration is exposed to binding authors; the target mechanism does not
change the language's internal calling convention.
