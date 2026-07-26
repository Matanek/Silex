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
- Package manifests locate no source by consumer-provided path. The resolver
  derives canonical local and global locations from package identities, builds
  a single-version dependency graph, and enforces direct visibility.
- Module interfaces preserve structured declaration identities (owner, module,
  name and complete parameter signature), the required parameter count that
  defines their effective call signatures, public nominal structures, fields,
  and constructor and method signatures. Default expressions remain source
  semantics resolved in their declaring module. `public` is checked during
  composition and semantic resolution; it is unrelated to Mach-O symbol export
  or native layout.
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
