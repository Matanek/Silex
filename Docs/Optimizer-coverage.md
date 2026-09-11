# Scope of optimizer evidence

The optimizer registry describes implemented mechanisms and a bounded corpus.
An `equivalent` coverage row or an `adapted` LLVM technique does not establish
performance parity for every program using that mechanism. Read those states
alongside `Toolchain/Benchmarks/Optimizer/Assurance.json`.

## Reproduce the audit

Run these development commands from `Silex/Toolchain` (or the corresponding
compiler worktree). The audit does not require GFX, a GPU, or an old Spec capsule:

```sh
zig build optimizer-oracle -- coverage-audit
zig build optimizer-oracle -- coverage-scan
zig build optimizer-admission-quick
```

`coverage-audit` checks the matrix, verifies the recorded source bytes at each
historical compiler proof revision in Git, and compares those bytes with the
current source. It requires the recorded compiler history to be available.
It deliberately does not certify external repository closures. The existing
`parity-audit` and final qualification retain those independent checks.

`coverage-scan` additionally composes every distinct registered corpus and
regression source, compares raw and Release interpreter observations, and tries
to emit both programs through the LLVM bridge. Sources importing `STD.Math`
require the ordinary local STD package link. Run the scan in the established
workspace or Spec worktree group; no GFX package is required. Unsupported types
and instructions appear as limitations; other failures stop the scan and retain
`llvm-case-coverage.partial.tsv`. An emitted LLVM program has not thereby been
compiled or executed by LLVM.

Reports are written under `Toolchain/.zig-cache/optimizer-oracle/`:

| Report | Meaning |
| --- | --- |
| `assurance.tsv` | Legacy state, timing evidence, interaction/proof/budget link counts, explicit budget-gap state, bounded scope and owner per family |
| `llvm-operation-coverage.tsv` | Exhaustive IR operation classification shared with the actual emitter |
| `proof-scope.tsv` | Historical outcome and whether its recorded source still matches; neither identity state means a fresh campaign |
| `llvm-case-coverage.tsv` | Source hash, interpreter agreement, raw/Release emission result and unmodeled instruction tags per registered source |
| `timing-observations.tsv` | Ordered paired timings, execution order, per-pair ratio and explicit diagnostic/qualified evidence mode |
| `timing-profile.tsv` | Actual host OS, process/hardware architecture, CPU model, translation state and distinct LLVM target/CPU selection |

The matrix owns every coverage family, registered pass, portable IR family and
LLVM transposition technique. Each family names existing positive and negative
regressions, preconditions, interaction axes, risk triplets, historical proofs,
target scope, unresolved questions and a next experiment. It also names every
applicable registered hot-function budget. A family without such a budget must
carry an explicit gap instead of an empty unexplained list. These associations
identify relevant witnesses, not newly proved exhaustiveness. Target names
identify required scope, not executed hosts.

Tests reject missing families, techniques, negative cases, open questions,
unregistered sources, stale proof identifiers, unknown interactions or budgets,
unowned passes and any registered proof, interaction or hot budget left without
a family. They also reject a missing or contradictory budget decision. The
matrix is checked by every oracle command, including the mandatory quick gate.
Admission prevents changing `Assurance.json` in the same commit as compiler
implementation, as it already does for performance baselines. This separation
does not replace review of a contract-only change.

## Current measured boundary

The initial audit is preserved in
[`Audits/2026-09-11-coverage`](../Toolchain/Benchmarks/Optimizer/Audits/2026-09-11-coverage/README.md).
It finds 13 legacy coverage families, 15 transposition techniques and 13 passes.
The fixed corpus contains 16 cases; only `IntegerArithmetic.sx`,
`BranchingLoop.sx` and `FloatArithmetic.sx` are timed by `compare`.
The union with registered regressions contains 50 distinct sources.
All 50 pass interpreter comparison; only 22 emit through LLVM in both modes.
The other 28 therefore cannot be counted as LLVM execution comparisons.
The scan is whole-program emission: one unsupported operation can prevent an
otherwise supported hot function from being compared.

The bridge conditionally handles 24 of 69 instruction tags and abstracts two
more (`list_retain` and `list_drop`). Forty-three tags are unsupported.
Support also depends on operand type and operation shape: an instruction-tag
inventory alone overstates coverage. Scalar collection values model copy-on-write
independence, but not reference-count traffic, destruction or allocation cost.
Strings, classes, protocols, globals, several callable forms and resource-bearing
values remain outside this bridge. Failure paths use LLVM traps rather than
Silex diagnostic text. See [the bridge contract](Optimizer-oracle.md).

`LlvmCoverage.zig` classifies the complete instruction union without a default
branch. Adding an IR operation requires an explicit bridge decision. Emission
consults that same classification before lowering an instruction.

Thirteen compiler proof sources match their recorded historical revisions.
Source identity alone does not reproduce an execution. The legacy `result`
hash protects a descriptive result string, not the raw observations of an
entire campaign. New qualifications must seal the actual commands, inputs,
closure, target, binaries and observations; old evidence remains historical.

## Extension to aggregate views

The follow-up audit in
[`Audits/2026-09-11-aggregate-views`](../Toolchain/Benchmarks/Optimizer/Audits/2026-09-11-aggregate-views/README.md)
adds three autonomous, untimed sources. The fixed corpus now has 19 cases;
the corpus/regression union has 53. All 53 agree in raw/Release interpretation,
and 26 emit LLVM in both modes. The bridge now models 25 instruction tags
conditionally, abstracts two lifetime tags and rejects 42 others.

