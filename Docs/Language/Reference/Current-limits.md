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

The native backend currently targets Apple Silicon macOS. The interpreter is
the reference behavior where both execution paths cover the same operation.

The source language exposes no stable ABI, native layout, compiler IR, linker
configuration, allocator, or runtime handle. Low-level C operations remain
restricted to platform and package-boundary implementations. Package-native
artefacts currently mean one precompiled ARM64 Mach-O archive plus Apple
frameworks on `macos-arm64`; dynamic libraries and other targets are absent.
