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
Sources stored under another platform or target are ignored. Active roots must
not provide the same logical module.

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
