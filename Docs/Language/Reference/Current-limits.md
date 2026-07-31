# Current limits

The current compiler intentionally keeps the language surface small.

Not implemented yet:

- custom iterators;
- string iteration;
- method extraction;
- package lockfiles;
- C++ interop and public general-purpose C interop;
- safe optional assignment, forced extraction, and `??`;
- wildcard or guarded `match` branches.

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
