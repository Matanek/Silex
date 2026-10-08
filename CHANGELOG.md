# Silex release notes

This log helps developers decide whether to upgrade Silex and prepare any
required changes. Each release candidate adds its French entry first in
`CHANGELOG.fr.md`, then the matching English translation here. Work in progress
is recorded under `## [Unreleased]` and consolidated when preparing a release.
This editorial history starts with version 0.44.1.

## [Unreleased]

- Compose implicit numeric widening with optional promotion: `float` durations can feed `float64?` without implicit unwrapping or narrowing; overload costs and LSP value suggestions follow the same rule. Named overloaded method arguments provide their shared collection context without selecting an overload arbitrarily.

- Reuse the identity of source-declared arrays of generic types during specialization. A method returning `Option<Choice>[]` and a field `Option<T>[]` no longer declare two structures with the same name.

- Native cycle collection skips elements of scalar, string and optional-scalar arrays because they cannot own class edges. Large list data is no longer scanned during each temporary cleanup; arrays containing classes remain traced.

- The parser distinguishes compound comparisons from generic calls when an operand is parenthesized; fixed-array, tuple and function type arguments remain recognized.

- On X64, `append()` reuses spare capacity in an unshared list and reserves space when growing. Building large arrays no longer copies all their contents on every append; shared snapshots remain independent.

- Mutable `indexed()` iteration keeps the owned element alive until writeback. Body cleanup failed to account for the index binding, causing premature release and an X64 crash.

- `for var` and `indexed()` can traverse mutable collection fields and write their storage on every iteration, including before continue and break; list copies remain independent.

- Mutability inference also follows mutable field views, contained protocol methods and mutable iteration over self collections. Getters remain protected against these indirect mutations.

- Protocol properties can be read from constructor parameters and borrowed collection elements without requiring a mutable receiver or writing its storage back.

- ARM64 Release loops testing `value % 2 == 0` or `!= 0` now reevaluate parity after each iteration. Nested loops no longer read a remainder eliminated by instruction fusion.

- On ARM64, class-reference cleanup addresses its runtime context independently of value registers when the stack reaches the 32 KiB boundary. This prevents crashes or corruption of a live register at that boundary, including UI description construction in Release.
- Mutable views `&T[..]` use the same calling convention in methods, constructors and callbacks as in free functions, including named calls and dynamic protocols.

- A cascade on a temporary value passed to an optional parameter now mutates the value before optional injection, including classes and collections. Completion preserves the concrete receiver’s members.

- `publish --dry-run` and publication preparation use Shadercross configured by `silex setup`, like the other compilation commands. Packages whose sources import HLSL programs are no longer incorrectly rejected as unconfigured.

- `take_last()` reuses an unshared collection buffer on ARM64 and X64 instead of copying every element. Shared snapshots, float32 storage and extracted resources retain their ownership.

- Module-visible function references remain accessible from constructors and methods in the other atoms of that module, following the visibility rules of ordinary calls. Completion retains a callback field signature and offers functions from the other atoms; navigation resolves their canonical declaration. File-local functions and private modules remain hidden outside their scope.

- Recursive descriptions stored in collections of protocol values now retain and release their contents without infinite compiler recursion. Direct inline value cycles receive a source diagnostic: their representation must cross a class or dynamic-array field.

- Generic calls in anonymous callbacks now infer types from captured values, including nested callbacks and generic parent functions. Callback parameters retain lexical shadowing; capture lifetime rules are unchanged.

- Native ARM64 Release preserves floating-point constants used before their SIMD partner is defined; quaternion rotations no longer read a previous register value in this case.

- Replacing a resource-owning field in an indexed class collection no longer releases the old reference twice. Restored shared snapshots and self-assignments keep their resource alive until the last owner is destroyed.

- Module-visible extension methods are accessible from atoms and implementation children of their activated provider module, including static, named and generic calls. LSP completion and navigation follow direct and transitive imports in the edited file and resolve the declaring atom. Module-visible methods remain hidden outside that module, and file-local methods outside their file.

- Imported `package` types in a composed module resolve in their declaring atom, regardless of file order. The LSP preserves canonical `Package` imports, aliases, and accessible members and variants; file-local and package-private types remain hidden from external consumers.

- In an explicit constructor, a class field without an `=` expression now awaits its assigned reference, even when its class has a parameterless constructor. It no longer creates an immediately replaced temporary instance; an intended prior construction must be written on the field as `= Resource()`. Reads before initialization and uninitialized paths are diagnosed.

- Overloaded constructors provide an expected argument type when all visible candidates accepting the call share that parameter type; empty lists or lists of computed dimensions can be written directly without arbitrarily selecting an overload. Completion offers the element type inside lists and preserves named, nested and incomplete calls.

- An unused abstract helper may declare protocol calls without requiring a concrete implementation in the program; its body remains type checked and no synthetic conformer is added.

- Dynamic protocol calls retain owned arguments and transfer results like ordinary calls; native execution no longer frees lists still used by the caller.

- Mutual dependencies between a module and its descendant are accepted within one package hierarchy; unrelated branches remain rejected.
- Module-visible fields of a class with a destructor remain accessible across its composed module atoms without exposing private fields.

- Fix `interpret` to accept `list.insert(list.count(), value)`, including
  empty lists, while retaining strict read and removal bounds.

