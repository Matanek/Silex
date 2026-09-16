# Portable semantics

Portable IR describes Silex behavior without committing it to an ABI, object
layout, register set, or executable format.

## Compiler-managed values

Some public APIs expose values whose construction and lifetime remain under
compiler control. A specialized `GFX.ECS.Query<Pattern>` is one such
system-owned capability. The generated system adapter constructs it for
exactly one callback invocation; source may iterate it directly but cannot
pass, store, return or encapsulate it. This prevents its opaque native
ownership edge from escaping and makes an invalid transfer a source diagnostic
instead of a double release.

## Control flow and storage

Portable functions are control-flow graphs of explicit blocks. Every block
ends in a branch, jump, return, or fatal terminator; target-dependent
fallthrough semantics never enter the frontend.

Mutable locals are abstract typed storage in portable IR. Reads and writes
do not expose an address or reference; target lowering alone chooses stack
slots. `while`, `break`, and `continue` are ordinary CFG branches and
backedges before they reach the machine backend.

A `mutex` block lowers to paired portable `mutex.lock` and `mutex.unlock`
effects. Semantic control-flow cleanup inserts unlocks before every exit;
target lowering owns the process-wide recursive lock representation.

## Values and nominal types

Nominal structures and structural tuples remain typed aggregates in portable
IR. Construction records one typed value per element and reads select
elements by structured indices; source code never observes an address,
offset, layout or copy machine operation. Calls, returns, local storage and
recursive equality preserve value semantics in the reference interpreter and
native backend.

Class roots lower to typed retain and finalization operations. Their runtime
representation, unique-finalization guard, cycle handling and target layout
remain private to the interpreter and target lowering; source code observes
only shared identity and the specified `drop` order.

Aggregate class construction acquires an initial root, just as a declared
constructor does, and returns an owned temporary.

Reading a stored field from an owned temporary retains the selected value
before dropping the complete owner, including sibling resources and its
finalizer. The resulting value carries its own cleanup obligation. This also
applies to named tuple projections and the present branch of optional access;
reading a scalar still releases its temporary owner. A reference into that
released owner is not propagated. Collection indexing follows the same rule:
the selected element gains its own lifetime before the temporary collection is
released. Built-in `count()` and `is_empty()` reads release an owned temporary
receiver after producing their scalar result; `str.count()` does likewise.
Stored receivers retain their original lifetime.

Indirect callback calls follow the ownership contract of direct calls: a
temporary value argument transfers its existing owner, while a stored argument
is retained for the callee. An owned callback result carries its transfer flag
so binding, projection and discarded-result cleanup preserve that obligation.

Tuple construction retains borrowed resource elements and transfers owned
ones. The completed tuple is an owned value. Destructuring a stored tuple
retains the selected fields; destructuring an owned temporary transfers them
into the new bindings without abandoning or double-retaining the tuple.

## Generics, protocols, and extensions

Generic nominal declarations are specialized before semantic lowering. One
deterministic concrete declaration represents each complete argument list
across modules, aliases and reexports; generic classes therefore reach the
IR as ordinary distinct class identities with concrete bases, fields,
methods, static storage and finalizers. Template bookkeeping and generated
names remain compiler details rather than runtime or source APIs.

Protocol declarations keep a nominal identity through module composition,
aliases and reexports. Semantic analysis validates each explicitly declared
conformance against exact public instance signatures, including inherited
class methods and conformances. Dynamic protocol values lower to explicit
typed erasure, discriminant tests and payload extraction in portable IR.
Their closed-program discriminant and inline payload layout remain private to
target lowering; no witness table, machine address or calling convention is
exposed in source.

Erasure preserves the payload's ownership and transfer status. A temporary
structure converted to a protocol carries its existing resources into the
destination; a conversion of a stored value retains the ordinary copy rules.

A generic parameter may carry one protocol identity through parsing, module
activation and public interfaces. Specialization validates the selected
concrete type's nominal or inherited conformance before rewriting the body;
requirement calls then resolve as ordinary concrete method calls. Static
generic constraints therefore add no runtime dispatch or representation.

Type extensions are composed as source-level method providers before generic
specialization and semantic lowering. Their activation set is derived from
each source file's transitive `use` closure. Once selected, an extension call
is an ordinary statically bound typed call; the portable IR and target backend
gain no extension object, registry, dispatch table or ABI concept. Generic
extension specializations additionally retain their declaring provider in
their compile-time identity, so equally named providers cannot alias through
the specialization cache.

Protocol conformances introduced by extensions retain their provider and
activation files through composition and generic specialization. The
frontend uses that metadata for exact-target constraint checking and dynamic
erasure, while lowering receives only the closed set of concrete protocol
payloads needed by the portable IR. No runtime registry or externally visible
witness-table ABI is introduced.

