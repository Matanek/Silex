# Cache and editor tooling

The cache and editor server reuse compiler contracts without exposing AST, IR,
or target representations as public APIs.

## Reuse compilation results

Source-compiling commands root their private cache at
`<invocation-cwd>/.silex/cache`. Content-addressed, versioned entries persist
module ASTs, portable typed IR, complete native inputs with their boundary
providers, Release and machine functions that are safe to reuse
independently, and mode-specific linked executables. Exact source and
boundary-archive contents are re-hashed before reuse; corrupt or unavailable
entries are misses, and atomic publication prevents readers from observing
partial data. Native images use target-specific Mach-O, ELF or PE cache
kinds.

`-n` and `--nocache` bypass reusable compilation entries. `run` still writes
its private executable under `.silex/run/`; the option forces rebuilding it
and does not change the command's output location.

## Serve editors

The command `silex lsp` speaks framed JSON-RPC over standard input and
output. Its public capabilities describe editor intentions; AST and IR
structures remain private implementation details.
