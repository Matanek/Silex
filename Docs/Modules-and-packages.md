# Modules and packages

Module and package composition is resolved before semantic lowering reaches a
native backend.

## Resolve sources and package graphs

Package manifests locate no source by consumer-provided path. The resolver
derives canonical local, workspace-link, user-link, and installed locations
from package identities, builds a single-version dependency graph, and
enforces direct visibility.

Each manifest selects one physical source directory with `sources`, defaulting
to `Module`. The resolver removes that directory from canonical module names
and applies the same leaf below the portable, active platform, and exact
target roots. A loose invocation without `Package.json` keeps its entry-owned
implicit source root.

A valid `@Name.sx` basename is an invisible physical atom of the logical
module represented by its directory. All atoms of that module are composed
before semantic lowering while retaining file-local imports, declarations
and provenance. Their basenames never enter module paths or LSP module
results; `@Module.sx` is a convention with no distinct compiler privilege.

## Resolve extensions and suites

An exact namespace extension may carry a `suite` installation permission.
The registry expands only a package explicitly requested by registered name
with `--suite`, and selects independently released members whose parent
dependency accepts that exact release. Suite selection adds no
package-composition dependency and is never inferred from a wildcard.

In an interactive terminal, registry installation reports lookup, package
resolution, release acquisition, and installation for transitive
dependencies and, only when requested, exact suite members. One active line
updates in place while completed packages remain as durable results. A
selected package release is processed once across the complete dependency
and requested suite graph. A failed suite member becomes a durable result and
does not prevent independent members from being installed. After visiting
the complete requested suite, the command returns a nonzero status without
repeating the durable interactive diagnostics. Redirected executions do not
gain progress output and instead receive one combined failure diagnostic.

## Enforce namespace ownership and visibility

A parent package remains authoritative over every module in its namespace.
When it and an authorized child package provide the child's exact principal
module, the parent is canonical and composition fails unless the parent's
exact extension policy carries `merge`. An enabled merge adds distinct public
declarations while retaining their package owners; duplicate public names
and every deeper exact-module collision remain deterministic errors, and
neither module nor package visibility crosses the boundary implicitly.

Module interfaces preserve structured declaration identities (owner, module,
name and complete parameter signature), the required parameter count that
defines their effective call signatures, public nominal structures, fields,
and constructor and method signatures. Default expressions remain source
semantics resolved in their declaring module. Public reexports add a visible
façade name to these identities without copying declarations or creating
backend symbols. Transparent type aliases are normalized to the same portable
type before signatures and IR are built; interfaces retain only their visible
source name and canonical target. `package` visibility is checked against
package identity and the declaring package's authenticated extension
`friend` permission, while `local` is checked against preserved source-file provenance;
both are removed from public interfaces. Opaque non-public return types remain
typed without exposing their declarations or members. `public` is checked
during composition and semantic resolution; none of these visibilities is
related to Mach-O symbol export or native layout.

## Collect catalog contributions

Umbrella catalog contributions are discovered only in an active child
package's portable principal module. The parent manifest authenticates each
open catalog, and composition accepts only public reexports whose declaration
provider is owned by that child. Ownership follows the exact source provider,
including when the child adds a declaration to a parent-owned principal module
through an authorized `merge`. Conflicting aliases or child namespaces are
rejected deterministically. Contributions become ordinary typed reexport
bindings before semantic lowering; they inject no declarations, executable
code, runtime registry or backend concept into the parent module.

## Build the active semantic closure

Source discovery records every provider needed for deterministic name and
namespace lookup, but discovery alone does not make a provider executable.
The compiler deeply parses the entry module and its active dependency closure.
An ordinary private `use` activates its target immediately because the loaded
module may refer to that binding from any declaration body.

Public reexports and authenticated catalog contributions keep a lighter
in-memory surface. The compiler lexically indexes direct public declaration
names to validate an exported binding without parsing the provider's bodies.
It loads the complete provider when an active type, call, field access or
qualified path crosses that binding. Ambiguous surfaces, chained reexports and
invalid targets also load enough of the chain to preserve the established
diagnostic and its source position.

The surface index lives only for the current compilation. If a provider later
enters the active closure, its already-read source text is reused by the full
parser. No persistent index artifact is added to `.silex`; persistent cache
retention remains a separate compilation-cache policy.
