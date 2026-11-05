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
