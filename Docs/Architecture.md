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
  runtime-error categories with execution of the generated ARM64 instructions.
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

## Current limits

- Executable values are limited to `int`, `bool`, and `void`.
- Function bodies are linear: no conditions, loops, mutable variables or
  assignment yet.
- `float`/`float32` and `str` remain available in parsed signatures, but their
  values and operations are not executable yet.
- No allocation, heap-managed value, system API, or general runtime yet.
- The native backend has no symbols, debugging information, dynamic imports,
  library model, or ABI stability guarantee yet.
- Native executable emission and native tests currently require an Apple
  Silicon macOS host.
- Interfaces, IR and package graphs are in-memory structures and have no stable
  serialized format yet.
