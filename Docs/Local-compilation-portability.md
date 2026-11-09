# Local compilation across native targets

Compilation work belongs to a semantic stage, machine representation, or OS
adapter. A directory name does not define the target scope: `Arm64/Lower.zig`
also supplies the stack-compatible machine form consumed by the X64 encoders.

## Applicability

Frontend callback indexing and confinement analysis, per-analysis destruction
plans, `BackendTransfer`, and `Ir.validate` are shared. Their reuse is internal to
one analysis; it does not add a persistent cache or a target-specific fast path.
`Main.compileNativeOptions` enforces the same post-publication retention policy
for Mach-O, ELF and PE. The interpreter owns a separate function-scope cleanup.

| Native target | Shared frontend/IR work | Stack-copy forwarding in Debug | Stack-copy forwarding in Release | Local retention |
|---|---|---|---|---|
| macos-arm64 | Shared | Before Debug register placement | After ARM64 allocation | Shared, Mach-O artifacts |
| macos-x64 | Shared | Before X64 Debug register placement | Not selected by the existing Release lowering policy | Shared, Mach-O artifacts |
| linux-arm64 | Shared | Before Debug register placement | After ARM64 allocation | Shared, ELF artifacts |
| linux-x64 | Shared | Before X64 Debug register placement | Not selected by the existing Release lowering policy | Shared, ELF artifacts |
| windows-arm64 | Shared | Before Debug register placement | Not selected by the existing Release lowering policy | Shared, PE artifacts |
| windows-x64 | Shared | Before X64 Debug register placement | Not selected by the existing Release lowering policy | Shared, PE artifacts |

`NativeTestRunner.lower` also uses the common Debug copy preparation before
selecting host register placement. No additional forwarding pass is enabled in
Release merely to make a target table uniform. Its target allocation policies
remain independently owned. The explicit LLVM backend shares the frontend,
`BackendTransfer` and IR validation, but does not consume native stack-copy
forwarding. Its CLI already registers post-mutation cleanup at function scope.

## Regression entry points

From the toolchain directory, `zig build test-fast-local-compilation` exercises
these shared contracts without a machine-dependent timing threshold:

- typed backend transfer remains equal to its independent JSON oracle and owns
  its data after frontend storage is freed;
- IR validation preserves text-writer checks without requiring text allocation;
- active-alias forwarding matches full and filtered scan oracles, including
  source writes, overlapping ranges and block joins;
- compiler identity, cache keys, corruption, private materialization and global
  rolling history preserve safe reuse and protect an oversized active set.

`test-debug-copies` includes all `stack forwarding` tests, including the
active-alias oracle. From the containing workspace, run
`python3 Silex/Toolchain/Tools/VerifyCacheRetention.py <built-cli>` alone to check
native Debug and Release reuse between two independent same-basename projects,
import invalidation, unchanged-consumer hits, and retention after native and
interpreter publication or interpreter failure. Only console fixtures execute.

The five non-local native jobs in `native-portability.yml` invoke
`.github/scripts/verify-local-compilation.py` after setup. It runs the unit portal
on that host and the CLI bank from the common workspace above the checkout.
Windows ARM64 explicitly selects `aarch64-windows` when its Zig bootstrap tool
runs through X64 compatibility; the tested CLI, unit binary and generated native
programs remain ARM64. No cache archive is uploaded by these guards.

## Observe an interrupted first compilation

The CLI bank clears its previous trace before each command, preserves partial
stdout/stderr, and reports the sizes of the executable, adjacent Debug object,
and trace every 15 seconds while a command is pending. With a fresh output path,
a completed `.silex.o` separates object production from subsequent linkage. After
success the initial compile reports its full phase timings. A timeout stops only
the owned compiler process tree; inherited linker output handles cannot leave
the test waiting indefinitely for captured pipes to close.

`--initial-compile-timeout` changes only the diagnostic observation window for
the first Debug compile. Other compilation cases keep their 60-second safety
bound, and all reuse, invalidation, output and storage assertions remain active.
The Windows ARM64 workflow explicitly permits 300 seconds for that one initial
observation after an unexplained first-compile timeout. This is not a relaxed
product latency budget or evidence that the delay comes from the linker.
Interpret its phase timings before attributing or correcting the cost. Process
capture/cleanup regressions run through `VerifyCacheProcess.py` on every host.

## Evidence boundaries

A configured job is not an executed proof. Keep these results distinct for each
candidate: shared host unit tests, emitted target format/relocations, translated
execution, native execution, distribution, and compilation performance. An ARM64
measurement does not predict an X64 gain; a PE or ELF produced on macOS does not
prove Windows or Linux behavior. A Mac X64 process run through Rosetta validates
that translated execution, not a physical Intel performance measurement.

Use the manual target-selectable native workflow for target behavior unavailable
locally, on the exact candidate SHA, with the task's required remote authorization.
The shared workflow runs the compiler-owned fixtures and guards; GFX examples and
package graphs do not become compiler CI dependencies.
