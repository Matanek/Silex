# Silex release notes

This log helps developers decide whether to upgrade Silex and prepare any
required changes. Each release candidate adds its French entry first in
`CHANGELOG.fr.md`, then the matching English translation here. Work in progress
is recorded under `## [Unreleased]` and consolidated when preparing a release.
This editorial history starts with version 0.44.1.

## [0.47.1] - 2026-09-25

### Why upgrade?

This release reduces small-allocation costs in native Windows programs on
both ARM64 and x64. The default backend remains `native` on all six platforms;
language and ownership semantics are unchanged.

### Changes

- The Windows ARM64 and x64 native backend uses the system heap for strings,
  collections, classes, and copy/collection callbacks instead of reserving
  virtual memory per allocation. Adapters preserve scratch and SIMD registers;
  value and ownership semantics remain unchanged.
- Distribution qualification now checks allocation, copying and cycles, then
  fixed work in Debug and Release, on every native target. Measurements remain
  separate from correctness tests.
- The historical 0.47.0 notes distinguish shared changes, target-specific
  mechanisms and the actual scope of measurements.

The [fixed-work diagnostic](https://github.com/Matanek/Silex/blob/v0.47.1/Toolchain/Benchmarks/Native/Allocation/README.md)
compares the Windows candidate with 0.47.0 on the same host, with twelve Release
samples per configuration: medians move from 146.25 to 11.69 ms on x64 and from
178.10 to 14.94 ms on ARM64. These results include process startup and do not
predict application-level speedups. Linux and macOS x64 retain their existing
allocation paths; their extension remains unfinished and no gain is claimed.

### Impact and migration

Recompile Windows programs to use the new allocator. No source migration or
backend change is required.

## [0.47.0] - 2026-09-24

### Why upgrade?

This release unifies the default backend: `native` on all six distributed
platforms. It reduces copies in the shared optimizer and fixes lifetime and
code-generation errors. Further improvements apply to specific architectures
and backends, as detailed below.

### Changes

#### Shared behavior and processing

- `run`, `test`, and `compile` without `--backend` select `native` on macOS,
  Linux, and Windows, for both ARM64 and x64.
- The shared optimizer narrows nested aggregate copies. This transformation
  runs before target-specific code generation.
- Both backends strengthen cycle collection and preservation of descendants
  that are still live.
- The compiler releases unneeded analysis data earlier and bounds temporary
  memory used by some analyses and evaluations.

#### Target-specific and backend-specific changes

- ARM64 native code generation admits more scalar regions and optimizes
  checked-view kernels. It correctly preserves SIMD registers and floating-point
  components across calls.
- The macOS ARM64 native allocator uses the system heap (`calloc`/`free`)
  instead of a memory mapping per small allocation. Allocation paths on the
  other five targets are unchanged in this release.
- LLVM fixes recursive class-graph copies, tagged-enum equality, inherited
  calls, resources, collections, and callbacks. This backend remains explicitly
  available on macOS ARM64 through `--backend llvm`.

#### Available performance measurement

The [fixed-work CCD diagnostic](https://github.com/Matanek/Silex-Lib-GFX.Physics/blob/c9f85526488f0dbed0842a22ca484d06b1f46772/Benchmarks/Baselines/2026-09-24-native-heap.md)
compares the allocator before and after its change, using native Release on
macOS ARM64: 16 bodies, four moving walls, and 24 steps. The two measurement
pairs go from 16.48–17.06 to 1.70–2.51 ms/step, with identical physics code and
final states. They isolate this cost; they measure neither the full gain
between published versions nor other targets, and do not guarantee application
FPS.

### Impact and migration

On macOS ARM64, add `--backend llvm` to retain the default backend used in
0.45–0.46. Other hosts keep their existing default. Recompile your programs to
benefit from the fixes; no syntax migration is required.

## [0.46.1] - 2026-09-19

### Why upgrade?

This release prevents an older Silex installation from blocking `silex login`
when its authentication directory still has overly broad permissions.

### Changes

- The client automatically tightens a legacy storage directory to `0700` when
  it does not contain a registry credential yet.
- It continues to reject symbolic links and any credential found in a
  directory that another local user may have been able to read.

### Impact and migration

No manual action is required when the directory does not contain a registry
credential yet. A credential already present under permissive directory modes
remains rejected and must be revoked before signing in again.

## [0.46.0] - 2026-09-18

### Why upgrade?

Authors who publish packages regularly can remain signed in to the Cloudflare
registry without reauthorizing GitHub every day.

### Changes

- `silex login` now keeps access for 30 days. Publishing or running
  `silex login` renews it automatically when seven days or less remain,
  for up to 90 days after the initial GitHub authorization.
- `silex logout` still revokes registry access and removes the local copy
  when the service is reachable.

### Impact and migration

The official registry preserves the 24-hour flow for Silex 0.45.0 clients.
Update Silex to use the longer connection. GitHub authorization is required
again after 30 days of inactivity or after 90 days at the latest; no Git
repository or additional permission is required. Public installs remain
anonymous.

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
