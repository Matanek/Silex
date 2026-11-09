# Silex release notes

This log helps developers decide whether to upgrade Silex and prepare any
required changes. Each release candidate adds its French entry first in
`CHANGELOG.fr.md`, then the matching English translation here. Work in progress
is recorded under `## [Unreleased]` and consolidated when preparing a release.
This editorial history starts with version 0.44.1.

## [0.48.0] - 2026-11-09

### Why upgrade?

This release introduces one implementation per `Result` operation, default
protocol methods, and explicitly rounded floating-point conversions. It fixes
callback, collection, and composed native-program behavior while reducing
compilation work for large applications. Ecosystem packages publish their own
features and versions; these are not included in the compiler binary.

### Changes

- On ARM64, native `float64` array reads retain all 64 bits when a scalar element or an aggregate’s odd tail resides in a floating-point register. Coordinates built in a loop and passed to a method no longer become zero before conversion to `float`.
- Consumers located under their dependency directory retain sibling modules with absolute or relative entry paths. Compiler and editor discovery exclude only descendant dependency roots, without hiding a consumer below an ancestor dependency.
- On Windows ARM64, dependencies declaring the C++ runtime retain its full CRT startup; linking no longer combines it with the standalone UCRT startup and TLS symbols.
- Native link failures also report the process termination status and standard output, distinguishing symbol errors from a linker crash.
- Correct ARM64 stack-slot reuse after floating-point writes: stale integer bits no longer hide the current result. Constants, unary operations and arithmetic are covered in Debug and Release on ARM64 targets; the X64 backend does not share this cache.

- Native Windows ARM64 linking uses UCRT directly and a small startup embedded
  in the compiler, avoiding a full MinGW rebuild. COFF objects and the existing
  cache remain in use; archives that require GNU helpers, constructors,
  relocations or TLS callbacks retain the compatibility link after inspecting
  the linker output. Cross-emission and native execution have separate validation
  gates.

- Compilation probes retain partial output and file-phase evidence while
  waiting, then stop their child processes on timeout. The initial Windows
  ARM64 diagnostic keeps observation limits separate from latency budgets
  and preserves reuse and retention assertions.

- Native multi-target validation includes local compilation guards for active
  aliases, Debug/Release reuse, and bounded retention.

- Native and interpreter caches enforce retention after writes, including
  error exits. Native executable cache hits retain their fast path.

- IR validation retains the writer checks without formatting or allocating
  discarded text. Explicit text output remains deterministic, and global indices
  and dynamic-call targets are checked explicitly.

- Native copy cleanup tracks only active storage aliases, avoiding repeated
  scans of other slots while retaining the same invalidations. This temporary
  tracking adds no persistent cache.

- Program transfer to compilation backends copies typed descriptors directly,
  without intermediate JSON serialization. Metadata and ownership lifetimes
  are preserved while compilation avoids the text conversion.

- Semantic analysis shares identical destruction plans between operations in
  one program. Each new analysis resets the lookup; inherited finalizers and
  construction cleanup remain identical.

- Specialization indexes lexical callbacks by file, position and arity before
  comparing names. It avoids repeatedly scanning incompatible declarations
  while preserving callback selection and capture context.

- Native copy forwarding avoids definition queries for entries that already
  point to their own storage. Other alias invalidations and the emitted
  instructions remain identical in Debug and Release on the shared ARM64
  and X64 paths.

- Callback confinement follows values, fields, aliases and calls in a finite
  flow graph before the complete ownership interpretation. Unproven cases
  retain that interpretation, including opaque factories and retaining paths.
  Emitted IR and the capture contract remain unchanged; see
  `Docs/Callback-confinement.md`.

- Callback analysis preserves discriminants and branch payloads for associated
  enums without assuming payload equality. Unknown receivers use finalizers
  only from their declared class and subclasses. Block entries omit dead SSA
  values, calls use an exact context index, and invalidation visits only known
  facts; memory, ownership, and capture rules remain tracked.

- Callback analysis avoids rescanning abstract memory whose mutable facts have
  already been invalidated until a new known fact is written. Branches, joins,
  and arena changes preserve the validity of this reuse without changing
  diagnostics or capture rules.

