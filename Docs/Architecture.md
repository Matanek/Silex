# Compiler architecture

The shared frontend and reference path are:

```text
Silex source
    -> lexer
    -> parser and AST
    -> module index and explicit use closure
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
    -> direct Mach-O emission and ad-hoc signature
    -> native executable
```

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
- Nominal structures are portable IR declarations. Construction records one
  typed value per declared field and reads select fields by structured indices;
  source code never observes a tuple, address, offset, layout or copy machine
  operation. Calls, returns, local storage and recursive equality preserve
  value semantics in the reference interpreter and native backend.
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
  derives canonical local and global locations from package identities, builds
  a single-version dependency graph, and enforces direct visibility.
- Module interfaces preserve structured declaration identities (owner, module,
  name and complete parameter signature), the required parameter count that
  defines their effective call signatures, public nominal structures, fields,
  and constructor and method signatures. Default expressions remain source
  semantics resolved in their declaring module. Public reexports add a visible
  façade name to these identities without copying declarations or creating
  backend symbols. Transparent type aliases are normalized to the same portable
  type before signatures and IR are built; interfaces retain only their visible
  source name and canonical target. `internal` is checked against preserved
  source-file provenance and is removed from interfaces; opaque internal return
  types remain typed without exposing their declarations or members. `public`
  is checked during composition and semantic resolution; neither visibility is
  related to Mach-O symbol export or native layout.
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
- `main` is the only source name with entry-point semantics. Other function
  names are chosen freely by the user.
- The initial backend targets only `macos-arm64`. It uses an internal
  register-and-stack ABI, places every IR value in a deterministic stack slot,
  and reports checked arithmetic failures through an internal status register.
- Native structure lowering flattens fundamental leaves into private stack-slot
  spans. Aggregate arguments use internal addresses and aggregate returns use
  an internal hidden destination; neither convention, nor the flattened layout,
  is observable or stable outside the backend.
- The compiler writes the Mach-O headers, load commands, `__text`, entry
  wrapper, and ad-hoc SHA-256 code signature itself. It does not produce an
  object file or invoke an assembler, linker, or `codesign`.
- The command `silex run <source.sx>` uses the reference interpreter.
  `silex compile <source.sx> -o <executable>` selects the native path.
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
- The native backend has no symbols, debugging information, dynamic imports,
  library model, or ABI stability guarantee yet.
- Native executable emission and native tests currently require an Apple
  Silicon macOS host.
- Interfaces, IR and package graphs are in-memory structures and have no stable
  serialized format yet.
- LSP syntax diagnostics always analyze the open buffer; semantic diagnostics
  currently run only when the unit has no `use`. Completion independently
  resolves the project module index and direct package graph, with open buffers
  masking their disk providers. The bootstrap rebuilds that completion view for
  each request; an incremental cache remains a performance optimization and
  must preserve the same observable results. Navigation, rename, hover,
  formatting, semantic tokens and project-wide semantic diagnostics are not
  implemented yet.
