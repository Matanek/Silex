# Current limits

The current compiler intentionally keeps the language surface small.

Not implemented yet:

- package lockfiles;
- C++ interop and public general-purpose C interop;

List literal inference is currently syntactic. A non-empty list whose first
element is a variable or another expression without an immediately visible
type needs a collection annotation, for example
`let values:Pair<int>[] = [first, second]`. Removing this annotation requires
moving collection-type creation out of the parser and into typed analysis.

The complete, host-executed native backend currently targets Apple Silicon
macOS. Linux x64, Windows x64, and Windows ARM64 also emit native executables;
their output is cross-linked and structurally validated on macOS but still
requires runtime validation on those operating systems. The interpreter is the
reference behavior where both execution paths cover the same operation.

The source language exposes no stable ABI, native layout, compiler IR, linker
configuration, allocator, or runtime handle. Low-level C operations remain
restricted to platform and package-boundary implementations. Package-native
artefacts mean one target-matched static archive per provider: Mach-O ARM64,
ELF x64, COFF x64, or COFF ARM64. Manifests may declare Apple frameworks and
named Linux or Windows system libraries. Dynamic-library providers remain
absent.
