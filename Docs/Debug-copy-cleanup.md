# Native Debug stack copies

This records the stack-copy increment at `62c62dc`. The current native Debug
policy also prepares value helpers and allocates registers; its test runner
uses that same policy. See [Debug preparation](Debug-preparation.md). The
measurements and validation below describe the earlier increment.

Native `run` and `compile` in Debug keep function calls and diagnostic source
locations while avoiding redundant stack transfers. This is a machine-lowering
cleanup, not the Release IR pipeline. The native test runner uses the
unmodified machine lowering for backend diagnosis.

`Arm64/Lower.simplifyDebugCopies` shares the existing stack-copy forwarding and
per-leaf copy-demand passes with Release. Despite the directory name, this
machine representation feeds both ARM64 and X64 encoders. LLVM is unaffected.
The CLI applies the cleanup only for Debug, on all six native targets.

Forwarding stays within a basic block and excludes addressed storage. Writes
invalidate snapshots. Copy-demand analysis retains every leaf read by an
effectful instruction and all addressed local storage. Overlapping aggregate
transfers remain conservative. Calls, checks, ownership operations, slot/frame
layout and the surviving instructions' source positions are preserved.

`zig build test-debug-copies` checks snapshots, calls, source locations,
addressed locals, overlapping transfers and loop-carried copies. The executable
fixture `Tests/Native/DebugCopies.sx` also covers reference writes, collection
replacement and branch/loop snapshots. `NativePortability.sx` invokes it from
both the test corpus and its distribution entry point.

## Compilation work

Forwarding omits definition queries for an alias entry that already points to
its own storage. Invalidating that entry would assign the same slot back to
itself. Non-identity snapshots still test both their destination and their
storage source, so source writes, range writes and block boundaries preserve
the previous invalidation rules.

The sparse-alias regression compares the complete machine function with the
previous algorithm, including writes, overlapping ranges and a join. Its
2,048-slot fixture reduces definition queries by more than a factor of 100
without changing the serialized instructions. This is a work-count proof,
not an end-to-end timing claim. The exclusion applies to the shared Debug and
Release pass for all six native targets; LLVM does not use this pass. It changes
neither emitted operations nor architecture/OS adapters.

## Local qualification

Measured on macOS 26.6.2, ARM64, on 31 October 2026. The workload is
`Silex-Examples/Sources/Physics3D/SoftTire/Main.sx` at Examples `6a062ee`,
Physics `e779f48`, Scene3D `3116e49`, Native Debug. It retains 192 vertices,
120 controller ticks/s, four reciprocal coupling steps with two soft substeps
each, and 24 rigid velocity iterations. No scene or solver setting changes.

The installed Debug executable averaged 9.93 FPS over 12.083 seconds; the
candidate averaged 227.04 FPS over 12.007 seconds. These are one graphical run
per executable, not a portable FPS guarantee. Simulation time is now 12.008
seconds over 12.007 wall seconds, versus 11.508 over 12.083 before. Reducing
physics cost below its fixed-step budget prevents continuous catch-up; the FPS
ratio is consequently much larger than the fixed-work CPU improvement.

Three fixed-work runs per executable in ABBAAB order took 5.311–5.407 seconds
before and 3.847–3.955 seconds after for 600 controller ticks. Medians were
5.352 and 3.911 seconds, respectively. All five physical snapshots match
exactly on every run. The complete tire check also preserves all 47 physical
observation lines from its retained qualification reference.

A second control rebuilds the same compiler sources (base `8a9e4f0`) with only
the cleanup call disabled. Three runs per variant in ABBAAB order take 5.435–6.058 seconds
without cleanup (median 5.474) and 3.977–4.067 with cleanup (median 4.041).
Snapshots again match exactly. The wider first control range limits timing
precision but does not overlap the candidate's range. Both executables retain
the same 4,716 function symbols and 4,441 source-mapped function names; pure
copy-only source anchors may disappear with their eliminated instructions.

The final local rebuild after test-root registration has identical `__text`,
`__const` and `__cstring` sections to the profiled executable. Its complete
tire check passes again with the same 47 physical observations.

The regression executable runs on macOS ARM64 and macOS X64 through Rosetta.
Linux ARM64/X64 and Windows ARM64/X64 binaries are emitted and identified as
ELF/PE for the requested architecture; they are not executed here. Performance
is not measured on X64, Linux or Windows. This qualification does not claim a
compile-time improvement, a release/distribution gate, or a general FPS gain.

## Validation commands and limits

The targeted `zig build test-debug-copies` gate executes 11 tests from the real
`Root.zig`, including explicit imports of both cleanup suites. The broader
bootstrap run passes 1,645 tests; the optimizer admission control passes its
84 tests and 28 semantic corpus programs. The complete language suite passes
278 tests across 111 files when run alone from `SilexProject/`.

`zig build check test -j2` also starts workspace-root CLI checks with
`SILEX_USER_PACKAGE_ALLOWLIST=STD`. In this workspace a local Physics link
requires a user GFX link that this filter excludes. The unmodified control
compiler rejects the same graph. The Result-call CLI checks, native Debug and
Release math checks, and full language suite are therefore replayed from the
workspace root with normal package resolution; all pass, without changing
package links. The original aggregate command's environment failure is not
reported as a green run.

Do not change compiler identities concurrently with a shared-cache language
campaign: generation cleanup can remove a test object while it is linking or
running. An initial overlapping campaign was discarded, and its affected
coordinate regression and complete suite pass on sequential replay.
