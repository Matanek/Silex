# Release optimization

After native program closure, Release mode applies semantics-preserving
transformations first to the retained portable IR, then to the target's machine
representation.

The optimizer exposes a stable development-only pass registry. Each entry
records its precondition, postcondition, and preserved invariants. The
optimizer oracle can stop after one registered pass or disable exactly one
pass for attribution and bisection; these controls are not part of the public
`silex` command line or language. In qualification mode, the portable verifier
runs on the input and after every registered pass. It checks typed operation
contracts, direct and indirect call signatures, ownership-operation domains,
native-width memory operations, control targets, definitions and uses,
dominance, and complete edge-copy lowering of join values. A malformed program
therefore fails at the pass that produced it instead of surfacing only in a
later native benchmark.

## Qualify adversarial robustness

The optimizer oracle turns the interaction plan in
`Benchmarks/Optimizer/Coverage.json` into executable Silex projects. Every
binary combination of the registered type, control, memory, alias, call, loop,
error, package, and target axes is materialized in all four states. The five
registered high-risk triplets are materialized separately. A generated case is
accepted only after raw and Release interpreter results agree, a repeated
compilation produces byte-identical textual IR and output hashes, every Release
pipeline prefix preserves the same observable result, and both the ARM64 and
X64 machine allocation paths accept the optimized program. The quick campaign
samples native Debug/Release execution; the qualified campaign runs one native
case for every axis pair and every risk triplet. Every selected native build is
repeated. The emitted Debug code object and the complete Release executable must
have the same SHA-256 digest. The system linker's Debug-only Mach-O UUID and
link metadata are deliberately not claimed as reproducible code bytes.

`zig build optimizer-robustness-quick` is the bounded per-change campaign.
`zig build optimizer-robustness-qualified` adds cold, warm, invalidated,
partially replaced, restored, and concurrently populated cache states, then
compiles a graph of sixteen linked packages containing recursion, an aggregate,
a collection loop, and a larger live program. `zig build
optimizer-robustness-soak` repeats the complete interaction plan across three
deterministic seed windows by default; an explicit round count and initial seed
can be passed to `optimizer-oracle -- robustness-soak`.

All campaigns use fixed source, IR, and native-artifact size ceilings. They
write seed-addressed sealed interaction tables plus uniquely named run records
under `.zig-cache/optimizer-oracle/robustness/`; an existing sealed table may
be reused only when its bytes match. Failures from the numeric differential
generator retain their seed and reduced Silex source. Invalid-source cases are
compiled twice and require the same nonempty diagnostic. Unit mutation tests
prove that changes to values, effects, diagnostics, exit codes, Debug/Release
coverage, target lowering, or cache state make the verdict fail.

The manual `optimizer-robustness.yml` workflow provides a 90-minute external
hang limit, records the exact commit and macOS ARM64 host, and uploads partial
evidence even on failure. ARM64 and X64 lowering are structural proofs on every
generated case; only the host named by a campaign record is a native execution
claim. Toolchain-owned language and native-math tests set the internal
`SILEX_USER_PACKAGE_ALLOWLIST` to `STD`; the robustness workflow sets an empty
allowlist. Thus unrelated live package links cannot change the test graph of a
fixed Silex commit without changing the user's home environment, while explicit
workspace links remain available.

## Simplify portable IR

Release propagates constants and copies across the control-flow graph. It
promotes profitable, non-addressed integer and boolean locals to SSA values,
constructs join values, removes trivial joins, lowers the remaining parallel
edge transfers, and prunes unreachable blocks. Distinct live joins retain
distinct typed SSA residences, so promotion does not need to manufacture
control-flow blocks merely to share storage. Floating-point recurrences remain
eligible for the later promotion pass, after loop simplification has exposed
their complete edge transfers. These decisions are automatic and require no
source annotation.

