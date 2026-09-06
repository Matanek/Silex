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
budgets; the initial Boids `steering` budget covers its field and collection
loads, checks, calls, branches, stack residence, frame size, and SIMD pairs.

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
semantic result.

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
  machine budget against its exact source hash;
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

Timing remains separate from correctness. The comparison runner builds each
candidate once, alternates execution order, and reports median, MAD, p10-p90,
and limitations. A noisy or too-short workload is diagnostic evidence, not a
performance verdict.
