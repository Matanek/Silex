# Compiler architecture

The shared frontend and reference path are:

```text
Silex source
    -> lexer
    -> parser and AST
    -> module index and referenced module closure
    -> package graph and typed module interfaces
    -> semantic composition and typed lowering
    -> typed Silex IR
    -> reference interpreter
```

The first native path branches only after the typed IR:

```text
typed Silex IR
    -> macos-arm64 lowering
    -> ARM64 machine IR
    -> direct AArch64 instruction encoding
    -> direct Mach-O executable emission and ad-hoc signature
    -> native executable
```

A program that actually calls a package-private native provider takes a second
bootstrap path after instruction encoding:

```text
ARM64 encoded image
    -> relocatable Mach-O object
    -> target-matched package archives, frameworks, and system libraries
    -> bootstrap system linker
    -> native executable
```

The choice and linker inputs come from the resolved package graph. They remain
toolchain data and never enter portable IR or the consuming application's
manifest.

The editor path reuses the same source contracts without exposing compiler
internals through LSP:

```text
open Silex document
    -> full-document synchronization
    -> current lexer, parser and semantic analysis
    -> LSP diagnostics
    -> context and inferred syntactic intention
    -> typed frontend declarations and package graph
    -> prioritized completion from visible declarations
    -> definition navigation to module and package sources
    -> inline colors for direct GFX.Color expressions
```

## Current decisions

- The established Silex syntax is input to the project, not something to
  redesign incidentally while building the backend.
- Zig 0.16 is a bootstrap implementation detail.
- The compiler never generates C or C++.
- The textual IR is deterministic so tests can treat it as an observable
  artifact without declaring its serialization stable.
- IR functions and values use structured numeric identities. Source names
  remain available for diagnostics and readable IR, but calls do not rely on
  linker symbols.
- Portable functions are control-flow graphs of explicit blocks. Every block
  ends in a branch, jump, return, or fatal terminator; target-dependent
  fallthrough semantics never enter the frontend.
- Mutable locals are abstract typed storage in portable IR. Reads and writes
  do not expose an address or reference; target lowering alone chooses stack
  slots. `while`, `break`, and `continue` are ordinary CFG branches and
  backedges before they reach the machine backend.
- A `mutex` block lowers to paired portable `mutex.lock` and `mutex.unlock`
  effects. Semantic control-flow cleanup inserts unlocks before every exit;
  target lowering owns the process-wide recursive lock representation.
- Nominal structures and structural tuples remain typed aggregates in portable
  IR. Construction records one typed value per element and reads select
  elements by structured indices; source code never observes an address,
  offset, layout or copy machine operation. Calls, returns, local storage and
  recursive equality preserve value semantics in the reference interpreter and
  native backend.
- Class roots lower to typed retain and finalization operations. Their runtime
  representation, unique-finalization guard, cycle handling and target layout
  remain private to the interpreter and target lowering; source code observes
  only shared identity and the specified `drop` order.
- Generic nominal declarations are specialized before semantic lowering. One
  deterministic concrete declaration represents each complete argument list
  across modules, aliases and reexports; generic classes therefore reach the
  IR as ordinary distinct class identities with concrete bases, fields,
  methods, static storage and finalizers. Template bookkeeping and generated
  names remain compiler details rather than runtime or source APIs.
- Protocol declarations keep a nominal identity through module composition,
  aliases and reexports. Semantic analysis validates each explicitly declared
  conformance against exact public instance signatures, including inherited
  class methods and conformances. Dynamic protocol values lower to explicit
  typed erasure, discriminant tests and payload extraction in portable IR.
  Their closed-program discriminant and inline payload layout remain private to
  target lowering; no witness table, machine address or calling convention is
  exposed in source.
- A generic parameter may carry one protocol identity through parsing, module
  activation and public interfaces. Specialization validates the selected
  concrete type's nominal or inherited conformance before rewriting the body;
  requirement calls then resolve as ordinary concrete method calls. Static
  generic constraints therefore add no runtime dispatch or representation.
- Type extensions are composed as source-level method providers before generic
  specialization and semantic lowering. Their activation set is derived from
  each source file's transitive `use` closure. Once selected, an extension call
  is an ordinary statically bound typed call; the portable IR and target backend
  gain no extension object, registry, dispatch table or ABI concept. Generic
  extension specializations additionally retain their declaring provider in
  their compile-time identity, so equally named providers cannot alias through
  the specialization cache.
