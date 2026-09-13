# Experimental LLVM evaluation

The `llvm-evaluation` Zig build step installs a separate development executable,
`silex-llvm-evaluation`, and its exact scalar-formatting object,
`lib/silex-llvm-format.o`, into the explicitly chosen prefix. The ordinary `silex`
command and default installation do not select or depend on either artifact. This is a
bounded macOS ARM64 experiment, not a distributed backend or a migration decision.

The adapter uses `Project.Compiler` for package resolution and typed composition,
then `ProgramScope.executable` and the IR verifier. It does not run the Silex
Release optimizer or native lowering. The audited virtual-register lowering from
`Tools/OptimizerOracle/LlvmValues.zig` supplies homes for multiply-defined values;
LLVM performs the subsequent promotion and optimization. The experimental emitter
is a separate fork so the oracle's coverage and lifetime guards remain unchanged.

Internal Silex calls use LLVM `fastcc`, including aggregate arguments and results.
The system entry point and `malloc`, `free`, `dprintf`, and `exit` calls are explicit
system boundaries. No C/C++ source, Clang frontend, JIT, or native Silex function is
mixed into the executable. `opt` and `llc` produce an object, and the system linker
produces the executable.

## Run the experiment

Build the `llvm-evaluation` step from `Toolchain/` with the chosen cache directories
and private install prefix. Run compilation and validation from the containing
workspace or Spec Worktree group root. All inputs and tool locations are explicit:

```sh
python3 Silex/Toolchain/Tools/LlvmEvaluation/compile.py \
  --backend llvm \
  --source Silex/Toolchain/Benchmarks/Optimizer/LlvmEvaluation/SteeringWorkload.sx \
  --adapter Tools/Adapter/bin/silex-llvm-evaluation \
  --format-runtime Tools/Adapter/lib/silex-llvm-format.o \
  --shadercross Tools/Shadercross/install/bin/shadercross \
  --silex-prefix none \
  --llvm-dir Tools/LLVM-21.1.8 \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
  --opt O3 --output Evaluations/SteeringWorkload-O3
```

The tool requires macOS ARM64; the current target is macOS 26 with the 26.5 SDK,
an explicit Shadercross executable and an explicit CPU selection (default
`apple-m3`). The Shadercross path lets package composition compile HLSL without
reading a user-global toolchain installation, and its digest participates in the
cache key. The tool never falls back to the native backend. Unsupported IR is
rejected before creating LLVM output, and a failed stage does not replace an
existing executable.

`--silex-prefix` defaults to `none`. A named internal `ReleaseOptimizer` pass
selects the cumulative prefix ending at that pass. This is an attribution control
for determining which Silex canonicalizations remain necessary before LLVM; it is
not a public optimizer switch or permission to enable the full Release pipeline.
The full prefix is also an explicit diagnostic comparison for Boids and Physics.
Virtual-register normalization reloads raw-memory addresses and byte offsets
after control-flow merges, including loop-carried values produced by the Silex
passes. `MergedRawMemory.sx` exercises both operands through loads and stores
with the full prefix in LLVM O0 and O3.
The adapter also accepts the analysis-only option `--closure-report REPORT.json`
after `--silex-prefix` (`--boundary-report` remains a compatibility alias). Once
the closed program verifies, it records direct package boundaries and global
values referenced by functions reachable from `main`, with typed signatures,
initialization modes and use-site counts. Producing this report does not imply
that the emitter supports every inventoried value. The report also inventories
every reachable instruction kind, its site and function counts, and its current
coverage class (`conditional`, `abstract_lifetime`, or `unsupported`).
`conditional` means that the opcode has an emitter path; its concrete types and
effects can still be rejected later, so these counts are a lower-bound gap
analysis rather than a promise of whole-program emission.

Assertions retain their runtime branch. Failure writes the source path, line,
column and exact string message to stderr after preserving prior stdout, then
terminates with status 1; successful assertions have no observable output.

Direct boundary calls are emitted only when every parameter and result already
has an explicit scalar or address LLVM representation. Void calls carry no
synthetic result. Duplicate declarations must keep the same provider and exact
signature; indirect calls and conflicts remain explicit refusals. Archive and
framework linking is a separate stage and is not inferred by the emitter.

Reachable global values are emitted for statically initialized integers and for
statically absent optionals whose payload already has an explicit LLVM value
representation. An optional is always `{ i1, payload }`; an absent value uses a
false presence tag and a zeroed payload. Class payloads are opaque `ptr` values,
never an exposed field layout. Loads and stores refer to an internal LLVM global
by stable IR index; stores additionally require a mutable declaration. Runtime
initialization and non-optional aggregate initializers remain explicit refusals.

