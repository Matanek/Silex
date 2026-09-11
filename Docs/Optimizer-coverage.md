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
| `assurance.tsv` | Legacy state, historical timing proof count, currently timed corpus cases, bounded scope and owner per family |
| `llvm-operation-coverage.tsv` | Exhaustive IR operation classification shared with the actual emitter |
| `proof-scope.tsv` | Historical outcome and whether its recorded source still matches; neither identity state means a fresh campaign |
| `llvm-case-coverage.tsv` | Source hash, interpreter agreement, raw/Release emission result and unmodeled instruction tags per registered source |

The matrix owns every coverage family, registered pass, portable IR family and
LLVM transposition technique. Each family names existing positive and negative
regressions, preconditions, target scope, unresolved questions and a next
experiment. These associations identify relevant witnesses, not newly proved
exhaustiveness. Target names identify required scope, not executed hosts.
Tests reject missing families, techniques, negative cases, open questions,
unregistered sources and unowned passes. The matrix is checked by every oracle
command, including the mandatory quick gate. Admission prevents changing
`Assurance.json` in the same commit as compiler implementation, as it already
does for performance baselines. This separation does not replace review of a
contract-only change.

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

## Experiments selected by the audit

| General mechanism | Existing discriminant | Next proof and present limitation |
| --- | --- | --- |
| Constant and memory propagation | `ReadonlyViewMemory.sx` | LLVM folds an observed result to a constant; separate call specialization, bounds information and load forwarding |
| Range and signedness | `BranchingLoop.sx` | Advisor observes different signed/unsigned remainder operations; compare proven nonnegative variants with overflow and negative counterexamples |
| Reference helpers and target pressure | `Regressions/PureMathReferenceInlining.sx`, `Regressions/HotReferenceLeafClosure.sx` | Existing integration reductions preserve semantics, but do not emit through this LLVM bridge; isolate unsupported operations before claiming a direct LLVM comparison |
| Aggregate preparation | No autonomous full preparation reduction yet | Extract fixed/dynamic body, zero denominator, warm-start and alias variants; observe every prepared field and separate output-reduction cost |
| Register residence and barriers | `Regressions/X64RegionalBarriers.sx`, `Regressions/X64IndirectAggregate.sx` | Structural witnesses do not replace physical X64 execution or dynamic spill measurements |
| Lifetime and effects | `OwningCollectionCopy.sx`, `Regressions/TextOutputIntegrity.sx` | Separate value semantics from destruction, runtime and text costs that the bridge does not model |

The integration scan contains unsupported assertion/text/optional operations
and `boundary_call`; the larger leaf-closure case also contains
`collection_reference`. These are operation inventories of the composed program,
not a causal attribution to each hot helper. `X64IndirectAggregate.sx` isolates
`function_reference` and `indirect_call` directly. This gives the next reduction
a concrete starting point while preserving the missing execution proof.

The independent Physics stage witnesses are useful evidence sources, not a
replacement for this compiler corpus. Their integration ordering follows Box2D
and differs from some production Physics operations. Preparation times both
preparation and observation. Matching-slot and packed C layouts answer different
questions. Importing those witnesses requires preserving these boundaries and
numerical contracts; comparing whole engines alone cannot attribute the gap.

## Timing and qualification

`compare 11` is diagnostic. Qualified timing requires at least 21 paired samples,
a one-sided nonparametric median bound with at least 95% confidence, a maximum
spread of 200,000 ppm, and a cost-ratio upper bound no greater than 1,000,000 ppm.
The existing retry uses 63 samples. These policies are unchanged by this audit.
The current runner does not archive ordered raw timing observations or test
stationarity; this remains an explicit qualification gap. Do not use the three
successful scalar timings to qualify unmeasured families.

The pinned LLVM source identity, actual Clang executable, target triple and CPU
selection are distinct facts. In this audit Clang targets `apple-m1` on a physical
Apple M3 Pro; the CPU option is not the host identity. LLVM source-transposition
references are not proof that Apple's Clang binary was built from that exact
upstream revision. ARM64 measurements do not establish X64 performance.

A green coverage audit means that the bounded evidence is honestly inventoried.
The schema has no general-parity status. Broader qualification requires new
explicit evidence contracts and executions, not deletion of unresolved questions
or conversion of a historical status into a universal claim.