- Protocol conformances introduced by extensions retain their provider and
  activation files through composition and generic specialization. The
  frontend uses that metadata for exact-target constraint checking and dynamic
  erasure, while lowering receives only the closed set of concrete protocol
  payloads needed by the portable IR. No runtime registry or externally visible
  witness-table ABI is introduced.
- Associated enums are portable nominal declarations whose variants carry
  typed positional values. Construction records the enum and variant by
  structured indices; module interfaces expose only the nominal identity and
  variant signatures. Target lowering may choose a tag and payload layout, but
  neither is a source-visible field, conversion, ABI or stable IR format.
- Raw enums keep each validated `int` or `str` literal in the nominal variant
  declaration. The typed `enum.raw` operation is the sole observation path;
  target lowering may cache that scalar beside its private tag, but exposes no
  layout, mutable field or enum/raw conversion to source code.
- Exhaustive expression matches lower their once-evaluated subject to explicit
  variant tests, typed payload extractions and ordinary CFG branches. Every
  branch copies its exact-typed result into the merge value; the portable IR
  does not expose a source tag field or apply an implicit convergence cast.
  A terminal `else` is simply the final CFG destination after the named tests;
  it creates neither a synthetic variant nor a catch-all payload binding.
- Imperative matches reuse the same selection CFG and payload extraction, but
  place ordinary statement blocks at each destination and produce no value.
  Branch terminators connect directly to the surrounding return or loop
  context; continuing branches alone join the post-match block.
- Optional values remain typed in portable IR through explicit `optional.null`
  and `optional.some` instructions. A branch-local presence proof emits an
  internal `optional.unwrap` only on the proven control-flow edge. Target
  lowering currently represents optionals as a presence slot followed by the
  flattened payload, but this layout is an experimental backend detail rather
  than a source ABI or serialized format.
- Conditional optional bindings lower their source, presence comparison and
  extraction directly into the existing CFG. The source stays in the reached
  condition block, while the body-local binding begins with the proven unwrap;
  loop backedges therefore preserve the source language's exact retry,
  `continue`, and `break` evaluation rules.
- Safe member access uses the same pattern at expression granularity: one
  receiver evaluation, a presence branch, ordinary member resolution on the
  unwrapped child, and a flat optional result merged with the absent edge.
  Arguments and mutating write-back live exclusively on the present edge.
- Package manifests locate no source by consumer-provided path. The resolver
  derives canonical local, workspace-link, user-link, and installed locations
  from package identities, builds a single-version dependency graph, and
  enforces direct visibility.
- An exact namespace extension may carry a `suite` installation permission.
  The registry expands only a package explicitly requested by registered name
  with `--suite`, and selects independently released members whose parent
  dependency accepts that exact release. Suite selection adds no
  package-composition dependency and is never inferred from a wildcard.
- In an interactive terminal, registry installation reports lookup, package
  resolution, release acquisition, and installation for transitive
  dependencies and, only when requested, exact suite members. One active line
  updates in place while completed packages remain as durable results. A
  selected package release is processed once across the complete dependency
  and requested suite graph. A failed suite member becomes a durable result and
  does not prevent independent members from being installed. After visiting
  the complete requested suite, the command returns a nonzero status without
  repeating the durable interactive diagnostics. Redirected executions do not
  gain progress output and instead receive one combined failure diagnostic.
- A parent package remains authoritative over every module in its namespace.
  When it and an authorized child package provide the child's exact principal
  module, the parent is canonical and composition fails unless the parent's
  exact extension policy carries `merge`. An enabled merge adds distinct public
  declarations while retaining their package owners; duplicate public names
  and every deeper exact-module collision remain deterministic errors, and
  neither module nor package visibility crosses the boundary implicitly.
