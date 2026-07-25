# Compiler architecture

The initial compilation path is:

```text
Silex source
    -> lexer
    -> parser and AST
    -> semantic validation
    -> typed Silex IR
    -> reference interpreter
```

The future native path will branch only after the typed IR:

```text
typed Silex IR
    -> target lowering
    -> machine IR
    -> instruction encoding
    -> object or executable emission
```

## Current decisions

- The established Silex syntax is input to the project, not something to
  redesign incidentally while building the backend.
- Zig 0.16 is a bootstrap implementation detail.
- The compiler never generates C or C++.
- The textual IR is deterministic so tests can treat it as an observable
  artifact without declaring its serialization stable.
- `main` is the only source name with entry-point semantics. Other function
  names are chosen freely by the user.
- Native code generation starts after the interpreter provides a semantic
  reference.

## Current limits

- Empty function bodies only.
- `void`, `float`/`float32`, and `str` signature types only.
- No statements, expressions, calls, values, allocation, or runtime.
- No native backend or executable emitter yet.
- No component serialization or composition yet.
