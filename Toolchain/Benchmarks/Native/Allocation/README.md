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

Both compilers passed the allocation regression, all 29 native portability
tests (including classes, copy/cycle callbacks and ownership), and the fixed
workload in Debug and Release before sampling. Windows ARM64's first cold
compilation took roughly 336 seconds; the earlier 180-second harness deadline
was insufficient. The corrected harness separates compilation deadlines from
the short executable deadline and prints the active operation.

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