`verify.py` accepts `--native`, `--adapter`, `--format-runtime`, `--shadercross`, `--llvm-dir`, `--sdk`,
`--output-dir`, and `--report`. It compares exact stdout, stderr, and exit status in native Debug,
native Release, LLVM O0, and LLVM O3; it also checks the interpreter on bounded
cases, unsupported source forms, cache reuse/repair, and native/LLVM/native runs.

## Current semantic boundary

Numeric operations, branches, calls, plain aggregates, scalar/aggregate references,
plain-value collections, resource-free optionals, and immutable string literals
cover the selected corpus.
Enumerations without raw values use a private tagged-union representation.
Payload-free enums keep a direct integer tag. Enums with associated values use a
tag followed by an aligned word reserve sized for the widest variant from the
LLVM representation of its payloads. Construction zeroes the reserve before
storing the selected values; variant tests read the tag and payload extraction
loads the requested typed region. Copies remain value copies: ownership retains
and drops stay explicit in the composed Silex IR. Raw enumerations with `int` or
`str` backing use a two-field representation containing the stable variant tag
and the declared raw value. Raw projection reads the second field; matching and
equality compare the tag, while string raw values point to private static
descriptors. Equality for associated-value enums remains an explicit refusal.
Dynamic protocol values likewise use a private tagged reserve: the first word is
the concrete structure index and the aligned payload is sized for the widest
conformer in the composed program. Construction zeroes the reserve, protocol
tests compare the tag, and extraction loads the requested concrete LLVM value.
Class conformers keep their opaque pointer in the payload; classes emitted by
the supported exact-class subset carry their dynamic structure index beside the
reference-count header so erasure does not substitute a static tag. Structure
copies and class identity remain governed by the explicit retain/drop sequence
already present in Silex IR. Protocol conformers outside the currently supported
concrete type and lifetime subsets remain conditional refusals.
Optional construction, extraction, copies, parameters, results, local storage and
equality use the explicit presence tag; equality ignores the payload when both
values are absent. Compiler-only `storage_init` placeholders materialize as a
typed zero constant; definite-initialization analysis guarantees that source code
cannot observe them before the explicit field replacement. A
`reference_optional` projection recovers the pointee type from its local, field,
collection or prior projection provenance and uses a typed LLVM `getelementptr`;
it therefore preserves payload offsets for both narrow and word-aligned optionals
instead of assuming the native stack-slot offset. Floating operations
have no fast-math permissions, and machine
contraction is disabled. Overflow and division errors preserve standalone failure
status; collection bounds and checked conversions preserve source-position
diagnostics and output emitted before failure.

Plain owning collections use heap storage with a reference-count header. Retains
and drops are emitted from composed IR, and `collection_replace` consumes the old
owning root when it creates replacement storage. `append` and `clear` follow the
same rule for dynamic lists of resource-free elements: they allocate exact new
storage, preserve the retained prefix when applicable, then consume the input
root. This intentionally has no spare-capacity optimization in the experiment.
Other edit kinds and resource-bearing elements remain conditional refusals. The same private allocation
foundation now covers exact, non-inherited classes whose fields are only numeric
or boolean: class values stay opaque pointers while a separate private storage
type drives allocation, field loads and field stores. A store mutates that private
storage and returns the same opaque class pointer, while the retain/drop operations
already present around the instruction retain responsibility for ownership. Their
root count starts at zero, matching the native IR contract, and explicit root
retains/drops control reclamation.

Slices of dynamic collections with resource-free elements normalize negative
bounds, clamp both ends and allocate an exact independent owning copy. Inverted
ranges produce an empty owning list. Slices whose elements carry resources and
slice results that remain borrowed views are still refused.

This class subset accepts a drop only when its exact static plan contains solely
provably empty finalizers. Effective finalizers, resource fields, inheritance,
edge ownership and cycles remain explicit refusals; this is not a substitute for
the native object graph collector. String literals use the native-style
mono-pointer descriptor: an explicit byte length followed by the exact bytes,
without using a trailing zero as value data. Their descriptors are private and
static, so string retain/drop recognize them without allocating or freeing.
Content equality, Unicode scalar count, calls, returns and output preserve empty,
UTF-8 and embedded-zero values. Numeric, boolean and string interpolation now
preserve the native rendering; numeric results allocate a dynamic descriptor and
floating-point rendering comes from the explicit object built with the adapter.
Concatenation allocates a dynamic descriptor,
checks both value and allocation-size overflow, and copies the exact bytes without
adding a terminator; operand lifetime remains controlled by explicit IR drops.
`C.string` copies a compact `uint8` view into the same owning descriptor, preserving
UTF-8 and embedded zero bytes. Its semantic result transfers the allocation's
initial root to the consumer, so a stored or immediately consumed conversion emits
exactly the corresponding drop instead of leaking or retaining an extra root.
Byte length masks the descriptor's dynamic
flag, byte access checks the index before reading, and the explicit interop pointer
addresses the first byte after the descriptor header. These byte projections stay
distinct from Unicode scalar count. Capture-free function references can expose
their internal symbol address through the explicit `C.function_address` bridge;
capturing closures and indirect calls remain refused. Other non-integer globals, package
providers, and mutable views requiring owning storage detachment are also still
rejected. Typed raw numeric loads and stores accept either an opaque interop
address or explicit address bits, add their offset in bytes, and use alignment
one so LLVM cannot infer an ABI alignment that the interop contract does not
guarantee. A live-allocation counter checked after normal return makes leaks fail
validation, including both collection replacement and the optional-class witness.
This counter is part of the prototype cost; it is not a production GC design.

