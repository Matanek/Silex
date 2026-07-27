# Current limits

The current compiler intentionally keeps the language surface small.

Not implemented yet:

- custom iterators;
- string iteration;
- method extraction;
- package lockfiles;
- visible C or C++ interop in application source;
- safe optional assignment, forced extraction, and `??`;
- wildcard or guarded `match` branches.

The native backend currently targets Apple Silicon macOS. The interpreter is
the reference behavior where both execution paths cover the same operation.

The source language exposes no stable ABI, native layout, compiler IR, linker
configuration, allocator, pointer, or runtime handle.
