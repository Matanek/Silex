# Implementation status

This page separates the portable behavior already covered from the runtime,
native, serialization, and editor work that remains.

## Portable coverage

- Executable values include every historical integer width, `float32`,
  `float64`, `bool`, `str`, and `void`.
- Conditions, short-circuit boolean expressions, mutable locals, checked
  arithmetic updates, and `while` loops with `break` and `continue` are
  implemented.
- Nominal structures can be declared, initialized, read, copied, passed,
  returned and compared recursively in the reference interpreter and verified
  native backends. Mutable field paths are lowered by rebuilding portable
  value aggregates and preserve independent copies. Public structures compose
  across modules and packages. Constructors lower to internal IR functions
  returning a fully initialized value; definite initialization is established
  before that lowering and exposes no receiver ABI.
- Method mutability is a fixed point over writes through `self` and the method
  call graph. Nonmutating methods lower as value-receiver functions. Mutating
  methods return updated receiver state internally; when they also return a
  source value, a private typed IR aggregate carries both results. The caller
  writes the receiver component back to its abstract place, so no reference,
  address or receiver convention enters the language contract.

## Runtime and native limits

- String concatenation currently retains its native storage until process exit;
  reclamation and a general allocation model remain future internal work.
- No public system API or general native allocation API exists yet.
- Debug `macos-arm64` images expose function, physical `.sx` path, line and
  column source symbols to LLDB. Source-variable inspection and Debug symbols
  for the structurally emitted non-host targets are not implemented yet. The
  backend also has no general dynamic-library model, public source-level
  external declarations, or ABI stability guarantee. Besides the closed
  system contracts, `macos-arm64` supports typed C ABI calls owned privately by
  a package that declares its static provider.
- Interfaces, IR and package graphs are in-memory structures and have no stable
  serialized format yet.

## Editor support

LSP syntax diagnostics always analyze the open buffer; semantic diagnostics
currently run only when the unit has no `use`. Completion independently
resolves the project module index and direct package graph, with open buffers
masking their disk providers. Definition navigation uses the same target and
overlay-aware project view for imported or directly qualified module and
package declarations. It follows methods declared by extensions, qualified
call return types, destructured query bindings, field chains and cascades when
their imported receiver type can be inferred. Bare function values resolve to
declarations in the current source or through explicit imports, so callbacks
navigate like direct calls.

The bootstrap rebuilds that editor view for each request. An incremental cache
remains a performance optimization and must preserve the same observable
results.

Document colors recognize direct `Color.bytes`, `Color.rgb`, `Color.rgba` and
named GFX palette expressions whose components are literals in the displayable
`[0.0, 1.0]` range. This bootstrap recognition is intentionally syntactic;
semantic constant evaluation should eventually replace its local palette
knowledge so aliases and computed colors work without coupling the language
server to one package API.

References, rename, hover, formatting, semantic tokens and project-wide
semantic diagnostics are not implemented yet.
