# Silex release notes

This log helps developers decide whether to upgrade Silex and prepare any
required changes. Each release candidate adds its French entry first in
`CHANGELOG.fr.md`, then the matching English translation here.

## [0.45.0] - 2026-09-18

### Why upgrade?

This release prepares package publishing and installation through the
Cloudflare registry. It can publish a snapshot of a local directory without a
Git repository and keep versions installable independently of the author's
repository. It also adds language expressions and extends the LLVM backend
qualified on macOS ARM64.

### Changes

- `silex login` authenticates authors through their GitHub identity without
  repository access; `silex logout` revokes the local credential.
- `silex publish <directory>` sends sources and declared artifacts to the
  registry. `--dry-run` lists included and excluded files and the snapshot
  digest without network access or publication.
- `silex install` detects the Cloudflare registry protocol when it is enabled
  on the official domain, verifies downloaded objects, and keeps access to
  the old index during the transition.
- The language supports value-producing `match` expressions, scalar literal
  patterns, and user-defined arithmetic operators.
- LSP completion covers more incomplete expressions, inherited members, and
  workspace changes.
- LLVM becomes the default backend on qualified macOS ARM64 hosts; other
  platforms keep the native backend by default. The native ARM64 and X64 paths
  also receive fixes and optimizations.

### Impact and migration

The Cloudflare registry must be active on `registry.silex-lang.org` before
`silex publish` can upload. Before the cutover, `--dry-run` works offline and
installs continue to read the old index. After the cutover, older Silex clients
cannot install versions stored only on Cloudflare: update the client. Packages
can now be published from a directory without Git; a repository link remains
optional for contributors. Existing source code needs no change to use the
new language constructs.

## [0.44.1] - 2026-09-09

### Why upgrade?

This release fixes several cases where valid programs could be analyzed
incorrectly and makes completion more reliable while editing incomplete code.

### Changes

- Construction now preserves inherited class graphs.
- Diagnostics remain correct when a module is imported through an atom.
- LSP completion recognizes incomplete cascades and prefixed expressions
  while they are being typed.
- Collection literals receive the correct type context when used in an
  optional value.

### Impact and migration

This release introduces no intentional breaking change and requires no source
change. Recompiling is sufficient. The upgrade is recommended for projects
that use class inheritance, atom imports, optional collections, or editor
completion.
