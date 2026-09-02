# Compiler architecture

This contributor-facing page documents the Silex compiler's internal pipeline,
implementation decisions, and backend limits. Public language and tool
documentation is maintained in the
[Silex-Documentation repository](https://github.com/Matanek/Silex-Documentation).

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
    -> closure from the selected native entry points
    -> Release optimization, or direct Debug lowering
    -> shared machine IR lowering
    -> target instruction encoding
    -> Mach-O, ELF or PE emission
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

## Architecture rules

These rules keep source semantics independent from the bootstrap implementation
and native targets:

- The established Silex syntax is input to the project, not something to
  redesign incidentally while building the backend.
- Zig 0.16 is a bootstrap implementation detail.
- The compiler never generates C or C++.
- The textual IR is deterministic so tests can treat it as an observable
  artifact without declaring its serialization stable.
- IR functions and values use structured numeric identities. Source names
  remain available for diagnostics and readable IR, but calls do not rely on
  linker symbols.

## Explore the compiler

Choose the subsystem that matches the question you are investigating:

- [Portable semantics](Portable-semantics.md): control flow, values, generics,
  protocols, enums, matches, and optionals before target lowering.
- [Modules and packages](Modules-and-packages.md): source roots, source atoms,
  package graphs, namespace ownership, visibility, suites, and catalogs.
- [Composition and runtime effects](Composition-and-runtime.md): closed-program
  assembly, interpreter comparisons, strings, output, entry points, and tests.
- [Native code generation](Native-code-generation.md): target status, object
  formats, internal calling conventions, package boundaries, and system ABIs.
- [Command-line compilation](Command-line-compilation.md): `run`, `interpret`,
  `compile`, Debug diagnostics, and interactive progress.
- [Release optimization](Release-optimization.md): portable IR simplification,
  inlining, bounds analysis, register allocation, and SIMD selection.
- [Cache and editor tooling](Cache-and-editor-tooling.md): reusable compilation
  artifacts and the LSP boundary.
- [Implementation status](Implementation-status.md): portable coverage and the
  runtime, native, serialization, and editor limits that remain.
