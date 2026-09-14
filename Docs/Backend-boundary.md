# Boundary between portable IR and compilation backends

Silex chooses a compilation backend only after source analysis, package
composition, specialization, and typed portable IR construction. Both `native`
and `llvm` therefore receive the same program contract; neither backend parses a
different language or repairs missing semantic information after the choice.

## Guarantees carried by portable IR

Portable IR identifies every value and operation with an explicit Silex type.
Function signatures, structures, enumerations, protocols, optionals,
collections, references, globals, package boundaries, and source positions are
resolved before backend lowering. Control flow uses typed blocks and explicit
transfers rather than backend labels or registers.

Observable effects also remain explicit. Calls, package-boundary calls, output,
assertions, panics, mutex operations, checked arithmetic, conversions, bounds
checks, and memory accesses cannot be silently reordered across one another.
Aliasing is conservative unless a shared optimizer proves a narrower relation.

Ownership and lifetime are instructions in the common program. Retains, drops,
deep copies, collection replacement, class finalization, captures, and borrowed
references keep their source semantics through optimization. A backend supplies
the storage and runtime mechanism, but it may not infer away an ownership event
without the same proof required by the shared optimizer.

Numeric operations preserve their declared width, signedness, overflow policy,
conversion checks, floating-point precision, NaN behavior, and signed zero.
Release optimization is applied to this portable contract before either
backend-specific lowering. Debug sends the closed portable program directly to
the selected backend.

## Responsibilities owned by each backend

The native backend lowers portable IR to the shared machine IR, applies the
target's register and instruction policies, emits the platform object or image,
and links the native runtime and package artifacts. Its register representation,
stack layout, calling convention, object writer, and embedded runtime layouts
are private native decisions.

The LLVM backend serializes the same closed IR to LLVM IR, runs the qualified
LLVM optimizer and code generator, then links its formatting runtime and the
same resolved package artifacts. LLVM types, aggregate reserves, private heap
headers, target data layout, attributes, and generated calling convention are
adapter decisions. They do not redefine Silex types or become a package ABI.

An unsupported operation is a backend refusal. Explicit `--backend llvm` never
executes a native implementation of the rejected function, and explicit
`--backend native` never invokes LLVM. The reference interpreter remains a
separate semantic oracle selected by `silex interpret`.

## Stable contract without a frozen representation

Tests at this boundary compare source observables and exercise both lowerings.
Cache keys include backend, compiler identity, target, configuration, sources,
package artifacts, and the qualified LLVM version where applicable. This makes
backend transitions inspectable without exposing the serialized IR or cache
format as a compatibility promise.

The portable IR schema, LLVM adapter layouts, native machine IR, and runtime ABI
may still evolve together with their tests. Stability means preserving typed
semantics and explicit responsibilities, not freezing an internal file format
or making two backend layouts identical.
