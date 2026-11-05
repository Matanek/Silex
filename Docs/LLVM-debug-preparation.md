# LLVM Debug preparation

This increment reduces repeated LLVM preparation without changing generated executables. It applies to the explicitly selected macOS ARM64 LLVM backend. The native backend remains the default.

## Mechanism and scope

LLVM 21.1.8 `default<O0>` still runs LoopSimplify, LCSSA and LoopIdiomVectorize. A global removal changes real machine code: the diagnostic JSON parser unit shrinks from 6,496 to 6,336 object bytes and its stack frame changes. A verify-only round trip matches the raw object. The original experiment and transformation evidence are retained in the [measurement export](LLVM-debug-preparation-measurements.json).

[DebugPipeline.zig](../Toolchain/Sources/Llvm/DebugPipeline.zig) only bypasses `opt` when every emitted function has strictly forward branch targets and no special attributes. Backward jumps, unknown targets/control transfers and special forms keep the existing pipeline. This deliberately includes backward jumps in acyclic graphs. The classifier owns the compiler's valid emitted unit dialect, not arbitrary LLVM text. `llc` still verifies input.

Release keeps O3 and its inlining threshold. Unit boundaries, text, imports, workers and publication after successful compilation are preserved. The policy participates in compiled-unit identity; classification happens only after a fragment miss. The new trace counter `llvm_units_optimized` reports units scheduled for `opt`. No helper or persistent process is distributed.

The Objective-C word-handle compatibility fix and temporary emission arena in the reference make current Boids compile with LLVM in both modes. See [LLVM evaluation](Llvm-evaluation.md). The five other distributed native targets do not use this LLVM path; no performance or execution result is extrapolated to them. Native macOS ARM64 is checked separately below.

## Compared inputs

Host: macOS ARM64, Apple M3 Pro. Baseline source: `189d577072811c44f347e09686185f1d62420fad`; candidate implementation: `79fd9f322b0e256401853cf93910d1a6adc101b7`. Bootstrap: Zig 0.16, ReleaseFast. Common accepted source before the two increments: `54b1b16238258b05ab26a78a945aafe32e66f169`.

Compiler SHA-256 values are `2cee461ca5fb103409f6e2ff45889811a129b56033cee53e4dbd9340d8521335` and `dce0e9917110534a818d47521cd19d3640366a9a9d9e79228be0d77a387d324a`. Source/tool hashes, current GFX dependency heads and local boundary archives are included in the export. These are the post-PNG GFX inputs; older native/frontend results retain their own baselines. An original LLVM reference that rejects Boids is not a timing baseline.

## Results

Cold compilation uses `--nocache`, a fresh temporary Zig cache per process, active OS caches, nice 10 and the default workers. Each configuration has six paired AB/BA blocks; Boids has one subpair per point, all other cases three. Separate primers are excluded. The two current C/C controls were qualified before candidate comparison. No observations were selected or replayed.

| LLVM Debug | Reference | Candidate | Reduction | Two-sided 95% reduction interval |
| --- | ---: | ---: | ---: | ---: |
| Boids | 16.046 s | 12.209 s | 23.91% | 23.40% to 24.88% |
| Tokenizer | 1.811 s | 1.381 s | 23.73% | 23.24% to 24.02% |

Boids keeps 2,213 units: `opt` jobs fall from 2,213 to 601, while 2,213 `llc` jobs remain. Tokenizer keeps 309 Debug units: `opt` jobs fall from 309 to 125, while 309 `llc` jobs remain. These are actual tool invocations or matching trace counters, not inferred speedups.

All twenty configurations pass the prospective latency, memory and size admission gates, with identical emitted hashes across 312 subpairs (624 processes, plus 40 primers). C/C controls add 48 processes and four primers. The largest one-sided 95% RSS-ratio upper bound is 1.04771. Binary size is identical. Nested frontend phases are retained separately and are not summed into totals.

The table retains increases as well as decreases. Small configurations use the agreed absolute non-regression guard of 50 ms when their reference median is below one second; otherwise the upper one-sided 95% latency ratio must be at most 1.05. These gates do not assert zero change in every duration.