Before constructing edge definitions, SSA promotion redirects empty jump-only
blocks to their effective target. A scalar join reached directly from a branch
can therefore place its parallel copies in that predecessor instead of
splitting the critical edge and adding a native jump. This applies uniformly
to integers, booleans, float32, and float64. Locals spanning several live joins
share one residence when an intermediate PHI only forwards its incoming value
to a unique successor PHI and has no read of its own. Distinct live joins keep
distinct typed residences and lower complete parallel edge transfers; sibling
branch targets are never coalesced when they require different incoming values.

The following value-range pass propagates signed and unsigned integer
intervals through the verified CFG. True and false comparison edges refine
their operands; joins take a conservative hull, and cyclic growth widens only
at loop headers so a dominating body condition remains available. Remainders
by a proven constant nonzero divisor contribute their signed or unsigned result
interval without removing the divisor check. Release removes an integer add,
subtract, multiply, or conversion check only when the complete mathematical
interval fits its result type. Unproved operations keep their observable
overflow or conversion failure. ARM64 lowering consumes the resulting checked
flag uniformly for addition, subtraction, and multiplication; a proven
unchecked multiply emits neither high-half overflow work nor an overflow
branch.

After final SSA promotion, Release recomputes exact scalar facts independently
of block serialization order. A constant may cross a join only when every
reachable definition proves the same type and bit pattern; divergent PHI
inputs remain unknown. The resulting facts fold safe arithmetic, replace
constant branches, prune unreachable blocks, and remove newly dead copies to a
fixed point. Representable constant integer conversions contribute a constant
of the target width, exposing dependent arithmetic to the same fixed point.
Constant shifts fold only when their signed or unsigned count is inside the
left operand width. Range analysis also marks dynamic shifts unchecked when
the complete count interval proves that condition; ARM64 then omits the width
guard. Invalid or unproved counts remain observable. Checked integer
operations and conversions fold only when the result fits, while non-finite
floating-point arithmetic and division by zero remain explicit.

Division and remainder become unchecked only when the divisor interval excludes
zero and, for signed integers, either the divisor excludes `-1` or the dividend
excludes the type minimum. ARM64 then omits both the zero and signed-overflow
guards. Every unresolved divisor retains both observable failures.

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
Nested constructors form the same scalar dependency graph: a child passed only
to a non-escaping parent can disappear with that parent, while an escaping
parent keeps every aggregate child needed to materialize its value. Nested
projections follow those child roots instead of leaving loads from an eliminated
parent. Each scalar leaf retains its declared width, including `float`,
`float64`, and fixed-width integers.
Within one block, loads of non-addressed scalar-structure locals reuse their
last single-definition snapshot. Intermediate stores overwritten in the same
block are removed when no remaining load observes them and the local is never
addressed. The last store remains available to successor blocks;
redefined sources and addressed locals are not forwarded.

The registered `reference_memory_elision` pass tracks explicit same-block
address derivations. It removes an exactly overwritten reference or
mutable-view store and forwards an exact load after the surviving store. A
read through another root is conservatively considered possibly aliasing;
calls, unknown memory effects, and block boundaries invalidate both proofs.
The pass never removes the final observable mutation or an unproved bounds
failure.

For flat numeric or boolean value structures, a reconstructed reference or
mutable-view store writes only the changed fields when the other fields come
from a still-current snapshot of that exact destination. Calls, unknown
effects, and block boundaries end this proof. Owning collection replacement,
stale snapshots, and structures with owned fields keep their value semantics.
An owning scalar collection replacement remains explicit so its copy-on-write
detach and lifetime effects are preserved. Its bounds failure also remains
unless a fixed length or traced list literal and a normalized constant index
prove the write in range. That proof is carried by the portable instruction
through ARM64 and X64 lowering, so both backends omit only the proven guard. A
later load may still resolve to a scalar list-literal element or to the exact
replacement value when the collection lineage and both normalized constant
indices are known. This forwards values across the functional update without
treating the input and result storage as aliases or removing the update itself.
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

