# Proving callback confinement without interpreting ownership

`Semantic/CallbackFlow/Confinement.zig` provides a sufficient proof before the
context-sensitive callback ownership interpreter. It can discharge a lexical
origin whose environments cannot reach anything that outlives its scope.
A failed proof runs the existing interpreter; it is not a diagnostic and does
not accept an abandoned or partially evaluated interpretation.

## Flow graph

The graph is built once from the complete composed typed IR. Its nodes represent
SSA values, locals, returns, globals, nominal fields, enum payloads and opaque
exits. Every branch and every function body contributes constraints, including
finalizers. No update, clear, release or destruction removes a constraint.
Consequently a finalizer that publishes an environment remains visible even
when the fast proof does not simulate its invocation or ownership counts.

Instances of a nominal type share field summaries. Inherited fields share the
base prefix; protocol extraction selects the destination conformer's own
nominal summary. Collections carry contents along their values and projections.
They do not share contents merely because both have type `uint[]`: such arrays
may hold unrelated numeric hashes or Silex object addresses.

Copies preserve aliases, including class addresses copied through integer
fields. References connect writes back to their pointees. Address, integer,
function and collection forwarding also carries alias information backwards.
Calls connect actual inputs, formals and returns. Indirect targets include all
referenced functions with the same lowered physical interface, conservatively
including erased reference modes. Inputs or results exposed by an indirect call
also flow back to its callee. This makes an opaque factory that can return a
retained owner visible through an external function input, including local
copies and higher-order returns.

Opaque results, callable native exports, raw stores and unsupported callable
projections retain the general proof when tainted. Native calls retain the
general interpreter's foreign-effect boundary: this pass does not execute
foreign code or establish a new ownership contract for unmanaged native handles.
It does not rewrite portable IR, change the ABI or remove native lifetime work.

## Per-origin decision

For one origin, reachability starts at each lexical environment that captures
an address. The proof requires lifetime-end metadata for every borrowed binding.
It succeeds only if reachability excludes:

- every Silex global and opaque exit;
- the origin's captures and parameters, including exposure through a factory;
- its returned value;
- every binding marked live at a lifetime end.

All environments of the origin participate together, so imprecision can require
the general proof even when individual lifetimes would be safe. The graph does
not use runtime control facts to accept a path. Its conservative merges can only
prevent this sufficient proof; the ownership interpreter still handles clears,
distinct instances, control alternatives and other precise cases.

Graph construction and each reachability walk use finite IR identities. A walk
visits each reached node and edge at most once. The graph belongs to this proof
invocation and is released afterwards; it is not a persistent compilation cache.
The internal `Options.confinement = false` retains the previous analysis as a
correctness oracle on bounded cases.

## Evidence and scope

`CallbackConfinementTests.zig` covers globals, live bindings, numeric aliases,
mutable references and collections, opaque factories and native values.
`CallbackConfinementSourceTests.zig` covers recursion and distinct factory
instances through the full frontend and reference interpreter. The existing
callback corpus remains authoritative for diagnostics and precise fallback.

The implementation is shared by both backends and all distributed targets.
End-to-end compilation timings must identify their host, backend, mode and cache
state; a graph-only replay is not a measurement of complete compilation.
Private trace counters report `callback_origins_confined`,
`callback_confinement_nodes` and `callback_confinement_edges` alongside the
existing interpreter counters.