- Module interfaces preserve structured declaration identities (owner, module,
  name and complete parameter signature), the required parameter count that
  defines their effective call signatures, public nominal structures, fields,
  and constructor and method signatures. Default expressions remain source
  semantics resolved in their declaring module. Public reexports add a visible
  façade name to these identities without copying declarations or creating
  backend symbols. Transparent type aliases are normalized to the same portable
  type before signatures and IR are built; interfaces retain only their visible
  source name and canonical target. `package` visibility is checked against
  package identity and the declaring package's authenticated extension
  `friend` permission, while `local` is checked against preserved source-file provenance;
  both are removed from public interfaces. Opaque non-public return types remain
  typed without exposing their declarations or members. `public` is checked
  during composition and semantic resolution; none of these visibilities is
  related to Mach-O symbol export or native layout.
- Umbrella catalog contributions are discovered only in an active child
  package's portable principal module. The parent manifest authenticates each
  open catalog, and composition accepts only public reexports whose declaration
  provider is owned by that child. Conflicting aliases or child namespaces are
  rejected deterministically. Contributions become ordinary typed reexport
  bindings before semantic lowering; they inject no declarations, executable
  code, runtime registry or backend concept into the parent module.
- The composer resolves all calls and assigns deterministic `FunctionId`
  values before native lowering. The backend receives one portable IR program
  and knows nothing about manifests, package paths, or source visibility.
- The reference interpreter checks integer arithmetic and is the semantic
  oracle for native backends. Differential tests compare its results and
  exact observable output, exit status, and runtime diagnostics with generated
  ARM64 executables.
- Text interpolation lowers through one typed value-to-`str` IR operation and
  ordinary immutable concatenation. It shares its canonical formatting with
  `print` without exposing a formatter or allocation surface.
- `print`, `assert`, and `panic` lower as typed effects. Output channels,
  platform descriptors, source-location formatting, and the macOS execution
  boundary remain privileged compiler details and never enter the source API.
- Native strings use an internal descriptor containing an explicit byte length.
  Literals and dynamically concatenated values share that representation and
  can cross Silex calls without adopting a C ABI, a terminating zero, or a
  linker-visible symbol. Dynamic storage is process-lived in this first runtime
  model; allocation remains invisible to source code.
- Decimal float formatting is a self-contained ARM64 runtime payload built with
  the Zig bootstrap and bundled into the compiler. Native emission copies it
  only when a program prints a float, patches a direct internal call, and never
  resolves a C library or user symbol.
- `main` is the only source name with entry-point semantics. It remains local
  to its physical source: the composer retains it only when that exact file is
  the explicit entry and excludes every other `main` before semantic analysis
  and portable IR construction. It is never a public module declaration.
  Other function names are chosen freely by the user.
- Test blocks are source-local root declarations activated only by `silex test`
  for each exact physical source selected directly or through directory
  discovery. Their entries and lexical helper functions are removed before
  ordinary semantic analysis and portable IR construction; they never enter a
  module interface or ordinary executable. On a macos-arm64 host, test
  compilation lowers each selected source once and emits an isolated native
  process entry for every block, including the active system boundaries.
- Package composition recognizes `macos-arm64`, `linux-x64`, `windows-x64`,
  and `windows-arm64`. It combines common modules with an OS-level
  `Platform/<OS>/Module/` root and an optional exact `Target/<target>/Module/`
  root. Recognizing and analyzing a target does not claim that its native
  backend is implemented.
- The complete initial backend targets `macos-arm64`. It uses an internal
  register-and-stack ABI, places every IR value in a deterministic stack slot,
  and reports checked arithmetic failures through an internal status register.
  The first eight scalar arguments use target registers and additional scalar
  or aggregate arguments use aligned outgoing stack slots; source arity is not
  capped by the register count.
- Native structure lowering flattens fundamental leaves into private stack-slot
  spans. Aggregate arguments use internal addresses and aggregate returns use
  an internal hidden destination; neither convention, nor the flattened layout,
  is observable or stable outside the backend.
- Without a package-native provider, the compiler writes the Mach-O headers,
  load commands, `__text`, entry wrapper, and ad-hoc SHA-256 code signature
  itself. It invokes neither an assembler, linker, nor `codesign` on that path.
- For a referenced package-private provider, the compiler writes a relocatable
  object for the selected target: ARM64 Mach-O, x64 ELF, or x64/ARM64 COFF. It
  then invokes the bootstrap linker with only the resolved package archives,
  declared Apple frameworks, and named system libraries. This path does not
  compile foreign sources and does not define a stable Silex object format or
  ABI.
