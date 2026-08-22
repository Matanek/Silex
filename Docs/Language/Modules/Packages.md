# Use source packages

A source package keeps its modules under `Module/`:

```text
Math/
  Package.json
  Module/
    @module.sx
    Vec3.sx
```

`Module/@module.sx` is the optional principal module of a named package. The
capitalized spelling `Module/@Module.sx` is also accepted with exactly the same
meaning. For a package named `Math`, either spelling provides `Math`; a nested
`Module/Geometry/@module.sx` provides `Math.Geometry`.

A named package may also provide modules selected for the current platform and
exact compilation target:

```text
Platform/MacOS/Module/
Platform/Linux/Module/
Platform/Windows/Module/
Target/macos-arm64/Module/
Target/linux-x64/Module/
Target/windows-x64/Module/
Target/windows-arm64/Module/
```

For `macos-arm64`, the compiler indexes `Module/`,
`Platform/MacOS/Module/`, then `Target/macos-arm64/Module/`. These physical
segments never appear in module names. For example,
`Platform/MacOS/Module/System/Write.sx` provides
`PackageName.System.Write`.

The platform root contains code shared by its architectures. Use the exact
target root only when source genuinely depends on the architecture or ABI.
Sources stored under another platform or target are ignored.

Distinct active roots of the same package may contribute fragments to one
logical module. For example, `Module/Randomizer.sx` and
`Platform/MacOS/Module/Randomizer.sx` both contribute to
`PackageName.Randomizer` for a macOS target. Their declarations are additive;
neither file overrides the other. Inside portable code, `Platform.name` and
`Target.name` select declarations from the homonymous active fragment. An
unqualified name never crosses this physical boundary. Equivalent paths inside
one root and the same logical module supplied by different packages remain
errors.

Each physical fragment may contain a local `main` for direct experimentation.
Only the `main` in the exact source passed as the program entry is selected;
the `main` declarations in every other fragment are ignored and never become
members of the logical module.

Fragments are optional. A package may continue to use explicit child modules
such as `Randomizer.Seed.sx` or `File.Platform.sx` whenever that boundary is
intentional.

`silex compile` selects the host target by default and accepts one explicit
target through `--target`. The recognized targets are `macos-arm64`,
`linux-x64`, `windows-x64`, and `windows-arm64`. A recognized target may still
have only a partial native emitter; unsupported machine operations are rejected
explicitly rather than silently changing the selected platform.

`silex targets` prints the matrix recognized by the running compiler and marks
its host target. This discovery belongs to the toolchain rather than a runtime
package because the compiler and STD are versioned independently.

A local source outside these public roots may nevertheless be compiled as the
explicit program entry. For example, compiling `Math/Tests/Main.sx` makes that
file available as `Math.Tests.Main` for this compilation only. It does not
index the rest of `Tests/`, does not expose test modules to package users, and
does not become an additional fragment of a module already supplied by an
active package root.

Its directory name and manifest identity match:

```json
{
  "name": "Math",
  "version": "1.4.1",
  "description": "Vectors, matrices, and numeric helpers for Silex programs.",
  "authors": ["Ada", "Grace"],
  "requires": {
    "silex": ">=0.38.0 <0.39.0"
  }
}
```

`description` is an optional non-empty single line without surrounding
whitespace. Keep it short enough to identify the package in search results and
catalogs without replacing the README.

`authors` is an optional non-empty array of unique, non-empty names. Its order
is preserved. The field records attribution only: it grants no namespace,
publication, registry, or source-access permission. Both metadata fields remain
optional so historical tagged manifests stay valid.

Qualified package names extend the namespace of each shorter package prefix.
Packages reject independently distributed extensions by default, so `GFX` and
`GFX.UI` cannot be loaded together unless `GFX` explicitly authorizes that
direct child package:

```json
{
  "name": "GFX",
  "version": "1.4.1",
  "extensions": {
    "GFX.UI": {}
  }
}
```

Use `"GFX.*"` to authorize any direct child of `GFX`. The wildcard covers one
name segment only: it permits `GFX.UI`, but never `GFX.UI.Controls`. Once
authorized, `GFX.UI` owns its namespace and must independently grant
`"GFX.UI.Controls"` or `"GFX.UI.*"`. An extension entry cannot skip a level or
name a package outside the declaring package's namespace. Omit `extensions` or
use an empty object to keep the namespace closed.

Each extension entry carries its own permissions. `friend` lets the selected
child access declarations carrying `package` visibility, `suite` includes that
exact child when the parent is explicitly installed from the registry, and
`merge` lets the parent and that exact child contribute public declarations to
the child's principal module:

