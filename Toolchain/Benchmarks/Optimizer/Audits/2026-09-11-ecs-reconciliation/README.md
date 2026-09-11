# GFX.ECS closure reconciliation

The historical GFX.ECS anchor `0fb019cf2f5bf0fc56078ba0a01618fca868fd87`
belongs to an unmerged branch, not the canonical package ancestry. Replacing
it silently, rewriting package history, or treating the two trees as equivalent
would lose the original contract.

`Reconciliation.json` records the explicit replacement by canonical
`9ddd3347bf630365ee9147ad024618f72af11f4c`, the common ancestor, both trees,
and the hash of `GFX.ECS.delta.patch`. The delta removes that old branch's public
Commands construction/flush API, advances package metadata/documentation, and
adds mutable-query regressions. `Tests/ECS.sx` is byte-identical at both anchors;
its original hash and revision remain in `Coverage.json`.

The optional registry reconciliation binds this exact repository/revision pair.
It cannot relax compiler ancestry, admit another external revision, change a
sealed source, or silently accept a different tree/delta. The ordinary ancestry
checks still apply everywhere else. Historical proof hashes are now checked
against their recorded Git blobs; they are not updated to current source bytes.
This fixes the five inherited proof/source conflicts after recent oracle work
without replacing the historical results.

Package validation uses the existing Silex compiler binary from `da76ef46`:

- `silex test Packages/GFX.ECS/Tests`: 19 native Debug tests in seven files.
- `silex test Packages/GFX.ECS/Tests/Consumer/Tests`: one public consumer test.
- `silex compile Packages/GFX.ECS/Tests/ECSUpdateLifetimeProbe.sx -d -n -o <binary>`
  and the same command with `-r`: both executables print `99999`.

The CLI test command always uses native Debug. Release evidence here is the
existing lifetime probe, not a claim to rerun every package test in Release.
All source compilation commands run from the Spec Worktree group root with
its existing package links. `Manifest.json` records the fresh oracle gate,
commands, closure and file hashes. The full gate's five timing pairs are only
diagnostic; this repair does not establish general LLVM performance parity.

## Compiler defect revealed by the restored gate

The first complete gate after reconciliation reached
`Regressions/MultipleReferenceCursors.sx` and exposed a pre-existing Release
SIGSEGV. The unchanged compiler reproduced it without cache; Debug passed.
`cursor-crash-lldb.log` shows `x1 = 0x3fc00000` (the bits of the first stored
float, 1.5) instead of the second view pointer. The paired replacement copy
used `x5`/`x6`, which still held that live view's descriptor. The offending
copy predates this continuation (`de15327b`, September 4).

The ARM64 helper now uses reserved scratch `x9`/`x11` after consuming the index
and stride, for both paired copies and an odd final leaf. It keeps the transfer
shape and register allocation unchanged. A native machine fixture checks live
volatile sentinels and stored values at widths one, two and three; it also emits
the fixture for Linux and Windows ARM64. The existing source reduction joins
`Tests/Native/MultipleReferenceCursors.sx` as a shared regression. Actual native
execution in this record is macOS ARM64 only.

The initial gate failure is retained as `gate-before-cursor-fix.log`; it must
not be confused with the final gate result in `Manifest.json`.
