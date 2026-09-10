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
  Part while a repair is in progress;
- `irrelevant` requires a checked reason why completion cannot apply.

The structural audit rejects duplicate identifiers, absent cursor markers, missing
positive or negative assertions, missing provenance, missing proof text, and
an unrepresented capability family. It also rejects runtime data tied to
`.specs/`, `.agents/`, or an absolute user path. Mutation tests remove a family,
a proof, a negative assertion, and a cursor to demonstrate that those omissions
turn the gate red. The release audit additionally rejects every
`assigned_gap`: the admission gate can only be green with zero known gap.

The matrix axes are closed enums: syntax position, symbol origin and kind,
receiver shape, project topology, visibility, editing state, trigger, and
observable output. Every enum value names an exact registry witness; deleting
that row fails the audit even when another scenario still covers the same broad
capability. Lexer tokens, expression and statement union tags, and parser
completion productions are mapped with exhaustive switches and no catch-all
branch. Adding a variant without a completion policy therefore fails
compilation of the LSP suite.

The record-shaped semantic surface is guarded as well. Every field of
`Ast.Program`, `Ast.Function`, `Ast.Structure` and `Ast.StructureField` has an
ordered decision naming either an existing completion witness or a precise
irrelevance reason. Adding, removing, renaming or reordering one of those
fields fails compilation before tests run. This closes the gap left by enum
switches alone: a new declaration category represented as record metadata
cannot silently bypass the completion inventory.

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
sibling repositories. Any newly reproduced completion defect must stay as an
explicit `assigned_gap` row until its repair and executable proof land
together.

Semantic, workspace, and protocol cases keep both a low-level proof and a
server proof. Real package or example failures are reduced to autonomous
fixtures; their original path is retained only as provenance.

`Lsp/Tests/SealedCompletionCorpus.zig` supplies a held-out semantic boundary.
Its fixed cases cover a value surface, a GFX-style cascade, an optional call
chain, a specialized generic and a protocol receiver. Each complete source is
compiled by the frontend oracle; the corresponding incomplete source is sent
through the server. The test compares the entire public instance surface,
checks forbidden candidates and duplicates, then repeats the request to prove
stable output. A failure is repaired in the engine, not by deleting an
expected member from the case.

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

## Local syntax and scope invariant

Local completion is checked through the real server request path, including
the item kind, detail, filter text, insertion text, order and absence of
duplicates. Exclusive positions compare the complete response, rather than
checking one expected label in a larger accidental catalogue. The contracts
cover module and structure declarations, nominal relations, type positions,
statement and expression roots, call labels and values, aggregate fields, and
lexical bindings.

The statement catalogue exposes `yield` only in the direct block of a match
branch. Ordinary function blocks and nested control-flow blocks do not suggest
it; semantic analysis then decides whether the enclosing match is used as a
value and requires the direct terminal `yield expression` form.

The lexical collector models parameters, ordinary declarations, nested and
shadowed scopes, direct tuple `for` bindings, indexed traversal bindings, local
tuple destructuring and implicit `match`/`try` bindings. Tuple element types
are retained whether the tuple comes from a parameter, a collection element,
a local binding or a function return. A binding becomes visible only after its
declaration and is removed at the closing brace of its exact scope.

Parser recovery at the cursor is insensitive to physical line layout. The
placeholder is selected from structural facts: an unfinished control condition
receives a condition and body, while an unfinished parenthesis, tuple or
collection receives an expression plus the exact missing closers. The same
lexical candidate must therefore survive missing `()`, `[]`, commas and bodies,
an invalid neighbouring statement, an invalid top-level declaration before or
after the cursor, interpolation, and Unicode preceding the cursor. Ordinary
string and comment text must return no language completion.

These guarantees live in `Lsp/Tests/Part03Contracts.zig` and the focused unit
tests next to `Lsp/Completion.zig`; they do not depend on the construction Spec.

## Running the gate

From `Silex/Toolchain`, run:

```text
zig build check-lsp-completion
zig build check
zig build audit-lsp-completion -- /path/to/SilexProject
zig build benchmark-lsp-completion -- 101
```

`check-lsp-completion` is the autonomous admission portal. It runs the complete
LSP contract suite, including registry, mutation, recovery, workspace,
protocol, oracle and sealed-corpus tests. The ordinary `check` step depends on
this named portal. A change to the parser catalogue, compiler enums, registry
schema, or protected behaviour is therefore rejected by the normal Silex
validation path.

`audit-lsp-completion` is the external corpus classifier. It accepts exactly
one workspace root, walks sorted `.sx` paths under `Silex`, `Silex-Examples`,
`Packages` and `Sandbox`, lexes every source, and prints a deterministic byte
fingerprint plus counts for every closed syntax/visibility signal. The command
fails on a lexical error, an empty corpus or an absent signal. This wide scan
detects new shapes and makes the qualified input reproducible; semantic
correctness remains proven by the reduced registry fixtures and the independent
frontend oracle rather than inferred from token counts. The latest recorded
campaign is in `LSP-completion-qualification.md`.

The benchmark remains separate from `check`: it validates the expected member
for every sample, then reports fresh, warmed, and edited-overlay latency,
dispersion, and request-arena backing allocations. Its committed observation is
documented under `Toolchain/Benchmarks/LspCompletion`; timing values are
comparison data, not nondeterministic test thresholds.

When adding a completion capability, first add its closed parser/contract
classification and an autonomous positive-and-negative server proof. For a
real omission, preserve the failing edit as a reduced fixture with provenance,
mark it `assigned_gap`, repair the shared inference or recovery rule, then turn
the row `protected` in the same green change. If the external audit reports a
new signal class, add a closed enum value and a witness before admitting the
language change. Never special-case a package, example, identifier or absolute
workspace path.