The three new sources separate aliasing/copy semantics, damping/translation and
effective-mass preparation. They enabled a direct LLVM comparison that exposed
an ARM64 overlapping-fusion correctness defect and a native-test C ABI defect.
The compiler regressions are independent of Physics. Remaining full-stage
observations, resource lifetimes, numerical edge policies and timing contracts
remain open; the initial audit above is preserved as historical evidence.

## Extension to pure scalar math boundaries

`PureMathReferenceInlining.sx` and `HotReferenceLeafClosure.sx` are now untimed
members of the executable corpus. The fixed corpus therefore contains 21 cases;
the corpus/regression union remains 53 distinct sources. All 53 agree in
raw/Release interpretation, and 28 emit LLVM in both modes. The bridge now
classifies 26 instruction tags as conditional, abstracts two lifetime tags and
rejects 41 others.

LLVM emission keeps only the direct execution closure rooted at `main`, using
the same reachability rule as structural comparison. Unreachable package
helpers can no longer reject a valid executable surface because they format a
diagnostic or use another unsupported feature. Calls from a reachable function
still make their callee reachable, and unsupported reachable operations still
fail emission.

Direct `boundary_call` emission is limited to the typed scalar system-math
contract already used by the interpreter and optimizer. The boundary must have
a recognized math symbol, exact float precision and arity, and a trusted
provider or explicit system-math provenance. Custom, package-private or
signature-mismatched boundaries remain unsupported. The differential result
retains this metadata through raw and Release emission; corpus entries that
need package composition opt into project compilation explicitly.

Both probes print independent boolean observations rather than relying on the
runtime assertion/text path. Their interpreter, native Silex, raw LLVM and
Release LLVM outputs agree. `HotReferenceLeafClosure.sx` now observes position,
rotation, both speed-cap branches and their numeric bounds.
`PreparationMasses.sx` also observes separation, dynamic/static relative
velocity and the selected bias, mass and impulse softness scales. These reduced
contracts exclude graph lookup, ownership and multi-point contact assembly.

## Experiments selected by the audit

| General mechanism | Existing discriminant | Next proof and present limitation |
| --- | --- | --- |
| Constant and memory propagation | `ReadonlyViewMemory.sx` | LLVM folds an observed result to a constant; separate call specialization, bounds information and load forwarding |
| Range and signedness | `BranchingLoop.sx` | Advisor observes different signed/unsigned remainder operations; compare proven nonnegative variants with overflow and negative counterexamples |
| Reference helpers and target pressure | `Regressions/PureMathReferenceInlining.sx`, `Regressions/HotReferenceLeafClosure.sx` | Both execute through LLVM and cover the linear/angular caps; obtain physical X64 pressure before changing the current out-of-line policy |
| Aggregate preparation | No autonomous full preparation reduction yet | Extract fixed/dynamic body, zero denominator, warm-start and alias variants; observe every prepared field and separate output-reduction cost |
| Register residence and barriers | `Regressions/X64RegionalBarriers.sx`, `Regressions/X64IndirectAggregate.sx` | Structural witnesses do not replace physical X64 execution or dynamic spill measurements |
| Lifetime and effects | `OwningCollectionCopy.sx`, `Regressions/TextOutputIntegrity.sx` | Separate value semantics from destruction, runtime and text costs that the bridge does not model |

`X64IndirectAggregate.sx` still isolates `function_reference` and
`indirect_call` directly. Those callable forms remain outside the bridge and
preserve a concrete starting point for the physical X64 experiment.

The independent Physics stage witnesses are useful evidence sources, not a
replacement for this compiler corpus. Their integration ordering follows Box2D
and differs from some production Physics operations. Preparation times both
preparation and observation. Matching-slot and packed C layouts answer different
questions. Importing those witnesses requires preserving these boundaries and
numerical contracts; comparing whole engines alone cannot attribute the gap.

## Timing and qualification

`compare 11` is diagnostic. Qualified timing requires at least 21 paired samples,
a one-sided nonparametric median bound with at least 95% confidence, a maximum
spread of 200,000 ppm, a maximum 100,000 ppm shift between the medians of the
ordered half-windows for Silex, LLVM and their paired ratio, and a cost-ratio
upper bound no greater than 1,000,000 ppm. The middle observation is excluded
from the half-window comparison. The existing retry uses 63 samples.

Every current comparison archives the observations in acquisition order and
the backend executed first for each alternating pair. Reports label a run
`diagnostic` unless the blocking parity gate requested qualification. The host
profile is recorded independently of the LLVM target and CPU options; a
translated process is rejected for qualification. Historical scalar proofs
without these artifacts remain historical and cannot acquire the new
qualification contract retroactively. Do not use them to qualify unmeasured
families.

The pinned LLVM source identity, actual Clang executable, target triple and CPU
selection are distinct facts. In this audit Clang targets `apple-m1` on a physical
Apple M3 Pro; the CPU option is not the host identity. LLVM source-transposition
references are not proof that Apple's Clang binary was built from that exact
upstream revision. ARM64 measurements do not establish X64 performance.

A green coverage audit means that the bounded evidence is honestly inventoried.
The schema has no general-parity status. Broader qualification requires new
explicit evidence contracts and executions, not deletion of unresolved questions
or conversion of a historical status into a universal claim.
