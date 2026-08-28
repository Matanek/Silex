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

Imperative matches reuse the same selection CFG and payload extraction, but
place ordinary statement blocks at each destination and produce no value.
Branch terminators connect directly to the surrounding return or loop
context; continuing branches alone join the post-match block.

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