- Package platform adapters may call a raw function-table entry through
  `C.call<func(...) T>`. Semantic analysis records its checked C signature in
  portable IR, and each native backend lowers the indirect call with the same
  target ABI rules as a named boundary function.
- The Linux X64 backend owns a distinct Silex call convention, encodes X64
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
- The Windows emitters write PE32+ for X64 and ARM64, including deterministic
  import descriptors, lookup tables and IAT entries for `VirtualAlloc` and
  `ProcessPrng`. X64 uses the Win64 boundary registers and ARM64 shares the
  instruction encoder while substituting the Windows allocation boundary. The
  Windows X64 path shares the Linux X64 list, output, stack-argument and
  baseline SSE pair instruction coverage while adapting system calls to
  imported Win32/UCRT functions.
  Package-boundary builds use COFF objects, Win64 or Windows ARM64 C ABI calls,
  and the bootstrap linker with the selected archives and system libraries.
  The X64 bootstrap image likewise keeps its combined code/global section
  writable until PE emission gains a distinct data section. These PE paths are
  structurally tested but are not yet declared verified on Windows hosts.
- The `macos-arm64` target can lower one verified C ABI contract declared in
  Silex as `MacOS.lib_system.write`. After portable composition, the target maps
  it to its internal Darwin provider and emits the `libSystem` load command,
  `_write` symbol, binding stream and GOT directly. Only the typed `Interop`
  declaration is exposed to binding authors; the target mechanism does not
  change the language's internal calling convention.
- The command `silex run <source.sx> [-d|--debug|-r|--release]
  [-n|--nocache]` expresses the intent to execute on the host. It emits a
  private native executable under `.silex/run/`, inherits the terminal streams,
  waits for the program and returns its exit code. Release is the default and
  applies semantics-preserving optimization; `--debug` disables those
  optimizations for backend diagnosis without weakening language safety in
  Release. When the child terminates through a signal, the CLI reports its
  symbolic name and meaning, source, mode, retained executable, no-cache Debug
  reproduction and host debugger command. It identifies native fault owners as
  generated code, embedded runtime or package boundary candidates without
  selecting one before diagnosis.
- `silex interpret <source.sx> [-n|--nocache] [--emit-ir]` explicitly selects
  the reference interpreter. It is intended for semantic validation and cannot
  execute most platform boundaries. `silex compile <source.sx>
  [--target <target>] [-d|--debug|-r|--release] [-n|--nocache]
  -o|--output <executable>` emits at a caller-selected path without running it.
- In an interactive terminal, native compilation reports intention-level
  progress through analysis, target preparation, executable construction,
  platform linkage, output publication, and launch. The progress channel is
  disabled when standard error is not a terminal, preserving quiet successful
  execution for scripts and CI. An ANSI-capable terminal clears successful
  progress when the operation completes but retains it when compilation fails.
- Release propagates constants and copies across the control-flow graph. It
  promotes profitable, non-addressed integer and boolean locals to SSA values,
  constructs join values, removes trivial joins, lowers the remaining parallel
  edge transfers, and prunes unreachable blocks. Promotion is deliberately
  skipped when several live joins would add control-flow work; those locals
  remain candidates for the native global allocator instead. Floating-point
  recurrences retain their local identity for scalar and SLP lane allocation.
  These decisions are automatic and require no source annotation.
- Release inlines direct callees under a bounded cost across branches, loops,
  and multiple returns, in addition to constant-result and small straight-line
  specialization. It then re-runs scalar aggregate replacement, propagation,
  dead-code elimination, dense-block reuse, and bounds analysis on the combined
  graph. In call-free functions containing a proven repeated scalar collection
  read, it reuses the corresponding local, field and collection loads within
  each basic block until an aliasing write. It also marks a
  collection load as bounded when a zero-origin induction variable is dominated
  by the exact collection-count comparison and cannot advance before that load;
  every unproved access retains its runtime bounds diagnostic.
