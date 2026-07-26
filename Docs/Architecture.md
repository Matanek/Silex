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
    -> syntax-aware completion from current declarations
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
- Package manifests locate no source by consumer-provided path. The resolver
  derives canonical local and global locations from package identities, builds
  a single-version dependency graph, and enforces direct visibility.
- Module interfaces preserve structured declaration identities (owner, module,
  name and parameter signature). `public` is checked during semantic call
  resolution; it is unrelated to Mach-O symbol export.
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
- Conditions and short-circuit boolean expressions are implemented. Loops,
  mutable variables and assignment are not.
- String concatenation currently retains its native storage until process exit;
  reclamation and a general allocation model remain future internal work.
- No public system API or general native allocation API exists yet.
- The native backend has no symbols, debugging information, dynamic imports,
  library model, or ABI stability guarantee yet.
- Native executable emission and native tests currently require an Apple
  Silicon macOS host.
- Interfaces, IR and package graphs are in-memory structures and have no stable
  serialized format yet.
- The first LSP analyzes an open buffer as one autonomous source unit. Syntax
  diagnostics always run; semantic diagnostics currently run only when the
  unit has no `use`. Package graph overlays, navigation, rename, hover,
  formatting and semantic tokens are not implemented yet.
