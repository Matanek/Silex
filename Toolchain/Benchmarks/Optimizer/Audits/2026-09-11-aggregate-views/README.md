# Aggregate views and independent LLVM comparisons

This continuation preserves the initial coverage audit and its pinned proofs.
It expands the compiler corpus without using a GFX consumer as the oracle.
The enclosing commit and `Manifest.json` identify the candidate sources and
captured commands; source identity is separate from execution evidence.

## Bounded cases

- `AggregateViewAliasing.sx`: mixed float/int8/float64 layout, negative indices,
  same and distinct mutable views, copy independence and a returned list literal.
- `DampedIntegration.sx`: force/gravity, damping and translation through reference
  helpers, including zero inverse mass. Rotation and speed caps are excluded.
- `PreparationMasses.sx`: effective masses, zero denominators and warm impulses
  for dynamic/fixed bodies. Relative velocity, softness and graph lookup are excluded.

These cases are registered as untimed semantic witnesses. Their outputs contain
31 independently expected boolean observations. LLVM heap allocation preserves
escaping values, but retains, drops and destruction costs remain abstract.
Owning references requiring detachment and nested resources remain rejected.
The bridge gives multiply-defined portable registers local homes before LLVM
promotion; raw input does not undergo Silex Release optimization first.

## Correctness findings

The integration witness reduced to `OriginalReproducer.sx.txt` (the `.txt`
extension keeps the archival source outside module discovery). The unfixed
ARM64 disassembly is `original-arm64.asm`: negated multiplication materializes
its product, but the following FMA reloads the elided negation's unwritten slot.
This failed in Debug as well as Release; LLVM and interpretation agreed.
After that fix, Release exposed another stale-home read: FMA bypassed the
ordinary lookup for a literal cached outside the loop. It now consumes the
actual cached register. The second native matrix covers both literal operand
positions, widths, residence modes and add/subtract forms.
The compiler now excludes producers already consumed by negated-multiply or
packed-lane encoding from the following arithmetic fusion.

The new native regression also exposed a C ABI defect in the in-memory test
entry: internal floating scratch registers overwrote the Zig caller's expected
value. The test entry now preserves the low halves of v8-v15. Unit coverage
crosses float32/float64, stack/register residence, both operand orders and
addition/subtraction: 64 host executions and emission checks for macOS, Linux
and Windows ARM64. `Tests/Native/FusedFloatArithmetic.sx` retains the source
reduction independently of the LLVM bridge. Non-host emission is not execution.

## Coverage and remaining work

The scan now compares 53 source observations in both interpreters. Twenty-six
emit LLVM in both modes, including the three additions and the previously
blocked `Boids2DSteering.sx`. Emission alone is not execution evidence.
The bridge conditionally models 25 of 69 instruction tags, abstracts two lifetime
tags and rejects 42 tags. The complete reports are retained here.
Advisor findings are hypotheses from whole-program structural counts. In these
constant-input witnesses LLVM can fold observations and vectorize aggregate
copies; such counts do not attribute a cost to the hot helper or establish a gain.

Full preparation/integration, operation interactions, numerical edge contracts,
stationarity and ordered timing evidence, inherited external GFX.ECS closure,
and physical X64 qualification remain open. No performance threshold or legacy
proof was replaced. This audit does not establish general compiler parity.

## Validation of this candidate

- `zig build check --summary all`: 44/44 steps, 1,931 tests passed.
- `zig build test --summary all`: 36/36 steps, 1,444 tests passed.
- Both language runs: 182 passed, zero failed, 62 files. The quick gate includes
  62 oracle tests and the protected-contract mutation checks.
- `compare 5`: all 19 fixed cases match LLVM and native Release. The three
  existing scalar timings are diagnostic only, not a qualified performance proof.
- `execution.json`: all three new cases match interpretation, native Debug and
  Release, and raw/Release LLVM at both `-O0` and `-O3`. Commands, observations
  and executable hashes are retained; emitted LLVM files are included.
- Qualified robustness: 144 pairwise cases, five risk triplets, 41 native cases
  and four negative cases; cache invalidation/concurrency and package-graph
  stress passed. The detailed tables are included.

`gate` still fails the inherited GFX.ECS ancestry check for
`0fb019cf2f5bf0fc56078ba0a01618fca868fd87` before full qualification. This is
recorded as a failed, unwaived check, not a passing local substitute. The impact
plan still requires the qualified internal, native portability and external
statuses before global integration. No remote target or physical X64 execution
was performed for this candidate.

Compiler correction: `382aeffcdd29da928f0a4e426d55b0dd7996a99f`.
The following oracle/contract commit is separate from compiler implementation.
`Manifest.json` seals the source and artifact bytes; its enclosing commit owns
the oracle candidate. `capture.py.txt` preserves the exact temporary script used
for the additional execution matrix. Replay into a new audit directory rather
than overwriting these observations.
