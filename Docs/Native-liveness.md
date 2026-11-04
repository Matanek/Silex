# Native liveness

`Arm64/ResidenceLiveness.compute` returns the same instruction-by-slot boolean
matrix consumed by the native register allocators. It solves the conventional
least fixed point:

```text
live_in = uses | (live_out & ~definitions)
live_out = union(live_in of each CFG successor)
```

Uses and definitions are computed once from the existing instruction rules.
The fixed-point sweeps operate on 64 slots at a time, with the same reverse
instruction order and successor rules. Every unused bit in a partial word
starts at zero and remains zero. Instructions that both read and define a
slot keep it live, as in the scalar solver. Unreachable rows are still solved;
this change neither removes instructions nor changes register policies.

The result is materialized back into the original dense boolean layout.
Transfer masks are released before allocating that result. Temporary bitsets
use a 4 KiB stack fallback and page-backed overflow local to the solve, rather
than retaining tables in a program-wide result arena. The surviving bitset
requires one eighth of the dense matrix's storage, rounded to whole words;
transfer masks exist only during the fixed point.

## Correctness and target impact

`ResidenceLivenessTests.zig` retains the former scalar solver as a differential
oracle. It compares every output bit on 192 deterministic CFG variants at
1, 31, 63, 64, 65, 127, 128 and 129 slots, including back edges, self loops,
branches, redefinitions, overlapping copies and returns. Independent expected
matrices cover branches, loops and unreachable rows. A bounded output allocator
checks that temporary tables do not consume or survive in result storage.

The solver is shared by ARM64 allocators and parts of X64 allocation. Its
implementation is applicable on all six distributed targets: macOS, Linux and
Windows, ARM64 and X64. The tests prove a target-independent boolean result;
they do not constitute six native executions or six performance measurements.
The instructions, calling conventions, allocation policy and emitters are
unchanged. Compiler-wide checks and native consumer validation remain required.

## Performance qualification

Compilation measurements must pin compiler binaries, sources, packages,
external tools, worker count and cache state. Compare complete successful
compilations, independently of profiles and compilation failures. Bootstrap
build time for the Zig implementation is a different metric. No gain or runtime
ratio is claimed from the representation alone.