The cache lives under the group's single `.silex/llvm-evaluation/v1` root. Keys
include emitted IR, source identity, adapter, formatting runtime and driver hashes, LLVM and linker
hashes, SDK settings/stubs, CPU, and optimization mode. Cache hits validate the
executable hash. Native artifacts use their existing independent namespace.

Reports retain the composed-IR adapter's internal timings, object optimization,
code generation, linking, end-to-end time, executable size, and child peak RSS.
Virtual-register lowering and textual LLVM serialization are currently one
measured interval; they must not be reported as independently measured costs.
Python process monitoring adds overhead to each stage and is included explicitly.
No timing assertion belongs to the correctness tests.

## Mutable views of owning plain collections

A view borrowed from a dynamic owning collection detaches shared storage before
exposing its elements. The same copy-on-write path serves element references and
views, updates the original owner and leaves existing snapshots independent.
Bounds remain clamped, including negative indices and empty slices. This path
currently accepts plain elements; resource-bearing owning-view elements remain
an explicit refusal. `MutableOwningView.sx` covers shared and unique owners,
floating aggregate elements, nested views and empty storage in both native modes
and LLVM O0/O3 with the full Silex prefix.

Direct floating-point `print` uses the same native formatter as interpolation,
including float32/float64, signed zero, infinities and NaN. It writes the scratch
buffer directly, without allocating a temporary owning string. This preserves
the ordinary Physics kernel's field-by-field diagnostic output.

## Scalar minimum and maximum

The `minimum`/`maximum` operations in Silex IR lower to LLVM 21
`llvm.minimumnum`/`llvm.maximumnum`. These intrinsics preserve signed-zero
ordering and return the numeric input when the other input is NaN. An explicit
selection of the original right operand when the left is NaN also preserves
Silex's exact result bits when both inputs are NaNs. No fast-math assumption is
added. See the [LLVM 21.1.8 semantics](https://github.com/llvm/llvm-project/blob/llvmorg-21.1.8/llvm/docs/LangRef.rst#llvmminimumnum-intrinsic).

`ScalarMinMax.sx` compares 576 results bit for bit against the source semantics:
both operations, float32 and float64, all ordered pairs of signed zeros,
subnormals, finite values, infinities, quiet NaNs and signaling NaNs. The LLVM
matrix uses the full Silex prefix and checks that both widths reach the
intrinsic lowering. This targets the cost exposed by `scalar_math_intrinsics`
in the unchanged Physics contact kernel; enabling every Silex pass does not
imply a speedup for an entire application.

## Reusing private collection storage

Owning replacements reuse storage when its root and edge counts sum to one.
Shared storage still detaches before the write, preserving snapshots. Append
uses the same uniqueness condition and grows byte capacity geometrically, so a
sequence of appends no longer copies every prefix. Both operations consume and
transfer the source owner; resource-bearing element transitions remain explicit
in Silex IR. Indexed insertions and removals retain their existing copy paths.

Untyped private allocations now place byte capacity at payload offset -32,
followed by roots (-24), edges (-16) and destruction state (-8). Typed classes
keep their separate native-compatible layout. This is an experimental adapter
detail, with no change to the native backend or public collection API. The live
allocation guard remains enabled. Append checks count and byte-size overflow;
reserve growth falls back to the required size when doubling cannot fit.

`ListGrowth.sx` checks repeated root and edge growth, rich values, shared
snapshots, appending an existing element, replacement, and clear/reuse in native
Debug/Release and LLVM O0/O3 with the full Silex prefix. Existing bounds and
ownership witnesses cover the other edits and finalization.

## Zero ownership counts

The private LLVM counters follow the native release contract. Class construction
starts with zero roots, and dropping an unrooted temporary can still claim its
finalization when no edges remain. Releasing a zero collection ownership count
is a no-op. Both paths use an atomic compare/exchange loop that never wraps zero
to the maximum integer. `RuntimeCounts.ll` exercises these direct runtime
contracts in LLVM O0/O3, including an edge that keeps an unrooted class alive
and a collection transferred from a root to an edge. The ordinary differential
corpus continues to check source-level finalizer order and ownership.
