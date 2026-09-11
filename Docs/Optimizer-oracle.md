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

Schema version 2 replaces free-form evidence strings with `proof_ids`. Every
identifier resolves through the top-level proof catalog to a repository and
ancestor revision, a source and SHA-256, the exact command and configuration,
the expected observation, and the result with its own SHA-256. The audit
rejects unknown identifiers, source hashes inconsistent with the recorded Git
revision, stale result hashes, and duplicate references. Historical proof sources
are read from that revision, not from the current working tree: extending the
oracle does not rewrite an older proof or turn it into a current execution. A closed coverage or LLVM-transposition entry may reference only
passed proofs; `diagnostic-red` results remain usable to explain an open gap
but cannot close it.

Fixed native regressions can also carry target-specific regional budgets.
`X64RegionalBarriers.sx` requires its direct call and aggregate construction to
survive portable optimization; `X64IndirectAggregate.sx` independently retains
a four-leaf aggregate, a function value, and an indirect call. Their contracts
fix direct and indirect call counts, aggregate width, register residences,
values without residence, physical frame slots and frame bytes. They also walk
every machine instruction in each backedge region and count every possible
value-frame load and store. A zero upper bound is exact even when a later X64
peephole elides an access, so both witnesses require zero dynamic stack traffic
in their hot loops. The physical frame may contain more slots than the number
of spilled values: contraction can omit only a contiguous resident prefix
while preserving the virtual offsets of all remaining addressable homes.

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
zig build optimizer-parity-gate
zig build optimizer-admission -- admission-audit
zig build optimizer-admission -- admission-impact Toolchain/Sources/Optimize/Release.zig
zig build optimizer-admission -- admission-plan Toolchain/Sources/Optimize/Release.zig
zig build optimizer-admission-quick
```

The permanent admission contract and the distinction between the mandatory
quick gate and impact-selected qualified campaigns are documented in
[`Optimizer-admission.md`](Optimizer-admission.md). `zig build check` depends on
the autonomous quick gate; full performance timing remains separate from
correctness assertions.

`audit` verifies the checked-in schema, the exact workspace and sealed-corpus
baseline recorded in Git history, exact sealed source hashes, and writes a
deterministic pairwise/risk-triplet plan. Later repository commits do not
rewrite the immutable baseline, while a changed sealed source fails the audit.
When at least one registered sibling repository is present, workspace mode
requires every registered repository and validates the complete closure. A
standalone `Silex` checkout with no sibling repository instead validates every
compiler-owned revision and source hash locally while retaining the sealed
external records in the registry. This makes source exports independently
auditable without allowing a partially populated workspace to pass as a full
qualification environment.
An external workspace anchor may carry an explicit `reconciliation` when its
historical branch was never merged into the current package line. This record
keeps the original revision and adds a candidate ancestor of HEAD, their exact
common ancestor, both tree identities, a SHA-256 of their deterministic Git diff,
and a reason for the replacement. It applies only to that repository and that
original revision. Compiler anchors cannot use this mechanism. Missing history,
wrong ancestry, a different tree or an unreviewed delta fail qualification;
other revisions retain the ordinary ancestry check. This is a reviewed closure
change, not a claim that the two package trees are equivalent.

Sealed corpus and hot-function sources must match their hashes both at the
original revision and in the current working tree. Historical proofs instead
bind their recorded source revision; their status never substitutes for running
the current gate. The GFX.ECS reconciliation and fresh package/consumer evidence
are recorded in
`Toolchain/Benchmarks/Optimizer/Audits/2026-09-11-ecs-reconciliation/`.

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
The loop corpus additionally covers signed and unsigned inductions, nested
loops, `break`, `continue`, dynamic bounds, strided accesses and contiguous
floating recurrences. Its `while`/`for` metamorphic pair compares the hot-loop
quality class—blocks, branches, backedges, checks, calls and memory traffic—so
front-end iterator bookkeeping cannot either hide or invent a loop-quality
regression. Target-cost unit counterexamples cover packing, extraction, spill,
call and code-size cliffs; native SLP contracts then require both ARM64 and X64
realization where the complete reduced kernel is profitable. Requirements are
recorded per target: the pinned ARM64 LLVM oracle materializes the loop-exit
XY and XYZW witnesses as `<2 x float>` and `<4 x float>`, while the simple XYZ
control remains scalar. Silex must recognize portable widths 2, 3, and 4, but
only profitable target realizations are mandatory. The comparison command
checks the expected LLVM width and the corresponding Silex ARM64 native pair;
an already realized native pair suppresses a false portable-IR vectorization
gap in the advisor. Integer-to-floating-point conversions used by these
witnesses preserve signedness and Silex's exact-conversion failure through a
saturating LLVM round trip before the value may continue.

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
- `hot-budget.sir` preserves the optimized closed program used by that real-
  consumer measurement, and `hot-budget-machine.json` exposes the selected
  ARM64 function, including its instructions and register residences. Both are
  emitted before budget validation so a rejected candidate remains
  attributable without weakening the budget;
- `*-raw.sir` and `*-silex.sir` preserve the deterministic portable IR before
  and after Release optimization for direct attribution of every reported gap;
- `report.tsv` includes source and executable hashes, LLVM source revision,
  target, CPU, robust timing statistics, and binary size;
- `opportunities.tsv` ranks measured structural gaps against LLVM.

Vector opportunities compare LLVM IR with Silex native backend evidence, not
only with portable Silex IR. Portable IR intentionally carries lane affinity as
metadata rather than inventing target vector instructions, so an ARM64 pair
that already realizes the oracle's transformation is not reported again as a
missing optimization.

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

Collections of scalar values and plain nested aggregates are emitted to LLVM
as `{data, count}` values. List literals use heap storage because they can escape
their creating function. Element strides and allocation sizes follow LLVM typed
GEP layout, including padding. The bridge models view construction, signed
negative-index normalization, checked loads and borrowed element references.
View bounds normalize negative offsets, clamp each endpoint to `[0, count]`,
and produce an empty view when the end precedes the start, matching the
interpreter and native backends. Construction does not trap for these bounds;
an invalid element access still does. `KnownViewElements.sx` compares clamped,
nested and empty views against LLVM as well as both native Silex modes.
Owning element references requiring copy-on-write detachment remain unsupported.
For owning lists, retains and drops have no LLVM-side lifetime effect;
instead, each functional owning replacement allocates and copies its input
storage before the checked write. This deliberately models Silex copy-on-write
value semantics rather than its reference-count implementation. A source list
and its updated result therefore remain independent, while LLVM can eliminate
the allocation and copy when their observable scalar values make that legal.
Resource-bearing elements and ownership edges remain unsupported rather than
being approximated with different lifetime semantics.

Mutable views of plain values use the same `{data, count}` representation, but
`collection_replace` becomes a checked store through `data`. On an exact
same-view, same-index chain with no intervening observable or possibly aliasing
instruction, Release may discard an overwritten store and forward a following
exact load from the surviving store.
Any access through another view is treated as possibly aliasing and ends the
proof. The oracle counts checks attached to collection replacement and element
references as safety guards, not only checks attached to collection loads.
Before LLVM emission, multiply-defined portable virtual registers receive local
homes and explicit edge stores/loads. This preserves short-circuit effects and
loop edge copies without treating portable IR as SSA or applying Silex Release
optimization to the raw oracle input. LLVM performs its own promotion. Exact
`float32` to `float64` widening uses `fpext`; narrowing remains unsupported.

Emission follows the closed function graph rooted at `main`. It does not emit
unreachable package helpers, matching native dead-function removal and the
reachability basis used by structural statistics. A reachable unsupported
instruction still rejects the program. Direct boundary calls are emitted only
when `Boundary.isPureScalarMath` proves a recognized system-math symbol with an
exact scalar float signature and trusted provenance. Their declarations and
calls preserve the source symbol and precision. Other native boundaries,
indirect boundary calls and mismatched signatures remain unsupported.

The autonomous `AggregateViewAliasing.sx`, `DampedIntegration.sx` and
`PreparationMasses.sx` cases exercise mixed-width padded elements, escaping
literals, aliasing, independent copies, reference helpers, damping/translation,
effective masses, warm impulses, separation, relative velocity and dynamic or
static softness selection. The `PureMathReferenceInlining.sx` and
`HotReferenceLeafClosure.sx` corpus cases add scalar square root/copy-sign
boundaries, rotation and independent linear/angular speed caps. They observe
deterministic values and are not timed. They do not cover graph lookup,
multi-point contact assembly or ownership. Their abstract lifetime model cannot
qualify allocation, destruction or reference-count costs.

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

For the distinction between a closed registry and general compiler parity, see
[scope of optimizer evidence](Optimizer-coverage.md). The coverage audit records
unsupported cases and historical proof identity without promoting either to
current LLVM execution evidence.
