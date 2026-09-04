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
Within one block, loads of non-addressed scalar-structure locals reuse their
last single-definition snapshot. Intermediate stores overwritten in the same
block are removed when no remaining load observes them and the local is never
addressed. The last store remains available to successor blocks;
redefined sources and addressed locals are not forwarded.

For flat numeric or boolean value structures, a reconstructed reference or
mutable-view store writes only the changed fields when the other fields come
from a still-current snapshot of that exact destination. Calls, unknown
effects, and block boundaries end this proof. Owning collection replacement,
stale snapshots, and structures with owned fields keep their value semantics.
Unaddressed mutable locals of the same flat scalar form are represented as
independent field locals before aggregate propagation. A load reconstructs the
value at its original observation point, while a reconstruction stored in the
same block writes only fields that differ from that local's current snapshot.
Control-flow entries start a new snapshot epoch, and addressable, nested, or
resource-bearing locals retain aggregate storage. Explicit deep copies of
numeric and boolean scalars become ordinary aliases because these values have
no identity or owned storage.
Non-escaping reference and view snapshots can also become scalar reads,
including explicit copies of these plain values. Each needed field is read
at the original snapshot, before any later aliasing write or branch. Checked
view indices retain their diagnostics; an unused snapshot is kept when its
read could fail. Floating-point fields are copied without arithmetic, so
signed zeros and NaN payloads are unchanged. Large scalar projections also
apply to loads already proven bounded; their generated element reference
remains bounded and therefore does not reintroduce a runtime check. Small
bounded aggregates retain their compact native copy so it can seed SIMD lanes.

A direct call may borrow a collection element for a flat scalar aggregate
parameter when the callee only projects fields from that parameter. Every
call site must provide a single-use element load in the same block, and no
intervening operation may invalidate its address. Function references,
captures, calls or storage mutations in the callee keep the value parameter.
Eligible calls pass the element address at the original load point and the
callee reads each field through it, avoiding the caller load and parameter
copy while preserving the original bounds check and observation order.

Release inlines direct callees under a bounded cost across branches, loops,
and multiple returns, in addition to constant-result and small straight-line
specialization. Before this inlining, exact scalar `STD.Math.min` and
`STD.Math.max` calls become portable float32 or float64 operations. Native
lowering emits them directly on ARM64 and X64 while preserving the library
contract for NaN operands, signed zeros, infinities, and ordinary values.
Other names and signatures remain ordinary calls. Release then re-runs scalar
aggregate replacement, propagation,
dead-code elimination, dense-block reuse, and bounds analysis on the combined
graph. In call-free functions containing a proven repeated scalar collection
read, it reuses the corresponding local, field and collection loads within
each basic block until an aliasing write. It also marks a collection load or
element reference as bounded when a zero-origin induction variable is
dominated by the exact collection-count comparison and cannot advance before
that access. Equivalent loads of the same unchanged collection and induction
locals share this proof; every unproved access retains its runtime bounds
diagnostic.

An indexed argument passed to a mutable parameter addresses the collection
element directly when its root and any enclosing fields are stable. The
callee therefore mutates the element in place instead of receiving a complete
temporary followed by whole-element replacement. Owning lists retain their
copy-on-write detachment, views retain negative-index normalization, and the
selected element is still checked unless the surrounding counted loop proves
it bounded. A type-checking snapshot covered by that same reference is
removed after its result becomes unused; other checked snapshots remain.

