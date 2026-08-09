# Recognize compiler-provided declarations

An `intrinsic class` publishes a source-level API whose storage and behavior
are provided by the Silex compiler:

```sx
public intrinsic class Resources {
    public func insert<T>(value:T)
    public func has<T>() bool
}
```

Its methods contain signatures without bodies. This makes the contract
discoverable without presenting a placeholder implementation or a runtime
failure as ordinary source code.

Application packages cannot use `intrinsic` as a general implementation or
interop mechanism. The compiler recognizes a fixed set of canonical classes
and validates their complete signatures. An unknown intrinsic class, a method
body, or a signature that differs from the compiler contract is a compilation
error.

Intrinsic classes cannot declare fields, constructors, `drop`, inheritance, or
protocol conformances. Those details belong to the compiler-provided
implementation. Consumers create and call an intrinsic class exactly like an
ordinary public class.
