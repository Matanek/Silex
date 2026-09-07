# Optimizer oracle and coverage registry

The development oracle under `Toolchain/Tools/OptimizerOracle/` compares the
raw and Release portable IR, reference interpretation, native Debug and
Release execution, and a pinned Clang/LLVM `-O3` configuration. LLVM output is
never consumed by the Silex compiler.

`Toolchain/Benchmarks/Optimizer/Coverage.json` is the machine-readable control
plane. It pins the Clang executable identity separately from the upstream LLVM
source revision, target triple, CPU, features, floating-point policy, linker,
and libraries. It also records immutable and diagnostic baselines, the exact
workspace closure, every portable and machine IR operation, Release pass
descriptors, coverage verdicts, interaction seeds, metamorphic axes, sealed
qualification projects, and the LLVM technique-transposition map.
Real-consumer hot functions have source hashes and directional structural
budgets. Alongside the initial Boids `steering` sentinel, the registry covers
the Physics contact and preparation kernels and two independent font-raster
functions. These budgets measure field and collection loads, checks, calls,
branches, stack residence, frame size, SIMD pairs, and recognized ARM64
post-indexed and pointer-terminated collection cursors without executing or
timing the complete consumer. `machine_stack_slots` counts machine slots that
do not receive whole-function register residence; it is not a count of dynamic
stack accesses in the hot loop. A consumer can therefore improve its loop
shape while retaining a separate register-allocation gap. Directional caps use
the last qualified real-consumer baseline, not an obsolete checked-in
observation; the coverage entry keeps that remaining gap assigned to its
owning Part.

The registry audit fails when an IR operation, terminator, named type, machine
operation, or Release pass is missing or duplicated. An `equivalent` coverage
entry must carry semantic, cost-model, Debug, Release, structural, and target
proofs. A `gap` remains visible with the Part that owns its resolution; it is
not interpreted as a passing parity claim.

Run commands from `Silex/Toolchain/`:

```text
zig build optimizer-oracle -- audit
zig build optimizer-oracle -- passes
zig build optimizer-oracle -- verify
zig build optimizer-oracle -- verify-prefix control_flow_inlining
zig build optimizer-oracle -- verify-without aggregate_scalarization_post
zig build optimizer-oracle -- cache-proof
zig build optimizer-oracle -- metamorphic
zig build optimizer-oracle -- qualify 8 1
zig build optimizer-oracle -- fuzz 100 1
zig build optimizer-oracle -- fuzz-llvm 16 1
zig build optimizer-oracle -- compare 11
zig build optimizer-gate
```

`audit` verifies the checked-in schema, the exact workspace and sealed-corpus
baseline recorded in Git history, exact sealed source hashes, and writes a
deterministic pairwise/risk-triplet plan. Later repository commits do not
rewrite the immutable baseline, while a changed sealed source fails the audit.
LLVM commands additionally refuse a different Clang version or host triple.
`cache-proof` builds each selected case without cache, after priming, and from
a warm hit, then compares executable hashes and outputs. `metamorphic` executes
equivalent source-shape pairs through the interpreter and both native modes;
its report records structural equivalence or a named gap without hiding the
semantic result. Fixed qualification cases also carry deterministic structural
contracts for aggregate scalarization, reference dead-store elimination,
mutable-view forwarding, and owning-list copy-on-write. The qualification gate
reruns the reference and view contracts with `reference_memory_elision`
disabled, proving that their measured memory reduction is attributable to the
registered pass while negative alias observations remain intact.
Native regression contracts also inspect the allocated ARM64 machine function
for a recognized post-indexed collection cursor and, when required, its direct
pointer termination. This makes a reduced unit-stride loop an independent
structural witness instead of inferring the mechanism from a consumer timing.

Profile a real package consumer from the root of its closed Spec worktree so
the command resolves that worktree's package links:

```text
zig build --build-file Silex/Toolchain/build.zig optimizer-oracle -- \
  hot-budget Silex-Benchmarks/Sources/Boids2D/Silex.sx \
  Boids2D.Silex.steering
```

Generated evidence is recreated under `.zig-cache/optimizer-oracle/`:

