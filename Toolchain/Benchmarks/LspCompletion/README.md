# LSP completion baseline

This benchmark records performance observations separately from correctness
gates. Run it from `Silex/Toolchain`:

```text
zig build benchmark-lsp-completion -- 101
```

The executable is always built in `ReleaseSafe`. It checks that every measured
request returns its expected member and rejects a sample otherwise. Each mode
creates a fresh request arena and rebuilds the current workspace view:

- `fresh_workspace` starts the campaign without a priming request;
- `warmed_filesystem` runs the same request after an explicit prime;
- `overlay_after_edit` supplies a versioned unsaved replacement for the
  imported `Math.sx` and requires the newly added `edited` method.

The current LSP has no persistent project index between these direct workspace
queries. “Warm” therefore describes filesystem/process warm-up, not a cache hit.
The allocation columns count successful backing-allocator blocks and bytes
requested by the per-request arena. They do not claim to count every logical
`alloc` call made inside that arena.

## Initial observation

Captured on 2026-09-09 from the cumulative completion Spec lane based on
`1920690`, with Zig 0.16.0, `ReleaseSafe`, macOS 26.6.2 arm64, Apple M3 Pro
(12 cores), 18 GB RAM, 101 samples per mode:

| Mode | median µs | p95 µs | min µs | max µs | stddev µs | Mean blocks | Mean bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| fresh workspace | 158.375 | 164.958 | 156.666 | 297.583 | 13.938 | 2 | 32,712 |
| warmed filesystem | 158.042 | 173.125 | 156.834 | 293.291 | 15.422 | 2 | 32,712 |
| overlay after edit | 149.375 | 159.333 | 148.334 | 182.042 | 5.985 | 2 | 38,504 |

This table is a comparison baseline, not a timing assertion. Correctness stays
in deterministic LSP tests; later changes report the same command, environment,
sample count, result validation, and dispersion before claiming a performance
effect.