- Static methods now propagate `try` using their declared `Result` return, including void results and error messages; local alternatives remain available.
- `interpret` ignores imported system functions unreachable from `main`.
  Effective calls and callbacks that may reach an unsupported boundary remain
  rejected, allowing portable programs in modules that also offer file loading
  to be compared with native execution.

- Injected systems select their function using the calling module visibility.
  A loaded private same-name function in another module no longer causes a
  false callback rejection; callers can retain their source function names.

- `try`, including local alternatives and messages, preserves the logical `Result` and receiver state in mutating struct and class methods. Propagated failures now follow the receiver return path.

- Visibility checks for a list shared across source atoms follow its element
  type in the declaring atom. An unrelated private type in the caller no
  longer falsely rejects a package or public signature; actual private type
  leaks remain rejected.

- Native ARM64 Release correctly loads SIMD lanes of floating vectors read
  from lists with wide storage. Borrowing another list element no longer
  changes the computed coordinates; convex wedge construction in a graphical
  scene is qualified on macOS ARM64. ARM64 Darwin/Linux/Windows emission is
  covered; the latter two systems are not executed in this local validation.

- Native ARM64 preserves payload bits when scalar or aggregate-field copies
  cross general-purpose and floating-point registers. Release `abs` of a field
  no longer reads a stale stack home. The `copysign` and `sqrt` intrinsics
  also access the correct paired float32 lane without overwriting its neighbour.

- Deferred SIMD operations keep their inputs alive until actual emission.
  In Native ARM64 Release, an intervening scalar load can no longer overwrite
  a component, restoring movement distances and cadence to the LLVM results.
  Large aggregate-copy indices also avoid intermediate overflow in the Debug
  toolchain.

- Native ARM64 preserves floating-point component copies when their SIMD
  partner copy was removed as unused. Partial vector assignments no longer
  trigger `InvalidMachineProgram` during Release emission.

- Native Release fix: `min/max` vector affinities retain scalar execution when
  their operator has no compatible SIMD emission. This fixes distorted shadow
  projections in 3D scenes.

- Fixed Native ARM64 Release aggregate class-field loads: simultaneously
  loaded leaves keep distinct registers, so an unused leaf cannot overwrite
  a live identity or value.

- Native ARM64 Release waits for external signatures before allocating
  registers in functions that call a library. Math intrinsics therefore avoid
  stack transfers previously imposed by an unresolved call.

- Native ARM64 keeps independent numeric values in registers across class
  operations. Their allocations and releases use the system ABI directly on
  macOS and Windows without saving every temporary register.

- Native ARM64 Release calculations reuse the values behind temporary stack
  copies while their storage remains unchanged. Exposed addresses and control
  flow boundaries retain their copies.

- Native ARM64 Release pins mixed aggregate load results without disabling
  registers for the entire function. Arithmetic regions qualify from
  16 floating-point operations.

- Native ARM64 Release no longer transfers unused fields through structure
  copy chains. Address-taken storage and overlapping transfers remain fully
  preserved.

- In Native ARM64 Release, an aggregate call inside a loop no longer forces
  the entire function onto the stack. Aggregate arguments and results retain
  protected memory homes while independent arithmetic can keep registers.

- Native ARM64 Release class field reads and writes can use scalar registers
  directly, avoiding intermediate stack copies. Mixed fields preserve their
  payload bits, and packed SIMD lanes remain excluded from these transfers.

- Register allocation accounts for every parameter captured at function entry,
  including unused ones. An unused parameter can no longer overwrite a live
  argument’s register in the native prologue.

- On macOS ARM64, class reference counters use the LSE atomic instructions
  guaranteed by Apple Silicon. Decrements remain saturating and retain
  acquire/release synchronization; other targets keep their existing path.

- Native ARM64 strings built by concatenation, byte conversion or formatting
  explicitly reserve and write their trailing zero. X64 formatting does the
  same. C calls receiving constructed strings no longer read past the
  allocation, fixing invalid window titles; logical string lengths are unchanged.

- Native ARM64 lists on macOS and Windows initially reserve 128 bytes
  instead of a whole page. Geometric growth, copying, detachment and
  destruction guarantees are preserved; small collections no longer zero
  unused pages.

- Release removes balanced temporary references around proven readers and
  numeric value stores. On macOS and Linux ARM64, class field transfers
  preserve arithmetic registers, and inline continuations are no longer
  mistaken for loops. Ownership barriers and actual cycles remain protected.

- Fixed Native Release ARM64 SIMD pairing of float fields produced by
  different operations, such as `center - radius` and `center + radius`.
  A native regression checks both values in Debug and Release; the bug
  previously duplicated the lower bound.
- The package method cache now tracks shaders, their included files, and embedded files. Editing or deleting any of these files invalidates the corresponding compiled constants; later compilations retain these dependencies, even after repeated cache hits.
- Fixed a native Release crash when iterating a list in an enum whose other variant contains floating-point values. Floating-register inference now respects the boundary between shared enum storage and typed payloads; a standalone regression covers this case.
- Fixed an incorrect normal in ARM64 Native Release when conditional copies made two still-live floating-point pairs share a SIMD register. Register coloring now keeps those pairs distinct while their lifetimes overlap; a 3D geometry regression checks both the normal and separation.

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
