# Known scalar views: bounded forwarding and oracle correction

Implementation: `0e0c77412f9e8075dc22b4c954a71a22e0aab5da`, from
`854307d8572d6f5042b48138d1525211d8bc5f0e`. The compiler binary and artifact
hashes are sealed in `Manifest.json`. This closes a numeric forwarding gap;
it does not establish general portable optimization or performance parity.

## Reproduction and causal evidence

`before-tests.log` records the new helper/view test failing on the original
optimizer: two collection reads remain in `main`. After the change,
`ReadonlyViewMemory-silex.sir` contains the constant result 18. The original
IR is preserved in `readonly-before.sir`. Allocation and lifetime operations
remain present.

`KnownViewElements.sx` adds direct/helper, nested/clamped/empty view, float64,
alias mutation and branch variants. All seven observations agree in raw/Release
interpretation, native Debug/Release and four LLVM executions (raw/Release IR
at O0/O3). Its structural contract removes all four memory operations exposed
after inlining in `constantViews`; disabling `reference_memory_elision`
restores them. Three arithmetic overflow guards remain. Unit tests retain
invalid indices, empty-view failures, overflowing index arithmetic, calls,
alias stores, releases, control boundaries and both primary and secondary
value redefinitions.

The memory design follows the no-intervening-write precondition in LLVM's
[pinned EarlyCSE implementation](https://github.com/llvm/llvm-project/blob/3623fe661ae35c6c80ac221f14d85be76aa870f1/llvm/lib/Transforms/Scalar/EarlyCSE.cpp)
and its [store/call counterexamples](https://github.com/llvm/llvm-project/blob/3623fe661ae35c6c80ac221f14d85be76aa870f1/llvm/test/Transforms/EarlyCSE/basic.ll).
Silex uses conservative block-local snapshots, not LLVM MemorySSA or inferred
global immutability from readonly types. The consulted files' hashes are sealed.

The wider source also exposed a bridge defect: LLVM view construction trapped
on outlying or reversed bounds, while Silex normalizes and clamps them.
`final-gates.log` preserves that rejection; `views-llvm-before*.ll` preserve its
cause. The bridge now clamps both endpoints and creates an empty reversed view.
`llvm-executions.json` records the four successful independent executions.
No failing native run is counted as a timing sample.

The `BranchingLoop` source test also establishes three nonnegative induction
dividends and one signed accumulator remainder on the original optimizer.
The LLVM emitter and advisor's signed-remainder counts do not expose that
portable metadata. Their `srem`/`urem` difference alone therefore does not prove
a missing range analysis. X64 consumption and machine profitability remain
separate questions.

## Validation and timing

`validated-gates.log` records all 53 steps and 2,123 tests passing, including
`zig build check`, `test`, `optimizer-gate` and
`optimizer-robustness-qualified`. The language corpus has 183 passing tests in
63 files. The oracle has 22 executable corpus cases, 43 fixed native
regressions, eight generated native scenarios, 128 internal and 32 LLVM fuzz
cases. Robustness covers 144 pairs, five triplets, 41 native and four negative
cases, plus cache and package-graph stress.

The coverage scan has 54 interpretation matches and 29 raw/Release LLVM
emissions. Emission is not execution. `targets.json` records Debug/Release
emission for all six targets, execution on physical macOS ARM64 and execution
under Rosetta X64. It does not claim physical X64, Linux or Windows execution.
The admission matrix still requires native and selected external qualification
on the exact candidate before integration.

`compare-11.log` and its TSV reports preserve the ordinary diagnostic LLVM
comparison. No reference, confidence rule or budget is changed.

The separate `KnownViewLoop.sx.txt` experiment repeats a natural list/view helper
250,000 times. `loop-builds.json` records the before/after binaries and their
common output `266`. On macOS ARM64 / Apple M3 Pro, six warmup pairs precede
21 alternating measured pairs. `view-timing.json` retains every observation:

| Metric | Before | After |
| --- | ---: | ---: |
| Median process time | 361.353 ms | 360.922 ms |
| Median absolute deviation | 3.603 ms | 4.183 ms |
| Binary size | 32,952 bytes | 32,952 bytes |

The median paired after/before ratio is 0.999180, with ratio MAD 0.013520.
This does not demonstrate a significant speedup. The metric includes process
startup and retained collection allocation/lifetime work; it has no LLVM
comparator and no physical X64 scope. Reproduce by copying the `.sx.txt` source
to a temporary `.sx` path, compiling it from the workspace or Spec-group root
with both compiler revisions using `--release --nocache`, naming the outputs
`view-loop-before` and `view-loop-after`, then running `measure_views.py` beside
those binaries and the source.

## Remaining work

Broader portable-optimization work remains open. Allocation/lifetime cost, general inter-block memory
facts, broader call/loop/vectorization interactions and the remaining portable
families are not closed by this bounded slice. A next reduction should separate
allocation and helper-call cost before choosing a transformation. The integration reduction
also exposes repeated pure scalar arithmetic that should be attributed
separately from alias-sensitive loads and target register pressure. The wider
consumer and physical-target qualifications retain their original contracts.