- Fix generic call inference inside `indexed()` loops: elements retain their collection type and indices retain `int`, including in nested loops. Borrowing and copying modes remain unchanged.

- The compiler proves capture confinement in an input-free void root when bindings expire without surviving values and no global, opaque import, or native recipient can carry the loan. Other cases retain the complete ownership analysis. Recursive contexts distinguish pre-existing receivers, addressed locals with no outside aliases remain invocation-private, and known collections retain their elements and resource counts. Concrete control flags and typed numeric zero exclude proven impossible paths; opaque calls, native calls, and raw stores invalidate mutable facts. Emitted code and the capture contract remain unchanged.

- Borrow analysis preserves known protocol, enum and optional-presence alternatives, then refines them in each branch. It distinguishes an absent target from an unknown function, materializes opaque carrier results, and retains unknown alternatives through copies and external collections. Writes through optional references remain analyzed even when they only change a scalar condition. Unaddressed locals remain private to each invocation, and control-flow cycles are checked directly. Objects present at invocation entry retain their identity in recursive contexts; a new identity restores finite nominal widening. Emitted code, the ABI, and the borrowed-capture contract remain unchanged.

- The compiler proves direct non-retaining uses of borrowed callbacks before interpreting application ownership. Direct forwarding between helpers is covered; storage, returns, copies, missing bodies, lifetimes, and unproven indirect forwarding retain the full analysis. Other borrows created inside the callback are still checked, without changing emitted code or the ABI.

- Borrow analysis preserves known booleans and payload-free variants in immutable values to exclude statically impossible paths. External inputs and aliases remain unknown; opaque calls invalidate mutable facts in concrete objects. Copies preserve these facts, and an unanalyzed return remains unknown in a union of callbacks. Emitted code and the ABI remain unchanged.

- Drawing-borrow validation distinguishes captures, global effects, and local creation to limit traversal to relevant callbacks. Logical reference types are preserved in IR and caches; returns, writes, and owners remain tracked.

- Collections and generic specializations distinguish callback signatures, including `@` and `&` modes. Free generic calls accept named arguments while preserving defaults and concrete overload priority. Completion follows function values and elements of inferred collections, and preserves the context of an incomplete argument placed before another positional argument.

- The interpreter preserves the initial root and owned edges of graphs created by `copy`, matching the native runtime. A helper call no longer prematurely destroys a copy that is still owned; cycles and shared references preserve their counts.

- Callback borrows are tracked through direct and indirect calls, their environments, fields, and collections. The compiler rejects retention beyond the captured binding, including retention by a finalizer; synchronous calls and owned bound methods preserve their lifetime. The shared analysis runs before either backend and may reject a path whose safety it cannot prove.

- Factory return inference accounts for named arguments: implicit results remain usable without annotations as resources and generic arguments. Static, free-function and method calls retain completion on their results. Values extracted by `match` also retain their type for generic calls inside modules and completion, respecting pattern mutability.

- Constrained generic calls preserve the public protocol contract with local or package conformers, including through a generic field. Other overloads and members remain hidden; completion follows generic field constraints and their returned values.

- Mutability inference recognizes writes to `self` in `try … else` branches, preserving mutable borrows and the getter mutation diagnostic.

- Principal enum variants remain values when their module contains homonymous helper functions; unrelated callback references remain available.

- LLVM Debug bypasses `opt` for units whose emitted functions have only forward branches and no special annotations. Loops and unknown forms retain the existing O0 pipeline; `llc` always verifies its inputs. The `llvm_units_optimized` trace counter reports units sent to `opt`, and the policy participates in their cache identity. Release retains its O3 pipeline and unit boundaries. On the local macOS ARM64 corpus, LLVM Debug compilation drops by 23.9% for Boids and 23.7% for the Tokenizer, with identical executables; see `Docs/LLVM-debug-preparation.md` for the protocol and limits.

- A string read through an `@` or `&` borrow can be passed by value or retained in an owned field, as with an ordinary return. Its immutable storage stays retained; borrow capabilities and class references still cannot escape.

