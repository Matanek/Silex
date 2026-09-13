# Experimental LLVM evaluation

The `llvm-evaluation` Zig build step installs a separate development executable,
`silex-llvm-evaluation`, into the explicitly chosen prefix. The ordinary `silex`
command and default installation do not select or depend on LLVM. This is a
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

`verify.py` accepts `--native`, `--adapter`, `--shadercross`, `--llvm-dir`, `--sdk`,
`--output-dir`, and `--report`. It compares exact stdout, stderr, and exit status in native Debug,
native Release, LLVM O0, and LLVM O3; it also checks the interpreter on bounded
cases, unsupported source forms, cache reuse/repair, and native/LLVM/native runs.

## Current semantic boundary

Numeric operations, branches, calls, plain aggregates, scalar/aggregate references,
plain-value collections, resource-free optionals, and immutable string literals
cover the selected corpus.
Enumerations whose variants have neither payload nor raw value use an internal
integer tag; construction, variant tests and equality are covered. Payload and raw
enumerations remain explicit refusals.
Optional construction, extraction, copies, parameters, results, local storage and
equality use the explicit presence tag; equality ignores the payload when both
values are absent. Floating operations have no fast-math permissions, and machine
contraction is disabled. Overflow and division errors preserve standalone failure
status; collection bounds and checked conversions preserve source-position
diagnostics and output emitted before failure.

Plain owning collections use heap storage with a reference-count header. Retains
and drops are emitted from composed IR, and `collection_replace` consumes the old
owning root when it creates replacement storage. The same private allocation
foundation now covers exact, non-inherited classes whose fields are only numeric
or boolean: class values stay opaque pointers while a separate private storage
type drives allocation, field loads and field stores. A store mutates that private
storage and returns the same opaque class pointer, while the retain/drop operations
already present around the instruction retain responsibility for ownership. Their
root count starts at zero, matching the native IR contract, and explicit root
retains/drops control reclamation.

This class subset accepts a drop only when its exact static plan contains solely
provably empty finalizers. Effective finalizers, resource fields, inheritance,
edge ownership and cycles remain explicit refusals; this is not a substitute for
the native object graph collector. String literals use the native-style
mono-pointer descriptor: an explicit byte length followed by the exact bytes,
without using a trailing zero as value data. Their descriptors are private and
static, so string retain/drop recognize them without allocating or freeing.
Content equality, Unicode scalar count, calls, returns and output preserve empty,
UTF-8 and embedded-zero values. Dynamic string construction, interpolation and
concatenation remain explicit refusals. Capture-free function references can expose
their internal symbol address through the explicit `C.function_address` bridge;
capturing closures and indirect calls remain refused. Other non-integer globals, package
providers, and mutable views requiring owning storage detachment are also still
rejected. A live-allocation counter checked after normal return makes leaks fail
validation, including both collection replacement and the optional-class witness.
This counter is part of the prototype cost; it is not a production GC design.

The cache lives under the group's single `.silex/llvm-evaluation/v1` root. Keys
include emitted IR, source identity, adapter and driver hashes, LLVM and linker
hashes, SDK settings/stubs, CPU, and optimization mode. Cache hits validate the
executable hash. Native artifacts use their existing independent namespace.

Reports retain the composed-IR adapter's internal timings, object optimization,
code generation, linking, end-to-end time, executable size, and child peak RSS.
Virtual-register lowering and textual LLVM serialization are currently one
measured interval; they must not be reported as independently measured costs.
Python process monitoring adds overhead to each stage and is included explicitly.
No timing assertion belongs to the correctness tests.