Before inlining, a closed-program summary reaches a fixed point over the
direct-call graph. It records transitive memory, ownership, boundary,
synchronization and output effects, whether any checked operation or callee
can fail, local instruction and control cost, return count, scalar/aggregate
pressure, and recursion. The inliner combines that summary with its bounded
expanded cost and whether the call site lies in a loop. It rejects recursive
cycles and, for newly supported IR forms, observable boundary, ownership,
synchronization or output effects. Calls admitted by the previous bounded
inliners remain a conservative compatibility floor; their established
decisions cannot be revoked merely because a richer summary now recognizes an
effect that was already present. Small reference and view callees remain
eligible when their exact reads, writes and checked operations can be cloned at
the original site. This keeps a single deterministic model for straight-line
and control-flow inlining without turning a new profitability analysis into a
semantic change for already-qualified callers.

Release inlines eligible direct callees across branches, loops, and multiple
returns, in addition to constant-result and small straight-line
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

A signed zero-origin induction used only by a simple `while index < limit`
header and its unit increment may become a countdown from `limit` to zero.
This requires one unconditional two-block loop, a stable parameter or earlier
value for `limit`, exactly one initialization and one update, and no other load
or address of the induction local. Observed indices, escaped addresses,
additional control flow, non-unit updates, and mutable bounds retain their
original ascending loop. The rewritten decrement is unchecked because the
positive loop condition proves that subtracting one remains representable.
On ARM64, when only copy instructions separate that decrement from the simple
backedge, the decrement sets the comparison flags directly and the repeated
compare is omitted. Because the positive entry condition and unit decrement
exclude a negative counter, the backedge tests the zero flag directly. The
entry guard remains an ordinary signed comparison.

After an effectful helper is inlined, a same-block address of a flat scalar
local may be demoted back to independent field locals when every use is an
exact field reference load or store. Any escaping address, unknown reference
operation or control-flow boundary keeps the aggregate addressable. This
post-inlining scalar replacement exposes the final caller without changing
alias observations.

At machine encoding, ARM64 and X64 compute the same transitive infallibility
fixed point for the private Silex call convention. A direct call omits its
status-register branch only when every instruction and direct callee in that
closure is proven infallible. Checked arithmetic, bounds operations, indirect
or external calls, allocation, assertions and panics retain the status path.

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
it is legal. A shared target-family cost model scores arithmetic, branches,
loads, stores, shuffles, scalar extractions, spills, calls and code size. The
portable SLP priority records useful isomorphic arithmetic depth; loop-local
work is amortized, while a stand-alone SSE pair whose packing cancels its
arithmetic saving remains scalar. Low-priority layout groups remain affinity
facts for profitable descendants and are never counted as vector work by
themselves. Exact machine legality, live ranges, memory barriers and scalar
uses prune the admitted plan a second time. Addressable values, unsupported aggregates, and values that
cross unsupported machine operations remain explicit spills. Empty SSA edge
transfers are bypassed after allocation, and the ARM64 collection cursor
recognizes both induction updates separated by independent SSA copies and
coalesced updates whose header and increment copies have disappeared. It
borrows a volatile integer register only when that register's allocated live
range does not overlap the loop, excludes the encoder-owned floating-literal
cache registers even though they have no allocated slots, reserves the
pointer-termination register
before integer coloring, and removes a per-iteration view-descriptor copy only
when no body operation uses that copy. A qualifying unit-stride loop therefore
uses a post-indexed data cursor and may compare that cursor directly with its
end pointer instead of rebuilding an indexed address on every iteration. The
unit increment may precede other independent recurrence copies on the loop
edge; those copies remain in place, while any extra use of the induction still
rejects pointer termination. Fully
resident leaf functions allocate no value frame. Debug retains the direct
stack-resident lowering.

