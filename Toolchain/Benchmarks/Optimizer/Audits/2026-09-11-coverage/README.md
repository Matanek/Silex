# Initial coverage audit — 2026-09-11

This is an evidence inventory, not a parity qualification or a replacement for
an accepted performance baseline. Commands run from the compiler worktree's
`Toolchain` directory. Paths in logs are normalized to `<SILEX>/Toolchain` and
`<ZIG_GLOBAL_CACHE>`; generated outputs and results are otherwise preserved.

## Before the audit changes

Compiler HEAD: `09b7a5ffaa438e808f920a534fefb1ccabce20ac`, clean at capture.
Physical host: Apple M3 Pro, ARM64 macOS. The configured LLVM CPU is `apple-m1`.
Clang: `Apple clang version 21.0.0 (clang-2100.1.1.101)`.
Triple: `arm64-apple-darwin25.6.0`.
All oracle settings are preserved in `Coverage.json`; none were relaxed.

| Command | Result | Evidence |
| --- | --- | --- |
| `zig build optimizer-oracle -- parity-audit` | Exit 1: inherited GFX.ECS ancestry does not match the required closure | `inherited-audit.log` |
| `zig build optimizer-oracle -- compare 11` | Exit 0, diagnostic comparison of the fixed corpus | `inherited-compare.log`, `baseline-report.tsv`, `baseline-parity.tsv`, `baseline-opportunities.tsv` |

The failed ancestry check is for GFX.ECS revision
`0fb019cf2f5bf0fc56078ba0a01618fca868fd87`. This failure occurred before the
audit implementation changed. It is not waived by `coverage-audit`.

The three median cost ratios (Silex/LLVM) are 0.857690, 0.909935 and 0.997008
for integer arithmetic, branching loop and floating arithmetic respectively.
Eleven samples do not satisfy the qualified minimum of 21; these values do not
qualify compiler parity. The original runner did not preserve ordered raw
observations, so no stationarity claim can be reconstructed from these reports.

The advisor identifies two discriminants: signedness/ranges in
`BranchingLoop.sx` and constant propagation in `ReadonlyViewMemory.sx`.
Those findings identify experiments, not a proven cause of an application gap.

## Audit candidate

The accompanying source-hash manifest identifies the audit implementation;
the enclosing Git commit identifies the complete candidate. `Coverage.json`
and `PerformanceBaselines.json` retain their original bytes.

`coverage-scan` first checks interpreter agreement for all 50 distinct registered
sources and then attempts whole-program LLVM emission. Twenty-two emit in both
raw and Release form. Twenty-eight remain unsupported. The per-case table lists
unmodeled instruction tags to distinguish unsupported harness operations (for
example assertions or text) from an unsupported hot function; it does not
attribute a whole-program failure to that function. Unsupported operand types
are reported separately by the emission result.

The IR classification has 24 conditional tags, two abstract lifetime tags and
43 unsupported tags. Every historical compiler source is also verified against
its recorded Git revision. Eleven source identities still match the candidate;
two changed when the oracle's `Main.zig` and `Llvm.zig` changed. Both sets of
campaign outcomes remain historical.

The integration reductions `PureMathReferenceInlining.sx` and
`HotReferenceLeafClosure.sx` already exercise bounded reference helpers and
velocity/position updates. They pass interpreter comparison but have no complete
LLVM emission proof here. A full autonomous preparation reduction is still
missing. Physical X64 performance and consumer qualification remain open.
See [scope and next experiments](../../../../../Docs/Optimizer-coverage.md).

## Validation of the audit slice

`Manifest.json` records command exit codes, source hashes, artifact hashes and
the clean STD revision used by the composed regressions. The enclosing commit
contains the exact audited sources.

- `zig build check --summary all`: 44/44 steps, 1,925/1,925 tests; language suite
  180 passed, zero failed in 61 files. Includes mandatory quick admission.
- `zig build test --summary all`: 36/36 steps, 1,442/1,442 tests; language suite
  180 passed, zero failed in 61 files.
- `zig build test-optimizer-oracle --summary all`: 58/58 tests, including
  coverage mutations and protected-contract admission.
- `zig build optimizer-oracle -- coverage-scan`: interpreter comparison and
  LLVM emission inventory for all 50 distinct sources.

The unit logs include intentionally rejected registry entries and invalid
indices. Zig displays these captured diagnostics with `run test w`; the final
summaries and zero exit codes establish that their negative tests passed.
The broader qualification still requires the external closure and remaining
semantic/performance evidence described above. These local results do not
waive the failed inherited `parity-audit` or close that qualification.
