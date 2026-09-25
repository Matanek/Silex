# Native allocation diagnostic — 2026-09-25

These results compare published Silex `v0.47.0`
(`65cce7f30a9f727b08706b57fc08d91cd4bbd313`) with the Windows heap candidate
`3229cfd285e9356589417eeac1fa1d7c9af4cf93`. The workload is
`Tests/Native/HeapAllocation.sx`, SHA-256
`353c9f8a7fcf37452ea6a544f520de290ac1758b0a80c224c3de750db2b890c3`:
4,000 rounds of string growth, Unicode/NUL preservation, collection mutation,
and detached snapshots, with the exact output `256000\n`.

The hypothesis is that one virtual-memory reservation per small allocation
dominates this workload. Both Windows architectures now call UCRT
`calloc`/`free` through register-preserving adapters. This preserves zeroed
storage and ownership behavior; it does not change the default backend.

| Native host | Baseline median [min–max], ms | Candidate median [min–max], ms |
| --- | --- | --- |
| Windows x64, AMD EPYC 7763, OS 10.0.26100 | 146.251 [144.084–150.469] | 11.688 [11.204–17.497] |
| Windows ARM64, Cobalt 100, OS 10.0.26200 | 178.103 [162.021–194.630] | 14.942 [14.540–16.214] |

Each row is a same-host comparison: warm-up followed by twelve Release samples
per compiler in alternating order, without compilation in the timed region.
Process startup is included. These descriptive measurements are not a general
application speedup, a comparison between hosts, or a statistical parity gate.
No Linux or macOS x64 allocator improvement is claimed.

The still-mapping paths were also measured with the published 0.47.0 compiler
and the same fixed-work source (LF checkout SHA-256
`864a20327ea06fed40828be0d1f49b707ca11562bd6614b4386789f9edad2114`).
The Windows report hashes the CRLF checkout bytes; the fixture's work and
expected output are the same.
Each row has twelve Release samples on its own native host, but no changed
allocator candidate yet. These absolute times are diagnostic baselines, not
cross-host comparisons or measured gains:

| Native host | Published 0.47.0 median [min–max], ms | Qualification run |
| --- | --- | --- |
| Linux ARM64, Ubuntu 24.04 ARM runner | 120.143 [115.270–131.378] | [run](https://github.com/Matanek/Silex/actions/runs/36105669215) |
| Linux x64, AMD EPYC 9V74 | 312.081 [272.153–320.077] | [run](https://github.com/Matanek/Silex/actions/runs/36105665651) |
| macOS x64, Intel i7-8700B | 250.090 [230.720–404.369] | [run](https://github.com/Matanek/Silex/actions/runs/36105668021) |

All three runs passed the heap regression, native portability corpus, and
Debug/Release fixed-work correctness checks. The macOS x64 range is notably
wide; an improvement claim will need paired baseline/candidate samples on the
same host, not a comparison with these independent runs.

Both Windows compilers passed the allocation regression, all 29 native
portability tests (including classes, copy/cycle callbacks and ownership),
and the fixed workload in Debug and Release before sampling. Windows ARM64's
first cold compilation took roughly 336 seconds; the earlier 180-second
harness deadline was insufficient. The corrected harness separates compilation
deadlines from the short executable deadline and prints the active operation.

The unmodified reports retain compiler, executable and source hashes, all raw
samples, correctness output and exact qualification commit:

- [Windows x64 report](2026-09-25-windows-x64.json),
  [native run](https://github.com/Matanek/Silex/actions/runs/36076215533).
- [Windows ARM64 report](2026-09-25-windows-arm64.json),
  [native run](https://github.com/Matanek/Silex/actions/runs/36076217610).

From the common workspace root, reproduce with:

```sh
node Silex/Toolchain/Tools/QualifyHeap.mjs CANDIDATE OUTPUT_DIRECTORY TARGET BASELINE
```

Both compiler binaries must be native to `TARGET`. The manual
`heap-qualification.yml` workflow builds an exact commit with `candidate=true`
and compares it with the immutable version selected by `version`.
