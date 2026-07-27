# Use source packages

A source package keeps its modules under `Module/`:

```text
Math/
  Package.json
  Module/
    Vec3.sx
```

A named package may also provide modules selected for the current target under
`Platform/macos-arm64/Module/`. This directory is a second logical module root:
`Platform/macos-arm64` never appears in module names. For example,
`Platform/macos-arm64/Module/System/Write.sx` provides
`PackageName.System.Write`.

Only `Module/` and the exact `macos-arm64` root are indexed. Sources stored
under another target are ignored. The common and selected roots must not both
provide the same logical module.

A local source outside these public roots may nevertheless be compiled as the
explicit program entry. For example, compiling `Math/Tests/Main.sx` makes that
file available as `Math.Tests.Main` for this compilation only. It does not
index the rest of `Tests/` and does not expose test modules to package users.

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
