# Native register conflict queries

The graph allocator keeps its existing ordering, aliases, register preferences
and destructive-sharing rules. It changes only how it finds instruction points
at which two slots can interfere.

## Immutable facts and lifetime

After liveness has been adjusted for incoming captures, reference cursors and
deferred packed operands, `Arm64/ResidenceConflicts.zig` transposes the live rows
into per-slot 64-bit words. It also records each slot's definitions and a shared
mask of class-load instructions. For slots A and B, possible ordinary conflicts
are:

```text
(liveA & (liveB | definitionsB)) | (definitionsA & liveB)
```

Only set bits need the existing destructive-sharing predicate. Simultaneous
class-load definitions conflict even when both leaves are dead; this remains a
separate condition. A word containing no possible conflict needs no emitter or
successor inspection. Neither alias roots nor register colors are cached.
Coalescing keeps its former scan and its distinct class-definition policy.

With I instruction points and S slots, the table uses
`8 * (2*S + 1) * ceil(I/64)` bytes. Construction inspects I*S instruction/slot
pairs once per nonempty graph. A pair query scans at most `ceil(I/64)` words,
plus the remaining possible sharing points. Unlike a pair cache, storage is
bounded by the instruction/slot matrix rather than S*S distinct queries.
A conflict found immediately is the important negative control: precomputation
can cost more than its former one-point scan, so whole-program and small-entry
guards remain necessary.

Scratch uses a local stack fallback and page allocator, then is released before
returning from the graph. It is not retained in the program's result arena.
Graphs with no intervals return without building liveness or conflict facts.
The small follow-up queries for loaded floating values retain the scalar scan.

## Correction and target impact

The former pair scan is retained as `scalarInterferes`. Every compact query in
unit-test builds is checked against it, including allocator tests exercising
captures, aliases, loops, calls, integer/float banks and packed operands.
`ResidenceConflictsTests.zig` also compares all slot pairs on deterministic live
matrices with dead, dense, sparse and random rows at 0, 1, 63, 64, 65, 127, 128
and 129 instructions. Explicit cases cover dead class leaves and destructive
copies crossing a loop. Arbitrary matrices test the representation independently
of the liveness solver; adjusted rows model capture and deferred-operand facts.

The ARM64 graph is used on macOS, Linux and Windows ARM64. X64 also consumes
this graph for some floating scalars on its three systems. Its integer graph
has a separate conflict scan and different sharing/capture rules; that applicable
path is not optimized by this change. The scalar liveness/coalescing policy,
emitters and system adapters are unchanged.

Boolean equivalence and identical emitted artifacts are separate evidence from
native execution, performance and distribution. Local macOS ARM64 execution does
not establish five other native executions or an X64 speedup. A performance
claim requires pinned binaries and inputs, balanced before/after acquisitions,
stationary reference controls and the existing latency, memory and size guards.
Instrumented visit counts establish the repeated work, not elapsed-time gains.

## Local compilation qualification

The [measurement record](Native-conflicts-measurements.json) preserves the raw
process observations, paired blocks, primers, phase timings, counters, compiler
hashes, dependency heads, tool hashes and local native-archive hashes. It compares
accepted source `c10b881` with implementation `9bacfb8` on macOS 26.6.2 ARM64,
Apple M3 Pro, ReleaseFast bootstrap, native backend:

| Boids configuration | Reference median | Candidate median | Reduction |
| --- | ---: | ---: | ---: |
| Debug | 6.245 s | 5.804 s | 7.1% |
| Release | 22.730 s | 10.833 s | 52.3% |

The upper one-sided 95% ratio bounds are 0.932 and 0.479, respectively. The RSS
upper bounds remain at most 1.013 across all configurations; executable sizes
are identical. Tokenizer, integer control flow, protocol defaults and aggregate
control flow pass their latency, memory and size guards in both modes. Small
entries use the declared absolute 50 ms allowance; relative percentages on
millisecond entries do not represent useful speedups or a universal +5% bound.

Each configuration uses six independent paired blocks, with alternating AB/BA
order and explicit primers. Boids uses one compilation per point. The eight
short configurations use three subpairs per block. The reported effect is the
median of all raw process durations. Confidence intervals resample paired blocks
10,000 times while keeping their observations together. RSS uses each block's
maximum process RSS, without smoothing. All 156 measured subpairs, comprising
312 compilations, emit identical executables. Console observables pass; Boids
is compiled without opening its application. Twenty primers remain separate.

Silex reuse is disabled. Each process uses a fresh temporary Zig linker cache,
removed after acquisition; OS caches remain active. Default compiler workers
and priority `nice 10` are recorded. Inputs and tools were verified unchanged
before and after the campaign, including fourteen local native archives.

Earlier controls had unstable absolute latency and remain excluded. After a
quieter execution window changed the host's execution rate, a preliminary mixed
control still showed a common Tokenizer Release shift; it did not establish
global stationarity. Final configurations were measured independently and each
passed its own reference stability and non-regression guards. The C/C practical
equivalence test was specified before this candidate campaign: its whole bilateral
95% interval must fit inside the existing tolerance, rather than merely fail to
reject exact equality. The record retains the control outcomes and this limit.
No observation is selected from a stopped cohort or normalized by CPU speed.

These are incremental compilation results against the latest accepted source,
not cumulative ratios against a reference measured under another host regime.
The frontend target, LLVM compatibility, package reuse and the other five native
executions retain separate gates. Generated code is unchanged; no runtime speedup
or performance result on another architecture is claimed.
