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
