# Dead scalar storage and X64 entry definitions

Implementation: `92961b870ae47c1168f4cee4ef65a9e0e6cd06e6`, after
`d990d12e44f966b3456f13fc114c2dc1ca37e468`. `Manifest.json` seals the exact
compiler, source files, observations and consulted LLVM source identities.
This is a bounded optimization proof, not general optimizer parity.

## Transformation and attribution

The preceding [known-view audit](../2026-09-11-known-views/README.md) retained
list allocation, view descriptors and lifetime management after forwarding all
observed elements. Its loop measurement showed no speedup. Dead-value cleanup
now removes unused view descriptors and single-definition primitive list
literals whose only remaining uses are retains/drops. It keeps initializer
computations, including checked arithmetic. Escaping lists, mutable homes and
resource-bearing or aggregate elements remain outside this storage rule.

`ReadonlyViewMemory-silex.sir` now contains only the constant 18 and its print
in `main`. `KnownViewElements` still observes all seven direct/helper, nested,
clamped, empty, floating, alias and branch results. Its strengthened structural
contract rejects residual list initialization, view construction or lifetime
operations in `constantViews`. Disabling `reference_memory_elision` restores
four memory operations; three arithmetic guards remain under the enabled pass.

LLVM's [pinned allocation-site simplification](https://github.com/llvm/llvm-project/blob/3623fe661ae35c6c80ac221f14d85be76aa870f1/llvm/lib/Transforms/InstCombine/InstructionCombining.cpp)
walks allocation users and rejects unhandled observations or escapes. Its
[malloc/free tests](https://github.com/llvm/llvm-project/blob/3623fe661ae35c6c80ac221f14d85be76aa870f1/llvm/test/Transforms/InstCombine/malloc-free.ll)
separate removable allocation from observable pointer/alignment cases. Silex
uses a narrower typed rule: primitive elements and zero data uses. It does not
import LLVM's pointer comparisons, allocation families or MemorySSA machinery.

## Correctness and the X64 counterexample

The first local campaign passed 2,125 tests, but the independent Rosetta X64
Release execution returned `false` for the first view observation. Its prologue
copied the useful second argument to `r8`, then copied the unused first argument
to the same register. Removing list storage had exposed a scalar function to an
allocator whose graph omitted implicit prologue definitions.

The corrected graph makes every incoming parameter definition interfere with
values live at entry. A machine-level test varies the useful parameter's
position independently of collections. `storage-targets-failure.json` and
`storage-x64-failure.asm` preserve the failure; the fixed entry and target report
show the corrected execution. The failing intermediate compiler can be
reconstructed from the implementation commit with `RegisterAllocation.zig`
from its parent. No failing native run is used as a timing sample.

The corrected cumulative command
`zig build check test optimizer-gate optimizer-robustness-qualified install --summary all`
passes all 53 steps and 2,126 tests. The language corpus has 183 tests in 63
files; the oracle has 22 corpus programs, 43 fixed native regressions, eight
generated native scenarios, 128 internal fuzz cases and 32 LLVM fuzz cases.
The robustness campaign retains 144 pairs, five triplets, 41 native and four
negative cases plus cache/package stress. Twelve cross-target emissions and
four macOS Debug/Release executions pass. X64 execution is Rosetta, not physical
X64 qualification. Four independent raw/Release LLVM executions at O0/O3 agree.
The ordinary 11-pair LLVM comparison remains diagnostic.

### Existing X64 arithmetic-check gap

`storage-failure-attribution.json` records 16 executions with both the original
compiler from `854307d8572d6f5042b48138d1525211d8bc5f0e` and the current candidate.
`UnusedInitializerFailure.sx.txt` overflows inside a discarded list initializer;
`ScalarOverflow.sx.txt` removes the list entirely. Both return 1 on ARM64 and 0
on Rosetta X64, in Debug and Release, before and after this Part's changes.
There is no stdout or stderr from these standalone native executables.

The portable interpreter test preserves the same overflow failure. X64
`emitBinary` does not consume the checked addition's failure requirement: this
is an existing machine gap, not an effect removed by dead-storage cleanup.
The strict `verify_storage_failures.py` intentionally remains red on X64; these
executions must not be reported as interpreter/native error parity. The reduced
case and this attribution are handed to machine-quality work. Reproduce the
sources in a directory containing `Package.json` with `sources: "."`; that
explicit dependency-free consumer avoids unrelated implicit graphics links.

## Separate ARM64 timing

The fixed 250,000-iteration list/view helper prints `266`. Six warmup rotations
precede 21 measured rotations of the original compiler, forwarding alone and
forwarding plus dead-storage cleanup. Every observation checks output and exit.
The host is a physical Apple M3 Pro running macOS; process time includes startup.

| Configuration | Median | MAD | Binary bytes |
| --- | ---: | ---: | ---: |
| Original compiler | 345.599 ms | 4.396 ms | 32,952 |
| Forwarding alone | 359.661 ms | 6.850 ms | 32,952 |
| Dead-storage candidate | 3.616 ms | 0.126 ms | 32,952 |

The paired candidate/original median ratio is 0.010432, with MAD 0.000342 and
half-window shift -4.77%. This demonstrates the allocation/lifetime saving for
this reduction. Startup is now a substantial part of the remaining time. It
has no LLVM timing comparator, physical X64 result or full-consumer scope.
`measure_storage.py` and `storage-timing.json` retain the acquisition order and
all observations. Rebuild the `.sx.txt` source as `.sx`, from the workspace or
Spec-group root using each compiler and `--release --nocache`; place the source
and binaries `view-loop-before`, `view-loop-forwarding`, `view-loop-after`
beside the runner. The preceding audit seals the first two compiler/binary
identities; `storage-loop-builds.json` seals the current compiler and binary.

The exploratory `IntegrationRepeated`/`IntegrationShared` variants use the
same compiler and differ only in explicitly sharing `step * inverse_mass`.
Their one-million-iteration medians are 8.919 and 8.523 ms; the paired ratio is
0.958672 with MAD 0.017168. These short process measurements motivate a longer
experiment with target pressure inspection. They do not yet justify a general
scalar-expression transformation or a claim about the full Integration stage.
The production source is unchanged; both experimental sources and the runner
are preserved here as `.sx.txt` files.

Native target qualification and selected external checks on the exact SHA
remain required before integration. No budget or statistical limit is relaxed.
Raw logs, TSV columns and disassembly whitespace are preserved byte-for-byte.