- The LLVM backend accepts fixed `objc_msgSend` signatures whose handles use 64-bit words while preserving provider and ordinary C signature checks. Its text-emission temporaries are released before the LLVM tools: Boids now compiles in Debug and Release on macOS ARM64 within the local memory guard. Native behavior is preserved.

- The frontend indexes source declarations once for inheritance and protocol queries. It resolves the current internal name, including after tuple inference, and rebuilds the index for each analysis. The mechanism is shared by both backends and all six targets; evidence and limits are in `Docs/Frontend-lookups.md`.

- Register conflict queries use per-slot liveness and definition masks to skip repeated scans of dead instruction points. The ARM64 graph shared with X64 floating scalars preserves the same sharing rules and decisions; temporary tables are released after each graph. Local macOS ARM64 measurements reduce Boids compilation by 7.1% in Debug and 52.3% in Release against the preceding increment, with identical executables; see `Docs/Native-conflicts.md` for the protocol and limits.

- Native liveness computes uses and definitions once, then solves the fixed point in 64-bit words. It preserves the same boolean matrix for ARM64 register allocators and their X64 consumers; temporary tables are released after each solve.

- Per-pass optimizer verification releases its temporary storage before the next pass. Validation shares the textual IR checks and reuses storage per function. Debug retains every check without accumulating verification memory in the compilation result.

- The native test runner releases emission and linking scratch after each case instead of retaining it until the source file finishes. The shared program, captured output, diagnostics and signal-artifact retention keep their contract.

- C callbacks have a distinct native entry: floating arguments and results, preserved registers, and stack arguments follow the target ABI, including after closing the program to its used functions. `C.call` and callbacks accept flat record parameters with 64-bit fields; their results remain scalar. C bindings also accept `uint16`. References must resolve without captures at compile time, directly or through immutable aliases. Static method references can be inferred without annotations, and local declarations take precedence over namespace homonyms. Completion inserts these references without invoking them and recovers indirect C argument contexts.

- Collection literals used as optional fallbacks inherit the payload type, including empty lists and tuple fields, while ordinary numeric fallback widening is preserved. Completion keeps the same element context.

- Reading narrow signed integers after a C pointer write now restores their sign, including fields, mutable borrows and collection elements.

- Protocol calls keep class receivers alive through arguments and callbacks, then preserve their shared identity without writing back the original field. Reentrant replacements remain in place, while value conformers still write back updates. Safe calls through optional fields participate in mutability inference.

- Native cycle collection reuses field offsets and types within a trial, using a bounded reserve in the existing context; aggregates without class references avoid repeated visits. Exhaustion preserves full traversal. Values, roots and finalizers retain their behavior. ARM64/X64 payloads share the implementation; CPU measurements remain limited to their macOS ARM64 Debug configurations, without claiming a global gain or execution on other systems.

- Protocol methods can provide default bodies: existing conformers reuse them, explicit implementations take precedence, and concrete, generic, and dynamic calls preserve the same choice. Bodies are checked in protocol scope even when unused; competing defaults require an explicit implementation. Completion, labels, and navigation retain the original declarations across imports and extensions.
- Method calls through a protocol accept named arguments using the protocol's labels. Comparing an optional protocol with the `null` literal tests presence without requiring a comparable payload.
- `main` retains its module scope for calls across atoms. The LSP also indexes open files before their first save, preserving file or atom identity and visibility boundaries.
- Native Debug prepares values and places temporaries in registers, with bounded inlining of small straight-line helpers. Checks and source information remain available; inlined helpers no longer create separate frames. The test runner uses the same policy. The monster truck retains its four soft tires and physics settings; see the local qualification and its limits in `Docs/Debug-preparation.md`.

- Native Debug removes unused temporary copies and redundant scalar stack transfers while preserving calls, source locations, checks and ownership. The soft-tire solver retains its settings and physical observations; qualification is local to macOS ARM64, with no performance claim for other targets. See `Docs/Debug-copy-cleanup.md`.

- `match` also releases a resource-bearing temporary subject when it selects `else`. Payload-binding branches keep their transfer behavior and borrowed subjects remain alive; object destruction is covered by native tests and an LLVM check.