## Enums, matches, and optionals

Associated enums are portable nominal declarations whose variants carry
typed positional values. Construction records the enum and variant by
structured indices; module interfaces expose only the nominal identity and
variant signatures. Target lowering may choose a tag and payload layout, but
neither is a source-visible field, conversion, ABI or stable IR format.

Raw enums keep each validated `int` or `str` literal in the nominal variant
declaration. The typed `enum.raw` operation is the sole observation path;
target lowering may cache that scalar beside its private tag, but exposes no
layout, mutable field or enum/raw conversion to source code.

Exhaustive expression matches lower their once-evaluated subject to explicit
variant tests, typed payload extractions and ordinary CFG branches. Every
branch copies its exact-typed result into the merge value; the portable IR
does not expose a source tag field or apply an implicit convergence cast.
A terminal `else` is simply the final CFG destination after the named tests;
it creates neither a synthetic variant nor a catch-all payload binding.

A subjectless condition match lowers ordered boolean expressions into the
same CFG shape. Each condition remains in its fallthrough block, so evaluation
stops after the first true condition; a required terminal `else` supplies the
last destination.

A value-match branch block lowers its ordinary statements before its direct
terminal `yield`. The yielded exact-typed value is copied into the match merge
value after branch-local ownership cleanup. Nested matches keep independent
merge values: each `yield` belongs to the nearest value-producing match block.

Literal matches accept boolean, integer and string subjects. Integer patterns
are checked and represented in the exact integer type of the subject; boolean
coverage is exhaustive only when both values have an unguarded branch, while
the open integer and string domains require `else`. Ordered literal equality
tests use the same portable scalar operations as ordinary source comparisons;
the language exposes no jump table, hash dispatch or fallthrough behavior.

Statement matches reuse the same selection CFG and payload extraction, but
discard the result of a concise call, cascade, propagated result or nested
match branch. A branch may instead contain an ordinary statement block.
Branch terminators connect directly to the surrounding return or loop context;
continuing branches alone join the post-match block.

Optional values remain typed in portable IR through explicit `optional.null`
and `optional.some` instructions. A branch-local presence proof emits an
internal `optional.unwrap` only on the proven control-flow edge. Target
lowering currently represents optionals as a presence slot followed by the
flattened payload, but this layout is an experimental backend detail rather
than a source ABI or serialized format.

Conditional optional bindings lower their source, presence comparison and
extraction directly into the existing CFG. The source stays in the reached
condition block, while the body-local binding begins with the proven unwrap;
loop backedges therefore preserve the source language's exact retry,
`continue`, and `break` evaluation rules.

Safe member access uses the same pattern at expression granularity: one
receiver evaluation, a presence branch, ordinary member resolution on the
unwrapped child, and a flat optional result merged with the absent edge.
Arguments and mutating write-back live exclusively on the present edge.

## Ownership of nested value receivers

Mutating value methods return their updated receiver to the caller. When that
receiver is stored in a class field, the caller keeps the original edge alive
and gives the callee a temporary root. Collection writes therefore preserve the
stored value observed through reentrant class aliases until receiver write-back,
just as scalar fields do. At return, the updated receiver moves back to the edge
and the old edge is released. These internal ownership transfers do not invoke
additional value `drop` hooks; class finalizers run when their last reachable
owner disappears. Positional, named, optional and protocol calls use the same
write-back rule. Explicit mutable-reference calls retain their separate location
semantics.

## Ownership carried by mutable references

An internal mutable reference identifies both a storage address and the
ownership domain of that place. Class-field projections select an edge;
structure, optional and array-element projections preserve the enclosing
domain. Calls, returns and captured mutable receivers preserve that metadata.
`reference.is_edge` lets semantic lowering select the existing root or edge
retain/drop operations without exposing a new source type or reference ABI.

A mutating value receiver reached through a reference holds a temporary root
until write-back. Write-back reloads the current destination after the call,
so a reentrant replacement is released in its actual domain. Whole-value
assignment and collection edits also use the referenced place's domain.

Compiler-generated typed resource slots are deliberately root owners although
they reside in a class. Their references explicitly remove the edge domain;
the resource registry's bookkeeping collection remains a class-owned edge.
Physical containment alone therefore does not establish ownership.

The current ARM64, X64 and evaluation LLVM encoders use bit 63 of an internal
reference word for the edge flag and clear it before dereferencing. This
private representation assumes user-space addresses below bit 63. Conversion
through `C.mutable_pointer` clears the flag before exposing an ordinary C
address. `reference.address` expresses that normalization in portable IR;
the interpreter keeps the same domain explicitly beside its reference value.
These details are not a public serialization or foreign-call ABI.
