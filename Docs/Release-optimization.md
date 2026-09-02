# Release optimization

After native program closure, Release mode applies semantics-preserving
transformations first to the retained portable IR, then to the target's machine
representation.

## Simplify portable IR

Release propagates constants and copies across the control-flow graph. It
promotes profitable, non-addressed integer and boolean locals to SSA values,
constructs join values, removes trivial joins, lowers the remaining parallel
edge transfers, and prunes unreachable blocks. Promotion is deliberately
skipped when several live joins would add control-flow work; those locals
remain candidates for the native global allocator instead. Floating-point
recurrences retain their local identity for scalar and SLP lane allocation.
These decisions are automatic and require no source annotation.

When the closed program contains at least 256 functions, the optimizer applies
its independent per-function simplification and scalar aggregate replacement
through at most four fixed worker ranges. Global summaries are complete before
workers start. Inlining, SSA promotion, validation, and every transformation
that can change cross-function identities remain sequential barriers. Each
worker writes the original function index in a separate output slice, so using
one, two, or four workers produces the same canonical portable IR. Smaller
programs keep the direct path.

Before inlining, Release removes unobserved local stores and scalarizes pure
value constructors. Immutable, single-definition aggregate projections can
be reused across blocks; joins and escaping or addressable values retain
their storage. This keeps a constructor's intermediate field assignments
from becoming repeated whole-structure copies in a branching caller.

Release inlines direct callees under a bounded cost across branches, loops,
and multiple returns, in addition to constant-result and small straight-line
specialization. It then re-runs scalar aggregate replacement, propagation,
dead-code elimination, dense-block reuse, and bounds analysis on the combined
graph. In call-free functions containing a proven repeated scalar collection
read, it reuses the corresponding local, field and collection loads within
each basic block until an aliasing write. It also marks a
collection load as bounded when a zero-origin induction variable is dominated
by the exact collection-count comparison and cannot advance before that load;
every unproved access retains its runtime bounds diagnostic.

## Allocate native registers

Native Release lowering performs deterministic CFG-wide liveness and graph
coloring for compatible scalar functions on ARM64 and X64. Copy-affinity
components and destructive arithmetic are coalesced globally. ARM64 colors
scalar floating-point values and proven SLP lanes in the shared SIMD register
class, then realizes profitable `float32` pairs with baseline NEON. X64
independently selects the same portable pairs for baseline SSE on both
System V and Win64, reserves only volatile XMM registers, and keeps their
scalar stack slots synchronized as a correct fallback for unselected or
unsupported operations. AVX is not selected until target features can prove
it is legal. Addressable values, unsupported aggregates, and values that
cross unsupported machine operations remain explicit spills. Empty SSA edge
transfers are bypassed after allocation, and the ARM64 collection cursor
recognizes induction updates separated by independent SSA copies. Fully
resident leaf functions allocate no value frame. Debug retains the direct
stack-resident lowering.

ARM64 also admits a restricted set of leaf memory operations. Checked dynamic
loads, view replacement, and explicit address/reference accesses retain their
bounds and failure behavior. Addresses, indices and composite memory operands
stay pinned; scalar loads and reference stores may transfer directly to a
register. Functions taking local addresses or making arbitrary calls remain
outside this path, and these memory kernels keep scalar rather than paired
SIMD residences.

Exact `copysignf`/`copysign` calls to a proven system provider use a sign-bit
transfer on ARM64. The transformation preserves signed zeros, infinities and
NaN payloads without relaxing floating-point arithmetic. A package-private
provider qualifies only when its macOS ARM64 metadata links libSystem alone,
without an archive, framework or provider dependency. Custom providers keep
their call. X64 register eligibility is unchanged by this ARM64 extension.

The native layout normally keeps unique deterministic homes. If their
cumulative count would exceed the shared machine limit, ARM64 and X64 instead
color physical stack spans from portable-IR liveness. Simultaneously live
values and incompatible scalar or aggregate residence classes never overlap;
storage reached through a derived reference remains pinned. These exceptional
large functions deliberately skip register coloring until virtual value
identities and physical stack homes become separate machine-IR concepts.
