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

The matrix axes are closed enums: syntax position, symbol origin and kind,
receiver shape, project topology, visibility, editing state, trigger, and
observable output. Every enum value names an exact registry witness; deleting
that row fails the audit even when another scenario still covers the same broad
capability. Lexer tokens, expression and statement union tags, and parser
completion productions are mapped with exhaustive switches and no catch-all
branch. Adding a variant without a completion policy therefore fails
compilation of the LSP suite.

The completion characters announced to clients are generated from the closed
protocol enum in `Lsp/Types.zig`. The contract maps that same enum, so adding a
trigger cannot update server capabilities while silently bypassing the
completion inventory.

## Independent oracle boundary

`Toolchain/Sources/Lsp/Tests/CompletionOracle.zig` establishes the first
independent boundary: it compiles a complete source through semantic analysis,
derives the declared public instance surface from the resulting frontend AST,
and compares that surface with the LSP response from an incomplete consumer.
The oracle never reads LSP candidates or recovery decisions. A source that
parses but is ill-typed is explicitly rejected.

The registry gate separately parses every canonical source and sends every
autonomous fixture through semantic checking. Local fixtures use the frontend
boundary. Each multi-package scenario names one fixture from a closed
`WorkspaceFixtures.Id` enum and is compiled through `Project.Compiler` with an
autonomous package graph. The audit rejects a `workspace` row without a
fixture, a local row tied to one, and a fixture enum value that no scenario
exercises. These graphs cover qualified imports, aliases, source atoms,
principal reexports, catalogues, development dependencies, friend visibility,
submodules, merged extensions, and platform-selected sources without reading
sibling repositories. Remaining completion defects stay explicit
`assigned_gap` rows until their owning Parts close them.

Semantic, workspace, and protocol cases keep both a low-level proof and a
server proof. Real package or example failures are reduced to autonomous
fixtures; their original path is retained only as provenance.

## Error recovery invariant

A syntax error is not evidence that a completion context has no candidates.
The registry distinguishes an error before the cursor, at the cursor, after the
cursor, and in a neighbouring block. Completion recovery must isolate the
invalid region, retain the last reliable scope and receiver type, and keep an
internal recovery failure distinct from a valid empty result.

The first recovery boundary is owned by `Lsp/Recovery.zig`. Once the completion
site has received its typed placeholder, independently invalid top-level
declarations are replaced with whitespace while preserving every byte offset
and line break. The current declaration is never discarded. Missing closing
parentheses or brackets immediately before the containing block are supplied
only to the parser view. Tests observe a closed recovery reason (`complete`,
`completion_site`, `isolated_invalid_declaration`,
`discarded_completion_line`, or `unavailable`) and exercise all four error
positions through the server protocol.

Every request constructs one `Completion.Decision` before any catalogue is
queried. It owns the byte cursor and prefix range, syntactic position,
receiver/cascade identity, qualified-type and return context, aggregate,
active call and argument, `try` variants, recovered program, trigger kind and
recovery reason. `Server.CompletionRequestDecision` binds that edit decision to
the document URI, exact document version and trigger character. Local and
workspace collectors consume this value; they do not classify the position a
second time.

Workspace member resolution has three observable outcomes: `items`,
`not_applicable`, and `unresolved_receiver`. Internal errors remain Zig errors
and reach the server's JSON-RPC safety boundary, which returns error `-32603`;
they must never become a successful empty completion list. A source-level gate
forbids `catch` conversions inside the completion request handler, while an
injected-failure test proves the protocol distinction.

## Running the gate

From `Silex/Toolchain`, run:

```text
zig build test-lsp
zig build check
zig build benchmark-lsp-completion -- 101
```

The ordinary `check` step already depends on the LSP suite. A change to the
parser catalogue, compiler enums, registry schema, or protected behaviour is
therefore rejected by the normal Silex validation path.

The benchmark remains separate from `check`: it validates the expected member
for every sample, then reports fresh, warmed, and edited-overlay latency,
dispersion, and request-arena backing allocations. Its committed observation is
documented under `Toolchain/Benchmarks/LspCompletion`; timing values are
comparison data, not nondeterministic test thresholds.

During construction of the contract, `assigned_gap` rows are allowed only with
an owner and an exact reproduction. Release qualification requires the count
to reach zero; a green registry audit alone does not claim that the recorded
gaps are fixed.
