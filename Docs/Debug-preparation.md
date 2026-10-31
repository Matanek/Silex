# Native Debug preparation

Native Debug is the default development path for `silex run`. It uses bounded
value preparation and target register placement instead of emitting every
intermediate value through the stack. Physics examples keep their existing
solver settings; this policy is independent of GFX and applies to ordinary
native consumers and the native test runner.

## Policy and diagnostic limits

`Optimize/Debug.zig` reuses the verified prefix of the shared optimizer through
`local_simplification_post`, with control-flow inlining explicitly disabled.
It includes local simplification, integer/boolean local promotion, aggregate
borrowing/scalarization, exact scalar math intrinsics and bounded straight-line
value inlining. It does not run range analysis, later SSA/global cleanup,
reference-memory elision or private-class-state caching. The portable verifier
runs between these passes. LLVM Debug and Release policy are unchanged.

Machine lowering removes redundant copies and `DebugNative.zig` selects the
existing ARM64 or X64 register allocator. Addressed storage and unsupported
functions retain the allocators' conservative stack treatment. Raw `Lower`
entry points remain available for independent backend tests. Aggregate call
forwarding compacts source positions alongside instructions on X64.

Safety operations retain their explicit diagnostic positions unless local
facts prove them unnecessary. Function-level source symbols remain available
on macOS ARM64. This is not an unoptimized statement-by-statement debugger
image: a small inlined helper need not have a separate frame, and transformed
instruction anchors may fall back to their enclosing function. There is no new
floating-point reassociation or relaxed arithmetic mode.

## Local runtime qualification

Measurements on macOS ARM64, 31 October 2026, use Examples `6a062ee`, Physics
`e779f48`, Scene3D `3116e49` and native Debug. MonsterTruck retains four soft
tires of 192 vertices each, 120 controller ticks/s, eight coupling steps per
tick, one soft substep, eight rigid velocity iterations and four workers.
Neither scene nor physics source is modified.

| MonsterTruck measurement | Wall seconds | Simulated seconds | Average FPS |
| --- | ---: | ---: | ---: |
| Previous Debug (`62c62dc`) | 12.197 | 3.267 | 4.02 |
| Value preparation alone (insufficient) | 12.030 | 8.892 | 11.14 |
| Value preparation and register placement | 12.008 | 12.033 | 182.55 |
| Ramp ascent, prepared Debug | 12.013 | 12.017 | 100.31 |
| Stopped on slope, prepared Debug | 6.006 | 6.008 | 105.73 |

Each row is one graphical measurement, not a portable FPS guarantee. The
baseline repeatedly exceeds the fixed-step budget and accumulates catch-up
work; the FPS ratio is not a fixed-work CPU speedup. The prepared runs still
have occasional long frames (maximum 82.4 ms on the normal course, 73.9 ms on
the ramp and 91.3 ms on the slope). They establish real-time progression for
these workloads, not a bound on every frame or every project.

The final installed compiler reproduces the profiled MonsterTruck executable's
`__text`, `__const` and `__cstring` sections exactly. The eight headless loaded
ramp approaches pass with the same binary, along with scene/input/HUD checks.
The standalone truck check matches the old Debug's 60-tick observation exactly;
the 120-tick comparison of one and four workers checks chassis, hubs, all tire
positions and velocities exactly at every tick and passes.

SoftTire's final native Debug profile averages 238.94 FPS over 12.003 seconds,
with 12.000 simulated seconds and a 24.1 ms maximum frame. A low-priority
compiler validation was active during that measurement, so it is a bounded
non-regression observation, not a matched-context speedup estimate. Its complete
physical and input/HUD checks pass; all 47 retained physical observation lines
match the earlier qualification reference exactly.

Compile timings from these context-sensitive runs do not establish an edit or
cold-build improvement. Unchanged executable-cache latency is a separate
measurement. No FPS claim is made for X64, Linux, Windows or LLVM.

## Reproduce from the workspace root

```sh
silex run Silex-Examples/Sources/Physics3D/MonsterTruck/Main.sx
silex run Silex-Examples/Sources/Physics3D/SoftTire/Main.sx
```

The `--profile`, `--profile-ramp` and `--profile-slope` application arguments
produce bounded graphical MonsterTruck measurements; SoftTire supports
`--profile`. Headless scene and physical checks use the same source entries.
The compiled standalone `MonsterTruck/Checks.sx` executable accepts `--compare`
to compare one and four physics workers exactly.
Compiler validation uses `zig build test-debug-copies` from `Silex/Toolchain/`
and the portable `Tests/Native/DebugCopies.sx` and `NativePortability.sx` entries.

## Validation boundary

The aggregate bootstrap, runtime and LSP tests pass all 1,650 cases (1,119
compiler, 506 LSP and 25 runtime tests). The optimizer admission control passes
its 84 tests and quick semantic corpus. The targeted Debug gate passes 22
tests. The complete native language suite
passes 279 tests in 111 files with normal workspace package resolution.
Result-call checks pass in the interpreter, native Debug and native Release;
linked native math checks pass in Debug and Release. The portable native entry
(including the new floating aggregate snapshot/loop regression) executes on
macOS ARM64 and macOS X64 through Rosetta. Linux and Windows ARM64/X64 emit
ELF/PE binaries for their requested architecture but are not executed here.

The aggregate `zig build check test -j2` command's CLI children set
`SILEX_USER_PACKAGE_ALLOWLIST=STD`. This excludes the user GFX link required by
the workspace's local Physics link, before source validation can run. Its
language, Result-call and native-math children fail on that package-resolution
condition; the normal-context replays above pass without altering any links.
The aggregate command must not be reported as green.

One unchanged MonsterTruck compilation reuses its executable before frontend
work in 0.852 seconds. Its preceding cache miss takes 34.961 seconds. These are
single context-sensitive samples and do not establish an edit-build or
cold-build speedup.
