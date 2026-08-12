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
  "requires": {
    "silex": ">=0.38.0 <0.39.0"
  }
}
```

Qualified package names extend the namespace of each shorter package prefix.
Packages reject independently distributed extensions by default, so `GFX` and
`GFX.UI` cannot be loaded together unless `GFX` explicitly authorizes that
direct child package:

```json
{
  "name": "GFX",
  "version": "1.4.1",
  "extensions": [
    "GFX.UI"
  ]
}
```

Use `"GFX.*"` to authorize any direct child of `GFX`. The wildcard covers one
name segment only: it permits `GFX.UI`, but never `GFX.UI.Controls`. Once
authorized, `GFX.UI` owns its namespace and must independently grant
`"GFX.UI.Controls"` or `"GFX.UI.*"`. Every qualified package therefore requires
its immediate parent package in the graph and the authorization of that parent.
An extension entry cannot skip a level or name a package outside the declaring
package's namespace. Omit `extensions` or use an empty array to keep the
namespace closed.

This policy concerns separate package identities. Modules owned directly by
`GFX`, including a module named `GFX.UI`, remain valid without authorization
because they belong to the same package.

For registry packages, extension grants are copied into the immutable release
manifest and checked against the archived `Package.json`. The installed package
keeps an internal proof of that release. Editing a global package manifest does
not grant another namespace: Silex rejects a manifest whose checksum or
extension policy no longer matches its proof and asks for reinstallation.
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

1. a compatible package beside the project;
2. a compatible package in the nearest ancestor `Packages/` directory;
3. a package registered with `silex link`;
4. the newest compatible installed version under
   `~/.silex/packages/Name@MAJOR.MINOR.PATCH/`.

The `SilexProject/Packages/` workspace therefore remains live by default:
editing `Packages/STD` or `Packages/GFX` is visible immediately to projects
inside the workspace. No installation, commit, tag, or push is involved.

Dependencies are direct. Declare every package used by the application; a
transitive dependency is not automatically visible.

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

Published packages come from the Silex registry. Their source archive is
verified against its registry SHA-256 before extraction, and its manifest must
match the selected name, version, and `requires.silex` range. Silex resolves
and installs every declared dependency first, selecting the newest published
version that satisfies both its package constraint and the running toolchain.
Dependency cycles and unavailable compatible releases are diagnosed before the
requested package is installed.

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

For a package checkout outside the consumer's ancestor `Packages/` directory,
register its source directory once:

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

The resolver then falls back to a compatible installed version. While the link
exists it is an intentional override: if its version no longer satisfies the
consumer or its `requires.silex` no longer accepts the toolchain, Silex reports
the incompatibility instead of silently selecting an installed copy.

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

A package that implements a platform boundary may bundle one precompiled
static archive per target and name the platform libraries it requires:

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

The same provider can declare system libraries on Linux and Windows without
exposing raw linker flags:

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

The archive path is relative to and must remain inside the package. The
compiler verifies that its object format and architecture match the manifest
target: Mach-O ARM64 on macOS, ELF x64 on Linux, and COFF x64 or ARM64 on
Windows. It selects only the matching declaration and supplies the archive,
Apple frameworks, and named system libraries to the final link when one of its
symbols is used. `frameworks` is restricted to macOS; `libraries` contains
portable names rather than `-l` flags or paths.

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
foreign source nor grants access to transitive packages. Dynamic libraries are
not part of this package contract.