ARM64 also admits a restricted set of memory operations. Checked dynamic
loads, view replacement, and explicit address/reference accesses retain their
bounds and failure behavior. Addressed local spans stay pinned. Scalar
references, loads and reference stores may remain in registers; direct
reference transfers address a resident reference without first copying it
through a scratch register. Pure aggregate construction and copies can also
retain arithmetic residences on ARM64, with the existing parameter and return
homes. Functions with direct Silex calls use only callee-saved integer colors,
so loop state can remain resident across the call. A local address used solely
as provenance for view element references pins the address but not the view
descriptor: mutating the element cannot change its base or count. Other local
addresses continue to pin their complete span, whose width is explicit in the
machine contract. Copy affinity does not cross these forced memory spans, so
an immutable snapshot taken before an indirect mutation cannot share the
residence of a post-call reload. View element references consume resident base,
count and index values directly. Checked references materialize a resident
original index on their failure edge before producing the unchanged diagnostic.
Independent
arithmetic may use paired SIMD residences,
while values consumed or produced by the memory instructions remain scalar
or stack-resident. Packing a scalar into a SIMD lane captures it at its
original use, before another scalar can reuse its register.

Release may also color a long scalar floating-point region inside a function
that contains unsupported machine operations. This regional path is limited to
functions that load a wide homogeneous aggregate and contain at least 32
contiguous floating-point operations, so its setup is amortized. Every
unsupported instruction is a hard barrier: its complete uses and definitions,
and every interval live across it, remain stack-resident. Mixed aggregate
loads and aggregate calls inside loops retain the whole-function spill path.
On ARM64, the same barrier model admits a repeated scalar loop with at least
four compatible arithmetic operations even when an output or another stack
effect follows the loop. Values confined to the loop can then remain in
registers; values live across the effect retain their deterministic stack
homes.
The regional path does not use paired SIMD residences or memory scheduling.
Every eligible function rejects a pair when delaying its first calculation
would cross a scalar use of that result, including pure aggregate constructors.
Aggregate returns copy resident lanes into the
caller's return storage instead of reading stale stack homes.
When an aggregate construction is immediately returned, ARM64 writes its
source fields straight to that storage and omits the temporary aggregate's
stack materialization. The return must be the construction's unique linear
successor; control-flow entry points keep the ordinary materialized path.
Stack-resident aggregate parameters use paired 64-bit transfers only for
leaves without scalar register residence. When the parameter pointer itself
arrives on the stack, the second transfer scratch stays distinct from that
pointer so consecutive pairs retain the same source base.
Replacing an ordinary slot-width aggregate in a collection similarly forms
the source stack address once and uses paired 64-bit transfers where their
offsets are encodable. Compact float32 storage and larger replacements retain
the scalar copy path.
Before allocation, fully residence-compatible native functions may reorder
independent single-definition arithmetic trees inside a pure region to make
their lanes adjacent. This includes pure or read-only loops as well as mutable
memory kernels. Memory accesses, calls, control-flow entries and potentially
trapping operations remain barriers; expression trees and source positions are
preserved. Float32 division is nontrapping under Silex semantics and can move
with its pure dependency tree; integer division remains a barrier because its
failure behavior is observable. The resulting order belongs to the shared
machine program: ARM64 allocates it directly, while X64 preserves it before
applying its integer and baseline-SSE allocation.
Constructed aggregates can seed those lanes by copying each leaf at its original
construction point, without requiring the input leaves to be packed already.
Scalar aggregate construction also contributes ordinary copy affinity per
leaf. When liveness proves the source dead at that construction, the source,
constructed field and later aggregate copies may share one register; live
siblings and repeated source fields still interfere normally.
Arithmetic dependencies are selected before competing copy-only affinities in
these scheduled regions; safety and operand-residency checks still apply. An
isolated pair remains scalar when its final values must be extracted before
separate scalar stores. Chained arithmetic and aggregate returns can retain
their lanes, where the setup cost is amortized or the result remains grouped.
When two floating-point recurrence copies are scheduled in reverse order, SLP
canonicalizes their lane order only if both results have multiple definitions
and the incoming operands already form the corresponding reversed pair. This
keeps genuine loop recurrences paired without treating unrelated reversed
copies as a vectorization opportunity.
Recurrence ancestry is likewise confined to the loop that carries it. Values
copied after loop exit are stable snapshots: their compatible XY, XYZ, or XYZW
arithmetic may be costed independently instead of being rejected as an
out-of-loop recurrence.
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
X64 applies a corresponding regional policy to scalar integer and boolean
loops containing at least four compatible arithmetic operations. Integer and
boolean output, direct and indirect calls, function addresses, and pure
aggregate construction or copies may remain outside those loops as hard
barriers. Values confined to a scalar region may use `r8` through `r11`, which
are volatile in both System V and Win64. Values live across a barrier retain
their deterministic stack homes. Direct-call arguments and results remain
addressable; indirect calls additionally pin the two-slot function value.
Aggregate results remain addressable, but their scalar source leaves are read
straight from their residences instead of being reloaded from stale stack
homes. Calls or aggregate operations inside the loop, strings, floating-point
values, unsupported operations and short loops retain the whole-function
spill path.
When these X64 residences cover a contiguous prefix of virtual slots, Release
omits that prefix from the physical value frame. A shifted frame base preserves
the existing virtual offsets for every remaining stack home, the cycle context,
and incoming stack arguments. The machine verifier accepts the contraction
only when every omitted slot has a register residence and the remaining frame
has the exact aligned suffix size. ARM64 keeps its ordinary frame base.
On ARM64, an unchecked integer multiplication by an adjacent, single-use
constant of the form `2^n + 1` selects one shifted `ADD`. Checked
multiplications retain the ordinary multiply and overflow proof.
In Release, an adjacent, single-use signed or unsigned divisor constant that
is neither trivial nor a power of two selects a shared reciprocal recipe on
ARM64 and X64. The backends realize the quotient with a high-half multiply,
the required correction, and a shift; remainder reuses that quotient in a
multiply-subtract sequence. This applies to every fixed integer width because
signed operands are sign-extended and unsigned operands are zero-extended at
the native boundary. Such a divisor cannot trigger division by zero or the
signed minimum divided by `-1`, so the replacement also preserves checked
division semantics. Exact powers of two use a separate selection: unsigned
quotients and remainders become a shift or mask, while signed quotients add the
sign bias required for truncation toward zero before the arithmetic shift and
signed remainders reuse that quotient. A negative divisor negates the quotient.
When range analysis proves a signed dividend non-negative and the constant
divisor positive, ARM64 omits the final quotient sign correction; all other
signed ranges keep it.
Checked division or remainder by `-1` retains the ordinary path and its minimum
value overflow guard; an earlier range proof may make the same operation
eligible once it is unchecked. Debug and constants not covered by either
recipe retain the ordinary hardware division path.
The LLVM advisor reports a strength-reduction opportunity only while the
optimized Silex program still contains a reachable multiplication. An LLVM
shift introduced in a helper that the final Silex caller has specialized away
is therefore not classified as a backend selection gap.
On ARM64, a field offset used exactly once by the immediately following
reference load or store is folded into that memory access. A control-flow entry
at the transfer, an additional use or an indirect class field keeps the explicit
address calculation. Large direct offsets synthesize a temporary base without
materializing the projected reference. The folded transfer uses the same scalar
or aggregate width and preserves the original access point.
Compact float32 pairs loaded from collection elements retain their exact byte
offset. ARM64 uses the scaled 64-bit vector load only for an eight-byte-aligned
offset; a pair beginning at an odd float32 field uses the exact unscaled form,
or a synthesized address when the offset exceeds that form's range. The
backend never rounds such an offset down to the previous aligned field pair.

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