| Backend | Workload | Mode | Reference | Candidate | Candidate − reference |
| --- | --- | --- | ---: | ---: | ---: |
| native | boids | debug | 5.779339 s | 5.821424 s | +42.085 ms |
| native | boids | release | 11.084037 s | 11.080645 s | -3.392 ms |
| native | tokenizer | debug | 0.294843 s | 0.294990 s | +0.147 ms |
| native | tokenizer | release | 0.571592 s | 0.575073 s | +3.482 ms |
| native | protocol | debug | 0.081224 s | 0.081958 s | +0.733 ms |
| native | protocol | release | 0.020947 s | 0.021649 s | +0.702 ms |
| native | integer | debug | 0.068973 s | 0.069407 s | +0.434 ms |
| native | integer | release | 0.010082 s | 0.010907 s | +0.824 ms |
| native | aggregate | debug | 0.069883 s | 0.070564 s | +0.682 ms |
| native | aggregate | release | 0.013898 s | 0.014766 s | +0.868 ms |
| llvm | boids | debug | 16.046339 s | 12.208962 s | -3837.377 ms |
| llvm | boids | release | 31.865543 s | 32.168136 s | +302.593 ms |
| llvm | tokenizer | debug | 1.811312 s | 1.381484 s | -429.828 ms |
| llvm | tokenizer | release | 3.700881 s | 3.702343 s | +1.462 ms |
| llvm | protocol | debug | 0.225063 s | 0.199043 s | -26.020 ms |
| llvm | protocol | release | 0.244603 s | 0.245561 s | +0.958 ms |
| llvm | integer | debug | 0.174105 s | 0.148589 s | -25.516 ms |
| llvm | integer | release | 0.172810 s | 0.173426 s | +0.615 ms |
| llvm | aggregate | debug | 0.262423 s | 0.201475 s | -60.948 ms |
| llvm | aggregate | release | 0.178045 s | 0.178770 s | +0.725 ms |

## Correctness and reuse

- `zig build check install -Doptimize=ReleaseFast -j1`: 54/54 steps, 2,013 tests. `zig build test`: 42/42 steps, 1,250 tests. The 294 language scenarios in 115 files overlap between these checks; optimizer quick admission covers 28 programs.
- Six policy tests cover forward diamonds/switches, backward edges without phi nodes, multiple functions, conservative backward acyclic branches, special headers and unknown control flow.
- The integrated LLVM corpus compares 123 cases in both modes: 492 compilations, with identical executables and observables. Varying ownership, views, bounds, callbacks and scalar representations are covered.
- Missing LLVM tools retain the same refusal; native execution remains independent. An invalid phi module is rejected by direct `llc`.
- Fourteen cache scenarios cover Debug/Release cold, exact hit, another consumer, entry/caller/callee edits and forced reconstruction. Debug has seven units: the second consumer compiles two and reuses five, edits compile one and reuse six. Release has four units: the second consumer compiles two and reuses two, edits compile one and reuse three. Forced reconstruction reuses none, with the same outputs.
- The old ClassFinalizers expectation counted an implicit temporary that current explicit constructors do not create. The [constructor contract regression](../Tests/Ownership/ConstructorClassIdentity.sx), public class documentation and ten A/B interpreter/native/LLVM runs establish `owner` then `leaf`. Only that stale expectation was corrected; no source workaround or semantic change was introduced.

All measured compilations preserve the 4 GiB process-group guard, initial free-memory threshold of 45% and stop threshold of 35%. The separately recorded 5 GiB Zig bootstrap guard does not relax measured Silex limits. Resource diagnostics for emission lifetime are separate from speedup comparisons.

## Recompute the evidence

From the workspace root, use the repository containing this candidate:

```sh
python3 Silex/Toolchain/Tools/VerifyLlvmDebugMeasurements.py \
  Silex/Docs/LLVM-debug-preparation-measurements.json
```

The verifier needs only the exported observations and Python. It independently recomputes all 22 cohorts, primary wall/RSS/size and frontend-total confidence intervals to 1e-12, plus admission and functional consistency. The estimator uses 10,000 paired-block resamples with seed 20261104; exact quantiles and thresholds are recorded in the dataset.

This is a compatible increment, not completion of the wider cold-compilation objective. Further frontend work, package reuse and cumulative qualification retain their own requirements. No runtime speedup or cross-host gain is claimed.
