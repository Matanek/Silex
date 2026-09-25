# FallingBodies2D corpus requalification — 2026-09-25

The sealed `falling-bodies-2d-full` source at Silex-Benchmarks revision
`1b73dccf7c14b69d0126778605a46d840018da5f` remains the historical
anchor (SHA-256 `6d61796ab85c564c3861f8e102aadb8f22463e9b68826ccdaa6ed312f7675a6c`).
The current source is separately sealed at revision
`0fa8ee85787f570ebc99eb8ddd8b4658b95efe36` (SHA-256
`e92f0c422c7cecf1525b096dfd170ad4090177e975ac12f5e673e81622cf0479`).
The original record was not rewritten. The registry validates each source at
its recorded Git revision and exactly one current source at the working path.

Reviewing `git diff 1b73dcc..0fa8ee8 -- Sources/FallingBodies2D/Main.sx`
shows optional CPU frame-phase/timeline recording, independent panel switches,
and a static performance-panel option. The equal-work path with `--no-panel`
does not enable these additions or change its physics schedule. The new seal is
an explicit current-source identity, not a claim of performance equivalence.

On macOS ARM64, Silex 0.47.1 candidate compiler SHA-256
`3da33816e7fd2fc709fb14ba0653176179a4c3b231cba70e0b0179c6b7a9be6a`
compiled the current benchmark in Release. Running

```sh
/private/tmp/falling-bodies-current-20260925 --stress --smoke --batch-1 --immediate --no-panel --fixed-work
```

exited zero, reported 120 bodies, 120 measured frames/steps and 180 total
steps. All 120 final `state[...]` lines matched
`Silex-Benchmarks/Sources/FallingBodies2D/Baselines/2026-09-20-llvm-cycle-boundary/fixed120-state.txt`
byte-for-byte after normalizing the final newline; their LF-joined SHA-256 is
`4f70cfb1d7677d5b9355ddcc5e7a5e8b28fb56d4f207058fd8d3179e59342199`.
The current executable SHA-256 was
`95cd88d38bf2044c15b709e0d34e8a04237c55f7efa199c3eeb600d16f34927f`.
This is a deterministic state check, not a comparative timing measurement.

The full `zig build optimizer-gate` passed after the missing-current-seal
regression assertion was added, using the pinned Command Line Tools Clang
(`21.0.0 (clang-2100.1.1.101)`) and its matching macOS SDK. The targeted
`zig build test-optimizer-oracle` passed 84/84 unit tests; `zig build check`,
`zig build test`, and `zig build optimizer-robustness-qualified` also passed.
