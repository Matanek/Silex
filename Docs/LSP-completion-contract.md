# LSP completion contract

Completion is a language contract, not a list of editor conveniences. The
durable inventory lives in `Toolchain/Sources/Lsp/CompletionContract.zig` and
the parser-owned catalogue of completion sites lives in
`Toolchain/Sources/Parser/CompletionSites.zig`. Neither depends on workspace
Specs, agent instructions, sibling repositories, or an editor extension.

## Registry model

Every scenario has one stable identifier, a complete canonical source, one
partial source containing exactly one `<|>` cursor, required and forbidden
candidates, provenance, and a mechanical status:

- `protected` names the executable proof already in the LSP suite;
- `assigned_gap` records a reproduced omission and its owning implementation
  Part while the completion guarantees are being built;
- `irrelevant` requires a checked reason why completion cannot apply.

The audit rejects duplicate identifiers, absent cursor markers, missing
positive or negative assertions, missing provenance, missing proof text, and
an unrepresented capability family. It also rejects runtime data tied to
`.specs/`, `.agents/`, or an absolute user path. Mutation tests remove a family,
a proof, and a cursor to demonstrate that those omissions turn the gate red.

The matrix axes are closed enums: syntax position, symbol origin, receiver
shape, project topology, editing state, trigger, and observable output. Lexer
tokens, expression and statement union tags, and parser completion productions
are mapped with exhaustive switches and no catch-all branch. Adding a variant
without a completion policy therefore fails compilation of the LSP suite.

## Independent oracle boundary

`Toolchain/Sources/Lsp/Tests/CompletionOracle.zig` establishes the first
independent boundary: it derives the declared public instance surface from a
complete source parsed by the frontend and compares that surface with the LSP
response from an incomplete consumer. The oracle never reads LSP candidates or
recovery decisions, and invalid canonical sources are rejected. This initial
oracle does not yet claim to reproduce the complete semantic visibility graph;
catalogue, reexport, specialization, conformance, and package-topology cases
remain explicit `assigned_gap` rows until the typed frontend oracle covers
them.

Semantic, workspace, and protocol cases keep both a low-level proof and a
server proof. Real package or example failures are reduced to autonomous
fixtures; their original path is retained only as provenance.

## Error recovery invariant

A syntax error is not evidence that a completion context has no candidates.
The registry distinguishes an error before the cursor, at the cursor, after the
cursor, and in a neighbouring block. Completion recovery must isolate the
invalid region, retain the last reliable scope and receiver type, and keep an
internal recovery failure distinct from a valid empty result.

## Running the gate

From `Silex/Toolchain`, run:

```text
zig build test-lsp
zig build check
```

The ordinary `check` step already depends on the LSP suite. A change to the
parser catalogue, compiler enums, registry schema, or protected behaviour is
therefore rejected by the normal Silex validation path.

During construction of the contract, `assigned_gap` rows are allowed only with
an owner and an exact reproduction. Release qualification requires the count
to reach zero; a green registry audit alone does not claim that the recorded
gaps are fixed.