- `coverage-plan.tsv` contains the seeded pairwise and risk-triplet plan;
- `cache-proof.tsv` contains cold, primed, warm, and output hashes;
- `metamorphic.tsv` records the structural class of equivalent source forms;
- `hot-budget.tsv` records the selected real function's Release IR and ARM64
  machine budget against its exact source hash, including SIMD-pair and loop-
  cursor counts;
- `*-raw.sir` and `*-silex.sir` preserve the deterministic portable IR before
  and after Release optimization for direct attribution of every reported gap;
- `report.tsv` includes source and executable hashes, LLVM source revision,
  target, CPU, robust timing statistics, and binary size;
- `opportunities.tsv` ranks measured structural gaps against LLVM.

Opportunity profiles compare only the optimized functions corresponding to
portable Silex functions. They exclude the generated ABI `main` wrapper and do
not compare how much work two differently shaped raw frontends happened to
remove. Loop block differences accompanied by LLVM PHI creation are attributed
to loop rotation and induction analysis rather than generic CFG cleanup.
Plain value structures are emitted as typed LLVM aggregates. Their residual
construction, projection, copy, parameter, and return operations are compared
separately from LLVM's internal `{result, overflow}` intrinsic pairs, so those
pairs cannot hide a missing Silex scalar-replacement transformation.
Mutable references to those structures are emitted as LLVM pointers with typed
field addresses, loads, and stores. The advisor conservatively compares Silex
reference traffic with all remaining LLVM loads and stores: this can hide an
opportunity but cannot invent one by assuming two references are disjoint.
Unused Silex reference reads are removable, while reads separated by a write
through a possibly aliasing reference remain observable and are preserved.
After local dead-read cleanup, `reference_memory_elision` follows explicit
same-block address derivations to remove an exactly overwritten store or
forward an exact post-store load. A different reference root is never assumed
disjoint: a read through it invalidates dead-store evidence, and calls, unknown
memory effects, and block boundaries invalidate both transformations.

Scalar read-only collection views are emitted to LLVM as `{data, count}`
values. The oracle models list literals with non-owning stack storage, view
construction, signed negative-index normalization, and checked element loads.
For owning scalar lists, retains and drops have no LLVM-side lifetime effect;
instead, each functional owning replacement allocates and copies its input
storage before the checked write. This deliberately models Silex copy-on-write
value semantics rather than its reference-count implementation. A source list
and its updated result therefore remain independent, while LLVM can eliminate
the allocation and copy when their observable scalar values make that legal.
Resource-bearing elements and ownership edges remain unsupported rather than
being approximated with different lifetime semantics.

Mutable scalar views use the same `{data, count}` representation, but
`collection_replace` becomes a checked store through `data`. On an exact
same-view, same-index chain with no intervening observable or possibly aliasing
instruction, Release may discard an overwritten store and forward a following
exact load from the surviving store.
Any access through another view is treated as possibly aliasing and ends the
proof. The oracle counts checks attached to collection replacement and element
references as safety guards, not only checks attached to collection loads.
Generated qualification also combines a nested scalar aggregate, an owning
copy-on-write snapshot, a temporary mutable view, a loop, and a branch in one
program. This interaction case is compiled and executed through the same
semantic and structural matrix as the sealed corpus.

Hot-function analysis closes the selected function over its exact transitive
program scope before Release optimization and native lowering. Function
identities therefore remain stable for direct callees such as scalar math
helpers, while unrelated unreachable generic or backend variants cannot affect
the selected budget.

Within one block, a successful checked load from an unchanged collection proves
that the collection is non-empty. Release optimization uses that fact for a
later `[-1]` access to materialize `count - 1` in portable IR before marking the
load unchecked. The explicit normalized index is required by the native backend
contract; merely clearing the checked flag would change program semantics.

When LLVM removes local memory or aggregate operations only in callers whose
calls it also inlined, the advisor attributes that causal difference to
interprocedural specialization instead of reporting duplicate memory and
aggregate findings. The independent callee remains available for direct
reference-memory comparison.

Timing remains separate from correctness. The comparison runner builds each
candidate once, alternates execution order, and reports median, MAD, p10-p90,
and limitations. A noisy or too-short workload is diagnostic evidence, not a
performance verdict.
