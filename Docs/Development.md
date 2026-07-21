# Develop Silex

The compiler lives in the standalone Zig project at `Toolchain/`. It currently
requires Zig 0.16 and translates Silex source to C++ before producing native
executables.

```sh
cd Toolchain
zig build
```

The development executable is installed at `Toolchain/zig-out/bin/silex`.

## Verification

```sh
cd Toolchain
zig build test
zig build smoke
zig build cross-smoke
zig build cross-native-smoke
```

`test` runs targeted compiler checks; `smoke` compiles and runs Silex programs.
The cross-platform checks are available when needed, but macOS ARM64 is the
current development target.

Source-quality checks are explicit: `silex lint <source.sx|project.json>` walks
the parsed AST without starting compilation or creating `.silex` artifacts.
Its diagnostics use stable rule codes and are ordered by source path and
position, which keeps command-line and future editor consumers deterministic.

## Build a distributable toolchain

```sh
cd Toolchain
zig build dist-check
```

The verified distribution is written below
`Toolchain/zig-out/dist/silex-<version>-<arch>-<os>/`.

## Zed integration

The Zed extension and its Tree-sitter grammar are in `Editors/Zed/`. Its local
development workflow is intentionally kept outside this public repository.
The extension starts `silex lsp`; semantic behavior remains in the toolchain,
not in the extension's Rust code or Tree-sitter queries.

The server selects a compilation input for every open `.sx` document. An
initialization option named `silex.project` may select a source or JSON project
manifest explicitly. A relative value is resolved from the first workspace
folder. Otherwise, the server searches from the document's directory towards
the workspace root for the closest Silex manifest whose `modules[].sources`
contains that document. Two matching manifests at the same level are reported
as ambiguous instead of being chosen arbitrarily. With no match, the document
itself is analyzed as a small single-source program.

All open documents loaded by one input are applied together as in-memory
overlays before the ordinary source graph, module resolver, generic
specializer and semantic analyzer run. The editor mode reads existing package
locks and materialized checkouts but never updates a lock, downloads a package,
generates C++, compiles native code or creates build artifacts. Its semantic
error therefore follows the same resolved program and first diagnostic as
`silex compile`, while `silex lint` warnings remain separately identified as
`silex lint`.

Each successful project snapshot contains the symbol identities used by
definition, references, hover, completion, signature help and rename:

- definition and references cross all loaded source units and can open local
  modules, resolved packages and the distributed library read-only. Opening
  such a destination keeps the project input that resolved it, so a native
  library unit is never reinterpreted as an isolated source program;
- hover shows the canonical Silex contract, logical module, source path and
  origin. Ordinary `//` comments and similarly named Markdown pages are not
  treated as documentation prose;
- completion uses compiler-resolved scopes, owners and visibility. Discovery
  immediately after `use` remains filesystem-based because the module may not
  belong to the graph yet;
- signature help uses the visible function, method, constructor or protocol
  requirement signatures and computes the active argument through nested
  calls;
- rename edits only application and local-module sources inside a workspace.
  It closes base/override and protocol requirement/conformance groups, rejects
  collisions and external sources conservatively, then reruns the shared
  front-end over the proposed edits before returning a `WorkspaceEdit`.

Definition, references, hover and rename require the current successful
snapshot. Completion and signature help alone may consult the last successful
snapshot while the current document contains an incomplete suffix such as
`value.` or an open call; that fallback is disabled as soon as another open
unit has a newer version.

Zed's ordinary format action uses the server's whole-document formatter.
Formatting always follows canonical Silex style independently of editor tab
and space preferences. Zed displays all LSP results through its standard
language features; the extension does not reproduce semantic analysis.
