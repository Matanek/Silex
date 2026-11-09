# Frontend declaration lookup

The semantic analyzer builds one index from source declaration names to their
positions after validating duplicate names and fields. Inheritance and protocol
queries resolve the current IR structure name through that index. They preserve
the former first-name-match behavior without scanning all declarations per query.

## Identity and lifetime

A nominal type ID is insufficient for this lookup. Tuple literal inference can
rename an IR placeholder to an existing tuple name or to a name with no source
declaration. `Semantic/Tuples.zig` updates those IR names during analysis.
Caching an initial nominal-ID-to-declaration association changes resolution.
The name index instead keeps the source names fixed and reads the current IR
name at every query. Missing declarations, enum placeholders and generated method
results retain the former null result.

The index stores positions, not declaration copies. Later protocol preparation
can update source methods in place, and a lookup still reads the current method
body. The analyzer resets and rebuilds the index for each program. It belongs
to the analysis allocator and introduces no persistent cache, key, serialized
artifact or cross-document invalidation state. No map iteration determines IR,
diagnostic ordering, method selection or conformance visibility.

Building the table requires one entry per source structure. The existing
preparation lookups also use it; repeated declaration queries require one name
hash lookup rather than a scan of all source structures. Protocol conformer
traversals, class hierarchy traversal and visibility checks remain unchanged.

## Differential evidence

In unit-test builds, every indexed inheritance/protocol query also executes the
former linear name search and compares the resulting source position. An explicit
panic keeps this oracle active in ReleaseFast tests. `DeclarationIndexTests.zig`
covers reordered declarations, enum entries, IR renaming to existing and absent
names, generated structures, current source changes and analyzer reuse.

A separate frontend-only probe on the unchanged corpus counts actual queries
and the number of name comparisons that the former scan would require:

| Workload | Source declarations | Nominal types | Queries | Former name comparisons | Missing results |
| --- | ---: | ---: | ---: | ---: | ---: |
| Boids | 795 | 913 | 1,044,911 | 544,641,637 | 322,558 |
| Tokenizer | 130 | 191 | 4,765 | 392,954 | 600 |

The probe keeps the linear oracle active on both real workloads. It produces
3,924 and 581 portable functions respectively. These counts establish repeated
work; instrumented runs do not establish elapsed-time gains. The probe and its
printing are absent from the production compiler.

## Target scope

This is shared semantic analysis for native and LLVM, Debug and Release, on
`macos-arm64`, `macos-x64`, `linux-arm64`, `linux-x64`, `windows-arm64` and
`windows-x64`. It changes no target selection, portable IR contract, ABI,
optimizer policy or emitter. Host tests establish the common lookup logic;
local macOS ARM64 measurements do not predict an X64 or other-host speedup.
Native execution and distribution gates remain distinct from lookup equivalence.

## Local compilation qualification

The [measurement record](Frontend-lookups-measurements.json) compares accepted
source `99c2e7d` with implementation `ebd5309` on macOS 26.6.2 ARM64, Apple M3 Pro,
using the ReleaseFast bootstrap. It preserves raw wall/CPU/RSS observations,
phase traces, paired blocks, controls, compiler hashes, changed source hashes,
dependency heads, external tools and native archive hashes.

| Boids native configuration | Reference frontend | Candidate frontend | Frontend reduction | Whole compilation reduction |
| --- | ---: | ---: | ---: | ---: |
| Debug | 2.231 s | 2.024 s | 9.3% | 2.3% |
| Release | 2.221 s | 2.028 s | 8.7% | 2.2% |

The upper one-sided 95% frontend ratio bounds are 0.943 and 0.924. Whole-process
ratio bounds are 0.995 and 0.981. These are incremental results against the last
accepted compiler, not a cumulative claim against the original long-term
baseline. They do not meet the final 20% frontend improvement on every main
workload. Specialization and remaining semantic work retain separate costs.

All ten native and eight console LLVM configurations pass the declared latency,
maximum-RSS and size guards. Every one of the 300 measured subpairs emits an
identical executable. Tokenizer, protocol defaults, integer control flow and
aggregate control flow preserve their expected output in both modes. Small
entries use the absolute 50 ms allowance; some relative ratios exceed +5%, and
sub-millisecond frontend increases are retained. The largest positive whole-process
median difference is 3.72 ms. This is not a uniform speedup.

Each configuration uses six paired blocks, alternating AB/BA order. Boids has
one compilation per point; shorter cases have three subpairs per block. Effects
use all raw observations and 10,000 paired-block bootstrap resamples, keeping
each block's observations together. The seed is reset to 20261104 for each
configuration or phase; RSS uses the maximum process value within each block.
The 600 measured compilations and 36 explicit primers remain separate. No
outlier is removed or cohort rerun to obtain admission.

Fresh reference/reference controls on Boids native Debug and Tokenizer native
Release pass stability, bilateral practical equivalence, output, RSS and size
guards. Each final cohort also passes its own reference stability check. This
control coverage does not establish timing equivalence on every other workload.
Silex reuse is disabled; each measured process uses a fresh temporary Zig linker
cache that is removed afterwards, while OS caches remain active. Priority is
nice 10 and compiler workers use their recorded default. Inputs and tools are
unchanged before and after the full campaign.

Separate functional controls preserve interpreter output and exact portable IR
on all four console workloads. Cache miss, exact hit, modified source and forced
reconstruction preserve the expected result in native/LLVM Debug/Release. Boids
LLVM retains the same `objc_msgSend` rejection in both modes; a failed compilation
provides no speedup evidence. Boids is never executed graphically. The owner
checks pass: `zig build check` (1,775 tests), `zig build test` (1,240 tests), and
293 language scenarios in 115 files; those suites overlap. The name index remains
an intermediate frontend improvement, not completion of the broader cold-build,
LLVM compatibility, reuse or six-target distribution qualification.

## Lexical callback candidate filtering

Generic specialization resolves parser-lifted anonymous bodies at their lexical
definition, preserving the binding types supplied by that context. Before a
name or qualified suffix can match, the declaration must be anonymous and have
the same source file, byte offset and generic arity. Checking these pure
conditions first avoids name comparisons for impossible candidates without
changing their order, selection or instantiation arguments.

The lexical-callback selector tests compare the previous and filtered paths,
including qualified suffix boundaries, files, offsets, arities and forwarded
locals. The 1,024-declaration fixture performs two name checks instead of 1,024
while selecting the same body. This count describes the mechanism, not a
portable end-to-end timing guarantee. Both compilation backends use the shared
specializer; native ABI, emitted instructions and public syntax are unchanged.