- Add `round_float<T>(value)`: explicit rounded floating conversion to `float32` or `float64`, using nearest ties-to-even with subnormals, signed zero, infinities and NaNs. The `as` conversion retains its lossless check.

- LSP and admission test runners use the bootstrap’s 32 MiB Debug stack, so the recursion test reaches its diagnostic instead of overflowing the system stack.

- Native cycle collection also skips scalar, string and optional scalar fields while preserving their reserved width. Frequent UI traversals avoid these visits without hiding class references or callbacks. Collector and native cycle regressions; local table gallery measurements.
- Parameter defaults retain their declaration’s visibility: internal enums and helpers work in functions, constructors and methods without granting those access rights to the caller.

- An imported function alias no longer renames an identically named method called through a receiver; instance, static, generic and protocol calls retain member resolution.

- A `Result<T,E>` operation has one implementation: an ordinary call produces `T` or panics; `try operation()` keeps the `Result`. This replaces the previous extraction/propagation meaning of `try`. Propagation now uses an explicit `else error { return … }` branch, and previous ordinary captures add `try`. Explicit Result constructions remain data; receivers, arguments and defaults are evaluated once. LSP completion follows the call mode and previous caches are invalidated.

- Anonymous functions retain the private/protected access of their lexical context, including nested callbacks and static methods. Capturing a receiver from outside grants no additional access; extension restrictions still apply.

- Recursive structures through dynamic lists copy and drop without infinite compiler recursion; their resource operations use IR calls, like recursive protocols. Interpreter and native macOS ARM64 regressions.
- Accept append(null) for lists of optional elements using the known receiver type, while preserving sequence append behavior.

- Parentheses can group a type: `(func(str) int?)?` distinguishes an optional function from its optional result. Generic optional callbacks preserve their signature and type suggestions remain available inside these annotations.

- Callbacks stored in array element fields can be called directly, including through a collection held in a field. The receiver and index are evaluated once; completion and bound-receiver lifetime are covered.

- Native cycle collection also skips arrays of structures and enumerations composed only of scalars, strings and collections without class references. Large `Select` sources are no longer traversed during every temporary cleanup; class and callback edges and ordinary finalizers remain intact. Native macOS ARM64 regressions and measurements; shared ARM64/X64 payloads are rebuilt, with no new execution evidence on other hosts.

- Preserve shared context for named arguments of overloaded functions and static methods: structure/protocol lists and empty lists use the common parameter type without an intermediate array or arbitrary selection when candidate types differ.

- ARM64 failure guards reach their handler beyond 1 MiB, including large composed constructors. Successful execution and error propagation retain their results; Darwin/Linux/Windows encoding regressions and native macOS execution, with no new Linux/Windows execution proof.
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

- Static methods preserve value and void results, local alternatives, and error messages when explicitly captured with `try`.
- `interpret` ignores imported system functions unreachable from `main`.
  Effective calls and callbacks that may reach an unsupported boundary remain
  rejected, allowing portable programs in modules that also offer file loading
  to be compared with native execution.

- Injected systems select their function using the calling module visibility.
  A loaded private same-name function in another module no longer causes a
  false callback rejection; callers can retain their source function names.

- Explicit `try` capture and its local alternatives preserve the `Result` and receiver state in mutating structure and class methods, including error paths.

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

### Impact and migration

The meaning of `try` changes: an ordinary call to an operation returning
`Result<T,E>` produces `T` or stops the program on failure. Write `try call()`
to keep and inspect the `Result`; replace old implicit propagation with an
explicit branch returning the error. Upgrade the compiler together with packages
that adopt this contract.

In an explicit constructor, initialize every class field on every path. To
request prior construction, write an `=` initializer on the field. Callback
borrows that may outlive their binding are rejected; keep an owned bound method
when its receiver must survive. `round_float<T>` explicitly requests rounding;
`as` remains lossless.

Shared optimizations and changes specific to ARM64, X64, or LLVM are identified
above. Quoted measurements qualify the named local macOS ARM64 workloads; they
do not promise general speedups or performance parity across platforms.
Distribution checks do not replace those measurement campaigns.

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