- Native Release lowering performs deterministic CFG-wide liveness and graph
  coloring for compatible scalar functions on ARM64 and X64. Copy-affinity
  components and destructive arithmetic are coalesced globally. ARM64 colors
  scalar floating-point values and proven SLP lanes in the shared SIMD register
  class, then realizes profitable `float32` pairs with baseline NEON. X64
  independently selects the same portable pairs for baseline SSE on both
  System V and Win64, reserves only volatile XMM registers, and keeps their
  scalar stack slots synchronized as a correct fallback for unselected or
  unsupported operations. AVX is not selected until target features can prove
  it is legal. Addressable values, unsupported aggregates, and values that
  cross unsupported machine operations remain explicit spills. Empty SSA edge
  transfers are bypassed after allocation, and the ARM64 collection cursor
  recognizes induction updates separated by independent SSA copies. Fully
  resident leaf functions allocate no value frame. Debug retains the direct
  stack-resident lowering.
- Source-compiling commands root their private cache at
  `<invocation-cwd>/.silex/cache`. Content-addressed, versioned entries persist
  module ASTs, portable typed IR, complete native inputs with their boundary
  providers, Release and machine functions that are safe to reuse
  independently, and mode-specific linked executables. Exact source and
  boundary-archive contents are re-hashed before reuse; corrupt or unavailable
  entries are misses, and atomic publication prevents readers from observing
  partial data. Native images use target-specific Mach-O, ELF or PE cache
  kinds.
  `-n` and `--nocache` bypass reusable compilation entries. `run` still writes
  its private executable under `.silex/run/`; the option forces rebuilding it
  and does not change the command's output location.
- The command `silex lsp` speaks framed JSON-RPC over standard input and
  output. Its public capabilities describe editor intentions; AST and IR
  structures remain private implementation details.

## Current limits

- Executable values include every historical integer width, `float32`,
  `float64`, `bool`, `str`, and `void`.
- Conditions, short-circuit boolean expressions, mutable locals, checked
  arithmetic updates, and `while` loops with `break` and `continue` are
  implemented.
- Nominal structures can be declared, initialized, read, copied, passed,
  returned and compared recursively in both the reference interpreter and the
  macOS ARM64 backend. Mutable field paths are lowered by rebuilding portable
  value aggregates and preserve independent copies. Public structures compose
  across modules and packages. Constructors lower to internal IR functions
  returning a fully initialized value; definite initialization is established
  before that lowering and exposes no receiver ABI.
- Method mutability is a fixed point over writes through `self` and the method
  call graph. Nonmutating methods lower as value-receiver functions. Mutating
  methods return updated receiver state internally; when they also return a
  source value, a private typed IR aggregate carries both results. The caller
  writes the receiver component back to its abstract place, so no reference,
  address or receiver convention enters the language contract.
- String concatenation currently retains its native storage until process exit;
  reclamation and a general allocation model remain future internal work.
- No public system API or general native allocation API exists yet.
- The native backend has no debugging information, general dynamic-library
  model, public source-level external declarations, or ABI stability guarantee
  yet. Besides the closed system contracts, `macos-arm64` supports typed C ABI
  calls owned privately by a package that declares its static provider.
- Native executable emission and native tests currently require an Apple
  Silicon macOS host.
- Interfaces, IR and package graphs are in-memory structures and have no stable
  serialized format yet.
- LSP syntax diagnostics always analyze the open buffer; semantic diagnostics
  currently run only when the unit has no `use`. Completion independently
  resolves the project module index and direct package graph, with open buffers
  masking their disk providers. Definition navigation uses the same target and
  overlay-aware project view for imported or directly qualified module and
  package declarations. It follows methods declared by extensions, qualified
  call return types, destructured query bindings, field chains and cascades
  when their imported receiver type can be inferred. Bare function values
  resolve to declarations in the current source or through explicit imports,
  so callbacks navigate like direct calls. The bootstrap rebuilds that editor
  view for each request; an
  incremental cache remains a performance optimization and must preserve the
  same observable results. Document colors recognize direct
  `Color.bytes`, `Color.rgb`, `Color.rgba` and named GFX palette expressions
  whose components are literals in the displayable `[0.0, 1.0]` range. This
  bootstrap recognition is intentionally syntactic; semantic constant
  evaluation should eventually replace its local palette knowledge so aliases
  and computed colors work without coupling the language server to one package
  API. References, rename, hover, formatting, semantic tokens and project-wide
  semantic diagnostics are not implemented yet.