```json
{
  "name": "GFX",
  "version": "1.4.1",
  "extensions": {
    "GFX.Physics": {
      "friend": true,
      "suite": true,
      "merge": true
    }
  }
}
```

Permissions default to `false`. A wildcard may carry `friend: true`, deliberately
granting privileged access to every matching direct child, including children
published later by the community. `suite: true` and `merge: true` are rejected
on a wildcard because an open name pattern can determine neither a stable
installation set nor one authenticated module participant. When both an exact
entry and a wildcard match a child, the exact entry defines its permissions.

Extension authorization delegates a namespace; it never transfers the
parent's authority over that namespace. A module supplied by `GFX` under the
exact name `GFX.Physics` is therefore canonical. If the active child package
also supplies its principal `GFX.Physics` module, composition rejects the two
providers by default with a diagnostic naming the parent and extension. The
child cannot replace the parent's module through installation order, version
selection, a workspace link, or a wildcard grant.

An exact `merge: true` permission makes this one collision intentionally
additive. The parent remains the canonical module provider, while public
declarations from both principal-module fragments enter the composed
`GFX.Physics` interface. Each declaration retains its package owner. `module`
and `package` visibility never merge across the package boundary; use the
independent `friend` permission when the child deliberately needs the parent's
`package` declarations. Two public declarations or reexports with the same
name reject the composition rather than selecting a winner. Modules below the
child namespace remain ordinary independently owned modules, and exact
collisions below the principal module remain errors.

Friendship grants access from the named child to the declaring parent. It does
not install or activate the child, replace a dependency, expose `module`,
`local`, `private`, or `protected` declarations, or make `package` declarations
public to ordinary consumers. A suite permission does not create a dependency
from the parent to the child and therefore cannot create a package-composition
cycle.

`silex install GFX` installs every exact extension carrying `suite: true`. For
each member, the registry selects the newest tagged release compatible with the
toolchain whose direct dependency on `GFX` accepts the selected GFX version.
The extension keeps its own release cycle; publishing a newer compatible
extension does not require a new GFX release. Suite expansion happens only for
the package explicitly requested by name. Installing `GFX.Physics`, or meeting
GFX as an ordinary dependency, does not expand GFX's suite. The member's normal
dependencies are still installed transitively.

This policy concerns separate package identities. Modules owned directly by
`GFX`, including a module named `GFX.UI`, remain valid without authorization
because they belong to the same package.

### Open umbrella catalogs to child packages

A package can designate selected public façade modules as reexport-only
catalogs:

```json
{
  "name": "GFX",
  "version": "1.4.1",
  "extensions": {
    "GFX.Physics": {
      "friend": true,
      "suite": true
    }
  },
  "catalogs": [
    "GFX.Components",
    "GFX.Plugins",
    "GFX.Resources"
  ]
}
```

An active immediate child such as `GFX.Physics` may then declare `contribute`
blocks in its portable principal module. The target must be an existing module
owned by its immediate parent and listed exactly in `catalogs`. The child can
reexport only declarations that it owns. Every contributed name is checked
against the umbrella's declarations, child namespaces and other contributions;
any collision rejects the composition.

Extension authorization, `friend`, `suite`, `merge`, and `catalogs` express
independent intentions. The extension key authorizes the child identity,
`friend` grants privileged source access, `suite` selects an exact child for
explicit parent installation, `merge` opens only the exact child principal
module to additive public composition, and `catalogs` opens named umbrellas to
safe public reexports.

For registered packages, extension permissions and catalog grants come directly
from `Package.json` in
the selected tagged commit. The installed package keeps a source proof binding
that manifest to its repository, commit, and checksums. Editing a global
package manifest does not grant another namespace or privileged package access:
Silex rejects a manifest whose checksum or grant policy no longer matches its
proof and asks for reinstallation.
Sibling workspace packages and packages selected with `silex link` remain live
development sources and therefore use their current manifests directly.

`requires.silex` states which Silex toolchains can load the package. The range
starts with an inclusive minimum and may add one exclusive maximum, separated
by a space. Silex validates this requirement before discovering or parsing the
package's modules. An installed package must declare it; application manifests
and local packages may omit it while being developed.

Use a bounded range while Silex is experimental so a breaking compiler release
cannot silently consume older package sources. A package may omit the maximum
only when it deliberately supports every newer Silex release:

```json
{
  "requires": {
    "silex": ">=1.2.0"
  }
}
```

## Declare a dependency

```json
{
  "dependencies": {
    "Math": "^1.4.0",
    "Silex.Bootstrap": "=0.1.0"
  }
}
```

