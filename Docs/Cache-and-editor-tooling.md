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

## Share LLVM compilation fragments

On the supported macOS ARM64 LLVM backend, a new application or an edited entry
can reuse unchanged machine code from `~/.silex/cache/compiled-v1`. The store is
shared by invocation directories, and is separate from the local executable
and semantic caches. Package composition still uses typed Silex declarations;
these private objects do not constitute a package ABI.

After Silex optimization, the LLVM splitter assigns functions stable identities
from their source provenance, qualified name, and typed signature. Type names,
class/protocol tags, globals, and literals no longer depend on the consumer's
numeric tables. Each key includes compiler identity, private schema, LLVM
version, target, CPU, mode, and the complete canonical unit text. Referenced
layouts and declarations are part of that text. Conflicting identities are
rejected instead of choosing an arbitrary definition.

Release units include `available_externally` bodies for direct callees, with at
most two call edges, 48 KiB per imported body, and 192 KiB of imports per unit.
This permits LLVM inlining while keeping cache invalidation explicit: changing
an imported body invalidates its caller's unit. Address references alone do not
import a body. Debug does not import bodies. LLVM optimization remains local to
each unit, so performance can differ from the former whole-program pipeline.
Uncached units compile using at most four workers; cached objects are copied to
private staging before linkage. Raw/optimized LLVM text and staging objects are
removed when the build completes, including failures.

The same store retains the interval solver's decisions for large numeric control
flow graphs (at least 16 blocks and 64 value slots). Its key preserves numeric
operations, integer widths, value identities, and control flow, while removing
unrelated consumer symbol indices. Only proved check removals and comparison
folds are cached; they are applied to the current instructions, retaining their
current symbol references and diagnostic locations. Other Silex optimization
passes and frontend composition still run after an entry changes.

The shared store retains at most **512 MiB of accounted storage and 8,192
records**, across applications, targets, modes, and compiler versions. Accounting
rounds each record to 4 KiB blocks and adds 4 KiB for metadata. Publication evicts
least-recently-used records to admit new ones; individual oversized records are
not retained. Filesystem overhead can vary, so this is an accounting bound,
not a portable guarantee of exact allocated disk bytes. The existing local
320 MiB history policy and installed package/toolchain archives are separate.

Readers validate a content checksum and own private bytes, so concurrent
eviction cannot break an active link. Writers hold a shared interprocess lock,
prune once per publication batch, and atomically rename complete records. An
interrupted pending record is removed on the next publication. Cache corruption
or unavailable storage causes a miss. `--nocache` bypasses this store as well.

Tests in `Sources/Llvm/Units.zig` cover consumer renumbering, layout/body
invalidation, imported callees, and literal preservation. `Sources/Llvm/Store.zig`
covers checksum failures, byte/entry limits, replacement, and concurrent writers.
The range solver tests compare relocated cached decisions with fresh analysis.

## Serve editors

The command `silex lsp` speaks framed JSON-RPC over standard input and
output. Its public capabilities describe editor intentions; AST and IR
structures remain private implementation details.
