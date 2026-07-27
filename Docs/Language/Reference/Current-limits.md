# Current limits

The current compiler intentionally keeps the language surface small.

Not implemented yet:

- custom iterators;
- string iteration;
- method extraction;
- package lockfiles;
- C++ interop and general C interop beyond the documented macOS `write`
  boundary;
- safe optional assignment, forced extraction, and `??`;
- wildcard or guarded `match` branches.

The native backend currently targets Apple Silicon macOS. The interpreter is
the reference behavior where both execution paths cover the same operation.

The source language exposes no stable ABI, native layout, compiler IR, linker
configuration, allocator, or runtime handle. Its only pointer surface is the
temporary opaque `C.Pointer<uint8>` produced for the documented foreign call.