A checked mutable-view reference in the entry block can also prove an
equivalent reference in a later block bounded. This proof accepts only views
whose descriptor and index originate from unchanged locals, copies, or fields
of value structures. Calls, storage-replacing mutations, explicit addresses,
and synchronization disable it. The later reference still recomputes its local
address and normalizes a negative index; ARM64 and X64 omit only the duplicate
failure branches and diagnostic path. Keeping the address local avoids
extending one reference lifetime across the whole control-flow graph.

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
bounds and failure behavior. Indices, composite memory operands and explicit
addresses stay pinned. Scalar references, loads and reference stores may remain
in registers; direct reference transfers address a resident reference without
first copying it through a scratch register. Pure aggregate construction and
copies can also retain arithmetic residences
on ARM64, with the existing parameter and return homes. Functions taking local
addresses or making arbitrary calls remain outside this path. Independent
arithmetic may use paired SIMD residences,
while values consumed or produced by the memory instructions remain scalar
or stack-resident. Packing a scalar into a SIMD lane captures it at its
original use, before another scalar can reuse its register.
Every eligible function rejects a pair when delaying its first calculation
would cross a scalar use of that result, including pure aggregate constructors.
Aggregate returns copy resident lanes into the
caller's return storage instead of reading stale stack homes.
Stack-resident aggregate parameters use paired 64-bit transfers only for
leaves without scalar register residence. When the parameter pointer itself
arrives on the stack, the second transfer scratch stays distinct from that
pointer so consecutive pairs retain the same source base.
Before allocation, compatible ARM64 memory kernels may reorder independent
single-definition arithmetic trees inside a pure region to make their lanes
adjacent. Memory accesses, calls, control-flow entries and potentially trapping
operations remain barriers; expression trees and source positions are preserved.
Constructed aggregates can seed those lanes by copying each leaf at its original
construction point, without requiring the input leaves to be packed already.
Scalar aggregate construction also contributes ordinary copy affinity per
leaf. When liveness proves the source dead at that construction, the source,
constructed field and later aggregate copies may share one register; live
siblings and repeated source fields still interfere normally.
Arithmetic dependencies are selected before competing copy-only affinities
in these memory kernels; safety and operand-residency checks still apply. A
memory kernel keeps an isolated pair scalar when its final values must be
extracted before separate scalar stores. Chained arithmetic and aggregate
returns can retain their lanes, where the setup cost is amortized or the
result remains grouped.
In these leaf functions, a borrowed aggregate read materializes only the fields
used by the function. Those fields are still loaded at the original read,
not at a later projection that could follow an aliasing write.
Aggregate copies omit unused register destinations in both integer and
floating-point registers: an unused leaf may share a register with a live
sibling defined by the same transfer and must not overwrite it.
Reference transfers to resident floating-point registers use direct 64-bit
loads and stores. Floating-point 64-bit stack transfers use the same direct
instructions in both stack-address windows, in Debug and Release. These are
bit transfers, preserving signed zeros and NaN payloads without an intermediate
integer register. The width of each memory access is unchanged.
Copies between a stack-resident floating-point value and a scalar SIMD
residence also use the final source or destination register directly. This
removes the otherwise redundant move through the floating-point scratch
register while retaining the same 64-bit payload transfer.
Floating-point negation similarly reads its allocated operand and writes its
allocated result directly; spilled endpoints retain the ordinary stack path.
On ARM64, a field offset used exactly once by the immediately following
reference load or store is folded into that memory access. A control-flow entry
at the transfer, an additional use or an indirect class field keeps the explicit
address calculation. Large direct offsets synthesize a temporary base without
materializing the projected reference. The folded transfer uses the same scalar
or aggregate width and preserves the original access point.
In compatible Release functions, checked dynamic collection reads whose
aggregate payload is unused keep the original index checks and diagnostics
without copying any element fields. Views and owning lists retain their
negative-index behavior. Debug and functions that reuse physical slots keep
their existing lowering.

Exact `copysignf`/`copysign` calls to a proven system provider use a sign-bit
transfer on ARM64. The transformation preserves signed zeros, infinities and
NaN payloads without relaxing floating-point arithmetic. A package-private
provider qualifies only when its macOS ARM64 metadata links libSystem alone,
without an archive, framework or provider dependency. Custom providers keep
their call. X64 register eligibility is unchanged by this ARM64 extension.

Exact system `sqrtf` and `sqrt` signatures lower to the scalar ARM64 `FSQRT`
instruction. Inputs and results may use ordinary floating-point residences, so
the function does not acquire call-preserved register restrictions. This is
the same IEEE operation already used for constant evaluation; unrelated
providers and mismatched signatures retain their calls.
Architecturally encodable nonzero float32 and float64 constants use scalar
`FMOV` immediates directly in their assigned register; every other bit pattern
keeps integer materialization. Inline `copysignf` and `copysign` operands and
results likewise stay in their scalar floating-point residences around the
existing exact sign-bit operation.

Functions with other exact scalar system-math signatures may also retain ARM64
residences across actual C calls. Their colors are restricted to x19–x28
(x28 remains reserved for a second stack window) and the preserved low 64 bits
of v8/v13–v15. Argument and result homes remain on the stack; the existing ABI
call, its result and its side effects are retained. Unknown providers and
signatures still take the conservative path. Call-free functions keep their
larger register set. Structural tests cover both float precisions and stack
windows; `Toolchain/Benchmarks/Native/MathCallResidence.sx` exercises linked
macOS calls with live loop values and exact NaN/signed-zero payloads.

Native layout omits storage for value declarations whose definitions and uses
have disappeared from the IR. Parameters and closure captures still retain
their ABI homes even when the body does not use them. Remaining values
normally keep unique deterministic homes. If their
cumulative count would exceed the shared machine limit, ARM64 and X64 instead
color physical stack spans from portable-IR liveness. Simultaneously live
values and incompatible scalar or aggregate residence classes never overlap;
storage reached through a derived reference remains pinned. These exceptional
large functions deliberately skip register coloring until virtual value
identities and physical stack homes become separate machine-IR concepts.