Use `^` for a compatible version range or `=` for one exact version. A caret
accepts the requested version and every newer version with the same major
number, including during the `0.x` development series. For example, `^0.7.0`
accepts `0.8.0` but rejects `1.0.0`.

Silex resolves a dependency in this order:

1. a package linked in the nearest workspace scope;
2. a package linked for the current user;
3. the newest compatible installed version under
   `~/.silex/packages/Name@MAJOR.MINOR.PATCH/`.

A directory named `Packages/` has no special meaning to the resolver. Merely
placing STD, GFX, or HTML there never exposes them to a project. Register a
checkout explicitly with `silex link` when its sources must remain live.

Dependencies are direct. Declare every package used by the application; a
transitive dependency is not automatically visible.

### Declare development dependencies

Packages may keep tools used only by their examples, tests, benchmarks, smokes,
or other development programs outside their public dependency graph:

```json
{
  "dependencies": {
    "GFX": "^0.37.0"
  },
  "devDependencies": {
    "GFX.Viewer": "^0.1.0"
  }
}
```

`devDependencies` follows the same identity and version-constraint rules as
`dependencies`. One package cannot appear in both objects. The distinction is
semantic and does not depend on directory names: development sources in the
root checkout can import these packages, while the package's consumers never
inherit or see them through the package graph.

Install the explicitly requested package with its development environment:

~~~sh
silex install GFX.Canvas --dev
~~~

Only that root package's development dependencies are added. Their normal
dependencies remain transitive, but their own `devDependencies` are not
installed recursively. Without `--dev`, installation and consumption use only
`dependencies`. A missing development dependency is diagnosed with the exact
`silex install <package> --dev` command needed to prepare the checkout.

A loose program without `Package.json` needs no manifest merely to try Silex
or run a short script. Its implicit development environment exposes compatible
packages through workspace links, user links, then installed versions. Its
location and the directory from which `silex run` is launched never make a
nearby `Packages/` directory visible. When several installed versions are
compatible with the running toolchain, Silex selects the newest one. As soon
as a program gains a manifest, its declared direct dependencies replace this
implicit environment.

## Install a package

Install a package from a local checkout:

~~~sh
silex install path/to/STD
~~~

Install the newest published version compatible with the running toolchain, or
request one exact published version:

~~~sh
silex install STD
silex install STD@0.16.0
~~~

The Silex registry assigns each package name to its canonical Git repository.
Silex discovers `vMAJOR.MINOR.PATCH` tags there, reads their manifests, and
selects the newest tagged version satisfying both the package constraint and
the running toolchain. It creates the source archive from the exact selected
commit and records its repository, commit, and checksums in the installation
proof. Every declared dependency is resolved and installed first. Dependency
cycles and unavailable compatible releases are diagnosed before the requested
package is installed.

Silex validates its identity, version, and `requires.silex`, then copies it to
`~/.silex/packages/Name@MAJOR.MINOR.PATCH/`. Git metadata and local `.silex`
state are excluded. An installed version is immutable: the same name and
version cannot be replaced by another installation. Publish a new package
version when its distributed contents change.

If the package declares target artifacts, installation also prepares them for
the host. Select another target explicitly when required:

~~~sh
silex install path/to/GFX --target windows-x64
~~~

### Work on a package live

Register a package checkout once for the current user:

~~~sh
silex link path/to/STD
~~~

Consumers now resolve `STD` directly from that directory. Saved source and
manifest changes are visible to the compiler and LSP on their next request;
there is no copy and no Git publication step. Declared artifacts are prepared
inside the linked checkout for the host, or for the explicit target selected
with `--target`. Remove the override with:

~~~sh
silex unlink STD
~~~

To keep the override local to one workspace, name that workspace explicitly:

~~~sh
silex link path/to/STD --workspace path/to/MyApplication
silex unlink STD --workspace path/to/MyApplication
~~~

The link is stored as package identity and canonical source path under the
workspace's ignored `.silex/links/` state. It applies to projects below that
workspace, including loose scripts without a `Package.json`, and never leaks
into another workspace. Only the nearest workspace scope is used, and its
links win over the current user's links for the same package. This keeps the
package editable in place without requiring filesystem symbolic links or
making the consumer itself a package.

The resolver then falls back to a compatible installed version. While the link
exists it is an intentional override: if its version no longer satisfies the
consumer or its `requires.silex` no longer accepts the toolchain, Silex reports
the incompatibility instead of silently selecting an installed copy.

List every package available globally to the current user, independently of
the current directory, with:

~~~sh
silex packages
~~~

