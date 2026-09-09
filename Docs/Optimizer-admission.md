# Optimizer admission

Optimizer performance is protected by two complementary layers. The first is
autonomous and deterministic; the second selects expensive target and consumer
campaigns from the files changed by a candidate. Neither layer reads a Spec or
depends on a sibling repository merely to perform its local audit.

## The mandatory local path

From `Toolchain/`, every compiler change starts with:

```text
zig build check
```

`check` depends on `optimizer-admission-quick`. In addition to the compiler,
language and LSP tests, this gate audits the finite optimizer registry, runs the
fixed semantic and structural regression corpus, and executes the admission
matrix mutation tests. It rejects a relevant unclassified path, an admission
rule that omits the quick gate, and an implementation change that modifies its
protected performance baseline in the same slice.

The standalone commands are:

```text
zig build optimizer-admission -- admission-audit
zig build optimizer-admission -- admission-impact Toolchain/Sources/Optimize/Release.zig
zig build optimizer-admission -- admission-plan Toolchain/Sources/Optimize/Release.zig
zig build optimizer-admission-quick
```

`admission-impact` judges one commit and enforces protected-baseline separation.
`admission-plan` computes the union of required checks for a multi-commit pull
request. CI uses both: it plans the complete range, then audits every commit
that touched a protected contract so a legitimate earlier baseline commit does
not make a later implementation commit ineligible.

`Toolchain/Benchmarks/Optimizer/Admission.json` is the machine-readable impact
matrix. Its output names stable check identifiers, GitHub status contexts and
the exact command or owning workflow. `PerformanceBaselines.json` preserves the
accepted Boids control and the known Boids and Preparation residuals. A change
to that protected contract must be reviewed and committed separately from the
compiler implementation it will judge.

## Qualified checks selected by impact

A change under compiler semantics, typed or machine IR, Release optimization,
runtime, ARM64 or X64 selects all of these checks:

- `optimizer admission / quick` — `zig build check` on the exact candidate;
- `optimizer admission / qualified internal` — the complete semantic, native,
  differential, LLVM and structural `optimizer-gate`;
- `optimizer admission / robustness` — the qualified adversarial campaign;
- `optimizer admission / native portability` — native execution and linkage on
  every affected distributed target;
- `optimizer admission / external qualification` — the selected
  Silex-Benchmarks campaign against the exact Silex SHA.

The repository workflow `optimizer-admission.yml` runs the quick layer for pull
requests and pushes to `main`, preserves its impact plan as an artifact, and
fails before tests when a relevant path has no rule. Repository branch
protection must require the status contexts above according to the plan. A
workflow file cannot itself make its own check required; that is a GitHub
repository rule-setting responsibility.

Qualified and external statuses are never inferred from a local claim. They
must belong to the exact candidate SHA; missing, cancelled, stale or
inconclusive evidence is not green. The external owner retains raw samples,
binary hashes, target identity, closure and benchmark revision. GPU execution
is required on physical macOS ARM64. On macOS X64, Linux and Windows the GFX
sentinels compile and link in Debug and Release while SDL3 owns the unavailable
physical GPU boundary; CPU campaigns remain native and blocking.

## Fixing a regression revealed by an application

An application such as Boids remains a sentry, not an optimizer special case.
Keep its complete campaign external, reduce the compiler-owned loss to an
autonomous fixture in Silex, fix the general property, and run every check
selected by the impact matrix. Never compensate in the package or change the
baseline in the optimizer commit.

The current integrated candidate intentionally does not claim completed LLVM
parity. `PerformanceBaselines.json` records the Boids regression lead and the
Preparation interval transferred to
`Silex-Optimization-Parity-Completion`. Admission protects the correctness,
structure and measured gains already acquired while that continuation closes
the remaining performance gaps.
