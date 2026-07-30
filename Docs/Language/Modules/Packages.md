# Use source packages

A source package keeps its modules under `Module/`:

```text
Math/
  Package.json
  Module/
    Vec3.sx
```

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
  "version": "1.4.1"
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

Use `^` for a compatible version range or `=` for one exact version.

Silex first checks a compatible sibling package, then installed packages under
`~/.silex/packages/Name@MAJOR.MINOR.PATCH/`.

Dependencies are direct. Declare every package used by the application; a
transitive dependency is not automatically visible.

## Declare a private native boundary

A package that implements a platform boundary may bundle one precompiled
static archive for `macos-arm64` and name the Apple frameworks it requires:

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

The archive path is relative to and must remain inside the package. The
compiler verifies that it is an ARM64 Mach-O archive, selects this declaration
only for the matching target, and supplies the archive and frameworks to the
final link when one of its symbols is used.

Only source owned by that package may bind the provider, for example as
`MacOS.SDL3`. Consumers depend on the ordinary Silex package and see only its
public Silex API; they do not repeat archive paths, linker flags, framework
lists, or the private foreign API. This bootstrap contract neither compiles
foreign source nor grants access to transitive packages. Dynamic libraries and
native package artefacts for Linux or Windows are not supported yet.