This inventory includes every installed version and every user link. Each line
reports the package identity, version, origin (`user-link` or `installed`), and
canonical source path.

Inspect the exact graph selected for a source file or project directory
separately with:

~~~sh
silex packages resolve path/to/MyApplication
~~~

The resolved graph may additionally report the `workspace-link` origin.
Without a path, `silex packages resolve` inspects the current directory.

## Declare verified package artifacts

A source package may keep large, prebuilt files outside Git and declare where
Silex prepares them for each target during package installation:

~~~json
{
  "artifacts": {
    "macos-arm64": {
      "SDL3": {
        "path": "Boundary/macos-arm64/libSDL3.a",
        "url": "https://github.com/example/GFX/releases/download/sdl3-3.4.10/SDL3-macos-arm64.a",
        "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
      }
    }
  }
}
~~~

`path` is relative to the package and cannot escape it. `url` must use HTTPS,
and `sha256` pins the exact content. Silex keeps an existing file whose checksum
already matches, otherwise it downloads to a temporary file, verifies it, then
replaces the destination. Compilation itself never downloads from the network.
If a declared boundary archive is absent, the compiler asks for the explicit
installation command.

## Declare a private native boundary

A package that implements a platform boundary may bundle a precompiled static
archive, name platform libraries or Apple frameworks, or combine these inputs:

```json
{
  "name": "GFX",
  "version": "0.1.0",
  "boundary": {
    "macos-arm64": {
      "providers": {
        "SDL3": {
          "archive": "Boundary/macos-arm64/libSDL3.a",
          "frameworks": ["Cocoa", "Metal"]
        }
      }
    }
  }
}
```

An archive is not required when the provider calls only symbols supplied by
the selected platform. STD can therefore describe its system provider without
shipping a placeholder binary:

```json
{
  "boundary": {
    "macos-arm64": {
      "providers": {
        "System": {
          "libraries": ["System"]
        }
      }
    },
    "linux-x64": {
      "providers": {
        "System": {
          "libraries": ["c", "m", "pthread"]
        }
      }
    }
  }
}
```

An archive-backed provider can additionally declare system libraries on Linux
and Windows without exposing raw linker flags:

```json
{
  "boundary": {
    "linux-x64": {
      "providers": {
        "SDL3": {
          "archive": "Boundary/linux-x64/libSDL3.a",
          "libraries": ["dl", "m", "pthread"]
        }
      }
    },
    "windows-x64": {
      "providers": {
        "SDL3": {
          "archive": "Boundary/windows-x64/SDL3.lib",
          "libraries": ["user32", "winmm"]
        }
      }
    }
  }
}
```

When present, the archive path is relative to and must remain inside the
package. The compiler verifies that its object format and architecture match
the manifest target: Mach-O ARM64 on macOS, ELF x64 on Linux, and COFF x64 or
ARM64 on Windows. It selects only the matching declaration and supplies its
archive, Apple frameworks, and named system libraries when one of its symbols
is used. `frameworks` is restricted to macOS; `libraries` contains names rather
than raw linker flags or paths. A provider must declare at least one effective
input.

A provider can require another provider from the same package or from a direct
package dependency. This models a private native link dependency without
duplicating an archive or exposing its foreign API:

```json
{
  "name": "GFX",
  "version": "0.1.0",
  "boundary": {
    "macos-arm64": {
      "providers": {
        "SDL3": {
          "archive": "Boundary/macos-arm64/libSDL3.a"
        },
        "SDL3_mixer": {
          "archive": "Boundary/macos-arm64/libSDL3_mixer.a",
          "requires": ["GFX.SDL3"]
        }
      }
    }
  }
}
```

Each entry in `requires` has the form `Package.Provider`. The package must be
the owner itself or a direct dependency, and must provide the named boundary
for the active target. When `GFX.SDL3_mixer` is selected, the linker places its
inputs before those of `GFX.SDL3` and includes every required provider only
once. Requirements may themselves require other providers.

Only source owned by that package may bind the provider through the
target-independent `Boundary` namespace:

```sx
use Interop.C
use Interop.Boundary

let version = C.function<func() int32>(
    library:Boundary.SDL3,
    name:"SDL_GetVersion"
)
```

The active target selects the provider declaration from the manifest.
Consumers depend on the ordinary Silex package and see only its
public Silex API; they do not repeat archive paths, linker flags, framework
lists, or the private foreign API. This bootstrap contract neither compiles
foreign source nor grants source access to another package's private boundary.
Provider requirements may target another provider from the same package or
from one of its direct dependencies. They affect only native linking;
arbitrary library paths and runtime loading remain outside this contract.
